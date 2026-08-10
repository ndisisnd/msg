#!/usr/bin/env bash
# script-branch-topology.sh — READ-ONLY git branch topology resolver.
#
# One place where msg answers "what branches does this repo have, and which one
# is production?". The same four-line detection block used to be spelled out in
# msg/refs/protocol-cto.md (Deriving the rest), msg/refs/protocol-eng.md
# (Call 3), msg/refs/protocol-init-staging.md (Step 1) and the HAS_GH_REMOTE
# probe at msg/refs/protocol-init.md (Step 5, reused by --update Step 3-CI).
# Four copies could age apart; this script is the single copy.
#
# Mutates nothing — no branch is created, checked out, fetched or pushed.
#
# Usage:
#   script-branch-topology.sh [<repo-dir>] [--remote <name>]
#
#   <repo-dir>   defaults to $PWD
#   --remote     remote to probe for a published staging branch (default: origin)
#
# Output (stdout, key=value lines, always the full set even on failure):
#   IS_GIT_REPO=true|false          working dir is inside a git work tree
#   CURRENT_BRANCH=<name|none>      `none` on a detached HEAD or non-repo
#   HAS_MAIN=true|false             local refs/heads/main
#   HAS_MASTER=true|false           local refs/heads/master
#   HAS_STAGING=true|false          local refs/heads/staging
#   HAS_REMOTE_STAGING=true|false   <remote>/staging published
#   PROD_BRANCH=<name>              main -> master -> current branch (resolved
#                                   once, here; every caller reads this key)
#   HAS_REMOTE=true|false           any git remote configured
#   IS_GITHUB=true|false            a remote points at github.com
#   HAS_GH_CLI=true|false           `gh` on PATH
#   HAS_GH_REMOTE=true|false        IS_GITHUB && HAS_GH_CLI (the Step 5 gate)
#
# Exit codes:
#   0  resolved
#   3  not a git repository — every key is still printed with safe values
#      (IS_GIT_REPO=false, PROD_BRANCH=main). Informational for /msg --init,
#      which warns and may proceed; fatal for --init-staging, which requires git.
#   2  usage error (unknown flag, unreadable dir)
#
# Deterministic: identical repo state produces byte-identical output.
set -uo pipefail

SELF="script-branch-topology"

die() { printf '%s: ERROR=%s %s\n' "$SELF" "$1" "${2:-}" >&2; exit 2; }

DIR="$PWD"
REMOTE="origin"
DIR_SET=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote)
      [[ $# -ge 2 ]] || die usage "--remote needs a value"
      REMOTE="$2"; shift 2 ;;
    --remote=*) REMOTE="${1#*=}"; shift ;;
    -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
    --*) die usage "unknown flag: $1" ;;
    *)
      [[ "$DIR_SET" == false ]] || die usage "unexpected argument: $1"
      DIR="$1"; DIR_SET=true; shift ;;
  esac
done

[[ -d "$DIR" ]] || die usage "not a directory: $DIR"

git_in() { git -C "$DIR" "$@" 2>/dev/null; }
has_head() { git_in show-ref --verify --quiet "refs/heads/$1" && echo true || echo false; }

if ! git_in rev-parse --is-inside-work-tree >/dev/null; then
  cat <<'EOF'
IS_GIT_REPO=false
CURRENT_BRANCH=none
HAS_MAIN=false
HAS_MASTER=false
HAS_STAGING=false
HAS_REMOTE_STAGING=false
PROD_BRANCH=main
HAS_REMOTE=false
IS_GITHUB=false
HAS_GH_CLI=false
HAS_GH_REMOTE=false
EOF
  exit 3
fi

CURRENT_BRANCH="$(git_in rev-parse --abbrev-ref HEAD)"
[[ -n "$CURRENT_BRANCH" && "$CURRENT_BRANCH" != "HEAD" ]] || CURRENT_BRANCH="none"

HAS_MAIN="$(has_head main)"
HAS_MASTER="$(has_head master)"
HAS_STAGING="$(has_head staging)"

# Remotes.
if [[ -n "$(git_in remote)" ]]; then HAS_REMOTE=true; else HAS_REMOTE=false; fi

HAS_REMOTE_STAGING=false
if [[ "$HAS_REMOTE" == true ]]; then
  if git_in ls-remote --exit-code --heads "$REMOTE" staging >/dev/null; then
    HAS_REMOTE_STAGING=true
  fi
fi

IS_GITHUB=false
if [[ "$HAS_REMOTE" == true ]] && git_in remote -v | grep -qi 'github\.com'; then
  IS_GITHUB=true
fi

if command -v gh >/dev/null 2>&1; then HAS_GH_CLI=true; else HAS_GH_CLI=false; fi

if [[ "$IS_GITHUB" == true && "$HAS_GH_CLI" == true ]]; then
  HAS_GH_REMOTE=true
else
  HAS_GH_REMOTE=false
fi

# The prod-branch rule lives here and nowhere else: main -> master -> current.
if [[ "$HAS_MAIN" == true ]]; then
  PROD_BRANCH=main
elif [[ "$HAS_MASTER" == true ]]; then
  PROD_BRANCH=master
elif [[ "$CURRENT_BRANCH" != none ]]; then
  PROD_BRANCH="$CURRENT_BRANCH"
else
  PROD_BRANCH=main
fi

cat <<EOF
IS_GIT_REPO=true
CURRENT_BRANCH=$CURRENT_BRANCH
HAS_MAIN=$HAS_MAIN
HAS_MASTER=$HAS_MASTER
HAS_STAGING=$HAS_STAGING
HAS_REMOTE_STAGING=$HAS_REMOTE_STAGING
PROD_BRANCH=$PROD_BRANCH
HAS_REMOTE=$HAS_REMOTE
IS_GITHUB=$IS_GITHUB
HAS_GH_CLI=$HAS_GH_CLI
HAS_GH_REMOTE=$HAS_GH_REMOTE
EOF
exit 0
