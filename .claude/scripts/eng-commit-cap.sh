#!/usr/bin/env bash
# eng-commit-cap.sh — A5 commit-size measurement for the eng build commit gate.
#
# Checks the STAGED diff and reports whether it changes too many lines, so the
# agent can judge split-or-commit against a measured number rather than a
# guess. Changed LOC = additions + deletions from `git diff --cached
# --numstat`, excluding lockfiles and generated files (allowlist below).
#
# This script never blocks — the commit-time LOC count is a measured fact,
# not a plan-time estimate, so the agent reads it and decides. Always exits 0
# on a completed measurement; only a usage/environment error exits non-zero.
#
# Usage:
#   eng-commit-cap.sh                         cap = 500 changed LOC
#   eng-commit-cap.sh --breaking              cap = 300 (commit carries a breaking change)
#   eng-commit-cap.sh --oversize-reason "<t>" always exit 0; also prints an OVERSIZE
#                                             line to log to the PRD ledger
#
# Machine output (always one CAP_ line):
#   CAP_OK <loc>/<cap>          under cap, exit 0
#   CAP_EXCEEDED <loc>/<cap>    over cap — exit 0; the agent decides split-or-commit
#   OVERSIZE <loc> reason: <t>  printed only when --oversize-reason is supplied over-cap
#
# Exit: 0 = measurement completed (under cap, over cap, or reason-justified),
#       2 = usage/environment error.

set -uo pipefail

CAP=500
BREAKING=0
REASON=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --breaking) BREAKING=1; CAP=300; shift ;;
    --oversize-reason) REASON="${2:-}"; shift 2 ;;
    --oversize-reason=*) REASON="${1#*=}"; shift ;;
    *) echo "eng-commit-cap: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

command -v git >/dev/null 2>&1 || { echo "eng-commit-cap: git not available" >&2; exit 2; }

loc=0
while IFS=$'\t' read -r add del path; do
  [[ -n "$path" ]] || continue
  [[ "$add" == "-" ]] && continue   # binary file — numstat shows '-'
  case "$path" in
    package-lock.json|*/package-lock.json|\
    yarn.lock|*/yarn.lock|\
    pnpm-lock.yaml|*/pnpm-lock.yaml|\
    Cargo.lock|*/Cargo.lock|\
    Podfile.lock|*/Podfile.lock|\
    Gemfile.lock|*/Gemfile.lock|\
    go.sum|*/go.sum) continue ;;
    *.min.js|*.min.css|*.map|*.g.dart|*.freezed.dart|*.pb.go) continue ;;
    dist/*|*/dist/*|build/*|*/build/*|node_modules/*|*/node_modules/*|vendor/*|*/vendor/*|*/generated/*|*/__generated__/*) continue ;;
  esac
  loc=$((loc + add + del))
done < <(git diff --cached --numstat)

if (( loc > CAP )); then
  echo "CAP_EXCEEDED ${loc}/${CAP}"
  if [[ -n "$REASON" ]]; then
    echo "OVERSIZE ${loc} reason: ${REASON}"
  fi
  exit 0
fi

echo "CAP_OK ${loc}/${CAP}"
exit 0
