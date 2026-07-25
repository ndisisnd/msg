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
elif has_file 'go.mod' 2;                             then name=Go;        cmd='go test ./...'
elif has_dir '*.xcodeproj' 3 || has_dir '*.xcworkspace' 3; then name=Xcodebuild; cmd='xcodebuild test -scheme <scheme>'
elif has_file 'build.gradle*' 3 || has_file 'settings.gradle*' 3; then name=Gradle; cmd='./gradlew test'
fi

# integration-surface probe (new — the old detector has none)
surface="none"
if   has_dir integration_test 4;                          then surface='integration_test/'
elif has_dir integration 4;                                then surface='integration/'
elif has_file '*.integration.test.*' 4;                    then surface='*.integration.test.*'
elif has_file '*_integration_test.dart' 4;                 then surface='*_integration_test.dart'
fi

# --- minified selection capability (Wave 2C, plan-msg-test-selection.md §3) ---
# NOTE (executor §3c.1): at tier M, `integration` ALWAYS runs full regardless of
# run_minified — this field only matters at tier S. Cheap, deterministic probes only.
run_minified=""; test_selector=""
case "$name" in
  Vitest)
    run_minified='npx vitest related --changed <base>'
    test_selector='vitest related --changed'
    ;;
  Jest)
    run_minified='npx jest --changedSince=<base>'
    test_selector='jest --changedSince'
    ;;
  pytest)
    if req_has 'pytest-testmon' || pyproject_has 'pytest-testmon'; then
      run_minified='python3 -m pytest --testmon'
      test_selector='pytest-testmon'
    else
      run_minified='python3 -m pytest -m critical <files>'
      test_selector='pytest -m critical marker filter (no pytest-testmon detected)'
    fi
    ;;
  Go)
    run_minified='go test <affected_packages>'
    test_selector='go list changed-package graph (reverse deps)'
    ;;
  Xcodebuild)
    if has_file 'Critical.xctestplan' 4; then
      run_minified='xcodebuild test -testPlan Critical'
      test_selector='xcodebuild -testPlan Critical'
    else
      run_minified='xcodebuild test -only-testing:<target>'
      test_selector='xcodebuild -only-testing target mapping (no Critical.xctestplan)'
    fi
    ;;
  Gradle)
    run_minified='./gradlew <affected_modules>:test -Pandroid.testInstrumentationRunnerArguments.annotation=<critical_marker>'
    test_selector='gradle affected-module graph + annotation filter'
    ;;
  *)
    : # Mocha/Flutter/unknown — no native selection support; stays null (silent full)
    ;;
esac

if [[ -n "$name" ]]; then
  mk_report integration 03 universal true always "$(tooling "$name")" "$cmd" blocking moderate '[]' ready "runner: $name; integration surface: $surface" "$run_minified" "$test_selector"
else
  mk_report integration 03 universal false always "$NO_TOOLING" "" blocking moderate '[]' no_tooling "no test runner detected; integration surface: $surface" "" ""
fi
