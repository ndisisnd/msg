---
name: finding-schema
description: Pre-merge finding shape. Conforms to the canonical finding object in ../../shared/refs/finding-schema.md, with pre-merge bucket-specific evidence extensions.
---

# Finding Schema

Pre-merge findings use the **canonical finding object** defined in
[`../../shared/refs/finding-schema.md`](../../shared/refs/finding-schema.md) —
the single source of truth shared with `/review` and `/test`. Read that file for
the full field list, field reference, severity enum, category enum,
dedup/regression keys, verdict normalization, and the worked example (`sec-001`).
This file records **only** pre-merge's specifics; it does not re-list the field
set or repeat the shared example.

Each bucket subagent spawned by pre-merge Step 5 returns the canonical
`{ "verdict": ..., "findings": [ <canonical finding>, ... ] }` object.

## Pre-merge specifics

- **`id` prefixes:** `int` (integration), `e2e`, `build`, `sec` (security), `bundle`. Example id: `sec-001`.
- **`category`** is always the bucket name: `integration`, `e2e`, `build`, `security`, `bundle`.
- **`rule`** is **required** (per the canonical schema) and is the dedup + regression key.
  Populate it from the tool: the `gitleaks` rule id, the semgrep check id, the
  failing test/spec name, or the `bundlesize` route. Never leave it null — Step 6
  dedups on `(category, file, line, rule)` and marks regressions on `(category, file, rule)`.
- **`source`** is the bucket name (same as `category` for pre-merge, which has no semantic sub-agents).
- **`regression_of`** is set by the aggregation step (Step 6) when this finding matches a prior-issues entry. Subagents always emit `null`.

### Bucket-specific evidence extensions

Buckets MAY add these keys inside `evidence` (sanctioned by the canonical schema's
closed-field-set rule — extensions live inside `evidence`, never as new top-level
finding fields):

| Field | Bucket | Notes |
|---|---|---|
| `evidence.spec` | e2e | spec file path (e.g. `tests/e2e/checkout.spec.ts`) |
| `evidence.route` | bundle | Next.js/Vite route (e.g. `/dashboard`) |
| `evidence.baseline_kb` | bundle | prior size in KB |
| `evidence.current_kb` | bundle | current size in KB |
| `evidence.culprit` | bundle | detected cause module |

## Severity assignment

Use the canonical four-level scale (`blocker`/`high`/`medium`/`low`) — see the
shared schema and `refs/severity-rubric.md`. The aggregation step may downgrade
but never upgrade.

## Subagent return contract

- Return value is a single JSON object (not free-form text)
- `findings` must be an array (empty if `verdict: "pass"`)
- `verdict` is required even on pass — do not omit it
- Pre-merge reads this object via structured output; free-form text is ignored
