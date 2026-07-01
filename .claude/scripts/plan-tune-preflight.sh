#!/usr/bin/env bash
# plan-tune-preflight.sh [path-hint]
# Resolves, validates, and detects content type of a PRD file.
# Outputs KEY=VALUE lines to stdout. Exit 0 = success; exit 1 = error.
#
# Success outputs:
#   RESOLVED_PATH=features/prd-N-[slug]/prd-N-[slug].md
#   PRD_N=N
#   TUNE_SUGGESTION=product|eng
#
# Error outputs:
#   ERROR=no_path | invalid_pattern | not_found
#   RESOLVED_PATH=<attempted path>  (when applicable)

set -uo pipefail

hint="${1:-}"

if [[ -z "$hint" ]]; then
  echo "ERROR=no_path"
  exit 1
fi

resolved="${hint%/}"

# Derive file path from directory or extensionless path
if [[ -d "$resolved" ]] || [[ "$resolved" != *.md ]]; then
  base=$(basename "$resolved")
  if [[ "$base" =~ ^prd-[0-9]+(\.[0-9]+)? ]]; then
    resolved="${resolved}/${base}.md"
  fi
fi

# Validate pattern: features/prd-N[-slug]/prd-N[-slug].md with matching N
# N may be an integer (e.g. 3) or a decimal (e.g. 2.1) for sub-numbered PRDs.
if [[ ! "$resolved" =~ features/prd-([0-9]+(\.[0-9]+)?)(-[^/]*)?/prd-([0-9]+(\.[0-9]+)?)(-[^/]*)?\.md$ ]] || \
   [[ "${BASH_REMATCH[1]}" != "${BASH_REMATCH[4]}" ]]; then
  echo "ERROR=invalid_pattern"
  echo "RESOLVED_PATH=$resolved"
  exit 1
fi

n="${BASH_REMATCH[1]}"

if [[ ! -f "$resolved" ]]; then
  echo "ERROR=not_found"
  echo "RESOLVED_PATH=$resolved"
  exit 1
fi

if grep -qE "^## Engineering —" "$resolved"; then
  tune_suggestion="eng"
else
  tune_suggestion="product"
fi

echo "RESOLVED_PATH=$resolved"
echo "PRD_N=$n"
echo "TUNE_SUGGESTION=$tune_suggestion"
exit 0
