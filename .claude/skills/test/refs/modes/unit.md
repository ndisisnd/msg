# test — Unit / Integration bucket

**When it runs:** first bucket — before E2E and Functional.

**What it checks:** all unit and integration tests reachable by the detected test runner.

## Execution

Reads `test_runner` from the Step 1 fingerprint — does not re-detect.

### Step 1 — Guard

If `test_runner` is `null`: emit `pass_with_warnings` with note `"No test runner detected — unit/integration bucket skipped."` and return immediately.

### Step 2 — Scope

If `--base <branch>` was supplied: replace `<files>` in `test_runner.command` with the space-separated list of changed file paths (source files only — not test files themselves, since the runner will find associated tests).

If no `--base` flag: use `test_runner.command` without a file filter (full suite run).

### Step 3 — Run

Execute the scoped command. Capture stdout, stderr, and exit code.

- **Exit 0, no failures in output** → verdict `pass`.
- **Exit 0 with skipped/pending tests** → verdict `pass_with_warnings`; note skipped count.
- **Non-zero exit, output contains test failure(s)** → verdict `fail`; parse failures into findings.
- **Non-zero exit, stderr contains a crash trace (not test failures)** → verdict `pass_with_warnings` with note `"Test runner crashed — results unreliable."`. Do not treat a crash as a test failure.

### Step 4 — Parse failures

For each test failure in the output, extract:

- `file` — test file path (from runner output or stack trace)
- `line` — line number of the failing assertion (from runner output if available, else `null`)
- `rule` — test name / description string
- `message` — failure message from the runner
- `repro` — the command used to re-run just this test (if the runner supports `--testNamePattern` or equivalent)

## Output

```json
{
  "verdict": "pass" | "pass_with_warnings" | "fail",
  "bucket": "unit",
  "runner": "<test_runner.name>",
  "command": "<command executed>",
  "totals": { "passed": 0, "failed": 0, "skipped": 0 },
  "findings": [
    {
      "id": "unit-<n>",
      "severity": "fail" | "warn",
      "file": "<test file path or null>",
      "line": <number or null>,
      "rule": "<test description>",
      "message": "<failure message>",
      "repro": "<re-run command or null>"
    }
  ]
}
```

`fail` if any test failed (non-crash). `pass_with_warnings` if runner not found or crashed. `pass` if all tests pass.
