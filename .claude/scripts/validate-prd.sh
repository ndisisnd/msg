#!/usr/bin/env bash
# validate-prd.sh — validates a PRD path for plan-em
#
# Usage: validate-prd.sh <prd-path>
#
# On success: prints the derived n (integer from features/prd-N/) to stdout, exits 0
# On failure: prints a human-readable error to stderr, exits 1
#
# Run from the project root.

set -euo pipefail

prd_path="${1:-}"

if [[ -z "$prd_path" ]]; then
  echo "Error: no PRD path provided." >&2
  echo "plan-em requires an existing PRD .md file." >&2
  echo "  - Run /plan-pm to create one" >&2
  echo "  - Or supply a path: features/prd-N/prd-N.md" >&2
  exit 1
fi

# Normalize: strip leading ./
prd_path="${prd_path#./}"

# Pattern check
if ! [[ "$prd_path" =~ ^features/prd-[0-9]+/prd-[0-9]+\.md$ ]]; then
  echo "Error: PRD path does not match expected pattern." >&2
  echo "  Expected: features/prd-N/prd-N.md" >&2
  echo "  Got:      $prd_path" >&2
  exit 1
fi

# Existence check
if [[ ! -f "$prd_path" ]]; then
  echo "Error: PRD file not found: $prd_path" >&2
  exit 1
fi

# Derive and emit n
prd_dir="$(dirname "$prd_path")"
n="${prd_dir#features/prd-}"
echo "$n"
