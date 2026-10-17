---
name: INTAKE Template
description: Template for the root INTAKE.md backlog ledger — the chronological, graded table of feature ideas and bugs. Scaffolded by /msg --init and by /intake; rows written by /intake, status/prd cells stamped by plan-pm and merge. Lives at the REPO ROOT (D13), never in devkit/ — it is a living ledger, not a read-only devkit doc.
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
| content cells `idea` / `goal` / `type` (+ re-derived `grade`) | `intake` update (`--update` or plain language) | on user request; **`backlog` rows only** — `in-progress` and `completed` are refused |
| `INTAKE-UPDATE.md` log entries (separate file, not a section here) | `intake` update / delete / `--health` | one per changed cell, append-only, same write as the row edit |
| `status` correction (`completed` / `in-progress`) | `intake --health`, or capture when a duplicate's PRD has shipped | `--health` only behind one confirm |
| `status: in-progress` + `prd: prd-<n>-<slug>` | `plan-pm` | when it creates the PRD from the row |
| `status: completed` | `merge --production` | when the mapped PRD ships to `main` |
| `status` cell only (manual) | `/msg --gui` Intake tab | drag between lanes; the **only** surface that moves a row *backwards* through the lifecycle. It owns `status`; `intake --update` owns content; `intake --delete` owns removal |
| row removed (+ a `remove` entry in `INTAKE-UPDATE.md`) | `intake --delete` | on user confirm, after the warning pass. Never renumbers — the `#` gap stays |

`intake` never writes `prd`, and writes `status` only in the two correction cases
above.

## Grade-cell format

`C:<1|2|3|5|8|13> S:<now|next|later|blocked-by-#n>` — a single-turn banded
judgment by `intake` at capture time. **Bands and ranges only; never a fake-precise
number** (`~1,240 LOC` and `3.5 days` are forbidden). Older rows may still carry a
`T:<band>` token; readers ignore it. Full rubric:
`.claude/skills/intake/refs/rubric.md`.

## Update log — lives in `INTAKE-UPDATE.md`, not here

Every edit, removal and status fix is logged, but **not in this file**. The log
is a separate root file, `INTAKE-UPDATE.md`, lazy-created on first write. This
template's `## Template body` below scaffolds the row table **only** — no log
section (a log table in the same file would leak into the GUI's row scan).
Format: `.claude/skills/intake/refs/protocol-edit.md` § *The update log*. A legacy
in-file `## Update log` section is moved out by
`script-intake-stamp.sh --migrate-log` on the first edit.

## Template body

```
# INTAKE — Backlog ledger

The graded backlog of feature ideas and bugs. `/intake` appends rows, edits a
`backlog` row's `idea`/`goal`/`type`, and logs each change to `INTAKE-UPDATE.md`; `plan-pm` stamps `in-progress` + the `prd`
mapping when it plans a row; `merge --production` stamps `completed`
when the mapped PRD ships. The `/msg --gui` Intake tab renders this as a
board and may hand-edit `status`. Edit history lives in `INTAKE-UPDATE.md`
(lazy-created, gitignored alongside this file) — not in this ledger.

**Status lifecycle:** `backlog` → `in-progress` (plan-pm creates + maps the PRD)
→ `completed` (merge --production ships the mapped PRD).

**Grade cell** `C:… S:…` — a single-turn, banded judgment made at capture:
- `C:` complexity — `1` / `2` / `3` / `5` / `8` / `13`
- `S:` sequencing — `now` / `next` / `later` / `blocked-by-#n`

**Banded estimates ONLY.** Never write a fake-precise number (`~1,240 LOC`,
`3.5 days`) — grades are triage signals, not estimates.

| # | date | type | idea | goal | grade | status | prd |
|---|------|------|------|------|-------|--------|-----|
```
