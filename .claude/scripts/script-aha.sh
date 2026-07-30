#!/usr/bin/env bash
# script-aha.sh — the writer for devkit/AHA.md.
#
# FILE-OWNED, NOT SKILL-OWNED. Any skill that records a learning in AHA.md goes
# through this script, so the entry shape, the ordering rule (most recent first)
# and the recurrence count have exactly one implementation.
#
# Usage:
#   script-aha.sh <AHA.md> --tag <tag> --summary <text> --why <text> --note <text> [--date YYYY-MM-DD]
#   script-aha.sh <AHA.md> --count <tag>
#
#   --tag      bracket tag written into the entry title, e.g. `tune:vague-criteria`.
#              Rendered as `[<tag>]`. Callers own the vocabulary; this script only
#              requires it to be non-empty and free of `[`, `]` and newlines.
#   --count    report the recurrence count for <tag> and write nothing.
#   --date     defaults to today.
#
# Writes the entry directly beneath the `## Entries` heading (skipping any leading
# HTML comment block), so the file stays most-recent-first. Every other byte is
# preserved; the write goes via a temp file + mv so a crash cannot truncate the log.
#
# Output (KEY=VALUE lines on stdout):
#   AHA_TAG=<tag>
#   AHA_COUNT=<n>        occurrences of `[<tag>]` in the file AFTER the write
#   AHA_APPENDED=yes|no  `no` only in --count mode
#
# Exit codes:
#   0  entry appended, or count reported
#   2  usage error, or the file exists but has no `## Entries` heading
#   3  target file absent — the caller is expected to skip the writeback (no devkit)

set -uo pipefail

SELF="$(basename "$0")"

usage() {
  echo "usage: $SELF <AHA.md> --tag <tag> --summary <text> --why <text> --note <text> [--date YYYY-MM-DD]" >&2
  echo "       $SELF <AHA.md> --count <tag>" >&2
  exit 2
}

file=""; tag=""; summary=""; why=""; note=""; date=""; count_only=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)     tag="${2-}";     shift 2 || usage ;;
    --summary) summary="${2-}"; shift 2 || usage ;;
    --why)     why="${2-}";     shift 2 || usage ;;
    --note)    note="${2-}";    shift 2 || usage ;;
    --date)    date="${2-}";    shift 2 || usage ;;
    --count)   count_only=1; tag="${2-}"; shift 2 || usage ;;
    -h|--help) usage ;;
    --*)       echo "$SELF: unknown flag: $1" >&2; usage ;;
    *)         if [[ -z "$file" ]]; then file="$1"; shift
               else echo "$SELF: unexpected extra argument: $1" >&2; usage; fi ;;
  esac
done

[[ -n "$file" && -n "$tag" ]] || usage
if [[ "$tag" == *"["* || "$tag" == *"]"* || "$tag" == *$'\n'* ]]; then
  echo "$SELF: tag must not contain '[', ']' or a newline: $tag" >&2
  exit 2
fi

if [[ ! -f "$file" ]]; then
  echo "$SELF: $file not found — nothing written (skip the writeback)" >&2
  exit 3
fi

count_tag() {
  grep -cF -- "[$tag]" "$file" 2>/dev/null || true
}

if [[ $count_only -eq 1 ]]; then
  echo "AHA_TAG=$tag"
  echo "AHA_COUNT=$(count_tag)"
  echo "AHA_APPENDED=no"
  exit 0
fi

# A learning with an empty leg is not a learning — refuse rather than write a stub.
for pair in "summary:$summary" "why:$why" "note:$note"; do
  if [[ -z "${pair#*:}" ]]; then
    echo "$SELF: --${pair%%:*} is required and must be non-empty" >&2
    usage
  fi
done

[[ -n "$date" ]] || date="$(date +%Y-%m-%d)"
if [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "$SELF: --date must be YYYY-MM-DD, got: $date" >&2
  exit 2
fi

if ! grep -qE '^##[[:space:]]+Entries[[:space:]]*$' "$file"; then
  echo "$SELF: no '## Entries' heading in $file — refusing to guess an insertion point" >&2
  exit 2
fi

dir="$(dirname "$file")"
tmp="$(mktemp "$dir/.script-aha.XXXXXX")" || { echo "$SELF: cannot create temp file" >&2; exit 2; }
trap 'rm -f "$tmp"' EXIT

# Insert directly after `## Entries` and any HTML comment block that follows it.
awk -v tag="$tag" -v date="$date" -v summary="$summary" -v why="$why" -v note="$note" '
function flush(   ) {
  print ""
  print "### [" date "] [" tag "] " summary
  print "**Why**: " why
  print "**Note**: " note
  print ""
  inserted = 1
}
BEGIN { at = 0; incomment = 0; inserted = 0 }
{
  if (!inserted && at) {
    if (incomment) { print; if ($0 ~ /-->/) incomment = 0; next }
    if ($0 ~ /^[[:space:]]*$/) { print; next }
    if ($0 ~ /^[[:space:]]*<!--/) {
      print
      if ($0 !~ /-->/) incomment = 1
      next
    }
    flush()
    print
    next
  }
  print
  if (!at && $0 ~ /^##[[:space:]]+Entries[[:space:]]*$/) at = 1
}
END { if (!inserted && at) flush(); if (!at) exit 4 }
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

echo "AHA_TAG=$tag"
echo "AHA_COUNT=$(count_tag)"
echo "AHA_APPENDED=yes"
exit 0
