#!/usr/bin/env bash
# ship-find-prd.sh — find candidate PRD files matching a prose query.
# Usage: ship-find-prd.sh "<query words>"
# Prints ranked candidate PRD paths (best match first), one per line.
# No query → prints all PRDs. No matches → prints nothing (exit 0).
set -euo pipefail

q="${*:-}"
shopt -s nullglob
prds=(features/prd-*/prd-*.md)
[ ${#prds[@]} -eq 0 ] && exit 0

# No query: emit all PRDs, most recent dir first.
if [ -z "${q// }" ]; then
  printf '%s\n' "${prds[@]}" | sort -r
  exit 0
fi

# Score each PRD: body matches +1, path matches +3 (path/slug is a strong signal).
for f in "${prds[@]}"; do
  score=0
  for w in $q; do
    [ ${#w} -lt 3 ] && continue            # skip noise words like "to", "a"
    body=$(grep -i -c -- "$w" "$f" 2>/dev/null || true); body=${body:-0}
    path=$(printf '%s' "$f" | grep -i -c -- "$w" 2>/dev/null || true); path=${path:-0}
    score=$(( score + body + path * 3 ))
  done
  printf '%s\t%s\n' "$score" "$f"
done | sort -rn -k1,1 | awk -F'\t' '$1 > 0 { print $2 }'
