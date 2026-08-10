#!/usr/bin/env bash
# script-aggregate-verdict.sh — aggregate the per-component result reports in
# .pre-merge/<ts>/ into the run's verdict document (pre-merge/refs/output-schema.md).
#
# Input is the v3 **result report** family (one <check>.json per component that ran,
# every run — pre-merge/refs/executor.md §4, shared/refs/check-report-schema.md):
#
#   { "check", "group", "verdict", "runner", "ran_at", "totals", "findings"[],
#     "log_path", "skip_reason" }
#
# The script owns everything mechanical in executor.md §5 — nothing here is a
# judgment call:
#
#   1. collect   every report's findings[] plus the plan's resolved coverage-gap
#                findings (--plan), nulls filtered
#   2. dedup     by (category, file, line, rule) — highest severity wins, the
#                distinct `source` values comma-joined (the wire contract in
#                shared/refs/finding-schema.md; /msg --gui splits on "," and shows
#                the first, so the separator is load-bearing)
#   3. downgrade the two path-pattern rules from severity-rubric.md that are
#                decidable from paths alone: §2 dev-only scope and §4 out-of-diff.
#                Reachability (§3) and in-context grading stay with the model.
#   4. verdict   blocker|high → fail · medium|low → pass_with_warnings · none → pass
#                plus the critical-abort signal when a `critical` component failed
#   5. counts    per-severity summary + the checks[] roll-up
#
# It refuses malformed input so a broken component fails loudly instead of silently
# downgrading the verdict. Components that did not run are simply absent from the
# directory — the *completeness* question ("did every planned component report?")
# belongs to `script-pipeline-resolve.py --check-complete`, not here.
#
# Usage:
#   script-aggregate-verdict.sh --run-dir <dir>
#     [--plan <plan.json>] [--diff <resolve-diff.json>]
#     [--prd <path>] [--eval-set <path>] [--parallel]
#
#   --run-dir    .pre-merge/<ts>/ — the result reports (required)
#   --plan       script-pipeline-resolve.py output; supplies each component's
#                criticality so a critical failure reports as a pipeline abort
#   --diff       script-resolve-diff.sh output; supplies files_changed for the out-of-diff
#                downgrade. Absent ⇒ that downgrade is skipped (fail open: no
#                finding is ever weakened on a guess)
#   --prd        PRD path, echoed into the document
#   --eval-set   eval-set path, echoed into the document
#   --parallel   records that the waves ran concurrently
#
# Exit 0 on success; 1 on malformed input or usage error.

set -uo pipefail

RUN_DIR=""; PLAN=""; DIFF=""; PRD=""; EVAL_SET=""; PARALLEL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-dir)   RUN_DIR="$2"; shift 2;;
    --plan)      PLAN="$2"; shift 2;;
    --diff)      DIFF="$2"; shift 2;;
    --prd)       PRD="$2"; shift 2;;
    --eval-set)  EVAL_SET="$2"; shift 2;;
    --parallel)  PARALLEL=true; shift;;
    -h|--help)
      sed -n '2,48p' "$0" | sed 's/^# \{0,1\}//'
      exit 0;;
    *) echo "unknown arg: $1" >&2; exit 1;;
  esac
done

[[ -n "$RUN_DIR" ]] || { echo "--run-dir <dir> is required" >&2; exit 1; }
[[ -d "$RUN_DIR" ]] || { echo "run-dir not found: $RUN_DIR" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required (brew install jq)" >&2; exit 1; }

# ── collect + validate the result reports ────────────────────────────────────
reports=()
while IFS= read -r f; do reports+=("$f"); done < <(find "$RUN_DIR" -maxdepth 1 -name '*.json' | sort)

if [[ ${#reports[@]} -eq 0 ]]; then
  echo "no result reports in $RUN_DIR (expected <check>.json per component)" >&2
  exit 1
fi

for f in "${reports[@]}"; do
  if ! jq -e . "$f" >/dev/null 2>&1; then
    echo "malformed JSON: $f" >&2; exit 1
  fi
  chk=$(jq -r '.check // empty' "$f")
  if [[ -z "$chk" ]]; then
    echo "missing .check in $f" >&2; exit 1
  fi
  v=$(jq -r '.verdict // empty' "$f")
  case "$v" in
    pass|pass_with_warnings|fail|skipped) ;;
    "") echo "missing .verdict in $f" >&2; exit 1;;
    *)  echo "invalid .verdict '$v' in $f (expected pass|pass_with_warnings|fail|skipped)" >&2; exit 1;;
  esac
done

reports_json=$(jq -s '.' "${reports[@]}")

# ── inputs the downgrades and the abort signal need ──────────────────────────
files_changed='null'
if [[ -n "$DIFF" && -f "$DIFF" ]]; then
  files_changed=$(jq -c 'if .error then null else (.files_changed // null) end' "$DIFF")
fi

criticality_map='{}'
gap_findings='[]'
if [[ -n "$PLAN" && -f "$PLAN" ]]; then
  criticality_map=$(jq -c '[.waves[].components[] | {key: .id, value: .criticality}] | from_entries' "$PLAN")
  # The C12 coverage-gap findings the plan already resolved (executor.md §1b) join
  # the pool here rather than being re-derived — they are repo-level (file: null),
  # so the path-pattern downgrades never touch them.
  gap_findings=$(jq -c '.gap_findings // []' "$PLAN")
fi

HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo "")

# ── aggregate ────────────────────────────────────────────────────────────────
jq -n \
  --argjson reports "$reports_json" \
  --argjson files_changed "$files_changed" \
  --argjson crit "$criticality_map" \
  --argjson gap_findings "$gap_findings" \
  --argjson parallel "$PARALLEL" \
  --arg head "$HEAD_SHA" \
  --arg prd "$PRD" \
  --arg eval_set_path "$EVAL_SET" '

def rank: {"low":0, "medium":1, "high":2, "blocker":3}[.] // 0;
def unrank: ["low","medium","high","blocker"][.];

# severity-rubric.md §2 — dev-only scope
def dev_only($f):
  $f != null and ($f | test(
    "(\\.test\\.|\\.spec\\.|/__tests__/|^tests?/|/tests?/|^e2e/|/e2e/|/integration/|\\.stories\\.|\\.mock\\.|\\.fixture\\.)"));

# The rubric exceptions: a secret hit, a build failure, and the repo-level
# safety-floor / coverage-gap findings hold their raw severity.
def exempt:
  (.rule // "") as $r
  | ($r | test("secret|gitleaks|trufflehog|platform-coverage-gap|safety-floor"))
    or ((.category // "") == "build")
    or ((.file // null) == null);

def downgrade:
  if exempt then .
  else
    (.severity // "low") as $s
    | if dev_only(.file // null) then .severity = ([($s|rank) - 1, 0] | max | unrank)
      elif ($files_changed != null and (.file // null) != null
            and ((.file) as $f | $files_changed | index($f)) == null)
      then .severity = "low"
      else . end
  end;

(($reports | map(select(.findings != null) | .findings[]? | select(. != null)))
   + $gap_findings)
  | map(downgrade)
  # dedup by (category, file, line, rule) — highest severity wins
  | group_by([(.category // ""), (.file // ""), (.line // -1), (.rule // "")])
  | map(
      (max_by(.severity | rank)) as $top
      | $top + { source: (map(.source // "") | map(select(. != "")) | unique | join(",")) }
    )
  | sort_by([-(.severity | rank), (.category // ""), (.file // ""), (.line // 0)])
  as $issues

| ($reports | map({check, group, verdict, totals, runner, log_path, skip_reason}))
  as $checks

| ($reports
   | map(select(.verdict == "fail")
         | .check as $c | select(($crit[$c] // "") == "critical") | $c))
  as $critical_failed

| {
    verdict:
      (if ($issues | map(select(.severity == "blocker" or .severity == "high")) | length) > 0
       then "fail"
       elif ($issues | length) > 0 then "pass_with_warnings"
       else "pass" end),
    aborted: (if $crit == {} then null else ($critical_failed | length) > 0 end),
    aborted_by: (if ($critical_failed | length) > 0 then $critical_failed else null end),
    head: (if $head == "" then null else $head end),
    parallel: $parallel,
    prd: (if $prd == "" then null else $prd end),
    eval_set_path: (if $eval_set_path == "" then null else $eval_set_path end),
    summary: {
      blocker: ($issues | map(select(.severity == "blocker")) | length),
      high:    ($issues | map(select(.severity == "high"))    | length),
      medium:  ($issues | map(select(.severity == "medium"))  | length),
      low:     ($issues | map(select(.severity == "low"))     | length)
    },
    totals: {
      passed:  ($reports | map(.totals.passed  // 0) | add // 0),
      failed:  ($reports | map(.totals.failed  // 0) | add // 0),
      skipped: ($reports | map(.totals.skipped // 0) | add // 0),
      flaky:   ($reports | map(.totals.flaky   // 0) | add // 0)
    },
    checks: $checks,
    skipped: ($reports | map(select(.verdict == "skipped")
                             | {bucket: .check, reason: (.skip_reason // "unknown")})),
    issues: $issues
  }
'
