---
name: bucket-coverage
description: Pre-merge coverage-gate bucket — enforce line/branch/function thresholds by parsing an existing report or re-running with coverage. Floor is enforced or advisory per the platform profile.
---

# coverage bucket

Guard, error rule, envelope: `_common.md`. Runner (`coverage_runner`: Flutter / Jest /
NYC / pytest-cov / Go) from the fingerprint.

## Report + thresholds

Reuse a fresh existing report (`coverage/lcov.info`, `coverage-summary.json`,
`coverage.out`, `.coverage`; modified < 10 min ago) rather than re-running; else run
the coverage command. Thresholds by priority: runner config (`coverageThreshold.global`,
`.nycrc`, pubspec `coverage_threshold`, pytest `fail_under`) → `.coverage-thresholds.json`
→ defaults (lines 80%, branches 70%, functions 80%).

## Parse + verdict

Parse lcov (`SF/LH/LF/BRH/BRF/FNH/FNF`) for per-file + overall percentages. Exclude
generated (`*.g.dart`, `*.freezed.dart`, …), test files, and mocks from **findings**
(still parsed, just not flagged).

**Profile-aware floor** (Step 0 `coverage_mode`):
- `enforced` (strict) → overall below any threshold = `fail`; per-file overall-blocking shortfall → `high`, else `medium`.
- `advisory` (standard/lenient) → never `fail` on coverage; shortfalls are `medium` (standard) / `low` (lenient) findings only.

Finding fields: `rule` = `line-coverage`/`branch-coverage`/`function-coverage`;
`file` = source path; `line` = `null` (file-level); `message` = observed-vs-threshold;
`suggestion` = uncovered line ranges from lcov when available.

Bucket fields: `runner`, `report_path`, `report_source` (existing/regenerated),
`thresholds`, `totals` (overall percentages, files_checked, files_below_threshold).
