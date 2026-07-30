---
name: Intake Protocol
description: End-to-end capture protocol for /intake — scaffold-or-proceed on INTAKE.md, the interview (flesh-out / suggest-adjacent / goal), hybrid-ask + ≥8-idea splitting, the single-turn grading pass, and the row write.
type: reference
---

# Intake Protocol

The end-to-end flow **capture mode** (`/intake`, `/intake <idea text>`) follows.
Update mode (`/intake --update`) is a separate protocol —
[`protocol-update.md`](protocol-update.md) — which reuses this file's Step 2
hybrid-split, Step 3 flesh-out, and Step 4 grading passes rather than restating
them.

The whole run stays **≤2 `AskUserQuestion` calls for a well-formed idea**
(batch questions, ≤4 per call). Never read the codebase; never draft a PRD.

## Pre-run — reads

Before Step 1, stat-check and read in parallel via `Bash`:

| File | How to apply |
|------|-------------|
| `INTAKE.md` (repo root) | The ledger. Read existing rows for the next `#`, for sequencing (`S:`) context, and to detect duplicates. Missing → Step 1 offers to scaffold it. |
| `devkit/AHA.md` | Read once for **grading calibration** (`refs/rubric.md` § AHA calibration). Absent → skip silently, no scaffold prompt. |

Do not block on either; do not ask about them.

## Step 1/5 — Ledger check (scaffold or proceed)

If `INTAKE.md` is **absent** from the repo root, offer to scaffold it via one
`AskUserQuestion`:

> header **Ledger**, question "No `INTAKE.md` yet — create the backlog ledger?"
> - **Yes, create it** — write `INTAKE.md` at the repo root from
>   `.claude/skills/msg/refs/init/templates/TEMPLATE-INTAKE.md` (the same content
>   `/msg --init` would write: extract its `## Template body` fenced block verbatim).
>   Idempotent — never overwrite an existing file.
> - **Skip** — proceed in-memory but note the row can't be persisted; recommend
>   `/msg --init` or accept the scaffold to keep the ledger.

On **Yes**, write the file, then continue. If present already, proceed directly.

## Step 2/5 — Parse the ask (hybrid-split detection)

Take the user's idea text (from args or a prompt). Determine whether it is **one**
idea or a **compound/hybrid ask**.

- A **hybrid ask** bundles multiple separable capabilities: "streaks + notifications
  + rewards", "add search, and also fix the crash on logout". Each clause could ship
  as its own releasable feature or standalone bug.
- Split it into discrete candidate rows (one per capability), then **serve them back
  for confirmation** in a single `AskUserQuestion` (`multiSelect: true`) — each split
  idea is one selectable option; the user confirms/deselects, "Other" adds bespoke
  ones. This **replaces plan-pm's old epic-split gate** — splitting happens here, at
  capture, never at planning.
- A single clean idea skips the split confirmation entirely.

Classify each confirmed idea's `type` as `feature` or `bug` from its wording (a
defect/regression/"broken"/"crash" → `bug`; new capability → `feature`).

## Step 3/5 — Interview (flesh-out · suggest-adjacent · goal)

Per idea, run the interview **plan-pm used to own** — batched, ≤2 `AskUserQuestion`
calls total for a well-formed idea (≤4 questions per call). Skip any sub-question
already answered by the brief. The three purposes:

1. **Flesh out a thin idea.** When the idea is a one-liner with no shape, ask what it
   should concretely do — present 2–4 PM-derived interpretations + "Other". Capture the
   sharpened one-line `idea` text.
2. **Proactively suggest adjacent/complementary ideas.** Derive 1–3 neighbouring ideas
   that naturally extend the core (e.g. "streaks" → "streak-freeze", "streak leaderboard").
   Offer them as **additional candidate rows** via `multiSelect` — **never forced**; the
   user opts in. Accepted suggestions become their own rows (each graded in Step 4).
3. **Ask the core user goal + product objective when unclear.** If the idea's `goal`
   (the user outcome it serves) isn't evident, ask for it. A crisp goal is what makes the
   row plannable — `plan-pm` traces every drafted feature back to it.

Batch (1) and (3) into one call where possible; (2) can share that call or be the
second. A well-formed idea with an obvious goal may need **zero** interview questions —
grade and write it.

## Step 4/5 — Grade (single-turn, banded)

Grade every confirmed idea (core + accepted suggestions + split rows) per
`refs/rubric.md` — a **single-turn judgment, banded only, no analysis pass, no
codebase read.** Produce the compact `grade` cell: `C:<1|2|3|5|8|13> T:<1|2|3|5|8|13>
S:<now|next|later|blocked-by-#n>`.

**≥8-split gate.** Any idea graded `C:` ≥ `8` triggers one `AskUserQuestion`. Why the
gate exists and why the threshold is `8`: `refs/rubric.md` § *Complexity drives the split
gate* — this step owns only the mechanics.

> header **Split ≥8**, question "`<idea>` grades `<grade>` (cross-platform / migration + breaking
> surface). Break it into smaller ideas?"
> - **Yes, split it** — derive 2–4 smaller ideas (same muscle as Step 2), re-grade each
>   (typically `3`/`5`), and replace the `≥8` row with them.
> - **Keep it whole** — record the single `≥8` row; the downstream reviewability risk is
>   now a known, logged fact.

**Replacement semantics** — for this gate and for Step 2's hybrid split, in capture and
in `--update` alike: the original row's `#` is retained by the **first** resulting row;
the others take fresh `#`s after the current maximum. No existing `#` is reused or
renumbered, so `S:blocked-by-#n` references elsewhere in the ledger never dangle. At
capture there is no original row on disk yet, so every resulting row is simply appended.

## Step 5/5 — Write the rows + summarise

Append each confirmed, graded idea to `INTAKE.md`'s row table, in capture order — **one
call per row**, through the shared ledger writer. Never hand-edit the file:

```bash
S=.claude/scripts/stamp-intake.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/stamp-intake.sh"
bash "$S" INTAKE.md <row-#> --append-row \
  --type <feature|bug> --idea "<idea>" --goal "<goal>" --grade "<grade cell>"
```

What you decide:

- `<row-#>` — next integer after the highest existing row (`1` for the first); increment it yourself across a multi-row capture.
- `--type` — `feature` or `bug`.
- `--idea` — the sharpened one-line description.
- `--goal` — the core user outcome (or `[USER: …]` if the user genuinely declined to specify — never invent one).
- `--grade` — the Step-4 cell.

What the writer guarantees, so this protocol no longer promises it: `date` defaults to
today, `status` to `backlog` (capture never advances a row), `prd` to empty; every other
row, the header and the surrounding prose stay byte-identical; pipes inside `idea`/`goal`
are escaped; a legacy in-file `## Update log` section is never appended past — the new
row lands inside the ledger table above it.

**Exit codes:** `0` written · `1` no ledger table (Step 1 should have caught that —
re-check the file) · `2` usage error · `4` that `#` already exists (re-read the ledger
for the true maximum, then retry) · `5` write failure. On any non-zero, stop and report;
do not fall back to a hand-edit.

**Capture writes no log entries** — the row's own `date` cell already records when it
entered, and logging captures would duplicate the whole ledger into the log. The log is
`--update`/`--delete`'s file: `protocol-update.md` § *The update log*. Migrating a legacy
in-file `## Update log` section out is likewise their job on first touch, not capture's.

Then emit a compact summary:

```
Captured <N> row(s) into INTAKE.md: #<a> <idea> (<grade>), #<b> …
Next: run /plan-pm to draft a PRD from the backlog, or /intake again to add more.
```

Recommend (never invoke) `plan-pm`. Terminate.
