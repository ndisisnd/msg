---
name: bucket-qa
description: Pre-merge visual/QA bucket — compare screenshots/renders against baselines via the detected runner, parse diffs to canonical findings.
---

# qa (visual) bucket

Guard, error rule, envelope: `_common.md`. Runner (`qa_runner`: Playwright visual /
Chromatic / Percy / BackstopJS / Loki) from the Step 1 fingerprint.

## Baseline check

Verify baselines exist before running: Playwright `.png` snapshots; BackstopJS
`backstop_data/bitmaps_reference/`; Loki `.loki/reference/`; Chromatic/Percy are
remote (assume present if configured). No local baseline and not Chromatic/Percy →
`pass_with_warnings`, note `"No visual baselines found — run once in update mode."`

## Run + parse

Execute `qa_runner.command`.

- Exit 0, no diffs (or below threshold) → `pass`.
- Non-zero with visual diffs → each diff is one finding, `severity: high` (`medium` if attribution/threshold uncertain).
- Runner crash/auth error → `pass_with_warnings`, note `"QA runner failed to start — results unreliable."`.

Finding fields: `rule` = story/snapshot name; `file` = spec/story that produced the
diff; `evidence.file` = diff-image path or report URL; `message` = e.g. `"23.4% pixel
difference exceeds 0.1% threshold"`. Totals: `{ passed, failed, skipped }`.
