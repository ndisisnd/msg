---
name: eng --build — report orchestrated
description: The default route for eng --build report=<path>. An Opus fix-build orchestrator session that reads the fix plan (or projects issues from the issues file report-prd-<N>-<K>.json), grades each issue simple|complex, and fans the fixes out to per-issue subagents (model=sonnet for simple, model=opus for complex). Bypassed by orchestrate=off, which runs the flat single-agent flow in report-fix.md.
type: reference
---

# eng --build — `report` orchestrated

Loaded **by default** when `--build` is invoked with `report=<path>` (the `orchestrate=on` default — see `report-fix.md` § Orchestration routing). Pass `orchestrate=off` to skip this orchestrator and run the flat single-agent flow documented in `report-fix.md` instead.

This ref owns only the **orchestration layer** — session model, plan/rubric-driven complexity grading, per-issue subagent fan-out, post-return re-verification, and loop-close. Every leaf contract it drives — the finding→issue-ticket projection, the per-issue reproduce→fix→verify-green flow, one-commit-per-issue, the 3-cycle debug escalation, and the `followUp.status` write — lives in the sibling refs below and is **cited, never duplicated**.

## Session model — Opus orchestrator

This session runs as **Opus** and does not write code itself. It coordinates per-issue fix **subagents** spawned via the `Agent` tool, keeping the orchestrator on Opus regardless of which tier each subagent runs on. There is no Fable/other tier — the only tiers in play are the two subagent models below (`sonnet` for simple, `opus` for complex).

## Step 0 — Load tickets + complexity grades

Resolve the issue set and each issue's `complexity` (`simple` | `complex`), in priority order:

1. **Fix plan present** — `features/prd-<N>-<slug>/reports/report-prd-<N>-<K>-fix-plan.md` exists (same `<N>`/`<K>` as the issues file; written by `eng --plan report=…` per `../plan/report-fix.md`). Read its tickets and take each ticket's `complexity` tag as authoritative. This is the normal path — `pre-merge`/`post-merge` reach here through the § fix-loop offer sequence (`../../../shared/refs/fix-loop.md`), which plans before it builds.
2. **No fix plan** — project the tickets directly from the issues file's `issues[]` using the **finding→issue-ticket projection in `report-fix.md`** (§ Finding → issue-ticket projection — read-time view, never a rewrite; cite, do not re-derive), then grade each projected issue's `complexity` yourself via the rubric below.

## Complexity rubric (grade only when no plan tag)

When Step 0 falls back to grading (no plan, or a ticket carries no `complexity`), grade each issue against this rubric. The plan's tag, when present, always wins.

- **simple → `model: sonnet`** — single-file (`files` length ≤ 1); a clear `suggestion` is present; `category` ∈ {mechanical/lint/format/typecheck, dead-code, duplication, readability, naming, coverage}; or a localized single-assertion `unit` failure with a small `repro`.
- **complex → `model: opus`** — multi-file (`files` length > 1); `category` ∈ {security, migration/schema, architecture, performance/perf, integration, e2e, contract}; no `suggestion`; `regression_of` is set (recurring); or `file` is `null` (a suite-level finding).

On mixed or ambiguous signals, grade **complex** — an over-powered subagent is safe; an under-powered one on a security/migration fix is not.

## Step 1 — Route each issue to a fix subagent

For each issue/ticket, spawn one fix subagent via the `Agent` tool with `model` set from the grade — `model: sonnet` for `simple`, `model: opus` for `complex`. Reuse the roadmap orchestrator's **Subagent contract** (`protocol-roadmap.md` § Subagent contract) for the spawn spec and the return-JSON discipline — cite it, do not restate it. In particular:

- Prefix each prompt with the **autonomy paragraph** (the subagent runs hands-off; treat the skill's `AskUserQuestion` gates as pre-approved; return the blocker instead of guessing).
- Each subagent runs the msg skill `eng --build report=<path>` scoped to its **single** issue, with `branch` defaulted from the issues file's `context.branch` and `commit_mode=direct` (per `report-fix.md` § Branch default).
- **Return contract:** a single JSON summary object (the `Issue`-keyed build summary from `report-fix.md` § Output contract), never free-form prose. A subagent that dies or returns unparseable output is a failed stage — re-spawn once, then escalate.

Independent issues fan out in parallel (spawn in a single message). Order any issue whose fix another issue depends on first — findings carry no `depends-on`, so this only matters when two issues touch the same file; serialize those onto one subagent to avoid a race on the shared branch.

## Step 2 — Per-issue fix flow (inside each subagent)

Each subagent runs the **existing per-issue fix flow — cited, not duplicated**:

- The reproduce → fix → verify-green collapse (Item 4a/b/c) and flaky handling in `report-fix.md` § Work-step deltas.
- **One commit per issue** — `protocol.md` Step 7 (one-commit-per-ticket) applied per issue-ticket, with its two mechanical staged-diff gates (comment scan, commit cap).
- A still-red issue at verify-green enters the bounded **3-cycle debug escalation** (`protocol-build-debug.md`) inside the subagent, exactly as the flat flow does.

## Step 3 — Re-verify on return, then re-enter if still red

After a subagent returns, the **orchestrator re-runs that ticket's covering test / `done-when`** itself before marking the ticket done — a subagent's self-reported green is not trusted blind. Then:

- **Green** — mark the ticket done; record it in the run ledger.
- **Still red** — re-enter the same subagent with the residual failure, **bounded**: reuse the 3-cycle debug escalation from `protocol-build-debug.md` at the orchestrator level (max 3 re-entry cycles per ticket). After the 3rd failed re-entry, stop re-spawning, mark the ticket `partially_resolved`, and carry its escalation into the loop-close below — never spin a ticket indefinitely.

## Step 4 — Close the loop

Once every ticket is done or escalated, write the **single** issues-file mutation — `followUp.status` — per the existing contract in `report-fix.md` § Closing the loop (cite, do not duplicate):

- every issue verified green → `"resolved"`
- one or more issues escalated (3-cycle bound hit) or left unreproduced (flaky) → `"partially_resolved"`

This is the **only** write to the issues file `features/prd-<N>-<slug>/reports/report-prd-<N>-<K>.json`; `issues[]` and every other field stay canonical (the projection was read-time only). Emit an `Issue`-keyed roll-up summary (per-ticket status + assigned model) so the human/`--gui` board sees which model fixed each issue and which escalated. After loop-close the user re-runs the gate (`/pre-merge` or `/post-merge`) — the fixed branch comes back through the same gate (`fix-loop.md` § Re-entry).

## References (cited, not duplicated)

- `report-fix.md` — finding→issue-ticket projection, per-issue reproduce→fix→verify-green deltas, `Issue`-keyed summary, `followUp.status` loop-close, `orchestrate=off` escape hatch
- `protocol-roadmap.md` § Subagent contract — spawn spec (autonomy paragraph) + return-JSON discipline
- `protocol.md` Step 7 — one commit per issue-ticket + the two mechanical commit gates
- `protocol-build-debug.md` — the bounded 3-cycle debug escalation (reused per subagent and per orchestrator re-entry)
- `../plan/report-fix.md` — writes `features/prd-<N>-<slug>/reports/report-prd-<N>-<K>-fix-plan.md` with the `complexity` tags this orchestrator reads
- `../../../shared/refs/fix-loop.md` — the post-failure offer sequence that routes here as Offer #2
