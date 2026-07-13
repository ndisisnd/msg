---
name: finding-schema
description: Canonical finding object emitted by pre-merge's gate stages and eng's pair-review / fail-ticket loop. One severity enum, one field set, one evidence shape. The single source of truth for finding interoperability across the gate.
---

# Finding Schema

The single canonical finding shape emitted across the harness — every pre-merge
gate stage (mechanical, unit-int, regression, platform buckets, security,
migration, PRD-consistency, preview), eng's per-ticket pair-review, and the
`msg-gate/gate-<n>.json` fail-ticket that `eng --build gate-json=` consumes. Every
producer conforms to this object so downstream consumers (the `/msg --gui` board,
`eng --build`'s gate-json read, the roadmap orchestrator) can merge, dedup, and
regression-match findings mechanically — without per-producer translation.

Replaces the divergent shapes that previously drifted apart (disjoint severity
enums, `title` vs `message`, string vs nested evidence, `rule`/`category` present
in some and absent in others).

> **v2 note:** the producers `/review` and `/test` are retired — their stages are
> now pre-merge gate stages. `post-merge` is a producer too — it emits findings on
> refusals and deploy failures (`source: post-merge`).

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
| `source` | string | yes | The producing gate stage. Pre-merge stages: `pre-merge:mechanical`, `pre-merge:unit-int`, `pre-merge:regression`, `pre-merge:bucket:<name>` (`<name>` ∈ e2e/qa/mobile/perf/a11y/coverage/api/load), `pre-merge:security`, `pre-merge:migration`, `pre-merge:prd-consistency`, `pre-merge:preview`. Mechanical sub-runners keep their tool prefix (`lint:`/`format:`/`typecheck:`/`secrets:<scanner>`/`comment-scan`/`commit-cap`). eng's per-ticket pair-review emits `pair-review`. `post-merge` emits `post-merge` (deploy failures + refusals). After dedup may be a comma-separated list of merged sources. |
| `severity` | enum | yes | `blocker` / `high` / `medium` / `low`. See "Severity enum" below. |
| `category` | enum | yes | See "Category enum" below. Never omit — dedup and regression keys depend on it. |
| `rule` | string | yes | **The dedup/regression key.** Tool rule-id (`stripe-access-token`, semgrep check id), failing test name, or the verbatim assertion text. Never null — synthesize a stable slug from the finding if the tool gives no id. |
| `message` | string | yes | One sentence: what went wrong + where. (Formerly `title` in pre-merge.) Keep ≤ 80 chars for the headline; detail goes in `evidence.snippet`. |
| `file` | string\|null | yes | Relative path from repo root. `null` only for non-file-scoped findings (bundle routes, suite-level failures). Mirrors `evidence.file`. |
| `line` | int\|null | yes | Line number, or `null`. Mirrors `evidence.line`. |
| `evidence` | object | yes | Nested object — the canonical evidence shape. `tool` is required; `file`/`line`/`snippet` may be null/omitted for non-file-scoped findings. Buckets MAY add documented extra keys (e.g. bundle's `route`, `baseline_kb`, `current_kb`, `culprit`; e2e's `spec`; mobile's `platform`, `device`; unit-int/e2e's `flaky`, `retries` when pre-merge's `--flaky <N>` reclassifies a failure that passed on retry). Extensions live inside `evidence`, never as new top-level finding fields — this keeps the finding object's field set closed across producers so the gate and its consumers can merge mechanically. |
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
`complexity`, `scope-creep`, `performance`, `deploy`, `other`.

A bucket-based stage (a pre-merge platform bucket) sets `category` to its bucket
name. A semantic stage (security, migration, PRD-consistency) or eng's pair-review
picks the closest concern category.

## Verdict normalization

The gate's overall verdict (the per-run rollup, not per-finding severity) maps
onto a shared three-state scale so callers can aggregate:

| Canonical verdict | `/pre-merge` |
|---|---|
| `block` | `fail` |
| `warn` | `pass_with_warnings` |
| `pass` | `pass` |

Pre-merge additionally uses two early-termination verdicts, with one meaning
each: `skipped` = the user cancelled at a gate; `refused` = the skill declined to
run (error paths — e.g. `no_diff`, `no_staging`, `schema_mismatch`). Both have no
severity and carry no findings. `post-merge` uses the same four-verdict scale
(`pass`/`fail`/`refused`/`skipped`) — `fail` when a production deploy errors
(carries a `deploy` finding), `refused` on a blocked precondition/gate, `skipped`
when a human cancels a ship gate (`post-merge/refs/output-schema.md`).

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

## Example — assertion failure (pre-merge unit-int stage)

```json
{
  "id": "unit-002",
  "source": "pre-merge:unit-int",
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
