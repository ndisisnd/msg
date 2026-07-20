#!/usr/bin/env bash
# preflight-check-06-coverage.sh — detect+normalize the `coverage` check.
# id 06 · group universal · kind script · active_when always · criticality config-driven
# depends_on {unit, integration} (parses their output — hard edge, AC-CAT3).
# Schema: .claude/skills/shared/refs/check-report-schema.md (detect section).
# Emits to .pre-merge/preflight/coverage.json + stdout. Never hardcodes a tool (AC-CK3).
ROOT="${1:-.}"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" || { echo "cannot cd to $ROOT" >&2; exit 1; }
. "$DIR/preflight-common.sh"

DEPS='["unit","integration"]'

name=""; cmd=""
if   pubspec_flutter;                                    then name=Flutter;        cmd='flutter test --coverage'
elif pkg_dep vitest || has_file 'vitest.config.*' 3;     then name='Vitest coverage'; cmd='npx vitest run --coverage'
elif pkg_dep jest   || has_file 'jest.config.*' 3;       then name=Jest;           cmd='npx jest --coverage --coverageReporters=json-summary'
elif pkg_dep nyc    || has_file '.nycrc' 3;              then name=NYC;            cmd='npx nyc --reporter=lcov npm test'
elif has_file 'pytest.ini' 3 || pyproject_has '\[tool\.coverage' || setupcfg_has '\[coverage'; then
  name=pytest-cov; cmd='pytest --cov --cov-report=lcov'
elif [[ -f go.mod ]];                                    then name=Go;             cmd='go test -coverprofile=coverage.out ./...'
fi

# config-driven criticality: advisory unless the project configures explicit thresholds
if [[ -n "$name" ]]; then
  mk_report coverage 06 universal true always "$(tooling "$name")" "$cmd" config-driven moderate "$DEPS" ready "coverage runner: $name"
else
  mk_report coverage 06 universal false always "$NO_TOOLING" "" config-driven moderate "$DEPS" no_tooling "no coverage runner detected"
fi
