#!/usr/bin/env bash
# script-cert-status.sh — plan-review certification gate checker.
#
# Answers a single mechanical question for plan-em's Step 2 / Step 4
# preconditions: is this PRD certified for the requested wave? A PRD is
# certified when its frontmatter stamp is `yes` AND the §7 "Plan review findings"
# ledger carries no Critical finding still Open (or "Still open").
#
# Usage:
#   script-cert-status.sh <prd.md> --product   # gate the product/plan wave
#   script-cert-status.sh <prd.md> --eng        # gate the eng/build wave
#
# --product reads the `product-tuned:` stamp; --eng reads `eng-tuned:`.
#
# Output (single line on stdout):
#   CERTIFIED                                   stamp yes + no open Criticals
#   UNCERTIFIED no-stamp                        stamp missing / not `yes`
#   UNCERTIFIED open-critical <finding-id>      a Critical row is Open/Still open
#   LEDGER_HEADER_UNRESOLVED=severity|status    §7 header drift (exit 2, never CLEAN)
#
# A stamped PRD whose §7 ledger section is absent is CERTIFIED (ledger absent =
# no findings), with a note on stderr.
#
# Exit code: 0 = CERTIFIED, 1 = UNCERTIFIED, 2 = usage/environment error.

set -uo pipefail

SELF="$(basename "$0")"

usage() {
  echo "usage: $SELF <prd.md> --product|--eng" >&2
  exit 2
}

prd=""
mode=""
for arg in "$@"; do
  case "$arg" in
    --product) mode="product" ;;
    --eng)     mode="eng" ;;
    -h|--help) usage ;;
    --*)       echo "$SELF: unknown flag: $arg" >&2; usage ;;
    *)         if [[ -z "$prd" ]]; then prd="$arg"; else echo "$SELF: unexpected extra argument: $arg" >&2; usage; fi ;;
  esac
done

[[ -n "$prd" && -n "$mode" ]] || usage

if [[ ! -f "$prd" ]]; then
  echo "$SELF: no such PRD file: $prd" >&2
  exit 2
fi

case "$mode" in
  product) field="product-tuned" ;;
  eng)     field="eng-tuned" ;;
esac

# ── Frontmatter must open on line 1 with a `---` fence ────────────────────────
if [[ "$(sed -n '1p' "$prd")" != "---" ]]; then
  echo "$SELF: no YAML frontmatter in $prd" >&2
  exit 2
fi

# Extract the stamp value (everything after `<field>:`, comment- and space-trimmed).
stamp="$(awk -v key="$field" '
  NR==1 { next }                       # skip opening fence
  /^---[[:space:]]*$/ { exit }         # closing fence ends frontmatter
  {
    if ($0 ~ "^"key":[[:space:]]*") {
      v=$0; sub("^"key":[[:space:]]*","",v); sub(/[[:space:]]*#.*/,"",v)
      gsub(/^[[:space:]]+|[[:space:]]+$/,"",v)
      print tolower(v); exit
    }
  }
' "$prd")"

if [[ "$stamp" != "yes" ]]; then
  echo "UNCERTIFIED no-stamp"
  exit 1
fi

# ── §7 "Plan review findings" ledger — hunt for an Open Critical row ────────────
# Match on the section TITLE (number-agnostic — §7 may renumber); the legacy
# "Plan tune findings" heading in pre-v5 PRDs is accepted too. The findings
# table columns are: # | Date | Auditor | Severity | ... | Status. We locate the
# Severity and Status columns from the header row (position-independent) and flag
# any Critical row whose Status is still Open / Still open.
result="$(awk '
  function trim(s){ gsub(/^[[:space:]]+|[[:space:]]+$/,"",s); return s }
  BEGIN { insec=0; found=0; header_done=0; sev_col=0; stat_col=0; id_col=2; emitted=0 }
  /^##[[:space:]]/ {
    insec=0
    h=$0; sub(/^##[[:space:]]+/,"",h); sub(/^[0-9]+\.[[:space:]]*/,"",h); h=trim(h)
    if (tolower(h) ~ /^plan (review|tune) findings/) { insec=1; found=1; next }
  }
  insec && /^\|/ {
    n=split($0, cells, "|")
    issep=1
    for (i=2;i<n;i++){ c=trim(cells[i]); if (c !~ /^:?-+:?$/ && c!="") issep=0 }
    if (issep) next
    if (!header_done) {
      for (i=2;i<n;i++){ c=tolower(trim(cells[i]))
        if (c=="severity") sev_col=i
        if (c=="status")   stat_col=i
        if (c=="#")        id_col=i
      }
      header_done=1
      # A1: the Severity/Status columns are how an open Critical is detected. If
      # the header drifted and either did not resolve, every row would compare
      # against an empty cell and the ledger would read CLEAN past an open
      # Critical. Fail loud instead of falling through.
      if (sev_col==0 || stat_col==0) {
        miss = (sev_col==0 ? "severity" : "")
        if (stat_col==0) miss = (miss=="" ? "status" : miss "|status")
        print "HEADERBAD " miss
        emitted=1; exit
      }
      next
    }
    sev=tolower(trim(cells[sev_col]))
    stat=tolower(trim(cells[stat_col]))
    id=trim(cells[id_col])
    if (sev=="critical" && (stat=="open" || stat=="still open")) {
      print "OPENCRIT " (id==""?"row-" NR:id)
      emitted=1; exit
    }
  }
  END {
    if (!found) print "NOSECTION"
    else if (!emitted) print "CLEAN"
  }
' "$prd")"

case "$result" in
  NOSECTION)
    echo "CERTIFIED"
    echo "$SELF: note: §7 Plan review findings ledger absent in $prd — no findings to gate on." >&2
    exit 0 ;;
  CLEAN)
    echo "CERTIFIED"
    exit 0 ;;
  OPENCRIT\ *)
    echo "UNCERTIFIED open-critical ${result#OPENCRIT }"
    exit 1 ;;
  HEADERBAD\ *)
    echo "LEDGER_HEADER_UNRESOLVED=${result#HEADERBAD }"
    echo "$SELF: §7 findings table header did not resolve required column(s): ${result#HEADERBAD } — refusing to report CERTIFIED." >&2
    exit 2 ;;
  *)
    echo "$SELF: internal error parsing §7 ledger" >&2
    exit 2 ;;
esac
