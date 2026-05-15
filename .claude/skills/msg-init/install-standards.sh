#!/usr/bin/env bash
# Installs agent-skills-standard coding standards for the detected framework.
#
# Usage: install-standards.sh <target_dir>
#
# Env vars:
#   LANGUAGE   Q2b answer (e.g. "Flutter / Dart", "Go", "Swift (iOS)")
#   PLATFORM   Q2 answer  (e.g. "Mobile (iOS/Android)", "Backend API")
#
# Exits 0 always — prints a skip message when no mapping exists or .skillsrc
# already exists. Exits non-zero only if npm install or sync fails.

set -eo pipefail

TARGET="${1:-.}"
LANGUAGE="${LANGUAGE:-}"
PLATFORM="${PLATFORM:-}"

# ── Framework mapping ─────────────────────────────────────────────────────────

ags_framework=""
case "$LANGUAGE" in
  "Flutter"*|"Dart"*)      ags_framework="flutter" ;;
  "Swift"*)                ags_framework="ios" ;;
  "Kotlin (Android)"*)     ags_framework="android" ;;
  "React Native"*)         ags_framework="react-native" ;;
  "Go"*)                   ags_framework="golang" ;;
  "Java / Kotlin"*)        ags_framework="spring-boot" ;;
  "TypeScript / Node.js"*) ags_framework="nestjs" ;;
esac

if [[ -z "$ags_framework" ]]; then
  echo "install-standards: no framework mapping for LANGUAGE='$LANGUAGE' — skipping."
  exit 0
fi

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
