#!/usr/bin/env bash
# check-staged.sh — gate for msg-commit; exits non-zero when nothing is staged
#
# Exit 0: staged changes exist; diff written to stdout
# Exit 1: nothing staged or not a git repo; reason written to stderr

set -euo pipefail

if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Not a git repository." >&2
  exit 1
fi

diff=$(git diff --staged)

if [[ -z "$diff" ]]; then
  echo "No staged changes. Stage your changes with 'git add <files>' first." >&2
  exit 1
fi

printf '%s\n' "$diff"
