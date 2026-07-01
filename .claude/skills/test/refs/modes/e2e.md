# test — E2E bucket

**When it runs:** second bucket — after Unit/Integration, before Functional.

**What it checks:** end-to-end tests via the detected e2e runner.

## Execution

Reads `e2e_runner` from the Step 1 fingerprint — does not re-detect.

### Step 1 — Guard

If `e2e_runner` is `null`: emit `pass_with_warnings` with note `"No e2e runner detected — E2E bucket skipped."` and return immediately.

### Step 2 — Scope

Construct the run command from `e2e_runner.command`:

- If `--base <branch>` was supplied and the runner supports spec-path filtering (Playwright: `--grep`, Cypress: `--spec`), attempt to map changed source files to e2e spec files by name convention (e.g. `auth.ts` → `e2e/auth.spec.ts`) and append the filter. **This is a best-effort heuristic, not a reliable protocol** — the detect script's `e2e_runner.command` carries no `<files>`/`<spec>` placeholder, so the mapping is entirely name-guessed here. It will miss specs that don't follow a 1:1 source↔spec naming convention (grouped specs, feature-based spec files, renamed modules) more often than it hits in real repos.
- If no scoping is possible (no `--base` flag, no matching spec files found, or the guessed mapping can't be verified to exist on disk), run the full e2e suite — do not run a guessed filter that resolves to zero matched spec files silently as if it were a deliberate empty scope.

### Step 3 — Run

Execute the command. Capture stdout, stderr, and exit code.

- **Exit 0** → verdict `pass` (or `pass_with_warnings` if any tests were skipped).
- **Non-zero exit, output contains test failure(s)** → verdict `fail`; parse failures into findings.
- **Non-zero exit, stderr contains a crash trace / startup error** → verdict `pass_with_warnings` with note `"E2E runner failed to start — results unreliable."`. Include the error in `message`.

### Step 4 — Parse failures

For each e2e test failure:

- `file` — spec file path (from runner output)
- `line` — line number of the failing step (from runner output if available, else `null`)
- `rule` — test title / `describe + it` path
- `message` — failure message and first relevant stack line
- `repro` — command to re-run just this spec (e.g. `npx playwright test e2e/auth.spec.ts`)
- artifact path — screenshot or trace path if the runner produced one, else `null`

Findings conform to the canonical finding object (`../../../shared/refs/finding-schema.md`). `severity` is `high` for a named spec failure (matches the pre-merge severity floor for e2e); `medium` when attribution is unclear. `evidence.file` carries the screenshot/trace artifact path (`null` if none produced); the shared schema sanctions e2e adding `evidence.spec` for the spec file path alongside the top-level `file`.

### Step 4b — Flaky retry (`--flaky <N>` only)

Runs only when `--flaky <N>` was supplied and Step 3 produced at least one spec failure.

For each individually-failing spec that has a `repro` command (e.g. `npx playwright test e2e/auth.spec.ts`), re-run just that spec, up to `N` times, stopping as soon as it passes. Specs with no derivable single-spec `repro` are skipped by this step and stay classified as regular failures — note `"Flaky retry skipped for <n> spec(s) — no single-spec repro available"` when this happens.

- **Passes within `N` retries** → reclassify as **flaky**: keep the finding in `findings[]` for visibility, set `severity: "medium"`, and add `evidence.flaky: true` and `evidence.retries: <attempts used>` (alongside the existing `evidence.spec`). Do not count it toward `totals.failed`; instead increment `totals.flaky`.
- **Still fails after `N` retries** → genuine failure: unchanged from Step 4 (`severity: "high"`, counts toward `totals.failed`).

Recompute the bucket verdict after retries: `fail` only if at least one spec is still failing after exhausting its retries. If every originally-failing spec resolved as flaky, verdict is `pass_with_warnings` with note `"<n> flaky spec(s) passed on retry"`.

## Output

```json
{
  "verdict": "pass" | "pass_with_warnings" | "fail",
  "bucket": "e2e",
  "runner": "<e2e_runner.name>",
  "command": "<command executed>",
  "totals": { "passed": 0, "failed": 0, "skipped": 0, "flaky": 0 },
  "findings": [
    {
      "id": "e2e-<n>",
      "source": "e2e",
      "severity": "high" | "medium",
      "category": "e2e",
      "file": "<spec file path or null>",
      "line": <number or null>,
      "rule": "<test title>",
      "message": "<failure message>",
      "evidence": {
        "tool": "<e2e_runner.name>",
        "file": "<screenshot or trace path, or null>",
        "line": <number or null>,
        "snippet": "<failure message and first relevant stack line>",
        "spec": "<spec file path>",
        "flaky": true,
        "retries": 1
      },
      "suggestion": null,
      "repro": "<re-run command or null>",
      "regression_of": null
    }
  ]
}
```

`totals.flaky` and `evidence.flaky`/`evidence.retries` are only populated when `--flaky <N>` was supplied; omit them otherwise rather than emitting zeros/`false` on every finding.

`fail` if any e2e test failed (non-crash) after exhausting retries (or immediately, when `--flaky` wasn't supplied). `pass_with_warnings` if runner not found, crashed, or all failures resolved as flaky. `pass` if all tests pass.