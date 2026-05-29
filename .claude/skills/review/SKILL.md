---
name: review
description: >
  After eng --build, resolve a diff, fingerprint the codebase, bootstrap an
  eval-set from the PRD, confirm the review surface, then fan out to /cook
  sub-agents across five ordered review modes — with mechanical gates
  (lint / format / typecheck / secret scan via local tooling) layered in
  ahead of the semantic agents — aggregating findings into a single
  structured JSON. Consumed by preflight or read directly by a human.
model: claude-sonnet-4-6
allowed_tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
  - Agent
---

# review

Code review orchestrator. Runs after `eng --build`, before `gh pr create`. Each run is independent — no state carried between runs.

```
eng --build  →  /review  →  [address findings]  →  /review (repeat until pass/warn)  →  /docu  →  gh pr create
```

## Usage

- `/review` — diffs against HEAD
- `/review <branch>` — diffs against a named branch
- `/review <PR#>` — fetches PR diff via `gh pr diff <n>`
- `/review --full-secret-scan` — opts Security mode Stage 0 into scanning the full working tree (default is diff-only). Composable with branch and PR args, e.g. `/review feature/x --full-secret-scan` or `/review 42 --full-secret-scan`.

**Hard refusals:** does NOT modify source code; does NOT check documentation (`/docu`'s job); makes exactly ONE `AskUserQuestion` call (Step 5).

## Inputs / Outputs

| | Name | Source / Destination |
|--|------|----------------------|
| In | Diff | `git diff HEAD` / `git diff <branch>` / `gh pr diff <n>` |
| In | PRD | Auto-discovered from `features/prd-*/prd-*.md` (most recent first) |
| Out | Findings JSON | stdout always; `features/prd-[n]/review/review-<YYYYMMDD-HHmmss>.json` when PRD known |

Schema, sub-skill contract, verdict semantics: `refs/schema.md`.

## Protocol

### Step 1/7 — Resolve diff

| Arg | Command |
|-----|---------|
| None | `rtk git diff HEAD` |
| None, bare invocation on `main` | `rtk git diff HEAD~1 HEAD` |
| Branch name | `rtk git diff <branch>` |
| PR number | `gh pr diff <n>` |

Run `rtk git branch --show-current` to determine the current branch. `review` is workflow-agnostic — runs on any branch including `main`. Bare `/review` on `main` falls back to `git diff HEAD~1 HEAD` so trunk-based and solo workflows still get a review surface. Named-branch and PR invocations work unchanged from any branch. If the resulting diff is empty: exit `Nothing to review — diff is empty.`

### Step 2/7 — Fingerprint codebase

Run once at startup; never re-derive mid-run. Detection signals, runner mappings, and the authoritative `/cook` flag inventory all live in `refs/FLAG-LIST.md` — load it once here.

Produce five outputs from this step:

- **`active_domains[]`** — list of detected technology domains (used by Steps 4–6 for flag assembly). Signals: `refs/FLAG-LIST.md#domain-detection-review-step-2-fingerprint`.
- **`test_runner`** — structured object used exclusively by Coverage mode. Signals: `refs/FLAG-LIST.md#test-runner-detection-review-step-2-fingerprint`. If no runner is detected, set `test_runner` to `null`; Coverage mode will emit `warn` and skip execution.
- **`mechanical_runners[]`** — list of detected lint/format/typecheck runners (used by Quality mode Stage 0). Signals: `refs/FLAG-LIST.md#mechanical-runner-detection-review-step-2-fingerprint`. Each entry has `{ name, command, expects_zero_exit, severity_on_fail }`. Empty list if nothing detected — Quality Stage 0 becomes a no-op.
- **`secret_scanner`** — single object describing the highest-priority detected secret scanner (used by Security mode Stage 0), or `null` if none. Signals and shape: `refs/FLAG-LIST.md#mechanical-runner-detection-review-step-2-fingerprint` (Secret scanners sub-table). When `null`, Security Stage 0 emits a `warn` finding rather than blocking.
- **`flag_inventory`** — in-memory set of every valid flag token parsed from `refs/FLAG-LIST.md` (concerns + per-domain + sub-refs). Used by Step 4 to validate assembled flags.

### Step 3/7 — Locate PRD; bootstrap eval-set

Discovery runs in this order, merging results into `eval_set[]` and deduplicating by assertion text:

1. **PRD sections** — search `features/prd-*/prd-*.md` by recency; extract "Acceptance Criteria", "Test Cases", or "Assertions" sections.
2. **Test files in the diff** — for each `*.test.*`, `*.spec.*`, or `__tests__/` file present in the diff, parse `it(...)`, `test(...)`, `describe(...)` strings as assertions.
3. **Co-located tests** — for each changed source file, check for a sibling test file (same basename, `.test.*` or `.spec.*` suffix, or matching path under `__tests__/`) even if not in the diff; extract assertions as in step 2.
4. **schemas.json** — if the located PRD has a sibling `agent-audit/` or `audit/` run dir (e.g. `features/prd-<n>/agent-audit/schemas.json`), read the `assertions` field and merge.
5. **Conventional test directories** — scan `tests/`, `e2e/`, `integration/` for files tagged to the PRD slug (filename or content contains `prd-<n>`); extract assertions.

If all five sources yield zero assertions, generate `eval_set[]` from the diff as a fallback. Emit the numbered merged list to stdout. User refines at Step 5 via **Adjust**.

Set `eval_set_source` in the top-level output JSON to one of:
- `"prd"` — every assertion from PRD sections.
- `"tests"` — every assertion from test files (in-diff or co-located).
- `"schemas"` — every assertion from `schemas.json`.
- `"diff"` — every assertion generated from the diff (no other source produced results).
- `"mixed"` — assertions came from two or more of the above sources.

Emit before continuing: `Eval-set: <N> assertions (prd: <a>, tests: <b>, schemas: <c>, diff: <d>).` where the four counts sum to N (omit zero buckets only if it improves readability; otherwise show all four).

### Step 4/7 — Derive review surface

Cross-reference diff against PRD: produce `files_changed`, `prd_rows_covered`, `uncovered_changes[]` (scope creep candidates). Assemble flags per mode using `active_domains[]` and the global + per-domain tables in `refs/FLAG-LIST.md`. **Validate every assembled flag against `flag_inventory` (loaded in Step 2) — any flag absent from the inventory is silently dropped.** Surface schema: `refs/schema.md`.

### Step 5/7 — Confirm surface ← sole AskUserQuestion call

Show surface summary + full execution plan (each mode → flags + files). Example:
```
Quality    → /cook --api-design --architecture --react  (auth.ts, api/users.ts)
Coverage   → test runner vs eval-set                   (auth.ts, api/users.ts)
Functional → eval-set assertions vs diff               (3 assertions)
Security   → /cook --security --auth --typescript      (auth.ts, api/users.ts)
Performance→ /cook --performance --database            (api/users.ts)
```

Options: **Proceed** / **Adjust** (update surface + `eval_set[]`, continue without re-asking) / **Cancel** (exit, no findings). No further `AskUserQuestion` calls.

### Step 6/7 — Run modes in order; fan out /cook per mode

Order and per-mode stage layout:

| Order | Mode | Stage 0 (mechanical, runs first) | Semantic stage |
|-------|------|-----------------------------------|----------------|
| 1 | Quality | Mechanical gate — lint / format / typecheck via `mechanical_runners[]`; any `block` short-circuits and skips the semantic stage. | `/cook --<flag>` semantic agents with rubric amendment. |
| 2 | Coverage | — (no Stage 0) | Test-runner protocol against `eval_set`. |
| 3 | Functional | — (no Stage 0) | Eval-set assertion protocol against the diff. |
| 4 | Security | Secret scan — runs `secret_scanner` (diff-only by default, full-tree with `--full-secret-scan`); always proceeds to semantic stage regardless of verdict. | `/cook --<flag>` semantic agents for injection / auth / input-validation. |
| 5 | Performance | — (no Stage 0) | `/cook --<flag>` semantic agents. |

For each mode: run Stage 0 first (if defined), then spawn all `/cook --<flag>` sub-agents in parallel; wait; collect `{ verdict, findings[] }` per sub-skill contract (`refs/schema.md`). Aggregate Stage 0 findings with semantic-stage findings into the mode output. On any mode-level `block`: stop pipeline immediately, skip remaining modes, go to Step 7. Mode details: `refs/modes/<mode>.md`.

**Quality-mode only:** Before spawning Quality sub-agents, append the rubric amendment from `refs/modes/quality.md#sub-agent-prompt-amendment` to each agent's prompt. Also pass `uncovered_changes[]` (from Step 4) as an additional input to every Quality sub-agent. No other mode receives the rubric amendment or `uncovered_changes[]`.

**Post-collection dedup (all modes):** After collecting all sub-agent outputs for a mode, apply a deduplication pass: collapse findings sharing `(file, line, category)` into a single entry, keeping the one with the highest severity (`block` > `warn` > `info`). Concatenate distinct `source` values from collapsed findings into a comma-separated string on the surviving finding (e.g. `"--api-design,--architecture"`).

### Step 7/7 — Aggregate and emit

Merge mode outputs into output schema (`refs/schema.md`). Overall verdict = worst across completed modes (`block` > `warn` > `pass`). Emit JSON to stdout. If PRD known, also write `features/prd-<n>/review/review-<YYYYMMDD-HHmmss>.json`. Omit unrun modes from output.

## References

- `refs/FLAG-LIST.md` — domain, test-runner, mechanical-runner, and secret-scanner detection signals + authoritative `/cook` flag inventory (single source of truth for Step 2 fingerprint and Step 4 flag validation)
- `refs/schema.md` — sub-skill interface contract, output JSON schema, verdict semantics
- `refs/modes/quality.md` — Quality mode: flags, orchestrator rubric (extends `/cook`'s flag coverage with orchestrator-owned checks), and sub-agent prompt amendment
- `refs/modes/coverage.md` — Coverage mode: test-runner protocol
- `refs/modes/functional.md` — Functional mode: eval-set assertion protocol
- `refs/modes/security.md` — Security mode: flags and what it checks
- `refs/modes/performance.md` — Performance mode: flags and what it checks
