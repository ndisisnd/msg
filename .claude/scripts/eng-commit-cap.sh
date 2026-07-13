#!/usr/bin/env bash
# eng-commit-cap.sh — A5 small-commit cap for the eng build commit gate.
#
# Checks the STAGED diff and blocks a commit that changes too many lines, so
# each commit stays a small, reviewable, ticket-sized unit. Changed LOC =
# additions + deletions from `git diff --cached --numstat`, excluding
# lockfiles and generated files (allowlist below).
#
# Usage:
#   eng-commit-cap.sh                         cap = 500 changed LOC
#   eng-commit-cap.sh --breaking              cap = 300 (commit carries a breaking change)
#   eng-commit-cap.sh --oversize-reason "<t>" escape hatch: exit 0 even over-cap,
#                                             printing an OVERSIZE line to log to the PRD ledger
#
# Machine output (always one CAP_ line):
#   CAP_OK <loc>/<cap>          under cap, exit 0
#   CAP_EXCEEDED <loc>/<cap>    over cap  (exit 1, or exit 0 with a reason)
#   OVERSIZE <loc> reason: <t>  printed only when --oversize-reason is supplied over-cap
#
# Exit: 0 = under cap or reason-justified, 1 = over cap and unjustified,
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
    exit 0
  fi
  exit 1
fi

echo "CAP_OK ${loc}/${CAP}"
exit 0
