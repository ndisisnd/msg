#!/usr/bin/env bash
set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
MSG_REPO="${MSG_REPO:-https://github.com/ndisisnd/msg.git}"
COOK_INSTALL="curl -fsSL https://raw.githubusercontent.com/ndisisnd/cook/main/install.sh | bash"
CLAUDE_DIR="${HOME}/.claude"
SKILLS_DIR="${CLAUDE_DIR}/skills"
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
for arg in "$@"; do
  case "$arg" in
    --help|-h)
      echo "Usage: install.sh [--with-cook]"
      echo
      echo "  Installs the msg skills into ~/.claude/skills."
      echo "  --with-cook   Also install the cook dependency (coding standards)."
      exit 0
      ;;
    --with-cook) WITH_COOK=1 ;;
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
success "Cloned msg"

# ── Install skills ────────────────────────────────────────────────────────────
info "Installing skills to ${SKILLS_DIR}..."
mkdir -p "${SKILLS_DIR}"

SRC="${TMP_DIR}/msg/.claude/skills"
installed=0

for skill_dir in "${SRC}"/*/; do
  skill_name="$(basename "${skill_dir}")"
  # improve/ is a repo-internal plan tracker, not an invokable skill — never ship it.
  [[ "${skill_name}" == "improve" ]] && continue
  dest="${SKILLS_DIR}/${skill_name}"
  rm -rf "${dest}"
  cp -r "${skill_dir}" "${dest}"
  ((installed++)) || true
done

success "Installed ${installed} skill(s)"

# ── Install scripts ───────────────────────────────────────────────────────────
SRC_SCRIPTS="${TMP_DIR}/msg/.claude/scripts"
if [[ -d "${SRC_SCRIPTS}" ]]; then
  SCRIPTS_DIR="${CLAUDE_DIR}/scripts"
  mkdir -p "${SCRIPTS_DIR}"
  info "Installing scripts to ${SCRIPTS_DIR}..."
  script_count=0
  for f in "${SRC_SCRIPTS}"/*; do
    fname="$(basename "${f}")"
    cp "${f}" "${SCRIPTS_DIR}/${fname}"
    ((script_count++)) || true
  done
  # Several skills invoke these scripts directly (e.g. /pre-merge runs the
  # preflight-check-*.sh family and pre-merge-aggregate-verdict.sh as "$S",
  # not "bash $S"), so the execute bit must survive fresh and repeat installs.
  chmod +x "${SCRIPTS_DIR}"/*.sh "${SCRIPTS_DIR}/scan-n.prd" 2>/dev/null || true
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
success "msg installed successfully"
echo "  Skills: ${SKILLS_DIR}"
echo
echo "  Next steps:"
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
