#!/usr/bin/env bash
# eng-web-plan-extract-rows.sh — extracts eng-web rows from the Execution Table in a PRD
#
# Usage: eng-web-plan-extract-rows.sh <prd-path>
#
# Parses the ## Execution Table section and outputs every row where Agent = eng-web.
# Each row is emitted as:
#   FEATURE: <Feature column value>
#   STEPS:   <Execution steps column value>
#   ROW_ORDER: <1-based index among all table rows>
#   ---
#
# Exit 0 with output on success; exit 1 if file missing or no eng-web rows found.
#
# Run from the project root.

set -euo pipefail

prd_path="${1:-}"

if [[ -z "$prd_path" ]] || [[ ! -f "$prd_path" ]]; then
  echo "Error: PRD file not found: ${prd_path:-<none provided>}" >&2
  exit 1
fi

found=$(awk -F'|' '
  /^## Execution Table/ { in_table=1; row=0; next }
  in_table && /^## /    { in_table=0 }

  # Skip header and separator lines
  in_table && /^\|[[:space:]]*[-:]+[[:space:]]*\|/ { next }
  in_table && /^\|[[:space:]]*Feature[[:space:]]*\|/ { next }

  in_table && NF >= 5 {
    row++
    agent = $4; gsub(/^[[:space:]]+|[[:space:]]+$/, "", agent)
    if (agent == "eng-web") {
      feature = $2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", feature)
      steps   = $3; gsub(/^[[:space:]]+|[[:space:]]+$/, "", steps)
      printf "FEATURE: %s\nSTEPS: %s\nROW_ORDER: %d\n---\n", feature, steps, row
      found++
    }
  }
  END {
    if (!found) {
      print "No eng-web rows found in Execution Table" > "/dev/stderr"
      exit 1
    }
  }
' "$prd_path")

if [[ -z "$found" ]]; then
  exit 1
fi

printf '%s\n' "$found"
