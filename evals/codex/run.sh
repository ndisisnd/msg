#!/usr/bin/env bash
# evals/codex/run.sh — the Codex compatibility eval runner.
#
# It runs the eval cases named by the per-skill compatibility maps and reports
# what they actually prove. A case is a directory `evals/codex/cases/<eval-id>/`:
#
#   about                metadata (see below) — required
#   fixture/             input files, copied into a temp dir before the run
#   cmd                  one-line-or-more shell command, cwd = the temp copy
#   expected/exit        expected exit code (bare integer)
#   expected/stdout      optional golden stdout (exact match)
#   expected/files/<p>   optional golden files, diffed against <p> in the temp copy
#
# `about` is `key: value` lines:
#
#   layer:      0 | 2 | 3 | 4     which eval layer of plan §8 this case executes
#   assertions: MSG-CX-001, ...   the map assertions this case carries evidence for
#   proves:     one line          what the deterministic run establishes
#   residual:   one line          what this case CANNOT establish without a live
#                                 Codex model session; omitted when nothing is left
#
# The residual field is the honesty mechanism. A layer 0/2/4 case runs offline and
# proves packaging, deterministic-helper and artifact parity for real. It does not
# prove that a model driving the adapter behaves identically — that is layer 3,
# which needs a live Codex session and is opt-in (`--layer3`, or MSG_CODEX_LAYER3=1).
# Nothing here reports runtime proof coverage as anything but `not-run` until the
# layer 3 suite has actually run.
#
# The command sees $REPO (absolute repo root), $LIB (evals/codex/lib) and TZ=UTC.
#
# Usage: run.sh [--only <eval-id>] [--layer <n>] [--layer3]
# Exit 0 iff every runnable case passed.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO
LIB="$REPO/evals/codex/lib"
export LIB
CASES_DIR="$REPO/evals/codex/cases"

only=""
layer_filter=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --only) only="${2-}"; shift 2 || exit 1 ;;
    --layer) layer_filter="${2-}"; shift 2 || exit 1 ;;
    --layer3) export MSG_CODEX_LAYER3=1; shift ;;
    -h|--help) echo "usage: run.sh [--only <eval-id>] [--layer <n>] [--layer3]"; exit 0 ;;
    *) echo "run.sh: unknown argument: $1" >&2; exit 1 ;;
  esac
done

about_value() { sed -n "s/^$2:[[:space:]]*//p" "$1" | head -n 1; }

trim_diff() { head -n 5 | tr '\n' '\036' | sed -e 's/\036/ ⏎ /g' -e 's/ ⏎ $//'; }

passed=0; failed=0; pending=0; total=0
residuals=0
assertion_list=""

for case_dir in "$CASES_DIR"/*/; do
  [[ -d "$case_dir" ]] || continue
  case_dir="${case_dir%/}"
  slug="$(basename "$case_dir")"
  [[ -z "$only" || "$only" == "$slug" ]] || continue

  if [[ ! -f "$case_dir/about" || ! -f "$case_dir/cmd" || ! -f "$case_dir/expected/exit" ]]; then
    echo "FAIL $slug — case is missing about, cmd or expected/exit"
    failed=$((failed + 1)); total=$((total + 1)); continue
  fi

  layer="$(about_value "$case_dir/about" layer)"
  assertions="$(about_value "$case_dir/about" assertions)"
  residual="$(about_value "$case_dir/about" residual)"
  [[ -z "$layer_filter" || "$layer_filter" == "$layer" ]] || continue
  total=$((total + 1))
  assertion_list+="${assertions//,/ } "
  [[ -n "$residual" ]] && residuals=$((residuals + 1))

  if [[ "$layer" == "3" && "${MSG_CODEX_LAYER3:-0}" != "1" ]]; then
    echo "PEND $slug — layer 3 needs a live Codex session (run with --layer3)"
    pending=$((pending + 1)); continue
  fi

  reason=""
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
      if [[ ! -f "$work/$rel" ]]; then reason="files: $rel was not produced"; break; fi
      if ! d="$(diff -u "$golden" "$work/$rel" 2>&1)"; then
        reason="files: $rel — $(printf '%s\n' "$d" | tail -n +3 | trim_diff)"; break
      fi
    done < <(find "$case_dir/expected/files" -type f 2>/dev/null | sort)
  fi
  rm -rf "$work"

  if [[ -z "$reason" ]]; then
    echo "PASS $slug (layer $layer)"
    passed=$((passed + 1))
  else
    echo "FAIL $slug — $reason"
    failed=$((failed + 1))
  fi
done

if [[ "$total" -eq 0 ]]; then
  echo "CODEX_EVALS 0/0 — no cases matched" >&2
  exit 1
fi

covered="$(printf '%s\n' $assertion_list | sed '/^$/d' | sort -u | wc -l | tr -d ' ')"
runnable=$((total - pending))
echo "CODEX_EVALS $passed/$runnable passed · pending=$pending · cases=$total"
echo "ASSERTIONS_TOUCHED $covered"
echo "RESIDUAL_MODEL_MEDIATED $residuals cases carry a declared layer-3 residual"
if [[ "${MSG_CODEX_LAYER3:-0}" == "1" ]]; then
  echo "RUNTIME_PROOF partial — layer 3 ran; see per-case results"
else
  echo "RUNTIME_PROOF not-run — layer 3 (live Codex behaviour) was not executed"
fi
[[ "$failed" -eq 0 ]] || exit 1
exit 0
