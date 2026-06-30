#!/usr/bin/env bash
# append-tasks.sh — append a JSON array of tasks to TODOs.json
#
# Usage:
#   append-tasks.sh <tasks-json-file> [todos-file]
#
# Arguments:
#   tasks-json-file   Path to a JSON file containing an array of task objects.
#                     Each task must have: status, agents, description, source.
#                     The id field is assigned by this script.
#   todos-file        Optional. Path to TODOs.json. Defaults to ./TODOs.json.
#
# Behavior:
#   - Creates the todos file as [] if it does not exist.
#   - Drops any incoming task whose `source` already exists in the todos file,
#     and de-duplicates within the incoming batch — so re-running /todo on the
#     same input never doubles tasks.
#   - Reads the highest existing id (todo-N) and assigns sequential ids
#     starting at N+1 to the surviving tasks.
#   - Appends the survivors to the array and writes the result atomically.
#   - Prints the absolute path of the todos file, the count appended, and the
#     count skipped as duplicates.
#
# Requires: jq.

set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: append-tasks.sh <tasks-json-file> [todos-file]" >&2
  exit 2
fi

TASKS_FILE="$1"
TODOS_FILE="${2:-./TODOs.json}"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required but not installed" >&2
  exit 1
fi

if [[ ! -f "$TASKS_FILE" ]]; then
  echo "error: tasks file not found: $TASKS_FILE" >&2
  exit 1
fi

# Validate incoming tasks are a non-empty array
if ! jq -e 'type == "array" and length > 0' "$TASKS_FILE" >/dev/null; then
  echo "error: $TASKS_FILE must be a non-empty JSON array" >&2
  exit 1
fi

# Validate each task has the required fields (id is assigned here, so not required on input)
if ! jq -e 'all(.[]; has("status") and has("agents") and has("description") and has("source"))' "$TASKS_FILE" >/dev/null; then
  echo "error: each task must have status, agents, description, and source fields" >&2
  exit 1
fi

# Bootstrap TODOs.json if missing
if [[ ! -f "$TODOS_FILE" ]]; then
  echo "[]" > "$TODOS_FILE"
fi

# Validate existing TODOs.json is an array
if ! jq -e 'type == "array"' "$TODOS_FILE" >/dev/null; then
  echo "error: $TODOS_FILE exists but is not a JSON array" >&2
  exit 1
fi

# Find highest existing id number; default to 0 when file is empty
NEXT_ID=$(jq '
  [.[] | .id | capture("^todo-(?<n>[0-9]+)$").n | tonumber] as $ids
  | (if ($ids | length) == 0 then 0 else ($ids | max) end) + 1
' "$TODOS_FILE")

ORIG_LEN=$(jq 'length' "$TODOS_FILE")
INCOMING=$(jq 'length' "$TASKS_FILE")

# Drop incoming tasks whose `source` already exists, de-dup within the batch,
# then assign sequential ids to the survivors and concatenate.
TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

jq --slurpfile new "$TASKS_FILE" --argjson next "$NEXT_ID" '
  . as $existing
  | ($existing | map(.source)) as $seen
  | reduce $new[0][] as $t ({kept: [], seen: $seen};
      if (.seen | index($t.source)) then .
      else {kept: (.kept + [$t]), seen: (.seen + [$t.source])} end)
  | .kept
  | to_entries
  | map(.value + {id: ("todo-" + ((.key + $next) | tostring))})
  | $existing + .
' "$TODOS_FILE" > "$TMP_FILE"

mv "$TMP_FILE" "$TODOS_FILE"

ABS_PATH="$(cd "$(dirname "$TODOS_FILE")" && pwd)/$(basename "$TODOS_FILE")"
NEW_LEN=$(jq 'length' "$TODOS_FILE")
APPENDED=$((NEW_LEN - ORIG_LEN))
SKIPPED=$((INCOMING - APPENDED))
echo "Appended $APPENDED task(s) to $ABS_PATH ($SKIPPED duplicate(s) skipped)"
