---
name: emulate
description: >
  Runs this repo's app on a local simulator or emulator and opens the window on
  the user's desktop. Use it when the user says "run the app", "open the
  simulator", "launch the emulator", "boot the iOS sim", "start Expo", "see it
  running", "show me the app", or invokes `/emulate`. Takes the branch the user
  is standing on, clears the stale build processes from the last attempt, and
  launches. `--ios` / `--adr` / `--expo` pick the lane; with no flag the platform
  is read from `devkit/PLATFORMS.md`. `--device` pins the simulator or AVD,
  `--dry-run` shows what would happen and touches nothing. Writes nothing to the
  repo — no commits, no branches, no PRs.
argument-hint: "[--ios | --adr | --expo] [--device <name>] [--dry-run]"
allowed_tools:
  - AskUserQuestion
  - Bash
  - Read
---

# emulate

The harness's **local run lane**. `/pre-merge` runs the checks and `/merge`
deploys to a remote target; neither one puts a live app in front of a human on
their own machine. That is this skill's whole job.

`/emulate` is a **leaf**: nothing invokes it and it invokes nothing. It has no
place in the `intake → plan-pm → plan-em → eng → pre-merge → merge` spine and
never blocks it. Run it whenever you want to look at the app.

## Dispatch

Every mode runs the same protocol —
[`refs/protocol.md`](refs/protocol.md). The flags only change what Step 0
resolves. First match wins; flags compose.

| Invocation | Also triggers on (natural language) | Effect |
|---|---|---|
| `/emulate` | "run the app", "open the simulator", "see it running", "show me the app" | Platform resolved from `devkit/PLATFORMS.md` |
| `/emulate --ios` | "boot the iOS sim", "run it on iPhone" | iOS lane, `PLATFORMS.md` not consulted |
| `/emulate --adr` (alias `--android`) | "run it on Android", "open the emulator" | Android lane, `PLATFORMS.md` not consulted |
| `/emulate --expo` | "start Expo", "run Metro", "expo go" | Pins the **runner**; the platform still resolves normally |
| `/emulate --device <name>` | "run it on an iPhone 15 Pro" | Pins the simulator / AVD and skips the device question |
| `/emulate --dry-run` | "what would this do", "don't actually run it" | Prints the plan and the kill list, launches nothing, kills nothing |
| `/emulate --help` | — | This table, then stop |

**Two axes, not one.** `--ios` and `--adr` pin the **platform** — a product
fact, declared in `devkit/PLATFORMS.md`. `--expo` pins the **runner** — a repo
fact, detected from the working tree, because Expo is a toolchain that targets
both platforms rather than a platform of its own. `--device` is a third,
orthogonal axis. `/emulate --expo --ios --device "iPhone 15 Pro"` is legal and
means exactly what it reads like.

**An unrecognised flag is never ignored.** It stops the run with the flag named
and the valid set printed — it never falls through to auto-detection.

## The two contracts

**Fail loudly.** Where a wrong guess would cost the user a long build or boot
the wrong thing, `/emulate` stops with a named cause, a non-zero exit and a
copy-pasteable fix. It never invents a launch command, never fuzzy-matches a
device name, and never boots something and hopes. The exit-code table lives in
[`refs/protocol.md`](refs/protocol.md) § Loud failures.

**Ask only where the answer is genuinely the user's.** Exactly two questions
exist — which platform, when the repo declares more than one, and which device,
when more than one is available. Both are asked in a **single**
`AskUserQuestion` call, both offer a working default first, and **nothing is
killed or built until the answers land**. A dismissed prompt falls back to the
default and still launches.

## Safety floor

`/emulate` writes **nothing** to the repo: no commits, no branches, no PRs, no
PRD stamps, no report files. It is read-only against the working tree.

Its only side effect is in the OS process table, and it is bounded — see
[`../shared/refs/safety-floor.md`](../shared/refs/safety-floor.md) and the
allowlist compiled into `script-emulate-sweep.sh`.

## Closing message

Every run ends with the closing message per
[`../shared/refs/closing-message.md`](../shared/refs/closing-message.md), after
the launch banner. A launched app is 🟢; a launch that started but reported a
degraded state (dirty tree noted, a process that refused to die) is 🟡; a loud
failure is 🔴 with the fix as step 1.

## Harness incidents

Unexpected script failures, tool errors and retries are logged to
`devkit/DOCTOR.md` per
[`../shared/refs/doctor-logging.md`](../shared/refs/doctor-logging.md). A
**loud failure is not an incident** — an absent toolchain or an undeclared
platform is the contract working, not the harness misbehaving. Log only what
was genuinely unexpected.
