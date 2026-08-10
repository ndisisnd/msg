#!/usr/bin/env bash
# script-cert-status.sh — plan-review certification gate checker.
#
# Answers a single mechanical question for plan-em's Step 2 / Step 4
# preconditions: is this PRD certified for the requested wave? A PRD is
# certified when its frontmatter stamp is `yes` AND its findings ledger carries
# no Critical finding still Open (or "Still open").
#
# Usage:
#   script-cert-status.sh <prd.md> --product   # gate the product/plan wave
#   script-cert-status.sh <prd.md> --eng        # gate the eng/build wave
#
# WHICH STAMP, WHICH LEDGER — both auto-detected, so the flags never change:
#   stamp   `--product` reads `product-tuned:` and `--eng` reads `eng-tuned:`
#           when the PRD carries that key (a pre-v5.4 file). When it does not,
#           both fall back to v5.4's single `reviewed:` stamp.
#   ledger  `<prd-dir>/reports/review-<prd-stem>.md` (its `## Findings` table)
#           when that report exists; otherwise the PRD's own inline
#           `## 7. Plan review findings` section. Nothing is ever migrated.
#
# Output (single line on stdout):
#   CERTIFIED                                   stamp yes + no open Criticals
#   UNCERTIFIED no-stamp                        stamp missing / not `yes`
#   UNCERTIFIED open-critical <finding-id>      a Critical row is Open/Still open
#   LEDGER_HEADER_UNRESOLVED=severity|status    ledger header drift (exit 2, never CLEAN)
#
# A stamped PRD whose ledger section is absent is CERTIFIED (ledger absent =
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

# Extract a frontmatter scalar (everything after `<key>:`, comment- and
# space-trimmed). Prints nothing when the key is absent.
read_fm() {
  awk -v key="$1" '
    NR==1 { next }                       # skip opening fence
    /^---[[:space:]]*$/ { exit }         # closing fence ends frontmatter
    {
      if ($0 ~ "^"key":[[:space:]]*") {
        v=$0; sub("^"key":[[:space:]]*","",v); sub(/[[:space:]]*#.*/,"",v)
        gsub(/^[[:space:]]+|[[:space:]]+$/,"",v)
        print tolower(v); exit
      }
    }
  ' "$prd"
}

# v5.4 fused the two tune stamps into one `reviewed:`. Read the mode's stamp when
# the PRD actually has it (a pre-v5.4 file), and fall back to `reviewed` when it
# does not — so `--product` and `--eng` keep working, unchanged at the call site,
# against a PRD of either shape.
if grep -qE "^${field}:" <(sed -n '2,/^---[[:space:]]*$/p' "$prd"); then
  stamp="$(read_fm "$field")"
else
  stamp="$(read_fm reviewed)"
fi

if [[ "$stamp" != "yes" ]]; then
  echo "UNCERTIFIED no-stamp"
  exit 1
fi

# ── Which ledger holds the findings ───────────────────────────────────────────
# v5.4 moved the ledger out of the PRD into a sibling report. An existing report
# is authoritative; otherwise the findings are still inline in the PRD's §7.
prd_dir="$(dirname "$prd")"
prd_stem="$(basename "$prd" .md)"
report="$prd_dir/reports/review-$prd_stem.md"
if [[ -f "$report" ]]; then
  ledger="$report"
  sec_re="^findings"
else
  ledger="$prd"
  sec_re="^plan (review|tune) findings"
fi

# ── The findings ledger — hunt for an Open Critical row ───────────────────────
# Match on the section TITLE (number-agnostic — the section may renumber); the
# legacy "Plan tune findings" heading in pre-v5 PRDs is accepted too. The two
# table shapes differ (the report dropped the Auditor column), so Severity and
# Status are resolved from the header row BY NAME rather than by position — which
# is what lets one scan read either ledger. Flags any Critical row whose Status
# is still Open / Still open.
result="$(awk -v secre="$sec_re" '
  function trim(s){ gsub(/^[[:space:]]+|[[:space:]]+$/,"",s); return s }
  BEGIN { insec=0; found=0; header_done=0; sev_col=0; stat_col=0; id_col=2; emitted=0 }
  /^##[[:space:]]/ {
    insec=0
    h=$0; sub(/^##[[:space:]]+/,"",h); sub(/^[0-9]+\.[[:space:]]*/,"",h); h=trim(h)
    if (tolower(h) ~ secre) { insec=1; found=1; next }
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
' "$ledger")"

case "$result" in
  NOSECTION)
    echo "CERTIFIED"
    echo "$SELF: note: findings ledger absent in $ledger — no findings to gate on." >&2
    exit 0 ;;
  CLEAN)
    echo "CERTIFIED"
    exit 0 ;;
  OPENCRIT\ *)
    echo "UNCERTIFIED open-critical ${result#OPENCRIT }"
    exit 1 ;;
  HEADERBAD\ *)
    echo "LEDGER_HEADER_UNRESOLVED=${result#HEADERBAD }"
    echo "$SELF: findings table header did not resolve required column(s): ${result#HEADERBAD } — refusing to report CERTIFIED." >&2
    exit 2 ;;
  *)
    echo "$SELF: internal error parsing the findings ledger" >&2
    exit 2 ;;
esac
