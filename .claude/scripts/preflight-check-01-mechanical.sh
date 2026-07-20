#!/usr/bin/env bash
# preflight-check-01-mechanical.sh — detect+normalize the `mechanical` check.
# id 01 · group universal · kind script · active_when always · criticality critical
# Schema: .claude/skills/shared/refs/check-report-schema.md (detect section).
# Emits to .pre-merge/preflight/mechanical.json + stdout. Never hardcodes a tool (AC-CK3).
ROOT="${1:-.}"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" || { echo "cannot cd to $ROOT" >&2; exit 1; }
. "$DIR/preflight-common.sh"

names=""; cmds=""
add() { names="${names:+$names,}$1"; cmds="${cmds:+$cmds; }$2"; }

# JS/TS
{ has_file 'biome.json' 3 || pkg_dep '@biomejs/biome'; }                    && add biome    'npx @biomejs/biome check <files>'
{ has_file 'eslint.config.*' 3 || has_file '.eslintrc.*' 3; }              && add eslint   'npx eslint <files>'
{ has_file '.prettierrc*' 3 || has_file 'prettier.config.*' 3 || pkg_dep prettier; } && add prettier 'npx prettier --check <files>'
{ pkg_dep oxlint || has_file '.oxlintrc.json' 3; }                         && add oxlint   'npx oxlint <files>'
{ has_file '.stylelintrc*' 3 || has_file 'stylelint.config.*' 3 || pkg_dep stylelint; } && add stylelint 'npx stylelint <files>'
has_file 'tsconfig.json' 3                                                  && add tsc      'npx tsc --noEmit'
# Python
{ pyproject_has '\[tool\.ruff' || has_file 'ruff.toml' 2 || has_file '.ruff.toml' 2; } && add ruff   'ruff check <files>'
{ pyproject_has '\[tool\.black' || req_has black; }                        && add black    'black --check <files>'
{ has_file '.flake8' 2 || setupcfg_has '\[flake8\]' || req_has flake8; }    && add flake8   'flake8 <files>'
{ has_file '.pylintrc' 2 || has_file 'pylintrc' 2 || req_has pylint; }      && add pylint   'pylint <files>'
{ pyproject_has '\[tool\.mypy' || has_file 'mypy.ini' 2 || req_has mypy; }  && add mypy     'mypy <files>'
# Dart/Flutter
if pubspec_flutter; then
  has_file 'analysis_options.yaml' 3 && add dart-analyze 'dart analyze <files>'
  add dart-format 'dart format --output=none --set-exit-if-changed <files>'
fi

if [[ -n "$names" ]]; then
  mk_report mechanical 01 universal true always "$(tooling "$names")" "$cmds" critical cheap '[]' ready "detected: $names"
else
  mk_report mechanical 01 universal false always "$NO_TOOLING" "" critical cheap '[]' no_tooling "no lint/format/typecheck tooling detected"
fi
