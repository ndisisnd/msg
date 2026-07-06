# test — Coverage gate bucket

**When it runs:** tenth bucket in `--sequential` order — after Mobile; by default runs concurrently as its own subagent.

**What it checks:** enforces minimum line/branch coverage thresholds by parsing an existing coverage report or re-running the test suite with coverage enabled.

## Execution

Guard, bucket-error rule, and output envelope: see `_common.md`. `coverage_runner` (name, coverage `command`, and `report` path — e.g. Flutter / Jest / NYC / pytest-cov / Go) comes from the Step 1 fingerprint — this bucket does not re-detect. The fingerprint's command is already FVM-aware for Flutter.

### Step 1 — Guard

Per `_common.md`: if `coverage_runner` is `null`, emit `pass_with_warnings` with note `"No coverage runner detected — coverage bucket skipped."` and return immediately.

### Step 2 — Resolve existing report

Before re-running tests, check if a coverage report already exists from an earlier bucket run in this session:

| Runner | Check for |
|--------|-----------|
| Flutter / NYC / Jest | `coverage/lcov.info` |
| Jest (alternative) | `coverage/coverage-summary.json` |
| pytest-cov | `coverage.lcov` or `.coverage` |
| Go | `coverage.out` |

If a fresh report exists (modified in the last 10 minutes): parse it directly — **do not re-run tests**.

If no report exists: run the coverage command from Step 1. Capture stdout, stderr, and exit code.

Emit: `Coverage: using existing report at <path>.` or `Coverage: running <command>.`

### Step 3 — Resolve thresholds

Resolve in priority order:

1. **Runner config:**
   - Flutter: `coverage_threshold` field in `pubspec.yaml` (project-local convention: `flutter_test: coverage_threshold: 80`)
   - Jest: `coverageThreshold.global` in `jest.config.*`
   - NYC: `check-coverage` + `lines` / `branches` in `.nycrc` or `package.json`
   - pytest-cov: `fail_under` in `setup.cfg` `[coverage:report]` or `pyproject.toml`
   - Go: no built-in config; falls through to step 2
2. **`.coverage-thresholds.json`** at project root:
   ```json
   { "lines": 80, "branches": 70, "functions": 80 }
   ```
3. **Defaults:**
   - Lines: 80%
   - Branches: 70%
   - Functions: 80%

Emit: `Coverage thresholds: lines ≥ <n>%, branches ≥ <n>%, functions ≥ <n>%.`

### Step 4 — Parse report

Parse the coverage report to extract per-file and overall coverage metrics.

**lcov.info parsing:**
- Read `SF:` (source file), `LH:` (lines hit), `LF:` (lines found), `BRH:` (branches hit), `BRF:` (branches found), `FNH:` (functions hit), `FNF:` (functions found).
- Compute per-file: `line_pct = LH / LF * 100`, `branch_pct = BRH / BRF * 100`, `function_pct = FNH / FNF * 100`.
- Compute overall: sum all LH/LF/BRH/BRF/FNH/FNF across all files.

**Go `coverage.out` parsing:**
- Run `go tool cover -func=coverage.out` to get per-function and total coverage.
- Map total line to `line_pct`; branch and function not available → set to `null`.

**Files to exclude from threshold checking:**
- Generated files: `*.g.dart`, `*.gen.dart`, `*.freezed.dart`, `*.gr.dart` (Flutter code generation)
- Test files themselves: `*_test.dart`, `*.test.ts`, `test_*.py`
- Mock files: `mock_*.dart`, `*.mock.ts`
- Do not exclude these from the lcov parse — just do not raise a finding if they fall below threshold.

### Step 5 — Check thresholds and emit findings

**Overall verdict logic:**
- If overall `line_pct` < threshold → `fail`
- If overall `branch_pct` < threshold (and `branch_pct` is not `null`) → `fail`
- If overall `function_pct` < threshold (and `function_pct` is not `null`) → `fail`
- Otherwise → `pass`

**Per-file findings** (only for non-excluded files):
- Emit one finding per file that falls below any threshold.
- Severity: `fail` if the file's shortfall would drag overall coverage below threshold; `warn` otherwise.

For each failing file, extract:

- `file` — source file path
- `line` — `null` (coverage is file-level)
- `rule` — which metric failed (e.g. `"line-coverage"`, `"branch-coverage"`)
- `message` — observed vs threshold (e.g. `"lib/auth/login_bloc.dart: 61% lines (threshold: 80%)"`)
- `repro` — command to run coverage for just this file (e.g. `flutter test --coverage test/auth/login_bloc_test.dart`)
- `suggestion` — `"Add tests for uncovered branches in <file>"` with specific uncovered line ranges from lcov if available

Record aggregate totals:

- `totals.overall.lines_pct` / `totals.overall.branches_pct` / `totals.overall.functions_pct`
- `totals.files_checked` — number of non-excluded files checked
- `totals.files_below_threshold` — number of files below any threshold

## Error handling

| Error condition | Verdict | Note in output |
|----------------|---------|----------------|
| Runner binary not found | `pass_with_warnings` | `"<runner> not found — install it or add to dependencies."` |
| Coverage command fails (non-zero, no report produced) | `pass_with_warnings` | `"Coverage run failed — no report produced."` Include stderr (max 5 lines). |
| Report file exists but is empty or malformed | `pass_with_warnings` | `"Coverage report at <path> is empty or unreadable."` |
| Report is stale (> 10 min old) and re-run also fails | `pass_with_warnings` | `"Stale coverage report and re-run failed."` |
| All files excluded (generated code only) | `pass_with_warnings` | `"All source files are excluded (generated code) — no coverage thresholds enforced."` |
| Branch coverage not available for runner (e.g. Go) | Skip branch threshold; check lines only | Note `"Branch coverage not available for <runner> — checking lines only."` |

Findings conform to the canonical finding object (`../../../shared/refs/finding-schema.md`). Per Step 5's severity split: `fail`-tier files (shortfall drags overall coverage below threshold) → `high`; `warn`-tier files (below threshold but not overall-blocking) → `medium`. `evidence.tool` is the coverage runner name; `evidence.file` mirrors the top-level `file`; `evidence.snippet` carries the observed-vs-threshold line.

## Output

Envelope + finding shape per `_common.md`. Bucket fields:

```json
"runner": "<runner name>", "report_path": "<path to lcov.info or equivalent>",
"report_source": "existing" | "regenerated",
"thresholds": { "lines": 80, "branches": 70, "functions": 80 },
"totals": { "overall": { "lines_pct": 0.0, "branches_pct": 0.0, "functions_pct": 0.0 }, "files_checked": 0, "files_below_threshold": 0 }
```

Findings: category/source `coverage`; per the Step 5 severity split (overall-blocking→high, else→medium); `rule` = `"line-coverage"|"branch-coverage"|"function-coverage"`, `line` = null (file-level).

`fail` if overall line, branch, or function coverage falls below its threshold. `pass_with_warnings` if runner unavailable, report unreadable, or all files excluded. `pass` if all thresholds are met.
