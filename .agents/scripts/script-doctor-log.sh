#!/usr/bin/env bash
# script-doctor-log.sh — the writer for devkit/DOCTOR.md, the harness-incident ledger.
#
# FILE-OWNED, NOT SKILL-OWNED. Every skill and every script that records a harness
# incident goes through this script, so the row shape, the signature-class enum and
# the append-only rule have exactly one implementation.
#
# Contract: .claude/skills/shared/refs/doctor-logging.md
#
# Usage:
#   script-doctor-log.sh <DOCTOR.md> --skill <name> --signature <class[:step]> \
#                        --context <text> [--mode <mode>] [--status logged|graduated] \
#                        [--date YYYY-MM-DD]
#
#   --skill      the skill that hit the incident, e.g. `pre-merge`.
#   --mode       optional mode/flag, e.g. `--build`. Omit for a skill without modes.
#   --signature  `<class>` or `<class>:<artifact-or-step>`. The class MUST be one of
#                write-miss | retry | tool-error | validator-fail | gate-infra —
#                the enum is what makes the tally (and graduation) possible.
#   --context    1–2 lines of free text. Never tallied; newlines and `|` are folded
#                so a row can never break the table.
#   --status     defaults to `logged`. `/msg --doctor` owns `graduated`.
#   --date       defaults to today.
#
# APPEND-ONLY. The row is appended at end of file — the ledger's `## Incidents`
# table is the last thing in the file, so a crash can lose the new row but can
# never damage the rows already there.
#
# LAZY. No devkit/DOCTOR.md means this repo was never initialised (or predates the
# ledger): exit 3 and write nothing. Callers skip silently — a missing ledger is
# never itself an incident, and this script never creates the file.
#
# Output (KEY=VALUE lines on stdout):
#   DOCTOR_SKILL=<skill+mode>
#   DOCTOR_SIGNATURE=<signature>
#   DOCTOR_APPENDED=yes
#   DOCTOR_ROWS=<n>       incident rows in the file AFTER the write
#
# Exit codes:
#   0  row appended
#   2  usage error, bad signature class, or no `## Incidents` table in the file
#   3  target file absent — the caller skips the log (no devkit)

set -uo pipefail

SELF="$(basename "$0")"
CLASSES="write-miss retry tool-error validator-fail gate-infra"

usage() {
  echo "usage: $SELF <DOCTOR.md> --skill <name> --signature <class[:step]> --context <text> [--mode <mode>] [--status logged|graduated] [--date YYYY-MM-DD]" >&2
  echo "       signature classes: $CLASSES" >&2
  exit 2
}

file=""; skill=""; mode=""; signature=""; context=""; status="logged"; date=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill)     skill="${2-}";     shift 2 || usage ;;
    --mode)      mode="${2-}";      shift 2 || usage ;;
    --signature) signature="${2-}"; shift 2 || usage ;;
    --context)   context="${2-}";   shift 2 || usage ;;
    --status)    status="${2-}";    shift 2 || usage ;;
    --date)      date="${2-}";      shift 2 || usage ;;
    -h|--help)   usage ;;
    --*)         echo "$SELF: unknown flag: $1" >&2; usage ;;
    *)           if [[ -z "$file" ]]; then file="$1"; shift
                 else echo "$SELF: unexpected extra argument: $1" >&2; usage; fi ;;
  esac
done

[[ -n "$file" && -n "$skill" && -n "$signature" && -n "$context" ]] || usage

# The class enum is the whole point of the signature — validate it, never guess.
class="${signature%%:*}"
case " $CLASSES " in
  *" $class "*) ;;
  *) echo "$SELF: signature class must be one of: $CLASSES (got: $class)" >&2; exit 2 ;;
esac

case "$status" in
  logged|graduated) ;;
  *) echo "$SELF: --status must be logged or graduated, got: $status" >&2; exit 2 ;;
esac

[[ -n "$date" ]] || date="$(date +%Y-%m-%d)"
if [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "$SELF: --date must be YYYY-MM-DD, got: $date" >&2
  exit 2
fi

if [[ ! -f "$file" ]]; then
  echo "$SELF: $file not found — nothing logged (skip the log)" >&2
  exit 3
fi

if ! grep -qE '^##[[:space:]]+Incidents[[:space:]]*$' "$file"; then
  echo "$SELF: no '## Incidents' heading in $file — refusing to guess an insertion point" >&2
  exit 2
fi

# Fold anything that would break the row. An incident is never dropped for a
# cosmetic reason — recording it matters more than its punctuation.
fold() { printf '%s' "$1" | tr '\n\r|' '  /' | sed -e 's/  */ /g' -e 's/^ *//' -e 's/ *$//'; }

skill_cell="$(fold "$skill")"
[[ -n "$mode" ]] && skill_cell="$skill_cell $(fold "$mode")"
sig_cell="$(fold "$signature")"
ctx_cell="$(fold "$context")"

if ! printf '| %s | %s | %s | %s | %s |\n' \
      "$date" "$skill_cell" "$sig_cell" "$ctx_cell" "$status" >> "$file"; then
  echo "$SELF: append to $file failed" >&2
  exit 2
fi

rows=$(grep -cE '^\|[[:space:]]*[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]*\|' "$file" 2>/dev/null || true)

echo "DOCTOR_SKILL=$skill_cell"
echo "DOCTOR_SIGNATURE=$sig_cell"
echo "DOCTOR_APPENDED=yes"
echo "DOCTOR_ROWS=$rows"
exit 0
