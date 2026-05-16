#!/usr/bin/env bash
# detect-platform.sh — extracts target platform(s) from ARCHITECTURE.md
#
# Outputs one platform per line: Expo, Flutter, React Native, iOS, Android,
#   Desktop, Web, Backend
# Outputs nothing (exit 0) if ARCHITECTURE.md is absent or no platform detected.
#
# Run from the project root.

set -euo pipefail

file="ARCHITECTURE.md"

[[ -f "$file" ]] || exit 0

platforms=()

add_if_match() {
  local pattern="$1" label="$2"
  if grep -qiE "$pattern" "$file"; then
    platforms+=("$label")
  fi
}

# Most specific first — prevents broader terms from shadowing narrower ones.
add_if_match '\bExpo\b'                                                                  "Expo"
add_if_match '\bFlutter\b'                                                               "Flutter"
add_if_match '\bReact Native\b'                                                          "React Native"
add_if_match '\biOS\b'                                                                   "iOS"
add_if_match '\bAndroid\b'                                                               "Android"
add_if_match '\b(Electron|Tauri)\b'                                                      "Desktop"
# Fix: require frontend-specific terms — avoids matching "web API", "web server", "web service".
add_if_match '\b(web app|web application|web frontend|web client|browser|SPA|PWA)\b'    "Web"
add_if_match '\b(REST API|GraphQL|microservice|server-side|backend|API server)\b'        "Backend"

if [[ ${#platforms[@]} -gt 0 ]]; then
  printf '%s\n' "${platforms[@]}"
fi
