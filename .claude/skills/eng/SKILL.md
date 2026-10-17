---
name: eng
description: >
  Platform-agnostic engineering agent with three modes: --plan (propose file changes for human approval AND write the per-feature todo tickets in the same pass), --build (write code from the todo tickets — the single and final build spec), --review (one adversarial whole-change review of the working diff, run by a separate reviewer subagent — spawned by --build automatically, and available standalone on any branch at any time). Use --review when the user says "review this change", "review my diff", "code review this branch", or invokes /eng --review. Invoked by plan-em or directly by the user.
argument-hint: "<--plan | --build | --review> [report=<path>] [--quiet | --status <n>m]"
allowed_tools:
  - Bash
  - Read
  - Write
  - Edit
  - Skill
  - AskUserQuestion
  - Agent
---

# eng

Platform-agnostic engineering agent with three modes — `--plan`, `--build`, `--review`. This file routes. The shared spine for every mode is `refs/protocol-core.md` (Steps 0–6); it never runs a mode's work itself.

## Routing — the one routing table

Read the invocation flag and load exactly one mode file:

| Flag | Read |
|------|------|
| `--plan` | `refs/plan/protocol.md` |
| `--plan report=<path>` | `refs/plan/fix-plan.md` |
| `--build` (manual run) | `refs/build/protocol.md`, which runs the build loop in `refs/build/protocol-packet.md` |
| `--build` (spawned by an orchestrator as a build packet) | `refs/build/protocol-packet.md` only — it is the whole leaf contract; stop reading here |
| `--build report=<path>` | `refs/build/fix-build.md` |
| `--review` | `refs/review/protocol.md` |

**Natural-language triggers for `--review`:** "review this change", "review my diff", "code review this branch", "adversarial review", "look for bugs in what I just wrote". Anything about *style, naming or standards* is `/cook`, not this mode.

**`--quiet` / `--status <n>m`** (`--build` only) — progress-message control; flag beats policy beats default (`../shared/refs/status-heartbeat.md`).

Exactly one mode flag must be present. Zero, several, or `--todo` hard-fail with the messages in `refs/protocol-core.md` § Step 0. Then read the active mode file **fully** and run the spine end to end.

## The shared spine (`refs/protocol-core.md`)

- **Step 1 — Input validation.** The PRD/exec-table source (mode flag + `prd-path` + `rows` + `agent`) or the `report=<path>` alternate. `--review` skips Steps 1–4.
- **Step 2 — Pre-flight, one pass.** Injected scoped excerpts on an orchestrated run; otherwise the PRD (the digest on `--build`), devkit and the row-relevant code. Row ownership is checked by `script-prd-digest.py --verify-rows`.
- **Step 3 — Summary gate (`--plan` only).** `--build` asks no opening question; a manual build asks one question at the end, "Commit?".
- **Step 4 — Coding standards (`--build` only).** An injected payload wins; else `script-eng-cook-flags.py` + the standards cache, then `/cook` on a miss.
- **Step 5 — Run the mode's work**, then the closing message (`../shared/refs/closing-message.md`).
- **Step 6 — Scope enforcement, continuous.** Only the assigned rows.

## References

- `refs/plan/protocol.md` — `--plan`: summary, output contract, the `## Todos — <Agent>` ticket spec, the closing shape check. `refs/plan/template-todo.md` — the ticket schema the build reads. `refs/plan/template-eng-plan.md` — the plan section shapes. `refs/plan/fix-plan.md` — planning fixes from a `report`.
- `refs/build/protocol.md` — the manual build's solo-only steps (branch, ticket check, standards, progress messages, "Commit?", sub-branch PR, summary and run report). `refs/build/protocol-packet.md` — **the build loop**, written once: tickets, TDD, full-suite gate, review and re-test, db-touch pause, one commit per ticket, output. `refs/build/protocol-build-debug.md` — debug mode. `refs/build/fix-build.md` — the `report` source. `refs/build/fix-build-orchestrated.md` — the fix coordinator.
- `refs/review/protocol.md` — `--review`: change set, adversarial charter, severity, return contract, artifact, spawn rules. One review, whole change, by an agent that did not write the code.
- `.claude/scripts/` — `script-eng-db-touch.sh` (production/data guardrail over this run's changes; a trip pauses for sign-off) · `script-eng-cook-flags.py` (the `/cook` flag set from the stack) · `script-eng-comment-scan.sh` (A4 comment presence) · `script-eng-commit-cap.sh` (A5 commit size, advisory; a missing `Oversize-reason:` trailer exits 3) · `script-eng-plan-shape.py` (the `--plan` closing check) · `script-project-findings.py` (the one finding→issue-ticket projection + issues-file validator) · `script-eng-fix-grade.py` (fix complexity + tier→model) · `script-eng-close-loop.py` (the only write to an issues file)
- `../shared/refs/status-heartbeat.md` — the progress-message contract
- **Contract:** the `## Engineering — <Agent>` and `## Todos — <Agent>` headings written by `--plan` are how `plan-em` detects a finished section and how `--build` finds its tickets. Do not rename them.
