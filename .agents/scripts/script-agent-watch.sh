#!/usr/bin/env bash
# script-agent-watch.sh — the sole owner of "is a spawned leaf still producing
# evidence of work?" arithmetic for msg's subagent waves (v5.5.0 Part B / B1).
#
# FILE-OWNED, NOT SKILL-OWNED. An orchestrator registers each leaf it spawns,
# then calls --check on every poll wake. The script reports each leaf's idle
# age and nothing else. No skill re-derives mtimes, thresholds or tier
# boundaries — that is exactly the arithmetic a model gets wrong, and drift
# between skills would make the stall report untrustworthy.
#
# STRICTLY OBSERVATIONAL — THERE IS NO AUTO-STOP, IN ANY CONFIGURATION.
# This script never kills, signals, pauses or otherwise touches a task. It
# reports facts ("no evidence for 12m"); only a human acts on them. There is
# no `action` key in the state file and no flag that could introduce one.
#
# Contract: .claude/skills/shared/refs/agent-watch.md (B2); until that lands,
# this header + update/plan-msg-v5.5.md §B1 are the source of truth.
#
# Usage (exactly one verb per invocation):
#   script-agent-watch.sh --register --run-id <id> --leaf <leaf-id> \
#                          [--evidence <glob>]... [--label <text>] [--now <epoch>]
#   script-agent-watch.sh --check    --run-id <id> [--now <epoch>]
#   script-agent-watch.sh --done     --run-id <id> --leaf <leaf-id> [--now <epoch>]
#   script-agent-watch.sh --close    --run-id <id> [--now <epoch>]
#
#   --evidence may be repeated; each is a glob, relative to the repo root,
#         naming where this leaf's work lands (its report path, its
#         result-report path, its ticket file …). Globs are expanded at
#         --check time, not at --register time.
#   --now overrides the wall clock on every verb. It exists so the eval harness
#         can drive a scripted fake clock and get stable goldens; test-only.
#
# Output:
#   --register  `WATCH_REGISTERED=<leaf-id>` (silent when the watch is disabled)
#   --check     one line per registered leaf, in registration order —
#                 `OK <leaf> <age>m`        idle below the notice threshold
#                 `NOTICE <leaf> idle <n>m` idle >= notice
#                 `WARN <leaf> idle <n>m`   idle >= warn
#                 `STALL <leaf> idle <n>m`  idle >= stall (assumed stalled)
#               then always `WATCH_SUMMARY=<ok>/<notice>/<warn>/<stall>` last,
#               for cheap parsing.
#   --done      `WATCH_DONE=<leaf-id>`
#   --close     nothing
#
# Liveness evidence per leaf — freshest timestamp wins:
#   1. newest mtime among the files matching that leaf's registered evidence
#      globs (expanded from the repo root at check time);
#   2. newest commit on HEAD since the leaf's register ts
#      (`git log -1 --format=%ct --since=@<ts>`). ANY commit counts — commits
#      are not attributed to a leaf. In a file-disjoint wave that is close
#      enough, and the alternative (parsing packet ids out of subjects) is a
#      guess dressed up as precision. Deliberately simple.
#   3. fallback: the leaf's own register ts.
# Idle age = now - freshest, floored to whole minutes (never negative).
#
# Thresholds — three tiers, resolved ONCE at the first --register for a run-id
# and carried in the state file for the run's whole life (a policy edit
# mid-run must not move an already-open watch window):
#   1. MSG_WATCH_THRESHOLD env var, in minutes.
#        "0"  disables the watch for this run: --register stores a disabled
#             state and prints nothing; --check prints only
#             `WATCH_SUMMARY=0/0/0/0`; everything still exits 0.
#        "N"  a single integer sets stall=N, warn=ceil(2N/3), notice=ceil(N/3)
#             — one knob for callers who only care where "stalled" sits, with
#             the two softer tiers spaced evenly below it.
#        anything else is ignored and falls through, as if unset.
#   2. devkit/policy.json -> policies.agent_watch
#      {enabled, notice_minutes, warn_minutes, stall_minutes}, read with
#      python3. Absence, parse failure or a missing key falls through silently
#      — the policy file is a nicety, never a dependency.
#   3. Default: enabled, notice 5 / warn 10 / stall 15 minutes.
#   Ordering notice < warn < stall is enforced: a resolved set that violates it
#   (or carries a non-positive tier) is repaired to the 5/10/15 defaults and
#   one `WATCH_THRESHOLDS_REPAIRED=<n>/<w>/<s>->5/10/15` note goes to stderr.
#
# State file: .claude/msg/cache/watch/<run-id>.state under the repo root
# (`git rev-parse --show-toplevel`, falling back to $PWD) — already inside the
# gitignored .claude/msg/cache/, so no .gitignore change. Flat KEY=VALUE lines,
# not JSON, for the same reason as script-status-tick.sh: this repo's evals run
# on coreutils+diff alone. Shape:
#   run_id=<id>
#   enabled=<0|1>
#   notice_seconds=<n>  warn_seconds=<n>  stall_seconds=<n>
#   LEAF=<leaf-id>|<register_ts>|<label>      one per live leaf, in order
#   EVID=<leaf-id><TAB><glob>                 zero or more per leaf
# Free text (leaf id, label) is folded so it can never corrupt a line. EVID
# uses a TAB separator precisely so globs keep their `|`, `=` and `*` intact —
# folding a glob would silently break the evidence it names.
#
# Failure discipline — THE WATCH IS OBSERVATIONAL, IT NEVER BREAKS A RUN:
# --check/--done against a missing, unreadable or corrupt state file print one
# stderr note plus `WATCH_SUMMARY=0/0/0/0`, and exit 0. --close on missing
# state is silently fine. The ONLY non-zero exit is 2, for a genuine caller
# usage error: no verb, more than one verb, an unknown flag, a missing
# --run-id, a missing --leaf on --register/--done, or a non-integer --now.
#
# Exit codes:
#   0  handled (includes every disabled/missing/corrupt watch no-op)
#   2  caller usage error

set -uo pipefail

SELF="$(basename "$0")"
DEF_NOTICE=5
DEF_WARN=10
DEF_STALL=15
TAB=$'\t'

usage() {
  echo "usage: $SELF --register --run-id <id> --leaf <leaf-id> [--evidence <glob>]... [--label <text>] [--now <epoch>]" >&2
  echo "       $SELF --check --run-id <id> [--now <epoch>]" >&2
  echo "       $SELF --done --run-id <id> --leaf <leaf-id> [--now <epoch>]" >&2
  echo "       $SELF --close --run-id <id> [--now <epoch>]" >&2
  exit 2
}

# ---- arg parsing --------------------------------------------------------
verb=""; run_id=""; leaf=""; label=""; now_override=""
evidence=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --register|--check|--done|--close)
      [[ -z "$verb" ]] || { echo "$SELF: only one verb allowed (got --$verb and $1)" >&2; usage; }
      verb="${1#--}"; shift ;;
    --run-id)   run_id="${2-}";        shift 2 || usage ;;
    --leaf)     leaf="${2-}";          shift 2 || usage ;;
    --evidence) evidence+=("${2-}");   shift 2 || usage ;;
    --label)    label="${2-}";         shift 2 || usage ;;
    --now)      now_override="${2-}";  shift 2 || usage ;;
    -h|--help)  usage ;;
    --*)        echo "$SELF: unknown flag: $1" >&2; usage ;;
    *)          echo "$SELF: unexpected argument: $1" >&2; usage ;;
  esac
done

[[ -n "$verb" ]] || usage
[[ -n "$run_id" ]] || usage
[[ "$verb" != "register" || -n "$leaf" ]] || usage
[[ "$verb" != "done"     || -n "$leaf" ]] || usage
[[ -z "$now_override" || "$now_override" =~ ^[0-9]+$ ]] || { echo "$SELF: --now must be a non-negative integer epoch, got: $now_override" >&2; usage; }

# ---- helpers -------------------------------------------------------------
repo_root() {
  local r; r="$(git rev-parse --show-toplevel 2>/dev/null)"
  [[ -n "$r" ]] && printf '%s' "$r" || printf '%s' "$PWD"
}
now_ts() { [[ -n "$now_override" ]] && printf '%s' "$now_override" || date +%s; }

# Fold anything that would break a state-file line or a `|`-separated field out
# of free text — same spirit as script-status-tick.sh's fold(). Losing a pipe
# from a label is fine; corrupting the state file is not. NOT used on globs.
fold() { printf '%s' "$1" | tr '\n\r|\t' '    ' | sed -e 's/  */ /g' -e 's/^ *//' -e 's/ *$//'; }
# Globs keep every metacharacter; only line/field breakers go.
fold_glob() { printf '%s' "$1" | tr '\n\r\t' '   ' | sed -e 's/^ *//' -e 's/ *$//'; }

# mtime of one file, portable across BSD (macOS) and GNU stat. Empty on failure.
file_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || true
}

ceil_div() { echo $(( ( $1 + $2 - 1 ) / $2 )); }

# Resolved here only on --register (see header); later verbs read the stored
# tiers, plus the cheap env_disabled() shortcut below.
resolve_thresholds() {
  WATCH_ENABLED=1
  local n="$DEF_NOTICE" w="$DEF_WARN" s="$DEF_STALL" from_env=0
  if [[ -n "${MSG_WATCH_THRESHOLD:-}" ]]; then
    if [[ "$MSG_WATCH_THRESHOLD" == "0" ]]; then
      WATCH_ENABLED=0
      WATCH_NOTICE_SEC=0; WATCH_WARN_SEC=0; WATCH_STALL_SEC=0
      return
    fi
    if [[ "$MSG_WATCH_THRESHOLD" =~ ^[0-9]+$ ]]; then
      s="$MSG_WATCH_THRESHOLD"
      w="$(ceil_div $(( 2 * s )) 3)"
      n="$(ceil_div "$s" 3)"
      from_env=1
    fi
    # malformed env value: never a usage error — fall through to policy/default
    # as if it had not been set.
  fi
  if (( ! from_env )) && command -v python3 >/dev/null 2>&1; then
    local root pj out
    root="$(repo_root)"; pj="$root/devkit/policy.json"
    if [[ -f "$pj" ]]; then
      out="$(python3 -c '
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    aw = d["policies"]["agent_watch"]
    print(("1" if aw.get("enabled", True) else "0"),
          int(aw.get("notice_minutes", 5)),
          int(aw.get("warn_minutes", 10)),
          int(aw.get("stall_minutes", 15)))
except Exception:
    print("DEFAULT")
' "$pj" 2>/dev/null)"
      if [[ "$out" != "DEFAULT" && -n "$out" ]]; then
        local en; read -r en n w s <<< "$out"
        [[ "$en" == "1" ]] || WATCH_ENABLED=0
      fi
    fi
  fi
  # Ordering guard: an unusable tier set is repaired, never obeyed.
  if (( n < 1 || w <= n || s <= w )); then
    echo "WATCH_THRESHOLDS_REPAIRED=${n}/${w}/${s}->${DEF_NOTICE}/${DEF_WARN}/${DEF_STALL}" >&2
    n="$DEF_NOTICE"; w="$DEF_WARN"; s="$DEF_STALL"
  fi
  WATCH_NOTICE_SEC=$(( n * 60 )); WATCH_WARN_SEC=$(( w * 60 )); WATCH_STALL_SEC=$(( s * 60 ))
}

# Only the explicit "0" override can silence a run that --register already
# opened; nothing else needs a live re-check outside of --register.
env_disabled() { [[ "${MSG_WATCH_THRESHOLD:-}" == "0" ]]; }

read_state() {
  st_run_id=""; st_enabled=""; st_notice=""; st_warn=""; st_stall=""
  st_leaves=(); st_evid=()
  local line key value
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == *"="* ]] || continue
    key="${line%%=*}"; value="${line#*=}"
    case "$key" in
      run_id)         st_run_id="$value" ;;
      enabled)        st_enabled="$value" ;;
      notice_seconds) st_notice="$value" ;;
      warn_seconds)   st_warn="$value" ;;
      stall_seconds)  st_stall="$value" ;;
      LEAF)           st_leaves+=("$value") ;;
      EVID)           st_evid+=("$value") ;;
      *) : ;;  # unknown key: tolerate for forward-compat
    esac
  done < "$1"
}

# The only gate between "trust this state" and "treat it as corrupt": the
# fields every later comparison depends on must be present and numeric.
state_is_valid() {
  [[ -n "$st_run_id" && "$st_enabled" =~ ^[01]$ && "$st_notice" =~ ^[0-9]+$ && \
     "$st_warn" =~ ^[0-9]+$ && "$st_stall" =~ ^[0-9]+$ ]]
}

write_state() {
  local f="$1" tmp e
  tmp="$(mktemp "${f}.XXXXXX" 2>/dev/null)" || tmp="$f"
  {
    printf 'run_id=%s\n' "$st_run_id"
    printf 'enabled=%s\n' "$st_enabled"
    printf 'notice_seconds=%s\n' "$st_notice"
    printf 'warn_seconds=%s\n' "$st_warn"
    printf 'stall_seconds=%s\n' "$st_stall"
    for e in "${st_leaves[@]+"${st_leaves[@]}"}"; do printf 'LEAF=%s\n' "$e"; done
    for e in "${st_evid[@]+"${st_evid[@]}"}"; do printf 'EVID=%s\n' "$e"; done
  } > "$tmp"
  [[ "$tmp" == "$f" ]] || mv -f "$tmp" "$f"
}

degraded_exit() {   # missing/corrupt state on --check/--done
  echo "$SELF: $1" >&2
  echo "WATCH_SUMMARY=0/0/0/0"
  exit 0
}

root="$(repo_root)"
statedir="$root/.claude/msg/cache/watch"
statefile="$statedir/$run_id.state"

# ---- verbs -----------------------------------------------------------------
case "$verb" in
register)
  ts="$(now_ts)"
  leaf_id="$(fold "$leaf")"
  if [[ -f "$statefile" ]]; then
    read_state "$statefile"
    state_is_valid || { st_run_id="$run_id"; st_enabled=""; st_leaves=(); st_evid=(); }
  fi
  if [[ ! "${st_enabled:-}" =~ ^[01]$ ]]; then
    # First --register for this run-id (or a discarded corrupt state): resolve
    # the tiers once, here, and never again for this run.
    resolve_thresholds
    mkdir -p "$statedir"
    st_run_id="$run_id"; st_enabled="$WATCH_ENABLED"
    st_notice="$WATCH_NOTICE_SEC"; st_warn="$WATCH_WARN_SEC"; st_stall="$WATCH_STALL_SEC"
    st_leaves=(); st_evid=()
  fi
  if [[ "$st_enabled" == "0" ]]; then
    write_state "$statefile"   # disabled marker, so --check stays silent
    exit 0
  fi
  # Re-registering a leaf refreshes it rather than duplicating it.
  kept=(); for l in "${st_leaves[@]+"${st_leaves[@]}"}"; do
    [[ "${l%%|*}" == "$leaf_id" ]] || kept+=("$l")
  done
  st_leaves=("${kept[@]+"${kept[@]}"}" "$leaf_id|$ts|$(fold "$label")")
  kept=(); for e in "${st_evid[@]+"${st_evid[@]}"}"; do
    [[ "${e%%"$TAB"*}" == "$leaf_id" ]] || kept+=("$e")
  done
  st_evid=("${kept[@]+"${kept[@]}"}")
  for g in "${evidence[@]+"${evidence[@]}"}"; do
    g="$(fold_glob "$g")"; [[ -n "$g" ]] && st_evid+=("$leaf_id$TAB$g")
  done
  write_state "$statefile"
  printf 'WATCH_REGISTERED=%s\n' "$leaf_id"
  ;;

check)
  if env_disabled; then echo "WATCH_SUMMARY=0/0/0/0"; exit 0; fi
  [[ -f "$statefile" ]] || degraded_exit "no watch state for run $run_id — nothing to report"
  read_state "$statefile"
  state_is_valid || degraded_exit "watch state for run $run_id is corrupt — nothing to report"
  if [[ "$st_enabled" == "0" ]]; then echo "WATCH_SUMMARY=0/0/0/0"; exit 0; fi

  ts="$(now_ts)"
  n_ok=0; n_notice=0; n_warn=0; n_stall=0
  for l in "${st_leaves[@]+"${st_leaves[@]}"}"; do
    lid="${l%%|*}"; rest="${l#*|}"; rts="${rest%%|*}"
    [[ "$rts" =~ ^[0-9]+$ ]] || continue   # garbled row: skip, never fail
    freshest="$rts"
    # (1) evidence globs, expanded now, from the repo root
    for e in "${st_evid[@]+"${st_evid[@]}"}"; do
      [[ "${e%%"$TAB"*}" == "$lid" ]] || continue
      glob="${e#*"$TAB"}"
      while IFS= read -r f; do
        [[ -n "$f" ]] || continue
        m="$(file_mtime "$root/$f")"
        [[ "$m" =~ ^[0-9]+$ ]] || continue
        (( m > freshest )) && freshest="$m"
      done < <(
        cd "$root" 2>/dev/null || exit 0
        shopt -s nullglob dotglob
        # shellcheck disable=SC2086  # intentional: $glob must be expanded
        for f in $glob; do [[ -e "$f" ]] && printf '%s\n' "$f"; done
      )
    done
    # (2) newest commit on HEAD since this leaf was registered (any commit)
    c="$(git -C "$root" log -1 --format=%ct --since="@$rts" 2>/dev/null)"
    if [[ "$c" =~ ^[0-9]+$ ]] && (( c > freshest )); then freshest="$c"; fi
    # (3) fallback is the register ts, already seeded above
    idle=$(( ts - freshest )); (( idle < 0 )) && idle=0
    mins=$(( idle / 60 ))
    if   (( idle >= st_stall ));  then printf 'STALL %s idle %dm\n' "$lid" "$mins";  n_stall=$((n_stall+1))
    elif (( idle >= st_warn ));   then printf 'WARN %s idle %dm\n' "$lid" "$mins";   n_warn=$((n_warn+1))
    elif (( idle >= st_notice )); then printf 'NOTICE %s idle %dm\n' "$lid" "$mins"; n_notice=$((n_notice+1))
    else printf 'OK %s %dm\n' "$lid" "$mins"; n_ok=$((n_ok+1))
    fi
  done
  printf 'WATCH_SUMMARY=%d/%d/%d/%d\n' "$n_ok" "$n_notice" "$n_warn" "$n_stall"
  ;;

done)
  if env_disabled; then exit 0; fi
  leaf_id="$(fold "$leaf")"
  [[ -f "$statefile" ]] || degraded_exit "no watch state for run $run_id — nothing to drop"
  read_state "$statefile"
  state_is_valid || degraded_exit "watch state for run $run_id is corrupt — nothing to drop"
  kept=(); for l in "${st_leaves[@]+"${st_leaves[@]}"}"; do
    [[ "${l%%|*}" == "$leaf_id" ]] || kept+=("$l")
  done
  st_leaves=("${kept[@]+"${kept[@]}"}")
  kept=(); for e in "${st_evid[@]+"${st_evid[@]}"}"; do
    [[ "${e%%"$TAB"*}" == "$leaf_id" ]] || kept+=("$e")
  done
  st_evid=("${kept[@]+"${kept[@]}"}")
  write_state "$statefile"
  printf 'WATCH_DONE=%s\n' "$leaf_id"
  ;;

close)
  rm -f "$statefile"
  ;;
esac

exit 0
