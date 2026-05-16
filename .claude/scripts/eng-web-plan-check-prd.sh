#!/usr/bin/env bash
# eng-web-plan-check-prd.sh — validates a PRD has all sections required by eng-web-plan
#
# Usage: eng-web-plan-check-prd.sh <prd-path>
#
# Checks (in order):
#   1. File exists and is readable
#   2. ## Execution Table section is present
#   3. ## Engineering — eng-web section is present
#   4. At least one row with Agent = eng-web exists in the Execution Table
#
# On success: prints "OK: <path> is valid for eng-web-plan", exits 0
# On failure: prints a [PLAN BLOCKED] error to stderr, exits 1
#
# Run from the project root.

set -euo pipefail

prd_path="${1:-}"

if [[ -z "$prd_path" ]]; then
  echo "[PLAN BLOCKED] No PRD path provided." >&2
  echo "  Usage: eng-web-plan-check-prd.sh <prd-path>" >&2
  exit 1
fi

if [[ ! -f "$prd_path" ]]; then
  echo "[PLAN BLOCKED] PRD file not found: $prd_path" >&2
  exit 1
fi

if ! grep -q "^## Execution Table" "$prd_path"; then
  echo "[PLAN BLOCKED] Missing '## Execution Table' section in $prd_path" >&2
  echo "  Run plan-em to generate the execution table before running eng-web-plan." >&2
  exit 1
fi

if ! grep -q "^## Engineering — eng-web" "$prd_path"; then
  echo "[PLAN BLOCKED] Missing '## Engineering — eng-web' section in $prd_path" >&2
  echo "  Run plan-em (or eng-web in plan mode) to generate the engineering section first." >&2
  exit 1
fi

# Extract table rows between ## Execution Table and the next ## section,
# then check that at least one has Agent = eng-web (4th pipe-delimited field).
found=$(awk -F'|' '
  /^## Execution Table/ { in_table=1; next }
  in_table && /^## /   { in_table=0 }
  in_table && NF >= 5  {
    agent = $4
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", agent)
    if (agent == "eng-web") found++
  }
  END { print found+0 }
' "$prd_path")

if [[ "$found" -eq 0 ]]; then
  echo "[PLAN BLOCKED] No rows with Agent = 'eng-web' found in the Execution Table in $prd_path" >&2
  echo "  Check that plan-em has assigned at least one execution concern to eng-web." >&2
  exit 1
fi

echo "OK: $prd_path is valid for eng-web-plan ($found eng-web row(s) found)"
