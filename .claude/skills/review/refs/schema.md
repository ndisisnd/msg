# review — Schema reference

## Sub-skill interface contract

Each `/cook --<flag>` sub-agent called by `/review` must conform to:

**Input:** `diff` (string — git diff output) + files scoped to its domain.

**Output:**
```json
{
  "verdict": "pass" | "warn" | "block",
  "findings": [
    {
      "source": "<flag>",
      "file": "<path>",
      "line": <number>,
      "rule": "<rule-id>",
      "severity": "block" | "warn" | "info",
      "message": "<description>",
      "suggestion": "<actionable fix>"
    }
  ]
}
```

`source` identifies the `/cook --<flag>` agent that produced the finding. `/review` reads this object mechanically — it does not parse free-form text.

---

## Output JSON schema

```json
{
  "verdict": "pass" | "warn" | "block",
  "prd": "<path>" | null,
  "eval_set": [ "<assertion string>" ],
  "eval_set_source": "prd" | "tests" | "schemas" | "diff" | "mixed",
  "surface": {
    "files_changed": [ "<path>" ],
    "prd_rows_covered": [ "<row-id>" ],
    "uncovered_changes": [ "<path or description>" ],
    "modes": [
      { "mode": "<mode-name>", "flags": [ "<flag>" ] }
    ]
  },
  "modes": {
    "quality":     { "verdict": "...", "findings": [] },
    "coverage":    { "verdict": "...", "gaps": [] },
    "functional":  { "verdict": "...", "evaluated": 0, "n_a": 0, "findings": [] },
    "security":    { "verdict": "...", "findings": [] },
    "performance": { "verdict": "...", "findings": [] }
  }
}
```

Unrun modes (pipeline stopped by `block`) are **omitted** from the `modes` object — not included as empty objects.

### Top-level fields

- `eval_set_source` — provenance of the assertions in `eval_set[]`:
  - `"prd"` — every assertion came from PRD sections.
  - `"tests"` — every assertion came from test files (in-diff or co-located).
  - `"schemas"` — every assertion came from `schemas.json` of a prior `agent-audit` run.
  - `"diff"` — generated from the diff because no other source produced results.
  - `"mixed"` — two or more of the above sources contributed.

  Functional mode reads this and downgrades its verdict to `warn` only when value is `"diff"` (diff-derived assertions are circular by construction; PRD/tests/schemas sources are authoritative and do not trigger a downgrade).

### Functional mode fields

- `evaluated` — count of applicable assertions (verdict ∈ {`pass`, `warn`, `block`}).
- `n_a` — count of non-applicable assertions (assertion concerns a surface untouched by the diff or its direct dependencies).
- Each finding gains an `applicable: bool` field. Non-applicable assertions emit findings with `applicable: false` and verdict `n/a`.

### Mandatory evidence rule (Functional)

Every Functional finding with severity `pass` or `block` MUST populate `file` and `line` with the location of the satisfying or violating code. `null` is permitted only on `n/a` entries. Functional mode self-checks and downgrades any `pass` or `block` lacking evidence to `warn` with reason `"no evidence located"`.

---

## Verdict semantics

| Verdict | Meaning | Pipeline effect |
|---------|---------|----------------|
| `block` | At least one mode returned `block` | Stop after blocking mode; skip remaining modes |
| `warn` | No blocks; at least one `warn` | Continue; warnings surface in PR summary |
| `pass` | All modes `pass` | Continue silently |

Overall verdict = worst across all completed modes.
