#!/usr/bin/env bash
# preflight-check-13-migration.sh — detect+normalize the `migration` check.
# id 13 · group platform · kind hybrid · active_when migrations · criticality critical · MANDATORY
# No external runner — a static SQL-safety scan + /cook semantic pass. ALWAYS emits (AC-PF2).
# Surface probe (new): the diff's migration directories/files.
# Schema: .claude/skills/shared/refs/check-report-schema.md (detect section).
# Emits to .pre-merge/preflight/migration.json + stdout.
ROOT="${1:-.}"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" || { echo "cannot cd to $ROOT" >&2; exit 1; }
. "$DIR/preflight-common.sh"

# migration-surface probe: any conventional migrations location
surface=false; where=""
if   [[ -d supabase/migrations ]]; then surface=true; where='supabase/migrations'
elif [[ -d prisma/migrations ]];   then surface=true; where='prisma/migrations'
elif [[ -d db/migrate ]];          then surface=true; where='db/migrate'
elif has_dir migrations 4;          then surface=true; where='**/migrations'
elif has_file '*.up.sql' 4 || has_file '*.down.sql' 4; then surface=true; where='*.up.sql/*.down.sql'
fi

if [[ "$surface" == true ]]; then
  mk_report migration 13 platform true migrations "$NO_TOOLING" "platform/protocol-migration.md" critical moderate '[]' ready "mandatory; migration surface: $where; static SQL-safety scan + /cook semantic pass"
else
  # mandatory: still emits — nothing to scan yet, activates when the diff adds a migration
  mk_report migration 13 platform false migrations "$NO_TOOLING" "platform/protocol-migration.md" critical moderate '[]' n/a "mandatory; no migration surface — activates when the diff touches migrations (AC-PF12)"
fi
