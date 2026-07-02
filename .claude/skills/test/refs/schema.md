# test — Schema reference

## Output JSON schema

```json
{
  "verdict": "pass" | "pass_with_warnings" | "fail" | "refused",
  "parallel": true | false,
  "prd": "<path>" | null,
  "eval_set_path": "<path to eval_set.json consumed>" | null,
  "buckets": {
    "unit":       { "verdict": "...", "runner": "...", "totals": {}, "findings": [] },
    "e2e":        { "verdict": "...", "runner": "...", "totals": {}, "findings": [] },
    "functional": { "verdict": "...", "evaluated": 0,  "findings": [] },
    "qa":         { "verdict": "...", "runner": "...", "totals": {}, "findings": [] },
    "load":       { "verdict": "...", "runner": "...", "totals": {}, "findings": [] },
    "a11y":       { "verdict": "...", "runner": "...", "totals": {}, "findings": [] },
    "perf":       { "verdict": "...", "runner": "...", "totals": {}, "findings": [] },
    "api":        { "verdict": "...", "runners": [], "commands": [], "totals": {}, "findings": [] },
    "mobile":     { "verdict": "...", "runner": "...", "matrix": [], "totals": {}, "findings": [] },
    "coverage":   { "verdict": "...", "runner": "...", "report_path": "...", "thresholds": {}, "totals": {}, "findings": [] }
  }
}
```

Skipped buckets (runner not detected, eval_set empty, mode-flag-excluded, or user-skipped) are **omitted** from the `buckets` object.

### Top-level fields

- `verdict` — overall verdict across all completed buckets.
- `parallel` — `true` for the default parallel subagent dispatch; `false` only when `--sequential` was used.
- `prd` — path to the PRD used for eval_set bootstrap, or `null` if not applicable.
- `eval_set_path` — path to the `eval_set.json` consumed (from `--eval-set` flag or `null`).

---

## Finding shape

Every finding produced by any bucket conforms to the **canonical finding object**
in `../../shared/refs/finding-schema.md` — the single source of truth shared with
`/review` and `/pre-merge`. Read that file for the full field reference, severity
enum, category enum, dedup/regression keys, and verdict normalization.

```json
{
  "id": "<bucket>-<n>",
  "source": "<bucket>",
  "severity": "blocker" | "high" | "medium" | "low",
  "category": "<bucket>",
  "rule": "<test name, assertion text, or rule-id>",
  "message": "<description of what failed or was observed>",
  "file": "<path or null>",
  "line": <number or null>,
  "evidence": {
    "tool": "<runner name>",
    "file": "<path or null>",
    "line": <number or null>,
    "snippet": "<exact runner output line>"
  },
  "suggestion": "<actionable fix or null>",
  "repro": "<command or script path to reproduce the failure, or null>",
  "regression_of": null
}
```

### Test specifics

- **`category`** is the bucket name (`unit`, `e2e`, `functional`, `qa`, `load`, `a11y`, `perf`, `api`, `mobile`, `coverage`).
- **`source`** is also the bucket name (`/test` has no semantic sub-agents).
- **`severity`** uses the canonical four-level scale. Map test outcomes: a hard
  test/assertion failure or non-zero runner exit → `blocker`; a reachable,
  diff-adjacent failure → `high`; a warning-class observation with unclear
  reachability → `medium`; informational / environment-only noise → `low`.
- **`rule`** is **required** — the failing test name, verbatim assertion text, or
  tool rule-id. It is the dedup/regression key downstream.
- **`evidence`** is the nested canonical object. `evidence.tool` is the runner;
  `evidence.snippet` carries the failure output. Buckets that produce artifacts
  (E2E screenshots/traces, Functional script output, QA diff images, A11y page
  screenshots) put the artifact path in `evidence.file`. Unit, Load, and Perf may
  leave `evidence.file` null (Perf uses `repro` to link the Lighthouse HTML report).
  When `/test --flaky <N>` is supplied, Unit and E2E findings that pass on retry
  add `evidence.flaky: true` and `evidence.retries: <n>`, and the bucket's `totals`
  gains a `flaky` count — see `refs/modes/unit.md` Step 3b / `refs/modes/e2e.md`
  Step 4b. Both are omitted when `--flaky` wasn't used.
- **`regression_of`** is `null` from buckets; the consuming gate sets it during aggregation.

`pass`-type results are NOT findings — they belong in `totals`/`evaluated`, never `findings[]`.

---

## Verdict semantics

| Verdict | Meaning | Action |
|---------|---------|--------|
| `fail` | One or more tests or assertions failed | Fix failing tests before merging |
| `pass_with_warnings` | No failures, but some buckets skipped or runners crashed | Review warnings; safe to proceed with awareness |
| `pass` | All attempted tests and assertions passed | Proceed |
| `refused` | User cancelled at the gate (Step 3) | No findings emitted |

Overall verdict = worst across completed buckets (`fail` > `pass_with_warnings` > `pass`).

These run-level verdicts map onto the shared three-state scale (`block`/`warn`/`pass`)
via the verdict-normalization table in `../../shared/refs/finding-schema.md`, so
`ship`/`preflight` can aggregate across `/review`, `/test`, and `/pre-merge`.

---

## eval_set.json shape (written by /review, consumed by /test)

```json
{
  "eval_set_source": "prd" | "tests" | "schemas" | "diff" | "mixed",
  "assertions": [
    { "text": "<assertion>", "class": "executable" | "intent" | "negative" }
  ]
}
```

`/test` reads only `executable`-classed assertions from this file. `intent` and `negative` assertions are owned by `/review` Functional mode and are not re-run here.

**Producer contract:** this shape is owned by `/review` — see `../review/refs/modes/functional.md` Step 1 ("Write eval_set.json") for the authoritative definition of the `class` enum and when each class is assigned. If that step changes the shape, this section must be updated to match.
