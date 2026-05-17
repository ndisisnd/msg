#!/usr/bin/env bash
# eng-web-build-preflight.sh — pre-flight check for eng-web-build
#
# Usage: eng-web-build-preflight.sh <prd-path> [project-root]
#        project-root defaults to . (current directory)
#
# Checks foundational files and verifies the implementation plan section exists in the PRD.
# Outputs a structured report to stdout.
#
# Exit codes:
#   0 — all clear (P2/P3 issues only, or no issues)
#   1 — P1 issue(s) present (warn; user must confirm before proceeding)
#   2 — P0 issue(s) present (build blocked; must resolve before continuing)
#
# Run from the project root.

set -uo pipefail

prd_path="${1:-}"
root="${2:-.}"

p0=0
p1=0
lines=()

check_file() {
  local severity="$1" label="$2" path="$3" reason="$4"
  if [[ ! -f "$path" ]]; then
    lines+=("${severity}  ${label} — MISSING  ${reason}")
    case "$severity" in
      P0) (( p0++ )) ;;
      P1) (( p1++ )) ;;
    esac
  else
    lines+=("OK  ${label} — present")
  fi
}

printf '# Pre-flight — eng-web-build\n\n'

# --- Foundational files ---
check_file P0 "DESIGN-SYSTEM.md"  "$root/DESIGN-SYSTEM.md"  "(component registry — cannot enforce reuse without it)"
check_file P0 "ARCHITECTURE.md"   "$root/ARCHITECTURE.md"   "(system topology — cannot verify code placement without it)"
check_file P1 "AHA.md"            "$root/AHA.md"            "(institutional knowledge log — past mistakes and learnings unavailable)"
check_file P1 "GLOSSARY.md"       "$root/GLOSSARY.md"       "(domain terms — naming decisions are unguided)"
check_file P2 "OPEN-QUESTIONS.md" "$root/OPEN-QUESTIONS.md" "(unresolved decisions will not be surfaced)"
check_file P3 "CLAUDE.md"         "$root/CLAUDE.md"         "(repo-level agent instructions missing)"

# --- Implementation plan section ---
if [[ -z "$prd_path" ]]; then
  lines+=("P0  Implementation Plan — NO PRD PATH PROVIDED")
  (( p0++ ))
elif [[ ! -f "$prd_path" ]]; then
  lines+=("P0  Implementation Plan — PRD NOT FOUND: $prd_path")
  (( p0++ ))
elif ! grep -q "^## Implementation Plan — eng-web" "$prd_path"; then
  lines+=("P0  Implementation Plan — MISSING in $prd_path  (run eng-web-plan first)")
  (( p0++ ))
else
  lines+=("OK  Implementation Plan — present in $prd_path")
fi

# --- Report ---
for line in "${lines[@]}"; do
  printf '%s\n' "$line"
done

printf '\n'

if (( p0 > 0 )); then
  printf '[BUILD BLOCKED] %d P0 issue(s) — resolve before proceeding.\n' "$p0"
  exit 2
elif (( p1 > 0 )); then
  printf '[BUILD WARNING] %d P1 issue(s) — present options and require user confirmation before proceeding.\n' "$p1"
  exit 1
else
  printf '[PRE-FLIGHT OK] All critical checks passed.\n'
  exit 0
fi
