#!/usr/bin/env bash
# evals/codex/lib/codex-session.sh — layer 3 driver: run one real Codex session
# against the generated msg skill tree, in isolation, and capture its trace.
#
# Source it from a case `cmd`:  . "$LIB/codex-session.sh"
#
# Isolation, per plan §8 layer 3:
#
# * a temporary HOME, so the session sees only the msg skills this eval installs
#   and never the operator's personal `$HOME/.agents/skills`
# * the operator's CODEX_HOME is reused read-only for credentials only; sessions
#   run `--ephemeral` so nothing is persisted into it
# * the workspace is a throwaway git repo seeded from the case fixture
# * `--sandbox read-only` unless the case explicitly asks for workspace-write
# * stub commands are prepended to PATH, so `git`, `gh`, deploy, store and
#   simulator commands never touch a real system
#
# Layer 3 is opt-in: cases marked `layer: 3` only run under `run.sh --layer3`
# (MSG_CODEX_LAYER3=1). Without it the runner reports them PEND and the suite
# reports runtime proof as not-run, which is the honest state.

set -euo pipefail

codex_session_available() {
  [ "${MSG_CODEX_LAYER3:-0}" = "1" ] || { echo "L3_DISABLED"; return 1; }
  command -v codex >/dev/null 2>&1 || { echo "L3_NO_BINARY"; return 1; }
  codex login status >/dev/null 2>&1 || { echo "L3_NOT_AUTHENTICATED"; return 1; }
  return 0
}

# codex_workspace — build an isolated workspace containing the Codex skill tree.
# Prints the workspace path. The caller seeds any fixture files it needs.
codex_workspace() {
  local work; work="$(mktemp -d)"
  mkdir -p "$work/repo" "$work/home" "$work/stubs"
  cp -R "$REPO/.agents" "$work/repo/.agents"
  echo "$work"
}

# codex_stub <name> <body>  — install a stub command on the session PATH.
codex_stub() {
  local work="$1" name="$2" body="$3"
  printf '#!/usr/bin/env bash\n%s\n' "$body" > "$work/stubs/$name"
  chmod +x "$work/stubs/$name"
}

# codex_run <workspace> <sandbox> <prompt>  — run the session, print the raw
# JSONL trace on stdout. Never inherits the operator's project instructions.
codex_run() {
  local work="$1" sandbox="$2" prompt="$3"
  # Resolved against the operator's real home, before HOME is swapped: the
  # session gets an empty home (so it sees only the skills this eval installs)
  # while credentials keep resolving from the operator's Codex home, read-only.
  local credentials="${CODEX_HOME:-$HOME/.codex}"
  ( cd "$work/repo" \
    && HOME="$work/home" \
       PATH="$work/stubs:$PATH" \
       CODEX_HOME="$credentials" \
       codex exec \
         --json \
         --ephemeral \
         --skip-git-repo-check \
         --sandbox "$sandbox" \
         -C "$work/repo" \
         "$prompt" 2>/dev/null )
}

# codex_trace <workspace> <sandbox> <prompt>  — run and normalize in one step.
codex_trace() {
  local work="$1"
  codex_run "$@" | python3 "$LIB/normalize-trace.py" --home "$work/home" --repo "$work/repo"
}

# assert_trace_has <trace-file> <regex>  — a required semantic event occurred.
assert_trace_has() {
  grep -Eq "$2" "$1" || { echo "TRACE_MISSING $2" >&2; exit 1; }
  echo "TRACE_HAS $2"
}

# assert_trace_lacks <trace-file> <regex>  — a forbidden event never occurred.
assert_trace_lacks() {
  ! grep -Eq "$2" "$1" || { echo "TRACE_FORBIDDEN $2" >&2; exit 1; }
  echo "TRACE_LACKS $2"
}
