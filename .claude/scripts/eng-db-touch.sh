#!/usr/bin/env bash
# eng-db-touch.sh — production/data guardrail for the roadmap orchestrator.
#
# Flags a diff that touches database, data, or production-config surfaces the
# autonomous run must not change without the user's sign-off. Ported from ship's
# guardrail so the roadmap orchestrator (eng --build roadmap=…) can pause safely.
#
# Usage:
#   eng-db-touch.sh [<base-ref>]     diff the current branch against <base-ref>
#                                    (default: main) and check changed paths
#   eng-db-touch.sh -                read a newline-separated path list from stdin
#
# Prints each offending path (prefixed with its category) to stdout.
# Exit code: 0 = clean (no guarded paths), 1 = tripped (guarded paths present),
#            2 = usage/environment error.

set -euo pipefail

# ── Guarded path patterns (extended-regex, matched against each changed path) ──
# Category | pattern
guard_patterns=(
  "migration|(^|/)migrations/|supabase/migrations/"
  "sql|\.sql$"
  "orm-schema|(^|/)schema\.prisma$|(^|/)schema\.rb$"
  "orm-model|(^|/)models/|(^|/)entities/|\.entity\.[a-z]+$"
  "seed-fixture|(^|/)seeds/|(^|/)fixtures/|(^|/)seed\.[a-z]+$"
  "env|(^|/)\.env($|\.)|(^|/)secrets?\.[a-z]+$"
  "prod-config|(^|/)production\.[a-z]+$|(^|/)prod\.[a-z]+$|(^|/)deploy/"
)

collect_paths() {
  if [[ "${1:-}" == "-" ]]; then
    cat -
    return
  fi
  local base="${1:-main}"
  command -v git >/dev/null 2>&1 || { echo "eng-db-touch: git not available" >&2; exit 2; }
  # Changed files vs base (committed + staged + unstaged), de-duplicated.
  {
    git diff --name-only "$base"...HEAD 2>/dev/null || true
    git diff --name-only 2>/dev/null || true
    git diff --name-only --cached 2>/dev/null || true
  } | sort -u | sed '/^$/d'
}

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
done < <(collect_paths "${1:-main}")

exit "$tripped"
