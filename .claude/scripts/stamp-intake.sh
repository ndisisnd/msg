#!/usr/bin/env bash
# stamp-intake.sh — deterministic row writer for the INTAKE.md backlog ledger
# and its sidecar update log, INTAKE-UPDATE.md.
#
# The ledger is the markdown table at the repo root with the canonical header
#   | # | date | type | idea | goal | grade | status | prd |
# (see .claude/skills/msg/refs/init/templates/TEMPLATE-INTAKE.md). Every verb
# below touches ONLY what it names — the header, every other row, and every
# other byte of the file are left identical. Replaces the improvised row edits
# in plan-pm (in-progress + prd), post-merge (completed) and the freehand
# markdown writes in intake's capture / --update / --delete protocols.
#
# Verbs (exactly one per call; --status with no other verb = stamp, the
# original behaviour, unchanged for its existing callers):
#
#   stamp        stamp-intake.sh <intake.md> <row-#> --status <value> [--prd <id>]
#                Rewrite the `status` cell (and `prd` when given) of one row.
#
#   append-row   stamp-intake.sh <intake.md> <row-#> --append-row
#                  --type <t> --idea <s> --goal <s> --grade <s>
#                  [--date <YYYY-MM-DD>] [--status <v>] [--prd <id>]
#                Append one full 8-cell row after the last ledger row.
#                Defaults: --date today, --status backlog, --prd empty.
#                Refuses a `#` that already exists (never renumbers).
#
#   set-cell     stamp-intake.sh <intake.md> <row-#> --set-cell <cell> <value>
#                Rewrite exactly one cell of one row and print the OLD value on
#                stdout (the protocols' old → new diff echo reads it).
#                Allowed cells: type · idea · goal · grade.
#                Refused: `#` and `date` (immutable), `status` and `prd`
#                (stamp-verb territory — D14 lifecycle owners only).
#
#   remove-row   stamp-intake.sh <intake.md> <row-#> --remove-row
#                Delete exactly one row. Never renumbers — the gap stays.
#
#   log-append   stamp-intake.sh <intake.md> <row-#> --log-append
#                  --change <modify|add|remove> --detail <text> [--when <YYYY-MM-DD>]
#                Append one entry (when | row | change | detail) to
#                INTAKE-UPDATE.md beside the ledger, creating that file with the
#                canonical header (intake/refs/protocol-update.md § The update
#                log) when it is absent. Append-only; never rewrites an entry.
#
# Column positions are derived from the header row (cell names matched
# case-insensitively) — never hardcoded. Pipe characters escaped as \| inside a
# cell are respected on read and re-escaped on write, so idea/goal/detail cells
# may contain them (set-cell prints the old value unescaped, for display).
# Rows are matched on the `#` cell with an optional leading `#`. All ledger
# writes go through a temp file + mv. The header contract is owned by this file.
#
# Exit codes: 0 = done; 1 = row-# not found (or no ledger table); 2 = usage
#             error / missing file / unknown column; 3 = refused (protected
#             cell, bad --change value); 4 = `#` already exists (--append-row);
#             5 = write failure (temp file, mv, or log write).

set -uo pipefail

usage() {
  cat >&2 <<'USAGE'
usage: stamp-intake.sh <intake.md-path> <row-#> <verb>
  --status <value> [--prd <id>]                                   (stamp)
  --append-row --type <t> --idea <s> --goal <s> --grade <s>
               [--date <YYYY-MM-DD>] [--status <v>] [--prd <id>]
  --set-cell <type|idea|goal|grade> <value>
  --remove-row
  --log-append --change <modify|add|remove> --detail <text> [--when <YYYY-MM-DD>]
USAGE
}

file="${1:-}"
row="${2:-}"
shift 2 2>/dev/null || { usage; exit 2; }

verb=""
status=""
prd=""
have_status=0
have_prd=0
cell=""
value=""
rtype=""
idea=""
goal=""
grade=""
rdate=""
change=""
detail=""
when=""

set_verb() {
  if [[ -n "$verb" ]]; then
    echo "stamp-intake: verbs --$verb and --$1 are mutually exclusive" >&2
    usage
    exit 2
  fi
  verb="$1"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --status)     status="${2:-}"; have_status=1; shift 2 || { usage; exit 2; } ;;
    --prd)        prd="${2:-}"; have_prd=1; shift 2 || { usage; exit 2; } ;;
    --append-row) set_verb append-row; shift ;;
    --remove-row) set_verb remove-row; shift ;;
    --log-append) set_verb log-append; shift ;;
    --set-cell)   set_verb set-cell; cell="${2:-}"; value="${3:-}"
                  [[ $# -ge 3 ]] || { usage; exit 2; }; shift 3 ;;
    --type)       rtype="${2:-}"; shift 2 || { usage; exit 2; } ;;
    --idea)       idea="${2:-}"; shift 2 || { usage; exit 2; } ;;
    --goal)       goal="${2:-}"; shift 2 || { usage; exit 2; } ;;
    --grade)      grade="${2:-}"; shift 2 || { usage; exit 2; } ;;
    --date)       rdate="${2:-}"; shift 2 || { usage; exit 2; } ;;
    --change)     change="${2:-}"; shift 2 || { usage; exit 2; } ;;
    --detail)     detail="${2:-}"; shift 2 || { usage; exit 2; } ;;
    --when)       when="${2:-}"; shift 2 || { usage; exit 2; } ;;
    *) echo "stamp-intake: unknown argument '$1'" >&2; usage; exit 2 ;;
  esac
done

[[ -n "$verb" ]] || verb="stamp"
row="${row#\#}"

if [[ -z "$file" || -z "$row" ]]; then
  usage
  exit 2
fi

if [[ ! -f "$file" ]]; then
  echo "stamp-intake: file not found: $file" >&2
  exit 2
fi

# ── shared awk library ───────────────────────────────────────────────────────
# Row splitting, cell rewriting and \| handling — one parser for every verb.
awk_lib='
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
# Escape every pipe in a value written into a cell; collapse newlines.
function esc(v) { gsub(/\\\|/, "\001", v); gsub(/\|/, "\\|", v); gsub(/\001/, "\\|", v);
                  gsub(/[\n\r]/, " ", v); return v }
# Unescape for display (set-cell prints the old value for the diff echo).
function unesc(v) { gsub(/\\\|/, "|", v); return v }
function issep(arr, n,   j,b) {
  for (j=1;j<=n;j++) { b=trim(arr[j]); if (b=="") continue; if (b !~ /^:?-+:?$/) return 0 }
  return 1
}
function rownum(x) { x=trim(x); sub(/^#/, "", x); return (x ~ /^[0-9]+$/) ? x : "" }
'

mktmp() {
  local dir
  dir=$(dirname "$file")
  mktemp "$dir/.stamp-intake.XXXXXX" || { echo "stamp-intake: cannot create temp file" >&2; exit 5; }
}

commit_tmp() {
  local tmp="$1" mode
  mode=$(stat -f '%Lp' "$file" 2>/dev/null || stat -c '%a' "$file" 2>/dev/null || echo 644)
  chmod "$mode" "$tmp" 2>/dev/null || true
  mv "$tmp" "$file" || { echo "stamp-intake: cannot write $file" >&2; exit 5; }
}

case "$verb" in

# ── stamp (original behaviour) ───────────────────────────────────────────────
stamp)
  if [[ $have_status -ne 1 ]]; then usage; exit 2; fi
  tmp=$(mktmp) || exit 5
  trap 'rm -f "$tmp"' EXIT

  SI_STATUS="$status" SI_PRD="$prd" awk -v target="$row" -v have_prd="$have_prd" "$awk_lib"'
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
      if (ci_num>0 && ci_status>0) {
        header_found=1; col_num=ci_num; col_status=ci_status; col_prd=ci_prd
      }
      print; next
    }
    n=splitcells(line, dc)
    if (issep(dc, n)) { print; next }
    if (rownum(dc[col_num]) == target) {
      dc[col_status] = setcell(dc[col_status], esc(ENVIRON["SI_STATUS"]))
      if (have_prd=="1" && col_prd>0) dc[col_prd] = setcell(dc[col_prd], esc(ENVIRON["SI_PRD"]))
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
    0) commit_tmp "$tmp"; trap - EXIT; exit 0 ;;
    1) echo "stamp-intake: row #$row not found in ledger $file" >&2; exit 1 ;;
    2) echo "stamp-intake: no ledger table found in $file" >&2; exit 1 ;;
    *) echo "stamp-intake: internal error (awk rc=$rc)" >&2; exit 2 ;;
  esac
  ;;

# ── append-row ───────────────────────────────────────────────────────────────
append-row)
  if [[ -z "$rtype" || -z "$idea" || -z "$goal" || -z "$grade" ]]; then
    echo "stamp-intake: --append-row needs --type, --idea, --goal and --grade" >&2
    usage; exit 2
  fi
  [[ -n "$rdate" ]] || rdate=$(date +%F)
  [[ $have_status -eq 1 ]] || status="backlog"

  tmp=$(mktmp) || exit 5
  trap 'rm -f "$tmp"' EXIT

  SI_NUM="$row" SI_DATE="$rdate" SI_TYPE="$rtype" SI_IDEA="$idea" SI_GOAL="$goal" \
  SI_GRADE="$grade" SI_STATUS="$status" SI_PRD="$prd" \
  awk -v target="$row" "$awk_lib"'
  function put(name, val,   i) { i=cols[name]; if (i>0) out[i]=" " esc(val) " " }
  BEGIN { header_found=0; col_num=0; hn=0; hdridx=0; sepidx=0; last=0; dup=0; nl=0 }
  {
    lines[++nl]=$0
    line=$0
    if (line !~ /\|/) next
    if (!header_found) {
      n=splitcells(line, hc)
      ci_num=0; ci_status=0
      for (j=1;j<=n;j++) {
        name=tolower(trim(hc[j]))
        if (name!="") cols[name]=j
        if (name=="#") ci_num=j
        else if (name=="status") ci_status=j
      }
      if (ci_num>0 && ci_status>0) { header_found=1; col_num=ci_num; hn=n; hdridx=nl }
      next
    }
    n=splitcells(line, dc)
    if (issep(dc, n)) { if (last==0) sepidx=nl; next }
    v=rownum(dc[col_num])
    # A pipe row whose # cell is not a number is not a ledger row (e.g. a
    # legacy in-file update-log table) — never append after it.
    if (v=="") next
    if (v==target) dup=1
    last=nl
  }
  END {
    if (!header_found) exit 2
    if (dup) exit 4
    ins = (last>0) ? last : ((sepidx>0) ? sepidx : hdridx)
    for (i=1;i<=hn;i++) out[i]=" "
    out[1]=""; out[hn]=""
    put("#", ENVIRON["SI_NUM"]); put("date", ENVIRON["SI_DATE"])
    put("type", ENVIRON["SI_TYPE"]); put("idea", ENVIRON["SI_IDEA"])
    put("goal", ENVIRON["SI_GOAL"]); put("grade", ENVIRON["SI_GRADE"])
    put("status", ENVIRON["SI_STATUS"]); put("prd", ENVIRON["SI_PRD"])
    for (i=1;i<=nl;i++) { print lines[i]; if (i==ins) print join(out, hn) }
    exit 0
  }' "$file" > "$tmp"
  rc=$?
  case $rc in
    0) commit_tmp "$tmp"; trap - EXIT; exit 0 ;;
    2) echo "stamp-intake: no ledger table found in $file" >&2; exit 1 ;;
    4) echo "stamp-intake: row #$row already exists in $file — rows are never reused" >&2; exit 4 ;;
    *) echo "stamp-intake: internal error (awk rc=$rc)" >&2; exit 2 ;;
  esac
  ;;

# ── set-cell ─────────────────────────────────────────────────────────────────
set-cell)
  lc=$(printf '%s' "$cell" | tr '[:upper:]' '[:lower:]')
  case "$lc" in
    ""|"#"|date)
      echo "stamp-intake: cell '$cell' is immutable — # and date are never rewritten" >&2
      exit 3 ;;
    status|prd)
      echo "stamp-intake: cell '$cell' belongs to the stamp verb (--status/--prd), not --set-cell" >&2
      exit 3 ;;
    type|idea|goal|grade) ;;
    *)
      echo "stamp-intake: unknown cell '$cell' — allowed: type, idea, goal, grade" >&2
      exit 2 ;;
  esac

  cellprog="$awk_lib"'
  BEGIN { header_found=0; col_num=0; col_target=0; matched=0 }
  {
    line=$0
    if (line !~ /\|/) { if (mode=="set") print; next }
    if (!header_found) {
      n=splitcells(line, hc)
      ci_num=0; ci_status=0; ci_t=0
      for (j=1;j<=n;j++) {
        name=tolower(trim(hc[j]))
        if (name=="#") ci_num=j
        else if (name=="status") ci_status=j
        if (name==cellname) ci_t=j
      }
      if (ci_num>0 && ci_status>0) { header_found=1; col_num=ci_num; col_target=ci_t }
      if (mode=="set") print; next
    }
    n=splitcells(line, dc)
    if (issep(dc, n)) { if (mode=="set") print; next }
    if (rownum(dc[col_num]) == target) {
      matched=1
      if (mode=="get") { print unesc(trim(dc[col_target])); next }
      if (col_target>0) {
        dc[col_target] = setcell(dc[col_target], esc(ENVIRON["SI_VALUE"]))
        print join(dc, n); next
      }
    }
    if (mode=="set") print
  }
  END {
    if (!header_found) exit 2
    if (col_target==0) exit 5
    if (!matched) exit 1
    exit 0
  }'

  old=$(awk -v mode=get -v target="$row" -v cellname="$lc" "$cellprog" "$file")
  rc=$?
  case $rc in
    0) ;;
    1) echo "stamp-intake: row #$row not found in ledger $file" >&2; exit 1 ;;
    2) echo "stamp-intake: no ledger table found in $file" >&2; exit 1 ;;
    5) echo "stamp-intake: ledger $file has no '$cell' column" >&2; exit 2 ;;
    *) echo "stamp-intake: internal error (awk rc=$rc)" >&2; exit 2 ;;
  esac

  tmp=$(mktmp) || exit 5
  trap 'rm -f "$tmp"' EXIT
  SI_VALUE="$value" awk -v mode=set -v target="$row" -v cellname="$lc" "$cellprog" "$file" > "$tmp"
  rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "stamp-intake: internal error (awk rc=$rc)" >&2
    exit 2
  fi
  commit_tmp "$tmp"
  trap - EXIT
  printf '%s\n' "$old"
  exit 0
  ;;

# ── remove-row ───────────────────────────────────────────────────────────────
remove-row)
  tmp=$(mktmp) || exit 5
  trap 'rm -f "$tmp"' EXIT
  awk -v target="$row" "$awk_lib"'
  BEGIN { header_found=0; col_num=0; matched=0 }
  {
    line=$0
    if (line !~ /\|/) { print; next }
    if (!header_found) {
      n=splitcells(line, hc)
      ci_num=0; ci_status=0
      for (j=1;j<=n;j++) {
        name=tolower(trim(hc[j]))
        if (name=="#") ci_num=j
        else if (name=="status") ci_status=j
      }
      if (ci_num>0 && ci_status>0) { header_found=1; col_num=ci_num }
      print; next
    }
    n=splitcells(line, dc)
    if (issep(dc, n)) { print; next }
    # Drop exactly the target row. No renumbering — by construction.
    if (rownum(dc[col_num]) == target) { matched=1; next }
    print
  }
  END {
    if (!header_found) exit 2
    if (!matched) exit 1
    exit 0
  }' "$file" > "$tmp"
  rc=$?
  case $rc in
    0) commit_tmp "$tmp"; trap - EXIT; exit 0 ;;
    1) echo "stamp-intake: row #$row not found in ledger $file" >&2; exit 1 ;;
    2) echo "stamp-intake: no ledger table found in $file" >&2; exit 1 ;;
    *) echo "stamp-intake: internal error (awk rc=$rc)" >&2; exit 2 ;;
  esac
  ;;

# ── log-append ───────────────────────────────────────────────────────────────
log-append)
  case "$change" in
    modify|add|remove) ;;
    "") echo "stamp-intake: --log-append needs --change <modify|add|remove>" >&2; usage; exit 2 ;;
    *)  echo "stamp-intake: --change '$change' is not one of modify, add, remove" >&2; exit 3 ;;
  esac
  if [[ -z "$detail" ]]; then
    echo "stamp-intake: --log-append needs --detail <text>" >&2
    usage; exit 2
  fi
  [[ -n "$when" ]] || when=$(date +%F)

  logfile="$(dirname "$file")/INTAKE-UPDATE.md"
  # Lazy-create with the canonical header (protocol-update.md § The update log).
  if [[ ! -f "$logfile" ]]; then
    cat > "$logfile" <<'HEADER' || { echo "stamp-intake: cannot create $logfile" >&2; exit 5; }
# INTAKE-UPDATE — Update log

Edit history for INTAKE.md: entries made by `/intake --update` and removals by
`/intake --delete` — append-only. INTAKE.md holds the current state; this file
is how it got there, including rows that no longer exist. Rows created by plain
`/intake` capture are not logged (their `date` cell already records them).

`change` is always one of `modify` (a cell value changed — one entry per cell) ·
`add` (a row created by a split) · `remove` (a row deleted; the `#` is never
reused, so the ledger keeps a visible gap).

| when | row | change | detail |
|------|-----|--------|--------|
HEADER
  fi

  # Never duplicate the header on a subsequent append; just ensure the file ends
  # in a newline so the entry lands on its own row.
  if [[ -s "$logfile" && -n "$(tail -c1 "$logfile")" ]]; then
    printf '\n' >> "$logfile" || { echo "stamp-intake: cannot write $logfile" >&2; exit 5; }
  fi

  detail_esc=$(printf '%s' "$detail" | tr '\n\r' '  ' | sed -e 's/\\|/|/g' -e 's/|/\\|/g')
  printf '| %s | #%s | %s | %s |\n' "$when" "$row" "$change" "$detail_esc" >> "$logfile" \
    || { echo "stamp-intake: cannot write $logfile" >&2; exit 5; }
  exit 0
  ;;

*)
  usage
  exit 2
  ;;
esac
