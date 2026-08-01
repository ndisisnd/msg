#!/usr/bin/env bash
# script-em-timing.sh — coarse stage timestamps for a plan-em run.
#
# Every v5.4 saving is a structural estimate: fewer invocations, fewer certs,
# fewer reviewer spawns, less prose. None of them say where the wall-clock hour
# actually goes on a real run. This script is the measurement — one appended
# line per stage boundary, so a finished run leaves a readable timeline of what
# it spent its time on.
#
# It is deliberately dumb and deliberately best-effort. It appends a line and
# exits; it never reads a PRD, never decides anything, and a failed append must
# never change a protocol's control flow — call sites append `|| true`.
#
# Usage:
#   script-em-timing.sh --stage <name> --reports-dir <dir> [--run-id <id>]
#                       [--note <text>] [--date <iso8601>]
#   script-em-timing.sh --stage <name> --log <path> [...]
#
#   --stage        the boundary just crossed: lowercase, digits and hyphens
#                  (`pre-flight-done`, `cert-done`, `build-wave-2-done`, …).
#                  Anything else is a usage error — a stage name with a space
#                  or a capital breaks the column layout it is written into.
#   --reports-dir  the PRD's reports folder; the log is
#                  `<dir>/timings-<YYYY-MM-DD>.log`, created with its parents.
#   --log          an explicit log path, which wins over --reports-dir.
#   --run-id       the run this line belongs to (default `em`). Deltas are
#                  computed within a run id, so concurrent runs sharing a log
#                  do not corrupt each other's elapsed times.
#   --note         free text for the tail column (tabs and newlines stripped).
#   --date         pin "now" to an ISO-8601 instant, for tests.
#
# Line format (tab-separated, append-only, never rewritten):
#   <iso>  <epoch>  <run-id>  <stage>  +<delta>s  <note>
#
# `<delta>` is seconds since this run id's previous line, so reading the log
# top to bottom answers "which stage ate the run?" without any arithmetic.
#
# Exit codes:
#   0  line appended
#   2  usage error (no stage, no log target, malformed stage, unknown flag)
#   1  the append itself failed (unwritable path) — reported, never fatal to
#      the caller, which is expected to ignore it.

set -uo pipefail

usage() {
  echo "usage: script-em-timing.sh --stage <name> (--reports-dir <dir> | --log <path>) [--run-id <id>] [--note <text>] [--date <iso>]" >&2
  exit 2
}

stage=""
reports_dir=""
log_path=""
run_id="em"
note=""
date_override=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stage) stage="${2-}"; shift 2 || usage ;;
    --reports-dir) reports_dir="${2-}"; shift 2 || usage ;;
    --log) log_path="${2-}"; shift 2 || usage ;;
    --run-id) run_id="${2-}"; shift 2 || usage ;;
    --note) note="${2-}"; shift 2 || usage ;;
    --date) date_override="${2-}"; shift 2 || usage ;;
    -h|--help) echo "usage: script-em-timing.sh --stage <name> (--reports-dir <dir> | --log <path>) [--run-id <id>] [--note <text>] [--date <iso>]"; exit 0 ;;
    *) echo "script-em-timing: unknown argument: $1" >&2; usage ;;
  esac
done

[[ -n "$stage" ]] || usage
[[ -n "$reports_dir" || -n "$log_path" ]] || usage
command -v python3 >/dev/null 2>&1 || {
  echo "script-em-timing: python3 not available" >&2; exit 2; }

# A stage name is a column value, not prose. Reject anything that would break
# the layout rather than writing a line that cannot be read back.
case "$stage" in
  *[!a-z0-9-]*) echo "script-em-timing: stage '$stage' must be lowercase letters, digits and hyphens" >&2; exit 2 ;;
esac
[[ "$stage" == [a-z0-9]* ]] || {
  echo "script-em-timing: stage '$stage' must start with a letter or digit" >&2; exit 2; }
[[ -n "$run_id" ]] || { echo "script-em-timing: --run-id may not be empty" >&2; exit 2; }

python3 - "$stage" "$reports_dir" "$log_path" "$run_id" "$note" "$date_override" <<'PY'
import datetime, os, re, sys

stage, reports_dir, log_path, run_id, note, date_override = sys.argv[1:7]

# "Now" is pinnable so a test can assert on a golden file.
if date_override.strip():
    text = date_override.strip().replace("Z", "+00:00")
    try:
        now = datetime.datetime.fromisoformat(text)
    except ValueError:
        print("script-em-timing: --date '%s' is not ISO-8601" % date_override, file=sys.stderr)
        sys.exit(2)
    if now.tzinfo is None:
        now = now.replace(tzinfo=datetime.timezone.utc)
else:
    now = datetime.datetime.now(datetime.timezone.utc)
now = now.astimezone(datetime.timezone.utc)
iso = now.strftime("%Y-%m-%dT%H:%M:%SZ")
epoch = int(now.timestamp())

path = log_path.strip() or os.path.join(reports_dir, "timings-%s.log" % now.strftime("%Y-%m-%d"))

# Elapsed is measured against this run id's own previous line, so two runs
# sharing one log file never report each other's gaps as their own.
previous = None
try:
    with open(path) as fh:
        for line in fh:
            cols = line.rstrip("\n").split("\t")
            if len(cols) >= 4 and cols[2] == run_id:
                try:
                    previous = int(cols[1])
                except ValueError:
                    continue
except OSError:
    pass

delta = 0 if previous is None else max(0, epoch - previous)
clean_note = re.sub(r"[\t\r\n]+", " ", note).strip()
row = "%s\t%d\t%s\t%s\t+%ds\t%s\n" % (iso, epoch, run_id, stage, delta, clean_note)

try:
    parent = os.path.dirname(path)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(path, "a") as fh:
        fh.write(row)
except OSError as exc:
    print("script-em-timing: could not append to '%s': %s" % (path, exc), file=sys.stderr)
    sys.exit(1)
PY
