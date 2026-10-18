#!/usr/bin/env bash
# script-premerge-last-check.sh — the durable record of pre-merge's last check per branch.
#
# pre-merge writes one record at the end of every gate run that reached a verdict:
# the commit it checked (the branch tip after sync + regression commits) AND the
# verdict, stored together. Two readers use it:
#   * the next pre-merge run's commit-cap audit (protocol-mechanical.md) — it audits
#     only commits new since the last checked commit, so an old oversize-commit
#     warning stops repeating;
#   * merge — it checks that pre-merge passed on the current branch tip. Either the
#     commit or the verdict missing ⇒ no pass.
#
# File: .pre-merge/last-check.json (gitignored, local state)
#   { "branches": { "<branch>": { "head", "verdict", "checked_at", "report", "run_dir" } } }
#
# Usage:
#   script-premerge-last-check.sh --write --branch <b> --head <sha> --verdict <v>
#                                 [--report <path>] [--run-dir <dir>] [--now <iso>]
#                                 [--file <path>]
#   script-premerge-last-check.sh --read --branch <b> [--file <path>]
#
# --write  records (replaces) the branch's entry. verdict ∈ pass|pass_with_warnings|
#          fail|skipped|refused. Prints RECORDED=<branch> HEAD=<sha> VERDICT=<v>.
# --read   prints the branch's entry as one JSON line; exit 3 when there is none.
#          A corrupt file reads as "no record" (exit 3) — never a pass.
#
# Exit: 0 ok · 1 usage · 3 no record for the branch.

set -uo pipefail

MODE=""; BRANCH=""; HEAD=""; VERDICT=""; REPORT=""; RUN_DIR=""; NOW=""
FILE=".pre-merge/last-check.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --write)   MODE=write; shift;;
    --read)    MODE=read; shift;;
    --branch)  BRANCH="${2-}"; shift 2;;
    --head)    HEAD="${2-}"; shift 2;;
    --verdict) VERDICT="${2-}"; shift 2;;
    --report)  REPORT="${2-}"; shift 2;;
    --run-dir) RUN_DIR="${2-}"; shift 2;;
    --now)     NOW="${2-}"; shift 2;;
    --file)    FILE="${2-}"; shift 2;;
    -h|--help) sed -n '2,27p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "unknown arg: $1" >&2; exit 1;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
[[ -n "$MODE" ]] || { echo "one of --write | --read is required" >&2; exit 1; }
[[ -n "$BRANCH" ]] || { echo "--branch is required" >&2; exit 1; }

current='{"branches":{}}'
if [[ -f "$FILE" ]] && jq -e '.branches | type == "object"' "$FILE" >/dev/null 2>&1; then
  current=$(jq -c '.' "$FILE")
fi

if [[ "$MODE" == read ]]; then
  entry=$(jq -c --arg b "$BRANCH" '.branches[$b] // empty' <<<"$current")
  if [[ -z "$entry" ]] || ! jq -e '(.head // "") != "" and (.verdict // "") != ""' <<<"$entry" >/dev/null; then
    echo "NO_RECORD branch=$BRANCH"
    exit 3
  fi
  echo "$entry"
  exit 0
fi

[[ -n "$HEAD" ]] || { echo "--head is required with --write" >&2; exit 1; }
case "$VERDICT" in
  pass|pass_with_warnings|fail|skipped|refused) ;;
  *) echo "--verdict must be pass|pass_with_warnings|fail|skipped|refused" >&2; exit 1;;
esac
[[ -n "$NOW" ]] || NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

mkdir -p "$(dirname "$FILE")"
tmp="$FILE.tmp.$$"
jq --arg b "$BRANCH" --arg h "$HEAD" --arg v "$VERDICT" --arg r "$REPORT" \
   --arg d "$RUN_DIR" --arg t "$NOW" '
  .branches[$b] = {
    head: $h, verdict: $v, checked_at: $t,
    report: (if $r == "" then null else $r end),
    run_dir: (if $d == "" then null else $d end)
  }' <<<"$current" > "$tmp" && mv "$tmp" "$FILE"

echo "RECORDED=$BRANCH HEAD=$HEAD VERDICT=$VERDICT"
