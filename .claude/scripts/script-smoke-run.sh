#!/usr/bin/env bash
# script-smoke-run.sh — the executor for the v2 smoke contract + the
# config-gated macOS release checks.
#
# `refs/verify-deploy.md` describes three retry mechanics in prose — one-shot,
# `poll` (wait for a late-live target), `watch_window` (re-check health after
# it passes) — plus three macOS checks (notarization poll, signing/Gatekeeper,
# appcast fetch). Every one of them is "run a command, read a status, compare,
# maybe sleep and repeat": a fixed result given its inputs. A model hand-rolling
# a bounded retry loop miscounts attempts, drops the ceiling, or turns a
# still-warming target into a false failure. This script runs the loops; the
# model relays the outcome and writes the finding.
#
# What stays with the model: whether to offer the rollback, what the finding
# message says in context, and every human gate. This script never asks, never
# rolls back, never merges, and never writes a tracked file.
#
# Contract:
#   .claude/skills/merge/refs/verify-deploy.md § Smoke contract v2
#   .claude/skills/merge/refs/verify-deploy.md § macOS release checks
#   .claude/skills/merge/refs/output-schema.md § platforms[] · smoke
#
# Usage:
#   script-smoke-run.sh --platform <p> [--cmd <cmd>]
#                       [--watch-window <duration>/<interval>]
#                       [--poll <timeout>/<interval>]
#                       [--model deploy|submission] [--mode staging|production]
#                       [--notarize-cmd <cmd>] [--signing-cmd <cmd>]
#                       [--appcast-url <url>] [--version <x.y.z>]
#                       [--notarize-poll <timeout>/<interval>]
#                       [--log-dir <dir>] [--repo <dir>]
#
#   --cmd            the smoke command (the PLATFORMS.md `smoke_cmd` column).
#                    EMPTY / omitted ⇒ RESULT=skipped, exit 0 — verification is
#                    skipped with a note, never invented and never a failure.
#   --poll           run `cmd` every <interval> until exit 0 or <timeout>,
#                    BEFORE the first verdict. Timeout with no pass is the
#                    distinct `smoke-never-live` verdict, not a generic fail.
#   --watch-window   after a passing first verdict, re-run `cmd` every
#                    <interval> across <duration>. Any non-zero re-check is a
#                    degrade → verdict fail.
#   --model          `submission` relabels a pass as backend/build health,
#                    never "live" (the label discipline, refs/submission.md).
#   --mode           `staging` suppresses the appcast check (there is no
#                    NEXT_VERSION to assert in --staging).
#   --notarize-cmd   macOS `deploy` only — polled to a terminal status, bounded
#                    by --notarize-poll, else --poll, else the default 15m/30s.
#                    NEVER a single read: a lone `In Progress` is not a stall.
#   --signing-cmd    macOS `deploy` only — exit 0 = signed + Gatekeeper-accepted.
#   --appcast-url    macOS `deploy` + --mode production + --version — the feed
#                    must be reachable AND carry the version.
#
# Durations accept `s`/`m`/`h` suffixes (bare digits = seconds).
#
# Output (stdout, KEY=VALUE lines, always the full key set):
#   PLATFORM=<p>
#   MODE=one_shot|poll|watch|poll+watch|skipped
#   ATTEMPTS=<n>              total `cmd` invocations (1 + poll retries +
#                             watch re-checks; summed when composed)
#   WINDOW=held|degraded|timed_out|            (empty for one-shot / skipped)
#   RESULT=verified|smoke-failed|smoke-never-live|degraded-in-window|skipped
#   EXIT_CODE=<n>             the last `cmd` exit ("" when it never ran)
#   LABEL=live-target|backend-build-health|    what the pass/fail is ABOUT
#   RULE=smoke-failed|smoke-never-live|        the finding rule ("" on a pass)
#   SEVERITY=high|                             ("" on a pass)
#   LOG=<path>                stdout+stderr of every invocation
#   NOTARIZATION=verified|invalid|stall|unconfigured
#   NOTARIZATION_STATUS=<last status line read>
#   NOTARIZATION_ATTEMPTS=<n>
#   SIGNING=verified|fail|unconfigured
#   APPCAST=verified|stale|unconfigured|inactive-staging
#   MACOS_RULE=notarization-invalid|notarization-stall|signing-fail|appcast-stale|
#   FINDING=<one-line JSON finding skeleton>   emitted ONLY on a failure; the
#                             model fills `id`/`evidence.snippet` from LOG and
#                             relays it — it never re-implements the loop.
#
# Exit codes:
#   0  RESULT=verified (or skipped — nothing configured)
#   3  smoke-failed          (non-zero first verdict)
#   4  smoke-never-live      (poll ceiling exhausted, nothing ever came up)
#   5  degraded-in-window    (passed, then a re-check failed)
#   6  a macOS release check produced a finding (MACOS_RULE names which)
#   2  usage error
#
# The exit code is the SMOKE verdict; a macOS finding on an otherwise-passing
# smoke exits 6. Any non-zero exit means verdict `fail` for the caller.
#
# Deterministic in shape (mode/attempts/window derive from the declaration and
# the commands' own exit codes); wall-clock durations are bounded, never
# unbounded, and the script never backgrounds itself.

set -uo pipefail

SELF="$(basename "$0")"

die() { echo "$SELF: $1" >&2; exit 2; }

usage() {
  echo "usage: $SELF --platform <p> [--cmd <cmd>] [--poll <t>/<i>] [--watch-window <d>/<i>] [--model deploy|submission] [--mode staging|production] [--notarize-cmd <c>] [--signing-cmd <c>] [--appcast-url <u>] [--version <v>] [--log-dir <d>] [--repo <d>]" >&2
  exit 2
}

PLATFORM=""; CMD=""; WATCH=""; POLL=""; MODEL="deploy"; RUNMODE="production"
NOTARIZE_CMD=""; SIGNING_CMD=""; APPCAST_URL=""; VERSION=""; NOTARIZE_POLL=""
LOG_DIR=""; REPO="$PWD"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)       [[ $# -ge 2 ]] || usage; PLATFORM="$2"; shift 2 ;;
    --platform=*)     PLATFORM="${1#--platform=}"; shift ;;
    --cmd)            [[ $# -ge 2 ]] || usage; CMD="$2"; shift 2 ;;
    --cmd=*)          CMD="${1#--cmd=}"; shift ;;
    --watch-window)   [[ $# -ge 2 ]] || usage; WATCH="$2"; shift 2 ;;
    --watch-window=*) WATCH="${1#--watch-window=}"; shift ;;
    --poll)           [[ $# -ge 2 ]] || usage; POLL="$2"; shift 2 ;;
    --poll=*)         POLL="${1#--poll=}"; shift ;;
    --model)          [[ $# -ge 2 ]] || usage; MODEL="$2"; shift 2 ;;
    --model=*)        MODEL="${1#--model=}"; shift ;;
    --mode)           [[ $# -ge 2 ]] || usage; RUNMODE="$2"; shift 2 ;;
    --mode=*)         RUNMODE="${1#--mode=}"; shift ;;
    --notarize-cmd)   [[ $# -ge 2 ]] || usage; NOTARIZE_CMD="$2"; shift 2 ;;
    --notarize-cmd=*) NOTARIZE_CMD="${1#--notarize-cmd=}"; shift ;;
    --notarize-poll)  [[ $# -ge 2 ]] || usage; NOTARIZE_POLL="$2"; shift 2 ;;
    --notarize-poll=*) NOTARIZE_POLL="${1#--notarize-poll=}"; shift ;;
    --signing-cmd)    [[ $# -ge 2 ]] || usage; SIGNING_CMD="$2"; shift 2 ;;
    --signing-cmd=*)  SIGNING_CMD="${1#--signing-cmd=}"; shift ;;
    --appcast-url)    [[ $# -ge 2 ]] || usage; APPCAST_URL="$2"; shift 2 ;;
    --appcast-url=*)  APPCAST_URL="${1#--appcast-url=}"; shift ;;
    --version)        [[ $# -ge 2 ]] || usage; VERSION="$2"; shift 2 ;;
    --version=*)      VERSION="${1#--version=}"; shift ;;
    --log-dir)        [[ $# -ge 2 ]] || usage; LOG_DIR="$2"; shift 2 ;;
    --log-dir=*)      LOG_DIR="${1#--log-dir=}"; shift ;;
    --repo)           [[ $# -ge 2 ]] || usage; REPO="$2"; shift 2 ;;
    --repo=*)         REPO="${1#--repo=}"; shift ;;
    -h|--help)        sed -n '2,100p' "$0"; exit 0 ;;
    *) usage ;;
  esac
done

[[ -n "$PLATFORM" ]] || usage
[[ -d "$REPO" ]] || die "not a directory: $REPO"
case "$MODEL" in deploy|submission) ;; *) die "--model must be deploy|submission" ;; esac
case "$RUNMODE" in staging|production) ;; *) die "--mode must be staging|production" ;; esac

if [[ -z "$LOG_DIR" ]]; then LOG_DIR="$(mktemp -d)"; else mkdir -p "$LOG_DIR" 2>/dev/null || die "cannot create --log-dir $LOG_DIR"; fi
LOG="$LOG_DIR/smoke-$PLATFORM.log"
: >"$LOG"

# ── duration parsing ────────────────────────────────────────────────────────
# `90` / `90s` / `5m` / `1h` → seconds. Anything else is a usage error: a
# silently-misparsed ceiling is exactly the drift this script exists to remove.
secs() {
  local v="$1" n u
  n="${v%[smhSMH]}"; u="${v#$n}"
  [[ "$n" =~ ^[0-9]+$ ]] || die "bad duration: $v (want <n>[s|m|h])"
  case "$u" in
    ""|s|S) echo "$n" ;;
    m|M)    echo $(( n * 60 )) ;;
    h|H)    echo $(( n * 3600 )) ;;
    *)      die "bad duration unit in: $v" ;;
  esac
}

split_pair() {   # "<a>/<b>" → sets PAIR_A / PAIR_B in seconds
  local raw="$1" label="$2"
  [[ "$raw" == */* ]] || die "$label must be <duration>/<interval>, got: $raw"
  PAIR_A="$(secs "${raw%%/*}")"
  PAIR_B="$(secs "${raw##*/}")"
  [[ "$PAIR_B" -gt 0 ]] || die "$label interval must be > 0"
}

ATTEMPTS=0; EXIT_CODE=""; WINDOW=""; RESULT=""; RULE=""; SEVERITY=""
NOTARIZATION="unconfigured"; NOTARIZATION_STATUS=""; NOTARIZATION_ATTEMPTS=0
SIGNING="unconfigured"; APPCAST="unconfigured"; MACOS_RULE=""
FINDING=""

run_cmd() {   # run the smoke cmd once; sets EXIT_CODE, appends to the log
  ATTEMPTS=$(( ATTEMPTS + 1 ))
  { echo "--- attempt $ATTEMPTS  $(date -u +%Y-%m-%dT%H:%M:%SZ)  $CMD"; } >>"$LOG"
  ( cd "$REPO" && eval "$CMD" ) >>"$LOG" 2>&1
  EXIT_CODE=$?
  echo "--- exit $EXIT_CODE" >>"$LOG"
}

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' '; }

make_finding() {   # rule, severity, message, suggestion
  FINDING="{\"id\":null,\"source\":\"merge\",\"severity\":\"$2\",\"category\":\"deploy\",\"rule\":\"$1\",\"message\":\"$(json_escape "$3")\",\"file\":null,\"line\":null,\"evidence\":{\"tool\":\"merge\",\"snippet\":\"<last lines of $LOG — redact secrets>\"},\"suggestion\":\"$(json_escape "$4")\",\"repro\":\"$(json_escape "$CMD")\",\"regression_of\":null}"
}

if [[ "$MODEL" == "submission" ]]; then LABEL="backend-build-health"; else LABEL="live-target"; fi

# ── macOS release checks — config-gated, model-gated, run around the smoke ──
# Order per refs/verify-deploy.md § Ordering: notarization → signing → appcast,
# then the generic smoke. Each is silent when undeclared.
macos_checks() {
  [[ "$PLATFORM" == "macos" && "$MODEL" == "deploy" ]] || return 0

  if [[ -n "$NOTARIZE_CMD" ]]; then
    local bound="${NOTARIZE_POLL:-${POLL:-15m/30s}}"
    split_pair "$bound" "--notarize-poll"
    local ceiling="$PAIR_A" every="$PAIR_B" start now out
    start=$(date +%s)
    while :; do
      NOTARIZATION_ATTEMPTS=$(( NOTARIZATION_ATTEMPTS + 1 ))
      echo "--- notarize attempt $NOTARIZATION_ATTEMPTS" >>"$LOG"
      out="$( cd "$REPO" && eval "$NOTARIZE_CMD" 2>&1 )"
      printf '%s\n' "$out" >>"$LOG"
      NOTARIZATION_STATUS="$(printf '%s\n' "$out" | grep -iE '^[[:space:]]*status:' | tail -1 | sed 's/^[[:space:]]*//')"
      case "$NOTARIZATION_STATUS" in
        *Accepted*|*accepted*)         NOTARIZATION="verified"; break ;;
        *Invalid*|*invalid*|*Rejected*|*rejected*)
          NOTARIZATION="invalid"; MACOS_RULE="notarization-invalid"
          make_finding notarization-invalid high \
            "macOS notarization returned Invalid for the $PLATFORM artifact ($NOTARIZATION_STATUS)" \
            "Notarization is the failing step, not the build. Re-notarize after fixing the reported issue; the failed-ship loop offers the rollback lever first."
          break ;;
      esac
      now=$(date +%s)
      # Only ceiling-exhaustion is a stall — a non-terminal read INSIDE the
      # bound is `pending`, so keep polling.
      if [[ $(( now - start + every )) -gt "$ceiling" ]]; then
        NOTARIZATION="stall"; MACOS_RULE="notarization-stall"
        make_finding notarization-stall high \
          "macOS notarization did not reach a terminal status within ${bound%%/*} (last: ${NOTARIZATION_STATUS:-no status line}, ${NOTARIZATION_ATTEMPTS} reads)" \
          "A stall is diagnostically distinct from a reject: the notary is still working or wedged. Re-check with the notarize_status_cmd before re-submitting."
        break
      fi
      sleep "$every"
    done
  fi

  if [[ -n "$SIGNING_CMD" && -z "$MACOS_RULE" ]]; then
    echo "--- signing check" >>"$LOG"
    ( cd "$REPO" && eval "$SIGNING_CMD" ) >>"$LOG" 2>&1
    if [[ $? -eq 0 ]]; then
      SIGNING="verified"
    else
      SIGNING="fail"; MACOS_RULE="signing-fail"
      make_finding signing-fail high \
        "macOS signing/Gatekeeper check rejected the $PLATFORM artifact (spctl: rejected)" \
        "The shipped app will not open on a user's Mac. Re-sign and re-verify before shipping; the failed-ship loop offers the rollback lever first."
    fi
  fi

  if [[ -n "$APPCAST_URL" ]]; then
    if [[ "$RUNMODE" == "staging" ]]; then
      # No NEXT_VERSION exists in --staging — never fabricate one to check.
      APPCAST="inactive-staging"
    elif [[ -z "$VERSION" ]]; then
      APPCAST="unconfigured"
      echo "--- appcast skipped: --appcast-url given without --version" >>"$LOG"
    else
      echo "--- appcast $APPCAST_URL (expect $VERSION)" >>"$LOG"
      if curl -fsS "$APPCAST_URL" 2>>"$LOG" | grep -q -- "$VERSION"; then
        APPCAST="verified"
      else
        APPCAST="stale"
        if [[ -z "$MACOS_RULE" ]]; then
          MACOS_RULE="appcast-stale"
          make_finding appcast-stale high \
            "macOS appcast $APPCAST_URL is unreachable or missing version $VERSION" \
            "The update channel did not publish, so existing users will never be offered the update. Re-publish the appcast item for this release."
        fi
      fi
    fi
  fi
}

emit_and_exit() {
  cat <<EOF
PLATFORM=$PLATFORM
MODE=$MODE
ATTEMPTS=$ATTEMPTS
WINDOW=$WINDOW
RESULT=$RESULT
EXIT_CODE=$EXIT_CODE
LABEL=$LABEL
RULE=$RULE
SEVERITY=$SEVERITY
LOG=$LOG
NOTARIZATION=$NOTARIZATION
NOTARIZATION_STATUS=$NOTARIZATION_STATUS
NOTARIZATION_ATTEMPTS=$NOTARIZATION_ATTEMPTS
SIGNING=$SIGNING
APPCAST=$APPCAST
MACOS_RULE=$MACOS_RULE
EOF
  [[ -n "$FINDING" ]] && echo "FINDING=$FINDING"
  exit "$1"
}

# ── mode resolution (derived, never authored) ───────────────────────────────
if [[ -z "$CMD" ]]; then
  MODE="skipped"; RESULT="skipped"; LABEL=""
  macos_checks
  if [[ -n "$MACOS_RULE" ]]; then emit_and_exit 6; fi
  emit_and_exit 0
fi

if   [[ -n "$POLL" && -n "$WATCH" ]]; then MODE="poll+watch"
elif [[ -n "$POLL" ]];               then MODE="poll"
elif [[ -n "$WATCH" ]];              then MODE="watch"
else                                      MODE="one_shot"
fi

macos_checks

# ── poll — wait for a late-live target, BEFORE the first verdict ────────────
if [[ -n "$POLL" ]]; then
  split_pair "$POLL" "--poll"
  ceiling="$PAIR_A"; every="$PAIR_B"; start=$(date +%s)
  while :; do
    run_cmd
    [[ "$EXIT_CODE" -eq 0 ]] && break
    now=$(date +%s)
    if [[ $(( now - start + every )) -gt "$ceiling" ]]; then
      RESULT="smoke-never-live"; RULE="smoke-never-live"; SEVERITY="high"
      WINDOW="timed_out"
      make_finding smoke-never-live high \
        "$PLATFORM never went live within the ${POLL%%/*} poll window (${ATTEMPTS} attempts, last exit $EXIT_CODE)" \
        "The target never came up inside the bounded wait — a different diagnosis than 'up but unhealthy'. The failed-ship loop offers the platform's rollback lever before the fix loop."
      emit_and_exit 4
    fi
    sleep "$every"
  done
else
  run_cmd
fi

# ── first verdict ───────────────────────────────────────────────────────────
if [[ "$EXIT_CODE" -ne 0 ]]; then
  RESULT="smoke-failed"; RULE="smoke-failed"; SEVERITY="high"
  if [[ "$MODEL" == "submission" ]]; then
    make_finding smoke-failed high \
      "$PLATFORM backend/build health check failed (exit $EXIT_CODE) — the submission itself is unaffected" \
      "The backend/build target is not healthy. The failed-ship loop offers the platform's rollout_halt_cmd (if configured) before the fix loop; then fix forward via /pre-merge."
  else
    make_finding smoke-failed high \
      "$RUNMODE deploy for $PLATFORM is up but failing its smoke check (exit $EXIT_CODE)" \
      "The deployed target is not healthy. The failed-ship loop offers the platform's rollback_cmd (if configured) before the fix loop; then fix forward via /pre-merge."
  fi
  emit_and_exit 3
fi

# ── watch-window — re-check health AFTER a passing first verdict ────────────
if [[ -n "$WATCH" ]]; then
  split_pair "$WATCH" "--watch-window"
  duration="$PAIR_A"; every="$PAIR_B"; start=$(date +%s)
  while :; do
    now=$(date +%s)
    [[ $(( now - start + every )) -gt "$duration" ]] && break
    sleep "$every"
    run_cmd
    if [[ "$EXIT_CODE" -ne 0 ]]; then
      elapsed=$(( $(date +%s) - start ))
      RESULT="degraded-in-window"; RULE="smoke-failed"; SEVERITY="high"
      WINDOW="degraded"
      make_finding smoke-failed high \
        "$PLATFORM ${LABEL} passed initially then degraded at ${elapsed}s into a ${WATCH%%/*} watch-window (exit $EXIT_CODE)" \
        "Health did not hold. This is exactly the signal a redeploy-last-good rollback answers — the failed-ship loop OFFERS it (always-ask, never auto) before the fix loop."
      emit_and_exit 5
    fi
  done
  WINDOW="held"
fi

RESULT="verified"
[[ -n "$MACOS_RULE" ]] && emit_and_exit 6
emit_and_exit 0
