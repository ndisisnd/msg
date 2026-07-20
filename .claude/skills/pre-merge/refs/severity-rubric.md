---
name: severity-rubric
description: How to grade pre-merge findings using diff context, reachability, dev-only scope, and regression status. Defines blocker/high/medium/low rules and all downgrade conditions.
---

# Severity Rubric

## Base severity by tool signal

| Tool signal | Raw severity |
|---|---|
| Secret scanner hit (any type) | blocker |
| No secret scanner configured (`no-secret-scanner`, C9 safety floor) | blocker |
| Platform coverage-gap (`platform-coverage-gap`, C12 — target platform, applicable component, no runner) | high |
| Test suite exit non-zero (failing test) | blocker |
| Build tool exit non-zero | blocker |
| E2E test failure (spec named) | high |
| SAST: confirmed injectable path | high |
| Dependency: CVE CVSS ≥ 9 (critical) | high |
| Bundle: route size > 15% regression vs baseline | high |
| SAST: possible/likely injectable path | medium |
| Dependency: CVE CVSS 7–8.9 (high) | medium |
| Lint: error-class finding | medium |
| Bundle: route size 5–15% regression vs baseline | medium |
| Dependency: CVE CVSS < 7 (medium/low) | low |
| Lint: warning-class finding | low |
| Bundle: route size < 5% regression vs baseline | low |

## Adjustment rules (applied in order; stop at first match)

Apply each rule once per finding. Rules may only downgrade, never upgrade.

### 1 — In-diff file weighting (upgrade eligible)

If the finding's `evidence.file` is in `files_changed` (the diff), treat the raw severity as-is. This is the default path — no adjustment.

### 2 — Dev-only scope (downgrade one level)

Condition: finding is in a file whose path matches any of:
- `*.test.*`, `*.spec.*`
- `__tests__/`, `test/`, `tests/`, `e2e/`, `integration/`
- `devDependencies` (for dependency scanner findings)
- `*.stories.*`, `*.mock.*`, `*.fixture.*`

Action: downgrade one level (`blocker` → `high`, `high` → `medium`, `medium` → `low`, `low` stays `low`).

Exception: a **secret scanner hit** in a test file is still `blocker` — test files are committed and secrets in them are just as public.

### 3 — Unreachable code path (downgrade one level)

Condition: the finding is in a code path that is:
- Dead code (function never called from any export or entry point)
- Behind a compile-time flag that is `false` in all known build configs
- In a file not imported anywhere

Action: downgrade one level. Document the unreachability evidence in `evidence.snippet`.

Exception: secret scanner hits are never downgraded for unreachability.

### 4 — Out-of-diff file (informational only)

Condition: `evidence.file` is NOT in `files_changed` and is not a test file co-located with a changed file.

Action: downgrade to `low` regardless of tool raw severity. The caller did not change this file; the finding is ambient context, not a regression.

Exception: build-failure and secret-scanner findings are not downgraded — they block the build or expose a credential regardless of whether the file was in the diff. The safety-floor `no-secret-scanner` blocker (C9) and the `platform-coverage-gap` finding (C12) are **repo-level** (no `evidence.file`), so this file-scoped downgrade never applies to them — they hold their raw severity.

### 5 — Regression marking (no severity change)

Condition: `regression_of` is non-null (set by aggregation step, not by subagent).

Action: no severity change. Add a `regression_of` note in the output. Human reviewers and the JSON consumer can filter on this field.

## Severity floor by stage

Even after downgrade, each stage has a severity floor for hard-fail signals:

| Stage | Signal | Minimum severity |
|---|---|---|
| mechanical | Lint/typecheck exit non-zero (`block`) | `blocker` |
| unit-int (Step 3) | Test suite exit non-zero | `blocker` |
| regression (Step 4) | Named regression failure; uncited prior-test edit | `high` |
| e2e | Named spec failure | `high` |
| coverage | Below floor, `enforced` profile | `high` |
| security | Secret scanner hit | `blocker` |
| security | No secret scanner configured (C9 floor) | `blocker` |
| migration | `DROP TABLE`/`DROP COLUMN` | `blocker` |
| migration | Same-PR destructive rename + app-code ref (C17 expand/contract) | `high` |
| executor | `platform-coverage-gap` — targeted platform, applicable component, no runner (C12) | `high` |
| prd-consistency | Acceptance criterion unmet (C11) | `high` |
| prd-consistency | Acceptance/error-case met-but-untested (C11) | `medium` |

## Fail-fast by component `criticality` (the executor's short-circuit)

The old fixed "any red step short-circuits" rule is generalized to a **DAG fail-fast
keyed on each component's `criticality`** (`refs/executor.md`, AC-PF11). When a component
returns a failing verdict:

| Failed component's `criticality` | Effect on the pipeline |
|---|---|
| `critical` (`mechanical`, `security`, `migration`) | **abort** the remaining pipeline — no later wave runs (the old mechanical short-circuit, generalized) |
| `blocking` (`unit`, `integration`, `e2e`, `regression`, `prd-consistency`, `api`, `a11y`, `mobile`) | fail the verdict, mark the component's **downstream dependents `blocked`** (they write a `skipped` result with `skip_reason: "blocked:<dep>"`), and let **independent** in-flight branches finish so the verdict aggregates the full picture |
| `advisory` / `config-driven` (until the project sets budgets) | never aborts — findings recorded, pipeline continues |

A platform profile may override a component's `criticality` (Q1) — the fail-fast class
follows the overridden tier. This governs run-abort only; per-finding severity is graded
by the rules above independently.

## Verdict derivation

After all adjustments:

```
if any finding.severity in ["blocker", "high"]  → verdict: "fail"
elif any finding.severity in ["medium", "low"]  → verdict: "pass_with_warnings"
else                                             → verdict: "pass"
```

## What "evidence" means in this rubric

A finding is only as good as its evidence. If a subagent cannot produce a quoted tool output line for a finding, it must drop the finding rather than emit an evidence-free claim. "The code looks suspicious" is not evidence — `gitleaks rule X matched file:line` is.
