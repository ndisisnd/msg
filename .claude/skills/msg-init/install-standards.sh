#!/usr/bin/env bash
# Installs agent-skills-standard coding standards for the user's language.
#
# Usage: install-standards.sh <target_dir>
#
# Env vars:
#   LANGUAGE   Language/framework the user named (e.g. "Flutter", "Go", "React")
#
# Behaviour:
#   - Skips if LANGUAGE is empty or .skillsrc already exists.
#   - Normalises LANGUAGE to a kebab-case framework key (two aliases only:
#     "dart" → "flutter" and "go" → "golang" where the package name differs).
#   - Checks for npm; installs Node.js automatically if missing.
#   - Writes .skillsrc and runs agent-skills-standard sync --yes.
#   - Exits 0 always on skip; exits non-zero if npm install or sync fails.

set -eo pipefail

TARGET="${1:-.}"
LANGUAGE="${LANGUAGE:-}"

# ── Skip if no language given ─────────────────────────────────────────────────

if [[ -z "$LANGUAGE" ]]; then
  echo "install-standards: no language specified — skipping."
  exit 0
fi

# ── Normalise to ags framework key ────────────────────────────────────────────
#
# Mechanical transform: lowercase + kebab-case.
# Two aliases for names where the ags package key differs from common usage.

normalize() {
  local key
  key=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr ' /.' '-' | tr -s '-' | sed 's/^-//;s/-$//')
  case "$key" in
    go)   printf 'golang' ;;
    dart) printf 'flutter' ;;  # ags calls the Dart SDK "flutter"
    *)    printf '%s' "$key" ;;
  esac
}

ags_framework=$(normalize "$LANGUAGE")

# ── Idempotency ───────────────────────────────────────────────────────────────

if [[ -f "$TARGET/.skillsrc" ]]; then
  echo "install-standards: .skillsrc already exists — skipping."
  exit 0
fi

# ── npm availability ──────────────────────────────────────────────────────────

ensure_npm() {
  if command -v npm &>/dev/null; then
    return 0
  fi

  echo "install-standards: npm not found — attempting to install Node.js..."

  # nvm (may be installed but not loaded in a non-interactive shell)
  if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
    # shellcheck source=/dev/null
    . "$HOME/.nvm/nvm.sh"
    nvm install --lts && return 0
  fi

  # macOS — Homebrew
  if command -v brew &>/dev/null; then
    brew install node && return 0
  fi

  # Debian / Ubuntu
  if command -v apt-get &>/dev/null; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq \
      && sudo apt-get install -y nodejs npm \
      && return 0
  fi

  # Alpine
  if command -v apk &>/dev/null; then
    apk add --no-cache nodejs npm && return 0
  fi

  echo "install-standards: cannot install npm automatically." \
       "Install Node.js from https://nodejs.org and re-run /msg-init." >&2
  exit 1
}

ensure_npm

# ── Write .skillsrc ───────────────────────────────────────────────────────────

cat > "$TARGET/.skillsrc" <<SKILLSRC
registry: https://github.com/HoangNguyen0403/agent-skills-standard
agents:
  - claude
skills:
  ${ags_framework}: {}
workflows: false
SKILLSRC

echo "install-standards: wrote .skillsrc (framework: $ags_framework)."

# ── Sync standards ────────────────────────────────────────────────────────────

echo "install-standards: running agent-skills-standard sync..."
(cd "$TARGET" && npx agent-skills-standard@latest sync --yes)
echo "install-standards: sync complete."
