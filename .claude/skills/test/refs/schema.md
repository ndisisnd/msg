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
    "api":        { "verdict": "...", "runners": [], "commands": [], "totals": {}, "findings": [] }
  }
}
```

Skipped buckets (runner not detected, eval_set empty, mode-flag-excluded, or user-skipped) are **omitted** from the `buckets` object.

### Top-level fields

- `verdict` — overall verdict across all completed buckets.
- `parallel` — `true` if `--fast` was used, `false` otherwise.
- `prd` — path to the PRD used for eval_set bootstrap, or `null` if not applicable.
- `eval_set_path` — path to the `eval_set.json` consumed (from `--eval-set` flag or `null`).

---

## Finding shape

Every finding produced by any bucket conforms to:

```json
{
  "id": "<bucket>-<n>",
  "severity": "fail" | "warn",
  "file": "<path or null>",
  "line": <number or null>,
  "rule": "<test name, assertion text, or rule-id>",
  "message": "<description of what failed or was observed>",
  "suggestion": "<actionable fix or null>",
  "repro": "<command or script path to reproduce the failure, or null>",
  "evidence": "<path to screenshot, trace, or coverage artifact, or null>"
}
```

`evidence` is bucket-specific: populated by E2E (screenshots/traces), Functional (script output files), QA (diff images, baseline vs actual screenshots), and A11y (page screenshot at time of audit); omitted or `null` for Unit, Load, and Perf (Perf uses `repro` to link to the Lighthouse HTML report instead).

---

## Verdict semantics

| Verdict | Meaning | Action |
|---------|---------|--------|
| `fail` | One or more tests or assertions failed | Fix failing tests before merging |
| `pass_with_warnings` | No failures, but some buckets skipped or runners crashed | Review warnings; safe to proceed with awareness |
| `pass` | All attempted tests and assertions passed | Proceed |
| `refused` | User cancelled at the gate (Step 3) | No findings emitted |

Overall verdict = worst across completed buckets (`fail` > `pass_with_warnings` > `pass`).

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
