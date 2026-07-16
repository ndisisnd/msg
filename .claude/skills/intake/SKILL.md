---
name: intake
description: >
  The planning front-door. Captures feature ideas and bugs as graded rows in
  the root INTAKE.md ledger. Use it when the user says "log an idea", "capture
  a bug", "add to the backlog", "note this down", "track this feature", or
  invokes `/intake`. Owns the requirements interview — fleshes out thin ideas,
  proactively suggests adjacent ideas, splits compound/hybrid asks and ideas
  grading C:8 or higher into discrete rows, and grades every idea in a single-turn
  banded judgment (complexity / token-cost / sequencing). Feeds `plan-pm`, which
  drafts the PRD.
allowed_tools:
  - AskUserQuestion
  - Bash
  - Read
  - Write
---

# intake

The front-door of the msg planning pipeline. Ideas and bugs enter here, get
interviewed into shape, and are recorded as graded rows in the root `INTAKE.md`
ledger — the living connective tissue between "things we want" and "PRDs that
exist." `plan-pm` reads those rows and drafts the PRD autonomously.

```
intake (capture + interview + grade → INTAKE.md rows)
  → plan-pm (picks a row, drafts the PRD solo, stamps in-progress + prd mapping)
  → … → post-merge --production (stamps the row completed)
```

## Usage

- `/intake` — capture one or more ideas/bugs into `INTAKE.md`. Pass the idea(s) as input, or be prompted.
- `/intake <idea text>` — capture the described idea directly.

Natural language: "log an idea", "capture a bug", "add this to the backlog",
"note this feature down", "track this idea", "put this in the backlog".

**Hard refusals:**
- Never drafts a PRD, never reads the codebase, never runs an analysis pass. intake captures and grades; `plan-pm` plans. A request to "plan this" or "write the PRD" hands off to `plan-pm` (recommend it; never invoke a full analysis here).
- Never invents a fake-precise estimate (`~1,240 LOC`, `3.5 days`). Grades are **banded only** (§ Grading).

## Persona

Intake triage lead. Cheap, fast, and additive. Turns a one-liner into a
well-formed, graded backlog row in ≤2 questions. Suggests neighbouring ideas but
never forces them. Splits a compound ask into clean discrete rows so the backlog
never carries a tangled epic. Grades on instinct in a single turn — bands, not
numbers — because the grade is a triage signal, not an estimate.

## Protocol

Follow `refs/protocol-intake.md` end-to-end. It defines: scaffold-or-proceed on
`INTAKE.md`, the interview (flesh-out / suggest-adjacent / goal), hybrid-ask and
`≥8`-idea splitting, the single-turn grading pass, and the row write.

## Grading

Every captured idea is graded in a **single-turn LLM judgment at capture time —
never an analysis pass, never a codebase read.** Three banded dimensions stored
compactly in the row's `grade` cell (e.g. `C:5 T:8 S:blocked-by-#4`). Bands and
ranges only; fake-precise numbers are forbidden. Full rubric: `refs/rubric.md`.
`devkit/AHA.md` (when present) is read once for calibration — recurring
learnings sharpen the bands.

## Status lifecycle (D14)

intake writes every new row as `backlog`. It never advances a row itself.

| Status | Set by | When |
|--------|--------|------|
| `backlog` | **intake** | on capture |
| `in-progress` | `plan-pm` | when it creates the PRD and fills the `prd` cell |
| `completed` | `post-merge --production` | when the mapped PRD ships to `main` |

The `/msg --gui` Intake tab may hand-edit statuses (same trust level as its PRD-board edits).

## References

- `refs/protocol-intake.md` — end-to-end capture protocol: scaffold check, interview, hybrid/`≥8` split, grading pass, row write
- `refs/rubric.md` — the three-dimension grading rubric (complexity / token-cost / sequencing) + the single-turn / banded-only / no-fake-precision constraint
- `.claude/skills/msg/refs/init/templates/TEMPLATE-INTAKE.md` — the `INTAKE.md` template `/msg --init` scaffolds; intake offers to scaffold from it when the ledger is missing
- `devkit/AHA.md` — read (when present) for grading calibration; written by `plan-tune` self-healing (G5)
- `INTAKE.md` — the root ledger this skill writes; read by `plan-pm`, `plan-pm --roadmap`, and the `/msg --gui` Intake tab
