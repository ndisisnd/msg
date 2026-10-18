---
name: plan-em
description: >
  Engineering Manager skill. Reads an approved PRD, runs pre-flight checks against
  AHA.md, GLOSSARY.md and ARCHITECTURE.md, auto-runs plan-review certification inline
  (no ask), picks the specialist agents (it asks to approve the roster only when the
  roster is unusual for the project), spins them up to write engineering sections
  directly into the PRD, then prints a short digest. Never builds automatically: every
  run stops after the plan half and asks "Start the build now?"; No ends the run and a
  later /plan-em resumes at the build half. The PRD's intake grade picks the check before
  the build: a mechanical plan-shape check on a medium PRD, the eng certification on a
  large one. An Opus orchestrator engineer decomposes each half into file-disjoint,
  model-tiered packets fanned out to leaf eng subagents. Refuses without a referenced
  PRD .md path.
argument-hint: "<prd-path> [--review [on|off]]"
allowed_tools:
  - Agent
  - AskUserQuestion
  - Bash
  - Edit
  - Read
  - Skill
  - Write
---

# plan-em

**This file is a router.** The five-step protocol lives in `refs/protocol-em.md` and the team-lane fan-out in `refs/protocol-team.md` — neither is restated here.

## Usage

**Invoke**: `/plan-em <prd-path>`. The PRD path is a `.md` file inside a PRD folder in any lane — `features/{planned,wip,done}/prd-[n]-[slug]/` or the legacy flat `features/prd-[n]-[slug]/`.

- Slash command: `/plan-em` · natural language: "engineering plan for <PRD>", "scope this PRD", "spin up eng agents" · context: a path to an existing approved PRD `.md` file, typically passed forward from `plan-pm` or `plan-review`
- Progress messages are always on, every 5 minutes (`../shared/refs/status-heartbeat.md`)
- `/plan-em <prd-path> --review` — run the plan-review eng check at the end of the plan half, this run only. `--review on` / `--review off` (or "always review the plan") — save it for the project:

  ```bash
  .claude/scripts/script-policy-set.py --file devkit/policy.json --set policies.plan_em.review=<true|false>
  ```

  No `devkit/policy.json` (a project set up before the file existed) → say `/msg --update` adds it, and use the value for this run only. Absent = off: the closing message suggests `/plan-review` instead. The certification gate still runs plan-review on an uncertified PRD either way.

**Hard refusals:**
- Invocation without a PRD path: refuse. State that `plan-em` requires an existing PRD. Offer two paths: run `/plan-pm` to create one, or supply a path to an existing PRD `.md` file.
- PRD path does not exist or does not match a lane-lifecycle path — `features/{planned,wip,done}/prd-*/prd-*.md` (top-level) or `features/{planned,wip,done}/prd-*/prd-*/prd-*.md` (nested sub-PRD, per `plan-pm`'s § Sub-PRD mode) — or the legacy flat `features/prd-*/prd-*.md` / `features/prd-*/prd-*/prd-*.md`: refuse. State the expected location.

## Execution mode

plan-em always runs the team lane and never names the lane to the user. At Step 4 it
spawns one **orchestrator engineer agent on Opus** per half, backgrounded and watched, which
decomposes the half into file-disjoint, model-tiered packets for leaf `eng` subagents
(`refs/protocol-team.md`). A hidden `--solo` flag (maintainers and debugging) runs one
leaf per roster stack for that run only; it is never saved (`refs/protocol-em.md` Step 0).

## Run shape and size tier

plan-em never builds automatically. Every run plans, prints a short summary, and asks
**"Start the build now?"**. Yes → the build half runs in the same run. No → the run ends;
a later `/plan-em` on the same PRD resumes at the build half. A run that dies resumes the
same way.

The **size tier**, resolved once from the intake complexity grade (`refs/protocol-em.md`
Step 1e — no flag, no question), picks the check before the build half. Both sizes run
the product certification before planning. `C:` **< 8** or unresolvable ⇒ **medium**: a
mechanical plan-shape check. `C:` **≥ 8** ⇒ **large**: the plan-review eng certification.

## Inputs

| Name | Format | Source |
|------|--------|--------|
| PRD file path | `.md` file path matching `features/{planned,wip,done}/prd-*/prd-*.md` (or legacy flat `features/prd-*/prd-*.md`) | User message at invocation, or handoff from `plan-pm` / `plan-review` |
| Clarification answers | `AskUserQuestion` selections | Human during ambiguity resolution and an unusual-roster approval |

## Outputs

| Name | Format | Destination |
|------|--------|-------------|
| Pre-flight report | Markdown findings file — **written only when the scan found something**; a clean run emits one inline line and no file | `features/prd-[n]-[slug]/preflight.md` |
| Engineering sections | Structured markdown per agent | Appended to the PRD file |
| Run digest | Built · Branch · Review · Findings lines, Critical findings listed below | Emitted inline above the closing message |
| Stage timing log | Append-only TSV, one line per stage boundary | `features/prd-[n]-[slug]/reports/timings-<date>.log` |

**No separate engineering plan files — all output lives in the PRD.** The pre-flight
report is the one exception, and it sits inside the PRD's own folder. `[n]` is the first
numeric segment of the input PRD's parent directory name; `[slug]` is the remainder.
Resolve the actual matched directory once at Step 1 and write every artifact relative to
it — do not reconstruct a bare `features/prd-[n]/` path.

## Step-by-step protocol

Follow `refs/protocol-em.md` end-to-end — it owns the steps, their order, their scripts, and their outputs. Step 4 hands each half to the orchestrator whose protocol is `refs/protocol-team.md`.

**Closing message (every outcome):** end with the closing message per `../shared/refs/closing-message.md` — the last chat output, after Step 5's digest. Take the next step from the registry's `plan-em` row; never compose it, never invoke it.

**Harness incidents (both lanes):** log unexpected script failures, tool errors, retries, and missed writes to `devkit/DOCTOR.md` per `../shared/refs/doctor-logging.md` — logging never changes what the run does next.

## References

- `refs/protocol-em.md` — end-to-end execution protocol (Step 0 mode resolve + five steps); followed from § Step-by-step protocol
- `refs/protocol-team.md` — the Opus orchestrator engineer's protocol, spawned at Step 4 · `refs/template-exec-table.md` — execution-table shape + concern checklist (Step 3)
- `../shared/refs/` — `closing-message.md` · `doctor-logging.md` · `status-heartbeat.md`
- `.claude/skills/eng/SKILL.md` — eng agent entry point; Step 4 subagents read this and run `--plan` or `--build` mode · `.claude/skills/eng/refs/plan/template-todo.md` — the todo ticket schema consumed by build agents
