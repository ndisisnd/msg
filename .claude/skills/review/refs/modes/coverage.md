# review — Coverage mode

**When it runs:** second in pipeline order — after Quality, before Functional.

**What it checks:** whether changed lines are exercised by existing tests. Produces a gap report against `eval_set[]`.

## Execution

No `/cook` sub-agents. Coverage is test-runner driven.

Reads `test_runner` from the Step 2 fingerprint — does not re-detect.

1. **Guard** — if `test_runner` is `null`: emit `warn` with note `"No test runner detected — coverage skipped."` and return immediately. Do not run tests.
2. **Run** — execute `test_runner.command` with `<files>` replaced by the space-separated list of changed file paths from the diff. Capture stdout + stderr. If the command exits non-zero and stderr contains a crash trace (not a test failure): emit `warn` with note `"Test runner crashed — coverage unreliable."` and return. Do not treat a crash exit as a coverage gap.
3. **Parse** — read `test_runner.coverage_output`. If the file is absent after a successful run, emit `warn` with note `"Coverage output not found at <path>."` and return.
4. **Cross-reference** — compare covered lines against `eval_set[]`: identify assertions with no corresponding test exercising the relevant changed lines.

## Output

```json
{
  "verdict": "pass" | "warn" | "block",
  "gaps": [
    { "assertion": "<eval_set entry>", "file": "<path>", "lines": "<range>", "note": "<why uncovered>" }
  ]
}
```

`block` if critical paths in the diff have zero test coverage. `warn` if coverage gaps exist but are non-critical. `pass` if all changed lines are exercised.
