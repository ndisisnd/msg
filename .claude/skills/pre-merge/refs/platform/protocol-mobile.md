---
name: mobile
description: Pre-merge mobile component — Flutter/Dart widget + integration tests across an Android/iOS device matrix, plus Patrol/Maestro flows. Parse to canonical findings.
---

# mobile component

Guard, error rule, envelope: `../_common.md`. Runner (`mobile_runner`, already `flutter`
or `fvm flutter` plus `patrol`/`maestro` + `has_test_dir`/`has_integration_dir` flags)
from the Step 1 fingerprint. Patrol/Maestro run **in addition to** the base flutter
runner when their flag is set.

## Sub-checks

| Sub-check | Condition | Command |
|---|---|---|
| Widget/unit | `test/` with `*_test.dart` | `flutter test` (or `fvm flutter test`) — no device |
| Integration | `integration_test/` with `*_test.dart` | `flutter test integration_test/ -d <device>` |
| Patrol | Patrol + `integration_test/` | `patrol test -d <device>` |
| Maestro | Maestro + `.maestro/*.yaml` | `maestro test .maestro/ --device <device>` |

No `test/` and no `integration_test/` → `pass_with_warnings`, note `"No Dart test files found."`

## Device matrix

Read `.flutter-test-matrix.json` if present (list of `{platform, name, os}`). Else
auto-detect: iOS via `xcrun simctl list devices available -j` (boot the latest if
none booted; macOS only); Android via `flutter emulators` / `emulator -list-avds`
(launch the first). Neither available → run widget/unit only, `pass_with_warnings`
note `"No simulator/emulator — integration tests skipped."` Only one platform →
run it, note the incomplete matrix.

## Parse

Flutter `--reporter json`/TAP: failed test → finding; skipped → `totals.skipped`;
setup/teardown error → finding. `severity: high` for a widget/integration failure,
`medium` for a device-degraded result. Finding fields: `rule` = test name; `file` =
Dart test path; `evidence.platform` (`ios`/`android`/`widget`) + `evidence.device`
carry the matrix (never top-level); `evidence.tool` = flutter/fvm/patrol/maestro.
Same failure on iOS and Android → keep both (platform-specific). Timeouts/binary-missing
follow the `../_common.md` error rule (→ `pass_with_warnings`, skip that sub-check).

Component fields: `runner`, `matrix[]`, `errors[]`, `totals` (per-sub-check passed/failed/skipped).
