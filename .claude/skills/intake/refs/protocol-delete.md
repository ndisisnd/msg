---
name: Intake Delete Protocol
description: End-to-end protocol for /intake --delete — pick the row(s) to remove, run the warning pass (mapped PRD, inbound blocked-by references, ship record, log history), take an explicit confirm, then remove the row without renumbering and append a `remove` log entry.
type: reference
---

# Intake Delete Protocol

The flow `/intake --delete` follows. Emit `Step X/5 — <title>` at the start of
each step. **This is the only destructive mode in intake.** It exists because no
other surface can remove a ledger row — `--update` edits content, the `/msg --gui`
Intake tab edits `status`, and neither deletes.

Never read the codebase; never draft a PRD; **never delete anything but ledger
rows** — a PRD folder, a branch, and a file on disk are all out of scope.

## The two invariants

1. **Never renumber.** Deleting `#4` leaves a gap: `#3, #5, #6`. Renumbering would
   silently repoint every `S:blocked-by-#n` reference, every `INTAKE-UPDATE.md`
   log entry, and every PRD folder name that encodes a row number. **A gap is
   correct** — it is the visible trace of a removal.
2. **Never delete silently.** Every removal is preceded by the warning pass
   (Step 3) and an explicit confirm (Step 4), and followed by a `remove` entry in
   `INTAKE-UPDATE.md` (Step 5). A deletion that leaves no record is a defect.

## Pre-run — reads

| File | How to apply |
|------|-------------|
| `INTAKE.md` (repo root) | The ledger. Absent → Step 1 terminates. |
| `INTAKE-UPDATE.md` (repo root) | The update/removal log. **May be absent** (lazy-created on first write). Checked by W4 (Step 3) and appended to at Step 5. |
| `features/` (listing only) | To resolve whether a row's `prd` cell maps to a **live PRD folder**. A directory listing, not a PRD read. |

## Pre-run — migration (first touch)

Before Step 1, check whether `INTAKE.md` still carries an in-file `## Update log`
section (pre-C11). This check runs **ahead of the warning pass** — not at
write time — precisely so that W4 (Step 3) never has to guess: on a legacy
ledger whose first-ever `/intake` touch happens to be `--delete`, running the
check here means `INTAKE-UPDATE.md` already reflects the row's history by the
time W4 reads it, instead of W4 finding that file absent while the real history
still sits in the in-file section.

1. **Present** → move the log's **entry rows only** — never the legacy `##
   Update log` heading or its column-header row — into `INTAKE-UPDATE.md`.
   `protocol-update.md` § *The update log* states the canonical header and the
   entry-rows-only rule in full; this step follows that rule by citation, not
   by restating it: create `INTAKE-UPDATE.md` with the canonical header if it
   doesn't exist yet, append the moved entry rows under the header's table,
   then strip the section from `INTAKE.md` (row table + everything above it is
   untouched).
2. **Absent** → nothing to migrate; proceed directly.

**Idempotent.** A ledger already split (no in-file section) hits case 2 on
every run — migration is a one-time event per ledger, never repeated, never
destructive. An absent `INTAKE.md` also hits case 2 trivially; Step 1 handles
that termination on its own terms.

## Step 1/5 — Ledger check

- **`INTAKE.md` absent** → *"No `INTAKE.md` — nothing to delete."* Terminate. Never scaffold.
- **Zero rows** → *"`INTAKE.md` has no rows."* Terminate.

## Step 2/5 — Pick the row(s)

Emit **every** row — including `completed` ones, unlike `--update`'s table.
Deletion is the one operation that legitimately targets shipped history, so
hiding those rows would just push the user to hand-edit the file.

```
| # | type | idea | goal | grade | status | prd |
```

The `prd` column is included here (it is not in `--update`'s table) because a
mapped PRD is the single most important thing to see **before** deleting.

Then prompt in free text:

> Which row(s) do you want to delete? (e.g. `#4`, or `#4 and #7`)

Target resolution follows `protocol-update.md` Step 3 — `#n` beats text match,
`≥2` matches disambiguate, `0` matches re-prompt, out-of-range says so plainly.
**Multiple rows may be deleted in one run**; the warning pass and the confirm
cover the whole set, and the confirm lists every row by `#` and `idea`.

One-shot form (`/intake --delete #4`) skips this table when the target resolves
unambiguously — but **never** skips Steps 3 and 4.

## Step 3/5 — The warning pass

This is the substance of the mode. For each targeted row, check all four and
report every hit. **Warnings never block** — they inform the confirm — but a run
with warnings must present them before the confirm, never after.

| # | Condition | Warning |
|---|---|---|
| **W1** | Row's `prd` cell is set **and** the folder exists under `features/` | ⚠️ **Orphans a live PRD.** `#4` maps to `features/prd-7-search/`, which will still exist with nothing pointing at it. Deleting the row does **not** delete the PRD — that is a separate, manual decision. |
| **W2** | `status` is `completed` | ⚠️ **Destroys ship record.** `#2` was stamped `completed` by `post-merge --production` — it records that something shipped. Deleting it removes that history. |
| **W3** | Any **other** row's grade cell contains `S:blocked-by-#<target>` | ⚠️ **Dangling reference.** `#6` and `#9` are graded `S:blocked-by-#4`. Deleting `#4` leaves them blocked by a row that no longer exists. Offer to re-grade those rows' `S:` in a follow-up `/intake --update` — never silently rewrite them here. |
| **W4** | `INTAKE-UPDATE.md` contains entries for the target row | ℹ️ **History is kept — in a separate file.** `#4` has 3 log entries in `INTAKE-UPDATE.md`. They are **preserved** — the log is append-only and survives the row's deletion in `INTAKE.md`, since it lives elsewhere. |

W3 requires scanning **every** row's grade cell, not just the targets. Do it
before the confirm, not after.

`status` is `in-progress` is **not** itself a warning — W1 covers the case that
matters (the mapped PRD). An `in-progress` row with no live PRD folder is just a
stale row, which is exactly what deletion is for.

Render the pass compactly:

```
Deleting #4 — "add full-text search over notes"
  ⚠️ W1  orphans features/prd-7-search/ (the PRD is NOT deleted)
  ⚠️ W3  #6, #9 are graded S:blocked-by-#4 — they will dangle
  ℹ️ W4  3 update-log entries preserved
```

No warnings → say so explicitly (`no warnings`), never render an empty block.

## Step 4/5 — Confirm

One `AskUserQuestion`, header **Delete**, naming every targeted row:

> Delete `#4 — "add full-text search over notes"`? This cannot be undone from
> here — `INTAKE.md` is gitignored, so there is no committed copy to restore from.
>
> - **Delete it** — remove the row, keep the gap at `#4`, log a `remove` entry.
> - **Cancel** — change nothing.

The gitignore caveat is **not optional boilerplate**: per D4 the ledger is
local-only, so a deleted row genuinely has no recovery path. Say it every time.

Multi-row runs confirm **once for the whole set**, listing each row — not one
question per row.

On **Cancel**: write nothing, say so, terminate.

## Step 5/5 — Remove + log

- Remove the target row line(s) **only**. Every other row, the header, the
  separator, and the preamble are preserved byte-for-byte. `INTAKE.md` no
  longer carries the log **for a post-migration ledger** — and every ledger is
  post-migration by this point, since **Pre-run — migration** (above) already
  ran, unconditionally and idempotently, before Step 1. So there is nothing
  else in the ledger to preserve around the removal.
- **Do not renumber.** The gap stays.
- **Do not touch** `features/`, any PRD file, or any branch. The ledger row is the
  entire blast radius.
- Append one `remove` entry per deleted row to `INTAKE-UPDATE.md` — this is the
  first and only writer of the `remove` kind. Lazy-created on first write, same
  as `--update`'s log writes:

```
| 2026-07-21 | #4 | remove | deleted "add full-text search over notes" (C:5 T:3 S:now, backlog) — orphaned features/prd-7-search/ |
```

  The `detail` cell carries the deleted row's `idea`, its final grade, its final
  status, and any W1 orphan — so the log alone answers *what was here and what it
  was attached to* after the row itself is gone.

- Summarise:

```
Deleted #4 from INTAKE.md — "add full-text search over notes"
  gap at #4 kept (rows are never renumbered)
  ⚠️ #6, #9 still graded S:blocked-by-#4 — run /intake --update to re-sequence them
  logged: 1 remove entry → INTAKE-UPDATE.md
```

Where W3 fired, the summary **must** repeat the dangling rows — that is the one
consequence the user has to act on, and it is invisible in the ledger afterwards.
Recommend `/intake --update` for the re-sequence; never do it automatically.
