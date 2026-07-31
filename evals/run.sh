#!/usr/bin/env bash
# evals/run.sh — the msg eval runner.
#
# A case is a directory `evals/cases/<slug>/`:
#   fixture/             input files, copied into a temp dir before the run
#   cmd                  one-line shell command, run with cwd = the temp copy
#   expected/exit        expected exit code (bare integer)
#   expected/stdout      optional golden stdout (exact match)
#   expected/files/<p>   optional golden files, diffed against <p> in the temp copy
#
# The command sees $REPO (absolute repo root) and TZ=UTC. Anything date-dependent
# must pin its own `--date` — no golden may contain today's date.
#
# Output: one PASS/FAIL line per case, then `EVALS <passed>/<total> passed`.
# Exit 0 iff every case passed.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO
CASES_DIR="$REPO/evals/cases"

only=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --only) only="${2-}"; shift 2 || { echo "usage: run.sh [--only <slug>]" >&2; exit 1; } ;;
    -h|--help) echo "usage: run.sh [--only <slug>]"; exit 0 ;;
    *) echo "run.sh: unknown argument: $1" >&2; exit 1 ;;
  esac
done

# First 5 lines of a diff, flattened onto one line so a FAIL stays one line.
trim_diff() {
  head -n 5 | tr '\n' '\036' | sed -e 's/\036/ ⏎ /g' -e 's/ ⏎ $//'
}

passed=0
total=0
failed=0

for case_dir in "$CASES_DIR"/*/; do
  [[ -d "$case_dir" ]] || continue
  case_dir="${case_dir%/}"
  slug="$(basename "$case_dir")"
  [[ -z "$only" || "$only" == "$slug" ]] || continue
  total=$((total + 1))

  reason=""
  if [[ ! -f "$case_dir/cmd" || ! -f "$case_dir/expected/exit" ]]; then
    reason="case is missing cmd or expected/exit"
  else
    work="$(mktemp -d)"
    [[ -d "$case_dir/fixture" ]] && cp -R "$case_dir/fixture/." "$work/" 2>/dev/null
    got_stdout="$(cd "$work" && TZ=UTC bash "$case_dir/cmd" 2>/dev/null)"
    got_exit=$?
    want_exit="$(tr -d '[:space:]' < "$case_dir/expected/exit")"

    if [[ "$got_exit" != "$want_exit" ]]; then
      reason="exit: expected $want_exit, got $got_exit"
    elif [[ -f "$case_dir/expected/stdout" ]] \
         && ! d="$(printf '%s\n' "$got_stdout" | diff -u "$case_dir/expected/stdout" - 2>&1)"; then
      reason="stdout: $(printf '%s\n' "$d" | tail -n +3 | trim_diff)"
    else
      while IFS= read -r golden; do
        [[ -n "$golden" ]] || continue
        rel="${golden#"$case_dir/expected/files/"}"
        if [[ ! -f "$work/$rel" ]]; then
          reason="files: $rel was not produced"
          break
        fi
        if ! d="$(diff -u "$golden" "$work/$rel" 2>&1)"; then
          reason="files: $rel — $(printf '%s\n' "$d" | tail -n +3 | trim_diff)"
          break
        fi
      done < <(find "$case_dir/expected/files" -type f 2>/dev/null | sort)
    fi
    rm -rf "$work"
  fi

  if [[ -z "$reason" ]]; then
    echo "PASS $slug"
    passed=$((passed + 1))
  else
    echo "FAIL $slug — $reason"
    failed=$((failed + 1))
    # E5: log the failure to the harness-incident ledger (doctor-logging.md,
    # Channel 1). Best-effort — absent ledger exits 3 and is skipped; a log
    # failure never changes the run's own outcome. Diagnosis stays deferred
    # to /msg --doctor; this row is the only analysis done at fail time.
    "$REPO/.claude/scripts/script-doctor-log.sh" "$REPO/devkit/DOCTOR.md" \
      --skill evals --signature "validator-fail:eval-$slug" \
      --context "$(head -c 120 "$case_dir/cmd" 2>/dev/null) — $reason" \
      >/dev/null 2>&1 || true
  fi
done

if [[ "$total" -eq 0 ]]; then
  echo "EVALS 0/0 passed — no cases matched${only:+ --only $only}" >&2
  exit 1
fi

echo "EVALS $passed/$total passed"
[[ "$failed" -eq 0 ]] || exit 1
exit 0
