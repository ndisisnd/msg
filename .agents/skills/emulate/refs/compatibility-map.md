---
skill: emulate
canonical: .claude/skills/emulate/SKILL.md
status: phase-0-audited-blocked-on-deviations
assertions:
  - EMU-CX-001
  - EMU-CX-002
  - EMU-CX-003
  - EMU-CX-004
  - EMU-CX-005
  - EMU-CX-006
  - EMU-CX-007
  - EMU-CX-008
  - EMU-CX-009
  - EMU-CX-010
  - EMU-CX-011
  - EMU-CX-012
  - EMU-CX-013
  - EMU-CX-014
  - EMU-CX-015
  - EMU-CX-016
  - EMU-CX-017
  - EMU-CX-018
evals:
  - emulate-routing-and-flags
  - emulate-resolve-platform
  - emulate-platform-and-device-questions
  - emulate-command-precedence
  - emulate-sweep-safety
  - emulate-dry-run-parity
  - emulate-expo-ios
  - emulate-expo-android
  - emulate-native-ios
  - emulate-native-android
  - emulate-loud-failures
  - emulate-log-fallback-and-repo-snapshot
  - emulate-process-lifetime-and-window
  - emulate-shared-contracts-and-closure
---

# emulate compatibility map

This Phase 0 map covers the complete local-run leaf. It authorizes no GUI, process, path,
or tool translation until the user decides the pending runtime differences.

## Canonical entry point and digest

- Entry: `.claude/skills/emulate/SKILL.md`.
- Entry digest: `e1b7dcc01d69befbeb261f4526b83a40d62a3079e227530500bbe768630d5fc0`.
- Scoped files mapped: **3/3**.
- Proposed destination: `.agents/skills/emulate/CLAUDE-SKILL.md` plus relative refs,
  blocked on installation/path approval.

## Canonical file coverage

| Canonical path | SHA-256 | Kind | Consumer / load condition | Proposed Codex path | Translation and proof |
|---|---|---|---|---|---|
| `.claude/skills/emulate/SKILL.md` | `e1b7dcc01d69befbeb261f4526b83a40d62a3079e227530500bbe768630d5fc0` | entry/router | Every explicit/natural-language local-run intent; help and all flag compositions | `.agents/skills/emulate/CLAUDE-SKILL.md` | generated-copy target; invocation/tool adapter pending; `EMU-CX-001..005`, routing eval |
| `.claude/skills/emulate/refs/protocol.md` | `58b9a34e634ee543011b22fa4c8efa66973f0d94e07ad3944fba74b7af604c90` | protocol | Every non-help invocation, steps 0–6; dry run stops after shared step 4 | same relative path | generated-copy target; `EMU-CX-002..018`, all behavior evals |
| `.claude/skills/emulate/refs/runners.md` | `ba7f23abab7ba81ffd8c30a0d56a59a78d0ea59cee36a41c514ac63ce7243f32` | recipes | Step 5 only when `emulate_cmd` is empty; one runner/platform recipe selected | same relative path | generated-copy target; external GUI/process mapping pending; `EMU-CX-009..014`, runner evals |

## Reference graph and resolution order

```text
emulate → protocol
  0 parse flags/help/unknown
  1 preflight resolver → platforms parser + toolchain/device discovery
  2 at most one question per resolver pass; re-run after platform choice
  3 report branch/sha/dirty; non-git stops
  4 allowlisted repo-attributed sweep (dry run shares this path)
  5 command override OR runners recipe
       ├─ Expo iOS
       ├─ Expo Android
       ├─ native iOS
       └─ native Android
  6 banner + closing message
```

Platform, runner, and device are independent axes. `--ios`/`--adr` pin platform;
`--expo` pins runner but still resolves platform; `--device` pins exact device. A declared
`emulate_cmd` always beats recipes. Nothing is swept before all questions resolve.

## Trigger, flag, question, and failure map

- Explicit `/emulate`; natural-language run/show/simulator/Expo/iOS/Android intents keep
  their first-match semantics. Proposed `$emulate` syntax is pending approval.
- Flags: `--ios`; `--adr|--android`; `--expo`; `--device <exact name>`; `--dry-run`;
  `--help`. Legal axes compose. Any unknown flag stops and prints the valid set.
- The resolver is the only PLATFORMS reader. Multiple platforms ask first and rerun; only
  after a platform exists can multiple devices ask. Thus one question per pass, never two
  in one call. Platform dismissal stops; device dismissal uses the computed default and
  reports it. No process is killed/built before the answer.
- Device options are exact installed names. Default precedence/description is booted,
  toolchain, newest. More than four offers default plus three next-newest and documents
  exact `--device` use. No fuzzy matching.
- Loud failures retain exact exit/cause/fix: 2 no platform/unknown flag; 3 missing/bad
  PLATFORMS without flag; 4 missing runner/toolchain/project shape; 5 unknown/no device.
  They are expected contract outcomes, not DOCTOR incidents.

## Sweep and OS safety map

- Branch line always precedes sweep and launch. Dirty/main are informational; non-git is
  a loud failure.
- `script-emulate-sweep.sh` alone owns the process allowlist, current-repo attribution,
  relevant port ownership, TERM-before-KILL, optional explicit cold boot, and dry-run.
  The skill never accepts a user pattern or broadens scope.
- Every candidate is announced with PID, match, and repo-attribution reason. Zero is
  reported as “nothing stale to clear.” A process outside repo/port/allowlist is untouched.
- Cold boot is never default. It is passed only on an explicit clean-run need plus the
  exact device ID. Already-running simulator/app reuse is normal.

## Runner parity map

| Runner/platform | Command/ready signal/window contract |
|---|---|
| Expo/iOS | background `npx expo start --ios [--device exact]`; Metro/bundle log; raise Simulator |
| Expo/Android | boot exact AVD when selected, `adb wait-for-device`, background Expo; wait for Metro |
| native iOS | resolve workspace/scheme without guessing; `simctl boot` already-running is okay; xcodebuild/install/launch; launch PID ready; raise Simulator |
| native Android | exact AVD; wait visible then device-side boot-completed poll; Gradle install; manifest package/activity or launcher monkey fallback; `Status: ok` ready |

All long-lived servers/emulators survive the skill return. Ready signals, not foreground
clock sleeps, govern progress. Missing/ambiguous workspace/scheme/activity stops and tells
the user to declare `emulate_cmd`; no invented launch command.

## Dry-run contract

Dry run executes the same parse, resolve, question, branch, and sweep-discovery code. It
prints the exact target, resolved command, and complete kill list, but sends no signals,
boots/installs/launches nothing, starts no background process, and changes no repository
or OS process state. Its closing next step contains the real command.

## Tool, path, environment, and external-command map

| Claude dependency | Proposed Codex semantic operation | Status |
|---|---|---|
| Bash/Read | shell and file reads with no repository mutation | Pending tool/sandbox decision. |
| AskUserQuestion | same platform/device options/default/dismissal behavior | Pending question-UI decision. |
| `run_in_background: true` | a persistent Codex-managed/background process whose PID/log remain valid after return | Pending `DEV-CX-016`; must be proven, not assumed. |
| `open -a Simulator` | GUI launch/raise on the user's macOS desktop | Pending `DEV-CX-015`; Codex escalation must not silently add/remove a gate. |
| `.claude/scripts` then `$HOME/.claude/scripts` | repo-local then installed Codex helper | Pending path decision; no Claude-home dependency. |
| `.emulate/<platform>-<epoch>.log` | runners allow it only when already ignored; otherwise `$TMPDIR` | Canonical conflict `AMB-CX-007`: the entry point also says no repository write or non-process side effect. |
| `devkit/PLATFORMS.md` | canonical product/command input through parser only | Exact data source. |
| `npx expo`, `xcrun`, `xcodebuild`, `open`, `emulator`, `adb`, Gradle | same command intent/order and ready signal | External tool/GUI/sandbox approval pending; loud absence remains exact. |
| git branch/HEAD/dirty reads | read-only branch identity | Exact; no branch/commit/PR writes. |

## Deterministic helper closure

| Helper | Relationship |
|---|---|
| `script-emulate-preflight.sh` | direct, read-only resolver for flags/platform/runner/toolchain/devices/branch/command |
| `script-emulate-sweep.sh` | direct, sole bounded destructive process/cold-boot action; dry-run-safe |
| `script-platforms-parse.py` | transitive sole PLATFORMS table parser used by preflight |
| `script-doctor-log.sh` | indirect unexpected-incident writer via shared contract |

## Shared-reference closure

| Shared ref | Edge | Proof |
|---|---|---|
| `shared/refs/safety-floor.md` | no product/source/git mutation; whether ignored runtime artifacts count as forbidden repo writes is blocked by `AMB-CX-007`; allowlisted attributed TERM→KILL remains the sole process power | `EMU-CX-006..008/016`, safety eval |
| `shared/refs/closing-message.md` | launch/degraded/loud-fail/dry-run terminal and exact next step | `EMU-CX-017`, closure eval |
| `shared/refs/doctor-logging.md` | unexpected script/tool/retry only; loud failures excluded | `EMU-CX-018`, closure eval |

## Allowed writes and forbidden writes

The runner recipes allow these side effects: named allowlisted process signals; requested
simulator/emulator boot, install, app launch, and window raise; background server/emulator;
log/DerivedData under `.emulate/` only when that directory is already ignored, otherwise
`$TMPDIR`. The entry point instead says there are no repository writes and the only side
effect is in the OS process table. `AMB-CX-007` blocks choosing between those contracts.

Forbidden: tracked or source file edits, `.gitignore`, commits, branches, PRs, stamps,
reports, deployment, broad/user-pattern kills, unrelated-repo processes, default cold boot,
or any OS/repository mutation during dry run. Tracked working-tree bytes must remain
identical under either interpretation; ignored workspace artifacts remain undecided until
`AMB-CX-007` is resolved.

## Output map

- Pre-sweep branch/sha/dirty → platform/runner line.
- Candidate/zero sweep sentences.
- Launch banner in exact Target, Branch, Cleared, Running order; PID and log mandatory;
  each target value says whether it came from a flag, PLATFORMS, or recommendation.
- Loud error includes the script's verbatim fix. Launch/degraded/failure/dry-run then use
  green/yellow/red shared closing semantics, last.

## Pending deviations

No difference is accepted. These pending deviations apply and block generation:

- `DEV-CX-001`: canonical slash invocation/help cannot become dollar syntax without a
  user-approved classification.
- `DEV-CX-002`: generated/installed paths, helper fallbacks, logs, and project-root
  resolution must not depend on or mutate Claude-owned state.
- `DEV-CX-003`: platform/device `AskUserQuestion` gates and shell/read bindings must
  retain the same defaults, dismissal, continuation, and enforcement semantics.
- `DEV-CX-004`: any project-instruction conflict must not change runner selection,
  command authority, or the no-repository-write contract.
- `DEV-CX-007`: sandbox/hooks and host command approval must preserve exact authority;
  a behavioral instruction cannot substitute for host enforcement.
- `DEV-CX-009`: all canonical natural-language local-run activation remains required.
  The pre-existing proposal to disable implicit Codex invocation is not adopted.
- `DEV-CX-015`: macOS GUI launch/raise may require host escalation or a visibly new
  approval gate.
- `DEV-CX-016`: persistent server/emulator lifetime, PID/log validity, and cleanup after
  the Codex turn are not yet proven equivalent.

Canonical ambiguity `AMB-CX-007` separately blocks the write boundary: the adapter may
neither silently reinterpret “writes nothing to the repo” as “no tracked writes” nor
discard the canonical `.emulate/` runner recipes.

Neither `DEV-CX-015` nor `DEV-CX-016` permits a foreground substitution, missing window,
fabricated PID/log, or silent “launched” result.

## Parity assertions

| ID | Assertion |
|---|---|
| `EMU-CX-001` | All explicit/natural triggers, help, aliases, first-match behavior, and unknown-flag failure match. |
| `EMU-CX-002` | Platform/runner/device axes compose and preserve flag > PLATFORMS/recipe resolution precedence. |
| `EMU-CX-003` | Preflight/platform parser are the sole resolvers and every loud exit/fix remains verbatim. |
| `EMU-CX-004` | Platform and device asks occur in resolver order, at most one per pass, before any mutation, with exact candidates/default/dismissal behavior. |
| `EMU-CX-005` | Declared emulate_cmd wins; placeholders collapse to absent; unresolved recipes stop without guessing. |
| `EMU-CX-006` | Branch identity is reported before mutation; dirty/main never gate and non-git loudly fails. |
| `EMU-CX-007` | Sweep candidates remain allowlisted, repo/port-attributed, visible, TERM-before-KILL, and never user-pattern broadened. |
| `EMU-CX-008` | Cold boot is explicit-only and device-pinned; zero candidates and already-running targets remain normal. |
| `EMU-CX-009` | Expo iOS command, optional exact device, log ready signal, persistence, and Simulator raise match. |
| `EMU-CX-010` | Expo Android exact-AVD, adb/Metro ready order, persistence, and no default cold boot match. |
| `EMU-CX-011` | Native iOS workspace/scheme resolution, boot/build/install/launch order, pid signal, and ambiguity stops match. |
| `EMU-CX-012` | Native Android AVD/boot/device poll/install/launch and manifest/monkey fallback match. |
| `EMU-CX-013` | Every real launch is backgrounded, survives return, uses signal-based readiness, raises the window, and returns a real PID/log. |
| `EMU-CX-014` | Every missing toolchain/device/scheme/activity follows its distinct loud-failure/fix path without incident logging. |
| `EMU-CX-015` | Dry run shares resolution/sweep discovery but performs zero process, device, GUI, or repository mutations. |
| `EMU-CX-016` | Tracked repository state, source, git state, `.gitignore`, reports, and stamps remain byte-identical in every mode; ignored `.emulate/` artifacts follow the eventual `AMB-CX-007` decision rather than an adapter assumption. |
| `EMU-CX-017` | Banner fields/order and shared launch/degraded/failure/dry-run closing message are exact and last. |
| `EMU-CX-018` | Only unexpected harness incidents log; expected loud failures do not, and logging never changes outcome. |

## Concrete eval cases

| Eval | Fixture/action | Required observations | Assertions |
|---|---|---|---|
| `emulate-routing-and-flags` | help, aliases, unknown, legal ios/expo/device/dry compositions | table/help stop; exact resolved axes; unknown stops preflight/sweep | 001,002 |
| `emulate-resolve-platform` | none/missing/single/multiple PLATFORMS plus explicit flag | existing deterministic goldens; parser only; exact ask/loud result | 002,003 |
| `emulate-platform-and-device-questions` | multiple platforms; booted/toolchain/newest/many devices; dismissals | one ask/pass; platform rerun before device; exact defaults/options/mutation order | 004 |
| `emulate-command-precedence` | declared command, USER placeholder, native/expo fallback, ambiguous recipe | override exact; placeholder falls back; ambiguity loudly stops | 005,014 |
| `emulate-sweep-safety` | owned/unowned/port/allowlist candidates; TERM refusal; cold boot | only qualified PIDs; visible reasons; TERM→KILL; no broad kill | 006..008,016 |
| `emulate-dry-run-parity` | same fixture real vs dry with command/signal stubs | identical target/kill discovery; dry mutation trace empty | 015,016 |
| `emulate-expo-ios` | stub Metro log and Simulator | exact command/device/log signal/open order; real PID/log | 009,013,017 |
| `emulate-expo-android` | selected/running AVD and Metro stubs | emulator/adb/Expo/ready order; no cold boot | 010,013,017 |
| `emulate-native-ios` | one/multiple schemes; already booted; launch pid | discovery/build/install/launch/raise exact; ambiguity fix | 011,013,014,017 |
| `emulate-native-android` | exact AVD, delayed boot prop, manifest and monkey fallback | device-side poll, Gradle/install/start order, Status ready | 012,013,014,017 |
| `emulate-loud-failures` | all exit 2/3/4/5 fixtures plus non-git | non-zero, exact cause/fix, no sweep/launch/DOCTOR | 003,006,014,018 |
| `emulate-log-fallback-and-repo-snapshot` | ignored and non-ignored `.emulate`; ios/android/expo | tracked tree/git bytes unchanged and no gitignore edit; ignored-workspace artifact expectation is parameterized by `AMB-CX-007` and cannot pass before decision | 013,016,017 |
| `emulate-process-lifetime-and-window` | real/stub long-lived server through turn completion | process alive, pid/log valid, window-raise event proven or deviation blocks | 009..013,017 |
| `emulate-shared-contracts-and-closure` | helper unexpected failures and all existing emulate deterministic fixtures | expected vs unexpected logging; closing last; all 3 digests and 4-helper closure current | 003,007,015..018 |

## Coverage accounting

- Phase-0 mapping ratio — file: `3/3 = 1.0000`.
- Phase-0 mapping ratio — reference: `2/2 = 1.0000` scoped refs, with all `3/3`
  shared-reference edges mapped.
- Phase-0 mapping ratio — behavior: `4/4 = 1.0000` runner/platform recipes, with all
  routing, resolution, question, sweep, dry-run, failure, and output branches mapped.
- Phase-0 mapping ratio — eval-specification: `18/18 = 1.0000` assertions linked to
  concrete eval designs.
- Phase-0 mapping ratio — dependency: `4/4 = 1.0000` direct, transitive, and indirect
  helper closure.
- Runtime proof = `not-run` (correct for Phase 0; GUI/process and adapter execution remain
  blocked by pending deviation decisions).
