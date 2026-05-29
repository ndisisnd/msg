---
name: finding-schema
description: Per-finding shape returned by each bucket subagent in pre-merge. Defines id, severity, category, evidence, repro, and regression_of fields.
---

# Finding Schema

Each bucket subagent spawned by pre-merge Step 5 returns:

```json
{
  "verdict": "pass" | "pass_with_warnings" | "fail" | "refused",
  "findings": [
    {
      "id": "<bucket>-<nnn>",
      "severity": "blocker" | "high" | "medium" | "low",
      "category": "integration" | "e2e" | "build" | "security" | "bundle",
      "title": "<short description, max 80 chars>",
      "evidence": {
        "tool": "<tool name>",
        "file": "<relative path, or null — omit for non-file-scoped findings>",
        "line": 0,
        "snippet": "<exact quoted tool output — redact any secret values>",
        "...": "<bucket-specific extra fields allowed — see per-bucket notes below>"
      },
      "repro": "<rtk command to reproduce this finding exactly>",
      "regression_of": null | "<prior issue id string>"
    }
  ]
}
```

## Field reference

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | string | yes | Format: `<prefix>-<zero-padded 3-digit index>`. Prefixes: `int` (integration), `e2e`, `build`, `sec` (security), `bundle`. Example: `sec-001` |
| `severity` | enum | yes | `blocker` / `high` / `medium` / `low` — see `refs/severity-rubric.md` |
| `category` | enum | yes | Matches the bucket name: `integration`, `e2e`, `build`, `security`, `bundle` |
| `title` | string | yes | One sentence. Tool name + location + what went wrong. Max 80 chars. |
| `evidence.tool` | string | yes | Tool that produced this finding (e.g. `gitleaks`, `playwright`, `vitest`) |
| `evidence.file` | string\|null | no | Relative path from repo root. Omit for non-file-scoped findings (bundle routes, e2e specs) |
| `evidence.line` | integer | no | 0 or omit if not line-scoped |
| `evidence.snippet` | string | no | Exact output line from the tool. **Redact secret values** — show rule name and masked value only |
| `evidence.spec` | string | no | e2e only — spec file path (e.g. `tests/e2e/checkout.spec.ts`) |
| `evidence.route` | string | no | bundle only — Next.js/Vite route (e.g. `/dashboard`) |
| `evidence.baseline_kb` | integer | no | bundle only — prior size in KB |
| `evidence.current_kb` | integer | no | bundle only — current size in KB |
| `evidence.culprit` | string | no | bundle only — detected cause module |
| `repro` | string | yes | Single `rtk` command that reproduces the finding. Must be copy-paste runnable. |
| `regression_of` | string\|null | yes | Set by the aggregation step (Step 6) when this finding matches a prior-issues entry. Not set by subagents. |

## Severity assignment

Subagents assign severity before returning. The aggregation step may downgrade but never upgrade:

| Level | When to assign |
|---|---|
| `blocker` | Exploit-ready now, or build/test suite fails hard (non-zero exit) |
| `high` | Reachable regression, test failure in diff-adjacent code, confirmed perf cliff |
| `medium` | Warning-class finding; reachability unclear; medium CVE in a dependency |
| `low` | Informational, dev-only scope, low-CVSS with no direct path |

See `refs/severity-rubric.md` for the full rubric including downgrade conditions.

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
      "severity": "blocker",
      "category": "security",
      "title": "Hardcoded credential in src/lib/stripe.ts:42",
      "evidence": {
        "file": "src/lib/stripe.ts",
        "line": 42,
        "tool": "gitleaks",
        "snippet": "gitleaks rule `stripe-access-token` matched — value redacted"
      },
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
      "severity": "high",
      "category": "bundle",
      "title": "/dashboard route +84 KB gzip vs baseline (+18.2%)",
      "evidence": {
        "file": null,
        "line": 0,
        "tool": "@next/bundle-analyzer",
        "snippet": "Route /dashboard: 545 KB (baseline: 461 KB, delta: +84 KB, culprit: moment-with-locales)"
      },
      "repro": "rtk pnpm build && rtk pnpm bundle-analyzer compare baseline",
      "regression_of": null
    }
  ]
}
```
