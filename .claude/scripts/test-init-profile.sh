#!/usr/bin/env bash
# test-init-profile.sh — emit a deterministic shape-profile of the codebase for
# `/test --init`. Answers "what KIND of project is this?" so the skill can map
# project shape → needed test buckets without re-deriving raw signals by LLM.
#
# Complements test-tooling-detect.sh (which reports what runners are INSTALLED).
# This script reports what the codebase IS, so the skill can compute the gap
# between "needed" and "installed".
#
# What the script DOES:
#   - Language detection by source-file extension counts
#   - Framework detection via package.json deps / pubspec.yaml / python configs
#   - App-shape flags: has_ui, has_http_api, has_db, has_openapi, is_cli,
#     is_library, is_mobile
#   - Existing-test presence (test dirs / *.test.* / *.spec.* files)
#
# What the script does NOT do (left to /test --init via refs/init.md):
#   - Mapping shape → needed buckets (intent matching)
#   - Choosing between competing tools (Playwright vs Cypress)
#   - Writing test.json or installing packages
#
# Usage:    test-init-profile.sh [project-root]    (default: .)
# Output:   single JSON object to stdout
# Exit:     0 always (profiling is non-fatal); errors → stderr

set -uo pipefail

ROOT="${1:-.}"
cd "$ROOT" || { echo "cannot cd to $ROOT" >&2; exit 1; }

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required (brew install jq)" >&2
  exit 1
fi

# ---------- helpers ----------
has_cmd() { command -v "$1" >/dev/null 2>&1; }

PRUNE=( \( -path './node_modules' -o -path './.git' -o -path '*/node_modules' -o -path './.fvm' -o -path './build' -o -path './dist' \) -prune )

has_file() {
  local glob="$1" depth="${2:-4}"
  find . -maxdepth "$depth" "${PRUNE[@]}" -o -name "$glob" -print 2>/dev/null | grep -q .
}

has_dir() {
  local glob="$1" depth="${2:-4}"
  find . -maxdepth "$depth" "${PRUNE[@]}" -o -type d -name "$glob" -print 2>/dev/null | grep -q .
}

count_ext() {
  find . -maxdepth 6 "${PRUNE[@]}" -o -type f -name "*.$1" -print 2>/dev/null | grep -c . | tr -d ' '
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

pubspec_flutter() {
  [[ -f pubspec.yaml ]] && grep -qE '^[[:space:]]*flutter[[:space:]]*:' pubspec.yaml
}

py_dep() {
  grep -qiE "^${1}([=<>!~ ]|$)" requirements*.txt 2>/dev/null && return 0
  { [[ -f pyproject.toml ]] && grep -qiE "[\"']?${1}[\"']?[ =><~]" pyproject.toml; } && return 0
  return 1
}

# ---------- languages ----------
ts=$(( $(count_ext ts) + $(count_ext tsx) ))
js=$(( $(count_ext js) + $(count_ext jsx) ))
py=$(count_ext py)
dart=$(count_ext dart)
go=$(( $([[ -f go.mod ]] && echo 1 || echo 0) ))
languages=$(jq -nc \
  --argjson ts "$ts" --argjson js "$js" --argjson py "$py" --argjson dart "$dart" --argjson go "$go" '
  [ (if $ts>0 then "typescript" else empty end),
    (if $js>0 then "javascript" else empty end),
    (if $py>0 then "python" else empty end),
    (if $dart>0 then "dart" else empty end),
    (if $go>0 then "go" else empty end) ]')

# ---------- frameworks ----------
fw='[]'
fw_add() { fw=$(jq -c --arg e "$1" '. + [$e]' <<<"$fw"); }
pkg_dep react        && fw_add react
pkg_dep next         && fw_add next
pkg_dep vue          && fw_add vue
pkg_dep svelte       && fw_add svelte
pkg_dep '@angular/core' && fw_add angular
pkg_dep express      && fw_add express
pkg_dep fastify      && fw_add fastify
pkg_dep '@nestjs/core' && fw_add nestjs
pkg_dep koa          && fw_add koa
py_dep fastapi       && fw_add fastapi
py_dep flask         && fw_add flask
py_dep django        && fw_add django
pubspec_flutter      && fw_add flutter

# ---------- app-shape flags ----------
has_ui=false
{ [[ $(count_ext tsx) -gt 0 || $(count_ext jsx) -gt 0 ]] || \
  has_file '*.vue' 6 || has_file '*.svelte' 6 || \
  pkg_dep react || pkg_dep vue || pkg_dep svelte || pkg_dep '@angular/core' || pkg_dep next || \
  pubspec_flutter; } && has_ui=true

is_mobile=false
pubspec_flutter && is_mobile=true

has_http_api=false
{ pkg_dep express || pkg_dep fastify || pkg_dep '@nestjs/core' || pkg_dep koa || pkg_dep hapi || \
  py_dep fastapi || py_dep flask || py_dep django || \
  has_dir 'controllers' 4 || has_dir 'routes' 4 || \
  find . -maxdepth 5 "${PRUNE[@]}" -o -type d -path '*api*' -print 2>/dev/null | grep -q . ; } && has_http_api=true

has_db=false
{ pkg_dep prisma || pkg_dep '@prisma/client' || pkg_dep typeorm || pkg_dep sequelize || \
  pkg_dep mongoose || pkg_dep knex || pkg_dep 'drizzle-orm' || \
  py_dep sqlalchemy || py_dep django || \
  has_file 'schema.prisma' 4 || has_dir 'migrations' 4; } && has_db=true

has_openapi=false
{ has_file 'openapi.yaml' 4 || has_file 'openapi.json' 4 || has_file 'openapi.yml' 4 || \
  has_file 'swagger.yaml' 4 || has_file 'swagger.json' 4; } && has_openapi=true

is_cli=false
pkg_field bin && is_cli=true

is_library=false
{ [[ "$has_ui" == false && "$has_http_api" == false && "$is_cli" == false ]] && \
  { pkg_field main || pkg_field exports || pkg_field module; }; } && is_library=true

# ---------- existing test presence ----------
has_tests=false
{ has_dir '__tests__' 5 || has_dir 'test' 3 || has_dir 'tests' 3 || \
  find . -maxdepth 6 "${PRUNE[@]}" -o -type f \( -name '*.test.*' -o -name '*.spec.*' -o -name '*_test.*' \) -print 2>/dev/null | grep -q . ; } && has_tests=true

# ---------- derive a coarse project type ----------
ptype="unknown"
if   [[ "$is_mobile" == true ]];                              then ptype="mobile"
elif [[ "$has_ui" == true && "$has_http_api" == true ]];     then ptype="fullstack"
elif [[ "$has_ui" == true ]];                                then ptype="web-frontend"
elif [[ "$has_http_api" == true ]];                          then ptype="backend-api"
elif [[ "$is_cli" == true ]];                                then ptype="cli"
elif [[ "$is_library" == true ]];                            then ptype="library"
fi

# ---------- emit ----------
jq -n \
  --arg project_type "$ptype" \
  --argjson languages "$languages" \
  --argjson frameworks "$fw" \
  --argjson has_ui "$has_ui" \
  --argjson has_http_api "$has_http_api" \
  --argjson has_db "$has_db" \
  --argjson has_openapi "$has_openapi" \
  --argjson is_cli "$is_cli" \
  --argjson is_library "$is_library" \
  --argjson is_mobile "$is_mobile" \
  --argjson has_tests "$has_tests" \
  '{
    project_type: $project_type,
    languages:    $languages,
    frameworks:   $frameworks,
    shape: {
      has_ui:       $has_ui,
      has_http_api: $has_http_api,
      has_db:       $has_db,
      has_openapi:  $has_openapi,
      is_cli:       $is_cli,
      is_library:   $is_library,
      is_mobile:    $is_mobile
    },
    has_existing_tests: $has_tests
  }'
