---
name: INTAKE Template
description: Template for the root INTAKE.md backlog ledger — the chronological, graded table of feature ideas and bugs. Scaffolded by /msg --init and by /intake; rows written by /intake, status/prd cells stamped by plan-pm and post-merge. Lives at the REPO ROOT (D13), never in devkit/ — it is a living ledger, not a read-only devkit doc.
type: reference
---

# INTAKE Template

`INTAKE.md` is the msg planning **front-door ledger** — every feature idea and bug
enters here as a graded row before it becomes a PRD. It lives at the **repo root**
(not `devkit/` — devkit files are read-only after init; this ledger keeps changing).

`init.sh` writes the `## Template body` block below verbatim to `<root>/INTAKE.md`,
idempotently (`/msg --init` never overwrites an existing file). `/intake` scaffolds
the identical content when the ledger is missing at capture time.

## Who writes what (D14 lifecycle)

| Cell change | Owner | When |
|---|---|---|
| new row, `status: backlog`, `prd` empty | `intake` | on capture |
| content cells `idea` / `goal` / `type` (+ re-derived `grade`) | `intake --update` | on user request; **`backlog` rows only** — `in-progress` and `completed` are refused |
| `## Update log` entries | `intake --update` | one per changed cell, append-only, same write as the row edit |
| `status: in-progress` + `prd: prd-<n>-<slug>` | `plan-pm` | when it creates the PRD from the row |
| `status: completed` | `post-merge --production` | when the mapped PRD ships to `main` |
| `status` cell only (manual) | `/msg --gui` Intake tab | drag between lanes; the **only** surface that moves a row *backwards* through the lifecycle. It owns `status`; `intake --update` owns content; `intake --delete` owns removal |
| row removed (+ a `remove` log entry) | `intake --delete` | on user confirm, after the warning pass. Never renumbers — the `#` gap stays |

`intake --update` never writes `status` or `prd` — the D14 lifecycle above is
unchanged by it.

## Grade-cell format

`C:<1|2|3|5|8|13> T:<1|2|3|5|8|13> S:<now|next|later|blocked-by-#n>` — a single-turn banded
judgment by `intake` at capture time. **Bands and ranges only; never a fake-precise
number** (`~1,240 LOC` and `3.5 days` are forbidden). Full rubric:
`.claude/skills/intake/refs/rubric.md`.

## Update-log format

The `## Update log` section below the row table records every edit made by
`/intake --update` — **one entry per changed cell**, append-only. Columns:

| Column | Content |
|---|---|
| `when` | `YYYY-MM-DD` the edit was applied. Distinct from the row's `date`, which is capture date and is never rewritten. |
| `row` | `#n` the entry is about. A split writes one `modify` for the surviving row plus one `add` per new row. |
| `change` | `modify` \| `add` \| `remove` — fixed vocabulary, no free-form kinds. |
| `detail` | `<cell>: <old> → <new>` for `modify`; `split from #n — "<idea>" (<grade>)` for `add`. Material re-grades append `(re-graded — material change)`. |

- **`modify`** — an existing row's cell value changed. The common case.
- **`add`** — a row created *as a consequence of an update* (a hybrid- or `≥8`-split).
  Rows created by **capture** are not logged — the row's own `date` cell already records those.
- **`remove`** — a row was deleted by `/intake --delete`. The `detail` cell keeps
  the deleted row's `idea`, final grade, final status, and any PRD it orphaned —
  so the log alone answers *what was here* after the row is gone. Rows are
  **never renumbered** on delete, so the ledger keeps a visible gap at that `#`.

**The two tables must be separated by non-blank prose.** The GUI's ledger parser
(`server.py: build_intake`) treats a **blank line as still inside** the row table
and stops only at the first non-pipe, **non-blank** line. So the `## Update log`
heading and its preamble paragraph are structural, not decorative: they are what
terminates the row scan.

Verified behaviour (three ledger rows + three log entries):

| Layout | Rows parsed |
|---|---|
| heading + preamble (as shipped) | 3 ✅ |
| heading removed, preamble kept | 3 ✅ |
| preamble removed, heading kept | 3 ✅ |
| **both removed — tables separated only by a blank line** | **7 ❌ log rows leak in as ledger rows** |

Either the heading or the preamble suffices, and both ship — so there is one
level of redundancy. **Never let the log table follow the row table across
nothing but blank lines**, and never place the log above the row table.

## Template body

```
# INTAKE — Backlog ledger

The graded backlog of feature ideas and bugs. `/intake` appends rows;
`/intake --update` edits a `backlog` row's `idea`/`goal`/`type` and logs it below;
`plan-pm` stamps `in-progress` + the `prd` mapping when it plans a row;
`post-merge --production` stamps `completed` when the mapped PRD ships. The
`/msg --gui` Intake tab renders this as a board and may hand-edit `status`.

**Status lifecycle:** `backlog` → `in-progress` (plan-pm creates + maps the PRD)
→ `completed` (post-merge --production ships the mapped PRD).

**Grade cell** `C:… T:… S:…` — a single-turn, banded judgment made at capture:
- `C:` complexity — `1` / `2` / `3` / `5` / `8` / `13`
- `T:` token cost — `1` / `2` / `3` / `5` / `8` / `13`
- `S:` sequencing — `now` / `next` / `later` / `blocked-by-#n`

**Banded estimates ONLY.** Never write a fake-precise number (`~1,240 LOC`,
`3.5 days`) — grades are triage signals, not estimates.

| # | date | type | idea | goal | grade | status | prd |
|---|------|------|------|------|-------|--------|-----|

## Update log

Edits made by `/intake --update` and removals by `/intake --delete` —
append-only. The table above is the current state; this is how it got there,
including rows that no longer exist. Rows created by plain `/intake` capture are
not logged (their `date` cell already records them).

`change` is always one of `modify` (a cell value changed — one entry per cell) ·
`add` (a row created by a split) · `remove` (a row deleted; the `#` is never
reused, so the ledger keeps a visible gap).

| when | row | change | detail |
|------|-----|--------|--------|
```
