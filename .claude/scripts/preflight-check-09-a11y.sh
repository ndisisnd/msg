#!/usr/bin/env bash
# preflight-check-09-a11y.sh — detect+normalize the `a11y` check.
# id 09 · group platform · kind subagent · active_when ui-surface · criticality blocking
# Subagent-kind: `run` = the protocol ref. `tooling` records the detected runner.
# Schema: .claude/skills/shared/refs/check-report-schema.md (detect section).
# Emits to .pre-merge/preflight/a11y.json + stdout. Never hardcodes a tool (AC-CK3).
ROOT="${1:-.}"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" || { echo "cannot cd to $ROOT" >&2; exit 1; }
. "$DIR/preflight-common.sh"

name=""
if   pkg_dep '@axe-core/cli' || pkg_script axe;                       then name='axe-core CLI'
elif pkg_dep axe-playwright;                                          then name=axe-playwright
elif pkg_dep jest-axe;                                                then name=jest-axe
elif pkg_dep pa11y || pkg_dep pa11y-ci || pkg_script pa11y;           then name=pa11y
elif pkg_dep lighthouse || pkg_dep '@lhci/cli' || pkg_script lhci;    then name='Lighthouse (a11y)'
fi

if [[ -n "$name" ]]; then
  mk_report a11y 09 platform true ui-surface "$(tooling "$name")" "platform/protocol-a11y.md" blocking moderate '[]' ready "a11y runner: $name"
else
  mk_report a11y 09 platform false ui-surface "$NO_TOOLING" "platform/protocol-a11y.md" blocking moderate '[]' n/a "no a11y runner / UI surface detected"
fi
