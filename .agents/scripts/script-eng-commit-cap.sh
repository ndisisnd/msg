#!/usr/bin/env bash
# script-eng-commit-cap.sh — A5 commit-size measurement for the eng build commit gate.
#
# Checks the STAGED diff and reports whether it changes too many lines, so the
# agent can judge split-or-commit against a measured number rather than a
# guess. Changed LOC = additions + deletions from `git diff --cached
# --numstat`, excluding lockfiles and generated files (allowlist below).
#
# The SIZE measurement never blocks — the commit-time LOC count is a measured
# fact, not a plan-time estimate, so the agent reads it and decides
# split-or-commit. An UNDER-cap commit is never blocked, ever.
#
# The one thing this script does enforce is the trailer pairing. The protocol
# says an over-cap commit MUST carry an `Oversize-reason:` trailer, and that
# rule used to be prose only — a model that forgot it produced a clean-looking
# over-cap commit with no recorded justification and no §12 ledger entry
# (fail-silent). When the prepared commit message is supplied via --message /
# --message-file and the staged diff is over cap, the trailer's presence is now
# checked mechanically and its absence fails loud (exit 3). The judgment call
# stays with the agent; only the justification's presence is mechanical.
#
# Usage:
#   script-eng-commit-cap.sh                         cap = 500 changed LOC
#   script-eng-commit-cap.sh --breaking              cap = 300 (commit carries a breaking change)
#   script-eng-commit-cap.sh --oversize-reason "<t>" also prints an OVERSIZE line to log
#                                             to the PRD ledger
#   script-eng-commit-cap.sh --message "<text>"      pair the cap with the prepared commit
#   script-eng-commit-cap.sh --message-file <path>   message (`-` = stdin); over cap without
#                                             an `Oversize-reason:` trailer exits 3
#
# Machine output (always one CAP_ line):
#   CAP_OK <loc>/<cap>            under cap, exit 0
#   CAP_EXCEEDED <loc>/<cap>      over cap — the agent decides split-or-commit
#   OVERSIZE <loc> reason: <t>    printed only when --oversize-reason is supplied over-cap
#   TRAILER_OK                    over cap and the message carries `Oversize-reason: <t>`
#   TRAILER_MISSING               over cap and it does not — exit 3
#   TRAILER_UNCHECKED             over cap and no message was supplied to check
#
# Exit: 0 = measurement completed (under cap, or over cap with the trailer
#           present / no message supplied to check),
#       2 = usage/environment error,
#       3 = over cap and the prepared commit message carries no
#           `Oversize-reason:` trailer.

set -uo pipefail

CAP=500
BREAKING=0
REASON=""
MESSAGE=""
HAVE_MESSAGE=0

read_message_file() {
  if [[ "$1" == "-" ]]; then
    MESSAGE="$(cat)"
  else
    [[ -f "$1" ]] || { echo "script-eng-commit-cap: no such message file '$1'" >&2; exit 2; }
    MESSAGE="$(cat "$1")"
  fi
  HAVE_MESSAGE=1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --breaking) BREAKING=1; CAP=300; shift ;;
    --oversize-reason) REASON="${2:-}"; shift 2 ;;
    --oversize-reason=*) REASON="${1#*=}"; shift ;;
    --message) MESSAGE="${2:-}"; HAVE_MESSAGE=1; shift 2 ;;
    --message=*) MESSAGE="${1#*=}"; HAVE_MESSAGE=1; shift ;;
    --message-file) read_message_file "${2:-}"; shift 2 ;;
    --message-file=*) read_message_file "${1#*=}"; shift ;;
    *) echo "script-eng-commit-cap: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

command -v git >/dev/null 2>&1 || { echo "script-eng-commit-cap: git not available" >&2; exit 2; }

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
  # Trailer pairing — the one enforcement. A trailer is a body line of the form
  # `Oversize-reason: <non-empty text>`; leading whitespace and CR are tolerated.
  if (( HAVE_MESSAGE )); then
    if printf '%s\n' "$MESSAGE" | grep -Eq '^[[:space:]]*Oversize-reason:[[:space:]]*[^[:space:]]'; then
      echo "TRAILER_OK"
      exit 0
    fi
    echo "TRAILER_MISSING"
    echo "script-eng-commit-cap: commit changes ${loc} LOC (cap ${CAP}) but the prepared" >&2
    echo "  message carries no 'Oversize-reason: <text>' trailer. Split the commit," >&2
    echo "  or add the trailer recording why it ships over cap." >&2
    exit 3
  fi
  echo "TRAILER_UNCHECKED"
  exit 0
fi

echo "CAP_OK ${loc}/${CAP}"
exit 0
