#!/usr/bin/env bash
# script-preflight-04-regression.sh — detect+normalize the `regression` check.
# id 04 · group universal · kind hybrid · active_when always · criticality blocking
# Tail-pinned: depends_on every other universal/prd component (C5). Its authoring
# sub-step is a spawned eng subagent (run-on-green); the accumulated suite runs last.
# Schema: .claude/skills/shared/refs/check-report-schema.md (detect section).
# Emits to .pre-merge/preflight/regression.json + stdout. Never hardcodes a tool (AC-CK3).
ROOT="${1:-.}"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" || { echo "cannot cd to $ROOT" >&2; exit 1; }
. "$DIR/script-check-common.sh"

DEPS='["mechanical","unit","integration","security","coverage","prd-consistency"]'

name=""; cmd=""
if   pkg_dep vitest || has_file 'vitest.config.*' 3; then name=Vitest; cmd='npx vitest run tests/regression'
elif pkg_dep jest   || has_file 'jest.config.*' 3;   then name=Jest;   cmd='npx jest tests/regression'
elif pkg_dep mocha  || has_file '.mocharc.*' 3;      then name=Mocha;  cmd='npx mocha tests/regression'
elif py_signal pytest '\[tool\.pytest' || has_file 'pytest.ini' 3;    then name=pytest; cmd='python3 -m pytest tests/regression'
elif pubspec_flutter; then name='Dart/Flutter'; cmd='flutter test test/regression'
elif has_file 'go.mod' 2;                             then name=Go;        cmd='go test ./tests/regression/...'
elif has_dir '*.xcodeproj' 3 || has_dir '*.xcworkspace' 3; then name=Xcodebuild; cmd='xcodebuild test -scheme <scheme> -only-testing:RegressionTests'
elif has_file 'build.gradle*' 3 || has_file 'settings.gradle*' 3; then name=Gradle; cmd='./gradlew test --tests *.regression.*'
fi

surface="none"; { has_dir regression 4 || has_path tests/regression; } && surface='tests/regression/'

# --- minified selection capability (policies.test_selection; see shared/refs/component-catalog.md § selection-capable tier) ---
# Selection-capable on the ACCUMULATED suite only (executor §3c.2) — this PRD's newly
# authored regression tests always run in full and are never selected away (AC-TS5);
# that contract lives in the executor/protocol, not here. Cheap, deterministic probes only.
run_minified=""; test_selector=""
case "$name" in
  Vitest)
    run_minified='npx vitest related --changed <base> tests/regression'
    test_selector='vitest related --changed (accumulated suite only)'
    ;;
  Jest)
    run_minified='npx jest --changedSince=<base> tests/regression'
    test_selector='jest --changedSince (accumulated suite only)'
    ;;
  pytest)
    if req_has 'pytest-testmon' || pyproject_has 'pytest-testmon'; then
      run_minified='python3 -m pytest --testmon tests/regression'
      test_selector='pytest-testmon (accumulated suite only)'
    else
      run_minified='python3 -m pytest -m critical tests/regression <files>'
      test_selector='pytest -m critical marker filter (accumulated suite only, no pytest-testmon detected)'
    fi
    ;;
  Go)
    run_minified='go test <affected_packages_regression>'
    test_selector='go list changed-package graph (accumulated suite only, reverse deps)'
    ;;
  Xcodebuild)
    if has_file 'Critical.xctestplan' 4; then
      run_minified='xcodebuild test -testPlan Critical'
      test_selector='xcodebuild -testPlan Critical (accumulated suite only)'
    else
      run_minified='xcodebuild test -only-testing:RegressionTests/<target>'
      test_selector='xcodebuild -only-testing target mapping (accumulated suite only, no Critical.xctestplan)'
    fi
    ;;
  Gradle)
    run_minified='./gradlew <affected_modules>:test --tests *.regression.* -Pandroid.testInstrumentationRunnerArguments.annotation=<critical_marker>'
    test_selector='gradle affected-module graph + annotation filter (accumulated suite only)'
    ;;
  *)
    : # Mocha/Flutter/unknown — no native selection support; stays null (silent full)
    ;;
esac

if [[ -n "$name" ]]; then
  # hybrid: script command (accumulated suite) + eng-subagent authoring (run-on-green)
  mk_report regression 04 universal true always "$(tooling "$name")" "$cmd" blocking expensive "$DEPS" ready "runner: $name; regression surface: $surface; authoring = spawned eng subagent (only-on-green)" "$run_minified" "$test_selector"
else
  # no runner: the component still exists — authoring/grading is the subagent protocol
  mk_report regression 04 universal false always "$NO_TOOLING" "universal/protocol-regression.md" blocking expensive "$DEPS" no_tooling "no test runner detected; regression surface: $surface" "" ""
fi
