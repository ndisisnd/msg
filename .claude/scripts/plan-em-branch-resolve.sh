#!/usr/bin/env bash
# plan-em-branch-resolve.sh — READ-ONLY branch resolver for plan-em Step 4.
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
#   plan-em-branch-resolve.sh <prd.md> [--main <main-branch>]   # default main: main
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
#   LANE_MOVE=git mv <src>/ features/wip/<prd-id>/   or   LANE_MOVE=none
#     Emitted only on create/fresh-cut of a TOP-LEVEL PRD whose folder is not
#     already under features/wip/. Sub-PRDs never move (they ride the parent's
#     lane); a re-checkout is never a move.
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
  lane_move="git mv $srcdir/ features/wip/$own_id/"
fi

echo "BRANCH=$branch"
echo "ACTION=$action"
echo "LANE_MOVE=$lane_move"
exit 0
