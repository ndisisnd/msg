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

Skip every assertion classed `executable` (classification happens once in `SKILL.md` Step 3, before Coverage runs). Executable assertions are deferred to `/test --eval-set`, which will verify them directly — a static text-match here would only produce false gaps against a check that hasn't run yet. Only `intent` and `negative` assertions are eligible for an assertion-gap in this step.

For each remaining (`intent`/`negative`) assertion in `eval_set[]`, scan the sibling test file(s) located in Step 1 and any test files present in the diff:

- Match if the assertion text (or a significant substring of ≥ 5 consecutive words) appears in a test description string (`it(...)`, `test(...)`, `describe(...)` argument)
- Match if the assertion's key domain terms (nouns + verbs) appear as a cluster in the test file body

An `intent`/`negative` assertion with no match in any reachable test file is an **assertion gap** (`warn`).

### Step 3 — Classify gaps and emit verdict

| Condition | Verdict | `sub-verdict` |
|-----------|---------|---------------|
| One or more critical source files have no sibling test file | `block` | `convention` |
| All critical files have test files, but some eval_set assertions are unmatched | `warn` | — |
| Non-critical files lack test files (no critical gaps, no assertion gaps) | `warn` | — |
| All changed files have test coverage and all eval_set assertions are referenced | `pass` | — |

**Why the `block` here is `sub-verdict: convention`, not `behavior`.** Coverage is
static-only (Step 0 note) — it never executes a test, so it can never observe that
behaviour is *wrong*, only that a dedicated sibling test file is *absent*. A critical
file that is exercised indirectly (through a consumer's test file) still trips this
`block` because no file matches the sibling-name patterns in Step 1 — yet every
functional/security/a11y check may have passed clean. Tagging the block
`sub-verdict: convention` tells a reader "add a dedicated test file," not "something is
broken." The `sub-verdict: behavior` value is reserved for a genuine behavioural
coverage failure (a test that ran and disproved required behaviour); Coverage mode
does not execute tests, so it never emits `behavior` — that signal is owned by `/test`.
`sub-verdict` is present **only** on a `block` verdict; `warn`/`pass` omit it.

## Output

```json
{
  "verdict": "pass" | "warn" | "block",
  "sub-verdict": "convention" | "behavior",
  "gaps": [
    {
      "assertion": "<eval_set entry, or null for file-level gaps>",
      "file": "<changed source file>",
      "lines": "<changed line range, or null>",
      "sub-verdict": "convention" | "behavior" | null,
      "note": "<reason: 'no sibling test file' | 'assertion not referenced in tests' | 'non-critical file has no sibling test'>"
    }
  ]
}
```

- Top-level `sub-verdict` is present **only** when `verdict` is `block`; omit it (or set `null`) for `warn`/`pass`.
- A missing-sibling-test `block` sets both the top-level and the per-gap `sub-verdict` to `convention` — the critical file may be tested indirectly through a consumer's test file; the block means "add a dedicated test file," not "behaviour is broken."
- `sub-verdict: behavior` is reserved for a block raised by a test that ran and disproved required behaviour. Coverage is static-only and never executes tests, so it never emits `behavior`; that signal is owned by `/test`.
- Per-gap `sub-verdict` is `null` on any gap that is not itself the cause of a `block` (assertion gaps, non-critical missing-test gaps).

`block` if one or more critical changed files have no sibling test file (always `sub-verdict: convention`). `warn` for non-critical missing tests or unmatched assertions. `pass` if all changed files have test coverage and all eval_set assertions are referenced in tests.