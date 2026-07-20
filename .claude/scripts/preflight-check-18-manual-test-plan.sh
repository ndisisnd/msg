#!/usr/bin/env bash
# preflight-check-18-manual-test-plan.sh — detect+normalize the `manual-test-plan` check.
# id 18 · group prd · kind subagent · active_when prd · criticality advisory (EMIT-ONLY)
# Subagent-kind: `run` names the protocol ref, not a command. Presence gated on a PRD
# surface (a no-PRD hotfix skips the whole prd/ group). depends_on prd-consistency —
# it reuses C11's per-item evidence grades (the 4th hard edge).
# Schema: .claude/skills/shared/refs/check-report-schema.md (detect section).
# Emits to .pre-merge/preflight/manual-test-plan.json + stdout.
ROOT="${1:-.}"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" || { echo "cannot cd to $ROOT" >&2; exit 1; }
. "$DIR/preflight-common.sh"

# PRD-surface probe (same as prd-consistency): a features/prd-<n>-*/ dir
surface=false
find . -maxdepth 3 -type d -name 'prd-*' \
  \( -path './node_modules' -o -path './.git' -o -path '*/node_modules' \) -prune -o \
  -type d -name 'prd-*' -print 2>/dev/null | grep -q . && surface=true
[[ -d features ]] && surface=true

if [[ "$surface" == true ]]; then
  mk_report manual-test-plan 18 prd true prd "$NO_TOOLING" "prd/protocol-manual-test-plan.md" advisory moderate '["prd-consistency"]' ready "PRD surface present; emit-only checklist runs when --prd is supplied (never blocks)"
else
  mk_report manual-test-plan 18 prd false prd "$NO_TOOLING" "prd/protocol-manual-test-plan.md" advisory moderate '["prd-consistency"]' n/a "no PRD surface — prd/ group skipped for hotfix/bugfix changes"
fi
