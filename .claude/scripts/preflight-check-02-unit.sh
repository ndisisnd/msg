#!/usr/bin/env bash
# preflight-check-02-unit.sh — detect+normalize the `unit` check.
# id 02 · group universal · kind script · active_when always · criticality blocking
# Schema: .claude/skills/shared/refs/check-report-schema.md (detect section).
# Emits to .pre-merge/preflight/unit.json + stdout. Never hardcodes a tool (AC-CK3).
ROOT="${1:-.}"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" || { echo "cannot cd to $ROOT" >&2; exit 1; }
. "$DIR/preflight-common.sh"

name=""; cmd=""
if   pkg_dep vitest || has_file 'vitest.config.*' 3; then name=Vitest; cmd='npx vitest run <files>'
elif pkg_dep jest   || has_file 'jest.config.*' 3;   then name=Jest;   cmd='npx jest <files>'
elif pkg_dep mocha  || has_file '.mocharc.*' 3;      then name=Mocha;  cmd='npx mocha <files>'
elif py_signal pytest '\[tool\.pytest';              then name=pytest; cmd='pytest <files>'
elif has_file 'pytest.ini' 3 || has_file 'conftest.py' 3 || \
     find tests test -maxdepth 3 -name 'test_*.py' -print -quit 2>/dev/null | grep -q .; then
  name=pytest; cmd='python3 -m pytest <files>'
elif pubspec_flutter; then name='Dart/Flutter'; cmd='flutter test <file>'
fi

if [[ -n "$name" ]]; then
  mk_report unit 02 universal true always "$(tooling "$name")" "$cmd" blocking cheap '[]' ready "unit runner: $name"
else
  mk_report unit 02 universal false always "$NO_TOOLING" "" blocking cheap '[]' no_tooling "no unit-test runner detected"
fi
