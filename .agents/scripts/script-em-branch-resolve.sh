#!/usr/bin/env bash
# script-em-branch-resolve.sh — READ-ONLY branch resolver for plan-em Step 4.
#
# Computes the feature branch plan-em should build on for a PRD, the git action
# to take, and any planned/->wip/ lane move — WITHOUT mutating git or moving
# files. It only reads the PRD frontmatter and the local branch/merge state and
# emits key=value lines; plan-em executes what it emits. This mechanises the
# "Branch resolution (parent-aware)", "Idempotent create-or-checkout", and
# "Lane move on a fresh cut" decision ladder from protocol-em.md Step 4 so the
# branch choice is made one proven way.
#
# Usage:
#   script-em-branch-resolve.sh <prd.md> [--main <main-branch>]   # default main: main
#
# Branch naming: feat/<prd-id>, where <prd-id> is the PRD folder basename
# (feat/prd-3-habit-tracking). A sub-PRD (frontmatter `parent: prd-<pn>-<pslug>`)
# rides the parent's branch feat/<parent-id> and never gets its own — UNLESS the
# parent branch has already merged, in which case the fresh cut uses the
# sub-PRD's OWN id (feat/prd-2.1-streak-freeze). This matches protocol-sub's
# branch inference and the roadmap scanner's completion ladder (feat/prd-<n>-*).
#
# Output (key=value lines on stdout):
#   BRANCH=<name>       the branch to build on
#   ACTION=create       branch absent           -> cut from main + push
#   ACTION=checkout     branch exists, unmerged  -> checkout, no re-create/reset
#   ACTION=fresh-cut    branch exists but already merged to main (reuse would
#                       double-merge) -> BRANCH is the fresh, non-colliding name
#   LANE_MOVE=mv <src>/ features/wip/<prd-id>/       or   LANE_MOVE=none
#     (`git mv` instead of `mv` only when <src> is actually tracked — features/
#      is gitignored, so plain `mv` is the normal path and `git mv` would fail.)
#     Emitted only on create/fresh-cut of a TOP-LEVEL PRD whose folder is not
#     already under features/wip/. Sub-PRDs never move (they ride the parent's
#     lane); a re-checkout is never a move.
#   MAIN_BEHIND_REMOTE=true
#     Emitted ONLY when origin/<main> exists and is strictly ahead of the local
#     <main> (A25). The merged test below is answered against the LOCAL <main>,
#     so a stale local copy makes an already-merged branch look unmerged: the
#     resolver says ACTION=checkout, the caller commits onto a shipped branch,
#     and the work merges twice — the exact outcome fresh-cut exists to prevent.
#     BRANCH/ACTION/LANE_MOVE are UNCHANGED by this line; it tells the caller to
#     `git fetch origin <main>` and re-run before acting on ACTION=checkout.
#     Absent = the local <main> is up to date with its remote, or there is no
#     origin/<main> to compare against (offline / no remote / no local <main>).
#
# Merged test: `git branch --merged <main>` listing containing BRANCH.
#
# Exit: 0 = resolved; 2 = missing file / unreadable frontmatter / not a git repo.

set -uo pipefail
SELF="$(basename "$0")"

usage() { echo "usage: $SELF <prd.md> [--main <main-branch>]" >&2; exit 2; }

prd=""
main="main"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --main)    main="${2:-}"; shift 2 || shift ;;
    --main=*)  main="${1#--main=}"; shift ;;
    -h|--help) usage ;;
    --*)       echo "$SELF: unknown flag: $1" >&2; usage ;;
    *)         if [[ -z "$prd" ]]; then prd="$1"; shift
               else echo "$SELF: unexpected extra argument: $1" >&2; usage; fi ;;
  esac
done

[[ -n "$prd" ]] || usage
[[ -n "$main" ]] || { echo "$SELF: --main requires a value" >&2; exit 2; }

if [[ ! -f "$prd" ]]; then
  echo "$SELF: no such PRD file: $prd" >&2
  exit 2
fi

# Not a git repo -> exit 2.
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "$SELF: not inside a git repository" >&2
  exit 2
fi

# Frontmatter must open on line 1 with a `---` fence.
if [[ "$(sed -n '1p' "$prd")" != "---" ]]; then
  echo "$SELF: no YAML frontmatter in $prd" >&2
  exit 2
fi

# Extract the `parent:` field (empty for a top-level PRD).
parent="$(awk '
  NR==1 { next }                        # skip opening fence
  /^---[[:space:]]*$/ { exit }          # closing fence ends frontmatter
  {
    if ($0 ~ /^parent:[[:space:]]*/) {
      v=$0; sub(/^parent:[[:space:]]*/,"",v); sub(/[[:space:]]*#.*/,"",v)
      gsub(/^[[:space:]]+|[[:space:]]+$/,"",v)
      print v; exit
    }
  }
' "$prd")"

srcdir="$(dirname "$prd")"
own_id="$(basename "$srcdir")"
lane="$(basename "$(dirname "$srcdir")")"

if [[ -n "$parent" ]]; then
  is_sub=1
  branch="feat/$parent"
else
  is_sub=0
  branch="feat/$own_id"
fi

branch_exists() { git rev-parse --verify --quiet "refs/heads/$1" >/dev/null 2>&1; }
is_merged() {
  # protocol: `git branch --merged <main>` listing containing BRANCH.
  git branch --merged "$main" 2>/dev/null | sed 's/^[*+ ]*//' | grep -qxF "$1"
}

if ! branch_exists "$branch"; then
  action="create"
else
  # The merged question needs main to exist.
  if ! branch_exists "$main"; then
    echo "$SELF: main branch '$main' not found — cannot test merge state" >&2
    exit 2
  fi
  if is_merged "$branch"; then
    action="fresh-cut"
    # Fresh, non-colliding name from THIS PRD's own id (a sub-PRD gets its own
    # id here; a top-level whose name collides with the shipped branch gets the
    # next free -N suffix so the emitted branch never already exists).
    fresh="feat/$own_id"
    if branch_exists "$fresh"; then
      i=2
      while branch_exists "${fresh}-${i}"; do i=$((i + 1)); done
      fresh="${fresh}-${i}"
    fi
    branch="$fresh"
  else
    action="checkout"
  fi
fi

# Lane move: only on create/fresh-cut of a top-level PRD not already in wip/.
lane_move="none"
if [[ ( "$action" == "create" || "$action" == "fresh-cut" ) && "$is_sub" -eq 0 && "$lane" != "wip" ]]; then
  if [[ -n "$(git ls-files -- "$srcdir" 2>/dev/null)" ]]; then
    lane_move="git mv $srcdir/ features/wip/$own_id/"
  else
    lane_move="mv $srcdir/ features/wip/$own_id/"
  fi
fi

# A25 — the merged test above reads the LOCAL "$main". If origin/$main carries
# commits the local copy has not fetched, a branch that has already merged
# upstream still reads unmerged here. Report the staleness (READ-ONLY: no fetch,
# no mutation); the verdict itself is deliberately left unchanged.
main_behind_remote=0
if git rev-parse --verify --quiet "refs/remotes/origin/$main" >/dev/null 2>&1 \
   && branch_exists "$main"; then
  ahead="$(git rev-list --count "$main..origin/$main" 2>/dev/null || true)"
  if [[ "${ahead:-0}" =~ ^[0-9]+$ ]] && (( ahead > 0 )); then
    main_behind_remote=1
  fi
fi

echo "BRANCH=$branch"
echo "ACTION=$action"
echo "LANE_MOVE=$lane_move"
if (( main_behind_remote )); then
  echo "MAIN_BEHIND_REMOTE=true"
  echo "$SELF: local '$main' is $ahead commit(s) behind origin/$main — the merged test ran against the stale local ref; fetch and re-run before acting on ACTION=$action" >&2
fi
exit 0
