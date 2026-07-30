---
name: eng --build — report orchestrated
description: The default route for eng --build report=<path>. An Opus fix-build orchestrator session that reads the fix plan (or projects issues from the issues file report-prd-<N>-<K>.json), grades each issue simple|complex, and fans the fixes out to per-issue subagents (model=sonnet for simple, model=opus for complex). Bypassed by orchestrate=off, which runs the flat single-agent flow in fix-build.md.
type: reference
---

# eng --build — `report` orchestrated

Loaded **by default** when `--build` is invoked with `report=<path>` (the `orchestrate=on` default — see `fix-build.md` § Orchestration routing). Pass `orchestrate=off` to skip this orchestrator and run the flat single-agent flow documented in `fix-build.md` instead.

This ref owns only the **orchestration layer** — session model, plan/rubric-driven complexity grading, per-issue subagent fan-out, post-return re-verification, and loop-close. Every leaf contract it drives — the finding→issue-ticket projection, the per-issue reproduce→fix→verify-green flow, one-commit-per-issue, the 3-cycle debug escalation, and the `followUp.status` write — lives in the sibling refs below and is **cited, never duplicated**.

## Session model — Opus orchestrator

This session runs as **Opus** and does not write code itself. It coordinates per-issue fix **subagents** spawned via the `Agent` tool, keeping the orchestrator on Opus regardless of which tier each subagent runs on. The only tiers in play are the two named in § Complexity rubric (fast and deep).

## Step 0 — Load tickets + complexity grades

Resolve the issue set and each issue's `complexity` (`simple` | `complex` — § Complexity rubric), in priority order:

1. **Fix plan present** — `features/prd-<N>-<slug>/reports/report-prd-<N>-<K>-fix-plan.md` exists (same `<N>`/`<K>` as the issues file; written by `eng --plan report=…` per `../plan/fix-plan.md`). Read its tickets and take each ticket's `complexity` tag as authoritative. This is the normal path — `pre-merge`/`post-merge` reach here through the § fix-loop offer sequence (`../../../shared/refs/fix-loop.md`), which plans before it builds.
2. **No fix plan** — project the tickets directly from the issues file's `issues[]` using the **finding→issue-ticket projection in `fix-build.md`** (§ Finding → issue-ticket projection — read-time view, never a rewrite; cite, do not re-derive), then grade each projected issue's `complexity` yourself via the rubric below.

## Complexity rubric

**This is the one definition of simple-vs-complex in eng.** `../plan/fix-plan.md` grades ahead of time by citing it; this file carries it because it is the fallback grader when no plan tag exists. When Step 0 falls back to grading (no plan, or a ticket carries no `complexity`), grade each issue here. The plan's tag, when present, always wins.

- **simple → fast tier** — single-file (`files` length ≤ 1); a clear `suggestion` is present; `category` ∈ {mechanical/lint/format/typecheck, dead-code, duplication, readability, naming, coverage}; or a localized single-assertion `unit` failure with a small `repro`.
- **complex → deep tier** — multi-file (`files` length > 1); `category` ∈ {security, migration/schema, architecture, performance/perf, integration, e2e, contract}; no `suggestion`; `regression_of` is set (recurring); or `file` is `null` (a suite-level finding).

On mixed or ambiguous signals, grade **complex** — an over-powered subagent is safe; an under-powered one on a security/migration fix is not.

**Tier → model (the one mapping line):** fast tier = `model: sonnet` · deep tier = `model: opus`. A model-family change is this line, nowhere else.

## Step 1 — Route each issue to a fix subagent

For each issue/ticket, spawn one fix subagent via the `Agent` tool with `model` set from the grade's tier (§ Complexity rubric — tier → model), per the § Subagent contract below. In particular:

- Each subagent runs the msg skill `eng --build report=<path>` scoped to its **single** issue, with `branch` defaulted from the issues file's `context.branch` and `commit_mode=direct` (per `fix-build.md` § Branch default).

Independent issues fan out in parallel (spawn in a single message). Order any issue whose fix another issue depends on first — findings carry no `depends-on`, so this only matters when two issues touch the same file; serialize those onto one subagent to avoid a race on the shared branch.

## Subagent contract

Every fix subagent is spawned via the `Agent` tool and **runs an msg skill — never general-purpose**. Each prompt is prefixed with the **autonomy paragraph**:

> You are running autonomously with no user present, as part of an orchestrated fix build. When the skill's protocol reaches an approval gate (`AskUserQuestion`), treat it as pre-approved and proceed. Only stop if genuinely blocked by missing information you cannot derive — if so, return the blocker instead of guessing. Read `.claude/skills/<skill>/SKILL.md` fully and follow its protocol.

**Injected context.** The orchestrator has already read the issues file, so each prompt carries the subagent's **single** issue-ticket (its `files`, `repro`, `done-when`, and preserved diagnostic fields) rather than making the leaf re-read and re-project the whole issues file. Include this escape hatch in the prompt: *"The full issues file is at `<report-path>`; read it on demand only if the scoped ticket is insufficient."* Scope-enforcement and the branch contract are unchanged — the subagent touches only its own issue's files and commits only to `branch`.

**Return contract:** each subagent returns a single JSON summary object (the `Issue`-keyed build summary from `fix-build.md` § Output contract) — **never** free-form prose. A subagent that dies or returns unparseable output is treated as a failed stage and re-spawned once; a second failure escalates.

## Step 2 — Per-issue fix flow (inside each subagent)

Each subagent runs the **existing per-issue fix flow — cited, not duplicated**:

- The reproduce → fix → verify-green collapse (Item 4a/b/c) and flaky handling in `fix-build.md` § Work-step deltas.
- **One commit per issue** — `protocol.md` Step 7 (one-commit-per-ticket) applied per issue-ticket, with its two mechanical staged-diff gates (comment scan, commit cap).
- A still-red issue at verify-green enters the bounded **3-cycle debug escalation** (`protocol-build-debug.md`) inside the subagent, exactly as the flat flow does.

## Step 3 — Re-verify on return, then re-enter if still red

After a subagent returns, the **orchestrator re-runs that ticket's covering test / `done-when`** itself before marking the ticket done — a subagent's self-reported green is not trusted blind. Then:

- **Green** — mark the ticket done; record it in the run ledger.
- **Still red** — re-enter the same subagent with the residual failure, **bounded**: reuse the 3-cycle debug escalation from `protocol-build-debug.md` at the orchestrator level (max 3 re-entry cycles per ticket). After the 3rd failed re-entry, stop re-spawning, mark the ticket `partially_resolved`, and carry its escalation into the loop-close below — never spin a ticket indefinitely.

## Step 4 — Close the loop

Once every ticket is done or escalated, write the **single** issues-file mutation — `followUp.status` — per the existing contract in `fix-build.md` § Closing the loop (cite, do not duplicate):

- every issue verified green → `"resolved"`
- one or more issues escalated (3-cycle bound hit) or left unreproduced (flaky) → `"partially_resolved"`

This is the **only** write to the issues file `features/prd-<N>-<slug>/reports/report-prd-<N>-<K>.json`; `issues[]` and every other field stay canonical (the projection was read-time only). Emit an `Issue`-keyed roll-up summary (per-ticket status + assigned model) so the human/`--gui` board sees which model fixed each issue and which escalated. After loop-close the user re-runs the gate (`/pre-merge` or `/post-merge`) — the fixed branch comes back through the same gate (`fix-loop.md` § Re-entry).

## References (cited, not duplicated)

- `fix-build.md` — finding→issue-ticket projection, per-issue reproduce→fix→verify-green deltas, `Issue`-keyed summary, `followUp.status` loop-close, `orchestrate=off` escape hatch
- `protocol.md` Step 7 — one commit per issue-ticket + the two mechanical commit gates
- `protocol-build-debug.md` — the bounded 3-cycle debug escalation (reused per subagent and per orchestrator re-entry)
- `../plan/fix-plan.md` — writes `features/prd-<N>-<slug>/reports/report-prd-<N>-<K>-fix-plan.md` with the `complexity` tags this orchestrator reads
- `../../../shared/refs/fix-loop.md` — the post-failure offer sequence that routes here as Offer #2
