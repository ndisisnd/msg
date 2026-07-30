#!/usr/bin/env bash
# script-openq.sh — the writer for devkit/OPEN-QUESTIONS.md.
#
# FILE-OWNED, NOT SKILL-OWNED. Any skill that logs an unresolved question goes
# through this script, so the entry shape and the structural rule below have
# exactly one implementation.
#
# STRUCTURAL RULE: the append is append-only, into the `## Open Questions`
# section, at its end (immediately before the next `##` heading). The `## Resolved`
# section is never read, moved, reordered or written — moving an entry there is a
# human decision, not a script's.
#
# Usage:
#   script-openq.sh <OPEN-QUESTIONS.md> --title <t> --question <q> --raised-by <who>
#                   [--severity critical|high|medium|low] [--status open|in-progress]
#                   [--context <c>] [--options <o>] [--date YYYY-MM-DD]
#
#   --severity  defaults to medium.
#   --status    defaults to open. `resolved` is rejected — a resolved question does
#               not belong in the open section, and this script never writes the
#               Resolved section.
#   --date      defaults to today.
#
# Output (KEY=VALUE lines on stdout):
#   OPENQ_TITLE=<title>
#   OPENQ_COUNT=<n>       entries in the open section AFTER the write
#   OPENQ_APPENDED=yes
#
# Exit codes:
#   0  entry appended
#   2  usage error, or the file exists but has no `## Open Questions` heading
#   3  target file absent — the caller is expected to skip the log (no devkit)

set -uo pipefail

SELF="$(basename "$0")"

usage() {
  echo "usage: $SELF <OPEN-QUESTIONS.md> --title <t> --question <q> --raised-by <who>" >&2
  echo "       [--severity critical|high|medium|low] [--status open|in-progress]" >&2
  echo "       [--context <c>] [--options <o>] [--date YYYY-MM-DD]" >&2
  exit 2
}

file=""; title=""; question=""; raised=""; severity="medium"; status="open"
context=""; options=""; date=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)     title="${2-}";    shift 2 || usage ;;
    --question)  question="${2-}"; shift 2 || usage ;;
    --raised-by) raised="${2-}";   shift 2 || usage ;;
    --severity)  severity="${2-}"; shift 2 || usage ;;
    --status)    status="${2-}";   shift 2 || usage ;;
    --context)   context="${2-}";  shift 2 || usage ;;
    --options)   options="${2-}";  shift 2 || usage ;;
    --date)      date="${2-}";     shift 2 || usage ;;
    -h|--help)   usage ;;
    --*)         echo "$SELF: unknown flag: $1" >&2; usage ;;
    *)           if [[ -z "$file" ]]; then file="$1"; shift
                 else echo "$SELF: unexpected extra argument: $1" >&2; usage; fi ;;
  esac
done

[[ -n "$file" && -n "$title" && -n "$question" && -n "$raised" ]] || usage

case "$severity" in
  critical|high|medium|low) ;;
  *) echo "$SELF: --severity must be critical|high|medium|low, got: $severity" >&2; exit 2 ;;
esac

case "$status" in
  open|in-progress) ;;
  resolved) echo "$SELF: --status resolved is rejected — this script only writes the open section" >&2; exit 2 ;;
  *) echo "$SELF: --status must be open|in-progress, got: $status" >&2; exit 2 ;;
esac

[[ -n "$date" ]] || date="$(date +%Y-%m-%d)"
if [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "$SELF: --date must be YYYY-MM-DD, got: $date" >&2
  exit 2
fi

if [[ ! -f "$file" ]]; then
  echo "$SELF: $file not found — nothing written (skip the log)" >&2
  exit 3
fi

if ! grep -qE '^##[[:space:]]+Open Questions[[:space:]]*$' "$file"; then
  echo "$SELF: no '## Open Questions' heading in $file — refusing to guess an insertion point" >&2
  exit 2
fi

dir="$(dirname "$file")"
tmp="$(mktemp "$dir/.script-openq.XXXXXX")" || { echo "$SELF: cannot create temp file" >&2; exit 2; }
trap 'rm -f "$tmp"' EXIT

# Append at the END of the open section — immediately before the next `##`
# heading (which is `## Resolved` in the standard template) or at EOF.
awk -v date="$date" -v title="$title" -v question="$question" -v severity="$severity" \
    -v status="$status" -v context="$context" -v options="$options" -v raised="$raised" '
function flush(   ) {
  print ""
  print "### [" date "] " title
  print "**Question**: " question
  print "**Severity**: " severity
  print "**Status**: " status
  if (context != "") print "**Context**: " context
  if (options != "") print "**Options**: " options
  print "**Raised by**: " raised
  inserted = 1
}
BEGIN { insec = 0; inserted = 0 }
{
  if (insec && !inserted && $0 ~ /^##[[:space:]]/) { flush(); print ""; insec = 0; print; next }
  print
  if (!insec && !inserted && $0 ~ /^##[[:space:]]+Open Questions[[:space:]]*$/) insec = 1
}
END { if (insec && !inserted) flush(); if (!inserted) exit 4 }
' "$file" > "$tmp"
rc=$?

if [[ $rc -ne 0 ]]; then
  echo "$SELF: internal error inserting the entry (awk rc=$rc)" >&2
  exit 2
fi

mode="$(stat -f '%Lp' "$file" 2>/dev/null || stat -c '%a' "$file" 2>/dev/null || echo 644)"
chmod "$mode" "$tmp" 2>/dev/null || true
mv "$tmp" "$file"
trap - EXIT

# Count entries in the open section only — never the Resolved section.
open_count="$(awk '
  BEGIN { insec = 0; n = 0 }
  /^##[[:space:]]/ {
    insec = ($0 ~ /^##[[:space:]]+Open Questions[[:space:]]*$/) ? 1 : 0
    next
  }
  insec && /^###[[:space:]]/ { n++ }
  END { print n }
' "$file")"

echo "OPENQ_TITLE=$title"
echo "OPENQ_COUNT=$open_count"
echo "OPENQ_APPENDED=yes"
exit 0
