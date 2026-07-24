#!/usr/bin/env bash
# stamp-intake.sh — deterministic row writer for the INTAKE.md backlog ledger.
#
# The ledger is the markdown table at the repo root with the canonical header
#   | # | date | type | idea | goal | grade | status | prd |
# (see .claude/skills/msg/refs/init/templates/TEMPLATE-INTAKE.md). This writer
# rewrites ONLY the `status` cell (and the `prd` cell when --prd is given) of the
# one row whose `#` cell equals <row-#>. The header, every other row, and every
# other byte of the file are left identical. Replaces the improvised row edits in
# plan-pm (in-progress + prd) and post-merge (completed).
#
# Usage:
#   stamp-intake.sh <intake.md-path> <row-#> --status <value> [--prd <id>]
#
# Column positions are derived from the header row (cell names matched
# case-insensitively) — never hardcoded. Never renumbers, appends, or deletes.
# Pipe characters escaped as \| inside a cell are respected, so idea/goal cells
# may contain them. Writes via a temp file + mv.
#
# Exit codes: 0 = stamped; 1 = row-# not found (or no ledger table); 2 = usage
#             error / missing file.

set -uo pipefail

usage() {
  echo "usage: stamp-intake.sh <intake.md-path> <row-#> --status <value> [--prd <id>]" >&2
}

file="${1:-}"
row="${2:-}"
shift 2 2>/dev/null || { usage; exit 2; }

status=""
prd=""
have_status=0
have_prd=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --status) status="${2:-}"; have_status=1; shift 2 || { usage; exit 2; } ;;
    --prd)    prd="${2:-}"; have_prd=1; shift 2 || { usage; exit 2; } ;;
    *) echo "stamp-intake: unknown argument '$1'" >&2; usage; exit 2 ;;
  esac
done

if [[ -z "$file" || -z "$row" || $have_status -ne 1 ]]; then
  usage
  exit 2
fi

if [[ ! -f "$file" ]]; then
  echo "stamp-intake: file not found: $file" >&2
  exit 2
fi

dir=$(dirname "$file")
tmp=$(mktemp "$dir/.stamp-intake.XXXXXX") || { echo "stamp-intake: cannot create temp file" >&2; exit 2; }
trap 'rm -f "$tmp"' EXIT

awk -v target="$row" -v status="$status" -v prd="$prd" -v have_prd="$have_prd" '
function trim(x) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", x); return x }
# Split a markdown row on unescaped pipes; \| stays inside the cell it belongs to.
function splitcells(s, arr,   n,i,c,cur,prev) {
  delete arr; n=1; cur=""; prev=""
  for (i=1; i<=length(s); i++) {
    c=substr(s,i,1)
    if (c=="|" && prev!="\\") { arr[n]=cur; n++; cur="" }
    else { cur=cur c }
    prev=c
  }
  arr[n]=cur
  return n
}
# Replace a cell body while preserving its original leading/trailing whitespace.
function setcell(orig, val,   lead,tmp,trail,t) {
  t=orig; gsub(/^[[:space:]]+|[[:space:]]+$/, "", t)
  if (t=="") return " " val " "
  match(orig, /^[[:space:]]*/); lead=substr(orig, 1, RLENGTH)
  tmp=substr(orig, RLENGTH+1)
  match(tmp, /[[:space:]]*$/); trail=substr(tmp, RSTART)
  return lead val trail
}
function join(arr, n,   i,out) { out=arr[1]; for (i=2;i<=n;i++) out=out "|" arr[i]; return out }
BEGIN { header_found=0; col_num=0; col_status=0; col_prd=0; matched=0 }
{
  line=$0
  # Only pipe rows are candidates.
  if (line !~ /\|/) { print; next }
  if (!header_found) {
    n=splitcells(line, hc)
    ci_num=0; ci_status=0; ci_prd=0
    for (j=1;j<=n;j++) {
      name=tolower(trim(hc[j]))
      if (name=="#") ci_num=j
      else if (name=="status") ci_status=j
      else if (name=="prd") ci_prd=j
    }
    # A row that names both the # and status columns is the ledger header.
    if (ci_num>0 && ci_status>0) {
      header_found=1; col_num=ci_num; col_status=ci_status; col_prd=ci_prd
    }
    print; next
  }
  # Past the header: is this a separator row (all dashes/colons)? pass through.
  n=splitcells(line, dc)
  is_sep=1
  for (j=1;j<=n;j++) {
    b=trim(dc[j])
    if (b=="") continue
    if (b !~ /^:?-+:?$/) { is_sep=0; break }
  }
  if (is_sep) { print; next }
  # Data row: compare its # cell to the target.
  if (trim(dc[col_num]) == target) {
    dc[col_status] = setcell(dc[col_status], status)
    if (have_prd=="1" && col_prd>0) dc[col_prd] = setcell(dc[col_prd], prd)
    matched=1
    print join(dc, n); next
  }
  print
}
END {
  if (!header_found) exit 2
  if (!matched) exit 1
  exit 0
}' "$file" > "$tmp"
rc=$?

case $rc in
  0) mode=$(stat -f '%Lp' "$file" 2>/dev/null || stat -c '%a' "$file" 2>/dev/null || echo 644)
     chmod "$mode" "$tmp" 2>/dev/null || true
     mv "$tmp" "$file"
     trap - EXIT
     exit 0 ;;
  1) echo "stamp-intake: row #$row not found in ledger $file" >&2
     exit 1 ;;
  2) echo "stamp-intake: no ledger table found in $file" >&2
     exit 1 ;;
  *) echo "stamp-intake: internal error (awk rc=$rc)" >&2
     exit 2 ;;
esac
