#!/usr/bin/env bash
# preflight-check-16-preview.sh — detect+normalize the `preview` check.
# id 16 · group platform · kind gate · criticality blocking · MERGED human-review gate (C20; absorbs qa/15).
# active_when = union: a UI surface OR an api/migration/deploy surface.
# id 15 (`qa`) is RETIRED — there is no preflight-check-15-qa.sh.
# Gate-kind: `run` = the resolved preview-deploy command if detected, else the protocol ref.
# Schema: .claude/skills/shared/refs/check-report-schema.md (detect section).
# Emits to .pre-merge/preflight/preview.json + stdout. Never hardcodes a tool (AC-CK3).
ROOT="${1:-.}"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" || { echo "cannot cd to $ROOT" >&2; exit 1; }
. "$DIR/preflight-common.sh"

# deploy/preview-surface probe (new — the old detector has no preview slot)
deploy=""
for f in vercel.json netlify.toml fly.toml render.yaml app.yaml Procfile Dockerfile; do
  has_file "$f" 2 && { deploy="$f"; break; }
done
# UI build surface (captures the visual states half of the merged gate)
ui=false
{ pkg_dep next || pkg_dep vite || pkg_dep astro || pkg_dep '@sveltejs/kit' || has_file 'index.html' 2 || pubspec_flutter; } && ui=true

if [[ -n "$deploy" || "$ui" == true ]]; then
  chosen="${deploy:-ui-build}"
  mk_report preview 16 platform true ui-or-deploy-surface "$(tooling "$chosen")" "platform/protocol-preview.md" blocking expensive '[]' ready "merged human-review gate; deploy surface: ${deploy:-none}; ui surface: $ui"
else
  mk_report preview 16 platform false ui-or-deploy-surface "$NO_TOOLING" "platform/protocol-preview.md" blocking expensive '[]' n/a "no UI or api/migration/deploy surface detected"
fi
