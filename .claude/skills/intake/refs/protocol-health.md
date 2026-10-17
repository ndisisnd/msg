---
name: Intake Health Protocol
description: End-to-end protocol for /intake --health — scan the ledger against the PRD set for stale, errant, shipped-but-open and duplicate rows, report them with plain-English grades, and offer to fix wrong statuses behind one confirm.
type: reference
---

# Intake Health Protocol

`/intake --health` checks that the ledger is still true. It reports first. It writes only a `status` fix, and only after one confirm. The writer `$S` is resolved as in `protocol-intake.md`.

## Step 1 — Read

- `INTAKE.md` absent → *"No `INTAKE.md` yet — nothing to check."* Terminate. Never scaffold.
- Open rows: `bash "$S" INTAKE.md - --list-rows --status backlog,in-progress`.
- PRDs: `bash .claude/scripts/script-prd-scan.sh --git` (one JSON line per PRD: `id`, `status`, `complete`, `completion`).

Health reads only open rows. A `completed` row is closed and is not checked again.

## Step 2 — Find problems

| Finding | Rule | Proposed fix |
|---------|------|--------------|
| **Stale** | `backlog`, no `prd`, `date` older than 14 days | none — list it. Suggest `/plan-pm #n` or `/intake --delete #n` |
| **Errant** | `in-progress` but the `prd` cell is empty, or names a PRD the scan does not find | none — flag it. The GUI Intake tab can move it back to Backlog |
| **Shipped, still open** | `prd` maps to a PRD the scan shows shipped (`status: complete`, or `completion: shipped`) | `status` → `completed` |
| **Planned, still backlog** | `backlog` but `prd` maps to a live PRD | `status` → `in-progress` |
| **Duplicate** | two open rows that duplicate each other (`principles.md` 5) — check with `--list-rows --match` on each row's key words | none — suggest `/intake --update` on one and `/intake --delete` on the other |

## Step 3 — Report

```
INTAKE.md health — 9 open rows checked
  Stale (2):     #3 offline mode (backlog since 2026-09-01) — Complexity 5 — medium: a few screens or one new service
                 #5 dark theme (backlog since 2026-08-20) — Complexity 2 — small: a couple of linked changes
  Errant (1):    #6 in-progress with no PRD
  Wrong status (1): #4 → completed (prd-7-search shipped)
  Duplicates:    none
```

Every grade shown carries its plain-English label (`rubric.md`). Nothing found → say `ledger is healthy` and terminate.

## Step 4 — Offer the status fixes

Only when the report has a **proposed fix**. One `AskUserQuestion`, header **Fix status**, listing every fix: **Fix all** / **Leave as is**. Leave → write nothing, terminate.

On **Fix all**, per row:

```bash
bash "$S" INTAKE.md <n> --status <completed|in-progress>
bash "$S" INTAKE.md <n> --log-append --change modify --detail "status: <old> → <new> (--health: <reason>)"
```

Stale, errant and duplicate rows are never changed here. Close with the shared closing message.
