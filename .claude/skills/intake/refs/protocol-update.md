---
name: Intake Update Protocol
description: End-to-end protocol for /intake --update — scan the ledger, emit the non-completed rows in full, resolve the target row from free text, gate locked rows, interview the change, re-grade + re-split on a material change, and write the row plus its update-log entries.
type: reference
---

# Intake Update Protocol

The flow `/intake --update` follows. Emit `Step X/6 — <title>` at the start of
each step. The whole run stays **≤2 `AskUserQuestion` calls** — the same budget
as capture. Never read the codebase; never draft a PRD; never write `status` or
`prd`.

This is the **update-mode** protocol. Capture mode is `protocol-intake.md`.

## What update mode may change

| Cell | Editable | Note |
|------|----------|------|
| `idea` | ✅ | the sharpened one-line description |
| `goal` | ✅ | the core user outcome |
| `type` | ✅ | `feature` ↔ `bug`, only on an explicit ask or an unambiguous reclassification |
| `grade` | **auto** | never user-set; **re-derived** by Step 5 when the change is material |
| `#` · `date` | ❌ | `date` is *capture* date — the edit date lives in the update log |
| `status` · `prd` | ❌ | D14 holds: intake never advances a row, in either mode |

## Pre-run — reads

Before Step 1, stat-check and read in parallel via `Bash`:

| File | How to apply |
|------|-------------|
| `INTAKE.md` (repo root) | The ledger. Missing → Step 1 terminates with a recommendation; **update mode never scaffolds** (there is nothing to update). |
| `devkit/AHA.md` | Read once for **re-grade calibration** (`refs/rubric.md` § AHA calibration). Absent → skip silently. |

## Step 1/6 — Ledger check

- **`INTAKE.md` absent** → *"No `INTAKE.md` yet — nothing to update. Run `/intake <idea>` to capture the first row."* Terminate. **Do not offer to scaffold** (that is capture mode's job, Step 1 of `protocol-intake.md`).
- **Present** → parse the row table and proceed.

## Step 2/6 — Emit the review table

Select **every row whose `status` is not `completed`** — i.e. `backlog` **and**
`in-progress` — and emit them **in full**:

```
| # | type | idea | goal | grade | status |
```

Rules:

- **No truncation of the set.** Every non-`completed` row appears — no pagination, no "and 12 more".
- **`completed` rows are excluded entirely.** They are not editable and are noise at this gate.
- **`in-progress` rows are shown but marked locked** — render the status cell as `in-progress 🔒`. They are rejected at selection (Step 3). Showing them is deliberate: a locked row explains *why* it can't be picked far better than its absence does.
- **`idea` and `goal` are emitted verbatim and unelided.** The user must be able to judge which row to pick from the text alone. Long cells wrap; this table is the payload of the step, not a preview.
- Sort by `#` ascending.

Then prompt in **free text** (not `AskUserQuestion` — the option space is the
whole backlog, which a 4-option picker cannot represent):

> Which row do you want to change, and what should it become?
> e.g. `#4 — goal should be "cut time-to-first-search"`

**Empty ledger.** Table present but zero non-`completed` rows → *"Every row in
`INTAKE.md` is `completed` — nothing to update."* (or *"`INTAKE.md` has no rows
yet."*). Recommend `/intake`. Terminate cleanly, not as an error.

**Skip condition.** In one-shot mode (`/intake --update <text>`) where Step 3
resolves the target to exactly one row, **this step is skipped entirely** — do
not emit the table.

## Step 3/6 — Resolve the target row

Resolve the free text to **exactly one row `#`**, in this precedence order:

1. **Explicit `#n`** — an integer reference (`#4`, `row 4`, `number 4`). Beats any text match in the same input.
2. **Idea-text match** — a distinctive phrase matching one row's `idea` or `goal`.
3. **Otherwise — never guess.**

Outcomes:

| Case | Action |
|------|--------|
| **1 match** | Proceed to the lock gate. |
| **≥2 matches** | One `AskUserQuestion` listing the tied rows (`#n — idea`), ≤4 options + Other. In browse mode the table is already on screen, so this is a pure disambiguator. |
| **0 matches** | Browse mode → re-prompt against the visible table. One-shot mode → **fall back to emitting the Step 2 table** and prompt. A failed one-shot **degrades into browse**; it never errors out and **never silently captures a new row instead**. |
| **`#n` out of range** | Say so plainly (*"there is no row #12 — the ledger ends at #7"*). Never coerce to the nearest row. |

### Lock gates

Both refusals are hard, both are **explained**, and **neither terminates the
run** — each re-offers selection, so a mistaken pick costs one turn, not a
restart. Neither writes to `INTAKE.md`.

- **Target is `in-progress`:**

  > `#4` is `in-progress` (PRD: `prd-7-search`). The PRD is the source of truth
  > once planning starts — run `/plan-tune <path>` to certify it, or `/plan-pm`
  > to revise it. `--update` edits `backlog` rows only.

  Then re-offer the selectable rows.

- **Target is `completed`:**

  > `#2` shipped; completed rows are historical record. To change what it does
  > now, capture a new idea with `/intake`.

**Why these lock:** editing a ledger row under a live PRD creates two
contradicting statements of intent with no reconciliation path — pre-merge's
PRD-consistency gate checks the PRD against the *code*, not against the ledger,
so nothing downstream would ever catch the drift.

**The sanctioned escape hatch for the `in-progress` lock** is the `/msg --gui`
Intake tab: drag the card back to **Backlog** (the only surface that moves a row
backwards through the D14 lifecycle), then re-run `--update`. Say so when
refusing. Never work around the gate here, and never write `status` to
self-serve the hatch.

There is **no escape hatch for `completed`** — a shipped row stays as it shipped.
If the row should not exist at all, that is `/intake --delete` (which warns that
it is destroying a ship record), not an edit.

## Step 4/6 — Resolve the change (and follow up)

Determine **which cells change and to what**. Three cases:

1. **Explicit and clear** — `#4 — goal should be "cut time-to-first-search"`.
   Take it. **Zero questions.**

2. **Row named, changes absent** — `/intake --update #4`, or a bare row pick from
   the table. **Follow up:** one `AskUserQuestion`, header **Change**, asking which
   cell(s) to change (`idea` / `goal` / `type`, `multiSelect: true`), then collect
   the new value(s) as free text. Never no-op; never invent a change.

3. **Row named, changes present but ambiguous** — `#4 — make it broader`,
   `#4 — also for mobile`. **Always follow up — including in one-shot mode.**
   Serve 2–3 concrete PM-derived interpretations of the vague instruction +
   Other, reusing the flesh-out muscle of `protocol-intake.md` Step 3.1. The
   `--update <text>` form **does not buy a bypass** of this.

Batch cell-selection and value-collection into one call where possible. Budget:
**≤2 `AskUserQuestion` calls for the whole run.**

**`type` changes** are accepted only when explicitly asked for, or when the
rewritten idea unambiguously reclassifies (a capability reworded as a defect).
Otherwise leave `type` alone.

**Never offer `status` or `prd` as editable cells, in any question.**

## Step 5/6 — Classify, re-grade, re-split

Classify the settled change:

- **Cosmetic** — a typo, a wording fix, a clarified `goal` that doesn't change
  scope. **Keep the existing grade cell byte-for-byte.** No re-grade, no gates.
  This is the cheap path and should be the common one.

- **Material** — scope, surface, or capability changed. Run
  **`protocol-intake.md` Step 4 verbatim**: a single-turn banded re-grade against
  `refs/rubric.md`, calibrated by `devkit/AHA.md`. Bands only — never a
  fake-precise number. Then apply both split gates:

  - **`≥8` gate** — new `C:` ≥ `8` fires the `≥8`-split `AskUserQuestion`
    (`protocol-intake.md` Step 4). On split, the updated row is **replaced** by
    2–4 re-graded rows.
  - **Hybrid gate** — if the rewritten idea now bundles separable capabilities,
    fire the split confirmation from `protocol-intake.md` Step 2. Same
    replacement semantics.

**Replacement semantics** (both gates): the original row's `#` is retained by the
**first** resulting row; the others take fresh `#`s appended after the current
maximum. No existing `#` is reused or renumbered — so `S:blocked-by-#n`
references elsewhere in the ledger never dangle.

**Sequencing.** `S:` is re-derived with the rest of the grade cell, which can
flip `S:blocked-by-#4` → `S:now`. Correct, but surface it — the grade diff in
Step 6 must show it.

## Step 6/6 — Write + summarise

### The diff echo (before writing)

Show old → new for **every** changed cell, including the grade:

```
#4
  idea:  add search → add full-text search over notes
  grade: C:3 T:2 S:next → C:5 T:3 S:next   (re-graded — material change)
```

### The write

A **targeted row rewrite, never a file rewrite**:

- Rewrite **only** the target row's changed cells. Every other row, the header,
  the preamble prose, and all table formatting are preserved byte-for-byte.
  `INTAKE.md` holds the ledger only — the log lives in `INTAKE-UPDATE.md`
  (below), a separate file this write does not touch except to append.
- `#` and `date` are **never** rewritten.
- `status` and `prd` are **never** written.
- Split cases (Step 5) rewrite the target row **and** append the new rows in the
  same write.
- **Log entries are written in the same operation as the row change.** A row
  edited without its log entry is a defect, not a degraded success.
- **No-op guard:** if the resolved change equals the current value, report
  `no change` and write **nothing** — no row edit, no log entry, and (see
  *Migration* below) no migration either: migration rides the first *write*,
  not the first *invocation*, so a no-op run leaves a pre-C11 ledger's in-file
  log exactly where it was.

### The update log — `INTAKE-UPDATE.md`

The log is a **separate file**, `INTAKE-UPDATE.md`, sitting beside `INTAKE.md`
at the repo root — not a section inside the ledger. Append **one entry per
changed cell**:

```
| when | row | change | detail |
|------|-----|--------|--------|
| 2026-07-21 | #4 | modify | idea: "add search" → "add full-text search over notes" |
| 2026-07-21 | #4 | modify | grade: C:3 T:2 S:next → C:8 T:5 S:next (re-graded — material change) |
| 2026-07-21 | #4 | modify | split ≥8 — narrowed to "full-text index" (C:5 T:3 S:now) |
| 2026-07-21 | #9 | add | split from #4 — "search result ranking" (C:3 T:2 S:next) |
```

- `when` — today, `YYYY-MM-DD`. Distinct from the row's `date`.
- `row` — the `#` the entry is *about*. A split writes one `modify` for the
  surviving row plus one `add` per new row.
- `change` — **exactly one of `modify` / `add` / `remove`.** No other value is
  ever written. **Update mode never writes `remove`** — that kind belongs to
  `/intake --delete` (`protocol-delete.md`), which is the only writer of it.
- `detail` — `<cell>: <old> → <new>` for `modify`; `split from #n — "<idea>"
  (<grade>)` for `add`.
- **Append-only.** Existing entries are never rewritten, reordered, or pruned.

**Missing file.** `INTAKE-UPDATE.md` is **lazy-created** — it does not exist
until the first entry is written. Absence is never an error; on first write,
create it with this canonical header, then append the entry rows:

```
# INTAKE-UPDATE — Update log

Edit history for INTAKE.md: entries made by `/intake --update` and removals by
`/intake --delete` — append-only. INTAKE.md holds the current state; this file
is how it got there, including rows that no longer exist. Rows created by plain
`/intake` capture are not logged (their `date` cell already records them).

`change` is always one of `modify` (a cell value changed — one entry per cell) ·
`add` (a row created by a split) · `remove` (a row deleted; the `#` is never
reused, so the ledger keeps a visible gap).

| when | row | change | detail |
|------|-----|--------|--------|
```

No `TEMPLATE-INTAKE-UPDATE.md` exists — this header is the one canonical
source for the file's shape; `/msg --init` does not pre-create it.

**Migration (first touch — meaning first *writing* touch).** A ledger that
predates the split may still carry an in-file `## Update log` section at the
foot of `INTAKE.md` (pre-C11). This check runs immediately before the row/log
write in this same step — never on a run that ends in the no-op guard above,
which writes nothing and therefore migrates nothing; the legacy layout stays
in place by design until a run that actually changes a cell. Before writing
the new entry, check for that section:

1. **Present** → move it **verbatim** (entries byte-for-byte) into
   `INTAKE-UPDATE.md` — creating the file with the canonical header above if it
   doesn't exist yet, then appending the moved rows under the header's table —
   then **remove the section from `INTAKE.md`** (row table + everything above
   it is untouched). Proceed to write the new entry as normal.
2. **Absent** → nothing to migrate; proceed directly.

**Idempotent.** A ledger already split (no in-file section) hits case 2 on
every subsequent run — migration is a one-time event per ledger, never
repeated, never destructive.

The old blank-line-leak risk (a bare-blank-line-separated log table parsed as
extra ledger rows by `msg/refs/gui/server.py: build_intake`) is now
**unreachable by construction** for any ledger past its first migration —
`INTAKE.md` and `INTAKE-UPDATE.md` are different files, so there is no shared
row-scan for a co-resident table to leak into. It remains a live risk only for
the narrow pre-migration window where an old-style ledger still carries the
in-file section; migration on first touch closes that window.

### The summary

```
Updated #4 in INTAKE.md
  idea:  add search → add full-text search over notes
  grade: C:3 T:2 S:next → C:5 T:3 S:next   (re-graded — material change)
  logged: 2 entries → INTAKE-UPDATE.md
Next: /plan-pm to draft a PRD from the backlog, or /intake --update to edit another row.
```

Split runs additionally list the created rows. Recommend (never invoke)
`plan-pm`. Terminate.
