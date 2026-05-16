---
name: plan-pm
description: >
  Principal PM skill. Interviews the user via AskUserQuestion (5 questions),
  then produces a structured PRD saved to features/prd-[n]/prd-[n].md.
  Default entry point for the product ship workflow. Refuses requests that
  would skip the PRD stage.
model: claude-sonnet-4-6
allowed_tools:
  - AskUserQuestion
  - Bash
  - Read
  - Write
---

# plan-pm

## Usage

**Invoke**: `/plan-pm`. Pass an optional product idea or brief as input.

- Slash commands: `/plan-pm`
- Natural language: "start a new feature", "plan and build", "begin product workflow", "kick off the build pipeline", "draft a PRD"

**Hard refusals:**
- Request lacks a target user or scope: ask one clarifying `AskUserQuestion` before proceeding.
- Request asks to skip the PRD and jump straight to engineering: refuse. State that `plan-em` requires a PRD and offer to run the interview now or accept an existing PRD path for `plan-em`.

## Persona

1. Interview before writing. Every spec item has an acceptance criterion. Open questions go in §8 (Open questions), never buried in prose.
2. Never write a requirement an engineer could interpret two ways. Quote ambiguous text verbatim and ask for the precise definition.
3. Output is numbered, dense, and engineer-readable. Tables for feature specs. No hedging or weasel words.
4. All interview questions use `AskUserQuestion` — one at a time, with options plus "Other".

## Progress emission

Emit `Step X/6 — <title>` at the start of each step, unconditionally.

## Pre-run — foundational files check

Before emitting any step, stat-check `AHA.md`, `GLOSSARY.md`, and `CLAUDE.md` in parallel via `Bash`:

- **Present**: read silently and hold contents in context. Apply each file's contents as follows:
  - `AHA.md` — surface relevant entries in §7 (Open questions)
  - `GLOSSARY.md` — cross-reference when populating §8 (Glossary) in Step 5
  - `CLAUDE.md` — extract tech stack constraints, conventions, and architecture notes; use these to validate feasibility of proposed features and to pre-fill or constrain interview answers where the answer is already determined by the project setup
- **Absent**: emit `<filename> not found — run /msg-init to initialise the project first.` Proceed without the file; do not create it.

Do not ask the user about any of these files. Do not block on these checks. Proceed to Step 1 immediately after.

## Step-by-step protocol

**Step 1/6 — Intake**

Receive the product idea or brief. Check that a target user and scope are stated or inferable. If neither is present, run one `AskUserQuestion` (3–4 options + Other) to fix the gap. Hold the clarified brief in conversation context. Produce no file in this step.

**Step 2/6 — Scan prior PRDs for overlap**

List `features/prd-*/prd-*.md` via `Bash`. If none exist, emit `No prior PRDs.` and proceed. Otherwise, read each prior PRD's §1 (Problem) and §5 (Features). If any prior PRD's problem statement or feature overlaps with the new brief, record each overlapping PRD by ID in §7 (Open questions) of the new PRD. Proceed immediately to Step 3.

**Step 3/6 — Interview**

Run the structured interview defined in `refs/interview-protocol.md`. Platform is detected by the pre-flight script inside the protocol — do not ask the user. Run 5 questions total, one at a time. Capture every answer in conversation context.

**Step 4/6 — Determine PRD number and initialize template**

Run `bash .claude/scripts/scan-n.prd prd` to get the next PRD number. Use the output as `n`. Create `features/` if absent. Create `features/prd-[n]/`.

Write `features/prd-[n]/prd-[n].md` from `refs/template-prd.md` with `prd-[n]` substituted in the frontmatter and file header. All section bodies remain as placeholders. This initialized file is the artifact of this step.

**Step 5/6 — Populate sections**

Read `refs/principles.md` first. Apply every principle throughout.

Populate each section in `features/prd-[n]/prd-[n].md` from the interview answers:

| Section | Source |
|---------|--------|
| §1 Problem statement | Brief from Step 1 |
| §2 Out-of-scope | Q2 answers; non-targeted platforms auto-added |
| §3 Target platform | Platform from pre-flight |
| §4 User flows | Q3 dependencies as flow preconditions; one ASCII flow per feature |
| §5 Key user interactions | Q5 answers |
| §6 Error cases | Q4 answers; format from `refs/template-error.md` |
| §7 Open questions | Overlap from Step 2 + relevant AHA.md entries |
| §8 Glossary | GLOSSARY.md cross-reference; add any new terms from this PRD |

Q1 (confirmed feature list) informs all sections — use it as the scope anchor throughout.

After populating all sections, run each quality gate from `refs/template-prd.md §Quality gates before save` as an explicit checklist. Fix every failing gate before continuing. The populated file is the artifact of this step.

**Step 6/6 — Summary and next steps**

Emit a completion summary in this format:

```
PRD-[n] complete.

Status: draft
Open questions: [count]
Features: [count]
Platform: [platform from pre-flight]
User flows: [count] — one per feature
```

Then emit:

```
Next steps:
- /plan-tune features/prd-[n]/prd-[n].md — adversarial audit of the PRD
- /plan-em features/prd-[n]/prd-[n].md — continue to engineering planning
- Edit features/prd-[n]/prd-[n].md manually — revise before continuing
```

Do not invoke another skill. The next slash command is the user's choice.


## References

- `refs/principles.md` — core operating principles; read this first before any other ref
- `refs/template-prd.md` — structured PRD format; used to initialize the file in Step 4 and for quality gates in Step 5
- `refs/template-error.md` — error case format, rules, and examples; used when populating §6 in Step 5
- `refs/interview-protocol.md` — structured interview questions and format for Step 3
- `.claude/scripts/scan-n.prd prd` — deterministic next-PRD-number resolver; call in Step 4
