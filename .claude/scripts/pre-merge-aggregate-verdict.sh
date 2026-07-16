#!/usr/bin/env bash
# pre-merge-aggregate-verdict.sh — aggregate per-bucket pre-merge JSON outputs into
# the top-level result document (pre-merge/refs/output-schema.md).
#
# Pure mechanical: computes the overall verdict as max severity across all present
# buckets (fail > pass_with_warnings > pass), merges bucket payloads under
# .buckets, and validates each bucket has a recognised verdict. Refuses malformed
# input so a broken bucket fails loudly instead of silently downgrading the
# overall verdict.
#
# Usage:
#   pre-merge-aggregate-verdict.sh --run-dir <dir> \
#     [--prd <path>] [--eval-set <path>] [--parallel]
#
# <dir> contains <bucket>.json for each completed bucket. Recognised buckets:
#   unit, e2e, functional, qa, load, a11y, perf, api, mobile, coverage
# Skipped buckets are simply absent from the directory and omitted from output.
#
# Exit 0 on success; exit 1 with a stderr message on malformed input.

set -uo pipefail

BUCKETS=(unit e2e functional qa load a11y perf api mobile coverage)
RUN_DIR=""
PRD=""
EVAL_SET=""
PARALLEL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir)   RUN_DIR="$2"; shift 2;;
    --prd)       PRD="$2"; shift 2;;
    --eval-set)  EVAL_SET="$2"; shift 2;;
    --parallel)  PARALLEL=true; shift;;
    -h|--help)
      sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'
      exit 0;;
    *) echo "unknown arg: $1" >&2; exit 1;;
  esac
done

if [[ -z "$RUN_DIR" ]]; then
  echo "--run-dir <dir> is required" >&2
  exit 1
fi
if [[ ! -d "$RUN_DIR" ]]; then
  echo "run-dir not found: $RUN_DIR" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required (brew install jq)" >&2
  exit 1
fi

present_paths=()
present_names=()
verdicts=()

for b in "${BUCKETS[@]}"; do
  f="$RUN_DIR/$b.json"
  [[ -f "$f" ]] || continue
  if ! jq -e . "$f" >/dev/null 2>&1; then
    echo "malformed JSON: $f" >&2
    exit 1
  fi
  v=$(jq -r '.verdict // empty' "$f")
  case "$v" in
    pass|pass_with_warnings|fail) ;;
    "") echo "missing .verdict in $f" >&2; exit 1;;
    *)  echo "invalid .verdict '$v' in $f (expected pass|pass_with_warnings|fail)" >&2; exit 1;;
  esac
  present_paths+=("$f")
  present_names+=("$b")
  verdicts+=("$v")
done

if [[ ${#present_paths[@]} -eq 0 ]]; then
  echo "no bucket files found in $RUN_DIR (looking for {${BUCKETS[*]// /,}}.json)" >&2
  exit 1
fi

overall=pass
for v in "${verdicts[@]}"; do
  case "$v" in
    fail) overall=fail; break;;
    pass_with_warnings) [[ "$overall" == pass ]] && overall=pass_with_warnings;;
  esac
done

slurp_args=()
filter='{}'
for i in "${!present_names[@]}"; do
  slurp_args+=( --slurpfile "b${i}" "${present_paths[$i]}" )
  filter+=" | .[\"${present_names[$i]}\"] = \$b${i}[0]"
done
buckets_obj=$(jq -nc "${slurp_args[@]}" "$filter")

# HEAD sha at aggregation time — pre-merge's verdict-JSON freshness check compares
# this against its own HEAD to decide whether the run is reusable.
HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo "")

jq -n \
  --arg verdict "$overall" \
  --arg head "$HEAD_SHA" \
  --argjson parallel "$PARALLEL" \
  --arg prd "$PRD" \
  --arg eval_set_path "$EVAL_SET" \
  --argjson buckets "$buckets_obj" \
  '{
    verdict: $verdict,
    head: (if $head == "" then null else $head end),
    parallel: $parallel,
    prd: (if $prd == "" then null else $prd end),
    eval_set_path: (if $eval_set_path == "" then null else $eval_set_path end),
    buckets: $buckets
  }'
