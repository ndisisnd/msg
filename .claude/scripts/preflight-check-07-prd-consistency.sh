#!/usr/bin/env bash
# preflight-check-07-prd-consistency.sh — detect+normalize the `prd-consistency` check.
# id 07 · group prd · kind subagent · active_when prd · criticality blocking
# Subagent-kind: `run` names the protocol ref, not a command. Presence gated on a PRD
# surface (a no-PRD hotfix skips the whole prd/ group).
# Schema: .claude/skills/shared/refs/check-report-schema.md (detect section).
# Emits to .pre-merge/preflight/prd-consistency.json + stdout.
ROOT="${1:-.}"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" || { echo "cannot cd to $ROOT" >&2; exit 1; }
. "$DIR/preflight-common.sh"

# PRD-surface probe (new — the old detector has none): a features/prd-<n>-*/ dir
surface=false
find . -maxdepth 3 -type d -name 'prd-*' \
  \( -path './node_modules' -o -path './.git' -o -path '*/node_modules' \) -prune -o \
  -type d -name 'prd-*' -print 2>/dev/null | grep -q . && surface=true
[[ -d features ]] && surface=true

if [[ "$surface" == true ]]; then
  mk_report prd-consistency 07 prd true prd "$NO_TOOLING" "prd/protocol-prd-consistency.md" blocking expensive '[]' ready "PRD surface present; runs when --prd is supplied"
else
  mk_report prd-consistency 07 prd false prd "$NO_TOOLING" "prd/protocol-prd-consistency.md" blocking expensive '[]' n/a "no PRD surface — prd/ group skipped for hotfix/bugfix changes"
fi
