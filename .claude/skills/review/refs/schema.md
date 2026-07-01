# review — Schema reference

Findings conform to the **canonical finding object** in
`../../shared/refs/finding-schema.md` — the single source of truth shared with
`/test` and `/pre-merge`. Read that file for the full field reference, severity
enum, category enum, dedup/regression keys, and verdict normalization. This file
records `/review`'s specifics: the sub-skill contract, the `source` taxonomy, the
dedup pass, and the output JSON envelope.

## Sub-skill interface contract

Each `/cook --<flag>` sub-agent called by `/review` must conform to:

**Input:** `diff` (string — git diff output) + files scoped to its domain.

**Output:**
```json
{
  "verdict": "pass" | "warn" | "block",
  "findings": [
    {
      "id": "<flag>-<nnn>",
      "source": "<flag>",
      "severity": "blocker" | "high" | "medium" | "low",
      "category": "<category>",
      "rule": "<rule-id>",
      "message": "<description>",
      "file": "<path>",
      "line": <number>,
      "evidence": {
        "tool": "<flag or runner>",
        "file": "<path or null>",
        "line": <number or null>,
        "snippet": "<exact offending code or tool output>"
      },
      "suggestion": "<actionable fix>",
      "regression_of": null
    }
  ]
}
```

Per-finding `severity` uses the canonical four-level scale
(`blocker`/`high`/`medium`/`low`); the mode/run-level `verdict` keeps `/review`'s
`pass`/`warn`/`block` triad (mapped to the shared scale via the
verdict-normalization table in the shared schema). Map a sub-agent's judgement:
a must-fix violation → `blocker` or `high`; a should-fix → `medium`; an
informational nit → `low`. `rule` is **required** — it is the dedup/regression key.

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
`"contract"`, `"architecture"`, `"error-handling"`, `"debug"`, `"dead-code"`, `"duplication"`, `"readability"`, `"naming"`, `"complexity"`, `"scope-creep"`, `"security"`, `"performance"`, `"a11y"`, `"other"`. Migration mode findings use `"architecture"` (no dedicated category — the schema-safety concern is a form of structural risk); A11y/i18n mode findings use `"a11y"`.

### Orchestrator dedup pass

After collecting all sub-agent outputs for a mode, `/review` applies a deduplication pass before aggregating verdicts. Findings sharing `(category, file, line, rule)` (the canonical dedup key) are collapsed into a single entry:
- **Severity:** keep the highest (`blocker` > `high` > `medium` > `low`).
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
  "eval_set_path": "<features/prd-n/review/eval_set.json>" | null,
  "surface": {
    "files_changed": [ "<path>" ],
    "uncovered_changes": [ "<path or description>" ],
    "undetected_domain_note": "<optional — present only when files_changed includes an extension with no /cook standards shelf>",
    "modes": [
      { "mode": "<mode-name>", "flags": [ "<flag>" ] }
    ]
  },
  "modes": {
    "quality":     { "verdict": "...", "findings": [] },
    "coverage":    { "verdict": "...", "gaps": [] },
    "functional":  { "verdict": "...", "evaluated": 0, "n_a": 0, "findings": [] },
    "security":    { "verdict": "...", "findings": [] },
    "performance": { "verdict": "...", "findings": [] },
    "migration":   { "verdict": "...", "findings": [] },
    "a11y_i18n":   { "verdict": "...", "findings": [] }
  }
}
```

Unrun modes (pipeline stopped by `block`) are **omitted** from the `modes` object — not included as empty objects. `migration` and `a11y_i18n` are additionally omitted whenever their trigger condition doesn't match (`refs/modes/migration.md` / `refs/modes/a11y-i18n.md`) — this is the normal case, not an error; most diffs touch neither a migration file nor UI code.

### Top-level fields

- `eval_set_source` — provenance of the assertions in `eval_set[]`:
  - `"prd"` — every assertion came from PRD sections.
  - `"tests"` — every assertion came from test files (in-diff or co-located).
  - `"schemas"` — every assertion came from `schemas.json` of a prior `agent-audit` run.
  - `"diff"` — generated from the diff because no other source produced results.
  - `"mixed"` — two or more of the above sources contributed.

  Functional mode reads this and downgrades its verdict to `warn` only when value is `"diff"` (diff-derived assertions are circular by construction; PRD/tests/schemas sources are authoritative and do not trigger a downgrade).

- `eval_set_path` — path to the `eval_set.json` artifact written by Functional mode after classifying assertions. `null` when no PRD is known (no persistent run directory). `/test` consumes this via `--eval-set <path>` to re-run deferred executable assertions without re-bootstrapping from the PRD. The file's shape (`assertions: [{text, class}]`, `class` is `"executable" | "intent" | "negative"`) is defined in `refs/modes/functional.md` Step 1, not repeated here — it's a distinct artifact from this file's own inline `eval_set` field above (that field is a flat array of assertion strings for display; `eval_set.json` is the structured, classified version `/test` reads).

### Functional mode fields

- `evaluated` — count of applicable assertions with a definitive per-assertion verdict (`pass`, `warn`, or `block` — Functional's own assertion-result vocabulary, distinct from a finding's canonical `severity`). Does not include deferred executable or non-applicable assertions.
- `n_a` — count of assertions emitted as `n/a`. Includes: (a) non-applicable assertions (assertion concerns a surface untouched by the diff) and (b) applicable executable assertions deferred to `/test`.
- `deferred_note` — present only when every applicable assertion is `n/a` (i.e. `evaluated == 0`). Value: `"all assertions deferred to /test"`. Verdict is `warn` in this case (never `pass`).
- Each finding gains an `applicable: bool` field. Applicable executable assertions deferred to `/test` emit findings with `applicable: true`, verdict `n/a`, and `message` containing the `/test --eval-set <path>` referral.

### Mandatory evidence rule (Functional)

Every Functional finding with a per-assertion verdict of `pass` or `block` MUST populate `file` and `line` with the location of the satisfying or violating code. `null` is permitted only on `n/a` entries. Functional mode self-checks and downgrades any `pass` or `block` lacking evidence to `warn` with reason `"no evidence located"`. (This per-assertion verdict is Functional's evaluation result, separate from the finding's canonical `severity` field defined in the shared schema.)

---

## Fingerprint object (Step 2 outputs)

Step 2 of `SKILL.md` produces these structures, consumed downstream by Step 4 (surface assembly) and Step 6 (mode execution):

```json
{
  "active_domains": ["<domain>"],
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
    "type": "secret",
    "command_diff": "<diff-mode command with <files> placeholder>",
    "command_full": "<command for --full-secret-scan>",
    "severity_on_hit": "block"
  } | null,
  "flag_inventory": ["<flag>"]
}
```

- `mechanical_runners[]` is the empty list when no lint/format/typecheck runner is detected — Quality mode Stage 0 becomes a no-op.
- `secret_scanner` is `null` when no scanner is detected — Security mode Stage 0 emits a single `warn` finding and proceeds.
- `test_runner` is no longer produced — Coverage mode is static-only; test execution belongs to `/test`.
- Detection signals and per-runner severity assignments live in `refs/FLAG-LIST.md`.

---

## Verdict semantics

| Verdict | Meaning | Pipeline effect |
|---------|---------|----------------|
| `block` | At least one mode returned `block` | Stop after blocking mode; skip remaining modes |
| `warn` | No blocks; at least one `warn` | Continue; warnings surface in PR summary |
| `pass` | All modes `pass` | Continue silently |

Overall verdict = worst across all completed modes.
