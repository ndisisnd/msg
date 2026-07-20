---
name: mobile
description: Pre-merge mobile component — native iOS (XCUITest/XCTest) + native Android (Espresso/JUnit) and Flutter/Dart widget + integration tests across an ENFORCED Android/iOS device matrix, plus Patrol/Maestro flows. Failures are flow-named. Parse to canonical findings.
---

# mobile component

Guard, error rule, envelope: `../_common.md`. `mobile` is a **self-contained** native
Android/iOS vertical — it must cover the **native** apps most teams ship (Swift, Kotlin),
not Flutter/Dart only. Runners come from the Step 1 fingerprint (`mobile_runner`, now a
set — see below). This is the mobile analog of C13's native a11y: it turns C12's
native-mobile *flag* into real coverage (AC-MOB3).

## Runner detection (native + Flutter — C18/M1)

`mobile_runner` resolves to **whichever of these are present**, run **in addition** to
each other — a repo is not Flutter-only:

| Runner | Detect | Command |
|---|---|---|
| **iOS native (Swift)** | `*.xcodeproj`/`*.xcworkspace` + `XCUITest`/`XCTest` targets (`*UITests`/`*Tests`) | `xcodebuild test -scheme <s> -destination <sim>` |
| **Android native (Kotlin)** | Gradle + `androidTest/` (Espresso) or `test/` (JUnit) | `./gradlew connectedAndroidTest` (Espresso) / `./gradlew test` (JUnit) |
| **Flutter widget/unit** | `test/` with `*_test.dart` | `flutter test` (or `fvm flutter test`) — no device |
| **Flutter integration** | `integration_test/` with `*_test.dart` | `flutter test integration_test/ -d <device>` |
| **Patrol** | Patrol + `integration_test/` | `patrol test -d <device>` |
| **Maestro** | Maestro + `.maestro/*.yaml` | `maestro test .maestro/ --device <device>` |

Patrol/Maestro run in addition to the base Flutter runner when their flag is set.
**A native SwiftUI/Kotlin app with no Dart files is no longer green** (AC-MOB1): the old
"no `test/`+`integration_test/` → `pass_with_warnings` (No Dart test files found)" path
applies **only** when *none* of the runners above is present. When a native runner **is**
present it runs; when a native runner is **detected but has no tests**, that is a
coverage gap on that platform (below), not a silent pass.

## Enforced device/OS matrix (C18/M2)

Read the **declared** `{platform, os}` matrix from the generalized declared-matrix config
(`.flutter-test-matrix.json` or the manifest's mobile matrix; established by `--init` when
absent — see `../protocol-init.md`). The matrix is **enforced**, not a soft fallback:

- For each declared `{platform, os}`, a runner must actually **execute** on an available
  device/simulator. A declared target with **no available device/simulator** (e.g. a Linux
  CI box with no iOS simulator, or **no macOS host** for the iOS XCUITest runner) is a
  **`high`** finding — `rule: platform-coverage-gap`, `category: mobile`, ties to C12's
  enforced coverage-gap (AC-MOB2) — **never** `pass_with_warnings`. This kills the silent
  false-green where an untested platform stays green forever.
- iOS native (XCUITest) **requires a macOS host** — the same host constraint the simulator
  path already has; its absence is now this **enforced** M2 finding, not a silent skip.
- Device discovery (only to *satisfy* a declared entry): iOS via
  `xcrun simctl list devices available -j` (boot the latest; macOS only); Android via
  `flutter emulators` / `emulator -list-avds` / `adb devices`. Discovery failing to place a
  **declared** target is the gap finding above — discovery is not the source of truth, the
  declared matrix is.
- **No declared matrix** → `--init` establishes one (target platforms + OS versions,
  `../protocol-init.md`); until then, degrade to running detected runners on whatever
  devices are available with a note (no fabricated matrix).

The **self-contained Flutter path is preserved** (widget/integration + Patrol/Maestro) for
Flutter projects — no regression (AC-MOB5).

## C12 satisfaction (AC-MOB3)

When a platform's native runner **is** present and actually runs on a matrix device, C12's
native-mobile coverage-gap for that platform is **satisfied** (flag → real coverage). An
absent-or-unexecuted declared platform stays a `high` gap.

## Parse — flow-named findings (C18/M3)

Native + Flutter reporters (Flutter `--reporter json`/TAP; `xcodebuild` result bundle;
Gradle test XML): failed test → finding; skipped → `totals.skipped`; setup/teardown error
→ finding. `severity: high` for a widget/integration/native failure, `medium` for a
device-degraded result.

Findings **lead with the user flow + platform/OS** per
`../../../shared/refs/name-the-user-impact.md` (AC-MOB4): `message` =
*"swipe-to-delete broken on iOS 17"*, with the **test name secondary** in `rule` and
`evidence`. Finding fields: `rule` = test name; `file` = test path (Dart/Swift/Kotlin);
`evidence.platform` (`ios`/`android`/`widget`) + `evidence.os` + `evidence.device` carry
the matrix (never top-level); `evidence.tool` = xcuitest/xctest/espresso/junit/flutter/
fvm/patrol/maestro. Same failure on iOS and Android → keep both (platform-specific).
Timeouts/binary-missing follow the `../_common.md` error rule (→ `pass_with_warnings`, skip
that sub-check) — **except** a missing device for a *declared* target, which is the
enforced M2 gap, not a soft skip.

Component fields: `runner`, `matrix[]` (declared + executed), `errors[]`, `totals` (per-runner passed/failed/skipped).
