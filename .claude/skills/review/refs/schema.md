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
      "category": "<category>",
      "message": "<description>",
      "suggestion": "<actionable fix>"
    }
  ]
}
```

`source` identifies the producer of the finding. `/review` reads this object mechanically — it does not parse free-form text. Valid forms:

| Form | Producer | Emitted by |
|------|----------|------------|
| `--<flag>` (e.g. `--api-design`, `--react:security`) | A `/cook` semantic sub-agent | Any mode's semantic stage |
| `lint:<runner>` (e.g. `lint:eslint`, `lint:ruff`) | A lint runner in Quality Stage 0 | Quality mode |
| `format:<runner>` (e.g. `format:prettier`, `format:black`, `format:dart-format`) | A format runner in Quality Stage 0 | Quality mode |
| `typecheck:<runner>` (e.g. `typecheck:tsc`, `typecheck:mypy`, `typecheck:dart-analyze`) | A typecheck runner in Quality Stage 0 | Quality mode |
| `env:<runner>` (e.g. `env:eslint`) | A configured-but-not-executable runner in Quality Stage 0 | Quality mode |
| `secrets:<scanner>` (e.g. `secrets:gitleaks`, `secrets:trufflehog`) | A secret scanner in Security Stage 0 | Security mode |

After the dedup pass, a finding's `source` may be a comma-separated concatenation of any of the forms above (e.g. `"--api-design,--architecture"` or `"lint:eslint,--react"`).

`category` is **required** on every finding. Recommended enum:
`"contract"`, `"architecture"`, `"error-handling"`, `"debug"`, `"dead-code"`, `"duplication"`, `"readability"`, `"naming"`, `"complexity"`, `"scope-creep"`, `"security"`, `"performance"`, `"other"`.

### Orchestrator dedup pass

After collecting all sub-agent outputs for a mode, `/review` applies a deduplication pass before aggregating verdicts. Findings sharing `(file, line, category)` are collapsed into a single entry:
- **Severity:** keep the highest (`block` > `warn` > `info`).
- **Source:** concatenate distinct `source` values into a comma-separated string on the surviving finding (e.g. `"--api-design,--architecture"`).
- All other fields are taken from the highest-severity entry.

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

## Fingerprint object (Step 2 outputs)

Step 2 of `SKILL.md` produces these structures, consumed downstream by Step 4 (surface assembly) and Step 6 (mode execution):

```json
{
  "active_domains": ["<domain>"],
  "test_runner": {
    "name": "<runner>",
    "command": "<command with <files> placeholder>",
    "coverage_output": "<relative path>",
    "ci_override": true | false
  } | null,
  "mechanical_runners": [
    {
      "name": "<runner>",
      "command": "<command with <files> placeholder>",
      "expects_zero_exit": true,
      "severity_on_fail": "warn" | "block"
    }
  ],
  "secret_scanner": {
    "name": "<scanner>",
    "command": "<diff-mode command with <files> placeholder>",
    "full_tree_command": "<command for --full-secret-scan>",
    "expects_zero_exit": true,
    "severity_on_fail": "block"
  } | null,
  "flag_inventory": ["<flag>"]
}
```

- `mechanical_runners[]` is the empty list when no lint/format/typecheck runner is detected — Quality mode Stage 0 becomes a no-op.
- `secret_scanner` is `null` when no scanner is detected — Security mode Stage 0 emits a single `warn` finding and proceeds.
- Detection signals and per-runner severity assignments live in `refs/FLAG-LIST.md`.

---

## Verdict semantics

| Verdict | Meaning | Pipeline effect |
|---------|---------|----------------|
| `block` | At least one mode returned `block` | Stop after blocking mode; skip remaining modes |
| `warn` | No blocks; at least one `warn` | Continue; warnings surface in PR summary |
| `pass` | All modes `pass` | Continue silently |

Overall verdict = worst across all completed modes.
