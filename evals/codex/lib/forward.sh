#!/usr/bin/env bash
# evals/codex/lib/forward.sh — plan §8 layer 5: forward testing.
#
# Source it from a case `cmd`:  . "$LIB/forward.sh"
#
# A forward test is not a contract check. It hands a *realistic user prompt* to a
# fresh, isolated Codex session — never the skill name where a real user would
# not say it, never the expected answer, never the defect being hunted — and then
# reads what actually came back. Plan §8 asks for four paths per skill: one happy
# path, one ambiguous input, one refusal, and one safety-sensitive path.
#
# Everything here runs `--sandbox read-only` by default, so a forward test can
# ask a session to consider shipping without any possibility of it shipping.
# Sessions are graded on their answer and their trace, not on prose style: the
# assertions below are semantic (did it name the right skill, did it ask instead
# of guessing, did it refuse and say why) precisely because model wording varies.
#
# Artifacts. Every session writes three files under `$work/traces/`:
#   <label>.jsonl   the raw Codex event stream
#   <label>.trace   the normalized semantic trace (plan §8 layer 4 form)
#   <label>.answer  the session's own words, concatenated, untruncated
# When MSG_CODEX_FORWARD_DIR is set they are also copied there, which is how the
# release evidence under `evals/codex/forward/` is produced.

set -euo pipefail

. "$LIB/codex-session.sh"

forward_fail() { echo "FORWARD_FAILED $*" >&2; exit 1; }

# forward_workspace — an isolated repo containing the Codex skill tree only.
forward_workspace() {
  local work; work="$(codex_workspace)"
  mkdir -p "$work/traces"
  printf '%s\n' "$work"
}

# forward_session <work> <label> <sandbox> <prompt>
forward_session() {
  local work="$1" label="$2" sandbox="$3" prompt="$4"
  local raw="$work/traces/$label.jsonl"

  codex_run "$work" "$sandbox" "$prompt" > "$raw" || true
  [ -s "$raw" ] || forward_fail "$label: the Codex session produced no events"

  python3 "$LIB/normalize-trace.py" --home "$work/home" --repo "$work/repo" \
    < "$raw" > "$work/traces/$label.trace"

  python3 - "$raw" > "$work/traces/$label.answer" <<'PY'
import json, sys
for line in open(sys.argv[1]):
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        event = json.loads(line)
    except json.JSONDecodeError:
        continue
    if event.get("type") != "item.completed":
        continue
    item = event.get("item", {})
    if item.get("type") == "agent_message":
        print(item.get("text", ""))
PY
  [ -s "$work/traces/$label.answer" ] || forward_fail "$label: the session never answered"

  if [ -n "${MSG_CODEX_FORWARD_DIR:-}" ]; then
    mkdir -p "$MSG_CODEX_FORWARD_DIR"
    cp "$work/traces/$label.jsonl" "$work/traces/$label.trace" "$work/traces/$label.answer" \
       "$MSG_CODEX_FORWARD_DIR/"
  fi
  echo "FORWARD_SESSION $label sandbox=$sandbox"
}

# forward_answer_has <work> <label> <what> <extended-regex>
# Graded case-insensitively: the meaning is the assertion, not the casing.
forward_answer_has() {
  local work="$1" label="$2" what="$3" regex="$4"
  grep -Eqi "$regex" "$work/traces/$label.answer" \
    || forward_fail "$label: the answer never $what — got: $(tr '\n' ' ' < "$work/traces/$label.answer" | cut -c1-300)"
  echo "FORWARD_OK $label $what"
}

forward_answer_lacks() {
  local work="$1" label="$2" what="$3" regex="$4"
  ! grep -Eqi "$regex" "$work/traces/$label.answer" \
    || forward_fail "$label: the answer $what when it must not — got: $(tr '\n' ' ' < "$work/traces/$label.answer" | cut -c1-300)"
  echo "FORWARD_OK $label not-$what"
}

# forward_no_writes <work> <before>  — the session changed nothing on disk.
forward_no_writes() {
  local work="$1" before="$2" after
  after="$(snapshot_tree "$work/repo")"
  [ "$before" = "$after" ] || forward_fail "the session wrote to the workspace under a read-only sandbox"
  echo "FORWARD_OK workspace-unchanged"
}
