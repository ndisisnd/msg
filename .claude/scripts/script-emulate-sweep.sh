#!/usr/bin/env bash
# script-emulate-sweep.sh — clear the stale build processes from the last
# `/emulate` attempt, and nothing else.
#
# This is the ONE destructive step in the /emulate lane, so it is deliberately
# narrow. Three rules hold it in:
#
#   1. ALLOWLIST. Only process shapes /emulate itself could have started —
#      a Metro / Expo dev server, a Gradle build or daemon, an xcodebuild run.
#      There is no broad `killall`, and no pattern a user could supply.
#   2. SCOPE. A process is a candidate only when it is attributable to THIS
#      repo — its working directory resolves inside the repo, or its command
#      line names the repo path — or when it holds the dev-server port this run
#      is about to bind. A Metro server for another project is never touched.
#   3. ANNOUNCED. Every candidate is printed with its pid, the pattern it
#      matched and why. `--dry-run` prints exactly that list and stops.
#
# TERM first, KILL only after a bounded wait. A build that is mid-write to a
# Gradle cache deserves the chance to close its files.
#
# Usage:
#   script-emulate-sweep.sh --platform ios|android [--runner expo|native]
#                           [--repo <dir>] [--port <n>] [--device-id <id>]
#                           [--cold-boot] [--dry-run] [--grace <secs>]
#
#   --device-id  the device this run will use; only meaningful with --cold-boot
#   --cold-boot  additionally shut down THAT device (never any other, never by
#                default — booting onto a running simulator is normal and fast)
#   --grace      seconds between TERM and KILL (default: 5)
#
# Output (stdout, key=value lines):
#   SWEEP_MODE=dry-run|live
#   SWEEP_CANDIDATE=<pid>|<pattern>|<reason>     zero or more, in pid order
#   SWEEP_CANDIDATE_COUNT=<n>
#   SWEEP_SIGNALLED=<pid>|<pattern>|TERM|KILL    live mode only
#   SWEEP_KILLED_COUNT=<n>
#   SWEEP_DEVICE_SHUTDOWN=<id>|skipped
#
# Exit codes:
#   0  swept (including "nothing matched" — an empty sweep is a normal run)
#   2  usage error
#
# Never fails the run: a process that refuses to die is reported, not fatal.
# /emulate's job is to launch, and a stubborn stale daemon is the user's call.
set -uo pipefail

SELF="script-emulate-sweep"

REPO="$PWD"
PLATFORM=""
RUNNER="native"
PORT=8081
DEVICE_ID=""
COLD_BOOT=false
DRY_RUN=false
GRACE=5

die() { printf 'ERROR=usage\n'; printf '%s: %s\n' "$SELF" "$1" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)  [[ $# -ge 2 ]] || die "--platform needs a value"; PLATFORM="$2"; shift 2 ;;
    --platform=*) PLATFORM="${1#*=}"; shift ;;
    --runner)    [[ $# -ge 2 ]] || die "--runner needs a value"; RUNNER="$2"; shift 2 ;;
    --runner=*)  RUNNER="${1#*=}"; shift ;;
    --repo)      [[ $# -ge 2 ]] || die "--repo needs a value"; REPO="$2"; shift 2 ;;
    --repo=*)    REPO="${1#*=}"; shift ;;
    --port)      [[ $# -ge 2 ]] || die "--port needs a value"; PORT="$2"; shift 2 ;;
    --port=*)    PORT="${1#*=}"; shift ;;
    --device-id) [[ $# -ge 2 ]] || die "--device-id needs a value"; DEVICE_ID="$2"; shift 2 ;;
    --device-id=*) DEVICE_ID="${1#*=}"; shift ;;
    --grace)     [[ $# -ge 2 ]] || die "--grace needs a value"; GRACE="$2"; shift 2 ;;
    --grace=*)   GRACE="${1#*=}"; shift ;;
    --cold-boot) COLD_BOOT=true; shift ;;
    --dry-run)   DRY_RUN=true; shift ;;
    -h|--help)   sed -n '2,50p' "$0"; exit 0 ;;
    *)           die "unknown flag: $1" ;;
  esac
done

case "$PLATFORM" in
  ios|android) ;;
  adr) PLATFORM="android" ;;
  *) die "--platform must be ios or android (got: '${PLATFORM}')" ;;
esac
[[ -d "$REPO" ]] || die "no such directory: $REPO"
REPO="$(cd "$REPO" && pwd -P)"

# ── The allowlist ────────────────────────────────────────────────────────────
# Deliberately anchored on the tool name, not on a language runtime: matching
# bare `node` or bare `java` would sweep half the user's machine.
PATTERNS=()
case "$RUNNER" in
  expo) PATTERNS+=("expo start" "expo run:" "react-native start" "cli.js start" "metro") ;;
esac
case "$PLATFORM" in
  ios)     PATTERNS+=("xcodebuild" "expo run:ios") ;;
  android) PATTERNS+=("gradlew" "GradleDaemon" "gradle-launcher" "expo run:android") ;;
esac

# ── Candidate collection ─────────────────────────────────────────────────────
# `cwd` is the strong attribution signal and the only one that catches a daemon
# started from this repo whose command line says nothing about it.
proc_cwd() {
  command -v lsof >/dev/null 2>&1 || return 1
  lsof -a -p "$1" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1
}

PORT_PIDS=""
if command -v lsof >/dev/null 2>&1; then
  PORT_PIDS="$(lsof -ti "tcp:${PORT}" -sTCP:LISTEN 2>/dev/null | tr '\n' ' ')"
fi

SELF_PID=$$
ANCESTORS=" $SELF_PID "
p=$PPID
while [[ -n "$p" && "$p" != "0" && "$p" != "1" ]]; do
  ANCESTORS+="$p "
  p="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"
done

CAND_PIDS=(); CAND_PATTERNS=(); CAND_REASONS=()

add_candidate() {  # <pid> <pattern> <reason>
  [[ "$ANCESTORS" == *" $1 "* ]] && return 0   # never sweep ourselves or our shell
  for existing in "${CAND_PIDS[@]:-}"; do
    [[ "$existing" == "$1" ]] && return 0
  done
  CAND_PIDS+=("$1"); CAND_PATTERNS+=("$2"); CAND_REASONS+=("$3")
}

while IFS= read -r line; do
  pid="${line%% *}"
  cmd="${line#* }"
  [[ "$pid" =~ ^[0-9]+$ ]] || continue
  for pat in "${PATTERNS[@]:-}"; do
    [[ "$cmd" == *"$pat"* ]] || continue
    # Scope: the command line naming the repo, or a cwd inside it. Everything
    # else with the same shape belongs to some other project and is left alone.
    if [[ "$cmd" == *"$REPO"* ]]; then
      add_candidate "$pid" "$pat" "cmdline-in-repo"
    else
      cwd="$(proc_cwd "$pid")"
      if [[ -n "$cwd" && ( "$cwd" == "$REPO" || "$cwd" == "$REPO"/* ) ]]; then
        add_candidate "$pid" "$pat" "cwd-in-repo"
      fi
    fi
    break
  done
done < <(ps -Ao pid=,command= 2>/dev/null)

# The port is its own attribution: whoever holds it will break this launch
# regardless of which directory it was started from.
for pid in $PORT_PIDS; do
  [[ "$pid" =~ ^[0-9]+$ ]] || continue
  add_candidate "$pid" "tcp:${PORT}" "holds-dev-server-port"
done

printf 'SWEEP_MODE=%s\n' "$([[ "$DRY_RUN" == true ]] && echo dry-run || echo live)"
for i in "${!CAND_PIDS[@]:-}"; do
  [[ -n "${CAND_PIDS[$i]:-}" ]] || continue
  printf 'SWEEP_CANDIDATE=%s|%s|%s\n' "${CAND_PIDS[$i]}" "${CAND_PATTERNS[$i]}" "${CAND_REASONS[$i]}"
done
printf 'SWEEP_CANDIDATE_COUNT=%d\n' "${#CAND_PIDS[@]}"

if [[ "$DRY_RUN" == true ]]; then
  printf 'SWEEP_KILLED_COUNT=0\n'
  printf 'SWEEP_DEVICE_SHUTDOWN=skipped\n'
  exit 0
fi

# ── The kill ─────────────────────────────────────────────────────────────────
KILLED=0
for i in "${!CAND_PIDS[@]:-}"; do
  pid="${CAND_PIDS[$i]:-}"
  [[ -n "$pid" ]] || continue
  kill -TERM "$pid" 2>/dev/null || continue
  waited=0
  while (( waited < GRACE )) && kill -0 "$pid" 2>/dev/null; do
    sleep 1; waited=$(( waited + 1 ))
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill -KILL "$pid" 2>/dev/null
    printf 'SWEEP_SIGNALLED=%s|%s|TERM|KILL\n' "$pid" "${CAND_PATTERNS[$i]}"
  else
    printf 'SWEEP_SIGNALLED=%s|%s|TERM\n' "$pid" "${CAND_PATTERNS[$i]}"
  fi
  KILLED=$(( KILLED + 1 ))
done
printf 'SWEEP_KILLED_COUNT=%d\n' "$KILLED"

# ── Device shutdown, only when asked, only the named device ──────────────────
if [[ "$COLD_BOOT" == true && -n "$DEVICE_ID" ]]; then
  if [[ "$PLATFORM" == "ios" ]]; then
    xcrun simctl shutdown "$DEVICE_ID" >/dev/null 2>&1
  else
    for serial in $(adb devices 2>/dev/null | awk '/^emulator-/ {print $1}'); do
      name="$(adb -s "$serial" emu avd name 2>/dev/null | head -1 | tr -d '\r')"
      [[ "$name" == "$DEVICE_ID" ]] && adb -s "$serial" emu kill >/dev/null 2>&1
    done
  fi
  printf 'SWEEP_DEVICE_SHUTDOWN=%s\n' "$DEVICE_ID"
else
  printf 'SWEEP_DEVICE_SHUTDOWN=skipped\n'
fi
exit 0
