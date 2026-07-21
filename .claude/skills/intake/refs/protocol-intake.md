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

Emit `Step X/5 — <title>` at the start of
each step. The whole run stays **≤2 `AskUserQuestion` calls for a well-formed idea**
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

**≥8-split gate.** Any idea graded `C:` ≥ `8` triggers one `AskUserQuestion`:

> header **Split ≥8**, question "`<idea>` grades `<grade>` (cross-platform / migration + breaking
> surface). Break it into smaller ideas?"
> - **Yes, split it** — derive 2–4 smaller ideas (same muscle as Step 2), re-grade each
>   (typically `3`/`5`), and replace the `≥8` row with them. Front-door defence of
>   reviewability — each piece is small enough for one reviewer to hold at once.
> - **Keep it whole** — record the single `≥8` row; the downstream reviewability risk is
>   now a known, logged fact.

## Step 5/5 — Write the rows + summarise

Append each confirmed, graded idea as a row to `INTAKE.md`'s table, in capture order:

```
| # | date | type | idea | goal | grade | status | prd |
```

- `#` — next integer after the highest existing row (`1` for the first).
- `date` — today, `YYYY-MM-DD`.
- `type` — `feature` or `bug`.
- `idea` — the sharpened one-line description.
- `goal` — the core user outcome (or `[USER: …]` if the user genuinely declined to specify — never invent one).
- `grade` — the Step-4 cell.
- `status` — `backlog` (always, on capture — intake never advances a row).
- `prd` — empty (filled by `plan-pm` when it plans the row).

Preserve every existing row verbatim; only append. **Capture writes no log
entries** — the row's own `date` cell already records when it entered, and
logging captures would duplicate the whole ledger into the log. The log lives
in `INTAKE-UPDATE.md`, a separate file written only by `--update`/`--delete`;
capture never touches it. If a legacy `INTAKE.md` still carries an in-file
`## Update log` section (pre-migration), append new rows **above** it, inside
the row table — migrating that section out to `INTAKE-UPDATE.md` is
`--update`/`--delete`'s job on their first touch, not capture's.

Then emit a compact summary:

```
Captured <N> row(s) into INTAKE.md: #<a> <idea> (<grade>), #<b> …
Next: run /plan-pm to draft a PRD from the backlog, or /intake again to add more.
```

Recommend (never invoke) `plan-pm`. Terminate.
