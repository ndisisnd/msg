---
name: emulate protocol
description: The /emulate run protocol — Steps 0–6 from flag parsing to the launch banner, the two ask paths, the loud-failure table, and the dry-run contract
type: reference
---

# /emulate — protocol

Seven steps, in order. Nothing later may run before everything earlier has
settled — in particular **Step 3 (the sweep) never runs before Step 0 and Step 2
have their answers**, so an abandoned question costs the user nothing.

Two scripts do the work. Resolve the path once, at the top of the run, and reuse
it — a local checkout wins over the installed copy so a repo can test its own
changes:

```bash
P=.claude/scripts/script-emulate-preflight.sh; [ -f "$P" ] || P="$HOME/.claude/scripts/script-emulate-preflight.sh"
W=.claude/scripts/script-emulate-sweep.sh;     [ -f "$W" ] || W="$HOME/.claude/scripts/script-emulate-sweep.sh"
```

## Step 0 — parse the invocation

| Flag | Sets |
|---|---|
| `--ios` | `PLATFORM=ios` |
| `--adr`, `--android` | `PLATFORM=android` |
| `--expo` | `RUNNER=expo` |
| `--device <name>` | `DEVICE=<name>` |
| `--dry-run` | dry-run mode |
| `--help` | print the SKILL.md dispatch table, stop |

Anything else is a **loud failure**: name the flag, print the valid set, stop.
Never guess, and never fall through to auto-detection — a typo'd flag that
silently becomes a platform auto-detect is how a user boots the wrong app.

## Step 1 — resolve the target

```bash
"$P" ${PLATFORM:+--platform "$PLATFORM"} ${EXPO:+--expo} ${DEVICE:+--device "$DEVICE"}
```

The script is the **only** reader of `devkit/PLATFORMS.md` in this lane — it
delegates to `script-platforms-parse.py`, which is the repo's one parser for
that table. Never hand-parse the table here.

Read its `KEY=VALUE` output. Two keys change the flow:

- **`ASK_PLATFORM=true`** — the repo declares more than one emulatable platform.
  Go to Step 2 with the candidates in `PLATFORM_CANDIDATES`, then **re-run this
  step** with `--platform <answer>`, because the runner, the toolchain and the
  device list are all platform-specific and none of them were resolved.
- **`ASK_DEVICE=true`** — more than one device is available and none was pinned.
  Go to Step 2 with the device keys.

If neither is true, the target is fully resolved and Step 2 is skipped entirely.

**The launch command.** `EMULATE_CMD` is the `emulate_cmd` cell from
`devkit/PLATFORMS.md` when the repo declared one. It **wins over** the runner
recipes in [`runners.md`](runners.md). Empty means not configured — fall back to
the recipe for `RUNNER` + `PLATFORM`. Never invent a command, and never run a
`[USER: …]` placeholder (the parser has already collapsed those to empty).

## Step 2 — ask, once

Only reached when `ASK_PLATFORM` or `ASK_DEVICE` is true. **Exactly one of them
can be true in any single run**, so this step is always one `AskUserQuestion`
call, never two: an unresolved platform stops Step 1 before devices are looked
at, because the device list is platform-specific and does not exist yet. The
platform ask therefore comes first, on its own, and the device ask (if it is
still needed) comes on the re-run.

**Platform question.** Options are exactly the strings in
`PLATFORM_CANDIDATES`, nothing invented. Each description names the flag that
skips the prompt next time (`/emulate --ios`), so the user learns the shortcut
rather than being asked forever.

**Device question.** The first option is `DEVICE_DEFAULT_NAME`, labelled
`(Recommended)`, with its description naming why it is the suggestion —
`DEVICE_DEFAULT_SOURCE` says which:

| `DEVICE_DEFAULT_SOURCE` | Say |
|---|---|
| `booted` | "already running — fastest, no cold boot" |
| `toolchain` | "your configured default" |
| `newest` | "the newest device installed" |

The remaining options are the other `DEVICE_<i>_NAME` entries. With more than
four devices, offer the default plus the three next-newest and say in the
question that `--device` takes any installed name.

**If the ask cannot run or is dismissed**, take `DEVICE_DEFAULT_NAME` (and, for
platform, stop loudly — a platform cannot be defaulted, which is why the
candidates are named). Say in the banner that the default was used. A dismissed
prompt must never be a dead end.

## Step 3 — branch check, reported not gated

From the Step 1 keys. State it before anything is killed or built:

```
branch <CURRENT_BRANCH> @ <HEAD_SHA><, uncommitted changes> → <PLATFORM> / <RUNNER>
```

**This never blocks.** A dirty tree is the normal case — emulating uncommitted
work is the entire point of a local run lane. Standing on `main` is legitimate
too: comparing shipped behaviour against a fix is real work.

`IS_GIT_REPO=false` is the **one** branch-related loud failure — without a repo
the branch line would be a lie, and the user cannot tell what they are looking
at.

## Step 4 — sweep the stale builds

```bash
"$W" --platform "$PLATFORM" --runner "$RUNNER" --port "$DEV_SERVER_PORT" ${DRY_RUN:+--dry-run}
```

The allowlist, the repo-scoping rule and the TERM-before-KILL ladder all live in
the script — do not reimplement or extend them here, and never pass a
user-supplied pattern.

Print every `SWEEP_CANDIDATE` line as a plain sentence: the pid, what it
matched, and why it was attributable to this repo. A kill the user did not see
is a kill they cannot trust.

`SWEEP_CANDIDATE_COUNT=0` is a normal, common run — say "nothing stale to
clear", not nothing.

**Cold boot.** Pass `--cold-boot --device-id "$DEVICE_ID"` only when the chosen
runner recipe requires a clean device (see [`runners.md`](runners.md)). Booting
a second app onto a running simulator is normal and fast; shutting one down by
default would make every run slower for no reason.

## Step 5 — launch

Follow the recipe in [`runners.md`](runners.md) for `RUNNER` + `PLATFORM`, or
run `EMULATE_CMD` when the repo declared one. Two rules hold across all of them:

1. **Backgrounded.** The dev server and the emulator must survive this run
   returning. Use `run_in_background: true`, never a foreground command that
   holds the turn open.
2. **Raised.** Booting a simulator is not the same as showing it. Every iOS
   recipe ends with `open -a Simulator`; every Android recipe waits for
   `adb wait-for-device` before installing.

Wait on the recipe's **ready signal** — a line in the log, or a command that
exits 0. Never poll with a foreground `sleep`.

## Step 6 — report

The launch banner, then the closing message. The banner states, in this order:

| Line | Content |
|---|---|
| Target | `<PLATFORM> · <RUNNER> · <DEVICE_NAME>` and where each came from (`--ios`, `PLATFORMS.md`, recommended default) |
| Branch | branch, sha, dirty flag |
| Cleared | the sweep result, or "nothing stale to clear" |
| Running | the background pid and the log path |

The **pid and log path are not optional**. They are how the user follows a slow
build or stops a dev server without coming back to this session.

## Loud failures

Every one exits non-zero from the preflight script, prints `ERROR=<cause>` and
carries a fix line. Surface the script's fix verbatim — it is more specific than
anything this protocol could restate.

| Exit | Cause | Fix shape |
|---|---|---|
| `2` | No emulatable platform in `PLATFORMS.md`; or an unrecognised flag | Add an `ios`/`android` row, or pass `--ios` / `--adr` |
| `3` | `PLATFORMS.md` missing or unparseable, no platform flag | `/emulate --ios`, or `/msg --init` |
| `4` | Toolchain or runner absent — no `xcrun simctl`, no `emulator`/`adb`, no expo dependency, no `ios/` or `android/gradlew` | The named install or `npx expo prebuild` |
| `5` | `--device` names nothing installed; or no devices exist at all | Copy an exact name from the list, or `avdmanager create` |

**A loud failure is the contract working.** Report it as 🔴 with the fix as
step 1, and do not log it to `devkit/DOCTOR.md` — nothing about the harness
misbehaved.

## Dry run

`--dry-run` runs Steps 0–4 exactly as a real run does, including the ask, and
then stops. It prints the resolved target, the launch command it *would* run,
and the full kill list — and kills nothing, boots nothing, installs nothing.

It shares the preflight and sweep code paths with a real run rather than
describing them, which is the only way the preview cannot drift from the
behaviour it is previewing. Closing message is 🟢 with the real command as the
next step.
