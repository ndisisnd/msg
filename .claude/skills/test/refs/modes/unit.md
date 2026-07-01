# test — Unit / Integration bucket

**When it runs:** first bucket — before E2E and Functional.

**What it checks:** all unit and integration tests reachable by the detected test runner.

## Execution

Reads `test_runner` from the Step 1 fingerprint — does not re-detect.

### Step 1 — Guard

If `test_runner` is `null`: emit `pass_with_warnings` with note `"No test runner detected — unit/integration bucket skipped."` and return immediately.

### Step 2 — Scope

If `--base <branch>` was supplied, resolve the changed source file list (source files only — not test files themselves, since the runner will find associated tests), then substitute `<files>`/`<file>` in `test_runner.command` per-runner — each runner expects a different format, not a plain space-separated path list:

| Runner | `<files>` placeholder expects | Example substitution |
|--------|-------------------------------|-----------------------|
| Vitest | space-separated file/glob paths (positional args) | `npx vitest run --coverage src/auth.ts src/user.ts` |
| Jest | a single regex, not literal paths — join changed paths with `\|` and escape regex metacharacters | `npx jest --coverage --testPathPattern="(src/auth\.ts\|src/user\.ts)"` |
| Mocha | space-separated file paths (positional args) | `npx nyc npx mocha src/auth.ts src/user.ts` |
| pytest | `--cov=<files>` in the detected command sets the **coverage measurement scope**, not the test selection — it does NOT filter which tests run. To actually scope execution, append changed test file paths or `::`-qualified nodeids as trailing positional args instead of touching `--cov=`; leave `--cov=<files>` as `--cov=.` (or drop `--base` scoping for pytest and run the full suite) until the detect script is fixed to separate the two concerns. |
| Dart/Flutter | the placeholder is singular `<file>` — pass one path per `flutter test` invocation, or a single shared parent directory if all changed files share one; do not join multiple paths with spaces into one `<file>` slot |

If a runner isn't listed above, or the changed-file mapping is ambiguous (e.g. more files than the runner's arg limit, or no reliable file→test mapping), fall back to the full suite rather than guessing at syntax.

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

Findings conform to the canonical finding object (`../../../shared/refs/finding-schema.md`). `severity` is `high` for a straightforward test failure attributable to the code under test; `medium` when attribution is unclear (e.g. the failure looks flaky, or is adjacent to a harness/fixture issue rather than the assertion itself). `evidence.tool` is the runner name; `evidence.snippet` carries the runner's failure output line.

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
      "source": "unit",
      "severity": "high" | "medium",
      "category": "unit",
      "file": "<test file path or null>",
      "line": <number or null>,
      "rule": "<test description>",
      "message": "<failure message>",
      "evidence": {
        "tool": "<test_runner.name>",
        "file": "<test file path or null>",
        "line": <number or null>,
        "snippet": "<runner failure output line>"
      },
      "suggestion": null,
      "repro": "<re-run command or null>",
      "regression_of": null
    }
  ]
}
```

`fail` if any test failed (non-crash). `pass_with_warnings` if runner not found or crashed. `pass` if all tests pass.
