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

## Output

```json
{
  "verdict": "pass" | "pass_with_warnings" | "fail",
  "bucket": "e2e",
  "runner": "<e2e_runner.name>",
  "command": "<command executed>",
  "totals": { "passed": 0, "failed": 0, "skipped": 0 },
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
        "spec": "<spec file path>"
      },
      "suggestion": null,
      "repro": "<re-run command or null>",
      "regression_of": null
    }
  ]
}
```

`fail` if any e2e test failed (non-crash). `pass_with_warnings` if runner not found or crashed. `pass` if all tests pass.