---
name: Intake Edit Protocol
description: End-to-end protocol for editing the INTAKE.md ledger — the shared find-the-row routine, the lock gates, update (change, re-grade, re-split, targeted write) and delete (warning pass, confirm, no-renumber removal), plus the INTAKE-UPDATE.md log contract.
type: reference
---

# Intake Edit Protocol

One protocol for both edit actions:

- **update** — `/intake --update …`, or plain language such as "change #4's goal".
- **delete** — `/intake --delete …`, or plain language such as "drop the search idea". A plain-language remove always gets the full warning pass and confirm.

Never draft a PRD. Never write `prd`. Never delete anything but ledger rows — no PRD folder, file or branch. The writer `$S` is resolved as in `protocol-intake.md`.

## What each action may change

| Cell | update | delete |
|------|--------|--------|
| `idea` · `goal` · `type` | ✅ `backlog` rows only | — |
| `grade` | re-derived on a material change, never user-set | — |
| `#` · `date` · `status` · `prd` | ❌ (the writer refuses them, exit `3`) | — |
| whole row | — | ✅ any row, after warnings + confirm |

## Step 1 — Ledger check

`INTAKE.md` absent → *"No `INTAKE.md` yet — nothing to edit. Run `/intake <idea>` to capture the first row."* Terminate. Never scaffold.

## Step 2 — Find the row

The shared routine for update and delete. Never print the whole ledger.

1. **Explicit `#n`** (`#4`, `row 4`) beats any text match. Read it: `bash "$S" INTAKE.md - --list-rows --row <n>`. `COUNT=0` → say so plainly (*"there is no row #12 — the ledger ends at #<MAX_ROW>"*). Never coerce to the nearest row.
2. **Text** → `bash "$S" INTAKE.md - --list-rows --match "<key words>" --limit 5` (update adds `--status backlog,in-progress`; delete searches every status). Results come best match first.
3. **No text** → ask in plain text: *"Which row, and what should change?"* Then go to 1 or 2.

| Result | Action |
|--------|--------|
| One clear best match | Show that single row in the terminal and proceed. |
| Several close matches | List them as bullets (`#n — idea · status`). The user picks one or more. |
| No match | Say so and ask again in plain text. Never capture a new row instead. |

With several picks, run Steps 3–5 for **one row at a time**, in `#` order.

## Step 3 — Lock gates (update only)

Both refusals explain themselves, write nothing, and re-offer the pick. Neither ends the run.

- **`in-progress`** → *"`#4` is `in-progress` (PRD: `prd-7-search`). The PRD is the source of truth now — run `/plan-pm --update <path>` to change it; plan-pm syncs this row."* The one escape hatch: drag the card back to **Backlog** in the `/msg --gui` Intake tab, then re-run the edit.
- **`completed`** → *"`#2` shipped; completed rows are a historical record. Capture a new idea with `/intake`."* No escape hatch. Removing it is a delete.

## Step 4u — Update: resolve, re-grade, write

1. **Resolve the change.** Explicit and clear (`#4 — goal should be "…"`) → take it, no question. Row named but change absent, or change vague (`make it broader`) → one `AskUserQuestion` with 2–3 concrete readings + Other. Change `type` only when asked or when the new wording clearly reclassifies it.
2. **Classify.** **Cosmetic** (wording, typo, a clearer goal of the same scope) → keep the grade cell byte-for-byte. **Material** (scope, surface or capability changed) → re-grade per `rubric.md`, re-check the split per `principles.md`, and apply `protocol-intake.md` Step 4 replacement semantics. A re-grade may flip `S:`; show it.
3. **No-op guard.** The new value equals the current one → report `no change`, write nothing.
4. **Migrate a legacy log** (before the first write): `bash "$S" INTAKE.md - --migrate-log`. Idempotent.
5. **Diff echo, then write** — one `--set-cell` call per changed cell (it prints the old value, the left side of the echo). A split also calls `--append-row` for each new row.

   ```bash
   bash "$S" INTAKE.md <row-#> --set-cell <idea|goal|type|grade> "<new value>"
   ```

6. **Log** each changed cell in the same operation (§ The update log). A row edit without its log entry is a defect.

Exit codes: `0` written · `1` no such row · `2` usage / no such column · `3` refused cell · `4` `#` exists · `5` write failure. Any non-zero → stop, report, write nothing more.

```
Updated #4 in INTAKE.md
  idea:  add search → add full-text search over notes
  grade: C:3 S:next → C:5 S:next   (re-graded — material change)
         Complexity 5 — medium: a few screens or one new service · Sequencing next — after the current work
  logged: 2 entries → INTAKE-UPDATE.md
Next: /plan-pm to draft a PRD, or /intake --update to edit another row.
```

## Step 4d — Delete: warn, confirm, remove

1. **Migrate a legacy log first** (`--migrate-log`), so W4 sees the full history.
2. **Warning pass.** Check all four and report every hit. Warnings inform the confirm; they never block.

   | # | Check | Warning |
   |---|-------|---------|
   | W1 | `prd` set and the folder exists (`script-prd-scan.sh`) | ⚠️ Orphans a live PRD — the PRD is **not** deleted. |
   | W2 | `status` is `completed` | ⚠️ Destroys a ship record. |
   | W3 | `bash "$S" INTAKE.md - --list-rows --blocked-by <n>` returns rows | ⚠️ Those rows will be blocked by a row that no longer exists. Re-sequence them later with `/intake --update`; never rewrite them here. |
   | W4 | `grep -c '| #<n> |' INTAKE-UPDATE.md` > 0 | ℹ️ Log history is kept (the log is append-only and lives in its own file). |

   No hits → say `no warnings`.
3. **Confirm** — one `AskUserQuestion`, header **Delete**: *"Delete `#4 — "<idea>"`? This cannot be undone — `INTAKE.md` is gitignored, so there is no committed copy."* Options **Delete it** / **Cancel**. Never skip it, in any invocation form. Cancel → write nothing, terminate.
4. **Remove** — `bash "$S" INTAKE.md <n> --remove-row`. It never renumbers; the `#` gap stays so `blocked-by` references and log entries never repoint. Exit `1` → re-read, write nothing more.
5. **Log** one `remove` entry: `--detail 'deleted "<idea>" (<grade>, <status>) — orphaned <prd-path>'`.

```
Deleted #4 from INTAKE.md — "add full-text search over notes"
  gap at #4 kept (rows are never renumbered)
  ⚠️ #6, #9 still graded S:blocked-by-#4 — run /intake --update to re-sequence them
  logged: 1 remove entry → INTAKE-UPDATE.md
```

When W3 fired, the summary must repeat the dangling rows.

## The update log — `INTAKE-UPDATE.md`

A separate root file beside `INTAKE.md`, append-only, lazy-created with its canonical header by the writer (the header lives only in `script-intake-stamp.sh`). One entry per changed cell:

```bash
bash "$S" INTAKE.md <row-#> --log-append --change <modify|add|remove> --detail "<text>"
```

- `modify` — `<cell>: <old> → <new>` (update, and `--health`/duplicate status fixes).
- `add` — `split from #n — "<idea>" (<grade>)`.
- `remove` — written by delete only.

## Three edit surfaces

| | update | delete | `/msg --gui` Intake tab |
|---|---|---|---|
| Owns | content (`idea`/`goal`/`type`) + re-grade | removal | `status` (drag between lanes) |
| Rows | `backlog` only | any | any |
| Gate | asks only when unclear | warning pass + confirm | none |
| Logged | one entry per cell | one `remove` entry | no |

`--health` and the shipped-duplicate stamp (`protocol-intake.md` Step 3) are the only intake paths that write `status`.
