---
name: refusal-patterns
description: The canonical refusal shapes for pre-merge. Defines no_diff, schema_mismatch, out_of_scope_modify, and out_of_scope_action — when each fires and what JSON to emit.
---

# Refusal Patterns

Pre-merge emits a structured refusal JSON and terminates on these conditions. Refusals always exit non-zero (except `sync_conflict`, which exits zero — that is the `skipped` verdict, not a refusal). A missing manifest is not a refusal: the first run sets the project up, then gates (`executor.md` §0).

Refusals are emitted as the sole JSON output. No other text follows.

---

## no_diff

**When it fires**: in the prelude, after running `scripts/script-resolve-diff.sh`. `files_changed` is empty — working tree matches the base ref.

**Exit code**: 1 (non-zero)

**JSON shape**:

```json
{
  "verdict": "refused",
  "reason": "no_diff",
  "detail": "The branch matches <base>. /pre-merge requires a diff to gate. Commit the work on the feature branch, then run /pre-merge again.",
  "base": "<base ref>",
  "prior_issues_loaded": false,
  "issues": []
}
```

**Never fall through**: do not resolve the pipeline, do not run a component, do not gate. Terminate immediately after emitting this JSON.

---

## schema_mismatch

**When it fires**: pre-flight, when `--prior-issues` file fails validation against `refs/output-schema.md`. The file exists but its shape does not match the expected schema (missing required fields, wrong types, unknown verdict value).

**Exit code**: 1 (non-zero)

**JSON shape**:

```json
{
  "verdict": "refused",
  "reason": "schema_mismatch",
  "detail": "Prior-issues file at <path> does not match the expected output schema. Field <field> is <actual_type>, expected <expected_type>. Load only files produced by /pre-merge.",
  "base": "<base ref>",
  "prior_issues_loaded": false,
  "issues": []
}
```

---

## out_of_scope_modify

**When it fires**: any point during the run — when a subagent attempts to modify source code, or when the user issues an instruction like "apply that fix", "edit the file", "patch it".

**Exit code**: 1 (non-zero)

**JSON shape**:

```json
{
  "verdict": "refused",
  "reason": "out_of_scope_modify",
  "detail": "/pre-merge is a read-only gate. It does not modify source code. To apply fixes, exit /pre-merge, use /simplify or /code-review --fix, then re-run /pre-merge.",
  "base": "<base ref>",
  "prior_issues_loaded": false,
  "issues": []
}
```

**Terminate the entire run** — do not continue fan-out after this refusal.

---

## out_of_scope_action

**When it fires**: any point during the run — when the user issues an instruction like "push this", "merge it", "create the PR", "run git push", or similar.

**Exit code**: 1 (non-zero)

**JSON shape**:

```json
{
  "verdict": "refused",
  "reason": "out_of_scope_action",
  "detail": "/pre-merge does not push or create PRs, and never merges. Run /pre-merge to get the verdict; on pass or pass_with_warnings, run /merge — it pushes the branch and opens the PR.",
  "base": "<base ref>",
  "prior_issues_loaded": false,
  "issues": []
}
```

**Terminate the entire run** — do not continue fan-out after this refusal.

---

## Refusal vs. verdict fail

| Condition | Output type | Exit code |
|---|---|---|
| Clean tree | Refusal JSON (`refused/no_diff`) | 1 |
| Schema mismatch | Refusal JSON (`refused/schema_mismatch`) | 1 |
| Modify instruction | Refusal JSON (`refused/out_of_scope_modify`) | 1 |
| Push/merge instruction | Refusal JSON (`refused/out_of_scope_action`) | 1 |
| Any blocking finding (blocker/high; a PRD-check finding only as acceptance-unmet) | Full output JSON (`fail`) | 1 |
| Only medium/low findings | Full output JSON (`pass_with_warnings`) | 0 |
| Zero findings | Full output JSON (`pass`) | 0 |
| Same-lines sync conflict (asked in the main conversation) | Skipped JSON (`skipped/sync_conflict`) | 0 |
