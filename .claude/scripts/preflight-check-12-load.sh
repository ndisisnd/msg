#!/usr/bin/env bash
# preflight-check-12-load.sh — detect+normalize the `load` check.
# id 12 · group platform · kind subagent · active_when api-surface · criticality config-driven
# Schema: .claude/skills/shared/refs/check-report-schema.md (detect section).
# Emits to .pre-merge/preflight/load.json + stdout. Never hardcodes a tool (AC-CK3).
ROOT="${1:-.}"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" || { echo "cannot cd to $ROOT" >&2; exit 1; }
. "$DIR/preflight-common.sh"

name=""
if   has_cmd k6 || pkg_script k6;                                        then name=k6
elif has_file 'artillery.yml' 2 || has_file 'artillery.json' 2 || pkg_dep artillery; then name=Artillery
elif has_file 'locustfile.py' 3;                                         then name=Locust
elif pkg_dep autocannon || pkg_script autocannon;                        then name=autocannon
elif has_cmd wrk;                                                        then name=wrk
elif has_cmd hey;                                                        then name=hey
fi

if [[ -n "$name" ]]; then
  mk_report load 12 platform true api-surface "$(tooling "$name")" "platform/protocol-load.md" config-driven expensive '[]' ready "load runner: $name"
else
  mk_report load 12 platform false api-surface "$NO_TOOLING" "platform/protocol-load.md" config-driven expensive '[]' n/a "no load runner detected"
fi
