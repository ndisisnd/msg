#!/usr/bin/env bash
set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
MSG_REPO="${MSG_REPO:-https://github.com/ndisisnd/msg.git}"
COOK_INSTALL="curl -fsSL https://raw.githubusercontent.com/ndisisnd/cook/main/install.sh | bash"
CLAUDE_DIR="${HOME}/.claude"
SKILLS_DIR="${CLAUDE_DIR}/skills"
# The Codex lane. Codex CLI reads user-level skills from ~/.agents/skills — not
# from ~/.codex/skills, and not from ~/.claude/skills. Only ever touched when
# --codex is passed.
AGENTS_DIR="${HOME}/.agents"
CODEX_SKILLS_DIR="${AGENTS_DIR}/skills"
TMP_DIR="$(mktemp -d)"

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { printf '\033[0;34m→\033[0m  %s\n' "$*"; }
success() { printf '\033[0;32m✓\033[0m  %s\n' "$*"; }
warn()    { printf '\033[0;33m!\033[0m  %s\n' "$*"; }
die()     { printf '\033[0;31m✗\033[0m  %s\n' "$*" >&2; exit 1; }

cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

# ── Parse args ────────────────────────────────────────────────────────────────
WITH_COOK=0
WITH_CODEX=0
for arg in "$@"; do
  case "$arg" in
    --help|-h)
      echo "Usage: install.sh [--with-cook] [--codex]"
      echo
      echo "  Installs the msg skills into ~/.claude/skills."
      echo "  --with-cook   Also install the cook dependency (coding standards)."
      echo "  --codex       Also expose the skills to OpenAI Codex CLI, by"
      echo "                symlinking ~/.agents/skills/<name> at the installed"
      echo "                ~/.claude/skills/<name>. Without this flag nothing"
      echo "                under ~/.agents is created or touched."
      exit 0
      ;;
    --with-cook) WITH_COOK=1 ;;
    --codex) WITH_CODEX=1 ;;
    *) die "Unknown flag: $arg" ;;
  esac
done

# ── Preflight ─────────────────────────────────────────────────────────────────
command -v git  >/dev/null 2>&1 || die "git is required but not installed"
command -v curl >/dev/null 2>&1 || die "curl is required but not installed"

# ── Clone msg ─────────────────────────────────────────────────────────────────
echo
info "Cloning msg..."
git clone --depth 1 --quiet "${MSG_REPO}" "${TMP_DIR}/msg" || die "Failed to clone msg"

# Stamp material for `/msg --version`. Parsed with sed, not node — the installer
# must not require a JS toolchain just to read one field.
# The `|| true` matters: under `set -euo pipefail` a missing package.json would
# otherwise abort the whole install over a cosmetic stamp.
MSG_VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${TMP_DIR}/msg/package.json" 2>/dev/null | head -1 || true)"
MSG_COMMIT="$(git -C "${TMP_DIR}/msg" rev-parse --short HEAD 2>/dev/null || echo unknown)"
# A clone with no readable version predates package.json — say so rather than
# printing "vunknown", which reads like a real version number.
if [[ -n "${MSG_VERSION}" ]]; then
  MSG_LABEL="msg v${MSG_VERSION}"
else
  MSG_LABEL="msg (unversioned)"
fi
success "Cloned ${MSG_LABEL}"

# ── Install skills ────────────────────────────────────────────────────────────
info "Installing skills to ${SKILLS_DIR}..."
mkdir -p "${SKILLS_DIR}"

# Skills that were renamed or retired upstream. This installer copies, it never
# deletes, so without this sweep an old directory keeps shadowing its replacement
# on every existing install and Claude Code loads both.
# Only ever list names msg itself shipped — never a name a user could have
# installed from somewhere else.
RETIRED_SKILLS=(plan-tune post-merge)
for retired in "${RETIRED_SKILLS[@]}"; do
  if [[ -d "${SKILLS_DIR}/${retired}" ]]; then
    rm -rf "${SKILLS_DIR:?}/${retired}"
    warn "Removed retired skill: ${retired}"
  fi
done

SRC="${TMP_DIR}/msg/.claude/skills"
installed=0
# The shipping set, recorded as it is installed. The Codex lane below sweeps
# against this rather than a second hand-maintained list, so the two roots can
# never disagree about what msg currently ships.
SHIPPED_SKILLS=()

for skill_dir in "${SRC}"/*/; do
  skill_name="$(basename "${skill_dir}")"
  # improve/ is a repo-internal plan tracker, not an invokable skill — never ship it.
  [[ "${skill_name}" == "improve" ]] && continue
  dest="${SKILLS_DIR}/${skill_name}"
  rm -rf "${dest}"
  cp -r "${skill_dir}" "${dest}"
  SHIPPED_SKILLS+=("${skill_name}")
  ((installed++)) || true
done

success "Installed ${installed} skill(s)"

# Version stamp — written after the copy, because copying msg/ wipes the dest dir.
# This file is the only thing that tells an installed copy which release it is:
# ~/.claude/skills is not a git checkout, so there is nothing else to ask.
printf '%s — %s, installed %s\n' \
  "${MSG_LABEL}" "${MSG_COMMIT}" "$(date +%F)" > "${SKILLS_DIR}/msg/VERSION"

# ── Optional Codex lane ───────────────────────────────────────────────────────
# Codex CLI discovers user-level skills under ~/.agents/skills and follows
# symlinked skill folders. So the Codex leg is symlinks, not a second copy:
# one set of bytes, one version stamp, and no way for the two harnesses to
# drift apart between releases. Without --codex this block does not run, and
# nothing under ~/.agents is created, read or touched.
if [[ "${WITH_CODEX}" -eq 1 ]]; then
  # Nothing installed means the clone was empty or the layout moved. Building a
  # lane of links to nowhere would be worse than stopping here.
  [[ "${#SHIPPED_SKILLS[@]}" -gt 0 ]] || die "No skills were installed — refusing to build the Codex lane"
  info "Linking skills for Codex into ${CODEX_SKILLS_DIR}..."
  mkdir -p "${CODEX_SKILLS_DIR}"

  # shared/ is a ref library reached by path from the protocols, not an
  # invokable skill — it has no SKILL.md and must not appear in a skill picker.
  # improve/ never reached ~/.claude/skills in the first place.
  CODEX_SKILLS=()
  for skill_name in "${SHIPPED_SKILLS[@]}"; do
    [[ "${skill_name}" == "shared" ]] && continue
    CODEX_SKILLS+=("${skill_name}")
  done

  # Same copy-never-delete problem the ~/.claude sweep solves, one root over:
  # a retired name left behind keeps offering a dead skill in Codex's picker.
  # Two passes, in widening order of confidence about ownership.
  #   1. Names msg itself retired — removed whatever shape they are in.
  #   2. Links msg itself created (they point into ~/.claude/skills) whose
  #      name is no longer shipped. A plain directory that msg never wrote is
  #      someone else's skill and is left strictly alone.
  swept=0
  for retired in "${RETIRED_SKILLS[@]}"; do
    if [[ -e "${CODEX_SKILLS_DIR}/${retired}" || -L "${CODEX_SKILLS_DIR}/${retired}" ]]; then
      rm -rf "${CODEX_SKILLS_DIR:?}/${retired}"
      ((swept++)) || true
    fi
  done
  for existing in "${CODEX_SKILLS_DIR}"/*; do
    [[ -L "${existing}" ]] || continue
    name="$(basename "${existing}")"
    target="$(readlink "${existing}")"
    [[ "${target}" == *"/.claude/skills/${name}" ]] || continue
    shipped=0
    for skill_name in "${CODEX_SKILLS[@]}"; do
      [[ "${skill_name}" == "${name}" ]] && { shipped=1; break; }
    done
    if [[ "${shipped}" -eq 0 ]]; then
      rm -f "${existing}"
      ((swept++)) || true
    fi
  done
  [[ "${swept}" -gt 0 ]] && warn "Removed ${swept} retired skill link(s) from ${CODEX_SKILLS_DIR}"

  # Relative targets, so the pair survives a home directory that moves or is
  # mounted at a different path. From ~/.agents/skills, ../.. is ~.
  linked=0
  for skill_name in "${CODEX_SKILLS[@]}"; do
    ln -sfn "../../.claude/skills/${skill_name}" "${CODEX_SKILLS_DIR}/${skill_name}"
    ((linked++)) || true
  done
  success "Linked ${linked} skill(s) for Codex"
fi

# ── Install scripts ───────────────────────────────────────────────────────────
SRC_SCRIPTS="${TMP_DIR}/msg/.claude/scripts"
if [[ -d "${SRC_SCRIPTS}" ]]; then
  SCRIPTS_DIR="${CLAUDE_DIR}/scripts"
  mkdir -p "${SCRIPTS_DIR}"
  # v5 renamed every script to the `script-*` convention. Same copy-never-delete
  # problem as the skills above: the pre-v5 filenames would linger forever and a
  # protocol's fallback path could still resolve a stale copy.
  RETIRED_SCRIPTS=(
    doctor-detect-repo.sh eng-comment-scan.sh eng-commit-cap.sh eng-db-touch.sh
    plan-em-branch-resolve.sh plan-em-exec-collision.py plan-em-exec-skeleton.py
    plan-pm-deps-mirror.sh plan-pm-roadmap-scan.sh plan-pm-roadmap-sequence.py
    plan-tune-cert-status.sh plan-tune-preflight.sh post-merge-protection.sh
    pre-merge-aggregate-verdict.sh pre-merge-tier-resolve.sh pre-merge-tooling-detect.sh
    preflight-common.sh scan-n.prd scan-prd-digest.py stamp-intake.sh stamp-prd.sh
  )
  for n in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18; do
    RETIRED_SCRIPTS+=("preflight-check-${n}"'*.sh')   # glob expanded below, not here
  done
  removed=0
  for retired in "${RETIRED_SCRIPTS[@]}"; do
    for stale in "${SCRIPTS_DIR}/"${retired}; do
      [[ -e "${stale}" ]] || continue
      rm -f "${stale}"
      ((removed++)) || true
    done
  done
  [[ "${removed}" -gt 0 ]] && warn "Removed ${removed} pre-v5 script(s) with retired names"

  info "Installing scripts to ${SCRIPTS_DIR}..."
  script_count=0
  for f in "${SRC_SCRIPTS}"/*; do
    fname="$(basename "${f}")"
    cp "${f}" "${SCRIPTS_DIR}/${fname}"
    ((script_count++)) || true
  done
  # Several skills invoke these scripts directly (e.g. /pre-merge runs the
  # script-preflight-*.sh family and script-aggregate-verdict.sh as "$S",
  # not "bash $S"), so the execute bit must survive fresh and repeat installs.
  chmod +x "${SCRIPTS_DIR}"/*.sh "${SCRIPTS_DIR}/script-prd-number" 2>/dev/null || true
  [[ "${script_count}" -gt 0 ]] && success "Installed ${script_count} script(s)"
fi

# ── Ensure skill-bundled scripts stay executable ──────────────────────────────
find "${SKILLS_DIR}" -type f -name '*.sh' -exec chmod +x {} + 2>/dev/null || true

# ── Optional cook bootstrap ───────────────────────────────────────────────────
if [[ "${WITH_COOK}" -eq 1 ]]; then
  info "Installing cook..."
  if bash -c "${COOK_INSTALL}"; then
    success "Installed cook"
  else
    warn "cook install failed — msg works without it; retry later with: ${COOK_INSTALL}"
  fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo
success "${MSG_LABEL} installed successfully"
echo "  Skills: ${SKILLS_DIR}"
[[ "${WITH_CODEX}" -eq 1 ]] && echo "  Codex:  ${CODEX_SKILLS_DIR} (symlinks — one copy, one version stamp)"
echo
echo "  Next steps:"
echo "    • Run /msg --version in any project to confirm which release is live"
echo "    • Run /msg --init in a project to scaffold devkit files"
echo "    • Run /msg to see the full menu of skills"
echo
echo "  Stay up to date: https://github.com/ndisisnd/msg"
echo "  (check periodically for updates)"
echo
echo "  msg works best with cook, a coding standard tooling for maximum code quality. Check out the repo at https://github.com/ndisisnd/cook"
echo "  or install it now with ${COOK_INSTALL}"
echo
echo "  Dedicated to JC, who started agentic engineering way before I did anything."
echo
