#!/usr/bin/env bash
# Run tooling detection per ../shared/refs/tooling-detection.md and print the
# detected object as JSON. Intended as a thin wrapper for pre-merge Step 2.
# Usage: detect-tooling.sh
# Output: JSON to stdout with package_manager, test_runner, e2e_runner,
#         build_tool, mechanical_runners, security_scanners, bundle_analyzer

set -euo pipefail

# ── Package manager ──────────────────────────────────────────────────────────

PKG_MGR="null"
PKG_PREFIX="null"

if [ -f pnpm-lock.yaml ] || find . -maxdepth 2 -name "pnpm-lock.yaml" -quit 2>/dev/null | grep -q .; then
  PKG_MGR="pnpm"; PKG_PREFIX="pnpm"
elif [ -f yarn.lock ] || find . -maxdepth 2 -name "yarn.lock" -quit 2>/dev/null | grep -q .; then
  PKG_MGR="yarn"; PKG_PREFIX="yarn"
elif [ -f package-lock.json ] || find . -maxdepth 2 -name "package-lock.json" -quit 2>/dev/null | grep -q .; then
  PKG_MGR="npm"; PKG_PREFIX="npm"
elif find . -maxdepth 2 -name "pubspec.yaml" -quit 2>/dev/null | grep -q .; then
  PKG_MGR="pub"; PKG_PREFIX="flutter pub"
elif find . -maxdepth 1 -name "pyproject.toml" 2>/dev/null | xargs grep -l '\[tool.poetry\]' 2>/dev/null | grep -q .; then
  PKG_MGR="poetry"; PKG_PREFIX="poetry run"
elif find . -maxdepth 1 -name "requirements*.txt" -quit 2>/dev/null | grep -q .; then
  PKG_MGR="pip"; PKG_PREFIX="pip"
fi

# ── Test runner ───────────────────────────────────────────────────────────────

TEST_RUNNER="null"

if find . -maxdepth 3 -name "vitest.config.*" -quit 2>/dev/null | grep -q . || \
   ([ -f package.json ] && grep -q '"vitest"' package.json 2>/dev/null); then
  TEST_RUNNER='{"name":"vitest","command":"npx vitest run --coverage <files>","coverage_output":"coverage/coverage-summary.json","ci_override":false}'
elif find . -maxdepth 3 -name "jest.config.*" -quit 2>/dev/null | grep -q . || \
   ([ -f package.json ] && grep -q '"jest"' package.json 2>/dev/null); then
  TEST_RUNNER='{"name":"jest","command":"npx jest --coverage --testPathPattern=<files>","coverage_output":"coverage/coverage-summary.json","ci_override":false}'
fi

# ── E2E runner ────────────────────────────────────────────────────────────────

E2E_RUNNER="null"

if find . -maxdepth 3 -name "playwright.config.*" -quit 2>/dev/null | grep -q . || \
   ([ -f package.json ] && grep -q '"@playwright/test"' package.json 2>/dev/null); then
  E2E_RUNNER='{"name":"playwright","command":"npx playwright test","config_path":null}'
elif find . -maxdepth 3 -name "cypress.config.*" -quit 2>/dev/null | grep -q . || \
   ([ -f package.json ] && grep -q '"cypress"' package.json 2>/dev/null); then
  E2E_RUNNER='{"name":"cypress","command":"npx cypress run","config_path":null}'
fi

# ── Build tool ────────────────────────────────────────────────────────────────

BUILD_TOOL="null"

if [ -f package.json ] && grep -q '"next"' package.json 2>/dev/null; then
  BUILD_TOOL='{"name":"next","command":"next build","output_dir":".next/"}'
elif find . -maxdepth 3 -name "vite.config.*" -quit 2>/dev/null | grep -q .; then
  BUILD_TOOL='{"name":"vite","command":"vite build","output_dir":"dist/"}'
elif find . -maxdepth 3 -name "tsup.config.*" -quit 2>/dev/null | grep -q .; then
  BUILD_TOOL='{"name":"tsup","command":"tsup","output_dir":"dist/"}'
elif find . -maxdepth 1 -name "tsconfig.json" -quit 2>/dev/null | grep -q .; then
  BUILD_TOOL='{"name":"typescript","command":"tsc --noEmit","output_dir":null}'
fi

# ── Security scanners ─────────────────────────────────────────────────────────

SEC_SCANNERS="[]"
SEC_LIST=""

if command -v gitleaks &>/dev/null; then
  SEC_LIST="${SEC_LIST}{\"name\":\"gitleaks\",\"type\":\"secret\",\"command_diff\":\"gitleaks detect --no-git --source=<files> --no-banner --redact\",\"command_full\":\"gitleaks detect\",\"severity_on_hit\":\"block\"},"
fi
if command -v semgrep &>/dev/null; then
  SEC_LIST="${SEC_LIST}{\"name\":\"semgrep\",\"type\":\"sast\",\"command_diff\":\"semgrep scan --config auto <files>\",\"command_full\":\"semgrep scan --config auto .\",\"severity_on_hit\":\"block\"},"
fi
if [ "$PKG_MGR" = "pnpm" ]; then
  SEC_LIST="${SEC_LIST}{\"name\":\"pnpm-audit\",\"type\":\"dependency\",\"command_diff\":\"pnpm audit --json\",\"command_full\":\"pnpm audit --json\",\"severity_on_hit\":\"block\"},"
elif [ "$PKG_MGR" = "npm" ]; then
  SEC_LIST="${SEC_LIST}{\"name\":\"npm-audit\",\"type\":\"dependency\",\"command_diff\":\"npm audit --json\",\"command_full\":\"npm audit --json\",\"severity_on_hit\":\"block\"},"
fi

if [ -n "$SEC_LIST" ]; then
  SEC_SCANNERS="[${SEC_LIST%,}]"
fi

# ── Bundle analyzer ───────────────────────────────────────────────────────────

BUNDLE="null"

if [ -f package.json ] && grep -q '@next/bundle-analyzer' package.json 2>/dev/null; then
  BUNDLE='{"name":"@next/bundle-analyzer","command":"ANALYZE=true next build","baseline_path":null}'
elif [ -f package.json ] && grep -q 'source-map-explorer' package.json 2>/dev/null; then
  BUNDLE='{"name":"source-map-explorer","command":"source-map-explorer '\''build/static/js/*.js'\''","baseline_path":null}'
fi

# ── Emit ──────────────────────────────────────────────────────────────────────

cat <<EOF
{
  "package_manager": $([ "$PKG_MGR" = "null" ] && echo null || echo "{\"name\":\"${PKG_MGR}\",\"run_prefix\":\"${PKG_PREFIX}\"}"),
  "test_runner": ${TEST_RUNNER},
  "e2e_runner": ${E2E_RUNNER},
  "build_tool": ${BUILD_TOOL},
  "mechanical_runners": [],
  "security_scanners": ${SEC_SCANNERS},
  "bundle_analyzer": ${BUNDLE}
}
EOF
