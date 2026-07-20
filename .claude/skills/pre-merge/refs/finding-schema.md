---
name: finding-schema
description: Pre-merge finding shape. Conforms to the canonical finding object in ../../shared/refs/finding-schema.md, with pre-merge component-specific evidence extensions.
---

# Finding Schema

Pre-merge findings use the **canonical finding object** defined in
[`../../shared/refs/finding-schema.md`](../../shared/refs/finding-schema.md) —
the single source of truth. Read that file for the full field list, field
reference, severity enum, category enum, dedup/regression keys, verdict
normalization, and the worked example (`sec-001`). This file records **only**
pre-merge's specifics; it does not re-list the field set or repeat the shared
example.

Each stage subagent (Step 5 components, Step 6 security/migration, Step 7
PRD-consistency) returns the canonical `{ "verdict": ..., "findings": [ ... ] }`
object.

## Pre-merge specifics

- **`id` prefixes** name the producing stage: `unit`, `regr` (regression), `e2e`, `qa`, `mobile`, `perf`, `a11y`, `cov` (coverage), `api`, `load`, `sec` (security), `mig` (migration), `func` (PRD-consistency), `mech` (mechanical). Example id: `sec-001`.
- **`category`** is the closest concern (platform components → the component name; security → `security`; migration → `architecture`; PRD-consistency → `functional`/`scope-creep`; mechanical comment/commit → `readability`/`scope-creep`).
- **`rule`** is **required** and is the dedup + regression key. Populate it from the tool: the `gitleaks` rule id, semgrep check id, failing test/spec name, WCAG criterion, coverage metric, or a stable slug (`acceptance-unmet`, `oversize-commit`). Never null — Step 6 dedups on `(category, file, line, rule)`, regressions on `(category, file, rule)`.
- **`source`** is the gate stage per `../../shared/refs/finding-schema.md`: `pre-merge:mechanical` (or `lint:`/`comment-scan`/`commit-cap`), `pre-merge:unit-int`, `pre-merge:regression`, `pre-merge:bucket:<name>`, `pre-merge:security` (or `secrets:<scanner>`/`sast:semgrep`/`dependency:<tool>`), `pre-merge:migration` (or `migration:static`), `pre-merge:prd-consistency`, `pre-merge:preview`.
- **`regression_of`** is set by the aggregation step when this finding matches a `--prior-issues` entry. Subagents always emit `null`.

### Stage-specific evidence extensions

Stages MAY add these keys inside `evidence` (extensions live inside `evidence`,
never as new top-level finding fields):

| Field | Stage | Notes |
|---|---|---|
| `evidence.spec` | e2e | spec file path (e.g. `tests/e2e/checkout.spec.ts`) |
| `evidence.platform` / `evidence.device` | mobile | device matrix (`ios`/`android`/`widget`) |
| `evidence.flaky` / `evidence.retries` | e2e, unit-int | present only under `--flaky <N>` |

## Severity assignment

Use the canonical four-level scale (`blocker`/`high`/`medium`/`low`) — see the
shared schema and `refs/severity-rubric.md`. The aggregation step may downgrade
but never upgrade.

## Subagent return contract

- Return value is a single JSON object (not free-form text)
- `findings` must be an array (empty if `verdict: "pass"`)
- `verdict` is required even on pass — do not omit it
- Pre-merge reads this object via structured output; free-form text is ignored
