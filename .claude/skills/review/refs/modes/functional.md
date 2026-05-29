# review — Functional mode

**When it runs:** third in pipeline order — after Coverage, before Security.

**What it checks:** whether the changed code satisfies the acceptance criteria and test cases in `eval_set[]`.

## Execution

No `/cook` sub-agents. Functional is eval-set driven and must produce **evidence-backed** verdicts, not reasoning-only confidence.

### Step 0 — Tautology check

Read `eval_set_source` from the top-level run output (emitted by SKILL.md Step 3).

- `"prd"` or `"mixed"` — proceed normally.
- `"diff"` — the eval-set was bootstrapped from the same diff being reviewed; verdicts are circular by construction. Prepend a `warning` field to the mode output:
  ```
  "warning": "eval_set derived from diff — verdicts are circular by construction"
  ```
  Cap the mode verdict at `warn` regardless of per-assertion outcomes.

### Step 1 — Classify each assertion

For each entry in `eval_set[]`, assign one of three classes:

| Class | Definition | Example |
|-------|------------|---------|
| `executable` | Has concrete inputs and an observable outcome that a short script can check | `"POST /users with empty email returns 400"` |
| `intent` | Reasoning-only — concerns design, naming, structure, or invariants without a runnable check | `"Login flow uses the new session abstraction instead of the legacy cookie helper"` |
| `negative` | Asserts removal or absence | `"The legacy /auth/v1 endpoint is no longer reachable"` |

If the project has no runnable surface (pure type-level refactor, doc-only change, etc.), reclassify every `executable` candidate as `intent` and annotate the mode output with `"downgrade_reason": "no runnable surface"`.

Also tag each assertion `applicable: true | false`. An assertion is **applicable** when it concerns code touched by the diff or its direct dependencies (files importing or imported by changed files). Non-applicable assertions get verdict `n/a` and are excluded from the pass/warn/block tally.

### Step 2 — Read full file context

For every applicable assertion:

1. Identify the files in the diff that plausibly relate to the assertion.
2. **Read each such file in full** via `Read` — do not rely on diff hunks alone. Guards, validators, and conditionals frequently sit outside the hunk window.
3. **Widening rule:** when an assertion clearly spans a file boundary (e.g. "the controller rejects empty emails" but validation lives in a sibling validator module), read direct callers and callees of the changed symbols in full.

Diff-only inspection is forbidden for `pass` and `block` verdicts.

### Step 3 — Verify

**Executable assertions:**

1. Generate an ephemeral script under `/tmp/review-functional-<runid>/assertion-<n>.<ext>` that exercises the assertion. The script must:
   - Write nothing outside `/tmp/review-functional-<runid>/`.
   - Make no network calls unless the assertion concerns a network behavior.
   - Make no database writes; if state is needed, stand up an in-memory or temp-file fixture.
2. Run the script. Exit code `0` → `pass`. Non-zero → `block` if the failure attributes to the code under review; `warn` if the failure attributes to the test harness (missing dependency, fixture setup error, etc.).
3. Locate the satisfying or violating code in the file(s) read in Step 2 and record `file` + `line`.

**Intent assertions:** reason from the fully-read files. Locate the satisfying or violating code and record `file` + `line`.

**Negative assertions** (evidence = absence):

1. Search the diff for *additions* matching the prohibited pattern. Any hit → `block`. Record `file` + `line` of the addition.
2. Search the post-change file(s) for *any remaining instance* of the prohibited pattern. Any hit → `warn`. Record `file` + `line`.
3. No hits → `pass`. Evidence message: `"absence verified"`; list the files searched in the finding's `message`.

### Verdict rubric

| Verdict | Rule | Example |
|---------|------|---------|
| `pass` | Assertion satisfied AND evidence (`file` + `line`) located | `"empty-email rejection"` — validator at `api/users.ts:42` returns 400 for `email === ""` |
| `warn` | One of: (a) happy path implemented but error/edge path missing; (b) implementation present but intent unclear from code; (c) executable assertion failed in a way attributable to the test harness, not the code | (a) success branch handles new field but the error branch still returns the old shape |
| `block` | Assertion clearly violated OR required behavior absent | `"reject duplicate signup"` — code path proceeds without uniqueness check |
| `n/a` | Assertion does not apply to the changed surface | Assertion concerns billing; diff only touches auth |

### Self-check: mandatory evidence

Every `pass` and `block` finding **must** populate `file` and `line` with the location of the satisfying or violating code. `null` for `file`/`line` is permitted **only** on `n/a` entries.

After producing all per-assertion verdicts, sweep the findings list:
- Any `pass` with `file: null` or `line: null` → downgrade to `warn` with reason `"no evidence located"`.
- Any `block` with `file: null` or `line: null` → downgrade to `warn` with reason `"no evidence located"`.

## Output

```json
{
  "verdict": "pass" | "warn" | "block",
  "warning": "<optional — present only when eval_set_source == 'diff'>",
  "downgrade_reason": "<optional — present only when executables were reclassified>",
  "evaluated": <number of applicable assertions>,
  "n_a": <number of non-applicable assertions>,
  "findings": [
    {
      "source": "functional",
      "assertion": "<eval_set entry>",
      "class": "executable" | "intent" | "negative",
      "applicable": true | false,
      "file": "<path or null>",
      "line": <number or null>,
      "severity": "block" | "warn" | "info",
      "message": "<why this assertion fails, is ambiguous, or — for negative pass — 'absence verified' plus files searched>",
      "suggestion": "<what needs to change>"
    }
  ]
}
```

Emit findings for every assertion that is `warn`, `block`, or `n/a`. `pass` assertions produce no finding entry (but are counted in `evaluated`).