#!/usr/bin/env bash
# evals/lib/properties.sh — writer properties for eval cases (E3).
#
# Sourced from a case's `cmd`:  . "$REPO/evals/lib/properties.sh"
# Each function prints one stable token on stdout when the property holds (so the
# case's expected/stdout golden captures it), and on a violation prints a reason
# on stderr and returns non-zero. Cases run these under `set -e`, so a violation
# fails the case on its exit code. The runner itself knows nothing about them.

_prop_snap() { mktemp "${TMPDIR:-/tmp}/prop.XXXXXX"; }

# prop_idempotent <file> -- <command...>
# Run the command twice; the file's bytes after run 2 must equal after run 1.
prop_idempotent() {
  local file="$1"; shift
  [[ "${1-}" == "--" ]] || { echo "prop_idempotent: expected -- before the command" >&2; return 2; }
  shift
  local a b rc=0
  a="$(_prop_snap)"; b="$(_prop_snap)"
  "$@" >/dev/null 2>&1 || true; cp "$file" "$a"
  "$@" >/dev/null 2>&1 || true; cp "$file" "$b"
  if cmp -s "$a" "$b"; then
    echo "PROP_IDEMPOTENT=$file"
  else
    echo "PROP_VIOLATION idempotent: $file differs after the second run" >&2
    diff -u "$a" "$b" >&2
    rc=1
  fi
  rm -f "$a" "$b"; return $rc
}

# prop_preserves <file> <sed-line-filter> -- <command...>
# Run the command once; every line NOT matched by the filter must be unchanged.
prop_preserves() {
  local file="$1" filter="$2"; shift 2
  [[ "${1-}" == "--" ]] || { echo "prop_preserves: expected -- before the command" >&2; return 2; }
  shift
  local a b rc=0
  a="$(_prop_snap)"; b="$(_prop_snap)"
  sed "/$filter/d" "$file" > "$a"
  "$@" >/dev/null 2>&1 || true
  sed "/$filter/d" "$file" > "$b"
  if cmp -s "$a" "$b"; then
    echo "PROP_PRESERVES=$file"
  else
    echo "PROP_VIOLATION preserves: $file changed outside /$filter/" >&2
    diff -u "$a" "$b" >&2
    rc=1
  fi
  rm -f "$a" "$b"; return $rc
}

# prop_refuses <expected-exit> <file> -- <command...>
# The command must exit <expected-exit> AND leave the file byte-identical.
prop_refuses() {
  local want="$1" file="$2"; shift 2
  [[ "${1-}" == "--" ]] || { echo "prop_refuses: expected -- before the command" >&2; return 2; }
  shift
  local a rc=0 got=0
  a="$(_prop_snap)"; cp "$file" "$a"
  "$@" >/dev/null 2>&1 || got=$?
  if [[ "$got" != "$want" ]]; then
    echo "PROP_VIOLATION refuses: expected exit $want, got $got" >&2
    rc=1
  elif ! cmp -s "$a" "$file"; then
    echo "PROP_VIOLATION refuses: $file was modified by a refused command" >&2
    diff -u "$a" "$file" >&2
    rc=1
  else
    echo "PROP_REFUSES=$want"
  fi
  rm -f "$a"; return $rc
}
