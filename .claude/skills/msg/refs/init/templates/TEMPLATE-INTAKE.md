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
| `status: in-progress` + `prd: prd-<n>-<slug>` | `plan-pm` | when it creates the PRD from the row |
| `status: completed` | `post-merge --production` | when the mapped PRD ships to `main` |
| any status cell (manual) | `/msg --gui` Intake tab | hand-edit, same trust level as PRD-board edits |

## Grade-cell format

`C:<1|2|3|5|8|13> T:<1|2|3|5|8|13> S:<now|next|later|blocked-by-#n>` — a single-turn banded
judgment by `intake` at capture time. **Bands and ranges only; never a fake-precise
number** (`~1,240 LOC` and `3.5 days` are forbidden). Full rubric:
`.claude/skills/intake/refs/rubric.md`.

## Template body

```
# INTAKE — Backlog ledger

The graded backlog of feature ideas and bugs. `/intake` appends rows; `plan-pm`
stamps `in-progress` + the `prd` mapping when it plans a row; `post-merge
--production` stamps `completed` when the mapped PRD ships. The `/msg --gui`
Intake tab renders this as a board and may hand-edit status cells.

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
```
