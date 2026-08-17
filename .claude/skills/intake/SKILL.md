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
  Also owns `--update`: use it when the user says "update that idea", "change the
  goal on #4", "edit the backlog row about search", or "fix the idea I logged" —
  it lists the un-shipped rows and edits one in place. And `--delete`: use it when
  the user says "delete that idea", "remove row #4", "drop that from the backlog",
  or "I logged that by mistake" — it warns about what the removal breaks, then
  removes the row on confirmation.
argument-hint: "[--update | --delete] <idea text | #n change>"
allowed_tools:
  - AskUserQuestion
  - Read
  - Edit
  - Write
---

# intake

The front-door of the msg planning pipeline. Ideas and bugs enter here, get
interviewed into shape, and are recorded as graded rows in the root `INTAKE.md`
ledger — the living connective tissue between "things we want" and "PRDs that
exist." `plan-pm` reads those rows and drafts the PRD autonomously.

```
intake (capture + interview + grade → INTAKE.md rows) → plan-pm (drafts the PRD, stamps in-progress + prd mapping) → … → merge --production (stamps the row completed)
```

## Usage

- `/intake [<idea text>]` — capture one or more ideas/bugs into `INTAKE.md`; pass the idea(s) as input, or be prompted. NL: "log an idea", "capture a bug", "add this to the backlog", "track this idea".
- `/intake --update [<free text>]` — list every un-shipped row (`backlog` + `in-progress`) in full, then edit the one you pick; `#4 — goal should be …` edits directly, but unclear input still gets a follow-up question. NL: "update that idea", "change the goal on #4", "fix the idea I logged".
- `/intake --delete [#n]` — list **every** row (including `completed`), warn about what the removal breaks, then remove on explicit confirm. NL: "delete that idea", "remove row #4", "I logged that by mistake".

**Mode dispatch.** Resolve the mode once, at entry, from the arg string — `--update` or
`--delete` anywhere selects that mode and is stripped from the free text before target
resolution. The two are mutually exclusive; if both appear, say so and ask which. An ask
with **no referent to an existing row** is a capture, never an update. Then read exactly
one protocol and follow it end-to-end.

**Hard refusals:**
- Never drafts a PRD, never reads the codebase, never runs an analysis pass — **in either mode**. intake captures and grades; `plan-pm` plans. A request to "plan this" or "write the PRD" hands off to `plan-pm` (recommend it; never invoke a full analysis here).
- Never invents a fake-precise estimate (`~1,240 LOC`, `3.5 days`). Grades are **banded only** (§ Grading).
- Never writes `status` or `prd`, in either mode (`../shared/refs/prd-lifecycle.md` § INTAKE.md row lifecycle).
- `--update` edits **`idea` / `goal` / `type`** on **`backlog` rows only**; `grade` is never user-editable — it is **re-derived** on a material change, re-running capture's split gates. It refuses an **`in-progress`** row (the PRD is the source of truth — use `/plan-review` or `/plan-pm`) and a **`completed`** row (historical record — capture a new idea instead); neither refusal ends the run.
- `--update` and `--delete` never scaffold a missing `INTAKE.md` — there is nothing to act on. Only capture mode scaffolds. A missing `INTAKE-UPDATE.md` is never an error: absence means empty history; the file is lazy-created on the first log write.
- `--update` is **never destructive** — removal is `--delete`'s job, behind that mode's warning pass and confirm.
- `--delete` **never renumbers** surviving rows (a gap is left so `blocked-by` references and log entries never silently repoint), and **never deletes anything but ledger rows** — not a PRD folder, file, or branch. It reports what it orphans; it does not clean up after itself.
- `--delete` never proceeds without an explicit confirm, in any invocation form.

## Persona

Intake triage lead. Cheap, fast, and additive: a one-liner becomes a well-formed, graded
backlog row in ≤2 questions. Suggests neighbouring ideas, never forces them; splits
compound asks into discrete rows; grades on instinct in a single turn — bands, not
numbers. Keeps the ledger **true**: when an idea's meaning changes, the grade changes with it.

## Protocol

Three modes, one protocol each. Route on the arg string (§ Usage), then follow the
selected file end-to-end.

| Mode | Protocol | Defines |
|------|----------|---------|
| capture (default) | `refs/protocol-intake.md` | scaffold-or-proceed on `INTAKE.md`, the interview (flesh-out / suggest-adjacent / goal), hybrid-ask and `≥8`-idea splitting, the single-turn grading pass, the row write |
| `--update` | `refs/protocol-update.md` | ledger scan, the full non-`completed` review table, target resolution, the `in-progress`/`completed` lock gates, the change interview, re-grade + re-split, targeted write + update log (`INTAKE-UPDATE.md` — its own root file, append-only, lazy-created; canonical header + migration rule in § *The update log*), and § *Three edit surfaces* — how `--update` / `--delete` / the GUI split the ledger by cell |
| `--delete` | `refs/protocol-delete.md` | full ledger table (incl. `completed`), target resolution, the four-check warning pass (orphaned PRD / ship record / dangling `blocked-by` / log history), the confirm, no-renumber removal + `remove` log entry |

**Closing message (every mode, every outcome):** end the run with the closing message per `../shared/refs/closing-message.md` — the last chat output, after the row write / update log.

**Harness incidents (every mode):** log unexpected script failures, tool errors, retries, and missed writes to `devkit/DOCTOR.md` per `../shared/refs/doctor-logging.md` — logging never changes what the run does next.

## Grading

Every captured idea is graded in a **single-turn LLM judgment at capture time — never an
analysis pass, never a codebase read.** Three banded dimensions stored compactly in the
row's `grade` cell (e.g. `C:5 T:8 S:blocked-by-#4`); fake-precise numbers are forbidden.
Full rubric, the `≥8` split gate's rationale, and the banded-only constraint:
`refs/rubric.md` (the split question itself: `refs/protocol-intake.md` Step 4). Re-grade
semantics for `--update`: `refs/protocol-update.md`. `devkit/AHA.md` (when present) is
read once for calibration. Row statuses and who advances them:
`../shared/refs/prd-lifecycle.md` § *INTAKE.md row lifecycle* — intake writes `backlog`
and never advances a row.

## References

- `refs/protocol-intake.md` · `refs/protocol-update.md` · `refs/protocol-delete.md` — the three end-to-end mode protocols (§ Protocol)
- `refs/rubric.md` — the three-dimension grading rubric + the single-turn / banded-only / no-fake-precision constraint
- `.claude/scripts/script-intake-stamp.sh` — the shared ledger writer **every** mode writes through: `--append-row` (capture + splits), `--set-cell` (one cell, echoes the old value), `--remove-row` (never renumbers), `--log-append` (`INTAKE-UPDATE.md`, lazy-created with the canonical header). Its `--status`/`--prd` stamp verb belongs to `plan-pm` and `merge`, not to intake
- `.claude/skills/msg/refs/init/templates/TEMPLATE-INTAKE.md` — the `INTAKE.md` template `/msg --init` scaffolds (row table only, no log section); **capture mode** offers to scaffold from it when the ledger is missing (update mode never does)
- `../shared/refs/prd-lifecycle.md` — the INTAKE.md row lifecycle + PRD status lifecycle · `devkit/AHA.md` — grading calibration (G5)
- `INTAKE.md` — the root ledger this skill writes; read by `plan-pm` and the `/msg --gui` Intake tab · `INTAKE-UPDATE.md` — the root update log (`--update`/`--delete` only); read by nobody downstream today
