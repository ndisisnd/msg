# review — Functional mode

**When it runs:** third in pipeline order — after Coverage, before Security.

**What it checks:** whether the changed code satisfies the acceptance criteria and test cases in `eval_set[]`.

## Execution

No `/cook` sub-agents. Functional is eval-set driven and must produce **evidence-backed** verdicts, not reasoning-only confidence.

Executable assertions (class `executable`) are **deferred** to `/test` — Functional mode emits `n/a` for them rather than generating and running ephemeral scripts. Only `intent` and `negative` assertions receive a definitive verdict here.

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

**Write eval_set.json** — after classifying all assertions, write the following to `eval_set_path` (derived in SKILL.md Step 3):

```json
{
  "eval_set_source": "<value from SKILL.md Step 3>",
  "assertions": [
    { "text": "<assertion>", "class": "executable" | "intent" | "negative" }
  ]
}
```

If `eval_set_path` is `null` (no PRD known), skip the write.

### Step 2 — Read full file context

For every applicable `intent` or `negative` assertion (executable assertions are deferred and do not require file reads):

1. Identify the files in the diff that plausibly relate to the assertion.
2. **Read each such file in full** via `Read` — do not rely on diff hunks alone. Guards, validators, and conditionals frequently sit outside the hunk window.
3. **Widening rule:** when an assertion clearly spans a file boundary (e.g. "the controller rejects empty emails" but validation lives in a sibling validator module), read direct callers and callees of the changed symbols in full.

Diff-only inspection is forbidden for `pass` and `block` verdicts.

### Step 3 — Verify

**Executable assertions:**

Emit `n/a` for every applicable executable assertion. These assertions require a running project environment and are deferred to `/test`. For each, produce a finding with:

- `severity`: omitted (n/a entries have no severity)
- `applicable`: `true` (the assertion targets code in the diff — it is deferred, not irrelevant)
- `class`: `executable`
- `message`: `"executable — run /test --eval-set <eval_set_path> for verification"` (where `<eval_set_path>` is the path derived in SKILL.md Step 3; if `eval_set_path` is `null`, use `"executable — run /test for verification"`)
- `file`: `null`
- `line`: `null`

Increment `n_a` for each deferred executable assertion.

**Intent assertions:** reason from the fully-read files. Locate the satisfying or violating code and record `file` + `line`.

**Negative assertions** (evidence = absence):

1. Search the diff for *additions* matching the prohibited pattern. Any hit → `block`. Record `file` + `line` of the addition.
2. Search the post-change file(s) for *any remaining instance* of the prohibited pattern. Any hit → `warn`. Record `file` + `line`.
3. No hits → `pass`. Evidence message: `"absence verified"`; list the files searched in the finding's `message`.

### Step 3.5 — All-deferred check

After processing all assertions, if every applicable assertion produced `n/a` (i.e. `evaluated == 0`):
- Set mode verdict to `warn` (never `pass`).
- Add `"deferred_note": "all assertions deferred to /test"` to the mode output.

### Verdict rubric

| Verdict | Rule | Example |
|---------|------|---------|
| `pass` | Assertion satisfied AND evidence (`file` + `line`) located | `"empty-email rejection"` — validator at `api/users.ts:42` returns 400 for `email === ""` |
| `warn` | One of: (a) happy path implemented but error/edge path missing; (b) implementation present but intent unclear from code | (a) success branch handles new field but the error branch still returns the old shape |
| `block` | Assertion clearly violated OR required behavior absent | `"reject duplicate signup"` — code path proceeds without uniqueness check |
| `n/a` | Assertion does not apply to the changed surface, OR assertion is `executable` (deferred to `/test`) | Assertion concerns billing; diff only touches auth — OR — assertion has concrete I/O that needs a running server |

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
  "downgrade_reason": "<optional — present only when executables were reclassified to intent>",
  "deferred_note": "<optional — 'all assertions deferred to /test' when evaluated == 0>",
  "evaluated": <number of applicable assertions with definitive verdict>,
  "n_a": <number of n/a assertions — non-applicable + deferred executable>,
  "findings": [
    {
      "source": "functional",
      "assertion": "<eval_set entry>",
      "class": "executable" | "intent" | "negative",
      "applicable": true | false,
      "file": "<path or null>",
      "line": <number or null>,
      "severity": "block" | "warn" | "info",
      "message": "<why this assertion fails, is ambiguous, or — for negative pass — 'absence verified' plus files searched; for executable n/a — '/test referral note'>",
      "suggestion": "<what needs to change>"
    }
  ]
}
```

Emit findings for every assertion that is `warn`, `block`, `n/a`, or deferred executable. `pass` assertions produce no finding entry (but are counted in `evaluated`).