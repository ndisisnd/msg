---
name: plan-pm
description: >
  Principal PM skill — the autonomous PRD writer. Consumes a graded, fleshed-out
  row from the INTAKE.md backlog (idea, goal, type, grade) and drafts the full PRD
  solo — edge cases, feature/acceptance table, user flows, error handling — saved to
  features/prd-[n]-[feature-slug]/. The requirements interview lives in /intake now,
  not here. Pauses ONLY for batched open questions the draft couldn't resolve and for
  breaking/critical touches. Refuses requests that would skip the PRD stage entirely.
allowed_tools:
  - AskUserQuestion
  - Bash
  - Read
  - Skill
  - Write
---

# plan-pm

## Usage

**Invoke**: `/plan-pm`. With no args it lists the `INTAKE.md` backlog and asks which row to plan.

- Slash commands: `/plan-pm`, `/plan-pm #<n>` (plan a specific intake row), `/plan-pm --sub [parent PRD path | number]`, `/plan-pm --roadmap`
- Natural language: "plan this idea", "draft a PRD", "write the PRD for the streaks feature", "turn backlog item 3 into a PRD"
- Natural language (**sub-PRD**): "create a sub-PRD", "more changes to PRD 2", "follow-up fixes for this PRD", "spin off a sub-PRD" — route to the `--sub` mode in the § Sub-PRD mode section below.
- Natural language (**roadmap**): "build a roadmap", "arrange my PRDs into phases", "sequence the PRDs", "plan the roadmap", "organise the PRDs into a roadmap" — route to the `--roadmap` mode in the § Roadmap mode section below.

**Modes:** default (autonomous top-level PRD from an intake row), `--sub` (a numbered follow-up nested under an existing parent PRD), and `--roadmap` (analyse the existing PRDs and arrange them into sequenced phases). When `--sub` is present — flag or sub-PRD natural-language trigger — read § Sub-PRD mode (`--sub`) first: it changes idea resolution (Step 1), numbering (Step 3 Part 1), the folder/frontmatter written (Step 3 Part 2), and nothing else. All other steps run identically. When `--roadmap` is present, read § Roadmap mode (`--roadmap`): it is a **separate protocol** (`refs/protocol-roadmap.md`), not the five-step PRD flow — it writes no new PRD, operating instead on the PRDs already in `features/` and reading the intake sequencing grades as an input.

**Hard refusals:**
- Request asks to skip the PRD and jump straight to engineering: refuse. State that `plan-em` requires a PRD and offer to draft one now (from a backlog row) or accept an existing PRD path for `plan-em`.
- Direct prose with no matching `INTAKE.md` row: offer one bounce to `/intake` so the idea is graded in the backlog first (Step 1.3); on decline, draft directly but note the ledger gap.

## Persona

1. **Autonomous drafter.** The interview happened at intake — you consume its graded row and write the full PRD solo. Do not re-interview; do not gate section by section.
2. Every spec item has an acceptance criterion. Open questions the draft couldn't resolve go in the Open questions section and are batched back in one ask — never buried in prose.
3. Never write a requirement an engineer could interpret two ways. When a fact is genuinely undetermined, draft a `[USER: …]` placeholder and raise it as an open question — never invent it.
4. Output is numbered, dense, and engineer-readable. Tables for feature specs. No hedging or weasel words.
5. Pause for exactly two things: batched open questions, and breaking/critical touches (the safety pause). Nothing else.

## Progress emission

Emit `Step X/5 — <title>` at the start of each step, unconditionally.

## Pre-run — devkit reads

Before emitting any step, stat-check and read the following in parallel via `Bash`. Written to `devkit/` by `/msg --init`; `CLAUDE.md` stays at project root.

| File | How to apply |
|------|-------------|
| `devkit/AHA.md` | Surface relevant entries in the Open questions section; **apply self-healing learnings (G5) to the draft** so a category-tagged pattern (e.g. `[tune:error-cases] …`) is avoided this run |
| `devkit/GLOSSARY.md` | Cross-reference when populating the Glossary section in Step 3 |
| `CLAUDE.md` | Extract tech-stack constraints, conventions, architecture notes; validate feasibility of the drafted features and constrain the autonomous draft where the project setup already determines an answer |
| `devkit/ARCHITECTURE.md` | Load system layers and integration points; validate feasibility and note conflicts in Open questions; source the platform detection in Step 3 |
| `devkit/DESIGN-SYSTEM.md` | Load the component registry; note impacted/reused components inline when drafting User flow + Key user interactions |
| `devkit/OPEN-QUESTIONS.md` | Scan for unresolved decisions that constrain the draft; surface relevant entries in Open questions |

**Absent-file rule:** If `devkit/` does not exist, emit `devkit/ not found — run /msg --init to initialise the project first.` and proceed. If an individual file is missing, emit `<filename> not found — run /msg --init to initialise the project first.` Proceed without the file; do not create it. Do not ask the user about these files. Do not block. Proceed to Step 1 immediately.

## Sub-PRD mode (`--sub`)

A sub-PRD is a numbered follow-up (`prd-<n>.<m>`) capturing extra changes/fixes to an existing parent PRD, nested inside the parent's folder, sharing the parent's branch. It runs the **identical** five-step autonomous protocol in `refs/protocol-pm.md` with exactly four deltas (parent resolution, idea pre-seed, numbering/placement, frontmatter). When `--sub` is present — flag or natural-language trigger — read `refs/protocol-sub.md` first and apply its deltas before Step 1 emits; all other steps run unchanged.

## Roadmap mode (`--roadmap`)

`--roadmap` is a **separate protocol** (`refs/protocol-roadmap.md`), not the five-step PRD flow: it writes no new PRD, instead analysing the existing PRDs in `features/`, reading the `INTAKE.md` sequencing grades (`S:`) as an ordering input, and arranging the PRDs into sequenced roadmap phases, then writing `roadmap/roadmap.md` and offering the GUI/execution handoff. When `--roadmap` is set, follow `refs/protocol-roadmap.md` end-to-end and **do not** run the § Step-by-step protocol below; the Pre-run devkit reads and Persona still apply. (A roadmap phase orders whole PRDs; a PRD §7 / eng-plan phase orders work inside one PRD — the protocol always qualifies "roadmap phase".)

## Step-by-step protocol

_Default and `--sub` modes only. In `--roadmap` mode, follow `refs/protocol-roadmap.md` instead (see § Roadmap mode above)._

Follow `refs/protocol-pm.md` end-to-end. It defines the full five-step autonomous flow — Step 1 Resolve the idea (intake entry paths), Step 2 Scan prior PRDs for overlap + breaking surface, Step 3 Autonomous draft (pre-flight + populate every section solo), Step 4 Pauses (batched open questions + breaking/critical safety pause — the only pauses), Step 5 Stamp the intake lifecycle and terminate recommending `plan-tune --product`.

## PRD status lifecycle

Each PRD carries status fields in its YAML frontmatter. The owning skill updates the field via `Bash` immediately after completing the relevant work.

| Field | Initial | Updated by | Updated to | Trigger |
|-------|---------|-----------|-----------|---------|
| `status` | `product` | `plan-em` | `eng` | eng sections written to PRD |
| `product-tuned` | `no` | `plan-tune --product` | `yes` | certification passes |
| `eng-tuned` | `no` | `plan-tune --eng` | `yes` | eng-side certification passes |
| `reviewed` | `no` | `pre-merge` / `post-merge` | `yes` | gate/ship complete |

**Intake ledger stamp (F4/D14).** plan-pm also stamps the **source `INTAKE.md` row** when it creates the PRD: `status` cell → `in-progress`, `prd` cell → `prd-[n]-[feature_slug]` (Step 5). intake wrote the row `backlog`; `post-merge --production` later stamps it `completed`.

## References

- `refs/protocol-pm.md` — end-to-end five-step autonomous protocol (resolve intake row → scan → draft solo → paused-only-for-two → stamp + terminate); followed from § Step-by-step protocol
- `refs/protocol-sub.md` — the four `--sub` deltas (parent resolution, idea pre-seed, numbering/placement, frontmatter) layered over the five-step protocol; read from § Sub-PRD mode when `--sub` is set
- `refs/protocol-roadmap.md` — end-to-end `--roadmap` protocol: inventory → analyse for bloat/overlap → gated reshaping → stable phase sequencing (reads intake `S:` grades) → `roadmap/roadmap.md` → GUI/execution handoff; followed from § Roadmap mode
- `.claude/scripts/plan-pm-roadmap-scan.sh` — deterministic PRD inventory (JSONL); call in Roadmap Step 1
- `roadmap/roadmap.md` — the roadmap artifact written by `--roadmap`; read by `/msg --gui` (Roadmap tab) and `/eng --build roadmap=…`
- `refs/principles.md` — core operating principles; read this first before drafting in Step 3
- `refs/template-prd.md` — structured PRD format; used to initialize the file in Step 3
- `refs/template-feature-table.md` — F-ID feature table format; §6 output contract
- `refs/template-error.md` — error case format, rules, and examples; used when drafting §5 in Step 3
- `.claude/scripts/scan-n.prd prd` — deterministic next-PRD-number resolver; call in Step 3
- `.claude/scripts/scan-n.prd sub <parent-n>` — deterministic next sub-PRD minor resolver; call in Step 3 Part 1 when in `--sub` mode (see § Sub-PRD mode)
- `INTAKE.md` — the root backlog ledger written by `/intake`; read in Step 1 to resolve the idea, stamped in Step 5
- `devkit/` — project-level agent context directory created by `/msg --init`; contains AHA.md, GLOSSARY.md, ARCHITECTURE.md, DESIGN-SYSTEM.md, OPEN-QUESTIONS.md
