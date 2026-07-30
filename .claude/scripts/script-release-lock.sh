#!/usr/bin/env bash
# script-release-lock.sh — the production release lock: acquire | release | status.
#
# A production ship is the one path that mutates prod. Two --production runs in
# flight at once race on that branch: both open a release PR, both merge, both
# deploy. This script serializes them, and it is the ONLY implementation of the
# lock — the ~1,100 words of mechanism prose it replaces are gone.
#
# Mechanism: an annotated git tag `release-lock-<prod>` pushed to the remote.
# A tag ref is never fast-forwarded, so pushing a name the remote already holds
# is REJECTED — that rejection is the compare-and-swap-to-absent. Storage is
# the remote, so the lock survives across machines. A tag is metadata on a
# commit: no tracked file changes, so post-merge's safety floor holds.
#
# Silent when uncontended: an uncontended acquire + release asks nothing and
# gates nothing. Friction appears only on a real collision.
#
# Contract: .claude/skills/post-merge/refs/production.md § Release lock
#
# Usage:
#   script-release-lock.sh acquire [--prod <branch>] [--remote <name>]
#                                  [--prds <a,b>] [--ttl <seconds>] [--repo <dir>]
#   script-release-lock.sh release [--prod <branch>] [--remote <name>] [--repo <dir>]
#   script-release-lock.sh status  [--prod <branch>] [--remote <name>]
#                                  [--ttl <seconds>] [--repo <dir>]
#
#   --prod    production branch the lock is scoped to (default: main)
#   --remote  git remote holding the lock (default: origin)
#   --prds    comma list of PRD ids this ship carries — holder metadata only
#   --ttl     staleness bound in seconds (default: 7200 = 2h)
#   --repo    repo dir (default: $PWD)
#
# `status` is read-only. `acquire`/`release` push and delete exactly one tag
# ref and nothing else.
#
# Output (stdout, KEY=VALUE lines, always the full key set):
#   LOCK_REF=release-lock-<prod>
#   LOCK_STATUS=acquired|held|released|absent|free|error
#   ACQUIRED=true|false        did THIS invocation acquire it
#   ACQUIRED_AT=<iso8601>      tagger date of the holding tag ("" when none)
#   RELEASED=true|false        did THIS invocation release it
#   RELEASED_AT=<iso8601>
#   HELD_BY=<name <email>>     holder read off the tag message
#   SHA=<sha>                  prod sha the holder locked at
#   PRDS=<a,b>                 PRDs the holder declared
#   AGE_SECONDS=<n>            age of the holding tag ("" when none)
#   STALE=true|false           AGE_SECONDS > ttl
#   UNLOCK_CMD=<cmd>           the manual unlock one-liner, emitted ONLY when
#                              STALE=true — the single place that text lives
#   ERROR=<short reason>       set on LOCK_STATUS=error
#
# Exit codes (identical across subcommands):
#   0  clean — acquired / released / absent (release is idempotent) / free
#   3  the lock is HELD by someone else and is NOT stale → refuse release_in_flight
#   5  the lock is HELD and STALE (> ttl) → terminal refusal + UNLOCK_CMD
#   4  infra/network error, NOT contention → FAIL-OPEN: the caller records one
#      `low` note and proceeds without the guard. The lock is a safety assist,
#      not a floor; a flaky network must never dead-end a legit solo ship.
#   2  usage error / not a git repo
#
# A hard process kill between acquire and release is the one path no graceful
# release can reach — the TTL + UNLOCK_CMD cover it, honestly rather than
# pretended away.

set -uo pipefail

SELF="$(basename "$0")"

usage() {
  echo "usage: $SELF acquire|release|status [--prod <branch>] [--remote <name>] [--prds <a,b>] [--ttl <secs>] [--repo <dir>]" >&2
  exit 2
}

die() { echo "$SELF: $1" >&2; exit 2; }

CMD="${1:-}"; shift || true
case "$CMD" in
  acquire|release|status) ;;
  -h|--help) sed -n '2,70p' "$0"; exit 0 ;;
  *) usage ;;
esac

REPO="$PWD"; PROD="main"; REMOTE="origin"; PRDS_IN=""; TTL=7200

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prod)     [[ $# -ge 2 ]] || usage; PROD="$2"; shift 2 ;;
    --prod=*)   PROD="${1#--prod=}"; shift ;;
    --remote)   [[ $# -ge 2 ]] || usage; REMOTE="$2"; shift 2 ;;
    --remote=*) REMOTE="${1#--remote=}"; shift ;;
    --prds)     [[ $# -ge 2 ]] || usage; PRDS_IN="$2"; shift 2 ;;
    --prds=*)   PRDS_IN="${1#--prds=}"; shift ;;
    --ttl)      [[ $# -ge 2 ]] || usage; TTL="$2"; shift 2 ;;
    --ttl=*)    TTL="${1#--ttl=}"; shift ;;
    --repo)     [[ $# -ge 2 ]] || usage; REPO="$2"; shift 2 ;;
    --repo=*)   REPO="${1#--repo=}"; shift ;;
    *) usage ;;
  esac
done

[[ -d "$REPO" ]] || die "not a directory: $REPO"
git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not a git repository: $REPO"

LOCK="release-lock-$PROD"
LOCK_STATUS=""; ACQUIRED=false; ACQUIRED_AT=""; RELEASED=false; RELEASED_AT=""
HELD_BY=""; SHA=""; PRDS=""; AGE_SECONDS=""; STALE=false; UNLOCK_CMD=""; ERROR=""

g() { git -C "$REPO" "$@"; }
now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }

emit() {
  cat <<EOF
LOCK_REF=$LOCK
LOCK_STATUS=$LOCK_STATUS
ACQUIRED=$ACQUIRED
ACQUIRED_AT=$ACQUIRED_AT
RELEASED=$RELEASED
RELEASED_AT=$RELEASED_AT
HELD_BY=$HELD_BY
SHA=$SHA
PRDS=$PRDS
AGE_SECONDS=$AGE_SECONDS
STALE=$STALE
UNLOCK_CMD=$UNLOCK_CMD
ERROR=$ERROR
EOF
}

# Read the remote's copy of the lock tag into local refs. Returns 1 when absent.
fetch_lock() {
  g fetch "$REMOTE" "+refs/tags/$LOCK:refs/tags/$LOCK" --quiet 2>/dev/null || true
  g rev-parse -q --verify "refs/tags/$LOCK" >/dev/null 2>&1
}

# Populate holder metadata from the local copy of the lock tag.
read_holder() {
  local body ts
  body="$(g for-each-ref --format='%(contents)' "refs/tags/$LOCK" 2>/dev/null)"
  HELD_BY="$(printf '%s\n' "$body" | sed -n 's/^held-by: //p' | head -1)"
  SHA="$(printf '%s\n' "$body" | sed -n 's/^sha: //p' | head -1)"
  PRDS="$(printf '%s\n' "$body" | sed -n 's/^prds: //p' | head -1)"
  ACQUIRED_AT="$(printf '%s\n' "$body" | sed -n 's/^at: //p' | head -1)"
  ts="$(g for-each-ref --format='%(taggerdate:unix)' "refs/tags/$LOCK" 2>/dev/null)"
  [[ -n "$ts" ]] || ts="$(g log -1 --format=%ct "refs/tags/$LOCK" 2>/dev/null)"
  if [[ -n "$ts" ]]; then
    AGE_SECONDS=$(( $(date +%s) - ts ))
    if [[ "$AGE_SECONDS" -gt "$TTL" ]]; then
      STALE=true
      UNLOCK_CMD="git push $REMOTE :refs/tags/$LOCK && git tag -d $LOCK"
    fi
  fi
}

held_exit() {
  LOCK_STATUS=held
  read_holder
  emit
  [[ "$STALE" == true ]] && exit 5
  exit 3
}

case "$CMD" in

  status)
    if fetch_lock; then held_exit; fi
    LOCK_STATUS=free; emit; exit 0
    ;;

  acquire)
    g fetch "$REMOTE" "$PROD" --quiet 2>/dev/null || true
    AT_SHA="$(g rev-parse --verify --quiet "$REMOTE/$PROD^{commit}" 2>/dev/null || g rev-parse --verify --quiet HEAD)"
    [[ -n "$AT_SHA" ]] || { LOCK_STATUS=error; ERROR="cannot resolve $REMOTE/$PROD"; emit; exit 4; }
    AT="$(now_iso)"
    g tag -d "$LOCK" >/dev/null 2>&1 || true
    g tag -a "$LOCK" "$AT_SHA" -m "held-by: $(g config user.name 2>/dev/null) <$(g config user.email 2>/dev/null)>
mode: production
at: $AT
sha: $AT_SHA
prds: $PRDS_IN" >/dev/null 2>&1 || { LOCK_STATUS=error; ERROR="cannot create tag"; emit; exit 4; }

    ERR_FILE="$(mktemp)"
    if g push "$REMOTE" "refs/tags/$LOCK" >"$ERR_FILE" 2>&1; then
      rm -f "$ERR_FILE"
      LOCK_STATUS=acquired; ACQUIRED=true; ACQUIRED_AT="$AT"; SHA="$AT_SHA"; PRDS="$PRDS_IN"
      HELD_BY="$(g config user.name 2>/dev/null) <$(g config user.email 2>/dev/null)>"
      AGE_SECONDS=0
      emit; exit 0
    fi
    OUT="$(cat "$ERR_FILE")"; rm -f "$ERR_FILE"
    g tag -d "$LOCK" >/dev/null 2>&1 || true      # we did NOT acquire — drop the local tag
    if printf '%s' "$OUT" | grep -qiE 'already exists|non-fast-forward|rejected|stale info'; then
      fetch_lock >/dev/null 2>&1
      held_exit
    fi
    LOCK_STATUS=error
    ERROR="$(printf '%s' "$OUT" | tr '\n' ' ' | cut -c1-160)"
    emit; exit 4                                   # fail-open: proceed without the guard
    ;;

  release)
    if ! fetch_lock; then
      LOCK_STATUS=absent; emit; exit 0             # idempotent — nothing to release
    fi
    read_holder
    if g push "$REMOTE" ":refs/tags/$LOCK" >/dev/null 2>&1; then
      g tag -d "$LOCK" >/dev/null 2>&1 || true
      STALE=false; UNLOCK_CMD=""
      LOCK_STATUS=released; RELEASED=true; RELEASED_AT="$(now_iso)"
      emit; exit 0
    fi
    LOCK_STATUS=error; ERROR="delete push failed"
    emit; exit 4                                   # low note; the TTL reclaims it anyway
    ;;
esac
