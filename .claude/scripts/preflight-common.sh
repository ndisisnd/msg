#!/usr/bin/env bash
# preflight-common.sh — shared helpers + normalized emit for the preflight-check-*.sh family.
#
# NOT a check itself: the filename has no `preflight-check-` prefix, so the
# `preflight-check-*.sh` glob (exit-check a, the executor's ingestion loop) skips it.
# It is *sourced* by every preflight-check-NN-<slug>.sh; running it directly is a no-op
# that exits 0.
#
# Provides:
#   - tooling-detection primitives the retired monolithic pre-merge tooling detector (has_cmd,
#     has_file, has_dir, pkg_dep, pkg_field, pkg_script, pubspec_*, py_*, etc.)
#   - `tooling <chosen> [version]` — build the `tooling` object; `NO_TOOLING` = the null literal
#   - `mk_report …` — emit the single check-report **detect** section
#     (schema: .claude/skills/shared/refs/check-report-schema.md) to stdout AND
#     .pre-merge/preflight/<slug>.json (AC-CK2/CK5).
#
# Portable to macOS bash 3.2 — no associative arrays. Requires jq (same as the detector).

set -uo pipefail

command -v jq >/dev/null 2>&1 || { echo "jq is required (brew install jq)" >&2; exit 1; }

# ---------- file / command / package probes (the retired monolithic pre-merge tooling detector) ----------
has_cmd() { command -v "$1" >/dev/null 2>&1; }

has_file() {
  local glob="$1" depth="${2:-3}"
  find . -maxdepth "$depth" \
    \( -path './node_modules' -o -path './.git' -o -path '*/node_modules' \) -prune -o \
    -name "$glob" -print 2>/dev/null | grep -q .
}

has_dir() {
  local glob="$1" depth="${2:-3}"
  find . -maxdepth "$depth" \
    \( -path './node_modules' -o -path './.git' -o -path '*/node_modules' \) -prune -o \
    -type d -name "$glob" -print 2>/dev/null | grep -q .
}

has_path() { [[ -e "$1" ]]; }

pkg_dep() {
  [[ -f package.json ]] || return 1
  jq -e --arg k "$1" '
    ((.dependencies // {}) | has($k)) or
    ((.devDependencies // {}) | has($k))
  ' package.json >/dev/null 2>&1
}
pkg_field()  { [[ -f package.json ]] && jq -e --arg k "$1" 'has($k)' package.json >/dev/null 2>&1; }
pkg_script() { [[ -f package.json ]] && jq -e --arg k "$1" '(.scripts // {}) | has($k)' package.json >/dev/null 2>&1; }

pubspec_flutter() { [[ -f pubspec.yaml ]] && grep -qE '^[[:space:]]*flutter[[:space:]]*:' pubspec.yaml; }
pubspec_dep()     { [[ -f pubspec.yaml ]] && grep -qE "^[[:space:]]+${1}[[:space:]]*:" pubspec.yaml; }

py_signal()    { grep -qE "^${1}" requirements*.txt 2>/dev/null && return 0; [[ -f pyproject.toml ]] && grep -qE "$2" pyproject.toml; }
pyproject_has(){ [[ -f pyproject.toml ]] && grep -qE "$1" pyproject.toml; }
req_has()      { grep -qE "^[[:space:]]*${1}" requirements*.txt 2>/dev/null; }
setupcfg_has() { [[ -f setup.cfg ]] && grep -qE "$1" setup.cfg; }

# ---------- normalized emit ----------
# The `tooling` object, or the null literal for subagent/surface-only checks.
NO_TOOLING='null'
tooling() { # chosen [version]
  jq -nc --arg c "$1" --arg v "${2:-}" '{chosen:$c, version:(if $v=="" then null else $v end)}'
}

# mk_report check id group present active_when tooling_json run criticality cost depends_on_json status notes
#   present         : "true" | "false"        (JSON bool)
#   tooling_json    : "null" or an object     (JSON)
#   run             : command | protocol ref | ""  ("" → null)
#   depends_on_json : "[]" or a JSON array
# Writes to .pre-merge/preflight/<check>.json AND stdout (AC-CK2).
mk_report() {
  local check="$1" id="$2" group="$3" present="$4" active_when="$5" \
        tooling_json="$6" run="$7" criticality="$8" cost="$9" \
        depends_on_json="${10}" status="${11}" notes="${12}"
  local out_dir=".pre-merge/preflight"
  mkdir -p "$out_dir" 2>/dev/null || true
  local json
  json=$(jq -n \
    --arg check "$check" --arg id "$id" --arg group "$group" \
    --argjson present "$present" --arg active_when "$active_when" \
    --argjson tooling "$tooling_json" --arg run "$run" \
    --arg criticality "$criticality" --arg cost "$cost" \
    --argjson depends_on "$depends_on_json" \
    --arg status "$status" --arg notes "$notes" \
    '{
      check: $check,
      id: $id,
      group: $group,
      present: $present,
      active_when: $active_when,
      tooling: $tooling,
      run: (if $run == "" then null else $run end),
      criticality: $criticality,
      cost: $cost,
      depends_on: $depends_on,
      status: $status,
      notes: $notes
    }')
  printf '%s\n' "$json" | tee "$out_dir/$check.json"
}

# Sourced-vs-executed guard: running this file directly is a harmless no-op.
# (It never matches the preflight-check-*.sh glob, so this is belt-and-braces.)
if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
  echo "preflight-common.sh is a sourced library, not a check — nothing to run." >&2
  exit 0
fi
