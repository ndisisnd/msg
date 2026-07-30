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
# Exit codes:
#   0  tally reported (including "nothing at threshold")
#   2  usage error, or the file exists but has no `## Incidents` table
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
BEGIN { FS = "|" }
# Only the Incidents table counts. Header and separator rows fall out on their own:
# a row is an incident only if its first cell is a date.
/^##[[:space:]]+Incidents[[:space:]]*$/ { in_table = 1; next }
!in_table { next }
$0 !~ /^\|/ { next }
{
  d = trim($2)
  if (d !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) next
  skill = trim($3); sig = trim($4); status = trim($6)
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
if [[ $rc -ne 0 ]]; then
  echo "$SELF: internal error tallying $file (awk rc=$rc)" >&2
  exit 2
fi

printf '%s\n' "$out" | grep -v '^TRIAGE=' || true
printf '%s\n' "$out" | { grep '^TRIAGE=' || true; } | sed 's/^TRIAGE=//' \
  | sort -t'|' -k1,1nr -k4,4 | sed 's/^/TRIAGE=/'

exit 0
