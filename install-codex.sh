#!/usr/bin/env bash
set -euo pipefail

# install-codex.sh — the Codex-only installer for the msg harness (plan §10).
#
# It installs the generated Codex tree (`.agents/`) into the locations Codex
# discovers: `$HOME/.agents/skills` and `$HOME/.agents/scripts`. It is the
# counterpart to install.sh, never a replacement for it.
#
# Contract (DEV-CX-002, approved-translation):
#   * This script never reads, writes, removes or migrates `$HOME/.claude`.
#     A Codex-only install leaves every Claude byte exactly as it found it.
#   * It is idempotent: running it twice produces the same tree.
#   * It supports a temporary destination so evals can install into a throwaway
#     home without touching the operator's real one.
#
# The one exception is `--with-claude`, the optional combined install of plan
# §10: the user explicitly asks for both runtimes, and the *unmodified* Claude
# installer is delegated to for the Claude half. install.sh itself is never
# edited by this file — the combined path is additive.

# ── Config ────────────────────────────────────────────────────────────────────
MSG_REPO="${MSG_REPO:-https://github.com/ndisisnd/msg.git}"
COOK_INSTALL="curl -fsSL https://raw.githubusercontent.com/ndisisnd/cook/main/install.sh | bash"
AGENTS_DIR="${MSG_AGENTS_HOME:-${HOME}/.agents}"
TMP_DIR="$(mktemp -d)"
CLONED=0

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { printf '\033[0;34m→\033[0m %s\n' "$*"; }
success() { printf '\033[0;32m✓\033[0m %s\n' "$*"; }
warn()    { printf '\033[0;33m!\033[0m %s\n' "$*"; }
die()     { printf '\033[0;31m✗\033[0m %s\n' "$*" >&2; exit 1; }

cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

# ── Parse args ────────────────────────────────────────────────────────────────
WITH_COOK=0
WITH_CLAUDE=0
SOURCE_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      cat <<'USAGE'
Usage: install-codex.sh [--dest <dir>] [--from <repo-path>] [--with-claude] [--with-cook]

  Installs the generated msg Codex skills into ~/.agents/skills and the
  deterministic helpers into ~/.agents/scripts.

  --dest <dir>     Install into <dir> instead of ~/.agents (also: MSG_AGENTS_HOME).
  --from <path>    Install from an existing msg checkout instead of cloning.
  --with-claude    Also run the unmodified Claude installer (install.sh).
  --with-cook      Also install the cook dependency (coding standards).

  This installer never reads or writes ~/.claude. Use --with-claude if you
  want both runtimes installed.
USAGE
      exit 0
      ;;
    --dest)  AGENTS_DIR="${2:-}"; [[ -n "${AGENTS_DIR}" ]] || die "--dest needs a directory"; shift 2 ;;
    --from)  SOURCE_DIR="${2:-}"; [[ -n "${SOURCE_DIR}" ]] || die "--from needs a path"; shift 2 ;;
    --with-claude) WITH_CLAUDE=1; shift ;;
    --with-cook)   WITH_COOK=1; shift ;;
    *) die "Unknown flag: $1" ;;
  esac
done

# ── Destination guard ─────────────────────────────────────────────────────────
# A Codex install must never be aimed at Claude's home, by flag or by env.
case "${AGENTS_DIR}" in
  *"/.claude"|*"/.claude/"*) die "refusing to install Codex assets into a Claude home: ${AGENTS_DIR}" ;;
esac

# ── Preflight ─────────────────────────────────────────────────────────────────
command -v python3 >/dev/null 2>&1 || die "python3 required but not installed"
if [[ -z "${SOURCE_DIR}" ]]; then
  command -v git >/dev/null 2>&1 || die "git required but not installed"
fi

# ── Resolve source ────────────────────────────────────────────────────────────
echo
if [[ -n "${SOURCE_DIR}" ]]; then
  SOURCE_DIR="$(cd "${SOURCE_DIR}" && pwd)" || die "no such source: ${SOURCE_DIR}"
  info "Using msg checkout at ${SOURCE_DIR}"
else
  info "Cloning msg..."
  git clone --depth 1 --quiet "${MSG_REPO}" "${TMP_DIR}/msg"
  SOURCE_DIR="${TMP_DIR}/msg"
  CLONED=1
fi

SRC_SKILLS="${SOURCE_DIR}/.agents/skills"
SRC_SCRIPTS="${SOURCE_DIR}/.agents/scripts"
[[ -d "${SRC_SKILLS}" ]]  || die "no generated Codex tree at ${SRC_SKILLS} — run codex/script-build-codex-skills.py first"
[[ -d "${SRC_SCRIPTS}" ]] || die "no generated Codex helpers at ${SRC_SCRIPTS}"

# ── Verify the generated tree before installing it ────────────────────────────
# The tree is committed, so a normal install only confirms what it already has.
# A drifted checkout is refused rather than silently shipped.
if [[ -f "${SOURCE_DIR}/codex/script-check-codex-compat.py" ]]; then
  info "Verifying the generated Codex tree..."
  if ( cd "${SOURCE_DIR}" && python3 codex/script-check-codex-compat.py >/dev/null 2>&1 ); then
    success "Generated tree verified (9 skills, manifest current)"
  else
    if [[ "${CLONED}" -eq 1 ]]; then
      die "the cloned Codex tree failed its compatibility check — refusing to install"
    fi
    warn "compatibility check failed in this checkout — install continues, but the tree may be drifting"
  fi
fi

# ── Version label ─────────────────────────────────────────────────────────────
MSG_VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${SOURCE_DIR}/package.json" 2>/dev/null | head -1)"
MSG_COMMIT="$(git -C "${SOURCE_DIR}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
if [[ -n "${MSG_VERSION}" ]]; then
  MSG_LABEL="msg v${MSG_VERSION} (codex)"
else
  MSG_LABEL="msg (codex)"
fi

info "Installing ${MSG_LABEL}"

# ── Install skills ────────────────────────────────────────────────────────────
SKILLS_DIR="${AGENTS_DIR}/skills"
info "Installing Codex skills to ${SKILLS_DIR}..."
mkdir -p "${SKILLS_DIR}"

# Skills msg itself once shipped on the Codex side and has since renamed or
# retired. Copy-never-delete would leave the old directory shadowing its
# replacement on every existing install. Only ever name directories msg shipped.
RETIRED_SKILLS=()
for retired in ${RETIRED_SKILLS[@]+"${RETIRED_SKILLS[@]}"}; do
  if [[ -d "${SKILLS_DIR}/${retired}" ]]; then
    rm -rf "${SKILLS_DIR:?}/${retired}"
    warn "Removed retired Codex skill: ${retired}"
  fi
done

installed=0
for skill_dir in "${SRC_SKILLS}"/*/; do
  skill_name="$(basename "${skill_dir}")"
  dest="${SKILLS_DIR}/${skill_name}"
  rm -rf "${dest}"
  cp -R "${skill_dir}" "${dest}"
  # `shared/` holds the cross-skill references the nine skills point at. It is a
  # reference holder, not an invokable skill, and carries no SKILL.md — Codex
  # discovers nine entry points, not ten.
  [[ "${skill_name}" == "shared" ]] || ((installed++)) || true
done

success "Installed ${installed} Codex skill(s) + shared references"

# ── Install helpers ───────────────────────────────────────────────────────────
SCRIPTS_DIR="${AGENTS_DIR}/scripts"
info "Installing helpers to ${SCRIPTS_DIR}..."
mkdir -p "${SCRIPTS_DIR}"

RETIRED_SCRIPTS=()
removed=0
for retired in ${RETIRED_SCRIPTS[@]+"${RETIRED_SCRIPTS[@]}"}; do
  for stale in "${SCRIPTS_DIR}/"${retired}; do
    [[ -e "${stale}" ]] || continue
    rm -f "${stale}"
    ((removed++)) || true
  done
done
[[ "${removed}" -gt 0 ]] && warn "Removed ${removed} retired helper(s)"

script_count=0
for f in "${SRC_SCRIPTS}"/*; do
  [[ -f "${f}" ]] || continue
  cp "${f}" "${SCRIPTS_DIR}/$(basename "${f}")"
  ((script_count++)) || true
done

# Skills invoke helpers directly (`"$S"`, not `bash "$S"`), so the execute bit
# has to survive both a fresh install and a repeat one.
chmod +x "${SCRIPTS_DIR}"/*.sh "${SCRIPTS_DIR}"/*.py "${SCRIPTS_DIR}/script-prd-number" 2>/dev/null || true
find "${SKILLS_DIR}" -type f -name '*.sh' -exec chmod +x {} + 2>/dev/null || true

success "Installed ${script_count} helper(s)"

# ── Version stamp ─────────────────────────────────────────────────────────────
# Written last: copying each skill wipes its destination directory first. The
# stamp names the runtime, because a machine may carry both installs and
# `$msg --version` must say which tree answered.
printf '%s — %s, installed %s\nruntime: codex\nskills: %s\n' \
  "${MSG_LABEL}" "${MSG_COMMIT}" "$(date +%F)" "${SKILLS_DIR}" \
  > "${SKILLS_DIR}/msg/VERSION"

# ── Optional combined install (plan §10) ──────────────────────────────────────
if [[ "${WITH_CLAUDE}" -eq 1 ]]; then
  echo
  info "Also installing the Claude runtime (unmodified install.sh)..."
  if [[ -f "${SOURCE_DIR}/install.sh" ]]; then
    claude_args=()
    [[ "${WITH_COOK}" -eq 1 ]] && claude_args+=(--with-cook)
    if MSG_REPO="${MSG_REPO}" bash "${SOURCE_DIR}/install.sh" ${claude_args[@]+"${claude_args[@]}"}; then
      success "Claude runtime installed"
      WITH_COOK=0   # install.sh already handled cook
    else
      warn "the Claude installer failed — the Codex install above is unaffected"
    fi
  else
    warn "install.sh not found in ${SOURCE_DIR} — skipping the Claude half"
  fi
fi

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
echo "    Skills:  ${SKILLS_DIR}"
echo "    Scripts: ${SCRIPTS_DIR}"
echo
echo "    Next steps:"
echo "      • Type \$msg --version in any Codex thread to confirm the install"
echo "      • Type \$msg --init to bootstrap a project"
echo "      • Type \$msg for the guided skill picker"
echo
echo "    Docs: https://github.com/ndisisnd/msg"
echo
