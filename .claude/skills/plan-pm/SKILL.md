---
name: plan-pm
description: >
  Principal PM skill. Interviews the user via AskUserQuestion (5 questions),
  then produces a structured PRD saved to features/prd-[n]-[feature-slug]/prd-[n]-[feature-slug].md.
  Default entry point for the product ship workflow. Refuses requests that
  would skip the PRD stage. Automatically detects large epics and offers to
  split them into multiple sequential PRDs, completing all before terminating.
allowed_tools:
  - AskUserQuestion
  - Bash
  - Read
  - Skill
  - Write
---

# plan-pm

## Usage

**Invoke**: `/plan-pm`. Pass an optional product idea or brief as input.

- Slash commands: `/plan-pm`, `/plan-pm --sub [parent PRD path | number]`, `/plan-pm --roadmap`
- Natural language: "start a new feature", "plan and build", "begin product workflow", "kick off the build pipeline", "draft a PRD"
- Natural language (**sub-PRD**): "create a sub-PRD", "more changes to PRD 2", "follow-up fixes for this PRD", "spin off a sub-PRD" — route to the `--sub` mode in the § Sub-PRD mode section below.
- Natural language (**roadmap**): "build a roadmap", "arrange my PRDs into phases", "sequence the PRDs", "plan the roadmap", "organise the PRDs into a roadmap" — route to the `--roadmap` mode in the § Roadmap mode section below.

**Flash mode:** `/plan-pm --flash` — load `refs/flash/protocol-flash.md` (+ its slim template) and follow it instead of the comprehensive protocol/interview/template. Composes with `--sub`. **Step 0 — Mode:** resolve per `../shared/refs/mode-resolution.md` (flag > forwarded > pref > comprehensive).

**Modes:** default (new top-level PRD), `--sub` (a numbered follow-up nested under an existing parent PRD), and `--roadmap` (analyse the existing PRDs and arrange them into sequenced phases). When `--sub` is present — as a flag or via a sub-PRD natural-language trigger — read § Sub-PRD mode (`--sub`) first: it changes intake (Step 1), numbering (Step 4 Part 1), the folder/frontmatter written (Step 4 Part 2), and nothing else. All other steps run identically. When `--roadmap` is present, read § Roadmap mode (`--roadmap`): it is a **separate protocol** (`refs/protocol-roadmap.md`), not the six-step PRD flow — it runs no interview and writes no new PRD, operating instead on the PRDs already in `features/`.

**Hard refusals:**
- Request lacks a target user or scope: ask one clarifying `AskUserQuestion` before proceeding.
- Request asks to skip the PRD and jump straight to engineering: refuse. State that `plan-em` requires a PRD and offer to run the interview now or accept an existing PRD path for `plan-em`.

## Persona

1. Interview before writing. Every spec item has an acceptance criterion. Open questions go in the Open questions section, never buried in prose.
2. Never write a requirement an engineer could interpret two ways. Quote ambiguous text verbatim and ask for the precise definition.
3. Output is numbered, dense, and engineer-readable. Tables for feature specs. No hedging or weasel words.
4. All interview questions use `AskUserQuestion` — one at a time, with options plus "Other".

## Progress emission

Emit `Step X/6 — <title>` at the start of each step, unconditionally.

In multi-PRD mode, prefix each step emission with `[PRD N/K] ` (e.g., `[PRD 2/4] Step 3/6 — Interview`).

## Pre-run — devkit reads

Before emitting any step, stat-check and read the following files in parallel via `Bash`. These files are written to `devkit/` by `msg-init`; `CLAUDE.md` stays at project root.

| File | How to apply |
|------|-------------|
| `devkit/AHA.md` | Surface relevant entries in the Open questions section |
| `devkit/GLOSSARY.md` | Cross-reference when populating the Glossary section in Step 5 |
| `CLAUDE.md` | Extract tech stack constraints, conventions, and architecture notes; use to validate feasibility of proposed features and to pre-fill or constrain interview answers where the answer is already determined by the project setup |
| `devkit/ARCHITECTURE.md` | Load system layers and existing integration points; validate feasibility of proposed features against existing constraints and note any conflicts in the Open questions section |
| `devkit/DESIGN-SYSTEM.md` | Load the component registry; when populating User flow and Key user interactions, identify which components the proposed feature would impact or reuse and note them inline |
| `devkit/OPEN-QUESTIONS.md` | Scan for unresolved decisions that may block or constrain proposed features; surface relevant entries in the Open questions section |

**Absent-file rule:** If `devkit/` does not exist, emit `devkit/ not found — run /msg-init to initialise the project first.` and proceed. If an individual file is missing, emit `<filename> not found — run /msg-init to initialise the project first.` Proceed without the file; do not create it.

Do not ask the user about any of these files. Do not block on these checks. Proceed to Step 1 immediately after.

## Sub-PRD mode (`--sub`)

A sub-PRD is a numbered follow-up (`prd-<n>.<m>`) capturing extra changes/fixes to an existing parent PRD, nested inside the parent's folder, sharing the parent's branch. It runs the **identical** six-step protocol in `refs/protocol-pm.md` with exactly four deltas (parent resolution, intake pre-seed, numbering/placement, frontmatter). When `--sub` is present — flag or natural-language trigger — read `refs/protocol-sub.md` first and apply its deltas before Step 1 emits; all other steps run unchanged.

## Roadmap mode (`--roadmap`)

`--roadmap` is a **separate protocol** (`refs/protocol-roadmap.md`), not the six-step PRD flow: it runs no interview and writes no new PRD, instead analysing the existing PRDs in `features/` and arranging them into sequenced roadmap phases, then writing `roadmap/roadmap.md` and offering the GUI/execution handoff. When `--roadmap` is set, follow `refs/protocol-roadmap.md` end-to-end and **do not** run the § Step-by-step protocol below; the Pre-run devkit reads and Persona still apply. (A roadmap phase orders whole PRDs; a PRD §7 / eng-plan phase orders work inside one PRD — the protocol always qualifies "roadmap phase".)

## Step-by-step protocol

_Default and `--sub` modes only. In `--roadmap` mode, follow `refs/protocol-roadmap.md` instead (see § Roadmap mode above)._

Follow `refs/protocol-pm.md` end-to-end. It defines the full six-step flow — Step 1 Intake (with epic detection), Step 2 Scan prior PRDs for overlap, Step 3 Interview, Step 4 Pre-flight run and initialize template, Step 5 Populate sections, Step 6 Summary and next steps — plus the multi-PRD final summary emitted when multi-PRD mode completes.

## PRD status lifecycle

Each PRD carries four status fields in its YAML frontmatter. The owning skill is responsible for updating the field via `Bash` (`sed -i` or equivalent) immediately after completing the relevant work.

| Field | Initial | Updated by | Updated to | Trigger |
|-------|---------|-----------|-----------|---------|
| `status` | `product` | `plan-em` | `eng` | eng sections written to PRD |
| `product-tuned` | `no` | `plan-tune --product` (via next-step prompt) | `yes` | user accepts tuned output |
| `eng-tuned` | `no` | `plan-tune --eng` (via next-step prompt) | `yes` | plan-tune completes |
| `reviewed` | `no` | `review` skill | `yes` | code review of PRD's changes is complete |

## References

- `refs/protocol-pm.md` — end-to-end six-step execution protocol + multi-PRD final summary; followed from § Step-by-step protocol
- `refs/protocol-sub.md` — the four `--sub` deltas (parent resolution, intake pre-seed, numbering/placement, frontmatter) layered over the six-step protocol; read from § Sub-PRD mode when `--sub` is set
- `refs/protocol-roadmap.md` — end-to-end `--roadmap` protocol: inventory → analyse for bloat/overlap → gated reshaping → stable phase sequencing → `roadmap/roadmap.md` → GUI/execution handoff; followed from § Roadmap mode
- `.claude/scripts/plan-pm-roadmap-scan.sh` — deterministic PRD inventory (JSONL); call in Roadmap Step 1
- `roadmap/roadmap.md` — the roadmap artifact written by `--roadmap`; read by `/msg --gui` (Roadmap tab) and `/eng --build roadmap=…`
- `refs/principles.md` — core operating principles; read this first before any other ref
- `refs/template-prd.md` — structured PRD format; used to initialize the file in Step 4
- `refs/template-error.md` — error case format, rules, and examples; used when populating §6 in Step 5
- `refs/protocol-interview.md` — structured interview questions and format for Step 3
- `.claude/scripts/scan-n.prd prd` — deterministic next-PRD-number resolver; call in Step 4
- `.claude/scripts/scan-n.prd sub <parent-n>` — deterministic next sub-PRD minor resolver; call in Step 4 Part 1 when in `--sub` mode (see § Sub-PRD mode)
- `devkit/` — project-level agent context directory created by `msg-init`; contains AHA.md, GLOSSARY.md, ARCHITECTURE.md, DESIGN-SYSTEM.md, OPEN-QUESTIONS.md
