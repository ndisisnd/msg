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

Platform-agnostic engineering agent with three modes — `--plan`, `--build`, `--review` —
each a distinct protocol in its own ref file, selected by the invocation flag. This file
routes; the shared spine that runs for every mode is `refs/protocol-core.md` (Steps 0–6),
and it never runs a mode's work itself.

## Routing (Step 0 — full rules in `refs/protocol-core.md`)

Read the invocation flag and load exactly one mode protocol:

| Flag | Read |
|------|------|
| `--plan` | `refs/plan/protocol.md` |
| `--plan report=<path>` | `refs/plan/fix-plan.md` (instead of `protocol.md`) |
| `--build` | `refs/build/protocol.md` — **unless an orchestrator spawned you as a build packet**, in which case read `refs/build/protocol-packet.md` instead and stop; it is the whole leaf contract |
| `--build report=<path>` | `refs/build/fix-build.md` (instead of `protocol.md`) |
| `--review` | `refs/review/protocol.md` |

**Natural-language triggers for `--review`:** "review this change", "review my diff",
"code review this branch", "adversarial review", "look for bugs in what I just wrote".
Anything asking for *style, naming or standards* is `/cook`, not this mode.
**`--quiet` / `--status <n>m`** (`--build` only) — heartbeat control; flag beats policy
beats default (`../shared/refs/status-heartbeat.md`).

Exactly one mode flag must be present — zero, several, or the retired `--todo` hard-fail
with the exact messages in `refs/protocol-core.md` § Step 0. Then read the active mode
file **fully** and run the spine end-to-end:

## The shared spine (`refs/protocol-core.md`)

- **Step 1 — Input validation.** PRD/exec-table source (mode flag + `prd-path` + `rows` + `agent`, hard-refuse on any missing) or the `report=<path>` alternate; more than one source is a hard failure. `--review` is exempt from Steps 1–4 — its input is the working diff; go straight to Step 5.
- **Step 2 — Pre-flight, one pass.** Orchestrated fast path works from injected scoped excerpts (full PRD only as escape hatch); standalone path reads the full PRD, verifies row ownership mechanically via `script-prd-digest.py --verify-rows`, and reads devkit + the row-relevant codebase in parallel.
- **Step 3 — Summary + approval gate.** 3–4 line summary, then `AskUserQuestion` (Yes / needs correction / follow-up → the Step 3a interview). Never proceed without an explicit "Yes, proceed" (pre-approved under an autonomy contract).
- **Step 4 — Coding standards (`--build` only).** Injected standards payload wins; else derive the `/cook` flag set and consult the persistent standards cache (`script-standards-cache.py`) before calling `/cook` (v5.6.5; `../shared/refs/session-cache.md` § Consumers).
- **Step 5 — Run the active mode's work** per its ref, then the closing message (`../shared/refs/closing-message.md`) as the last chat output, doctor-logging harness incidents (`../shared/refs/doctor-logging.md`).
- **Step 6 — Scope enforcement, continuous.** Only the assigned rows; unresolvable ambiguity is surfaced as a gap (plan/review) or blocks and asks (build) — never resolved by assumption.

## References

- `refs/protocol-core.md` — the shared spine, Steps 0–6: routing + hard-fail messages, input validation, pre-flight, approval gate + interview, standards resolution, mode dispatch, scope enforcement
- `refs/plan/protocol.md` — `--plan`: summary content, output contract, exact-identifier rule, **the `## Todos — <Agent>` ticket-writing spec** run in the same pass, and the mechanical closing check. `refs/plan/template-todo.md` — the ticket schema `--build` reads mechanically. `refs/plan/template-eng-plan.md` — the two output shapes and the rule that picks between them. `refs/plan/fix-plan.md` — the `report` source for planning fixes
- `refs/build/protocol.md` — `--build`: branch contract, `report` source, coding-standards flag table, work steps, the Step-5a whole-change review spawn, commit/PR contract. `refs/build/protocol-packet.md` — the **orchestrated build leaf's** self-contained fast path, read *instead of* protocol.md and this file when a leaf is spawned by `plan-em`; keeps the db-touch pause and the v5.3 review artifact. `refs/build/fix-build.md` — `report` source + the finding→issue-ticket projection and `kind` discriminator
- `refs/review/protocol.md` — `--review`: change-set resolution, reviewer inputs, the adversarial charter + exclusion list, the A4 what-vs-how exception, severity discipline (`source: eng:review`), the blocker/high-before-commit-confirm rule, the JSON return contract, the subagent spawn rules. One review, whole-change, run by an agent that did not write the code
- `.claude/scripts/` — `script-eng-db-touch.sh` (production/data guardrail; a tripped check pauses for sign-off) · `script-eng-comment-scan.sh` (deterministic A4 comment scan) · `script-eng-commit-cap.sh` (A5 commit-size measurement, advisory; the `Oversize-reason:` trailer pairing is not — `TRAILER_MISSING`, exit 3) · `script-eng-plan-shape.py` (the `--plan` closing check, eight fail-loud checks) · `script-project-findings.py` (the ONE finding→issue-ticket projection + issues-file validator; read-only, shared with `--gui`) · `script-eng-fix-grade.py` (the executable fix-complexity rubric + tier→model mapping; escalate `simple`→`complex`, never downgrade) · `script-eng-close-loop.py` (the only sanctioned write to an issues file)
- `../shared/refs/status-heartbeat.md` — the `--quiet`/`--status` heartbeat contract
- **Contract:** the `## Engineering — <Agent>` and `## Todos — <Agent>` headings written by `--plan` (same pass) are how `plan-em` detects the section is ready and how `--build` locates its spec. Do not rename them.
