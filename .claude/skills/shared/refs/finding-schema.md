---
name: finding-schema
description: Canonical finding object shared by /review, /test, and /pre-merge. One severity enum, one field set, one evidence shape. The single source of truth for finding interoperability across the review → test → pre-merge pipeline.
---

# Finding Schema

The single canonical finding shape emitted by every gate in the pipeline
(`/review` → `/test` → `/pre-merge`). All three skills conform to this object so
that `ship`/`preflight` can merge, dedup, and regression-match findings
mechanically — without per-skill translation.

Replaces the three divergent shapes that previously drifted apart (disjoint
severity enums, `title` vs `message`, string vs nested evidence, `rule`/`category`
present in some and absent in others).

## Canonical finding object

```json
{
  "id": "<prefix>-<nnn>",
  "source": "<producer flag, bucket, or runner>",
  "severity": "blocker" | "high" | "medium" | "low",
  "category": "<category enum>",
  "rule": "<rule-id, test name, or assertion text>",
  "message": "<one-sentence description of what went wrong>",
  "file": "<relative path, or null>",
  "line": <integer, or null>,
  "evidence": {
    "tool": "<tool name that produced the finding>",
    "file": "<relative path, or null — mirrors top-level file>",
    "line": <integer, or null>,
    "snippet": "<exact quoted tool output — redact secret values>"
  },
  "suggestion": "<actionable fix, or null>",
  "repro": "<command to reproduce, or null>",
  "regression_of": null | "<prior finding id>"
}
```

## Field reference

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | string | yes | `<prefix>-<zero-padded 3-digit index>`, e.g. `sec-001`, `quality-003`, `unit-002`. Prefix names the producing bucket/mode. |
| `source` | string | yes | The producer: a `/cook --<flag>` (review semantic agent), a `lint:`/`format:`/`typecheck:`/`secrets:` runner (review mechanical stage), or the bucket name (`/test`, `/pre-merge`). After dedup may be a comma-separated list of merged sources. |
| `severity` | enum | yes | `blocker` / `high` / `medium` / `low`. See "Severity enum" below. |
| `category` | enum | yes | See "Category enum" below. Never omit — dedup and regression keys depend on it. |
| `rule` | string | yes | **The dedup/regression key.** Tool rule-id (`stripe-access-token`, semgrep check id), failing test name, or the verbatim assertion text. Never null — synthesize a stable slug from the finding if the tool gives no id. |
| `message` | string | yes | One sentence: what went wrong + where. (Formerly `title` in pre-merge.) Keep ≤ 80 chars for the headline; detail goes in `evidence.snippet`. |
| `file` | string\|null | yes | Relative path from repo root. `null` only for non-file-scoped findings (bundle routes, suite-level failures). Mirrors `evidence.file`. |
| `line` | int\|null | yes | Line number, or `null`. Mirrors `evidence.line`. |
| `evidence` | object | yes | Nested object — the canonical evidence shape. `tool` is required; `file`/`line`/`snippet` may be null/omitted for non-file-scoped findings. Buckets MAY add documented extra keys (e.g. bundle's `route`, `baseline_kb`, `current_kb`, `culprit`; e2e's `spec`; mobile's `platform`, `device`). Extensions live inside `evidence`, never as new top-level finding fields — this keeps the finding object's field set closed across producers so `ship`/`preflight` can merge mechanically. |
| `suggestion` | string\|null | yes | Actionable fix, or `null`. |
| `repro` | string\|null | yes | Copy-paste-runnable command to reproduce, or `null`. |
| `regression_of` | string\|null | yes | Set by the aggregation step when this finding matches a prior-run finding on `(category, file, rule)`. Subagents always emit `null`. |

### Dedup & regression keys

- **Dedup key:** `(category, file, line, rule)`. On collision keep the highest
  severity; concatenate distinct `source` values.
- **Regression key:** `(category, file, rule)`. When `--prior-issues` is loaded,
  set `regression_of: <prior id>` on any finding matching a prior finding's triple.

Both keys depend on `rule` being present and stable on every finding — this is
why `rule` is required, not optional.

## Severity enum

Four levels. This is the canonical scale; the previously-used two-level
`fail`/`warn` scale maps onto it.

| Level | When to assign |
|---|---|
| `blocker` | Exploit-ready now, or build/test suite fails hard (non-zero exit) |
| `high` | Reachable regression, test/assertion failure in diff-adjacent code, confirmed perf cliff |
| `medium` | Warning-class finding; reachability unclear; medium-CVE dependency |
| `low` | Informational, dev-only scope, low-CVSS with no direct path |

### Mapping from the legacy two-level scale

Skills that historically graded `fail`/`warn` (or `block`/`warn`/`info`) map as:

| Legacy | Canonical |
|---|---|
| `fail` / `block` | `blocker` (hard failure / non-zero exit) or `high` (reachable, diff-adjacent) |
| `warn` | `medium` (reachability unclear) or `low` (informational / dev-only) |
| `info` | `low` |

A producer chooses `blocker` vs `high` (and `medium` vs `low`) using the
reachability and in-diff weighting in each skill's severity rubric. `pass`-type
results are NOT findings — route them to `totals`/`evaluated`, never `findings[]`.

## Category enum

`integration`, `e2e`, `build`, `security`, `bundle`, `unit`, `functional`, `qa`,
`load`, `a11y`, `perf`, `api`, `mobile`, `coverage`, `contract`, `architecture`,
`error-handling`, `debug`, `dead-code`, `duplication`, `readability`, `naming`,
`complexity`, `scope-creep`, `performance`, `other`.

A bucket-based producer (`/test`, `/pre-merge`) sets `category` to its bucket
name. A semantic producer (`/review` `/cook` agent) picks the closest concern
category.

## Verdict normalization

Each skill's overall verdict (the per-run rollup, not per-finding severity) maps
onto a shared three-state scale so callers can aggregate across gates:

| Canonical verdict | `/review` | `/test` | `/pre-merge` |
|---|---|---|---|
| `block` | `block` | `fail` | `fail` |
| `warn` | `warn` | `pass_with_warnings` | `pass_with_warnings` |
| `pass` | `pass` | `pass` | `pass` |

`/test` and `/pre-merge` additionally use `refused`/`skipped` for
early-termination paths; those have no severity and carry no findings.

## Subagent return contract

- Return a single JSON object (not free-form text); the orchestrator reads it structurally.
- `findings` is always an array (empty when nothing went wrong).
- `verdict` is required even on a clean pass — never omit it.
- Severity is assigned by the subagent before returning; the aggregation step may downgrade but never upgrade.

## Example — security finding (pre-merge)

```json
{
  "id": "sec-001",
  "source": "security",
  "severity": "blocker",
  "category": "security",
  "rule": "stripe-access-token",
  "message": "Hardcoded credential in src/lib/stripe.ts:42",
  "file": "src/lib/stripe.ts",
  "line": 42,
  "evidence": {
    "tool": "gitleaks",
    "file": "src/lib/stripe.ts",
    "line": 42,
    "snippet": "gitleaks rule `stripe-access-token` matched — value redacted"
  },
  "suggestion": "Move the key to an env var and rotate the leaked credential.",
  "repro": "rtk gitleaks detect --source . --no-banner --redact",
  "regression_of": null
}
```

## Example — assertion failure (test)

```json
{
  "id": "unit-002",
  "source": "unit",
  "severity": "high",
  "category": "unit",
  "rule": "rejects blank email on POST /users",
  "message": "Assertion failed: POST /users with empty email did not return 400",
  "file": "test/users.test.ts",
  "line": 88,
  "evidence": {
    "tool": "vitest",
    "file": "test/users.test.ts",
    "line": 88,
    "snippet": "expected 400, received 500"
  },
  "suggestion": "Validate email presence before the DB write.",
  "repro": "rtk npx vitest run test/users.test.ts",
  "regression_of": null
}
```
