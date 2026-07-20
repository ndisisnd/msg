#!/usr/bin/env bash
# preflight-check-10-perf.sh — detect+normalize the `perf` check.
# id 10 · group platform · kind subagent · active_when perf-config · criticality config-driven
# perf_runner is a {runtime, bundle} pair; either sub-check alone activates the component.
# Schema: .claude/skills/shared/refs/check-report-schema.md (detect section).
# Emits to .pre-merge/preflight/perf.json + stdout. Never hardcodes a tool (AC-CK3).
ROOT="${1:-.}"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" || { echo "cannot cd to $ROOT" >&2; exit 1; }
. "$DIR/preflight-common.sh"

runtime=""; bundle=""
if   has_file '.lighthouserc.*' 3 || has_file 'lighthouserc.js' 3 || pkg_dep '@lhci/cli' || pkg_script lhci; then runtime='Lighthouse CI'
elif pkg_dep web-vitals && has_file 'playwright.config.*' 3; then runtime='Playwright + web-vitals'
fi
if   pkg_field size-limit || pkg_dep size-limit; then bundle=size-limit
elif pkg_field bundlesize || pkg_dep bundlesize; then bundle=bundlesize
fi

chosen=""
[[ -n "$runtime" ]] && chosen="$runtime"
[[ -n "$bundle"  ]] && chosen="${chosen:+$chosen,}$bundle"

if [[ -n "$chosen" ]]; then
  mk_report perf 10 platform true perf-config "$(tooling "$chosen")" "platform/protocol-perf.md" config-driven expensive '[]' ready "perf runners: $chosen"
else
  mk_report perf 10 platform false perf-config "$NO_TOOLING" "platform/protocol-perf.md" config-driven expensive '[]' n/a "no perf budget config / runner detected"
fi
