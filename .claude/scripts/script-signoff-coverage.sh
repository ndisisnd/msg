#!/usr/bin/env bash
# script-signoff-coverage.sh — READ-ONLY staging sign-off coverage check.
#
# merge --production's Step 1 safety gate: does the newest staging
# sign-off actually cover what is about to ship, or has staging advanced past
# every stamped commit? The whole check used to be prose plus inline bash (an
# ancestry loop, a coverage compare and a pairwise topologically-newest loop)
# executed by the model twice per production run — a mis-run that wrongly
# PASSES ships commits no human certified, and nothing downstream notices.
# This script is the one implementation.
#
# The model keeps the one judgment half it must own: the unpinned-legacy
# human re-ask (this script only reports UNPINNED, it never resolves it).
#
# Contract: .claude/skills/merge/refs/production.md § Sign-off coverage
#
# Usage:
#   script-signoff-coverage.sh --stamp <prd-id>=<sha> [--stamp ...] \
#                              [--head <ref>] [--fetch] [--repo <dir>]
#
#   --stamp   one per shipping PRD: `<prd-id>=<sha>` read off its
#             `staging-signoff: <date>@<sha>` frontmatter stamp. A stamp with
#             no sha (`<prd-id>=`) is an UNPINNED legacy stamp — reported, not
#             judged.
#   --head    the tip the stamps must cover (default: origin/staging).
#   --fetch   `git fetch <remote> <branch>` for the head ref first. The ONLY
#             non-read-only action this script can take, and it is opt-in; it
#             touches remote-tracking refs only, never the work tree.
#   --repo    repo dir (default: $PWD).
#
# Output (stdout, KEY=VALUE lines, always the full key set):
#   VERDICT=covered|stale_signoff|unpinned|no_stamps
#   REASON=ok|not_ancestor|head_ahead|no_newest|unpinned_stamp|no_stamps
#   HEAD_REF=<ref>            what was checked against
#   HEAD_SHA=<40-char sha>    resolved tip (empty when unresolvable)
#   STAMP_COUNT=<n>           pinned stamps supplied
#   UNPINNED=<prd,prd>        PRDs whose stamp carries no sha (legacy)
#   NON_ANCESTOR=<prd:sha,…>  stamps not reachable from HEAD_SHA (rewritten
#                             history) — non-empty ⇒ REASON=not_ancestor
#   NEWEST_PRD=<prd-id>       owner of the topologically newest stamp
#   NEWEST_SHA=<sha>          the newest stamp itself (empty when none dominates)
#   UNCERTIFIED_COUNT=<n>     commits in NEWEST_SHA..HEAD_SHA
#   UNCERTIFIED_SHAS=<sha,…>  those commits, newest first
#
# After the key block, each uncertified commit is echoed as a comment line
# `# <short sha> <subject>` — informational for the refusal detail, never a key.
#
# "Newest" is the stamp EVERY other stamp is an ancestor of, computed by a
# pairwise ancestry loop. `git rev-list --topo-order` orders by commit date,
# not ancestry, so it cannot answer this. When no stamp dominates all others
# (stamps on divergent lines) the verdict is stale_signoff, never a guess.
#
# Coverage — not per-PRD equality: a multi-PRD release stamps each PRD at its
# own merge sha, so older stamps legitimately lag the tip. What must hold is
# that the NEWEST sign-off IS the tip.
#
# Exit codes:
#   0  VERDICT=covered
#   3  VERDICT=stale_signoff  (refuse — ancestry broken, head ahead, or no newest)
#   4  VERDICT=unpinned       (a legacy stamp needs the human re-ask first)
#   5  VERDICT=no_stamps      (nothing signed off — the caller refuses no_signoff)
#   2  usage error / not a git repo / unresolvable head
#
# Deterministic: identical repo state + identical stamps ⇒ byte-identical output.

set -uo pipefail

SELF="$(basename "$0")"

die() { echo "$SELF: $1" >&2; exit 2; }

usage() {
  echo "usage: $SELF --stamp <prd-id>=<sha> [--stamp ...] [--head <ref>] [--fetch] [--repo <dir>]" >&2
  exit 2
}

REPO="$PWD"
HEAD_REF="origin/staging"
DO_FETCH=false
STAMPS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --stamp)   [[ $# -ge 2 ]] || usage; STAMPS+=("$2"); shift 2 ;;
    --stamp=*) STAMPS+=("${1#--stamp=}"); shift ;;
    --head)    [[ $# -ge 2 ]] || usage; HEAD_REF="$2"; shift 2 ;;
    --head=*)  HEAD_REF="${1#--head=}"; shift ;;
    --repo)    [[ $# -ge 2 ]] || usage; REPO="$2"; shift 2 ;;
    --repo=*)  REPO="${1#--repo=}"; shift ;;
    --fetch)   DO_FETCH=true; shift ;;
    -h|--help) sed -n '2,70p' "$0"; exit 0 ;;
    *)         usage ;;
  esac
done

[[ -d "$REPO" ]] || die "not a directory: $REPO"
git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not a git repository: $REPO"

if [[ "$DO_FETCH" == true ]]; then
  case "$HEAD_REF" in
    */*) git -C "$REPO" fetch "${HEAD_REF%%/*}" "${HEAD_REF#*/}" --quiet 2>/dev/null || true ;;
    *)   git -C "$REPO" fetch origin "$HEAD_REF" --quiet 2>/dev/null || true ;;
  esac
fi

emit() {
  cat <<EOF
VERDICT=$VERDICT
REASON=$REASON
HEAD_REF=$HEAD_REF
HEAD_SHA=$HEAD_SHA
STAMP_COUNT=$STAMP_COUNT
UNPINNED=$UNPINNED
NON_ANCESTOR=$NON_ANCESTOR
NEWEST_PRD=$NEWEST_PRD
NEWEST_SHA=$NEWEST_SHA
UNCERTIFIED_COUNT=$UNCERTIFIED_COUNT
UNCERTIFIED_SHAS=$UNCERTIFIED_SHAS
EOF
}

VERDICT=""; REASON=""; HEAD_SHA=""; STAMP_COUNT=0
UNPINNED=""; NON_ANCESTOR=""; NEWEST_PRD=""; NEWEST_SHA=""
UNCERTIFIED_COUNT=0; UNCERTIFIED_SHAS=""

HEAD_SHA="$(git -C "$REPO" rev-parse --verify --quiet "$HEAD_REF^{commit}" 2>/dev/null || true)"
[[ -n "$HEAD_SHA" ]] || die "cannot resolve --head ref: $HEAD_REF"

# Split the supplied stamps into pinned (prd:sha) and unpinned (prd only).
PRDS=(); SHAS=()
for s in "${STAMPS[@]:-}"; do
  [[ -n "$s" ]] || continue
  prd="${s%%=*}"; sha="${s#*=}"
  [[ "$s" == *"="* ]] || die "bad --stamp (want <prd-id>=<sha>): $s"
  if [[ -z "$sha" ]]; then
    UNPINNED="${UNPINNED:+$UNPINNED,}$prd"
    continue
  fi
  full="$(git -C "$REPO" rev-parse --verify --quiet "$sha^{commit}" 2>/dev/null || true)"
  [[ -n "$full" ]] || die "stamp sha not found in this repo: $prd=$sha"
  PRDS+=("$prd"); SHAS+=("$full")
done
STAMP_COUNT=${#SHAS[@]}

# An unpinned stamp is a human question, not a machine verdict — report and stop.
if [[ -n "$UNPINNED" ]]; then
  VERDICT=unpinned; REASON=unpinned_stamp; emit; exit 4
fi

if [[ "$STAMP_COUNT" -eq 0 ]]; then
  VERDICT=no_stamps; REASON=no_stamps; emit; exit 5
fi

# 1 · Ancestry — every stamped sha reachable from HEAD (a sha is its own ancestor).
for i in "${!SHAS[@]}"; do
  if ! git -C "$REPO" merge-base --is-ancestor "${SHAS[$i]}" "$HEAD_SHA" 2>/dev/null; then
    NON_ANCESTOR="${NON_ANCESTOR:+$NON_ANCESTOR,}${PRDS[$i]}:${SHAS[$i]}"
  fi
done
if [[ -n "$NON_ANCESTOR" ]]; then
  VERDICT=stale_signoff; REASON=not_ancestor; emit; exit 3
fi

# 2 · Topologically newest — the stamp every other stamp is an ancestor of.
for i in "${!SHAS[@]}"; do
  dominates=1
  for j in "${!SHAS[@]}"; do
    git -C "$REPO" merge-base --is-ancestor "${SHAS[$j]}" "${SHAS[$i]}" 2>/dev/null || { dominates=0; break; }
  done
  if [[ "$dominates" -eq 1 ]]; then
    NEWEST_PRD="${PRDS[$i]}"; NEWEST_SHA="${SHAS[$i]}"; break
  fi
done
if [[ -z "$NEWEST_SHA" ]]; then
  VERDICT=stale_signoff; REASON=no_newest; emit; exit 3
fi

# 3 · Coverage — the newest stamp IS the tip.
if [[ "$NEWEST_SHA" == "$HEAD_SHA" ]]; then
  VERDICT=covered; REASON=ok; emit; exit 0
fi

while read -r c; do
  [[ -n "$c" ]] || continue
  UNCERTIFIED_SHAS="${UNCERTIFIED_SHAS:+$UNCERTIFIED_SHAS,}$c"
  UNCERTIFIED_COUNT=$((UNCERTIFIED_COUNT + 1))
done < <(git -C "$REPO" rev-list "$NEWEST_SHA..$HEAD_SHA" 2>/dev/null)

VERDICT=stale_signoff; REASON=head_ahead
emit
git -C "$REPO" log --oneline "$NEWEST_SHA..$HEAD_SHA" 2>/dev/null | sed 's/^/# /'
exit 3
