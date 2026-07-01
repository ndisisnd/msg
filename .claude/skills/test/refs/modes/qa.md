# test — QA / Visual bucket

**When it runs:** fourth bucket — after Functional (sequential), or concurrently with other buckets (`--fast`).

**What it checks:** visual regressions by comparing screenshots or component renders against stored baselines.

## Execution

Reads `qa_runner` from the Step 1 fingerprint — does not re-detect.

### Step 1 — Guard

If `qa_runner` is `null`: emit `pass_with_warnings` with note `"No visual testing runner detected — QA bucket skipped."` and return immediately.

Recognised runners (detection order):

| Runner | Detection signal | Default command |
|--------|-----------------|-----------------|
| Playwright visual | `playwright.config.*` + snapshot dirs (`__screenshots__`, `*.png` baselines) | `npx playwright test --update-snapshots=false` |
| Chromatic | `chromatic` in `package.json` scripts or devDeps | `npx chromatic --exit-zero-on-changes=false` |
| Percy | `@percy/cli` in devDeps or `.percy.yml` | `npx percy exec -- <e2e_runner.command>` |
| BackstopJS | `backstop.json` or `backstopjs` in devDeps | `npx backstop test` |
| Loki | `loki` in `package.json` scripts or devDeps | `npx loki test` |

Use the first match found.

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

```json
{
  "verdict": "pass" | "pass_with_warnings" | "fail",
  "bucket": "qa",
  "runner": "<qa_runner.name>",
  "command": "<command executed>",
  "totals": { "passed": 0, "failed": 0, "skipped": 0 },
  "findings": [
    {
      "id": "qa-<n>",
      "source": "qa",
      "severity": "high" | "medium",
      "category": "qa",
      "file": "<spec or story file path, or null>",
      "line": null,
      "rule": "<snapshot or story name>",
      "message": "<diff description>",
      "evidence": {
        "tool": "<qa_runner.name>",
        "file": "<diff image path or report URL, or null>",
        "line": null,
        "snippet": "<diff description>"
      },
      "suggestion": null,
      "repro": "<re-run command or null>",
      "regression_of": null
    }
  ]
}
```

`fail` if any visual diff exceeds the configured threshold. `pass_with_warnings` if runner not found, no baselines, or runner crashed. `pass` if all snapshots match within threshold.