#!/usr/bin/env bash
# preflight-check-05-security.sh — detect+normalize the `security` check.
# id 05 · group universal · kind hybrid · active_when always · criticality critical · MANDATORY
# Safety floor: ALWAYS emits a report even with no scanner detected (AC-PF2) — with no
# scanner it degrades to the /cook semantic pass rather than opting out.
# Schema: .claude/skills/shared/refs/check-report-schema.md (detect section).
# Emits to .pre-merge/preflight/security.json + stdout. Never hardcodes a tool (AC-CK3).
ROOT="${1:-.}"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" || { echo "cannot cd to $ROOT" >&2; exit 1; }
. "$DIR/preflight-common.sh"

names=""; primary=""
pick() { names="${names:+$names,}$1"; [[ -z "$primary" ]] && primary="$2"; }

# secret scanners
has_cmd gitleaks   && pick gitleaks   'gitleaks detect'
has_cmd trufflehog && pick trufflehog 'trufflehog filesystem --no-update --json .'
# SAST (project semgrep config wins over --config auto)
if   has_file '.semgrep.yml' 2; then pick 'semgrep (project config)' 'semgrep scan --config .semgrep.yml .'
elif has_cmd semgrep;           then pick semgrep 'semgrep scan --config auto .'
fi
# dependency scanners
if   has_file pnpm-lock.yaml 2;    then pick 'pnpm audit' 'pnpm audit --json'
elif has_file yarn.lock 2;         then pick 'yarn audit' 'yarn audit --json'
elif has_file package-lock.json 2; then pick 'npm audit'  'npm audit --json'
fi
{ has_cmd pip-audit && { has_file 'requirements*.txt' 2 || [[ -f pyproject.toml ]]; }; } && pick pip-audit 'pip-audit --format=json'
has_cmd osv-scanner && pick osv-scanner 'osv-scanner --recursive --format json .'
has_cmd trivy       && pick 'trivy fs'  'trivy fs --format json .'
has_cmd snyk        && pick snyk        'snyk test --json'

if [[ -n "$names" ]]; then
  mk_report security 05 universal true always "$(tooling "$names")" "$primary" critical moderate '[]' ready "mandatory; scanners: $names (+/cook semantic pass)"
else
  # no scanner: still mandatory — degrade to the /cook semantic pass, never opt out
  mk_report security 05 universal false always "$NO_TOOLING" "universal/protocol-security.md" critical moderate '[]' no_tooling "mandatory; no scanner detected — degrades to the /cook semantic pass (AC-PF2/PF12)"
fi
