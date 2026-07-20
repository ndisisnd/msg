#!/usr/bin/env bash
# preflight-check-17-smoke.sh — detect+normalize the `smoke` check.
# id 17 · group platform · kind subagent · active_when preview-fired · criticality blocking
# depends_on {preview} (hard edge — smoke checks the fired preview's liveness, AC-CAT3).
# `run` references platform/protocol-smoke.md (new — authored in Phase 6/C21).
# Schema: .claude/skills/shared/refs/check-report-schema.md (detect section).
# Emits to .pre-merge/preflight/smoke.json + stdout. Never hardcodes a tool (AC-CK3).
ROOT="${1:-.}"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" || { echo "cannot cd to $ROOT" >&2; exit 1; }
. "$DIR/preflight-common.sh"

DEPS='["preview"]'

# smoke-runner probe (new — resolves Q3): an explicit smoke suite/script
runner=""
{ has_dir smoke 4 || has_path tests/smoke || pkg_script smoke; } && runner='smoke suite'

# a preview surface (mirrors check 16) means smoke has something to fire against
preview=false
{ has_file 'vercel.json' 2 || has_file 'netlify.toml' 2 || has_file 'fly.toml' 2 || has_file 'Dockerfile' 2 \
  || pkg_dep next || pkg_dep vite || pkg_dep astro || pkg_dep '@sveltejs/kit' || has_file 'index.html' 2 || pubspec_flutter; } && preview=true

if [[ -n "$runner" ]]; then
  mk_report smoke 17 platform true preview-fired "$(tooling "$runner")" "platform/protocol-smoke.md" blocking moderate "$DEPS" ready "smoke runner: $runner (fires against the preview)"
elif [[ "$preview" == true ]]; then
  # preview exists but no explicit smoke suite → default liveness check at gate time (AC-SMK1)
  mk_report smoke 17 platform true preview-fired "$NO_TOOLING" "platform/protocol-smoke.md" blocking moderate "$DEPS" no_tooling "preview surface present, no smoke suite — default liveness check applies (AC-SMK1)"
else
  mk_report smoke 17 platform false preview-fired "$NO_TOOLING" "platform/protocol-smoke.md" blocking moderate "$DEPS" n/a "no preview surface — smoke fires only when a preview is deployed"
fi
