---
name: refusal-patterns
description: The three canonical refusal shapes for pre-merge. Defines no_diff, out_of_scope_modify, and out_of_scope_action — when each fires and what JSON to emit.
---

# Refusal Patterns

Pre-merge emits a structured refusal JSON and terminates on three conditions. Refusals always exit non-zero (except `user_declined` which exits zero — that is the `skipped` verdict, not a refusal).

Refusals are emitted as the sole JSON output. No other text follows.

---

## no_diff

**When it fires**: Step 1, after running `scripts/resolve-diff.sh`. `files_changed` is empty — working tree matches the base ref.

**Exit code**: 1 (non-zero)

**JSON shape**:

```json
{
  "verdict": "refused",
  "reason": "no_diff",
  "detail": "Working tree matches <base>. /pre-merge requires a diff to gate. To check committed work, supply --base <ref> pointing at the merge target; to check against a prior PR state, use --base <sha>.",
  "base": "<base ref>",
  "prior_issues_loaded": false,
  "issues": []
}
```

**Never fall through**: do not fingerprint, do not show a matrix, do not gate. Terminate immediately after emitting this JSON.

---

## no_staging

**When it fires**: Step 1 (SYNC), when neither `origin/staging` nor a local `staging` branch resolves. The v2 topology (D3) is `feature → staging → main` — without `staging` there is nothing to sync against and nothing for Step 9 to open a PR into.

**Exit code**: 1 (non-zero)

**JSON shape**:

```json
{
  "verdict": "refused",
  "reason": "no_staging",
  "detail": "No `staging` branch exists. /pre-merge gates a feature branch against staging (feature → staging → main). Create it: `git branch staging main && git push -u origin staging`, then re-run — or run /msg --init's branch-protection bootstrap.",
  "base": "<base ref>",
  "prior_issues_loaded": false,
  "issues": []
}
```

---

## schema_mismatch

**When it fires**: Step 2, when `--prior-issues` file fails validation against `refs/output-schema.md`. The file exists but its shape does not match the expected schema (missing required fields, wrong types, unknown verdict value).

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
  "detail": "/pre-merge does not push, merge, or create PRs. Run /pre-merge to get the verdict, then use 'gh pr create' or 'git push' yourself when the verdict is pass or pass_with_warnings.",
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
| No `staging` branch | Refusal JSON (`refused/no_staging`) | 1 |
| Schema mismatch | Refusal JSON (`refused/schema_mismatch`) | 1 |
| Modify instruction | Refusal JSON (`refused/out_of_scope_modify`) | 1 |
| Push/merge instruction | Refusal JSON (`refused/out_of_scope_action`) | 1 |
| Any blocker or high finding | Full output JSON (`fail`) | 1 |
| Only medium/low findings | Full output JSON (`pass_with_warnings`) | 0 |
| Zero findings | Full output JSON (`pass`) | 0 |
| User declined gate | Skipped JSON (`skipped`) | 0 |
