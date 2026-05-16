#!/usr/bin/env bash
# detect-platform.sh — extracts the target platform from ARCHITECTURE.md
#
# Outputs one of: iOS, Android, React Native, Web
# Outputs nothing (exit 0) if ARCHITECTURE.md is absent or no platform is detected.
#
# Run from the project root.

set -euo pipefail

file="ARCHITECTURE.md"

if [[ ! -f "$file" ]]; then
  exit 0
fi

content="$(cat "$file")"

if echo "$content" | grep -qi '\bReact Native\b'; then
  echo "React Native"
elif echo "$content" | grep -qi '\biOS\b'; then
  echo "iOS"
elif echo "$content" | grep -qi '\bAndroid\b'; then
  echo "Android"
elif echo "$content" | grep -qi '\bweb\b'; then
  echo "Web"
fi
