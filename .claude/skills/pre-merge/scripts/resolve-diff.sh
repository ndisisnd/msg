#!/usr/bin/env bash
# Resolve diff vs base and emit a structured summary.
# Usage: resolve-diff.sh [base-ref]
# Default base: origin/main
# Output: JSON to stdout with files_changed, lines_added, lines_removed, commit_count

set -euo pipefail

BASE="${1:-origin/main}"

# Fetch remote to ensure origin/main is up to date
# Warn to stderr if fetch fails; set flag so caller knows base may be stale
if ! git fetch --quiet origin 2>/dev/null; then
  echo "⚠️  Warning: git fetch failed — base ref may be stale" >&2
fi

# Commit count ahead of base
COMMIT_COUNT=$(rtk git rev-list --count "${BASE}..HEAD" 2>/dev/null || echo 0)

# Stat output: parse added/removed totals
STAT=$(rtk git diff --stat "${BASE}...HEAD" 2>/dev/null || echo "")

# Extract files changed from name-only output (one path per line)
FILES=$(rtk git diff --name-only "${BASE}...HEAD" 2>/dev/null || echo "")

# Parse insertions/deletions from stat summary line
# e.g. " 3 files changed, 42 insertions(+), 7 deletions(-)"
# Returns 0 if line is absent (e.g., binary-only or mode-only diffs)
ADDED=$(echo "$STAT" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' 2>/dev/null || echo "0")
REMOVED=$(echo "$STAT" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' 2>/dev/null || echo "0")
ADDED="${ADDED:-0}"
REMOVED="${REMOVED:-0}"

# Build JSON array of changed files (properly escaped for JSON)
# Use jq to handle filenames with quotes, spaces, newlines safely
if command -v jq &>/dev/null; then
  FILES_JSON=$(echo "$FILES" | jq -Rs 'split("\n") | map(select(length > 0))')
else
  # Fallback if jq unavailable: basic awk with quote escaping
  FILES_JSON=$(echo "$FILES" | grep -v '^$' | awk 'BEGIN{printf "["} NR>1{printf ","} {gsub(/"/,"\\\"",$0); printf "\"%s\"", $0} END{printf "]"}')
fi

BRANCH=$(rtk git branch --show-current 2>/dev/null || echo "")

# Use jq to construct final JSON safely
if command -v jq &>/dev/null; then
  jq -n \
    --arg base "$BASE" \
    --arg branch "$BRANCH" \
    --argjson commit_count "$COMMIT_COUNT" \
    --argjson lines_added "$ADDED" \
    --argjson lines_removed "$REMOVED" \
    --argjson files_changed "$FILES_JSON" \
    '{base: $base, branch: $branch, commit_count: $commit_count, files_changed: $files_changed, lines_added: $lines_added, lines_removed: $lines_removed}'
else
  # Fallback if jq unavailable
  cat <<EOJSON
{
  "base": "${BASE}",
  "branch": "${BRANCH}",
  "commit_count": ${COMMIT_COUNT},
  "files_changed": ${FILES_JSON},
  "lines_added": ${ADDED},
  "lines_removed": ${REMOVED}
}
EOJSON
fi
