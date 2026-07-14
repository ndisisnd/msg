---
name: output-schema
description: JSON schema for the pre-merge final emission. Defines field names, types, severity enum, verdict enum, and refusal shape.
---

# Output Schema

## Top-level shape

```json
{
  "run_id": "<uuid-or-timestamp>",
  "base": "<git ref used as base>",
  "branch": "<current branch name>",
  "timestamp": "<ISO 8601>",
  "commit_count": 0,
  "files_changed": ["path/to/file.ts"],
  "verdict": "pass" | "pass_with_warnings" | "fail" | "refused" | "skipped",
  "summary": {
    "blocker": 0,
    "high": 0,
    "medium": 0,
    "low": 0
  },
  "issues": [],
  "skipped": [],
  "prd_paths": [],
  "prior_issues_loaded": false,
  "profile": "strict" | "standard" | "lenient",
  "preview": { "fired": false, "approved": null, "kind": null, "artifact": null },
  "gate_ticket": "msg-gate/gate-<n>.json" | null,
  "pr_url": "<feature→staging PR url>" | null
}
```

- `profile` — the Step 0 platform-tolerance profile resolved for this run.
- `preview` — Step 8 outcome (`fired: false` when the D6 trigger didn't match).
- `gate_ticket` — path to the fail-ticket written on a non-clean verdict (`fail`), consumed by `eng --build gate-json=`; `null` on a clean pass.
- `pr_url` — the feature→staging PR opened at Step 9 on `pass`/`pass_with_warnings`; `null` otherwise. Pre-merge never merges it.

## Verdict semantics

| Verdict | Meaning | Exit code |
|---|---|---|
| `"pass"` | Zero findings | 0 |
| `"pass_with_warnings"` | Only medium / low findings | 0 |
| `"fail"` | Any blocker or high finding | 1 |
| `"refused"` | Early termination — clean tree, schema mismatch, or out-of-scope instruction | 1 |
| `"skipped"` | User declined at the human gate | 0 |

## issues[] entry shape

Each item in `issues[]` is a **canonical finding object** — the field set, types,
and enums are defined once in `../../shared/refs/finding-schema.md`, with pre-merge's
bucket-specific notes and evidence extensions in `refs/finding-schema.md`. This file
does not re-list the fields.

ID prefixes name the producing stage: `mech`, `unit`, `regr`, `e2e`, `qa`,
`mobile`, `perf`, `a11y`, `cov`, `api`, `load`, `sec`, `mig`, `func`. See
`refs/finding-schema.md`.

## skipped[]

Array of stages/buckets omitted from this run. Each entry:

```json
{
  "bucket": "load",
  "reason": "no_tooling" | "not_in_profile" | "not_triggered"
}
```

- `no_tooling` — no detected tool supports the bucket (Step 5).
- `not_in_profile` — the bucket is not in the Step 0 profile's `required_buckets`.
- `not_triggered` — a conditional stage whose trigger didn't match (Step 6 migration with no migration files, Step 8 preview with no D6 path match, Step 7 with no `--prd`).

## Refusal shape

When `verdict` is `"refused"`, the top-level object is:

```json
{
  "verdict": "refused",
  "reason": "no_diff" | "schema_mismatch" | "out_of_scope_modify" | "out_of_scope_action",
  "detail": "<human-readable explanation>",
  "base": "<base ref>",
  "prior_issues_loaded": false,
  "issues": []
}
```

See `refs/refusal-patterns.md` for the three canonical shapes.

## Skipped shape

When `verdict` is `"skipped"`:

```json
{
  "verdict": "skipped",
  "reason": "sync_conflict_declined" | "preview_rejected",
  "base": "<base ref>",
  "branch": "<branch>",
  "timestamp": "<ISO 8601>",
  "detail": "<what the human declined and where>"
}
```

- `sync_conflict_declined` — the human aborted the Step 1 sync at a semantic conflict.
- `preview_rejected` — the human rejected the Step 8 preview; the PR is not opened.

## Field reference

| Field | Type | Notes |
|---|---|---|
| `run_id` | string | Timestamp-based or UUID; unique per invocation |
| `base` | string | Git ref used as comparison base |
| `branch` | string | `git branch --show-current` at invocation time |
| `timestamp` | string | ISO 8601, UTC |
| `commit_count` | integer | `git rev-list --count <base>..HEAD` |
| `files_changed` | string[] | Relative paths from repo root |
| `verdict` | enum | See verdict table above |
| `summary` | object | Count of findings per severity level |
| `issues` | array | Zero or more findings; see finding-schema.md |
| `skipped` | array | Buckets omitted and why |
| `prd_paths` | string[] | Paths of loaded PRD files, empty if none |
| `prior_issues_loaded` | boolean | Whether `--prior-issues` file was loaded |
