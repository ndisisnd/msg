---
name: coverage
description: Pre-merge coverage-gate component — enforce line/branch/function thresholds by parsing an existing report or re-running with coverage. Floor is enforced or advisory per the platform profile.
---

# coverage component

Guard, error rule, envelope: `../_common.md`. Runner (`coverage_runner`: Flutter / Jest /
NYC / pytest-cov / Go) from the fingerprint.

## Report + thresholds

Reuse a fresh existing report (`coverage/lcov.info`, `coverage-summary.json`,
`coverage.out`, `.coverage`; modified < 10 min ago) rather than re-running; else run
the coverage command. Thresholds by priority: runner config (`coverageThreshold.global`,
`.nycrc`, pubspec `coverage_threshold`, pytest `fail_under`) → `.coverage-thresholds.json`
→ defaults (lines 80%, branches 70%, functions 80%).

## Parse

Parse lcov (`SF/LH/LF/BRH/BRF/FNH/FNF`) for per-file + overall percentages. Exclude
generated (`*.g.dart`, `*.freezed.dart`, …), test files, and mocks from **findings**
(still parsed, just not flagged) — the exclusion set is **unchanged** by C10 (AC-CV4).

## Verdict — judge the diff, ratchet the total (C10)

Coverage grades **the change**, not the repo's pre-existing debt — a fully-tested PR is
never blocked for coverage the author didn't touch.

### Diff-coverage is the blocking signal (AC-CV1/CV3)

**Diff-coverage** = of the lines *this diff* added/changed (reuse the executor's
`resolve-diff` surface to map changed lines → source lines), what fraction is covered by
the parsed report? This is the component's **blocking** signal. It honors the catalog's
**config-driven criticality** (`†`, Step 0 `coverage_mode`):

- **budget set** (`enforced` — the project configured explicit thresholds) → diff-coverage
  below the bar = `fail`; a per-file diff shortfall → `high`, else `medium`.
- **no budget** (`advisory` — standard/lenient) → a diff-coverage shortfall is a `medium`
  (standard) / `low` (lenient) finding only, never `fail`.

Applying the bar to the **diff** (not the whole repo) means the author is accountable for
what they changed, with no penalty for others' debt (AC-CV1/CV3).

### Total coverage is advisory context + a no-regression ratchet (AC-CV2)

Total (whole-repo) coverage never blocks a well-covered diff on its own. It carries two
things:

1. **Advisory context** — the overall percentages, reported for visibility.
2. **A no-regression ratchet** — total coverage may **not decrease vs base**. This is
   the shared **ratchet-vs-base** pattern (`../../../shared/refs/ratchet-vs-base.md`) —
   coverage is one of its three consumers (with perf C14 + api C15). Fetch the base
   branch's coverage (its report, or recompute on base) and compare **like-for-like**
   — same runner, same exclusion set, same metric (AC-CV4). A **drop** vs base → a finding
   (`rule: coverage-regression`, `category: coverage`; `high` when a budget is set, else
   `medium`) naming the delta. A low absolute total with **no** drop is **not** a finding —
   the ratchet gates *direction*, not *level*. If base coverage is **unavailable**
   (first run / no base report and base recompute not possible), skip the ratchet with a
   note (`reason: "no_base_coverage"`) — never fabricate a regression.

Finding fields: `rule` = `line-coverage`/`branch-coverage`/`function-coverage` (diff bar) or
`coverage-regression` (ratchet); `file` = source path (`null` for the repo-level ratchet);
`line` = `null` (file-level); `message` = observed-vs-threshold or the vs-base delta;
`suggestion` = uncovered changed-line ranges from lcov when available.

Component fields: `runner`, `report_path`, `report_source` (existing/regenerated),
`thresholds`, `totals` (overall %, files_checked, files_below_threshold), `diff_coverage`
(changed-line %, changed-lines-covered), `base_total` (+ `delta` vs base, or
`no_base_coverage`).
