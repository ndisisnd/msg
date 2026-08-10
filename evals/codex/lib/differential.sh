#!/usr/bin/env bash
# evals/codex/lib/differential.sh — run an existing msg eval case under both
# runtime packages and require identical observable results.
#
# Source it from a case `cmd`:  . "$LIB/differential.sh"
#
# This is the deterministic parity floor of plan §8 layer 1/4 made executable.
# Every msg artifact that matters — ledger rows, PRD migrations, verdicts, status
# lines, certification output — is written by a helper under `.claude/scripts/`.
# The Codex package mirrors those helpers byte-for-byte, so the claim "both
# runtimes reach the same product state" is testable without a model: take a real
# fixture from `evals/cases/`, run it once against the Claude package and once
# against the Codex package, and compare exit code, stdout and every resulting
# byte in the working tree.
#
# A difference here is a genuine parity failure, not a prose mismatch.

set -euo pipefail

differential_fail() { echo "DIFFERENTIAL_FAILED $*" >&2; exit 1; }

# Digest of every regular file in a tree, by relative path. `.git` is excluded
# (its index carries inodes and timestamps, not product state), `__pycache__` is
# excluded (a byproduct of whichever package ran first), and symlinks are not
# followed — several fixtures symlink a fake home at the package directory, and
# the package's own contents are asserted separately.
# Each file's own temp-directory path is normalised out before hashing: several
# helpers legitimately record the absolute path they resolved, and the two runs
# necessarily live in different temp directories. Everything else must match.
tree_digest() {
  local dir="$1" file
  ( cd "$dir" && find . -name .git -prune -o -name __pycache__ -prune -o -type f -print \
      | LC_ALL=C sort \
      | while IFS= read -r file; do
          printf '%s  %s\n' \
            "$(LC_ALL=C sed "s#$dir#<WORK>#g" "$file" 2>/dev/null | shasum -a 256 | cut -d' ' -f1)" \
            "$file"
        done )
}

# differential_case <case-slug> [<case-slug> ...]
differential_case() {
  local slug src claude_dir codex_dir claude_out codex_out claude_rc codex_rc cmd_codex
  for slug in "$@"; do
    src="$REPO/evals/cases/$slug"
    [ -d "$src" ] || differential_fail "$slug: no such case under evals/cases/"

    claude_dir="$(mktemp -d)"; codex_dir="$(mktemp -d)"
    [ -d "$src/fixture" ] && cp -R "$src/fixture/." "$claude_dir/" 2>/dev/null
    [ -d "$src/fixture" ] && cp -R "$src/fixture/." "$codex_dir/" 2>/dev/null

    # The only edit is the package root the case resolves its helpers from:
    # `$REPO/.claude/scripts/x` becomes `$REPO/.agents/scripts/x`. Fixture-local
    # paths are deliberately untouched — several cases build their own fake
    # `$HOME/.claude/scripts` to exercise a helper's own fallback ladder, and
    # rewriting those would test the fixture rather than the package.
    cmd_codex="$(mktemp)"
    sed 's#\$REPO/\.claude/scripts#$REPO/.agents/scripts#g' "$src/cmd" > "$cmd_codex"
    grep -q '\$REPO/\.agents/scripts' "$cmd_codex" \
      || differential_fail "$slug: case does not resolve a msg helper, nothing to compare"

    claude_out="$(cd "$claude_dir" && TZ=UTC bash "$src/cmd" 2>&1)" && claude_rc=0 || claude_rc=$?
    codex_out="$(cd "$codex_dir" && TZ=UTC bash "$cmd_codex" 2>&1)" && codex_rc=0 || codex_rc=$?

    # Normalise the two working directories out of any absolute path in stdout.
    claude_out="${claude_out//$claude_dir/<WORK>}"
    codex_out="${codex_out//$codex_dir/<WORK>}"

    [ "$claude_rc" = "$codex_rc" ] \
      || differential_fail "$slug: exit differs — claude=$claude_rc codex=$codex_rc"
    [ "$claude_out" = "$codex_out" ] \
      || differential_fail "$slug: stdout differs — $(diff <(printf '%s\n' "$claude_out") <(printf '%s\n' "$codex_out") | head -n 4 | tr '\n' ' ')"
    if [ "$(tree_digest "$claude_dir")" != "$(tree_digest "$codex_dir")" ]; then
      differential_fail "$slug: resulting artifacts differ — $(diff <(tree_digest "$claude_dir") <(tree_digest "$codex_dir") | head -n 4 | tr '\n' ' ')"
    fi

    echo "DIFFERENTIAL $slug exit=$claude_rc identical"
    rm -rf "$claude_dir" "$codex_dir" "$cmd_codex"
  done
}

# differential_helper <helper-name> -- <args...>
# Runs one helper from both packages in two identical scratch trees seeded from
# the current working directory, and requires identical stdout, exit and bytes.
differential_helper() {
  local name="$1"; shift
  [ "${1:-}" = "--" ] && shift
  local claude_dir codex_dir claude_out codex_out claude_rc codex_rc
  claude_dir="$(mktemp -d)"; codex_dir="$(mktemp -d)"
  cp -R ./. "$claude_dir/" 2>/dev/null || true
  cp -R ./. "$codex_dir/" 2>/dev/null || true
  claude_out="$(cd "$claude_dir" && TZ=UTC "$REPO/.claude/scripts/$name" "$@" 2>&1)" && claude_rc=0 || claude_rc=$?
  codex_out="$(cd "$codex_dir" && TZ=UTC "$REPO/.agents/scripts/$name" "$@" 2>&1)" && codex_rc=0 || codex_rc=$?
  claude_out="${claude_out//$claude_dir/<WORK>}"
  codex_out="${codex_out//$codex_dir/<WORK>}"
  [ "$claude_rc" = "$codex_rc" ] || differential_fail "$name: exit differs — $claude_rc vs $codex_rc"
  [ "$claude_out" = "$codex_out" ] || differential_fail "$name: stdout differs"
  [ "$(tree_digest "$claude_dir")" = "$(tree_digest "$codex_dir")" ] || differential_fail "$name: artifacts differ"
  echo "DIFFERENTIAL_HELPER $name exit=$claude_rc identical"
  rm -rf "$claude_dir" "$codex_dir"
}
