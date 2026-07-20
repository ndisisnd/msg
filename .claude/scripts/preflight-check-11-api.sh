#!/usr/bin/env bash
# preflight-check-11-api.sh — detect+normalize the `api` check.
# id 11 · group platform · kind subagent · active_when api-surface · criticality blocking
# Detects contract-test runners AND (new surface probe) an OpenAPI/Swagger spec.
# Schema: .claude/skills/shared/refs/check-report-schema.md (detect section).
# Emits to .pre-merge/preflight/api.json + stdout. Never hardcodes a tool (AC-CK3).
ROOT="${1:-.}"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" || { echo "cannot cd to $ROOT" >&2; exit 1; }
. "$DIR/preflight-common.sh"

names=""
add() { names="${names:+$names,}$1"; }
{ pkg_dep '@pact-foundation/pact' || pkg_dep pact || [[ -d pacts ]] || [[ -d .pact ]]; } && add Pact
{ pkg_dep newman || has_cmd newman; } && add Newman
{ pkg_dep dredd || has_file 'dredd.yml' 3; } && add Dredd
{ find . -maxdepth 4 -type f -name '*.hurl' -not -path '*/node_modules/*' 2>/dev/null | grep -q . && has_cmd hurl; } && add Hurl
{ has_file '.spectral.yaml' 3 || has_file '.spectral.json' 3 || pkg_dep '@stoplight/spectral-cli'; } && add Spectral
{ pkg_dep ibm-openapi-validator || has_file '.validaterc' 3; } && add openapi-validator

# API-surface probe (new — the old detector keys only off runners): an OpenAPI/Swagger spec
spec=false
{ has_file 'openapi.*' 3 || has_file 'swagger.*' 3 || has_file 'openapi.yaml' 4 || has_file 'openapi.json' 4; } && spec=true

if [[ -n "$names" ]]; then
  mk_report api 11 platform true api-surface "$(tooling "$names")" "platform/protocol-api.md" blocking moderate '[]' ready "api runners: $names; openapi spec: $spec"
elif [[ "$spec" == true ]]; then
  mk_report api 11 platform true api-surface "$(tooling spec)" "platform/protocol-api.md" blocking moderate '[]' no_tooling "openapi/swagger spec present but no contract runner detected"
else
  mk_report api 11 platform false api-surface "$NO_TOOLING" "platform/protocol-api.md" blocking moderate '[]' n/a "no API contract runner or spec detected"
fi
