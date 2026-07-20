#!/usr/bin/env bash
# preflight-check-04-regression.sh — detect+normalize the `regression` check.
# id 04 · group universal · kind hybrid · active_when always · criticality blocking
# Tail-pinned: depends_on every other universal/prd component (C5). Its authoring
# sub-step is a spawned eng subagent (run-on-green); the accumulated suite runs last.
# Schema: .claude/skills/shared/refs/check-report-schema.md (detect section).
# Emits to .pre-merge/preflight/regression.json + stdout. Never hardcodes a tool (AC-CK3).
ROOT="${1:-.}"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" || { echo "cannot cd to $ROOT" >&2; exit 1; }
. "$DIR/preflight-common.sh"

DEPS='["mechanical","unit","integration","security","coverage","prd-consistency"]'

name=""; cmd=""
if   pkg_dep vitest || has_file 'vitest.config.*' 3; then name=Vitest; cmd='npx vitest run tests/regression'
elif pkg_dep jest   || has_file 'jest.config.*' 3;   then name=Jest;   cmd='npx jest tests/regression'
elif pkg_dep mocha  || has_file '.mocharc.*' 3;      then name=Mocha;  cmd='npx mocha tests/regression'
elif py_signal pytest '\[tool\.pytest' || has_file 'pytest.ini' 3;    then name=pytest; cmd='python3 -m pytest tests/regression'
elif pubspec_flutter; then name='Dart/Flutter'; cmd='flutter test test/regression'
fi

surface="none"; { has_dir regression 4 || has_path tests/regression; } && surface='tests/regression/'

if [[ -n "$name" ]]; then
  # hybrid: script command (accumulated suite) + eng-subagent authoring (run-on-green)
  mk_report regression 04 universal true always "$(tooling "$name")" "$cmd" blocking expensive "$DEPS" ready "runner: $name; regression surface: $surface; authoring = spawned eng subagent (only-on-green)"
else
  # no runner: the component still exists — authoring/grading is the subagent protocol
  mk_report regression 04 universal false always "$NO_TOOLING" "universal/protocol-regression.md" blocking expensive "$DEPS" no_tooling "no test runner detected; regression surface: $surface"
fi
