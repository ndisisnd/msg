#!/usr/bin/env bash
# preflight-check-08-e2e.sh — detect+normalize the `e2e` check.
# id 08 · group platform · kind subagent · active_when ui-surface · criticality blocking
# Subagent-kind: `run` = the protocol ref. `tooling` still records the detected runner.
# Schema: .claude/skills/shared/refs/check-report-schema.md (detect section).
# Emits to .pre-merge/preflight/e2e.json + stdout. Never hardcodes a tool (AC-CK3).
ROOT="${1:-.}"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" || { echo "cannot cd to $ROOT" >&2; exit 1; }
. "$DIR/preflight-common.sh"

name=""
if   has_file 'playwright.config.*' 3 || pkg_dep '@playwright/test'; then name=Playwright
elif has_file 'cypress.config.*' 3    || pkg_dep cypress;            then name=Cypress
elif pubspec_flutter && [[ -d integration_test ]];                   then name='Flutter integration'
fi

if [[ -n "$name" ]]; then
  mk_report e2e 08 platform true ui-surface "$(tooling "$name")" "platform/protocol-e2e.md" blocking expensive '[]' ready "e2e runner: $name"
else
  mk_report e2e 08 platform false ui-surface "$NO_TOOLING" "platform/protocol-e2e.md" blocking expensive '[]' n/a "no e2e runner / UI surface detected"
fi
