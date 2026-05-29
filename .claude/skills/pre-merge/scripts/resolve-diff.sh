#!/usr/bin/env bash
# Resolve diff vs base and emit a structured summary.
# Usage: resolve-diff.sh [base-ref]
# Default base: origin/main
# Output: JSON to stdout with files_changed, lines_added, lines_removed, commit_count

set -euo pipefail

BASE="${1:-origin/main}"

# Fetch remote silently so origin/main is up to date when running against remote
git fetch --quiet origin 2>/dev/null || true

# Commit count ahead of base
COMMIT_COUNT=$(rtk git rev-list --count "${BASE}..HEAD" 2>/dev/null || echo 0)

# Stat output: parse added/removed totals
STAT=$(rtk git diff --stat "${BASE}...HEAD" 2>/dev/null || echo "")

# Extract files changed from name-only output (one path per line)
FILES=$(rtk git diff --name-only "${BASE}...HEAD" 2>/dev/null || echo "")

# Parse insertions/deletions from stat summary line
# e.g. " 3 files changed, 42 insertions(+), 7 deletions(-)"
ADDED=$(echo "$STAT" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo 0)
REMOVED=$(echo "$STAT" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo 0)

# Build JSON array of changed files
FILES_JSON=$(echo "$FILES" | grep -v '^$' | awk 'BEGIN{printf "["} NR>1{printf ","} {printf "\"%s\"", $0} END{printf "]"}')
if [ -z "$FILES_JSON" ] || [ "$FILES_JSON" = "[]" ]; then
  FILES_JSON="[]"
fi

cat <<EOF
{
  "base": "${BASE}",
  "branch": "$(rtk git branch --show-current 2>/dev/null || echo '')",
  "commit_count": ${COMMIT_COUNT},
  "files_changed": ${FILES_JSON},
  "lines_added": ${ADDED:-0},
  "lines_removed": ${REMOVED:-0}
}
EOF
