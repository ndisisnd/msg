#!/usr/bin/env bash
# script-tier-resolve.sh — deterministic S/M/L size-tier calculator for
# policies.test_selection (pre-merge refs/executor.md §3c.1).
#
# Computes the test-selection size tier for a diff against <base-ref> from three
# signals: `modules` (distinct top-level module/package dirs touched, derived
# straight from `git diff --name-only <base>` — always derivable from paths),
# `ratio` (|affected ∪ critical| / |suite|, supplied by the caller via
# --affected-ratio — this script never re-derives the affected set itself), and
# `fan_in_pct` (highest fan-in percentile among touched files, supplied via
# --fan-in-pct — from the code graph, e.g. tokensave `rank`/`hotspots`). A
# `force_full_paths` match on the diff short-circuits straight to tier L (rule
# step 1, executor.md §3c).
#
# AC-TS10 — a missing/unsupplied signal ALWAYS resolves toward the LARGER tier:
#   - base ref undiffable    -> diff surface unknown (not empty) -> tier L
#   - ratio unresolved       -> cannot be confirmed under any bound -> tier L
#   - fan_in_pct unresolved  -> treated as exceeding the small bound -> not tier S
#     (may still resolve to M if modules/ratio are within the M bounds)
#
# Usage:
#   script-tier-resolve.sh <base-ref> [--affected-ratio <0..1>] \
#                             [--fan-in-pct <0..1>] [--policy <path>]
#
#   <base-ref>            required positional — the ref/branch to diff against
#   --affected-ratio N    |affected ∪ critical| / |suite|; omitted => unresolved
#   --fan-in-pct N        highest fan-in percentile among touched files (0..1);
#                         omitted => treated as exceeding the small bound
#   --policy PATH         devkit/policy.json to read
#                         policies.test_selection.{tiers,force_full_paths,
#                         max_affected_ratio} from (default: devkit/policy.json).
#                         Missing/malformed/unset keys fall back to the documented
#                         defaults (policy-schema-pre-merge.md §test_selection).
#
# Output (stdout, one JSON object, AC-TS10):
#   {"tier":"S|M|L","signals":{"modules":N,"ratio":N|null,"fan_in_pct":N|null},"trigger":"..."}
#
# Read-only: reads git history + (optionally) devkit/policy.json; never mutates
# git state or policy.json (that stays --init's/--update's job, AC-OW1/AC-TS2).
# Requires jq. Pure POSIX-compatible bash (matches the script-preflight-*.sh family).

set -uo pipefail
SELF="$(basename "$0")"

command -v jq >/dev/null 2>&1 || { echo "$SELF: jq is required (brew install jq)" >&2; exit 1; }

usage() {
  echo "usage: $SELF <base-ref> [--affected-ratio <0..1>] [--fan-in-pct <0..1>] [--policy <path>]" >&2
  exit 2
}

base=""
ratio=""
fan_in=""
policy="devkit/policy.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --affected-ratio)   ratio="${2:-}"; shift 2 || shift ;;
    --affected-ratio=*) ratio="${1#--affected-ratio=}"; shift ;;
    --fan-in-pct)       fan_in="${2:-}"; shift 2 || shift ;;
    --fan-in-pct=*)     fan_in="${1#--fan-in-pct=}"; shift ;;
    --policy)           policy="${2:-}"; shift 2 || shift ;;
    --policy=*)         policy="${1#--policy=}"; shift ;;
    -h|--help)          usage ;;
    --*)                echo "$SELF: unknown flag: $1" >&2; usage ;;
    *)
      if [[ -z "$base" ]]; then base="$1"; shift
      else echo "$SELF: unexpected extra argument: $1" >&2; usage; fi
      ;;
  esac
done

[[ -n "$base" ]] || usage

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "$SELF: not inside a git repository" >&2
  exit 2
fi

# --- diff surface ---------------------------------------------------------------
# Direct diff against <base-ref> per the spec; fall back to the merge-base
# triple-dot form if the direct form resolves nothing (e.g. base is a remote-only
# ref with no local working-tree relationship yet).
#
# A5: "the diff ran and is empty" and "both diff invocations failed" used to
# collapse into the same empty string — an unresolvable base ref then read as a
# zero-module diff and resolved to tier S, inverting the AC-TS10 fail-large
# rule. Track whether either invocation actually succeeded.
diff_ok=false
diff_files="$(git diff --name-only "$base" -- 2>/dev/null)"
[[ $? -eq 0 ]] && diff_ok=true
if [[ -z "$diff_files" ]]; then
  diff_files="$(git diff --name-only "${base}...HEAD" -- 2>/dev/null)"
  [[ $? -eq 0 ]] && diff_ok=true
fi

# --- policy-configured knobs (defaults per policy-schema-pre-merge.md §test_selection) ----
small_max_modules=2
small_max_affected_ratio="0.10"
medium_max_modules=6
medium_max_fan_in_pct="0.90"
max_affected_ratio="0.5"

# Built-in force_full_paths catalog defaults (component-catalog.md) — universal
# rows plus every platform's rows, since this script doesn't know in isolation
# which platform(s) are detected. The policy file's own list (when present)
# overrides this wholesale, matching --init/--update's per-project resolution.
builtin_force_full='[
  "devkit/**", "**/migrations/**", "**/shared/**", "**/lockfiles/**",
  "package.json", "package-lock.json", "pnpm-lock.yaml", "yarn.lock", "tsconfig*.json",
  "pyproject.toml", "poetry.lock", "requirements*.txt", "conftest.py",
  "go.mod", "go.sum",
  "*.xcodeproj/**", "*.xcworkspace/**", "Package.swift", "Podfile.lock", "*.xctestplan",
  "*.gradle*", "gradle/libs.versions.toml", "gradle.properties", "settings.gradle*"
]'
force_full_paths="$builtin_force_full"

if [[ -f "$policy" ]] && jq -e . "$policy" >/dev/null 2>&1; then
  v="$(jq -c '.policies.test_selection.force_full_paths // empty' "$policy" 2>/dev/null)"
  [[ -n "$v" && "$v" != "null" ]] && force_full_paths="$v"

  v="$(jq -r '.policies.test_selection.tiers.small_max_modules // empty' "$policy" 2>/dev/null)"
  [[ -n "$v" ]] && small_max_modules="$v"
  v="$(jq -r '.policies.test_selection.tiers.small_max_affected_ratio // empty' "$policy" 2>/dev/null)"
  [[ -n "$v" ]] && small_max_affected_ratio="$v"
  v="$(jq -r '.policies.test_selection.tiers.medium_max_modules // empty' "$policy" 2>/dev/null)"
  [[ -n "$v" ]] && medium_max_modules="$v"
  v="$(jq -r '.policies.test_selection.tiers.medium_max_fan_in_pct // empty' "$policy" 2>/dev/null)"
  [[ -n "$v" ]] && medium_max_fan_in_pct="$v"
  v="$(jq -r '.policies.test_selection.max_affected_ratio // empty' "$policy" 2>/dev/null)"
  [[ -n "$v" ]] && max_affected_ratio="$v"
fi

# --- signal 1: modules touched (always derivable from paths) -------------------
modules_count=0
if [[ -n "$diff_files" ]]; then
  modules_count="$(printf '%s\n' "$diff_files" | awk -F/ '{print ($1=="" ? "." : $1)}' | sort -u | wc -l | tr -d ' ')"
fi

# --- signal 1b: force_full_paths match (short-circuits to tier L) --------------
trigger_force_full=""
if [[ -n "$diff_files" ]]; then
  while IFS= read -r f; do
    [[ -z "$f" || -n "$trigger_force_full" ]] && continue
    while IFS= read -r g; do
      [[ -z "$g" ]] && continue
      g2="${g//\*\*/\*}"                 # ** and * are equivalent in a bash case pattern
      alt="$g2"
      [[ "$g2" == \*/* ]] && alt="${g2#\*/}"   # tolerate a top-level file against a "**/x/**" glob
      case "$f" in
        $g2|$alt) trigger_force_full="force-full: $f (matches $g)"; break ;;
      esac
    done < <(printf '%s' "$force_full_paths" | jq -r '.[]')
  done <<< "$diff_files"
fi

# --- resolve the tier ------------------------------------------------------------
tier=""
trigger=""

if [[ "$diff_ok" != true ]]; then
  # A5 / AC-TS10: the base ref could not be diffed at all, so the diff surface is
  # unknown — not empty. Unknown always degrades to the largest tier.
  tier="L"
  trigger="base ref unresolvable — degrades to L (AC-TS10)"
elif [[ -n "$trigger_force_full" ]]; then
  tier="L"
  trigger="$trigger_force_full"
elif [[ -z "$ratio" ]]; then
  # AC-TS10: an unresolved ratio can't be confirmed under ANY bound (not even
  # max_affected_ratio) -> degrade all the way to the largest tier.
  tier="L"
  trigger="ratio unavailable — degrades to tier L (AC-TS10)"
elif awk -v r="$ratio" -v m="$max_affected_ratio" 'BEGIN{exit !(r>m)}'; then
  tier="L"
  trigger="ratio=$ratio > max_affected_ratio=$max_affected_ratio"
elif [[ "$modules_count" -gt "$medium_max_modules" ]]; then
  tier="L"
  trigger="modules=$modules_count > medium_max_modules=$medium_max_modules"
elif [[ "$modules_count" -le "$small_max_modules" ]] \
     && awk -v r="$ratio" -v m="$small_max_affected_ratio" 'BEGIN{exit !(r<=m)}' \
     && [[ -n "$fan_in" ]] \
     && awk -v f="$fan_in" -v b="$medium_max_fan_in_pct" 'BEGIN{exit !(f<b)}'; then
  tier="S"
  trigger="modules=$modules_count<=$small_max_modules, ratio=$ratio<=$small_max_affected_ratio, fan_in_pct=$fan_in<$medium_max_fan_in_pct"
else
  tier="M"
  # Name the S bound(s) that actually failed — the trigger is the audit trail a
  # miss is attributed to (AC-TS10), so it must never assert a bound that held.
  why=""
  [[ "$modules_count" -gt "$small_max_modules" ]] && \
    why="modules=$modules_count>small_max_modules=$small_max_modules"
  if ! awk -v r="$ratio" -v m="$small_max_affected_ratio" 'BEGIN{exit !(r<=m)}'; then
    why="${why:+$why, }ratio=$ratio>small_max_affected_ratio=$small_max_affected_ratio"
  fi
  if [[ -z "$fan_in" ]]; then
    why="${why:+$why, }fan_in_pct unavailable — treated as exceeding the small bound (AC-TS10)"
  elif ! awk -v f="$fan_in" -v b="$medium_max_fan_in_pct" 'BEGIN{exit !(f<b)}'; then
    why="${why:+$why, }fan_in_pct=$fan_in>=medium_max_fan_in_pct=$medium_max_fan_in_pct"
  fi
  trigger="not S ($why); within M bounds: modules=$modules_count<=$medium_max_modules, ratio=$ratio<=$max_affected_ratio"
fi

ratio_json="null"; [[ -n "$ratio" ]] && ratio_json="$ratio"
fan_json="null"; [[ -n "$fan_in" ]] && fan_json="$fan_in"

jq -n \
  --arg tier "$tier" \
  --argjson modules "$modules_count" \
  --argjson ratio "$ratio_json" \
  --argjson fan_in_pct "$fan_json" \
  --arg trigger "$trigger" \
  '{
    tier: $tier,
    signals: { modules: $modules, ratio: $ratio, fan_in_pct: $fan_in_pct },
    trigger: $trigger
  }'
