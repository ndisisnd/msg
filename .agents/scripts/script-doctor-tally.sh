#!/usr/bin/env bash
# script-doctor-tally.sh — the reader for devkit/DOCTOR.md, the harness-incident ledger.
#
# FILE-OWNED, NOT SKILL-OWNED. Everything decidable about the ledger happens here:
# parse the incident rows, group them by skill + signature, and flag every group at
# the triage threshold. The judgment — diagnosing the defect and recommending a fix
# — is the model's, in `/msg --doctor` (msg/refs/protocol-doctor.md).
#
# Usage: script-doctor-tally.sh <DOCTOR.md>
#
# THRESHOLD: 3 occurrences, ever. No time window — a window is machinery for a
# problem nobody has observed yet. The threshold is a triage heuristic, not a metric.
#
# A group is flagged when it has >= 3 rows AND at least one row still `logged`.
# A group whose rows are all `graduated` has been triaged and is not re-reported;
# a graduated defect that recurs picks up new `logged` rows and comes back — which
# is the point.
#
# Output (KEY=VALUE lines, then zero or more TRIAGE rows, most recurrent first):
#   DOCTOR_FILE=<path>
#   DOCTOR_THRESHOLD=3
#   DOCTOR_ROWS=<total incident rows>
#   DOCTOR_LOGGED=<n>
#   DOCTOR_GRADUATED=<n>
#   DOCTOR_GROUPS=<distinct skill+signature groups>
#   DOCTOR_AT_THRESHOLD=<groups flagged for triage>
#   CLASS_<class>=<n>            one line per signature class present
#   TRIAGE=<count>|<logged>|<graduated>|<skill+mode>|<signature>|<first-date>|<last-date>
#
# Column resolution: the date / skill+mode / signature / status columns are looked
# up BY NAME from the Incidents header row (the pattern script-intake-stamp.sh and
# script-cert-status.sh use), not by fixed position. A column inserted or reordered
# used to shift every field one place, so no first cell parsed as a date, the tally
# reported DOCTOR_ROWS=0 at exit 0, and a ledger at threshold looked clean.
#
# Exit codes:
#   0  tally reported (including "nothing at threshold")
#   2  usage error, the file exists but has no `## Incidents` table, or the table
#      has body rows but not one parsed (LEDGER_ROWS_UNPARSED)
#   3  target file absent — no ledger to read

set -uo pipefail

SELF="$(basename "$0")"
THRESHOLD=3

usage() {
  echo "usage: $SELF <DOCTOR.md>" >&2
  exit 2
}

[[ $# -eq 1 ]] || usage
file="$1"
case "$file" in
  -h|--help) usage ;;
esac

if [[ ! -f "$file" ]]; then
  echo "$SELF: $file not found — no ledger to tally" >&2
  exit 3
fi

if ! grep -qE '^##[[:space:]]+Incidents[[:space:]]*$' "$file"; then
  echo "$SELF: no '## Incidents' heading in $file — not a DOCTOR ledger" >&2
  exit 2
fi

# One pass. Summary lines are emitted as-is; TRIAGE lines are sorted after, so the
# doctor triages the most recurrent signature first.
out=$(awk -v threshold="$THRESHOLD" -v file="$file" '
function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
function is_sep(   i, c, sep) {
  sep = 1
  for (i = 2; i < NF; i++) { c = trim($i); if (c !~ /^:?-+:?$/ && c != "") sep = 0 }
  return sep
}
BEGIN { FS = "|"; DATE_RE = "^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$"
        c_date = 0; c_skill = 0; c_sig = 0; c_status = 0 }
# Only the Incidents table counts. Separator rows fall out on their own; the
# header row is consumed once, to resolve the columns this tally reads BY NAME.
/^##[[:space:]]+Incidents[[:space:]]*$/ { in_table = 1; next }
!in_table { next }
$0 !~ /^\|/ { next }
is_sep() { next }
# ── A18: resolve the columns from the header row ─────────────────────────────
!header_done {
  header_done = 1
  if (trim($2) ~ DATE_RE) {
    # No header row at all (a bare table of rows) — keep the historical fixed
    # positions so a header-less ledger tallies exactly as it always did, and
    # fall through to treat this line as data.
    c_date = 2; c_skill = 3; c_sig = 4; c_status = 6
    headers_seen = "(no header row)"
  } else {
    for (i = 2; i < NF; i++) {
      c = tolower(trim($i))
      headers_seen = headers_seen (headers_seen == "" ? "" : ", ") c
      if (c == "date" || c ~ /date/)        { if (!c_date)   c_date = i }
      else if (c ~ /skill/)                 { if (!c_skill)  c_skill = i }
      else if (c ~ /signature/)             { if (!c_sig)    c_sig = i }
      else if (c == "status" || c ~ /status/) { if (!c_status) c_status = i }
    }
    next
  }
}
{
  body_rows++
  d = (c_date ? trim($c_date) : "")
  if (d !~ DATE_RE) next
  skill = (c_skill ? trim($c_skill) : "")
  sig   = (c_sig   ? trim($c_sig)   : "")
  status = (c_status ? trim($c_status) : "")
  if (status != "graduated") status = "logged"
  rows++
  if (status == "graduated") ngrad++; else nlog++

  split(sig, parts, ":")
  cls = parts[1]
  if (!(cls in class_count)) class_order[++nclass] = cls
  class_count[cls]++

  key = skill "|" sig
  if (!(key in count)) { order[++ngroups] = key; first[key] = d }
  count[key]++
  last[key] = d
  if (status == "graduated") gcount[key]++; else lcount[key]++
}
END {
  # A18: body rows exist but not one of them parsed as an incident. Either the
  # date column did not resolve or every row is shaped unexpectedly — both mean
  # this tally has no idea what is in the ledger, and DOCTOR_ROWS=0 at exit 0
  # would read as "nothing to triage".
  if (body_rows > 0 && rows == 0) {
    printf "LEDGER_ROWS_UNPARSED=%d\n", body_rows
    printf "%s: the Incidents table in %s has %d body row(s) but not one parsed as an incident — header cells seen: %s; refusing to report an empty tally\n",
           "script-doctor-tally", file, body_rows, (headers_seen == "" ? "(none)" : headers_seen) > "/dev/stderr"
    exit 9
  }
  for (i = 1; i <= ngroups; i++) {
    k = order[i]
    if (count[k] >= threshold && lcount[k] > 0) flagged++
  }
  printf "DOCTOR_FILE=%s\n", file
  printf "DOCTOR_THRESHOLD=%d\n", threshold
  printf "DOCTOR_ROWS=%d\n", rows + 0
  printf "DOCTOR_LOGGED=%d\n", nlog + 0
  printf "DOCTOR_GRADUATED=%d\n", ngrad + 0
  printf "DOCTOR_GROUPS=%d\n", ngroups + 0
  printf "DOCTOR_AT_THRESHOLD=%d\n", flagged + 0
  for (i = 1; i <= nclass; i++) {
    c = class_order[i]
    printf "CLASS_%s=%d\n", c, class_count[c]
  }
  for (i = 1; i <= ngroups; i++) {
    k = order[i]
    if (count[k] < threshold || lcount[k] == 0) continue
    printf "TRIAGE=%d|%d|%d|%s|%s|%s\n", count[k], lcount[k], gcount[k] + 0, k, first[k], last[k]
  }
}
' "$file")

rc=$?
if [[ $rc -eq 9 ]]; then
  # A18 refusal — awk already wrote the reason to stderr; surface the key and stop.
  printf '%s\n' "$out"
  exit 2
fi
if [[ $rc -ne 0 ]]; then
  echo "$SELF: internal error tallying $file (awk rc=$rc)" >&2
  exit 2
fi

printf '%s\n' "$out" | grep -v '^TRIAGE=' || true
printf '%s\n' "$out" | { grep '^TRIAGE=' || true; } | sed 's/^TRIAGE=//' \
  | sort -t'|' -k1,1nr -k4,4 | sed 's/^/TRIAGE=/'

exit 0
