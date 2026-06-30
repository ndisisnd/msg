---
name: finding-schema
description: Pre-merge finding shape. Conforms to the canonical finding object in ../../shared/refs/finding-schema.md, with pre-merge bucket-specific evidence extensions.
---

# Finding Schema

Pre-merge findings use the **canonical finding object** defined in
`../../shared/refs/finding-schema.md` — the single source of truth shared with
`/review` and `/test`. Read that file for the full field reference, severity
enum, category enum, dedup/regression keys, and verdict normalization. This file
records only pre-merge's specifics.

Each bucket subagent spawned by pre-merge Step 5 returns:

```json
{
  "verdict": "pass" | "pass_with_warnings" | "fail" | "refused",
  "findings": [
    {
      "id": "<bucket>-<nnn>",
      "source": "<bucket>",
      "severity": "blocker" | "high" | "medium" | "low",
      "category": "integration" | "e2e" | "build" | "security" | "bundle",
      "rule": "<tool rule-id, failing test name, or bundle route>",
      "message": "<short description, max 80 chars>",
      "file": "<relative path, or null>",
      "line": <integer, or null>,
      "evidence": {
        "tool": "<tool name>",
        "file": "<relative path, or null — omit for non-file-scoped findings>",
        "line": 0,
        "snippet": "<exact quoted tool output — redact any secret values>"
      },
      "suggestion": "<actionable fix, or null>",
      "repro": "<rtk command to reproduce this finding exactly>",
      "regression_of": null | "<prior issue id string>"
    }
  ]
}
```

## Pre-merge specifics

- **`id` prefixes:** `int` (integration), `e2e`, `build`, `sec` (security), `bundle`. Example: `sec-001`.
- **`category`** is always the bucket name: `integration`, `e2e`, `build`, `security`, `bundle`.
- **`rule`** is **required** (per the canonical schema) and is the dedup + regression key.
  Populate it from the tool: the `gitleaks` rule id, the semgrep check id, the
  failing test/spec name, or the `bundlesize` route. Never leave it null — Step 6
  dedups on `(category, file, line, rule)` and marks regressions on `(category, file, rule)`.
- **`source`** is the bucket name (same as `category` for pre-merge, which has no semantic sub-agents).
- **`regression_of`** is set by the aggregation step (Step 6) when this finding matches a prior-issues entry. Subagents always emit `null`.

### Bucket-specific evidence extensions

Buckets MAY add these keys inside `evidence` (sanctioned by the canonical schema):

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

## Example — security finding

```json
{
  "verdict": "fail",
  "findings": [
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
  ]
}
```

## Example — bundle finding

```json
{
  "verdict": "fail",
  "findings": [
    {
      "id": "bundle-001",
      "source": "bundle",
      "severity": "high",
      "category": "bundle",
      "rule": "/dashboard",
      "message": "/dashboard route +84 KB gzip vs baseline (+18.2%)",
      "file": null,
      "line": null,
      "evidence": {
        "tool": "@next/bundle-analyzer",
        "file": null,
        "line": 0,
        "route": "/dashboard",
        "baseline_kb": 461,
        "current_kb": 545,
        "culprit": "moment-with-locales",
        "snippet": "Route /dashboard: 545 KB (baseline: 461 KB, delta: +84 KB, culprit: moment-with-locales)"
      },
      "suggestion": "Replace moment-with-locales with date-fns or dynamic import.",
      "repro": "rtk pnpm build && rtk pnpm bundle-analyzer compare baseline",
      "regression_of": null
    }
  ]
}
```
