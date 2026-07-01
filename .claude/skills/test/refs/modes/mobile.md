# test — Mobile bucket

**When it runs:** ninth bucket — after API / Contract (sequential), or concurrently with other buckets (`--fast`).

**What it checks:** Flutter/Dart app correctness across Android and iOS — widget tests (device-free), integration tests on device/emulator, and Patrol/Maestro flow tests.

## Execution

Reads `mobile_runner` from the Step 1 fingerprint — does not re-detect.

### Step 1 — Guard

If `mobile_runner` is `null`: emit `pass_with_warnings` with note `"No Flutter/Dart mobile runner detected — mobile bucket skipped."` and return immediately.

Detection signals (all require `pubspec.yaml` with a `flutter:` key):

| Runner | Detection signal | Notes |
|--------|-----------------|-------|
| `flutter` | `flutter` binary in PATH | Primary runner |
| `fvm flutter` | `fvm` binary in PATH AND `.fvm/flutter_sdk` directory present | Flutter Version Manager — preferred over bare `flutter` when both present |
| Patrol | `patrol` in `pubspec.yaml` dependencies/dev_dependencies | Flutter-native integration testing framework |
| Maestro | `maestro` binary in PATH OR `.maestro/` directory at project root | Cross-platform flow testing |

Use `fvm flutter` over `flutter` when FVM is detected. Patrol and Maestro run **in addition to** the base flutter runner when detected.

### Step 2 — Detect test surface

Identify what test types are available:

| Sub-check | Condition | Command |
|-----------|-----------|---------|
| Widget / unit | `test/` directory with `*_test.dart` files | `flutter test` (or `fvm flutter test`) |
| Integration | `integration_test/` directory with `*_test.dart` files | `flutter test integration_test/` |
| Patrol | Patrol detected AND `integration_test/` present | `patrol test` |
| Maestro | Maestro detected AND `.maestro/*.yaml` flows present | `maestro test .maestro/` |

Emit: `Mobile sub-checks: <list of active sub-checks>.`

If no `test/` and no `integration_test/` directory is found: emit `pass_with_warnings` with note `"No Dart test files found — mobile bucket skipped."` and return.

### Step 3 — Detect device matrix

Widget/unit tests run without a device. Integration tests, Patrol, and Maestro require a connected device or running emulator/simulator.

**Step 3a — Read matrix config**

Look for `.flutter-test-matrix.json` at project root. If found, read the device list from it. Example shape:
```json
{
  "devices": [
    { "platform": "ios",     "name": "iPhone 15 Pro", "os": "17.5" },
    { "platform": "android", "name": "Pixel 8",       "os": "14"   }
  ]
}
```

**Step 3b — Auto-detect available devices**

If no matrix config, auto-detect:

- **iOS** (macOS only): run `xcrun simctl list devices available -j`; pick the first booted simulator; if none booted, pick the latest available and boot it with `xcrun simctl boot <udid>`.
- **Android**: run `flutter emulators` or `emulator -list-avds`; pick the first entry; start it with `flutter emulators --launch <id>` if not already running.

If neither platform is available: skip integration/Patrol/Maestro sub-checks; emit `pass_with_warnings` with note `"No iOS simulator or Android emulator available — integration tests skipped."`. Widget/unit tests still run.

If only one platform is available: run integration tests on that platform; emit `pass_with_warnings` with note `"Only <platform> available — cross-platform matrix incomplete."`.

Emit: `Mobile matrix: <N> devices (iOS: <n>, Android: <n>).`

### Step 4 — Run sub-checks

Run each active sub-check in order (or concurrently per device under `--fast`):

1. **Widget/unit** — `flutter test` (or `fvm flutter test`). No device required.
2. **Integration (per device)** — `flutter test integration_test/ -d <device-id>`. Run on each device in the matrix.
3. **Patrol (per device)** — `patrol test -d <device-id>`.
4. **Maestro (per device)** — `maestro test .maestro/ --device <device-id>`.

Capture stdout, stderr, exit code, and any produced artifacts (screenshots, traces, `.xml` test reports).

### Step 5 — Parse results

**Flutter test output** (standard `--reporter json` or TAP format):

- Failed test → `fail` severity
- Skipped test → `warn` severity (counts toward `totals.skipped`)
- Error during setup/teardown (not a test assertion) → `fail` severity

For each failure, extract:

- `file` — Dart test file path (e.g. `test/widget_test.dart`, `integration_test/app_test.dart`)
- `line` — line number of the failing assertion if reported, else `null`
- `rule` — test name / description (e.g. `"renders login button"`)
- `message` — failure message from the test output
- `repro` — `flutter test <file> --name "<test name>" -d <device-id>` or equivalent
- `suggestion` — `null` (test failures are self-describing; no generic suggestion)
- artifact — path to screenshot or trace artifact if produced, else `null` (goes in `evidence.file`)

Findings conform to the canonical finding object (`../../../shared/refs/finding-schema.md`). `severity` is `high` for a widget or integration test failure; `medium` for a device/matrix-degraded result. `platform` (`"ios"` | `"android"` | `"widget"`) and `device` (device name/id, or `null` for widget tests) are **not** top-level finding fields — the shared schema only sanctions bucket extensions inside `evidence`, so they live at `evidence.platform` / `evidence.device`. `evidence.tool` is `flutter`/`fvm flutter`/`patrol`/`maestro`, whichever sub-check produced the finding.

**Patrol / Maestro output:** parse their respective JSON/XML output formats using the same field mapping.

**Deduplication:** if the same test failure occurs on both iOS and Android, keep both findings (platform-specific failures are distinct). Only deduplicate exact duplicates on the same platform/device.

Record aggregate totals:

- `totals.widget.passed` / `totals.widget.failed` / `totals.widget.skipped`
- `totals.integration.ios.passed` / `totals.integration.ios.failed`
- `totals.integration.android.passed` / `totals.integration.android.failed`

## Error handling

| Error condition | Verdict | Note in output |
|----------------|---------|----------------|
| `flutter` / `fvm` binary not found | `pass_with_warnings` | `"flutter not found — install the Flutter SDK or run: brew install flutter."` |
| `pubspec.yaml` missing `flutter:` key | `pass_with_warnings` | `"pubspec.yaml found but no flutter: section — is this a Flutter project?"` |
| `flutter pub get` fails before test run | `pass_with_warnings` | `"flutter pub get failed — run it manually and check pubspec.yaml."` Include stderr (max 5 lines). |
| iOS simulator boot times out (> 120 s) | Skip iOS; continue with Android | `"iOS simulator timed out after 120 s — iOS tests skipped."` |
| Android emulator boot times out (> 180 s) | Skip Android; continue with iOS | `"Android emulator timed out after 180 s — Android tests skipped."` |
| Device disconnects mid-run | Mark in-progress tests as `pass_with_warnings`; continue other devices | `"Device <id> disconnected during run — partial results for <platform>."` |
| Test run times out (> 300 s per sub-check per device) | Kill runner; `pass_with_warnings` for that sub-check | `"<sub-check> on <device> timed out after 300 s."` |
| Patrol binary not found | Skip Patrol sub-check; continue | `"patrol not found — install with: dart pub global activate patrol_cli."` |
| Maestro binary not found | Skip Maestro sub-check; continue | `"maestro not found — install from maestro.mobile.dev."` |
| No `integration_test/` directory | Skip integration/Patrol/Maestro; run widget only | (no warning needed — widget-only is a valid config) |

## Output

```json
{
  "verdict": "pass" | "pass_with_warnings" | "fail",
  "bucket": "mobile",
  "runner": "flutter" | "fvm flutter",
  "matrix": [
    { "platform": "ios" | "android", "device": "<name>", "os": "<version>" }
  ],
  "errors": [
    { "sub_check": "<widget|integration|patrol|maestro>", "platform": "<ios|android|null>", "reason": "<description>" }
  ],
  "totals": {
    "widget":      { "passed": 0, "failed": 0, "skipped": 0 },
    "integration": {
      "ios":     { "passed": 0, "failed": 0 },
      "android": { "passed": 0, "failed": 0 }
    }
  },
  "findings": [
    {
      "id": "mobile-<n>",
      "source": "mobile",
      "severity": "high" | "medium",
      "category": "mobile",
      "file": "<dart test file path>",
      "line": "<number or null>",
      "rule": "<test name>",
      "message": "<failure message>",
      "evidence": {
        "tool": "flutter" | "fvm flutter" | "patrol" | "maestro",
        "file": "<screenshot or trace path, or null>",
        "line": "<number or null>",
        "snippet": "<failure message>",
        "platform": "ios" | "android" | "widget",
        "device": "<device name or null>"
      },
      "suggestion": null,
      "repro": "<flutter test command to reproduce>",
      "regression_of": null
    }
  ]
}
```

`fail` if any widget or integration test fails. `pass_with_warnings` if device matrix is incomplete, sub-checks skipped, or runner unavailable. `pass` if all active sub-checks pass on all available devices.
