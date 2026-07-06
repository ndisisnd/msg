#!/usr/bin/env bash
# test-tooling-detect.sh — emit a single JSON fingerprint of detected tooling.
# Consumed by /test (runner buckets) and by /review + /pre-merge Step 2
# (build_tool, mechanical_runners, security_scanners/secret_scanner,
# bundle_analyzer). Replaces the LLM's manual priority-table walk over
# file / $PATH / package.json signals so a missed signal can't silently skip a
# check. The emitted shapes mirror shared/refs/tooling-detection.md (maintainer doc).
#
# What the script DOES:
#   - File existence checks (configs, lockfiles, source trees)
#   - $PATH probes (command -v)
#   - package.json dep / devDep / script / top-level-field lookups (via jq)
#   - pubspec.yaml dependency presence checks
#   - Returns the first-match per priority table per the test refs
#
# What the script does NOT do (left to /test SKILL.md):
#   - CI workflow override extraction (npm run test:*) — needs human-readable
#     intent matching; SKILL.md applies the override after reading this output
#   - <files> / <url> / <script> placeholder substitution — depends on diff scope
#   - Runner execution
#   - Multi-runner subtleties (e.g. detecting BOTH Playwright visual and
#     Playwright e2e on the same config — script reports e2e_runner; SKILL.md
#     promotes the same runner to qa_runner if snapshot dirs exist)
#
# Usage:    test-tooling-detect.sh [project-root]    (default: .)
# Output:   single JSON object to stdout
# Exit:     0 always (detection is non-fatal); errors → stderr

set -uo pipefail

ROOT="${1:-.}"
cd "$ROOT" || { echo "cannot cd to $ROOT" >&2; exit 1; }

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required (brew install jq)" >&2
  exit 1
fi

# ---------- helpers ----------
has_cmd() { command -v "$1" >/dev/null 2>&1; }

# Find a file by glob up to max depth, excluding node_modules/.git/.fvm
has_file() {
  local glob="$1" depth="${2:-3}"
  find . -maxdepth "$depth" \
    \( -path './node_modules' -o -path './.git' -o -path '*/node_modules' \) -prune -o \
    -name "$glob" -print 2>/dev/null | grep -q .
}

# Find a directory by glob up to max depth
has_dir() {
  local glob="$1" depth="${2:-3}"
  find . -maxdepth "$depth" \
    \( -path './node_modules' -o -path './.git' -o -path '*/node_modules' \) -prune -o \
    -type d -name "$glob" -print 2>/dev/null | grep -q .
}

pkg_dep() {
  [[ -f package.json ]] || return 1
  jq -e --arg k "$1" '
    ((.dependencies // {}) | has($k)) or
    ((.devDependencies // {}) | has($k))
  ' package.json >/dev/null 2>&1
}

pkg_field() {
  [[ -f package.json ]] || return 1
  jq -e --arg k "$1" 'has($k)' package.json >/dev/null 2>&1
}

pkg_script() {
  [[ -f package.json ]] || return 1
  jq -e --arg k "$1" '(.scripts // {}) | has($k)' package.json >/dev/null 2>&1
}

pubspec_flutter() {
  [[ -f pubspec.yaml ]] && grep -qE '^[[:space:]]*flutter[[:space:]]*:' pubspec.yaml
}

pubspec_dep() {
  [[ -f pubspec.yaml ]] && grep -qE "^[[:space:]]+${1}[[:space:]]*:" pubspec.yaml
}

py_signal() {
  grep -qE "^${1}" requirements*.txt 2>/dev/null && return 0
  [[ -f pyproject.toml ]] && grep -qE "$2" pyproject.toml
}

pyproject_has() { [[ -f pyproject.toml ]] && grep -qE "$1" pyproject.toml; }
req_has()       { grep -qE "^[[:space:]]*${1}" requirements*.txt 2>/dev/null; }
setupcfg_has()  { [[ -f setup.cfg ]] && grep -qE "$1" setup.cfg; }

# ---------- package_manager ----------
pm=null
if   has_file pnpm-lock.yaml 2;          then pm='{"name":"pnpm","run_prefix":"pnpm"}'
elif has_file yarn.lock 2;               then pm='{"name":"yarn","run_prefix":"yarn"}'
elif has_file package-lock.json 2;       then pm='{"name":"npm","run_prefix":"npm"}'
elif has_file pubspec.yaml 2;            then pm='{"name":"pub","run_prefix":"flutter pub"}'
elif [[ -f pyproject.toml ]] && grep -q '\[tool.poetry\]' pyproject.toml; then
                                             pm='{"name":"poetry","run_prefix":"poetry run"}'
elif has_file poetry.lock 2;             then pm='{"name":"poetry","run_prefix":"poetry run"}'
elif has_file 'requirements*.txt' 2;     then pm='{"name":"pip","run_prefix":"pip"}'
fi

# ---------- test_runner ----------
tr=null
if   pkg_dep vitest || has_file 'vitest.config.*' 3; then
  tr='{"name":"Vitest","command":"npx vitest run --coverage <files>","coverage_output":"coverage/coverage-summary.json","ci_override":false}'
elif pkg_dep jest || has_file 'jest.config.*' 3; then
  tr='{"name":"Jest","command":"npx jest --coverage --testPathPattern=<files>","coverage_output":"coverage/coverage-summary.json","ci_override":false}'
elif pkg_dep mocha || has_file '.mocharc.*' 3; then
  tr='{"name":"Mocha","command":"npx nyc npx mocha <files>","coverage_output":".nyc_output/coverage-summary.json","ci_override":false}'
elif py_signal pytest '\[tool\.pytest'; then
  tr='{"name":"pytest","command":"pytest --cov=<files> --cov-report=json","coverage_output":"coverage.json","ci_override":false}'
elif pubspec_flutter; then
  tr='{"name":"Dart/Flutter","command":"flutter test <file>","coverage_output":null,"ci_override":false}'
fi

# ---------- e2e_runner ----------
er=null
if   has_file 'playwright.config.*' 3 || pkg_dep '@playwright/test'; then
  cfg=$(find . -maxdepth 3 -name 'playwright.config.*' -not -path '*/node_modules/*' 2>/dev/null | head -1)
  er=$(jq -nc --arg c "${cfg#./}" '{name:"Playwright", command:"npx playwright test", config_path: (if $c == "" then null else $c end)}')
elif has_file 'cypress.config.*' 3 || pkg_dep cypress; then
  cfg=$(find . -maxdepth 3 -name 'cypress.config.*' -not -path '*/node_modules/*' 2>/dev/null | head -1)
  er=$(jq -nc --arg c "${cfg#./}" '{name:"Cypress", command:"npx cypress run", config_path: (if $c == "" then null else $c end)}')
elif pubspec_flutter && [[ -d integration_test ]]; then
  er='{"name":"Flutter integration test","command":"flutter test integration_test/","config_path":null}'
fi

# ---------- qa_runner ----------
qr=null
if has_file 'playwright.config.*' 3 && \
   ( has_dir '__screenshots__' 4 || \
     find . -maxdepth 5 -type f -name '*.png' -path '*snapshot*' -not -path '*/node_modules/*' 2>/dev/null | grep -q . ); then
  qr='{"name":"Playwright visual","command":"npx playwright test --update-snapshots=false"}'
elif pkg_dep chromatic || pkg_script chromatic; then
  qr='{"name":"Chromatic","command":"npx chromatic --exit-zero-on-changes=false"}'
elif pkg_dep '@percy/cli' || has_file .percy.yml 2; then
  qr='{"name":"Percy","command":"npx percy exec -- <e2e_runner.command>"}'
elif has_file backstop.json 2 || pkg_dep backstopjs; then
  qr='{"name":"BackstopJS","command":"npx backstop test"}'
elif pkg_dep loki || pkg_script loki; then
  qr='{"name":"Loki","command":"npx loki test"}'
fi

# ---------- load_runner ----------
lr=null
if   has_cmd k6 || pkg_script k6; then
  lr='{"name":"k6","command":"k6 run <script>"}'
elif has_file 'artillery.yml' 2 || has_file 'artillery.json' 2 || pkg_dep artillery; then
  lr='{"name":"Artillery","command":"npx artillery run <config>"}'
elif has_file 'locustfile.py' 3; then
  lr='{"name":"Locust","command":"locust --headless -u 10 -r 2 --run-time 30s"}'
elif pkg_dep autocannon || pkg_script autocannon; then
  lr='{"name":"autocannon","command":"npx autocannon <url>"}'
elif has_cmd wrk; then
  lr='{"name":"wrk","command":"wrk -t4 -c100 -d30s <url>"}'
elif has_cmd hey; then
  lr='{"name":"hey","command":"hey -n 1000 <url>"}'
fi

# ---------- a11y_runner ----------
ar=null
if   pkg_dep '@axe-core/cli' || pkg_script axe; then
  ar='{"name":"axe-core CLI","command":"npx axe <urls> --reporter json"}'
elif pkg_dep axe-playwright; then
  ar='{"name":"axe-playwright","command":"npx playwright test"}'
elif pkg_dep jest-axe; then
  ar='{"name":"jest-axe","command":"npx jest --testPathPattern=a11y"}'
elif pkg_dep pa11y || pkg_dep pa11y-ci || pkg_script pa11y; then
  ar='{"name":"pa11y","command":"npx pa11y-ci"}'
elif pkg_dep lighthouse || pkg_dep '@lhci/cli' || pkg_script lhci; then
  ar='{"name":"Lighthouse (a11y)","command":"npx lhci autorun --collect.settings.onlyCategories=accessibility"}'
fi

# ---------- perf_runner (runtime + bundle sub-checks) ----------
pr_runtime=null
pr_bundle=null
if   has_file '.lighthouserc.*' 3 || has_file 'lighthouserc.js' 3 || pkg_dep '@lhci/cli' || pkg_script lhci; then
  pr_runtime='{"name":"Lighthouse CI","command":"npx lhci autorun"}'
elif pkg_dep web-vitals && has_file 'playwright.config.*' 3; then
  pr_runtime='{"name":"Playwright + web-vitals","command":"npx playwright test"}'
fi
if   pkg_field size-limit || pkg_dep size-limit; then
  pr_bundle='{"name":"size-limit","command":"npx size-limit --json"}'
elif pkg_field bundlesize || pkg_dep bundlesize; then
  pr_bundle='{"name":"bundlesize","command":"npx bundlesize"}'
fi
pr=$(jq -nc --argjson rt "$pr_runtime" --argjson bd "$pr_bundle" '
  if $rt == null and $bd == null then null
  else {runtime: $rt, bundle: $bd}
  end
')

# ---------- api_runner (multiple may co-exist) ----------
api_arr='[]'
api_add() { api_arr=$(jq -c --argjson e "$1" '. + [$e]' <<<"$api_arr"); }
if pkg_dep '@pact-foundation/pact' || pkg_dep pact || [[ -d pacts ]] || [[ -d .pact ]]; then
  api_add '{"name":"Pact","command":"npx pact verify"}'
fi
if pkg_dep newman || has_cmd newman; then
  api_add '{"name":"Newman","command":"npx newman run <collection>"}'
fi
if pkg_dep dredd || has_file 'dredd.yml' 3; then
  api_add '{"name":"Dredd","command":"npx dredd"}'
fi
if find . -maxdepth 4 -type f -name '*.hurl' -not -path '*/node_modules/*' 2>/dev/null | grep -q . && has_cmd hurl; then
  api_add '{"name":"Hurl","command":"hurl --test <files>"}'
fi
if has_file '.spectral.yaml' 3 || has_file '.spectral.json' 3 || pkg_dep '@stoplight/spectral-cli'; then
  api_add '{"name":"Spectral","command":"npx spectral lint <spec>"}'
fi
if pkg_dep ibm-openapi-validator || has_file '.validaterc' 3; then
  api_add '{"name":"openapi-validator","command":"npx ibm-openapi-validator <spec>"}'
fi
if [[ "$(jq 'length' <<<"$api_arr")" == "0" ]]; then
  api_runner=null
else
  api_runner="$api_arr"
fi

# ---------- mobile_runner ----------
mr=null
if pubspec_flutter; then
  base="flutter"
  if has_cmd fvm && [[ -d .fvm/flutter_sdk ]]; then base="fvm flutter"; fi
  patrol=false; pubspec_dep patrol && patrol=true
  maestro=false; { has_cmd maestro || [[ -d .maestro ]]; } && maestro=true
  has_test_dir=false;        [[ -d test ]] && has_test_dir=true
  has_integration_dir=false; [[ -d integration_test ]] && has_integration_dir=true
  mr=$(jq -nc \
    --arg name "$base" \
    --argjson patrol "$patrol" \
    --argjson maestro "$maestro" \
    --argjson test_dir "$has_test_dir" \
    --argjson integration_dir "$has_integration_dir" \
    '{
      name: $name,
      command: ($name + " test"),
      patrol: $patrol,
      maestro: $maestro,
      has_test_dir: $test_dir,
      has_integration_dir: $integration_dir
    }')
fi

# ---------- coverage_runner ----------
cr=null
if pubspec_flutter; then
  base="flutter"
  if has_cmd fvm && [[ -d .fvm/flutter_sdk ]]; then base="fvm flutter"; fi
  cr=$(jq -nc --arg b "$base" '{name:"Flutter", command:($b+" test --coverage"), report:"coverage/lcov.info"}')
elif pkg_dep jest || has_file 'jest.config.*' 3; then
  cr='{"name":"Jest","command":"npx jest --coverage --coverageReporters=json-summary","report":"coverage/coverage-summary.json"}'
elif pkg_dep nyc || has_file '.nycrc' 3; then
  cr='{"name":"NYC","command":"npx nyc --reporter=lcov npm test","report":"coverage/lcov.info"}'
elif has_file 'pytest.ini' 3 || \
     ( [[ -f pyproject.toml ]] && grep -q '\[tool.coverage' pyproject.toml ) || \
     ( [[ -f setup.cfg ]] && grep -q '\[coverage' setup.cfg ); then
  cr='{"name":"pytest-cov","command":"pytest --cov --cov-report=lcov","report":"coverage.lcov"}'
elif [[ -f go.mod ]]; then
  cr='{"name":"Go","command":"go test -coverprofile=coverage.out ./...","report":"coverage.out"}'
fi

# run_prefix + pm name extracted from $pm for command templating
run_prefix=$(jq -nr --argjson pm "$pm" '($pm.run_prefix // "npm")')
pm_name=$(jq -nr --argjson pm "$pm" '($pm.name // "")')

# ---------- build_tool ----------
bt=null
if   pkg_dep next; then
  bt='{"name":"Next.js","command":"next build","output_dir":".next/"}'
elif has_file 'astro.config.*' 3 || pkg_dep astro; then
  bt='{"name":"Astro","command":"astro build","output_dir":"dist/"}'
elif has_file 'svelte.config.*' 3 || pkg_dep '@sveltejs/kit'; then
  bt='{"name":"SvelteKit","command":"vite build","output_dir":"build/"}'
elif has_file 'vite.config.*' 3 || pkg_dep vite; then
  bt='{"name":"Vite","command":"vite build","output_dir":"dist/"}'
elif has_file 'tsup.config.*' 3 || pkg_dep tsup; then
  bt='{"name":"tsup","command":"tsup","output_dir":"dist/"}'
elif pkg_dep esbuild; then
  bt=$(jq -nc --arg rp "$run_prefix" '{name:"esbuild", command:($rp+" run build"), output_dir:"dist/"}')
elif has_file 'rollup.config.*' 3 || pkg_dep rollup; then
  bt='{"name":"Rollup","command":"rollup -c","output_dir":"dist/"}'
elif has_file 'webpack.config.*' 3 || pkg_dep webpack; then
  bt='{"name":"Webpack","command":"npx webpack","output_dir":"dist/"}'
elif pubspec_flutter; then
  bt='{"name":"Flutter","command":"flutter build apk --debug","output_dir":"build/"}'
elif has_file 'tsconfig.json' 3; then
  bt='{"name":"TypeScript","command":"tsc --noEmit","output_dir":null}'
fi
# `build` script override — CI parity: prefer the package.json build script command.
if [[ "$bt" != "null" ]] && pkg_script build; then
  bt=$(jq -nc --argjson bt "$bt" --arg rp "$run_prefix" '$bt + {command:($rp+" run build")}')
fi

# ---------- mechanical_runners[] ----------
mech='[]'
mech_add() { mech=$(jq -c --argjson e "$1" '. + [$e]' <<<"$mech"); }
mj() { # name command severity
  jq -nc --arg n "$1" --arg c "$2" --arg s "$3" \
    '{name:$n, command:$c, expects_zero_exit:true, severity_on_fail:$s}'
}
# JS/TS
{ has_file 'biome.json' 3 || pkg_dep '@biomejs/biome'; } && \
  mech_add "$(mj biome 'npx @biomejs/biome check <files>' warn)"
{ has_file 'eslint.config.*' 3 || has_file '.eslintrc.*' 3; } && \
  mech_add "$(mj eslint 'npx eslint <files>' warn)"
{ has_file '.prettierrc*' 3 || has_file 'prettier.config.*' 3 || pkg_dep prettier; } && \
  mech_add "$(mj prettier 'npx prettier --check <files>' warn)"
{ pkg_dep oxlint || has_file '.oxlintrc.json' 3; } && \
  mech_add "$(mj oxlint 'npx oxlint <files>' warn)"
{ has_file '.stylelintrc*' 3 || has_file 'stylelint.config.*' 3 || pkg_dep stylelint; } && \
  mech_add "$(mj stylelint 'npx stylelint <files>' warn)"
has_file 'tsconfig.json' 3 && \
  mech_add "$(mj tsc 'npx tsc --noEmit' block)"
# Python
{ pyproject_has '\[tool\.ruff' || has_file 'ruff.toml' 2 || has_file '.ruff.toml' 2; } && \
  mech_add "$(mj ruff 'ruff check <files>' warn)"
{ pyproject_has '\[tool\.black' || req_has black; } && \
  mech_add "$(mj black 'black --check <files>' warn)"
{ has_file '.flake8' 2 || setupcfg_has '\[flake8\]' || req_has flake8; } && \
  mech_add "$(mj flake8 'flake8 <files>' warn)"
{ has_file '.pylintrc' 2 || has_file 'pylintrc' 2 || req_has pylint; } && \
  mech_add "$(mj pylint 'pylint <files>' warn)"
{ pyproject_has '\[tool\.mypy' || has_file 'mypy.ini' 2 || req_has mypy; } && \
  mech_add "$(mj mypy 'mypy <files>' block)"
# Dart/Flutter
if pubspec_flutter; then
  has_file 'analysis_options.yaml' 3 && \
    mech_add "$(mj 'dart analyze' 'dart analyze <files>' block)"
  mech_add "$(mj 'dart format' 'dart format --output=none --set-exit-if-changed <files>' warn)"
fi
[[ "$(jq 'length' <<<"$mech")" == "0" ]] && mech=null

# ---------- security_scanners[] ----------
sec='[]'
sec_add() { sec=$(jq -c --argjson e "$1" '. + [$e]' <<<"$sec"); }
sj() { # name type command_diff command_full
  jq -nc --arg n "$1" --arg t "$2" --arg d "$3" --arg f "$4" \
    '{name:$n, type:$t, command_diff:(if $d=="" then null else $d end),
      command_full:$f, severity_on_hit:"block"}'
}
# secret scanners (priority order)
has_cmd gitleaks && \
  sec_add "$(sj gitleaks secret 'gitleaks detect --no-git --source=<files>' 'gitleaks detect')"
has_cmd trufflehog && \
  sec_add "$(sj trufflehog secret 'trufflehog filesystem --no-update --json <files>' 'trufflehog filesystem --no-update --json .')"
# SAST (`.semgrep.yml` project config wins over --config auto)
if has_file '.semgrep.yml' 2; then
  sec_add "$(sj 'semgrep (project config)' sast 'semgrep scan --config .semgrep.yml <files>' 'semgrep scan --config .semgrep.yml .')"
elif has_cmd semgrep; then
  sec_add "$(sj semgrep sast 'semgrep scan --config auto <files>' 'semgrep scan --config auto .')"
fi
# dependency scanners (full-tree; diff-scoping N/A → command_diff null)
case "$pm_name" in
  pnpm) sec_add "$(sj 'pnpm audit' dependency '' 'pnpm audit --json')";;
  npm)  sec_add "$(sj 'npm audit'  dependency '' 'npm audit --json')";;
  yarn) sec_add "$(sj 'yarn audit' dependency '' 'yarn audit --json')";;
esac
{ has_cmd pip-audit && { has_file 'requirements*.txt' 2 || [[ -f pyproject.toml ]]; }; } && \
  sec_add "$(sj pip-audit dependency '' 'pip-audit --format=json')"
has_cmd osv-scanner && \
  sec_add "$(sj osv-scanner dependency '' 'osv-scanner --recursive --format json .')"
has_cmd trivy && \
  sec_add "$(sj 'trivy fs' dependency '' 'trivy fs --format json .')"
has_cmd snyk && \
  sec_add "$(sj snyk dependency '' 'snyk test --json')"
# container scanners
{ { has_file 'Dockerfile' 2 || has_file 'docker-compose*.yml' 2; } && has_cmd trivy; } && \
  sec_add "$(sj 'trivy image' container '' 'trivy image --format json <image>')"
if [[ "$(jq 'length' <<<"$sec")" == "0" ]]; then
  sec=null; secret_scanner=null
else
  secret_scanner=$(jq -c 'map(select(.type=="secret")) | (.[0] // null)' <<<"$sec")
fi

# ---------- bundle_analyzer ----------
bt_cmd=$(jq -nr --argjson bt "$bt" '($bt.command // "<build_tool.command>")')
ba=null
if   pkg_dep '@next/bundle-analyzer'; then
  ba='{"name":"@next/bundle-analyzer","command":"ANALYZE=true next build","baseline_path":".next/analyze/"}'
elif pkg_dep webpack-bundle-analyzer; then
  ba='{"name":"webpack-bundle-analyzer","command":"webpack --json stats.json && webpack-bundle-analyzer stats.json --mode static --no-open","baseline_path":null}'
elif pkg_dep rollup-plugin-visualizer; then
  ba=$(jq -nc --arg c "$bt_cmd" '{name:"rollup-plugin-visualizer", command:$c, baseline_path:"stats.html"}')
elif pkg_dep source-map-explorer; then
  ba='{"name":"source-map-explorer","command":"source-map-explorer '"'"'build/static/js/*.js'"'"'","baseline_path":null}'
elif pkg_dep size-limit || has_file '.size-limit.json' 2 || pkg_field size-limit; then
  ba='{"name":"size-limit","command":"npx size-limit","baseline_path":".size-limit.json"}'
elif pkg_dep bundlesize || has_file '.bundlesizerc' 2; then
  ba='{"name":"bundlesize","command":"bundlesize","baseline_path":".bundlesizerc"}'
elif pkg_dep vite-bundle-visualizer; then
  ba='{"name":"vite-bundle-visualizer","command":"vite-bundle-visualizer","baseline_path":null}'
fi

# ---------- emit ----------
jq -n \
  --argjson package_manager "$pm" \
  --argjson test_runner     "$tr" \
  --argjson e2e_runner      "$er" \
  --argjson qa_runner       "$qr" \
  --argjson load_runner     "$lr" \
  --argjson a11y_runner     "$ar" \
  --argjson perf_runner     "$pr" \
  --argjson api_runner      "$api_runner" \
  --argjson mobile_runner   "$mr" \
  --argjson coverage_runner "$cr" \
  --argjson build_tool          "$bt" \
  --argjson mechanical_runners  "$mech" \
  --argjson security_scanners   "$sec" \
  --argjson secret_scanner      "$secret_scanner" \
  --argjson bundle_analyzer     "$ba" \
  '{
    package_manager:  $package_manager,
    test_runner:      $test_runner,
    e2e_runner:       $e2e_runner,
    qa_runner:        $qa_runner,
    load_runner:      $load_runner,
    a11y_runner:      $a11y_runner,
    perf_runner:      $perf_runner,
    api_runner:       $api_runner,
    mobile_runner:    $mobile_runner,
    coverage_runner:  $coverage_runner,
    build_tool:          $build_tool,
    mechanical_runners:  $mechanical_runners,
    security_scanners:   $security_scanners,
    secret_scanner:      $secret_scanner,
    bundle_analyzer:     $bundle_analyzer
  }'
