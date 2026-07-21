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

**Capture mode** — protocol: [`refs/protocol-intake.md`](refs/protocol-intake.md)

- `/intake` — capture one or more ideas/bugs into `INTAKE.md`. Pass the idea(s) as input, or be prompted.
- `/intake <idea text>` — capture the described idea directly.

Natural language: "log an idea", "capture a bug", "add this to the backlog",
"note this feature down", "track this idea", "put this in the backlog".

**Update mode** — protocol: [`refs/protocol-update.md`](refs/protocol-update.md)

- `/intake --update` — list every un-shipped row (`backlog` + `in-progress`) in full, then edit the one you pick.
- `/intake --update <free text>` — edit directly, e.g. `/intake --update #4 — goal should be "cut time-to-first-search"`. Unclear input still gets a follow-up question; the one-shot form buys speed, not a bypass.

Natural language: "update that idea", "change the goal on #4", "edit the backlog
row about search", "fix the idea I logged".

Update mode edits **`idea` / `goal` / `type`** on **`backlog` rows only**. `grade`
is not user-editable — it is **re-derived** when a change is material, and a
re-grade re-runs the same hybrid-split and `≥8`-split gates as capture. Every edit
is recorded in `INTAKE-UPDATE.md`, the update log's own file.

An ask with **no referent to an existing row** is a capture, never an update.

**Delete mode** — protocol: [`refs/protocol-delete.md`](refs/protocol-delete.md)

- `/intake --delete` — list **every** row (including `completed`), then remove the one(s) you pick.
- `/intake --delete #4` — target directly. Still runs the warning pass and the confirm; the one-shot form never skips either.

Natural language: "delete that idea", "remove row #4", "drop that from the
backlog", "I logged that by mistake".

The only destructive mode. It **warns before it removes** — a mapped PRD it would
orphan, other rows graded `S:blocked-by-#n` against it, a `completed` ship record
— then takes an explicit confirm. It **never renumbers**: deleting `#4` leaves a
gap, because renumbering would silently repoint every `blocked-by` reference and
log entry. Deletes ledger rows and nothing else — never a PRD folder, file, or
branch.

**Mode dispatch.** Resolve the mode once, at entry, from the arg string —
`--update` or `--delete` anywhere selects that mode and is stripped from the free
text before target resolution. The two are mutually exclusive; if both appear,
say so and ask which. Then read exactly one protocol and follow it end-to-end.

**Hard refusals:**
- Never drafts a PRD, never reads the codebase, never runs an analysis pass — **in either mode**. intake captures and grades; `plan-pm` plans. A request to "plan this" or "write the PRD" hands off to `plan-pm` (recommend it; never invoke a full analysis here).
- Never invents a fake-precise estimate (`~1,240 LOC`, `3.5 days`). Grades are **banded only** (§ Grading).
- Never writes `status` or `prd`, in either mode (§ Status lifecycle).
- `--update` refuses an **`in-progress`** row (the PRD is the source of truth — use `/plan-tune` or `/plan-pm`) and a **`completed`** row (historical record — capture a new idea instead). Neither refusal ends the run; both re-offer selection.
- `--update` and `--delete` never scaffold a missing `INTAKE.md` — there is nothing to act on. Only capture mode scaffolds. A missing `INTAKE-UPDATE.md` is different — it is never an error, in either mode: absence means empty history, and the file is lazy-created on the first log write.
- `--update` is **never destructive** — it edits and re-grades; removing a row is `--delete`'s job and requires that mode's warning pass and confirm.
- `--delete` **never renumbers** surviving rows, and **never deletes anything but ledger rows** — not a PRD folder, not a file, not a branch. It reports what it orphans; it does not clean up after itself.
- `--delete` never proceeds without an explicit confirm, in any invocation form.

## Persona

Intake triage lead. Cheap, fast, and additive. Turns a one-liner into a
well-formed, graded backlog row in ≤2 questions. Suggests neighbouring ideas but
never forces them. Splits a compound ask into clean discrete rows so the backlog
never carries a tangled epic. Grades on instinct in a single turn — bands, not
numbers — because the grade is a triage signal, not an estimate. Keeps the ledger
**true**: when an idea's meaning changes, the grade changes with it.

## Protocol

Two modes, one protocol each. Route on the arg string (§ Usage), then follow the
selected file end-to-end.

| Mode | Protocol | Defines |
|------|----------|---------|
| capture (default) | `refs/protocol-intake.md` | scaffold-or-proceed on `INTAKE.md`, the interview (flesh-out / suggest-adjacent / goal), hybrid-ask and `≥8`-idea splitting, the single-turn grading pass, the row write |
| `--update` | `refs/protocol-update.md` | ledger scan, the full non-`completed` review table, target resolution, the `in-progress`/`completed` lock gates, the change interview, re-grade + re-split, targeted write + update log |
| `--delete` | `refs/protocol-delete.md` | full ledger table (incl. `completed`), target resolution, the four-check warning pass (orphaned PRD / ship record / dangling `blocked-by` / log history), the confirm, no-renumber removal + `remove` log entry |

## Grading

Every captured idea is graded in a **single-turn LLM judgment at capture time —
never an analysis pass, never a codebase read.** Three banded dimensions stored
compactly in the row's `grade` cell (e.g. `C:5 T:8 S:blocked-by-#4`). Bands and
ranges only; fake-precise numbers are forbidden. Full rubric: `refs/rubric.md`.
`devkit/AHA.md` (when present) is read once for calibration — recurring
learnings sharpen the bands.

**Re-grading (`--update`).** A grade is a judgment *of a specific text*. When an
update changes an idea **materially** (scope, surface, or capability), the row is
re-graded by the same single-turn pass and the same split gates apply. A
**cosmetic** change (typo, wording, a clarified goal that doesn't move scope)
keeps the grade byte-for-byte. The user never sets a grade by hand — they change
the meaning; intake re-derives the band.

## Status lifecycle (D14)

intake writes every new row as `backlog`. It never advances a row itself — **in
either mode.** `--update` *reads* `status` as a gate (§ Two edit surfaces) and
still never writes it.

| Status | Set by | When |
|--------|--------|------|
| `backlog` | **intake** | on capture |
| `in-progress` | `plan-pm` | when it creates the PRD and fills the `prd` cell |
| `completed` | `post-merge --production` | when the mapped PRD ships to `main` |

The `/msg --gui` Intake tab may hand-edit statuses (same trust level as its PRD-board edits).

## Two edit surfaces

The ledger has two writers, and they are **deliberately split by cell** — neither
is a superset of the other.

| | `/intake --update` | `/intake --delete` | `/msg --gui` Intake tab |
|---|---|---|---|
| **Owns** | content — `idea` / `goal` / `type` | removal | lifecycle — `status` |
| **Rows** | `backlog` only | any row | any row (drag between lanes) |
| **Grade** | re-derived on a material change | n/a | never touched |
| **Gate** | follow-up questions when unclear | warning pass + explicit confirm | none — direct manipulation |
| **Logged** | `INTAKE-UPDATE.md`, one entry per changed cell | `INTAKE-UPDATE.md`, one `remove` entry | no |

**They compose.** `--update` refuses an `in-progress` row because its PRD is the
source of truth. The sanctioned escape hatch is the GUI: drag the card back to
**Backlog**, then `--update` will edit it — a deliberate two-step, so demoting a
planned row is a visible act rather than a side effect of an edit.

The GUI does not offer content edits **on purpose**: a hand-edited `idea` would
leave the `grade` cell asserting a judgment of text that no longer exists.
`--update` re-derives the grade; the GUI cannot, so it does not offer the edit.

Deletion is deliberately **not** a `--update` flag: `--update`'s discipline is
*edit + re-grade*, and a removal has neither. Its real risk is the references to
the row — a mapped PRD, other rows' `S:blocked-by-#n`, the log history — which
earn a dedicated warning pass rather than a flag on an edit path.

## Update log

Every `--update` edit and every `--delete` removal appends to `INTAKE-UPDATE.md`
— its **own file**, at the repo root beside `INTAKE.md`, not a section inside
the ledger. Append-only, columns `when | row | change | detail`, where `change`
is exactly one of `modify` (a cell changed, one entry per cell) / `add` (a row
created by a split) / `remove` (a row deleted). `INTAKE.md`'s row table is the
current state; `INTAKE-UPDATE.md` is how it got there — including rows that no
longer exist, whose entries are never pruned. **Lazy-created**: absence is
never an error, and the file appears on the first log write; there is no
`TEMPLATE-INTAKE-UPDATE.md` to scaffold from, since `/msg --init` does not
pre-create it. A ledger that predates the split and still carries an in-file
`## Update log` section is **migrated on first touch** by `--update`/`--delete`
— section moved verbatim, then removed from `INTAKE.md`; idempotent. Canonical
header + format: `refs/protocol-update.md` § *The update log*.

## References

- `refs/protocol-intake.md` — end-to-end capture protocol: scaffold check, interview, hybrid/`≥8` split, grading pass, row write
- `refs/protocol-update.md` — end-to-end update protocol: ledger scan, full review table, target resolution, lock gates, change interview, re-grade + re-split, targeted write + update log (canonical `INTAKE-UPDATE.md` header + migration rule)
- `refs/protocol-delete.md` — end-to-end delete protocol: full ledger table, target resolution, the four-check warning pass, the confirm, no-renumber removal + `remove` log entry
- `refs/rubric.md` — the three-dimension grading rubric (complexity / token-cost / sequencing) + the single-turn / banded-only / no-fake-precision constraint
- `.claude/skills/msg/refs/init/templates/TEMPLATE-INTAKE.md` — the `INTAKE.md` template `/msg --init` scaffolds (row table only, no log section); **capture mode** offers to scaffold from it when the ledger is missing (update mode never does)
- `devkit/AHA.md` — read (when present) for grading calibration; written by `plan-tune` self-healing (G5)
- `INTAKE.md` — the root ledger this skill writes; read by `plan-pm`, `plan-pm --roadmap`, and the `/msg --gui` Intake tab
- `INTAKE-UPDATE.md` — the root update log this skill writes (`--update`/`--delete` only); lazy-created, gitignored alongside `INTAKE.md`, read by nobody downstream today (not `plan-pm`, not the GUI)
