---
name: plan-em
description: >
  Engineering Manager skill. Reads an approved PRD, runs pre-flight checks against
  AHA.md, GLOSSARY.md and ARCHITECTURE.md, auto-runs plan-review certification inline
  (no ask), identifies specialist agents to activate (roster approval — the single
  human gate), spins them up to write engineering sections directly into the PRD, then
  synthesises the full output. Sizes itself on the PRD's intake grade: a medium PRD
  runs one fused plan+build wave behind one certification, a large PRD keeps the
  two-wave path with a certification before each. Runs in --team mode by default (an Opus orchestrator
  engineer decomposes each wave into file-disjoint, model-tiered packets fanned out to
  leaf eng subagents) or --solo (one leaf subagent per roster stack). Refuses without a
  referenced PRD .md path.
argument-hint: "<prd-path> [--team | --solo] [--quiet | --status <n>m]"
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

**This file is a router.** The five-step protocol lives in `refs/protocol-em.md` and the
team-lane fan-out in `refs/protocol-team.md` — neither is restated here.

## Usage

**Invoke**: `/plan-em <prd-path>`. The PRD path is a `.md` file inside a PRD folder in any lane — `features/{planned,wip,done}/prd-[n]-[slug]/` or the legacy flat `features/prd-[n]-[slug]/`.

- Slash command: `/plan-em`
- Natural language: "engineering plan for <PRD>", "scope this PRD", "spin up eng agents"
- Context: a path to an existing approved PRD `.md` file, typically passed forward from `plan-pm` or `plan-review`
- `/plan-em <prd-path> --quiet` — suppress this run's status heartbeat
- `/plan-em <prd-path> --status <n>m` — override the heartbeat interval for this run; flag beats policy beats default (`../shared/refs/status-heartbeat.md`)

**Hard refusals:**
- Invocation without a PRD path: refuse. State that `plan-em` requires an existing PRD. Offer two paths: run `/plan-pm` to create one, or supply a path to an existing PRD `.md` file.
- PRD path does not exist or does not match a lane-lifecycle path — `features/{planned,wip,done}/prd-*/prd-*.md` (top-level) or `features/{planned,wip,done}/prd-*/prd-*/prd-*.md` (nested sub-PRD, per `plan-pm`'s § Sub-PRD mode) — or the legacy flat `features/prd-*/prd-*.md` / `features/prd-*/prd-*/prd-*.md`: refuse. State the expected location.

## Execution mode

Two mutually exclusive execution lanes, selected by a flag on invocation — **`--team`
is the default**. The flag changes only **how the wave is dispatched at Step 4**; every
other step is identical in both lanes.

| Flag | Lane | Step 4 dispatch |
|------|------|-----------------|
| `--team` (default) | **Team** | one **orchestrator engineer agent on Opus** decomposes the wave below the roster/stack level into file-disjoint, model-tiered packets and fans them out to leaf `eng` subagents. |
| `--solo` | **Solo** | **one leaf `eng` subagent per roster stack**, whole-stack scope each, on the inherited model. |

The mode is a **persisted preference**, not just a per-run flag. Resolution precedence and
the flag-parse rule live in `refs/protocol-em.md` Step 0; the pref file itself lives in
`.claude/skills/shared/refs/exec-mode-pref.md`.

## How many invocations a PRD costs

Independent of the lane above, the run's **size tier** decides how much ceremony the PRD
pays. plan-em resolves it once from the intake complexity grade (`refs/protocol-em.md`
Step 1e) — there is no flag and no question:

| Intake `C:` | Size | Invocations | Certifications |
|-------------|------|-------------|----------------|
| **< 8**, or unresolvable (the default) | medium | **one** — a fused wave plans and builds in a single run | one (product, before the wave); a mechanical plan-shape check replaces the eng cert |
| **≥ 8** | large | two — plan wave, then build wave | two (product before the plan wave, eng before the build wave) |

An interrupted fused run is resumed by re-invoking `/plan-em` on the same PRD: it detects
the written engineering sections and completes the build half. No flag, no state file.

## Inputs

| Name | Format | Source |
|------|--------|--------|
| PRD file path | `.md` file path matching `features/{planned,wip,done}/prd-*/prd-*.md` (or legacy flat `features/prd-*/prd-*.md`) | User message at invocation, or handoff from `plan-pm` / `plan-review` |
| Execution-mode flag | `--team` (default) / `--solo` | User message at invocation |
| Clarification answers | `AskUserQuestion` selections | Human during ambiguity resolution and agent approval |

## Outputs

| Name | Format | Destination |
|------|--------|-------------|
| Pre-flight report | Markdown findings file | `features/prd-[n]-[slug]/preflight.md` |
| Engineering sections | Structured markdown per agent | Appended to the PRD file |
| Synthesis report | Numbered findings with severity | Emitted inline at end of run |

**No separate engineering plan files — all output lives in the PRD.** The pre-flight report
is the one exception, and it sits inside the PRD's own folder.

`[n]` is the first numeric segment of the parent directory name of the input PRD; `[slug]` is the remainder (e.g., `features/prd-3-habit-tracking/prd-3-habit-tracking.md` → `n=3`, `slug=habit-tracking`). Resolve the actual matched directory once at Step 1 and write every artifact relative to it — do not reconstruct a bare `features/prd-[n]/` path.

## Step-by-step protocol

Follow `refs/protocol-em.md` end-to-end — it owns the steps, their order, their scripts, and
their outputs. In `--team` mode Step 4 hands the wave to the orchestrator whose protocol is
`refs/protocol-team.md`.

**Closing message (both lanes, every outcome):** end the run with the closing message per
`../shared/refs/closing-message.md` — the last chat output, after Step 5's synthesis. Take the
next step from the registry's `plan-em` row; never compose it. There is **no next-steps menu**:
plan-em recommends the next command, it never invokes the next stage itself.

**Harness incidents (both lanes):** log unexpected script failures, tool errors, retries, and missed writes to `devkit/DOCTOR.md` per `../shared/refs/doctor-logging.md` — logging never changes what the run does next.

## References

- `refs/protocol-em.md` — end-to-end execution protocol (Step 0 mode resolve + five steps); followed from § Step-by-step protocol
- `refs/protocol-team.md` — the Opus orchestrator engineer's protocol, spawned at Step 4 in `--team` mode
- `refs/template-exec-table.md` — execution-table shape and the concern checklist; used at Step 3
- `.claude/skills/shared/refs/exec-mode-pref.md` — the persisted team/solo pref (`.claude/msg/pref.json`). Shared source of truth.
- `../shared/refs/closing-message.md` — the closing message every run ends with; protocol + next-steps registry (shared)
- `../shared/refs/doctor-logging.md` — the harness-incident ledger contract (shared)
- `.claude/skills/eng/SKILL.md` — eng agent entry point; Step 4 subagents read this and run `--plan` or `--build` mode
- `.claude/skills/eng/refs/plan/template-todo.md` — todo ticket schema written by `eng --plan` and consumed by build agents
- `../shared/refs/status-heartbeat.md` — the `--quiet`/`--status` heartbeat contract
