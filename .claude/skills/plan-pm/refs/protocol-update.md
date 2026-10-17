---
name: PRD Update Protocol
description: The --update mode — change what an existing PRD says (features, scope, criteria, errors), keep it on the template, re-open certification, sync the change back to the PRD's INTAKE.md row through the ledger writer, and print the digest with the changed parts marked
type: reference
---

# Update mode (`--update`)

`--update` changes the **content** of a PRD that already exists: a feature added or
dropped, a criterion rewritten, the scope widened or narrowed, an error case added.
It is the content twin of `/intake --update`, one step later in the pipeline.

**Source of truth.** Before a PRD exists, the intake row is the source and plan-pm
never widens it (`principles.md` rule 1). Once the PRD exists, **the PRD is the
source and the row mirrors it.** This mode is how the two stay in step: every
content change lands in the PRD first, then the row is synced from it (U5).

Steps 1–5 of `refs/protocol-pm.md` do not run. Format-only conversion of an old PRD
is `--migrate` (`refs/protocol-migrate.md`), not this mode.

## Step U1 — Resolve the PRD and the change

| Argument | Resolution |
|---|---|
| a path | Use it. Not a file → hard-refuse: `Hard failure: --update target '<value>' is not a PRD file.` |
| a number `<n>` or `<n>.<m>` | Lane-agnostic: `features/{planned,wip,done}/prd-<n>-*/prd-<n>-*.md` (a sub-PRD sits one level deeper, inside its parent's folder), then legacy flat `features/prd-<n>-*/`. First hit wins. No match → hard-refuse: `Hard failure: --update target '<n>' does not match any PRD under features/.` |
| nothing | `AskUserQuestion` listing the PRDs whose `status` is not `complete`. |

Take the change from the user's words. Clear change → take it, no question. Vague
change (`make it simpler`) → one `AskUserQuestion` with 2–3 concrete readings plus
Other. One run edits one PRD.

**Lock gates — by the PRD's `status`:**

- `complete` → refuse: *"`prd-<n>` has shipped; a shipped PRD is a record. Run `/plan-pm --sub <n>` for follow-up changes."* Write nothing.
- `specced` or `wip` → one `AskUserQuestion` before any write: *"Engineering already planned this PRD. The change re-opens certification, and `/plan-em` may need to re-plan the affected features."* **Proceed** / **Stop**.
- `backlog` → no gate.

## Step U2 — Apply the change, on the template

Edit only the sections the change touches. Every edit follows the same rules as a
fresh draft:

- `refs/template-prd.md` — §1 two bullets, §3 criteria (`AC1`, `AC2`, … when a feature has several), §4 type labels, numbers only with a source, `[USER: …]` for an undecided value.
- `refs/error-checklist.md` — a new or changed feature is checked against the list, and its §4 rows are added or updated.
- `refs/principles.md` — rule 6 (one problem, one PRD): a change that adds a second user problem is refused here; send the user to `/intake` to capture it as its own row.

**F-IDs.** A new feature takes the next F-ID. A dropped feature moves to §2
Out-of-scope with a one-line reason. While §6 still holds its placeholder, the
remaining F-IDs may close the gap (F1..Fn stay sequential). Once §6 is populated,
never renumber: refuse to drop a feature other than the last, and suggest marking it
out of scope in a sub-PRD instead.

**§6 and §7 are never edited here.** They belong to plan-em and eng.

**No-op guard.** When the PRD text would not change, report `no change` and stop.

Then run the dependency mirror and the shape gate, exactly as `refs/protocol-pm.md`
Step 3 Parts 4–5 (`script-prd-deps-mirror.sh`, then `script-prd-shape.py`, checks
1–5). Exit 1 → fix the PRD and re-run until it exits 0.

## Step U3 — Re-open certification

A content change voids the certificate. When `reviewed` is `yes`, stamp it back:

```bash
S=.claude/scripts/script-prd-stamp.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-prd-stamp.sh"; bash "$S" <prd-path> reviewed no
```

plan-review then re-certifies before engineering uses the PRD (plan-em runs it inline).

## Step U4 — Re-grade, when the change is material

**Cosmetic** (wording, a clearer criterion, same scope) → the grade stays
byte-for-byte. **Material** (a feature added or dropped, the scope or surface
changed) → re-grade per `../intake/refs/rubric.md`: one banded judgment,
`C:<1|2|3|5|8|13> S:<now|next|later|blocked-by-#n>`, never a fake-precise number.

## Step U5 — Sync the intake row

plan-pm is the second writer of row content, **for PRD-linked rows only**. Every
write follows the intake ledger template (`../msg/refs/init/templates/TEMPLATE-INTAKE.md`
— same columns, same formats, same grade rules) and goes through the ledger writer,
never a hand edit:

```bash
S=.claude/scripts/script-intake-stamp.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-intake-stamp.sh"
bash "$S" INTAKE.md - --find-row --prd <prd-id>                 # read: ROW=<#> IDEA=… GOAL=…
bash "$S" INTAKE.md - --migrate-log                             # idempotent, before the first write
bash "$S" INTAKE.md <ROW> --set-cell <idea|goal|type|grade> "<new value>"
bash "$S" INTAKE.md <ROW> --log-append --change modify --detail "<cell>: <old> → <new> (plan-pm --update, <prd-id>)"
```

- **What to sync.** Rewrite `idea` and `goal` only when the PRD's scope or outcome changed, so the row still describes the PRD in one line each. Rewrite `grade` when U4 re-graded. Rewrite `type` only when the change turns a bug into a feature or back. A cosmetic PRD edit writes no cell.
- **One `--set-cell` per changed cell, one log entry per changed cell**, in the same operation. `--set-cell` prints the old value; use it for the log.
- **Never** write `#`, `date`, `status` or `prd` here.
- `FOUND=false` or no `INTAKE.md` → skip the sync with a one-line note and finish 🟡. Any other non-zero exit → stop and report; never fall back to a hand edit.

## Step U6 — Digest and close

Print the PRD digest, with the parts this run changed marked, directly above the
closing message:

```bash
G=.claude/scripts/script-prd-digest.py; [ -f "$G" ] || G="$HOME/.claude/scripts/script-prd-digest.py"
python3 "$G" <prd-path> --terminal --mark <title,change,builds,open — only the parts that changed>
```

`change` = §1 changed · `builds` = a §3 feature added, dropped or renamed · `open` =
the §5 open count changed · `title` = the feature name changed. A change only to
criteria or §4 marks nothing in the digest; name it in the closing message instead.

Close per `../shared/refs/closing-message.md`, using the `plan-pm --update` registry
row. Mandatory `What happened` rows: the PRD path, the sections changed, the row
cells synced (or the skip note), and `reviewed: yes → no` when U3 stamped it.

| Outcome | Protocol |
|---|---|
| PRD changed, shape gate passed, row synced (or nothing to sync) | 🟢 |
| Changed, but the row sync was skipped, or a `[USER: …]` placeholder or Open §5 row remains | 🟡 |
| Shape gate still failing, a lock gate refused, or a writer failed | 🔴 |
