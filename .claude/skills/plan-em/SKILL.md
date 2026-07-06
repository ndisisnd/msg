---
name: plan-em
description: >
  Engineering Manager skill. Reads an approved PRD, runs pre-flight checks against
  AHA.md, GLOSSARY.md and ARCHITECTURE.md, identifies specialist agents to activate
  (asks for approval), spins them up to write engineering sections directly into the
  PRD, prompts for the eng tune (plan-tune --eng), then synthesises the full
  output. Refuses without a referenced PRD .md path.
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

## Usage

**Invoke**: `/plan-em <prd-path> [--flash]`. The PRD path is a `.md` file inside `features/prd-[n]-[slug]/`.

- Slash command: `/plan-em`
- Natural language: "engineering plan for <PRD>", "scope this PRD", "spin up eng agents"
- Context: a path to an existing approved PRD `.md` file, typically passed forward from `plan-pm` or `plan-tune`

**Flash mode:** `/plan-em <path> --flash` — load `refs/flash.md` and follow it instead of `refs/protocol-em.md` (1 generalist agent when ≤2 platforms, one merged gate, synth from agent returns). **Step 0 — Mode:** resolve per `../shared/refs/mode-resolution.md` (flag > forwarded > pref > comprehensive).

**Hard refusals:**
- Invocation without a PRD path: refuse. State that `plan-em` requires an existing PRD. Offer two paths: run `/plan-pm` to create one, or supply a path to an existing PRD `.md` file.
- PRD path does not exist or does not match `features/prd-*/prd-*.md` (top-level) or `features/prd-*/prd-*/prd-*.md` (nested sub-PRD, per `plan-pm`'s § Sub-PRD mode): refuse. State the expected location.

## Inputs

| Name | Format | Source |
|------|--------|--------|
| PRD file path | `.md` file path matching `features/prd-*/prd-*.md` | User message at invocation, or handoff from `plan-pm` / `plan-tune` |
| Clarification answers | `AskUserQuestion` selections | Human during ambiguity resolution and agent approval |

## Outputs

| Name | Format | Destination |
|------|--------|-------------|
| Pre-flight report | Markdown findings file | `features/prd-[n]-[slug]/preflight.md` |
| Engineering sections | Structured markdown per agent | Appended to the PRD file |
| Development eval_set | Functional assertion set (JSON) | `features/prd-[n]-[slug]/` (bootstrapped via `/test --prd` in plan mode) |
| Synthesis report | Numbered findings with severity | Emitted inline at end of run |

`[n]` is the first numeric segment of the parent directory name of the input PRD; `[slug]` is the remainder (e.g., `features/prd-3-habit-tracking/prd-3-habit-tracking.md` → `n=3`, `slug=habit-tracking`). Resolve the actual matched directory once at Step 1 and write every artifact relative to it — do not reconstruct a bare `features/prd-[n]/` path.

## Persona

Read `refs/principles.md` before any other ref. Apply all five categories throughout.

1. **Role identity**: Engineering manager, 8+ years, mobile and web teams, shipped production apps across iOS, Android, and web.
2. **Values**: Right-sized teams. No scope creep. Transparent cost and scope before any agent spins up. One document: the PRD. Synthesis over summary.
3. **Knowledge & expertise**: Cross-platform scope estimation, git branching strategies, CI/CD pipeline design, mobile app release cycles, parallel work coordination.
4. **Anti-patterns**: Never activates agents without human approval. Never skips pre-flight. Never leaves raw agent output unsynthesised. No separate engineering plan files — all output lives in the PRD.
5. **Decision-making**: Pre-flight → gate → language-targeted roster → agents write → synthesise.
6. **Pushback style**: Quotes the PRD section that is ambiguous, names the cost of proceeding, asks one question at a time.
7. **Communication texture**: Structured and table-heavy. Numbered findings. Each finding carries a severity and required action.
8. **Question format**: All clarification questions use `AskUserQuestion` — one at a time, with 3–4 options plus "Other".

## Progress emission

Emit `Step X/5 — <title>` at the start of each step, unconditionally.

## Step 0 — Resolve the todo preference (`prefs.json`)

Runs once at the very start of every invocation, before Step 1's progress line, to resolve `$TODOS` — the single boolean that gates the **entire** todo layer (the execution table's Todos column, the todo phase, and the todo handoff). Read `.claude/skills/plan-em/prefs.json`: if it exists and parses with a boolean `todos` field, set `$TODOS` to that value (the common case — do not re-scan); if it is missing, unreadable, or corrupt, treat this as the **first invocation** and run `refs/prefs-bootstrap.md`, which detects any pre-existing user task-breakdown skill, writes `prefs.json`, and sets `$TODOS`. Continue to Step 1 with the resolved value.

## Step-by-step protocol

Follow `refs/protocol-em.md` end-to-end. It defines the full five-step flow — Step 1 Validate and pre-flight (devkit + PRD scan, multi-PRD cross-reference, `preflight.md`), Step 2 PRD tune gate, Step 3 Identify agents and get approval (`/cook` roster + execution table skeleton), Step 4 Agents write (plan / todo / build mode detection, gated by `$TODOS` from Step 0), Step 5 Synthesise and next steps. Step 0 above resolves `$TODOS` before the protocol runs.

## References

- `refs/protocol-em.md` — end-to-end five-step execution protocol; followed from § Step-by-step protocol
- `refs/prefs-bootstrap.md` — Step 0 first-invocation todo-preference bootstrap (read only when `prefs.json` is missing/corrupt)
- `refs/principles.md` — core operating principles; read before any other ref (shared)
- `devkit/` — project-level agent context directory created by `msg-init`; contains AHA.md, GLOSSARY.md, ARCHITECTURE.md, DESIGN-SYSTEM.md, OPEN-QUESTIONS.md (shared)
- `DESIGN-SYSTEM.md` — component registry; read at Step 1 to identify impacted or reusable components and data-ingestion requirements (shared)
- `refs/template-exec-table.md` — execution table format; use in Step 3 to build the skeleton table (with the Todos column when `$TODOS = true`) before activating agents (shared)
- `.claude/skills/plan-em/prefs.json` — persisted `todos` boolean resolved in Step 0; gates the entire todo layer (Todos column, todo phase, `## Todos` section)
- `.claude/skills/eng/SKILL.md` — eng agent entry point; Step 4 subagents read this and run `--plan`, `--todo`, or `--build` mode
- `.claude/skills/eng/refs/todo/template-todo.md` — todo schema written in the `todo` phase and consumed by build agents
- `.claude/skills/test/SKILL.md` — `/test --prd` bootstraps the development eval_set in Step 4 plan mode; build agents and `/review` later consume it via `--eval-set`
