#!/usr/bin/env bash
# preflight-check-03-integration.sh — detect+normalize the `integration` check.
# id 03 · group universal · kind script · active_when always · criticality blocking
# Shares the test-runner fingerprint with `unit` but adds an integration-surface probe.
# Schema: .claude/skills/shared/refs/check-report-schema.md (detect section).
# Emits to .pre-merge/preflight/integration.json + stdout. Never hardcodes a tool (AC-CK3).
ROOT="${1:-.}"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" || { echo "cannot cd to $ROOT" >&2; exit 1; }
. "$DIR/preflight-common.sh"

# same runner detection as unit (detection split from unit lands here in Phase 2)
name=""; cmd=""
if   pkg_dep vitest || has_file 'vitest.config.*' 3; then name=Vitest; cmd='npx vitest run <files>'
elif pkg_dep jest   || has_file 'jest.config.*' 3;   then name=Jest;   cmd='npx jest <files>'
elif pkg_dep mocha  || has_file '.mocharc.*' 3;      then name=Mocha;  cmd='npx mocha <files>'
elif py_signal pytest '\[tool\.pytest';              then name=pytest; cmd='pytest <files>'
elif has_file 'pytest.ini' 3 || has_file 'conftest.py' 3 || \
     find tests test -maxdepth 3 -name 'test_*.py' -print -quit 2>/dev/null | grep -q .; then
  name=pytest; cmd='python3 -m pytest <files>'
elif pubspec_flutter; then name='Dart/Flutter'; cmd='flutter test integration_test/'
fi

# integration-surface probe (new — the old detector has none)
surface="none"
if   has_dir integration_test 4;                          then surface='integration_test/'
elif has_dir integration 4;                                then surface='integration/'
elif has_file '*.integration.test.*' 4;                    then surface='*.integration.test.*'
elif has_file '*_integration_test.dart' 4;                 then surface='*_integration_test.dart'
fi

if [[ -n "$name" ]]; then
  mk_report integration 03 universal true always "$(tooling "$name")" "$cmd" blocking moderate '[]' ready "runner: $name; integration surface: $surface"
else
  mk_report integration 03 universal false always "$NO_TOOLING" "" blocking moderate '[]' no_tooling "no test runner detected; integration surface: $surface"
fi
