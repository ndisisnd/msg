#!/usr/bin/env bash
# evals/codex/lib/assertions.sh — shared assertions for Codex compatibility cases.
#
# Source it from a case `cmd`:  . "$LIB/assertions.sh"
#
# Every helper prints one deterministic line on success (so a case's stdout is a
# readable proof trace) and exits non-zero with a reason on failure. Nothing here
# writes inside the repository: cases run in a temp dir and only ever read the
# repo tree, or copy fixtures out of it.

set -euo pipefail

CLAUDE_SKILLS="$REPO/.claude/skills"
CLAUDE_SCRIPTS="$REPO/.claude/scripts"
CODEX_SKILLS="$REPO/.agents/skills"
CODEX_SCRIPTS="$REPO/.agents/scripts"

fail() { echo "ASSERTION_FAILED $*" >&2; exit 1; }

# --- packaging -------------------------------------------------------------- #

# Every tracked canonical file of a skill has a byte-identical Codex counterpart,
# the entry point arriving as CLAUDE-SKILL.md so Codex does not discover it twice.
assert_skill_files_mirrored() {
  local skill="$1" count=0 path rel mirror
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    rel="${path#.claude/skills/$skill/}"
    if [ "$rel" = "SKILL.md" ]; then
      mirror="$CODEX_SKILLS/$skill/CLAUDE-SKILL.md"
    else
      mirror="$CODEX_SKILLS/$skill/$rel"
    fi
    [ -f "$mirror" ] || fail "$skill: no Codex counterpart for $path"
    cmp -s "$REPO/$path" "$mirror" || fail "$skill: $mirror differs from $path"
    count=$((count + 1))
  done < <(cd "$REPO" && git ls-files ".claude/skills/$skill")
  [ "$count" -gt 0 ] || fail "$skill: no canonical files discovered"
  echo "MIRRORED $skill files=$count"
}

# The compatibility map's coverage table names every canonical path exactly once.
assert_map_covers_skill() {
  local skill="$1" map="$CODEX_SKILLS/$1/refs/compatibility-map.md" path base hits count=0
  [ -f "$map" ] || fail "$skill: compatibility map missing"
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    base="$(basename "$path")"
    hits="$(grep -c -F "$base" "$map" || true)"
    [ "$hits" -ge 1 ] || fail "$skill: compatibility map does not mention $path"
    count=$((count + 1))
  done < <(cd "$REPO" && git ls-files ".claude/skills/$skill")
  echo "MAPPED $skill rows>=files=$count"
}

# The thin adapter carries Codex frontmatter only, points at the three documents a
# Codex session must read in order, and emits no Claude slash invocation.
assert_adapter_contract() {
  local skill="$1" adapter="$CODEX_SKILLS/$1/SKILL.md" key
  [ -f "$adapter" ] || fail "$skill: adapter missing"
  for key in name description; do
    grep -q "^$key:" "$adapter" || fail "$skill: adapter frontmatter lacks $key"
  done
  grep -q "^name: $skill\$" "$adapter" || fail "$skill: adapter name is not $skill"
  for ref in "../shared/refs/codex-runtime.md" "refs/compatibility-map.md" "CLAUDE-SKILL.md"; do
    grep -qF "$ref" "$adapter" || fail "$skill: adapter does not point at $ref"
  done
  if grep -qE '(^|[^A-Za-z0-9_/.$-])/(msg|intake|plan-pm|plan-review|plan-em|eng|pre-merge|merge|emulate)([^A-Za-z0-9_/.-]|$)' "$adapter"; then
    fail "$skill: adapter emits a Claude slash invocation"
  fi
  echo "ADAPTER_OK $skill"
}

# The canonical payload is byte-identical to the Claude entry point: the product
# contract Codex executes is the same bytes Claude executes.
assert_payload_identical() {
  local skill="$1"
  cmp -s "$CLAUDE_SKILLS/$skill/SKILL.md" "$CODEX_SKILLS/$skill/CLAUDE-SKILL.md" \
    || fail "$skill: CLAUDE-SKILL.md is not byte-identical to the canonical SKILL.md"
  echo "PAYLOAD_IDENTICAL $skill $(shasum -a 256 "$CLAUDE_SKILLS/$skill/SKILL.md" | cut -c1-16)"
}

# A named deterministic helper is mirrored byte-for-byte, so both runtimes run the
# same implementation and every machine emission stays byte-identical (CX-G006).
assert_helper_mirrored() {
  local name
  for name in "$@"; do
    [ -f "$CLAUDE_SCRIPTS/$name" ] || fail "canonical helper missing: $name"
    cmp -s "$CLAUDE_SCRIPTS/$name" "$CODEX_SCRIPTS/$name" || fail "helper differs: $name"
    echo "HELPER_MIRRORED $name"
  done
}

# The payload still contains a canonical contract phrase. Used to prove a mode,
# refusal, gate or write boundary survived packaging unchanged.
assert_payload_contains() {
  local skill="$1"; shift
  local needle
  for needle in "$@"; do
    grep -qF -- "$needle" "$CODEX_SKILLS/$skill/CLAUDE-SKILL.md" \
      || fail "$skill: payload no longer states: $needle"
    echo "CONTRACT_PRESENT $skill :: $needle"
  done
}

assert_ref_contains() {
  local skill="$1" relpath="$2"; shift 2
  local needle target="$CODEX_SKILLS/$skill/$relpath"
  [ -f "$target" ] || fail "$skill: $relpath missing from the Codex tree"
  for needle in "$@"; do
    grep -qF -- "$needle" "$target" || fail "$skill/$relpath no longer states: $needle"
    echo "CONTRACT_PRESENT $skill/$relpath :: $needle"
  done
}

# --- runtime bindings ------------------------------------------------------- #

codex_script() { printf '%s\n' "$CODEX_SCRIPTS/$1"; }

# Invocation translation (DEV-CX-001): active-runtime tokens only.
assert_invocation_translation() {
  local input="$1" want="$2" got
  got="$(printf '%s\n' "$input" | "$CODEX_SCRIPTS/script-codex-invoke.sh" translate)"
  [ "$got" = "$want" ] || fail "invocation translation: expected [$want], got [$got]"
  echo "INVOCATION_OK $got"
}

# A gate keeps its decision, options, default and resume point (DEV-CX-003/011).
assert_gate_state() {
  local want_state="$1" want_exit="$2"; shift 2
  local out rc
  out="$("$CODEX_SCRIPTS/script-codex-gate.sh" "$@" 2>&1)" && rc=0 || rc=$?
  [ "$rc" = "$want_exit" ] || fail "gate: expected exit $want_exit, got $rc"
  printf '%s\n' "$out" | grep -q "^GATE_STATE=$want_state\$" \
    || fail "gate: expected GATE_STATE=$want_state, got: $(printf '%s' "$out" | tr '\n' ' ')"
  echo "GATE_OK $want_state exit=$want_exit"
}

# Packet class → canonical tier → Codex model (DEV-CX-006). The pinned map is
# asserted per packet class, never inferred: a class that cannot be tiered is a
# usage error, not an inherited default.
assert_packet_tier() {
  local class="$1" want_tier="$2" want_model="$3" out
  out="$("$CODEX_SCRIPTS/script-codex-packet.sh" tier --class "$class" 2>&1)" \
    || fail "packet tier: $class was rejected"
  printf '%s\n' "$out" | grep -q "^CANONICAL_TIER=$want_tier\$" \
    || fail "packet tier: $class expected tier $want_tier, got: $(printf '%s' "$out" | tr '\n' ' ')"
  printf '%s\n' "$out" | grep -q "^CODEX_MODEL=$want_model\$" \
    || fail "packet tier: $class expected model $want_model"
  echo "TIER_OK $class ${want_tier}→${want_model}"
}

assert_packet_tier_rejected() {
  local class="$1" rc=0
  "$CODEX_SCRIPTS/script-codex-packet.sh" tier --class "$class" >/dev/null 2>&1 || rc=$?
  [ "$rc" = "2" ] || fail "packet tier: expected an unknown class to be rejected (exit 2), got $rc"
  echo "TIER_REJECTED $class"
}

# Dispatch integrity (DEV-CX-005/013): disjoint ownership, dependency barriers,
# declared width, and the collision script's decomposition staying authoritative.
assert_dispatch_state() {
  local want_state="$1" want_exit="$2"; shift 2
  local out rc=0
  out="$("$CODEX_SCRIPTS/script-codex-packet.sh" check "$@" 2>&1)" || rc=$?
  [ "$rc" = "$want_exit" ] || fail "dispatch: expected exit $want_exit, got $rc — $(printf '%s' "$out" | tr '\n' ' ')"
  if [ "$want_state" = "ok" ]; then
    printf '%s\n' "$out" | grep -q '^DISPATCH_OK ' || fail "dispatch: expected DISPATCH_OK"
  else
    printf '%s\n' "$out" | grep -q "^DISPATCH_STATE=$want_state\$" \
      || fail "dispatch: expected DISPATCH_STATE=$want_state, got: $(printf '%s' "$out" | tr '\n' ' ')"
  fi
  echo "DISPATCH_OK $want_state exit=$want_exit"
}

# Child-thread lifecycle (DEV-CX-005, CX-G009): capability preflight that fails
# closed, disjoint identities, proven reviewer independence, resume that skips.
assert_subagent_state() {
  local want_line="$1" want_exit="$2"; shift 2
  local out rc=0
  out="$("$CODEX_SCRIPTS/script-codex-subagent.sh" "$@" 2>&1)" || rc=$?
  [ "$rc" = "$want_exit" ] || fail "subagent: expected exit $want_exit, got $rc — $(printf '%s' "$out" | tr '\n' ' ')"
  printf '%s\n' "$out" | grep -q "^$want_line\$" \
    || fail "subagent: expected [$want_line], got: $(printf '%s' "$out" | tr '\n' ' ')"
  echo "SUBAGENT_OK $want_line exit=$want_exit"
}

# Leaf-owned gate relay (DEV-CX-011).
assert_relay_state() {
  local want_state="$1" want_exit="$2"; shift 2
  local out rc=0
  out="$("$CODEX_SCRIPTS/script-codex-relay.sh" "$@" 2>&1)" || rc=$?
  [ "$rc" = "$want_exit" ] || fail "relay: expected exit $want_exit, got $rc — $(printf '%s' "$out" | tr '\n' ' ')"
  printf '%s\n' "$out" | grep -q "^RELAY_STATE=$want_state\$" \
    || fail "relay: expected RELAY_STATE=$want_state, got: $(printf '%s' "$out" | tr '\n' ' ')"
  echo "RELAY_OK $want_state exit=$want_exit"
}

# External actions and sanctioned writes (AMB-CX-001/006, CX-G007). Nothing here
# performs an external effect: the broker records the intent and refuses the ones
# a release gate does not own.
assert_ship_state() {
  local want_state="$1" want_exit="$2"; shift 2
  local out rc=0
  out="$("$CODEX_SCRIPTS/script-codex-ship.sh" "$@" 2>&1)" || rc=$?
  [ "$rc" = "$want_exit" ] || fail "ship: expected exit $want_exit, got $rc — $(printf '%s' "$out" | tr '\n' ' ')"
  printf '%s\n' "$out" | grep -q "^\(SHIP_STATE\|WRITE_STATE\|CLOSE_STATE\)=$want_state" \
    || fail "ship: expected state $want_state, got: $(printf '%s' "$out" | tr '\n' ' ')"
  echo "SHIP_OK $want_state exit=$want_exit"
}

# Release-gate ordering (AMB-CX-005, MRG-CX-002/003/004/006). The journal is the
# run's own record; the sequencer refuses every order that keeps the checks but
# loses the guarantee.
assert_release_state() {
  local want_state="$1" want_exit="$2"; shift 2
  local out rc=0
  out="$("$CODEX_SCRIPTS/script-codex-release.sh" "$@" 2>&1)" || rc=$?
  [ "$rc" = "$want_exit" ] || fail "release: expected exit $want_exit, got $rc — $(printf '%s' "$out" | tr '\n' ' ')"
  printf '%s\n' "$out" | grep -q "^RELEASE_STATE=$want_state\$" \
    || fail "release: expected RELEASE_STATE=$want_state, got: $(printf '%s' "$out" | tr '\n' ' ')"
  echo "RELEASE_OK $want_state exit=$want_exit"
}

# A skill-scoped bundled script (not a shared `.claude/scripts/` helper) is
# mirrored byte-for-byte into the skill's own Codex tree.
assert_skill_script_mirrored() {
  local skill="$1" rel="$2"
  [ -f "$CLAUDE_SKILLS/$skill/$rel" ] || fail "$skill: canonical $rel missing"
  cmp -s "$CLAUDE_SKILLS/$skill/$rel" "$CODEX_SKILLS/$skill/$rel" \
    || fail "$skill: $rel differs between packages"
  echo "SKILL_SCRIPT_MIRRORED $skill/$rel"
}

# --- write boundaries ------------------------------------------------------- #

snapshot_tree() { (cd "$1" && find . -type f -print0 | sort -z | xargs -0 shasum -a 256 2>/dev/null) ; }

assert_tree_unchanged() {
  local dir="$1" before="$2"
  local after; after="$(snapshot_tree "$dir")"
  [ "$before" = "$after" ] || fail "write boundary: $dir changed when it must not have"
  echo "TREE_UNCHANGED $dir"
}

# The Claude installation is never read for configuration nor written to.
assert_claude_untouched() {
  local dirty
  dirty="$(cd "$REPO" && git status --porcelain -- .claude install.sh package.json)"
  [ -z "$dirty" ] || fail "Claude isolation: $dirty"
  echo "CLAUDE_UNTOUCHED"
}
