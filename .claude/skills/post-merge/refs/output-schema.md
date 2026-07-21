---
name: post-merge-output-schema
description: What post-merge emits — a clean run's summary, and the canonical finding it raises on a deploy failure or refusal. Findings conform to shared/refs/finding-schema.md with source `post-merge`.
---

# Output Schema

Post-merge's primary artifact is its **run report** (`../shared/refs/report-schema.md`,
`skill: post-merge`). It additionally emits structured JSON in two cases: a
refusal (`refs/refusal-patterns.md`) and a deploy failure (a canonical finding).

## Clean-run summary (printed on success)

```json
{
  "verdict": "pass",
  "mode": "staging" | "production",
  "prd_paths": ["features/prd-101-task-crud/prd-101-task-crud.md"],
  "merged_pr": "<pr url>",
  "merge_commit": "<sha>",
  "deploy": { "ran": true, "target": "<url/build id>", "skipped": [] },
  "verify": { "ran": true, "passed": true, "skipped": [] },
  "staging_signoff": "2026-07-13@4f2c9a1e8b7d6c5a4938271605f4e3d2c1b0a9f8",  // <date>@<certified sha>; --staging only, on approval; null otherwise
  "report": "features/prd-101-.../reports/report-3.md"
}
```

## Deploy-failure finding

A non-zero deploy exit does not un-merge anything — the merge already happened —
so post-merge surfaces it as a finding rather than swallowing it. Conforms to
`../shared/refs/finding-schema.md` (the same object every gate stage emits):

```json
{
  "id": "deploy-001",
  "source": "post-merge",
  "severity": "high",
  "category": "deploy",
  "rule": "<mode>_deploy_cmd exited non-zero",
  "message": "Staging deploy for web failed (exit 1)",
  "file": null,
  "line": null,
  "evidence": {
    "tool": "post-merge",
    "snippet": "<last lines of the deploy log — redact secrets>"
  },
  "suggestion": "Check the deploy target's credentials/config; re-run the deploy command.",
  "repro": "<the exact staging_deploy_cmd / production_deploy_cmd>",
  "regression_of": null
}
```

- `source` is `post-merge` (the value added to the finding-schema source enum in P5).
- `category: deploy` is used for deploy failures; a refusal uses the refusal JSON shape instead (it carries no findings).

## Smoke-verification failure finding

A deploy that succeeds but fails its `smoke_cmd` emits the same canonical shape
with `rule: "smoke-failed"` — full example and consequences in
`refs/verify-deploy.md`. The clean-run summary's `verify` block records the
outcome either way: `ran: false` / `passed: null` when nothing was configured,
`passed: false` alongside the finding on a failure, `skipped` listing platforms
with no usable `smoke_cmd`.

## Verdict values

| Verdict | Meaning | Exit |
|---|---|---|
| `pass` | merged (+ deployed or deploy-skipped-with-note, + smoke verified or verify-skipped-with-note) | 0 |
| `fail` | merged but a deploy errored or failed its smoke check (finding emitted) | 1 |
| `refused` | a precondition/gate blocked before the sanctioned action | 1 |
| `skipped` | a human cancelled at a gate | 0 |
