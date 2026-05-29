# review — Coverage mode

**When it runs:** second in pipeline order — after Quality, before Functional.

**What it checks:** whether changed source files have sibling test counterparts and whether eval_set assertions are referenced in nearby test files. Static analysis only — no test execution.

## Execution

No `/cook` sub-agents. No test runner execution. Coverage uses static file-existence detection and text-search only.

Does NOT read `test_runner` from the Step 2 fingerprint — that field is no longer produced by Step 2.

### Step 1 — Sibling-test check

For each source file changed in the diff (excluding test files themselves), verify that at least one sibling test file exists:

- Same basename with `.test.<ext>` or `.spec.<ext>` suffix (e.g. `auth.ts` → `auth.test.ts`, `auth.spec.ts`)
- Matching path under an `__tests__/` directory (e.g. `src/auth.ts` → `src/__tests__/auth.ts` or `__tests__/auth.ts`)

Use `rtk find` to check existence. A changed file with no sibling test file is a **missing-test gap**.

Classify the changed file as *critical* if it contains business logic — not pure type declarations, configuration, or test utilities. Only critical files produce `block`-severity gaps.

### Step 2 — Assertion-reference check

For each assertion in `eval_set[]`, scan the sibling test file(s) located in Step 1 and any test files present in the diff:

- Match if the assertion text (or a significant substring of ≥ 5 consecutive words) appears in a test description string (`it(...)`, `test(...)`, `describe(...)` argument)
- Match if the assertion's key domain terms (nouns + verbs) appear as a cluster in the test file body

An assertion with no match in any reachable test file is an **assertion gap** (`warn`).

### Step 3 — Classify gaps and emit verdict

| Condition | Verdict |
|-----------|---------|
| One or more critical source files have no sibling test file | `block` |
| All critical files have test files, but some eval_set assertions are unmatched | `warn` |
| Non-critical files lack test files (no critical gaps, no assertion gaps) | `warn` |
| All changed files have test coverage and all eval_set assertions are referenced | `pass` |

## Output

```json
{
  "verdict": "pass" | "warn" | "block",
  "gaps": [
    {
      "assertion": "<eval_set entry, or null for file-level gaps>",
      "file": "<changed source file>",
      "lines": "<changed line range, or null>",
      "note": "<reason: 'no sibling test file' | 'assertion not referenced in tests' | 'non-critical file has no sibling test'>"
    }
  ]
}
```

`block` if one or more critical changed files have no sibling test file. `warn` for non-critical missing tests or unmatched assertions. `pass` if all changed files have test coverage and all eval_set assertions are referenced in tests.