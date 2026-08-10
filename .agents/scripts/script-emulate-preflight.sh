#!/usr/bin/env bash
# script-emulate-preflight.sh — READ-ONLY resolver for the `/emulate` lane.
#
# Answers, in one call, every question `/emulate` must settle before anything is
# killed or built: which platform, which runner, which launch command, which
# device, and what branch the user is standing on.
#
# Mutates nothing. No process is signalled, no simulator booted, no file
# written. `script-emulate-sweep.sh` owns the one destructive step.
#
# The two ASK_* keys are why this script exists as a separate step: when the
# answer is genuinely the user's (an ambiguous platform, a choice of devices),
# this resolves everything it can, says so, and stops — so the protocol can ask
# BEFORE the sweep kills anything. An abandoned prompt then costs nothing.
#
# Usage:
#   script-emulate-preflight.sh [--platform ios|android] [--expo]
#                               [--device <name>] [--platforms-file <path>]
#                               [--repo <dir>] [--port <n>]
#
#   --platform        pin the platform; PLATFORMS.md is then never read
#   --expo            pin the Expo runner (otherwise detected from the tree)
#   --device          pin the simulator / AVD by name
#   --platforms-file  default: devkit/PLATFORMS.md, relative to --repo
#   --repo            default: $PWD
#   --port            dev-server port the launch will bind (default: 8081)
#
# Output (stdout, key=value lines; every key is printed on a success path):
#   IS_GIT_REPO=true|false
#   CURRENT_BRANCH=<name|none>       `none` on a detached HEAD
#   HEAD_SHA=<short sha|none>
#   IS_DIRTY=true|false              uncommitted changes — reported, never a block
#   PLATFORM=<ios|android|>          empty when ASK_PLATFORM=true
#   PLATFORM_SOURCE=flag|platforms-file|ask
#   PLATFORM_CANDIDATES=<a,b>        emulatable rows found in PLATFORMS.md
#   ASK_PLATFORM=true|false          true ⇒ ask, then re-run with --platform
#   RUNNER=expo|native
#   RUNNER_SOURCE=flag|detected
#   EMULATE_CMD=<cmd>                "" ⇒ the runner recipe is used instead
#   EMULATE_CMD_SOURCE=platforms-file|detected
#   DEVICE_COUNT=<n>
#   DEVICE_<i>_NAME / _ID / _STATE   1-based, table order
#   DEVICE_BOOTED_NAME=<name>        "" when nothing is running
#   DEVICE_DEFAULT_NAME=<name>       the suggested default — always populated
#   DEVICE_DEFAULT_ID=<id>
#   DEVICE_DEFAULT_SOURCE=booted|toolchain|newest
#   DEVICE_NAME=<name>               resolved device, "" when ASK_DEVICE=true
#   DEVICE_ID=<id>
#   DEVICE_SOURCE=flag|single|ask
#   ASK_DEVICE=true|false
#   DEV_SERVER_PORT=<n>
#
# Exit codes:
#   0  resolved (including the two ask paths — an ask is not a failure)
#   2  no emulatable platform declared, or an unrecognised flag. LOUD
#   3  PLATFORMS.md missing/unreadable and no --platform. LOUD
#   4  toolchain or runner absent for the resolved platform. LOUD
#   5  device problem — --device names nothing, or no devices exist at all. LOUD
#   Every loud exit prints ERROR=<cause> on stdout and a fix line on stderr.
#
# Toolchains are looked up on PATH, so a test can inject stubs by prepending a
# stub directory — there is no bypass env var to drift from real behaviour.
#
# Deterministic: identical repo + toolchain state produces identical output.
set -uo pipefail

SELF="script-emulate-preflight"

REPO="$PWD"
PLATFORMS_FILE=""
WANT_PLATFORM=""
WANT_DEVICE=""
FORCE_EXPO=false
PORT=8081

fail() {  # <exit> <key> <message> [fix]
  printf 'ERROR=%s\n' "$2"
  printf '%s: %s\n' "$SELF" "$3" >&2
  [[ -n "${4:-}" ]] && printf '%s: fix: %s\n' "$SELF" "$4" >&2
  exit "$1"
}
die() { printf 'ERROR=usage\n'; printf '%s: %s\n' "$SELF" "$1" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)  [[ $# -ge 2 ]] || die "--platform needs a value"; WANT_PLATFORM="$2"; shift 2 ;;
    --platform=*) WANT_PLATFORM="${1#*=}"; shift ;;
    --device)    [[ $# -ge 2 ]] || die "--device needs a value"; WANT_DEVICE="$2"; shift 2 ;;
    --device=*)  WANT_DEVICE="${1#*=}"; shift ;;
    --platforms-file) [[ $# -ge 2 ]] || die "--platforms-file needs a value"; PLATFORMS_FILE="$2"; shift 2 ;;
    --platforms-file=*) PLATFORMS_FILE="${1#*=}"; shift ;;
    --repo)      [[ $# -ge 2 ]] || die "--repo needs a value"; REPO="$2"; shift 2 ;;
    --repo=*)    REPO="${1#*=}"; shift ;;
    --port)      [[ $# -ge 2 ]] || die "--port needs a value"; PORT="$2"; shift 2 ;;
    --port=*)    PORT="${1#*=}"; shift ;;
    --expo)      FORCE_EXPO=true; shift ;;
    -h|--help)   sed -n '2,60p' "$0"; exit 0 ;;
    *)           die "unknown flag: $1" ;;
  esac
done

[[ -d "$REPO" ]] || die "no such directory: $REPO"
cd "$REPO" || die "cannot enter $REPO"
[[ -n "$PLATFORMS_FILE" ]] || PLATFORMS_FILE="devkit/PLATFORMS.md"

# `android` is the platform identity in PLATFORMS.md; `--adr` is the user-facing
# flag and the skill normalises it before calling this script. Accept both here
# anyway — a script that rejects the spelling its own skill uses is a trap.
case "$WANT_PLATFORM" in
  adr) WANT_PLATFORM="android" ;;
  ""|ios|android) ;;
  *) die "unknown platform: $WANT_PLATFORM (expected ios or android)" ;;
esac

# ── Step 1: branch, reported and never gating ────────────────────────────────
IS_GIT_REPO=false; CURRENT_BRANCH="none"; HEAD_SHA="none"; IS_DIRTY=false
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  IS_GIT_REPO=true
  CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo none)"
  [[ "$CURRENT_BRANCH" == "HEAD" ]] && CURRENT_BRANCH="none"   # detached
  HEAD_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo none)"
  [[ -n "$(git status --porcelain 2>/dev/null)" ]] && IS_DIRTY=true
fi

# ── Step 2: platform ─────────────────────────────────────────────────────────
PLATFORM=""; PLATFORM_SOURCE=""; CANDIDATES=""; ASK_PLATFORM=false
EMULATE_CMD=""; EMULATE_CMD_SOURCE="detected"

parse_platforms() {
  local p=".claude/scripts/script-platforms-parse.py"
  [[ -f "$p" ]] || p="$HOME/.claude/scripts/script-platforms-parse.py"
  [[ -f "$p" ]] || return 127
  python3 "$p" --file "$PLATFORMS_FILE" 2>/dev/null
}

if [[ -n "$WANT_PLATFORM" ]]; then
  PLATFORM="$WANT_PLATFORM"
  PLATFORM_SOURCE="flag"
  # The file is optional on this path — /emulate must work in a repo msg has
  # never bootstrapped — but an emulate_cmd there is still honoured when present.
  if [[ -f "$PLATFORMS_FILE" ]]; then
    EMULATE_CMD="$(parse_platforms | sed -n "s/^${PLATFORM}\.emulate_cmd=//p" | head -1)"
  fi
else
  [[ -f "$PLATFORMS_FILE" ]] || fail 3 no-platforms-file \
    "$PLATFORMS_FILE not found and no platform flag given" \
    "run \`/emulate --ios\` or \`/emulate --adr\`, or bootstrap the repo with \`/msg --init\`"
  PARSED="$(parse_platforms)" || true
  [[ -n "$PARSED" ]] || fail 3 unreadable-platforms-file \
    "$PLATFORMS_FILE could not be parsed" \
    "run \`/emulate --ios\` or \`/emulate --adr\` to bypass the file, or fix the table"
  DECLARED="$(printf '%s\n' "$PARSED" | sed -n 's/^PLATFORMS=//p' | head -1)"
  for p in ${DECLARED//,/ }; do
    case "$p" in ios|android) CANDIDATES="${CANDIDATES:+$CANDIDATES,}$p" ;; esac
  done
  case "$CANDIDATES" in
    "")  fail 2 no-emulatable-platform \
           "$PLATFORMS_FILE declares no emulatable platform (rows: ${DECLARED:-none})" \
           "/emulate runs simulators and emulators only — add an \`ios\` or \`android\` row, or pass --ios / --adr" ;;
    *,*) ASK_PLATFORM=true; PLATFORM_SOURCE="ask" ;;
    *)   PLATFORM="$CANDIDATES"; PLATFORM_SOURCE="platforms-file"
         EMULATE_CMD="$(printf '%s\n' "$PARSED" | sed -n "s/^${PLATFORM}\.emulate_cmd=//p" | head -1)" ;;
  esac
fi
[[ -n "$EMULATE_CMD" ]] && EMULATE_CMD_SOURCE="platforms-file"

# An ambiguous platform settles nothing downstream — the runner, the toolchain
# and the device list are all platform-specific. Emit what is known and stop.
if [[ "$ASK_PLATFORM" == true ]]; then
  cat <<EOF
IS_GIT_REPO=$IS_GIT_REPO
CURRENT_BRANCH=$CURRENT_BRANCH
HEAD_SHA=$HEAD_SHA
IS_DIRTY=$IS_DIRTY
PLATFORM=
PLATFORM_SOURCE=ask
PLATFORM_CANDIDATES=$CANDIDATES
ASK_PLATFORM=true
EOF
  exit 0
fi

# ── Step 3: runner ───────────────────────────────────────────────────────────
RUNNER="native"; RUNNER_SOURCE="detected"
has_expo() {
  [[ -f package.json ]] || return 1
  grep -qE '"expo"[[:space:]]*:' package.json
}
if [[ "$FORCE_EXPO" == true ]]; then
  has_expo || fail 4 expo-absent \
    "--expo was given but no \`expo\` dependency is declared in package.json" \
    "install it with \`npx expo install expo\`, or drop --expo to use the native toolchain"
  RUNNER="expo"; RUNNER_SOURCE="flag"
elif has_expo; then
  RUNNER="expo"
fi

# ── Step 4: toolchain ────────────────────────────────────────────────────────
# Checked after the runner, because Expo still drives the same simulators and
# needs the same platform toolchain underneath.
if [[ "$PLATFORM" == "ios" ]]; then
  [[ "$(uname -s)" == "Darwin" ]] || fail 4 ios-not-macos \
    "the iOS simulator only exists on macOS (this is $(uname -s))" \
    "use --adr for Android, which runs anywhere"
  command -v xcrun >/dev/null 2>&1 || fail 4 toolchain-missing \
    "\`xcrun\` is not on PATH — Xcode command line tools are not installed" \
    "run \`xcode-select --install\`, then open Xcode once to accept the licence"
  xcrun simctl help >/dev/null 2>&1 || fail 4 toolchain-missing \
    "\`xcrun simctl\` is not usable — Xcode is installed but not selected" \
    "run \`sudo xcode-select -s /Applications/Xcode.app\`"
  if [[ "$RUNNER" == "native" && ! -d ios ]]; then
    fail 4 runner-absent \
      "no \`ios/\` project directory and no expo dependency — nothing to launch" \
      "run \`npx expo prebuild\`, or open the repo that actually holds the iOS app"
  fi
else
  command -v emulator >/dev/null 2>&1 || fail 4 toolchain-missing \
    "\`emulator\` is not on PATH — the Android SDK emulator is not installed or not exported" \
    "install it in Android Studio (SDK Tools → Android Emulator) and add \$ANDROID_HOME/emulator to PATH"
  command -v adb >/dev/null 2>&1 || fail 4 toolchain-missing \
    "\`adb\` is not on PATH — Android platform-tools are not installed or not exported" \
    "install platform-tools in Android Studio and add \$ANDROID_HOME/platform-tools to PATH"
  if [[ "$RUNNER" == "native" && ! -x android/gradlew && ! -f android/gradlew ]]; then
    fail 4 runner-absent \
      "no \`android/gradlew\` and no expo dependency — nothing to launch" \
      "run \`npx expo prebuild\`, or open the repo that actually holds the Android app"
  fi
fi

# ── Step 5: devices ──────────────────────────────────────────────────────────
# Parallel arrays rather than one delimited string: simulator names contain
# spaces, and a delimiter that a device name can also contain is a latent bug.
NAMES=(); IDS=(); STATES=()
BOOTED_NAME=""; BOOTED_ID=""

if [[ "$PLATFORM" == "ios" ]]; then
  # `simctl list devices available` groups by runtime, oldest first, and lists
  # models in ascending order inside each group — so the LAST match is the
  # newest device the machine has, which is what `newest` below relies on.
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]+(.+)[[:space:]]\(([0-9A-Fa-f-]{36})\)[[:space:]]\((Booted|Shutdown)\) ]] || continue
    NAMES+=("${BASH_REMATCH[1]}"); IDS+=("${BASH_REMATCH[2]}"); STATES+=("${BASH_REMATCH[3]}")
    if [[ "${BASH_REMATCH[3]}" == "Booted" && -z "$BOOTED_NAME" ]]; then
      BOOTED_NAME="${BASH_REMATCH[1]}"; BOOTED_ID="${BASH_REMATCH[2]}"
    fi
  done < <(xcrun simctl list devices available 2>/dev/null)
else
  RUNNING=""
  while IFS= read -r serial; do
    [[ "$serial" == emulator-* ]] || continue
    RUNNING="$(adb -s "$serial" emu avd name 2>/dev/null | head -1 | tr -d '\r')"
    [[ -n "$RUNNING" ]] && break
  done < <(adb devices 2>/dev/null | awk '/^emulator-/ {print $1}')
  while IFS= read -r avd; do
    [[ -n "$avd" ]] || continue
    NAMES+=("$avd"); IDS+=("$avd")
    if [[ "$avd" == "$RUNNING" ]]; then
      STATES+=("Booted"); BOOTED_NAME="$avd"; BOOTED_ID="$avd"
    else
      STATES+=("Shutdown")
    fi
  done < <(emulator -list-avds 2>/dev/null | tr -d '\r')
fi

COUNT=${#NAMES[@]}
if (( COUNT == 0 )); then
  if [[ "$PLATFORM" == "ios" ]]; then
    fail 5 no-devices \
      "no iOS simulators are available on this machine" \
      "open Xcode → Settings → Platforms and install an iOS simulator runtime"
  else
    fail 5 no-devices \
      "no Android AVDs are defined on this machine" \
      "create one: \`avdmanager create avd -n Pixel_7_API_34 -k \"system-images;android-34;google_apis;arm64-v8a\"\`"
  fi
fi

# The suggested default. Ranked so that the answer that needs no cold boot wins:
# an already-running device is both the likeliest intent and the fastest launch.
DEFAULT_IDX=-1; DEFAULT_SOURCE=""
if [[ -n "$BOOTED_NAME" ]]; then
  for i in "${!NAMES[@]}"; do
    [[ "${NAMES[$i]}" == "$BOOTED_NAME" ]] && { DEFAULT_IDX=$i; DEFAULT_SOURCE="booted"; break; }
  done
fi
if (( DEFAULT_IDX < 0 )) && [[ "$PLATFORM" == "android" ]]; then
  # ANDROID_AVD_DEFAULT is not a platform convention; the toolchain has no
  # "default AVD" of its own, so this is the only declared-default hook there is.
  if [[ -n "${ANDROID_AVD_DEFAULT:-}" ]]; then
    for i in "${!NAMES[@]}"; do
      [[ "${NAMES[$i]}" == "$ANDROID_AVD_DEFAULT" ]] && { DEFAULT_IDX=$i; DEFAULT_SOURCE="toolchain"; break; }
    done
  fi
fi
if (( DEFAULT_IDX < 0 )); then
  DEFAULT_SOURCE="newest"
  if [[ "$PLATFORM" == "ios" ]]; then
    # The last iPhone in `simctl` listing order, which Xcode emits newest
    # runtime first and, within a generation, Pro → Pro Max → e → Air → base.
    # So this lands on the BASE model of the current generation — verified
    # against a real Xcode 17 install — which is the right default: it is the
    # most representative device, not the most expensive one. Falls back to the
    # last device of any kind on an iPad-only or watch-only machine.
    for i in "${!NAMES[@]}"; do
      [[ "${NAMES[$i]}" == iPhone* ]] && DEFAULT_IDX=$i
    done
    (( DEFAULT_IDX < 0 )) && DEFAULT_IDX=$(( COUNT - 1 ))
  else
    # Highest API level wins; AVDs with no API token in the name rank lowest so
    # a hand-named legacy AVD never outranks a real, current one.
    BEST=-1
    for i in "${!NAMES[@]}"; do
      lvl=0
      [[ "${NAMES[$i]}" =~ [Aa][Pp][Ii]_?([0-9]+) ]] && lvl="${BASH_REMATCH[1]}"
      if (( lvl > BEST )); then BEST=$lvl; DEFAULT_IDX=$i; fi
    done
    (( DEFAULT_IDX < 0 )) && DEFAULT_IDX=0
  fi
fi

DEVICE_NAME=""; DEVICE_ID=""; DEVICE_SOURCE=""; ASK_DEVICE=false
if [[ -n "$WANT_DEVICE" ]]; then
  MATCH=-1
  for i in "${!NAMES[@]}"; do
    [[ "${NAMES[$i]}" == "$WANT_DEVICE" || "${IDS[$i]}" == "$WANT_DEVICE" ]] && { MATCH=$i; break; }
  done
  # Exact match only. A fuzzy match here boots the wrong device silently, which
  # is the entire failure --device exists to prevent.
  (( MATCH >= 0 )) || fail 5 unknown-device \
    "no device named '$WANT_DEVICE' — available: $(printf '%s; ' "${NAMES[@]}")" \
    "copy one of the names above exactly, or drop --device to be asked"
  DEVICE_NAME="${NAMES[$MATCH]}"; DEVICE_ID="${IDS[$MATCH]}"; DEVICE_SOURCE="flag"
elif (( COUNT == 1 )); then
  DEVICE_NAME="${NAMES[0]}"; DEVICE_ID="${IDS[0]}"; DEVICE_SOURCE="single"
else
  ASK_DEVICE=true; DEVICE_SOURCE="ask"
fi

# ── Emit ─────────────────────────────────────────────────────────────────────
cat <<EOF
IS_GIT_REPO=$IS_GIT_REPO
CURRENT_BRANCH=$CURRENT_BRANCH
HEAD_SHA=$HEAD_SHA
IS_DIRTY=$IS_DIRTY
PLATFORM=$PLATFORM
PLATFORM_SOURCE=$PLATFORM_SOURCE
PLATFORM_CANDIDATES=$CANDIDATES
ASK_PLATFORM=false
RUNNER=$RUNNER
RUNNER_SOURCE=$RUNNER_SOURCE
EMULATE_CMD=$EMULATE_CMD
EMULATE_CMD_SOURCE=$EMULATE_CMD_SOURCE
DEVICE_COUNT=$COUNT
EOF
for i in "${!NAMES[@]}"; do
  n=$(( i + 1 ))
  printf 'DEVICE_%d_NAME=%s\nDEVICE_%d_ID=%s\nDEVICE_%d_STATE=%s\n' \
    "$n" "${NAMES[$i]}" "$n" "${IDS[$i]}" "$n" "${STATES[$i]}"
done
cat <<EOF
DEVICE_BOOTED_NAME=$BOOTED_NAME
DEVICE_BOOTED_ID=$BOOTED_ID
DEVICE_DEFAULT_NAME=${NAMES[$DEFAULT_IDX]}
DEVICE_DEFAULT_ID=${IDS[$DEFAULT_IDX]}
DEVICE_DEFAULT_SOURCE=$DEFAULT_SOURCE
DEVICE_NAME=$DEVICE_NAME
DEVICE_ID=$DEVICE_ID
DEVICE_SOURCE=$DEVICE_SOURCE
ASK_DEVICE=$ASK_DEVICE
DEV_SERVER_PORT=$PORT
EOF
exit 0
