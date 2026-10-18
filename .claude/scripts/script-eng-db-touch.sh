#!/usr/bin/env bash
# script-eng-db-touch.sh — production/data guardrail for builds.
#
# Flags a diff that touches database, data, or production-config surfaces a
# build must not change without the user's sign-off, so a hands-off build
# (eng --build, plan-em) pauses safely instead of shipping them.
#
# It checks only THIS run's own changes: the caller records the commit at the
# start of its run and passes it as <run-base>. A migration added earlier on the
# same branch by another agent is therefore not re-flagged on every later run.
#
# Usage:
#   script-eng-db-touch.sh <run-base>   check paths changed since <run-base>
#                                       (committed since it + staged + unstaged + untracked)
#   script-eng-db-touch.sh -            read a newline-separated path list from stdin
#
# Record the run base at run start with: RUN_BASE=$(git rev-parse HEAD)
#
# Prints each offending path (prefixed with its category) to stdout.
# Exit code: 0 = clean (no guarded paths), 1 = tripped (guarded paths present),
#            2 = usage/environment error (no <run-base>, unknown ref, no git).

set -euo pipefail

# ── Guarded path patterns (extended-regex, matched against each changed path) ──
# Category | pattern
guard_patterns=(
  "migration|(^|/)migrations/|supabase/migrations/"
  "sql|\.sql$"
  "orm-schema|(^|/)schema\.prisma$|(^|/)schema\.rb$"
  "orm-entity|(^|/)entities/|\.entity\.[a-z]+$"
  "seed-fixture|(^|/)seeds/|(^|/)fixtures/|(^|/)seed\.[a-z]+$"
  "env|(^|/)\.env($|\.)|(^|/)secrets?\.[a-z]+$"
  "prod-config|(^|/)production\.[a-z]+$|(^|/)prod\.[a-z]+$|(^|/)deploy/"
)

if [[ $# -ne 1 || -z "${1:-}" ]]; then
  echo "usage: script-eng-db-touch.sh <run-base> | -   (run-base = the commit at run start)" >&2
  exit 2
fi

collect_paths() {
  if [[ "$1" == "-" ]]; then
    cat -
    return
  fi
  local base="$1"
  command -v git >/dev/null 2>&1 || { echo "script-eng-db-touch: git not available" >&2; exit 2; }
  git rev-parse --verify --quiet "$base^{commit}" >/dev/null \
    || { echo "script-eng-db-touch: unknown run-base '$base'" >&2; exit 2; }
  # Changed since the run base (committed + staged + unstaged + new untracked
  # files), de-duplicated.
  {
    git diff --name-only "$base" HEAD
    git diff --name-only
    git diff --name-only --cached
    git ls-files --others --exclude-standard
  } | sort -u | sed '/^$/d'
}

paths="$(collect_paths "$1")"

tripped=0
while IFS= read -r path; do
  [[ -n "$path" ]] || continue
  for entry in "${guard_patterns[@]}"; do
    category="${entry%%|*}"
    pattern="${entry#*|}"
    if printf '%s\n' "$path" | grep -Eq "$pattern"; then
      printf '%s\t%s\n' "$category" "$path"
      tripped=1
      break
    fi
  done
done <<< "$paths"

exit "$tripped"
