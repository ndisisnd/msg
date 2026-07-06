# test — QA / Visual bucket

**When it runs:** fourth bucket in `--sequential` order — after Functional; by default runs concurrently as its own subagent.

**What it checks:** visual regressions by comparing screenshots or component renders against stored baselines.

## Execution

Guard, bucket-error rule, and output envelope: see `_common.md`. `qa_runner` (name, command, e.g. Playwright visual / Chromatic / Percy / BackstopJS / Loki) comes from the Step 1 fingerprint — this bucket does not re-detect.

### Step 1 — Guard

Per `_common.md`: if `qa_runner` is `null`, emit `pass_with_warnings` with note `"No visual testing runner detected — QA bucket skipped."` and return immediately.

### Step 2 — Baseline check

Before running, verify baselines exist:

- **Playwright:** look for `.png` snapshot files under the project.
- **Chromatic / Percy:** baselines are remote — assume they exist if the runner is configured.
- **BackstopJS:** check `backstop_data/bitmaps_reference/` for reference images.
- **Loki:** check `.loki/reference/` for reference images.

If no baselines are found locally and the runner is not Chromatic/Percy:

- Emit `pass_with_warnings` with note `"No visual baselines found — run once with update mode to create them."` and return.

### Step 3 — Run

Execute `qa_runner.command`. Capture stdout, stderr, and exit code.

- **Exit 0, no diffs reported** → verdict `pass`.
- **Exit 0, diffs below configured threshold** → verdict `pass` (note threshold in output).
- **Non-zero exit, visual diffs detected** → verdict `fail`; parse each diff into a finding.
- **Non-zero exit, runner crash / auth error (Chromatic/Percy)** → verdict `pass_with_warnings` with note `"QA runner failed to start — results unreliable."`.

### Step 4 — Parse failures

For each visual diff failure, extract:

- `file` — spec or story file that produced the diff (from runner output)
- `line` — line number if available, else `null`
- `rule` — test name / story name / snapshot name
- `message` — description of the diff (e.g. `"23.4% pixel difference exceeds 0.1% threshold"`)
- `repro` — command to re-run just this snapshot comparison
- artifact — path to the diff image (baseline vs actual comparison) produced by the runner, or the runner's report URL (Chromatic/Percy)

Findings conform to the canonical finding object (`../../../shared/refs/finding-schema.md`). `severity` is `high` for a diff exceeding threshold; `medium` if the diff is present but attribution or threshold configuration is uncertain. `evidence.file` carries the diff image path or report URL.

## Output

Envelope + finding shape per `_common.md`. Bucket fields: `runner` (`qa_runner.name`), `command`, `totals: { passed, failed, skipped }`. Findings: category/source `qa`; `evidence.file` carries the diff image path or report URL.

`fail` if any visual diff exceeds the configured threshold. `pass_with_warnings` if runner not found, no baselines, or runner crashed. `pass` if all snapshots match within threshold.