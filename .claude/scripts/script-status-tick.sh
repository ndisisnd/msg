#!/usr/bin/env bash
# script-status-tick.sh — the sole owner of "has the status interval elapsed?"
# arithmetic for the msg heartbeat (v5.2.0 P0).
#
# FILE-OWNED, NOT SKILL-OWNED. Skills call this at checkpoints; it decides
# whether a status report is due and renders it. No skill re-derives elapsed
# time or interval math — that is exactly the kind of arithmetic a model gets
# wrong, and drift between skills would make the report shape untrustworthy.
#
# Contract: .claude/skills/shared/refs/status-heartbeat.md (lands in phase P5;
# until then this header + update/plan-msg-v5.2.0.md are the source of truth).
#
# Usage (exactly one verb per invocation):
#   script-status-tick.sh --start --phase <name> --run-id <id> \
#                          [--total <n>] [--label <text>] [--now <epoch>]
#   script-status-tick.sh --tick --run-id <id> [--step <text>] [--done <n>] \
#                          [--note <text>] [--finding <blocker|high|medium|low>] \
#                          [--next <text>] [--now <epoch>]
#   script-status-tick.sh --end --run-id <id> [--outcome <text>] [--now <epoch>]
#
#   --now overrides the wall clock on every verb. It exists so the eval harness
#         can drive a scripted fake clock and get stable goldens; test-only.
#
# Cadence — resolved ONCE at --start and carried in the state file for the run's
# whole life (a policy edit mid-run must not move an already-open report window):
#   1. MSG_STATUS_INTERVAL env var, in minutes. "0" disables the heartbeat for
#      this run: --start writes no state and prints nothing, and every
#      --tick/--end against that run-id then prints nothing (or QUIET) but
#      still exits 0.
#   2. devkit/policy.json -> policies.status_cadence {enabled, interval_minutes},
#      read with python3. Absence, parse failure or a missing key falls through
#      silently — the policy file is a nicety, never a dependency.
#   3. Default: enabled, 5 minutes.
#   A resolved interval under 2 minutes is clamped to 2 (plan Q3) and one
#   `STATUS_CLAMPED=<requested>m->2m` note is printed to stderr.
#
# State file: .claude/msg/cache/status/<run-id>.state under the repo root
# (`git rev-parse --show-toplevel`, falling back to $PWD) — already inside the
# gitignored .claude/msg/cache/, so no .gitignore change. Flat KEY=VALUE lines,
# not JSON: this repo's evals run on coreutils+diff alone, and JSON would add
# either a jq dependency or a hand-rolled parser for ~14 scalar fields plus a
# banked-note list. Free text is folded (fold(), below) so a note can never
# corrupt a line or the rendered block.
#
# Failure discipline — THE HEARTBEAT IS OBSERVATIONAL, IT NEVER BREAKS A RUN:
# --tick/--end against a missing, unreadable or corrupt state file print QUIET
# (or END with whatever is known) plus one stderr note, and exit 0. The ONLY
# non-zero exit is 2, for a genuine caller usage error: no verb, more than one
# verb, an unknown flag, a --finding outside the enum, a non-integer
# --done/--total/--now, or a missing --run-id/--phase.
#
# Output:
#   --start  the phase-open line, then `STATUS_STATE=<path>` (silent if disabled)
#   --tick   `REPORT` + the rendered status block, or exactly `QUIET`
#   --end    `END` + a one-line close summary
#
# Exit codes:
#   0  handled (includes every disabled/missing/corrupt heartbeat no-op)
#   2  caller usage error

set -uo pipefail

SELF="$(basename "$0")"
SEVERITIES="blocker high medium low"

usage() {
  echo "usage: $SELF --start --phase <name> --run-id <id> [--total <n>] [--label <text>] [--now <epoch>]" >&2
  echo "       $SELF --tick --run-id <id> [--step <text>] [--done <n>] [--note <text>] [--finding <sev>] [--next <text>] [--now <epoch>]" >&2
  echo "       $SELF --end --run-id <id> [--outcome <text>] [--now <epoch>]" >&2
  echo "       severities: $SEVERITIES" >&2
  exit 2
}

# ---- arg parsing --------------------------------------------------------
verb=""; phase=""; run_id=""; total=""; label=""; step=""; done_val=""
next_val=""; outcome=""; now_override=""
step_given=0; done_given=0; note_given=0; finding_given=0; next_given=0
# --note and --finding may each occur more than once per --tick (spec: "a tick
# reporting two findings must increment both") — accumulate, don't overwrite.
notes=(); findings=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --start|--tick|--end)
      [[ -z "$verb" ]] || { echo "$SELF: only one verb allowed (got --$verb and $1)" >&2; usage; }
      verb="${1#--}"; shift ;;
    --phase)   phase="${2-}";        shift 2 || usage ;;
    --run-id)  run_id="${2-}";       shift 2 || usage ;;
    --total)   total="${2-}";        shift 2 || usage ;;
    --label)   label="${2-}";        shift 2 || usage ;;
    --step)    step="${2-}";         step_given=1;    shift 2 || usage ;;
    --done)    done_val="${2-}";     done_given=1;    shift 2 || usage ;;
    --note)    notes+=("${2-}");     note_given=1;    shift 2 || usage ;;
    --finding) findings+=("${2-}");  finding_given=1; shift 2 || usage ;;
    --next)    next_val="${2-}";     next_given=1;    shift 2 || usage ;;
    --outcome) outcome="${2-}";      shift 2 || usage ;;
    --now)     now_override="${2-}"; shift 2 || usage ;;
    -h|--help) usage ;;
    --*)       echo "$SELF: unknown flag: $1" >&2; usage ;;
    *)         echo "$SELF: unexpected argument: $1" >&2; usage ;;
  esac
done

[[ -n "$verb" ]] || usage
[[ -n "$run_id" ]] || usage
[[ "$verb" != "start" || -n "$phase" ]] || usage
[[ -z "$total" || "$total" =~ ^[0-9]+$ ]] || { echo "$SELF: --total must be a non-negative integer, got: $total" >&2; usage; }
[[ -z "$done_val" || "$done_val" =~ ^[0-9]+$ ]] || { echo "$SELF: --done must be a non-negative integer, got: $done_val" >&2; usage; }
[[ -z "$now_override" || "$now_override" =~ ^[0-9]+$ ]] || { echo "$SELF: --now must be a non-negative integer epoch, got: $now_override" >&2; usage; }
if (( finding_given )); then
  for f in "${findings[@]+"${findings[@]}"}"; do
    case " $SEVERITIES " in
      *" $f "*) ;;
      *) echo "$SELF: --finding must be one of: $SEVERITIES (got: $f)" >&2; usage ;;
    esac
  done
fi

# ---- helpers -------------------------------------------------------------
repo_root() {
  local r; r="$(git rev-parse --show-toplevel 2>/dev/null)"
  [[ -n "$r" ]] && printf '%s' "$r" || printf '%s' "$PWD"
}
now_ts() { [[ -n "$now_override" ]] && printf '%s' "$now_override" || date +%s; }

# Fold anything that would break a state-file line or the rendered block out of
# free text — same spirit as script-doctor-log.sh's fold(). Losing a pipe in a
# note is fine; corrupting the state file is not.
fold() { printf '%s' "$1" | tr '\n\r|=' '    ' | sed -e 's/  */ /g' -e 's/^ *//' -e 's/ *$//'; }

fmt_elapsed() {
  local s=$1
  if (( s < 3600 )); then printf '%dm' $(( s / 60 ))
  else printf '%dh %dm' $(( s / 3600 )) $(( (s % 3600) / 60 )); fi
}

# Cadence is resolved here only on --start (see header); --tick/--end use the
# cheap env_disabled() shortcut below plus whatever was stored at --start.
resolve_cadence() {
  CADENCE_ENABLED=1
  CADENCE_INTERVAL_SEC=$((5 * 60))
  if [[ -n "${MSG_STATUS_INTERVAL:-}" ]]; then
    if [[ "$MSG_STATUS_INTERVAL" == "0" ]]; then
      CADENCE_ENABLED=0; CADENCE_INTERVAL_SEC=0; return
    fi
    if [[ "$MSG_STATUS_INTERVAL" =~ ^[0-9]+$ ]]; then
      local mins="$MSG_STATUS_INTERVAL"
      if (( mins < 2 )); then echo "STATUS_CLAMPED=${mins}m->2m" >&2; mins=2; fi
      CADENCE_INTERVAL_SEC=$(( mins * 60 )); return
    fi
    # malformed env value: never a usage error (constraint 2) — fall through
    # to policy/default as if it had not been set.
  fi
  if command -v python3 >/dev/null 2>&1; then
    local root pj out
    root="$(repo_root)"; pj="$root/devkit/policy.json"
    if [[ -f "$pj" ]]; then
      out="$(python3 -c '
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    sc = d["policies"]["status_cadence"]
    print(("1" if sc.get("enabled", True) else "0"), int(sc.get("interval_minutes", 5)))
except Exception:
    print("DEFAULT")
' "$pj" 2>/dev/null)"
      if [[ "$out" != "DEFAULT" && -n "$out" ]]; then
        local en mins; read -r en mins <<< "$out"
        CADENCE_ENABLED="$en"
        if [[ "$en" == "1" && "$mins" -lt 2 ]]; then
          echo "STATUS_CLAMPED=${mins}m->2m" >&2; mins=2
        fi
        CADENCE_INTERVAL_SEC=$(( mins * 60 ))
      fi
    fi
  fi
}

# Only the explicit "0" override can silence a run --start already opened —
# nothing else needs a live re-check outside of --start.
env_disabled() { [[ "${MSG_STATUS_INTERVAL:-}" == "0" ]]; }

read_state() {
  st_phase=""; st_run_id=""; st_started_at=""; st_last_report_at=""
  st_interval_seconds=""; st_steps_done=""; st_steps_total=""; st_label=""
  st_step=""; st_next=""; st_f_blocker=0; st_f_high=0; st_f_medium=0; st_f_low=0
  st_events=()
  local line key value
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == *"="* ]] || continue
    key="${line%%=*}"; value="${line#*=}"
    case "$key" in
      phase) st_phase="$value" ;;           run_id) st_run_id="$value" ;;
      started_at) st_started_at="$value" ;; last_report_at) st_last_report_at="$value" ;;
      interval_seconds) st_interval_seconds="$value" ;;
      steps_done) st_steps_done="$value" ;; steps_total) st_steps_total="$value" ;;
      label) st_label="$value" ;;           step) st_step="$value" ;;
      next) st_next="$value" ;;
      f_blocker) st_f_blocker="$value" ;;   f_high) st_f_high="$value" ;;
      f_medium) st_f_medium="$value" ;;     f_low) st_f_low="$value" ;;
      EVENT) st_events+=("$value") ;;
      *) : ;;  # unknown key: tolerate for forward-compat — part of the corruption story
    esac
  done < "$1"
}

# The only gate between "trust this state" and "treat it as corrupt": the four
# fields every later computation divides/compares on must be present and
# numeric. Everything else is free text and cannot corrupt the run if garbled.
state_is_valid() {
  [[ -n "$st_run_id" && "$st_started_at" =~ ^[0-9]+$ && \
     "$st_last_report_at" =~ ^[0-9]+$ && "$st_interval_seconds" =~ ^[0-9]+$ ]]
}

write_state() {
  local f="$1" tmp
  tmp="$(mktemp "${f}.XXXXXX" 2>/dev/null)" || tmp="$f"
  {
    printf 'phase=%s\n' "$st_phase";             printf 'run_id=%s\n' "$st_run_id"
    printf 'started_at=%s\n' "$st_started_at";   printf 'last_report_at=%s\n' "$st_last_report_at"
    printf 'interval_seconds=%s\n' "$st_interval_seconds"
    printf 'steps_done=%s\n' "$st_steps_done";   printf 'steps_total=%s\n' "$st_steps_total"
    printf 'label=%s\n' "$st_label";             printf 'step=%s\n' "$st_step"
    printf 'next=%s\n' "$st_next"
    printf 'f_blocker=%s\n' "$st_f_blocker";     printf 'f_high=%s\n' "$st_f_high"
    printf 'f_medium=%s\n' "$st_f_medium";       printf 'f_low=%s\n' "$st_f_low"
    local e; for e in "${st_events[@]+"${st_events[@]}"}"; do printf 'EVENT=%s\n' "$e"; done
  } > "$tmp"
  [[ "$tmp" == "$f" ]] || mv -f "$tmp" "$f"
}

# The report shape is rendered here, once, so wording can never drift between
# the skills calling this script (S3). Minimal report is two lines: the header
# and `now:` — the other three lines are each conditional.
render_report() {
  local elapsed header
  elapsed="$(fmt_elapsed $(( $1 - st_started_at )))"
  header="⏱ $elapsed · $st_phase"
  [[ -n "$st_steps_total" ]] && header="$header · ${st_steps_done:-0}/${st_steps_total}"
  [[ -n "$st_label" ]] && header="$header · $st_label"
  printf '%s\n' "$header"
  if (( ${#st_events[@]} > 0 )); then
    local joined="${st_events[0]}" i
    for (( i=1; i<${#st_events[@]}; i++ )); do joined="$joined; ${st_events[$i]}"; done
    printf 'done: %s\n' "$joined"
  fi
  [[ -n "$st_step" ]] && printf 'now: %s\n' "$st_step"
  if (( st_f_blocker > 0 || st_f_high > 0 || st_f_medium > 0 || st_f_low > 0 )); then
    local issues="issues: $st_f_blocker blocker / $st_f_high high / $st_f_medium medium"
    (( st_f_low > 0 )) && issues="$issues / $st_f_low low"
    printf '%s\n' "$issues"
  fi
  [[ -n "$st_next" ]] && printf 'next: %s\n' "$st_next"
}

root="$(repo_root)"
statedir="$root/.claude/msg/cache/status"
statefile="$statedir/$run_id.state"

# ---- verbs -----------------------------------------------------------------
case "$verb" in
start)
  resolve_cadence
  [[ "$CADENCE_ENABLED" == "0" ]] && exit 0   # disabled: no state, no output (constraint 2)
  mkdir -p "$statedir"
  ts="$(now_ts)"
  st_phase="$(fold "$phase")"; st_run_id="$run_id"
  st_started_at="$ts"; st_last_report_at="$ts"
  st_interval_seconds="$CADENCE_INTERVAL_SEC"
  st_steps_done=0; st_steps_total="$total"
  st_label="$(fold "$label")"; st_step=""; st_next=""
  st_f_blocker=0; st_f_high=0; st_f_medium=0; st_f_low=0
  st_events=()
  write_state "$statefile"
  printf '▶ %s%s\n' "$st_phase" "${st_label:+ · $st_label}"
  printf 'STATUS_STATE=%s\n' "$statefile"
  ;;

tick)
  if env_disabled; then echo "QUIET"; exit 0; fi
  if [[ ! -f "$statefile" ]]; then
    echo "$SELF: no status state for run $run_id — skipping heartbeat" >&2
    echo "QUIET"; exit 0
  fi
  read_state "$statefile"
  if ! state_is_valid; then
    echo "$SELF: status state for run $run_id is corrupt — skipping heartbeat" >&2
    echo "QUIET"; exit 0
  fi
  ts="$(now_ts)"
  (( done_given ))  && st_steps_done="$done_val"
  (( step_given ))  && st_step="$(fold "$step")"
  (( next_given ))  && st_next="$(fold "$next_val")"
  if (( finding_given )); then
    for f in "${findings[@]+"${findings[@]}"}"; do
      case "$f" in
        blocker) st_f_blocker=$(( st_f_blocker + 1 )) ;;
        high)    st_f_high=$(( st_f_high + 1 )) ;;
        medium)  st_f_medium=$(( st_f_medium + 1 )) ;;
        low)     st_f_low=$(( st_f_low + 1 )) ;;
      esac
    done
  fi
  if (( note_given )); then
    for n in "${notes[@]+"${notes[@]}"}"; do st_events+=("$(fold "$n")"); done
  fi
  if (( st_interval_seconds > 0 && (ts - st_last_report_at) >= st_interval_seconds )); then
    echo "REPORT"
    render_report "$ts"
    st_events=()
    st_last_report_at="$ts"
  else
    echo "QUIET"
  fi
  write_state "$statefile"
  ;;

end)
  if env_disabled; then exit 0; fi
  ts="$(now_ts)"
  if [[ ! -f "$statefile" ]]; then
    echo "$SELF: no status state for run $run_id — closing with nothing known" >&2
    echo "END"; echo "⏱ unknown · $run_id · no state recorded"
    exit 0
  fi
  read_state "$statefile"
  if ! state_is_valid; then
    echo "$SELF: status state for run $run_id is corrupt — closing with nothing known" >&2
    echo "END"; echo "⏱ unknown · $run_id · corrupt state discarded"
    rm -f "$statefile"; exit 0
  fi
  echo "END"
  findings="none"
  if (( st_f_blocker > 0 || st_f_high > 0 || st_f_medium > 0 || st_f_low > 0 )); then
    findings="$st_f_blocker blocker / $st_f_high high / $st_f_medium medium / $st_f_low low"
  fi
  summary="⏱ $(fmt_elapsed $(( ts - st_started_at ))) · $st_phase"
  [[ -n "$st_steps_total" ]] && summary="$summary · ${st_steps_done:-0}/${st_steps_total}"
  summary="$summary · findings: $findings"
  [[ -n "$outcome" ]] && summary="$summary · outcome: $(fold "$outcome")"
  printf '%s\n' "$summary"
  rm -f "$statefile"
  ;;
esac

exit 0
