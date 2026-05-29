# HANDOFF — 2026-05-29 — test Phase 3 (--mobile) + Coverage (--coverage)

## Purpose

Precise, verifiable record of every change made during Phase 3 (mobile bucket) and the coverage gate bucket addition. A verifier agent should be able to confirm each change by reading the listed files directly.

---

## Files Changed

### NEW: `.claude/skills/test/refs/modes/mobile.md`

Created from scratch. Flutter/Dart mobile testing bucket. Key design points:

- **Bucket order:** 9th (after API/Contract).
- **Flutter-specific:** requires `pubspec.yaml` with `flutter:` key AND `flutter` / `fvm flutter` in PATH.
- **FVM preference:** `fvm flutter` preferred over bare `flutter` when both detected.
- **Sub-checks (4):** widget/unit (`flutter test`), integration per device (`flutter test integration_test/`), Patrol (`patrol test`), Maestro (`maestro test .maestro/`).
- **Widget tests are device-free** — always run. Integration/Patrol/Maestro require a device.
- **Device matrix resolution order:**
  1. `.flutter-test-matrix.json` at project root (shape: `{ "devices": [{ "platform", "name", "os" }] }`)
  2. Auto-detect: iOS via `xcrun simctl list devices available -j` (boot if none booted), Android via `flutter emulators` / `emulator -list-avds`.
  3. If neither platform available: skip integration/Patrol/Maestro, `pass_with_warnings`.
  4. If only one platform: run on it, `pass_with_warnings` for incomplete matrix.
- **Deduplication rule:** same failure on iOS + Android = two distinct findings (not collapsed).
- **Excluded files from threshold checks:** none — coverage exclusion is in the coverage bucket.
- **Finding shape extension:** adds `platform` (`"ios"` | `"android"` | `"widget"`) and `device` fields beyond the base finding shape.
- **Error table:** 9 conditions — all `pass_with_warnings`. Simulator/emulator boot timeouts: iOS 120 s, Android 180 s. Sub-check run timeout: 300 s per device.
- **Output JSON:** `runner` (string), `matrix` (array of `{platform, device, os}`), `errors` (array of `{sub_check, platform, reason}`), `totals` (nested: `widget.passed/failed/skipped`, `integration.ios.passed/failed`, `integration.android.passed/failed`), `findings`.

---

### NEW: `.claude/skills/test/refs/modes/coverage.md`

Created from scratch. Coverage gate bucket. Key design points:

- **Bucket order:** 10th (after Mobile).
- **Runners (5, first-match):** Flutter (`flutter test --coverage` → `coverage/lcov.info`), Jest (`--coverage --coverageReporters=json-summary`), NYC/Istanbul (`nyc --reporter=lcov`), pytest-cov (`--cov --cov-report=lcov`), Go (`go test -coverprofile=coverage.out ./...`). Flutter FVM preferred when detected.
- **Existing report reuse:** if a report file exists and was modified within the last 10 minutes, parse it directly — do not re-run tests.
- **Threshold resolution order:**
  1. Runner config (Jest `coverageThreshold`, `.nycrc`, `setup.cfg fail_under`, `pubspec.yaml coverage_threshold`)
  2. `.coverage-thresholds.json` at project root: `{ "lines": 80, "branches": 70, "functions": 80 }`
  3. Defaults: lines 80%, branches 70%, functions 80%
- **lcov parsing:** reads `SF:`, `LH:`, `LF:`, `BRH:`, `BRF:`, `FNH:`, `FNF:` per file; computes per-file and overall percentages.
- **Go special case:** `go tool cover -func=coverage.out` for line coverage only; branch + function not available → set to `null`, skip those thresholds.
- **Excluded from threshold findings (not from parse):** `*.g.dart`, `*.gen.dart`, `*.freezed.dart`, `*.gr.dart`, `*_test.dart`, `*.test.ts`, `test_*.py`, `mock_*.dart`, `*.mock.ts`.
- **Finding severity:** `fail` if the file drags overall below threshold; `warn` otherwise.
- **Output JSON:** `runner`, `report_path`, `report_source` (`"existing"` | `"regenerated"`), `thresholds` (`lines`, `branches`, `functions`), `totals` (`overall.lines_pct/branches_pct/functions_pct`, `files_checked`, `files_below_threshold`), `findings`.

---

### MODIFIED: `.claude/skills/test/SKILL.md`

Six changes in document order:

#### 1. Frontmatter `description`

Old phrase: `"visual (QA), load, accessibility, performance budget, and API/contract test buckets"` / flags `(--unit, ..., --api)`

New phrase: `"visual (QA), load, accessibility, performance budget, API/contract, mobile (Flutter/Dart, Android + iOS), and coverage gate buckets"` / flags `(--unit, ..., --api, --mobile, --coverage)`

#### 2. Mode flags list

Added two lines after `--api`:
```
- `--mobile` — run only the mobile testing bucket (Flutter/Dart; Android + iOS)
- `--coverage` — run only the coverage gate bucket
```

#### 3. Step 1/5 — Detect tooling

Added two bullets after `api_runner`:
```
- **`mobile_runner`** — mobile testing runner object, or `null` if none detected. Requires `pubspec.yaml` with `flutter:` key. Recognised tools: `flutter`, `fvm flutter`, Patrol, Maestro. See `refs/modes/mobile.md` for device matrix detection.
- **`coverage_runner`** — coverage gate runner object, or `null` if none detected. Recognised tools: Flutter (`flutter test --coverage`), Jest, NYC/Istanbul, pytest-cov, Go.
```

#### 4. Step 3/5 — Execution plan display

Added two lines to the fenced block after `API / Contract`:
```
Mobile            → <mobile_runner.command> [iOS: <n> device(s), Android: <n> device(s)]
Coverage          → <coverage_runner.command> (thresholds: lines ≥ <n>%, branches ≥ <n>%)
```

#### 5. Step 4/5 — Skip condition + bucket table + sequential note

Skip condition bullet updated to include `--mobile`, `--coverage`:
```
(`--unit`, `--e2e`, `--functional`, `--qa`, `--load`, `--a11y`, `--perf`, `--api`, `--mobile`, `--coverage`)
```

Bucket table rows 9 and 10 added:
```
| 9  | Mobile   | `--mobile`   | `refs/modes/mobile.md`   | `mobile_runner` is `null`   |
| 10 | Coverage | `--coverage` | `refs/modes/coverage.md` | `coverage_runner` is `null` |
```

Sequential note changed from `1→8` to `1→10`.

#### 6. References section

Added two lines after `refs/modes/api.md`:
```
- `refs/modes/mobile.md` — Flutter/Dart mobile testing, Android + iOS device matrix, Patrol/Maestro
- `refs/modes/coverage.md` — coverage gate runner invocation, lcov parsing, threshold enforcement
```

---

### MODIFIED: `.claude/skills/test/refs/schema.md`

Two entries appended to the `buckets` object (after `api`):

Old:
```json
    "api":        { "verdict": "...", "runners": [], "commands": [], "totals": {}, "findings": [] }
```

New:
```json
    "api":        { "verdict": "...", "runners": [], "commands": [], "totals": {}, "findings": [] },
    "mobile":     { "verdict": "...", "runner": "...", "matrix": [], "totals": {}, "findings": [] },
    "coverage":   { "verdict": "...", "runner": "...", "report_path": "...", "thresholds": {}, "totals": {}, "findings": [] }
```

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Mobile bucket is Flutter-only, not generic | User explicitly stated dart-flutter across Android + iOS — no point designing for React Native / Xamarin at this stage |
| FVM preferred over bare `flutter` | FVM is standard in teams managing multiple Flutter versions; using the wrong SDK version silently produces wrong results |
| Widget tests always run (no device needed) | Fast feedback; widget tests don't need a simulator and shouldn't be blocked by device availability |
| Coverage bucket parses existing report first | The mobile bucket (and unit bucket) may already have produced `coverage/lcov.info`; re-running wastes time |
| Flutter generated files excluded from coverage threshold findings | `*.g.dart`, `*.freezed.dart` etc. are always 0% by definition — counting them as failures is noise |
| Go branch coverage not enforced | `go test` doesn't emit branch data; enforcing a threshold of 0% would be meaningless |
| Coverage is bucket 10 (last) | Must run after other buckets so it can reuse their coverage artifacts if available |

---

## Not Affected

- Browser compatibility matrix (BrowserStack, Sauce Labs)
- No existing mode files were modified

## Next Steps

- Commit this changeset (2 new mode files + 2 modified files + this handoff)
- Consider browser compatibility bucket (`--browser`: BrowserStack, Sauce Labs)
- Consider snapshot / golden file update workflow for the QA bucket
