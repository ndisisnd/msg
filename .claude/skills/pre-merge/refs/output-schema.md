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
  "eval_set_path": null
}
```

## Verdict semantics

| Verdict | Meaning | Exit code |
|---|---|---|
| `"pass"` | Zero findings | 0 |
| `"pass_with_warnings"` | Only medium / low findings | 0 |
| `"fail"` | Any blocker or high finding | 1 |
| `"refused"` | Early termination — clean tree, schema mismatch, or out-of-scope instruction | 1 |
| `"skipped"` | User declined at the human gate | 0 |

## issues[] entry shape

Each item in `issues[]` is a finding per `refs/finding-schema.md`, which conforms
to the shared canonical finding object in `../../shared/refs/finding-schema.md`:

```json
{
  "id": "<prefix>-<nnn>",
  "source": "<bucket>",
  "severity": "blocker" | "high" | "medium" | "low",
  "category": "integration" | "e2e" | "build" | "security" | "bundle",
  "rule": "<tool rule-id / failing test / route — dedup + regression key>",
  "message": "<short human-readable description>",
  "file": "<path or null>",
  "line": <integer or null>,
  "evidence": {
    "tool": "<tool name>",
    "<bucket-specific fields>": "..."
  },
  "suggestion": "<actionable fix or null>",
  "repro": "<rtk command to reproduce this finding>",
  "regression_of": null | "<prior issue id>"
}
```

ID prefixes: `int` (integration), `e2e`, `build`, `sec` (security), `bundle`.

## skipped[]

Array of bucket names omitted from this run. Each entry:

```json
{
  "bucket": "bundle",
  "reason": "no_tooling" | "user_removed"
}
```

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
  "reason": "user_declined",
  "base": "<base ref>",
  "branch": "<branch>",
  "timestamp": "<ISO 8601>",
  "check_matrix": [
    {
      "bucket": "integration",
      "command": "pnpm vitest run --coverage <files>",
      "est_seconds": 12
    }
  ]
}
```

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
| `eval_set_path` | string \| null | Path where eval_set was written, or null |
