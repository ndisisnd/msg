#!/usr/bin/env bash
# script-prd-stamp.sh — deterministic scalar writer for PRD YAML frontmatter stamps.
#
# Edits exactly one `<field>: <value>` line inside the frontmatter block (the
# first `---` … `---` pair), preserving every other byte of the file. Replaces
# the improvised Bash/Edit stamps scattered across plan-em, plan-review, and
# merge so the lifecycle fields are written one proven way.
#
# Usage:
#   script-prd-stamp.sh <prd.md> <field> <value>
#
# Allowed fields (scalar lifecycle stamps only — arrays are owned by
# script-prd-deps-mirror.sh): status, product-tuned, eng-tuned, reviewed,
# completion, module, staging-signoff.
#
# `staging-signoff` is merge's ship-gate stamp — `<YYYY-MM-DD>@<certified
# sha>`, written by `--staging` on approval and re-written by `--production`
# when an unpinned legacy stamp is confirmed. It is the one field the whole
# production safety check keys on, so it is written here rather than by an
# improvised whole-file re-emit.
#
# Behaviour:
#   - Field present in frontmatter  → rewrite that one line in place.
#   - Same value already set        → no write, exit 0 (idempotent).
#   - Field absent from frontmatter → refuse (exit 2), EXCEPT `completion` and
#                                     `staging-signoff` (both optional, absent
#                                     until first stamped) which are inserted
#                                     before the closing `---`.
#   - Unknown field                 → usage + allowed list on stderr, exit 2.
#   - Missing file / no frontmatter → reason on stderr, exit 2.
#
# Writes via a temp file + mv, so a crash can never truncate the PRD.
# Exit codes: 0 = stamped or already-stamped; 2 = usage / refusal / no-frontmatter.

set -uo pipefail

ALLOWED="status product-tuned eng-tuned reviewed completion module staging-signoff"
INSERTABLE="completion staging-signoff"

usage() {
  echo "usage: script-prd-stamp.sh <prd.md> <field> <value>" >&2
  echo "allowed fields: $ALLOWED" >&2
}

file="${1:-}"
field="${2:-}"
value="${3:-}"

if [[ $# -ne 3 ]]; then
  usage
  exit 2
fi

# Validate the field against the allow-list (whole-word match).
if [[ " $ALLOWED " != *" $field "* ]]; then
  echo "script-prd-stamp: unknown field '$field'" >&2
  usage
  exit 2
fi

if [[ ! -f "$file" ]]; then
  echo "script-prd-stamp: file not found: $file" >&2
  exit 2
fi

# Only the optional fields may be inserted when absent.
insert=0
[[ " $INSERTABLE " == *" $field "* ]] && insert=1

dir=$(dirname "$file")
tmp=$(mktemp "$dir/.script-prd-stamp.XXXXXX") || { echo "script-prd-stamp: cannot create temp file" >&2; exit 2; }
trap 'rm -f "$tmp"' EXIT

awk -v field="$field" -v value="$value" -v insert="$insert" '
BEGIN { in_fm=0; done_fm=0; found=0; changed=0; nofm=0 }
NR==1 {
  if ($0=="---") { in_fm=1; print; next }
  nofm=1
}
{
  if (in_fm && $0=="---") {
    if (!found && insert=="1") { print field ": " value; found=1; changed=1 }
    in_fm=0; done_fm=1; print; next
  }
  if (in_fm && $0 ~ ("^" field ":")) {
    found=1
    newline = field ": " value
    if ($0 != newline) changed=1
    print newline; next
  }
  print
}
END {
  if (nofm) exit 5            # first line was not the opening fence
  if (in_fm && !done_fm) exit 5  # frontmatter never closed
  if (!found) exit 4         # field absent and not insertable
  if (changed) exit 0        # rewrote the line
  exit 3                     # found, already the target value
}' "$file" > "$tmp"
rc=$?

case $rc in
  0) mode=$(stat -f '%Lp' "$file" 2>/dev/null || stat -c '%a' "$file" 2>/dev/null || echo 644)
     chmod "$mode" "$tmp" 2>/dev/null || true
     mv "$tmp" "$file"
     trap - EXIT
     exit 0 ;;
  3) # idempotent: value already set, leave the file untouched
     exit 0 ;;
  4) echo "script-prd-stamp: field '$field' absent from frontmatter — refusing (insertable fields: $INSERTABLE)" >&2
     exit 2 ;;
  5) echo "script-prd-stamp: no YAML frontmatter block in $file" >&2
     exit 2 ;;
  *) echo "script-prd-stamp: internal error (awk rc=$rc)" >&2
     exit 2 ;;
esac
