#!/usr/bin/env bash
# script-prd-deps-mirror.sh — mirror a PRD's §3 Dependencies column into its
# frontmatter `depends_on` array.
#
# §3 (Features & acceptance criteria) is the source of truth for cross-PRD edges:
# every prd-<n>-<slug> id that appears in a §3 Dependencies cell must also appear
# in the frontmatter `depends_on` array. This script extracts those ids, unions
# them with the current array, and rewrites `depends_on` in place. It replaces the
# inline awk-and-eyeball snippet in plan-pm's protocol Step 3 Part 4, and — per the
# wave design — owns its own array rewrite (script-prd-stamp.sh is scalar-only).
#
# Usage:
#   script-prd-deps-mirror.sh <prd.md>
#
# - Sub-PRD ids (prd-2.1-slug) count as ids. External services and bare F-IDs in
#   the Dependencies column are never mirrored — only prd-<n>-<slug> tokens.
# - The Dependencies column is located from the §3 table header, not a fixed index.
# - Prints `ADDED <id>` to stdout for each newly-added id (none added → no output).
# - Idempotent. Writes via a temp file + mv. `depends_on: []` when the union empty.
#
# Exit codes: 0 = mirrored (or nothing to add); 2 = missing file / no frontmatter.

set -uo pipefail

file="${1:-}"

if [[ -z "$file" ]]; then
  echo "usage: script-prd-deps-mirror.sh <prd.md>" >&2
  exit 2
fi
if [[ ! -f "$file" ]]; then
  echo "script-prd-deps-mirror: file not found: $file" >&2
  exit 2
fi

dir=$(dirname "$file")
tmp=$(mktemp "$dir/.deps-mirror.XXXXXX") || { echo "script-prd-deps-mirror: cannot create temp file" >&2; exit 2; }
trap 'rm -f "$tmp"' EXIT

awk -v out="$tmp" '
function trim(x) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", x); return x }
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
# Pull every prd-<n>[.<m>]-<slug> token out of s, recording first-seen order.
function extract(s, setarr, ordarr,   rest,tok) {
  rest=s
  while (match(rest, /prd-[0-9]+(\.[0-9]+)?-[a-z0-9-]+/)) {
    tok=substr(rest, RSTART, RLENGTH)
    if (!(tok in setarr)) { setarr[tok]=1; ordarr[++ordarr[0]]=tok }
    rest=substr(rest, RSTART+RLENGTH)
  }
}

# ── Pass 1: collect current depends_on ids and §3 Dependencies ids ──
FNR==NR {
  if (FNR==1) { if ($0=="---") { fm=1 } else { nofm=1 } ; next }
  if (fm==1) {
    if ($0=="---") { fm=2; next }
    if ($0 ~ /^depends_on:/) { extract($0, curset, curord); have_dep=1 }
    next
  }
  # body — locate §3 and its Dependencies column
  if (tolower($0) ~ /^##[[:space:]]*([0-9]+\.[[:space:]]*)?features[[:space:]]*&/) { insec=1; next }
  if (insec==1 && $0 ~ /^## /) { insec=0 }
  if (insec==1 && $0 ~ /\|/) {
    if (depcol==0 && tolower($0) ~ /dependencies/) {
      n=splitcells($0, hc)
      for (j=1;j<=n;j++) if (tolower(trim(hc[j]))=="dependencies") depcol=j
      next
    }
    if (depcol>0) {
      n=splitcells($0, dc)
      first=""
      for (j=1;j<=n;j++) { if (trim(dc[j])!="") { first=trim(dc[j]); break } }
      if (first ~ /^F[0-9]/) extract(dc[depcol], sixset, sixord)
    }
  }
  next
}

# ── Between passes: build the union line + ADDED list (once) ──
FNR==1 {
  if (nofm || fm!=2) { badfm=1 }
  # ordered union: existing ids first, then new §3 ids in first-seen order
  ucount=0
  for (i=1;i<=curord[0];i++) { ulist[++ucount]=curord[i] }
  for (i=1;i<=sixord[0];i++) {
    id=sixord[i]
    if (!(id in curset)) { ulist[++ucount]=id; print "ADDED " id }
  }
  newline="depends_on: ["
  for (i=1;i<=ucount;i++) { newline=newline (i>1?", ":"") ulist[i] }
  newline=newline "]"
  wrote_dep=0
}

# ── Pass 2: emit the file to $out, rewriting (or inserting) depends_on ──
{
  if (badfm) next
  if (fm2==0 && FNR==1 && $0=="---") { fm2=1; print > out; next }
  if (fm2==1) {
    if ($0=="---") {
      if (!have_dep && !wrote_dep) { print newline > out; wrote_dep=1 }
      fm2=2; print > out; next
    }
    if ($0 ~ /^depends_on:/ && !wrote_dep) { print newline > out; wrote_dep=1; next }
    print > out; next
  }
  print > out
}
END { if (badfm) exit 2 }
' "$file" "$file"
rc=$?

if [[ $rc -ne 0 ]]; then
  echo "script-prd-deps-mirror: no YAML frontmatter block in $file" >&2
  exit 2
fi

# Only replace the file when the mirror actually changed a byte.
if cmp -s "$tmp" "$file"; then
  exit 0
fi
mode=$(stat -f '%Lp' "$file" 2>/dev/null || stat -c '%a' "$file" 2>/dev/null || echo 644)
chmod "$mode" "$tmp" 2>/dev/null || true
mv "$tmp" "$file"
trap - EXIT
exit 0
