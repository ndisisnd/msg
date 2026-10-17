---
name: Intake Protocol
description: End-to-end capture protocol for /intake — the light context scan, one open prompt, inference, principle-driven questions, in-scope splits and brainstorm suggestions, duplicate handling, banded grading, and the row write.
type: reference
---

# Intake Protocol

Capture mode: `/intake`, `/intake <idea text>`, `/intake --brainstorm …`. Capture has **no fixed questions**. It asks only what [`principles.md`](principles.md) flags as unclear. Never draft a PRD and never run a codebase analysis — that is `plan-pm`'s job.

Writer, for every ledger call below:

```bash
S=.claude/scripts/script-intake-stamp.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-intake-stamp.sh"
```

## Pre-run — light context scan

Read in this order, in parallel where possible. Skip a missing file silently. Read only the first ~100 lines of a long file.

1. Memory (the project's auto-memory index, when present).
2. `CLAUDE.md`.
3. `README.md`.
4. `devkit/GLOSSARY.md`.
5. `ARCHITECTURE.md` (repo root or `devkit/`).
6. PRD titles and one-line summaries in `features/` — `bash .claude/scripts/script-prd-scan.sh` (id, feature, status per PRD). Never open a full PRD.
7. Open ledger rows: `bash "$S" INTAKE.md - --list-rows --status backlog,in-progress`. Keep `MAX_ROW` — the next row `#` is `MAX_ROW + 1`. Never read `INTAKE.md` in full.
8. `devkit/AHA.md` (grading calibration).
9. The brainstorm switch: `policies.intake.brainstorm` in `devkit/policy.json`. Absent → `false`.

Read source code only when the user names a screen or feature that this list does not explain. Read at most 3 files.

## Step 1/5 — Ledger check

`INTAKE.md` absent → write it from `.claude/skills/msg/refs/init/templates/TEMPLATE-INTAKE.md` (its `## Template body` fenced block, verbatim). No question. Never overwrite an existing file.

## Step 2/5 — Take the input and infer

- No idea text in the args → ask once, in plain text: **"What are you trying to build?"** The user answers in free prose.
- Build your own reading of each idea from the prose plus the context scan: the one-line `idea`, the user `goal`, and the `type` (`bug` for a defect, crash or regression; else `feature`).
- Split the prose into rows by principles 3 and 4. A pasted list or several ideas in one run is split by your own judgment — no confirm question.
- Keep every reading and split inside the product the context shows (principle 2).

## Step 3/5 — Check: ask, de-duplicate, suggest

1. **Ask only when unclear.** Compare the input with your reading, using `principles.md`. Unclear → one batched `AskUserQuestion` (principle 7). Clear → ask nothing.
2. **Duplicates.** For each idea, search the ledger by its key words: `bash "$S" INTAKE.md - --list-rows --match "<key words>" --limit 5`. Judge matches by principle 5.
   - Open match (`backlog`) → offer to update that row instead of adding a near-copy (one `AskUserQuestion`: **Update #n** / **Add as new row**). On update, run [`protocol-edit.md`](protocol-edit.md) Steps 3–5 for that row.
   - Open match (`in-progress`) → add the new idea as its own row and name the related row in the summary. The edit lock still holds.
   - Match whose PRD has shipped (`completed`, or the PRD scan shows it shipped) → the row is closed (principle 6). When its `status` is not yet `completed`, stamp it: `bash "$S" INTAKE.md <n> --status completed`, then log it (`--log-append --change modify --detail "status: <old> → completed (PRD shipped)"`). Tell the user it shipped, and capture the new idea as a follow-up row.
3. **Brainstorm suggestions.** Only when brainstorm is on for this run (`SKILL.md` § Brainstorm). Offer 1–3 related, in-scope ideas as extra candidate rows in one `multiSelect` `AskUserQuestion`. The user opts in. Brainstorm off → suggest nothing beyond what the user asked for.

## Step 4/5 — Grade

Grade every row per [`rubric.md`](rubric.md): a single-turn banded judgment, cell `C:<1|2|3|5|8|13> S:<now|next|later|blocked-by-#n>`.

A row at `C:` ≥ `8` is a split candidate (rubric § The split threshold). Split or keep it whole by principle 3. Re-grade each part.

**Replacement semantics** (splits in capture and in edit mode): the original row's `#` goes to the **first** resulting row. The other rows take fresh numbers after `MAX_ROW`. No `#` is reused or renumbered. At capture there is no original row yet, so every row is appended.

## Step 5/5 — Write + summarise

Append each row in capture order, one call per row. Never hand-edit the file:

```bash
bash "$S" INTAKE.md <row-#> --append-row \
  --type <feature|bug> --idea "<idea>" --goal "<goal>" --grade "<grade cell>"
```

- `<row-#>` — `MAX_ROW + 1`, then increment across a multi-row capture.
- `--goal` — the user outcome. Write `[USER: …]` only when the user declined to give one. Never invent a goal.
- The writer sets `date` (today), `status` (`backlog`) and an empty `prd`. It escapes pipes and leaves every other byte alone.
- **Exit codes:** `0` written · `1` no ledger table · `2` usage error · `4` that `#` exists (re-run `--list-rows` for the true `MAX_ROW`, then retry) · `5` write failure. Any other non-zero → stop and report. Never fall back to a hand-edit.

Capture writes **no** log entry: the row's `date` cell records it.

Summary — every grade carries its plain-English label (rubric):

```
Captured 2 row(s) into INTAKE.md:
  #7 add full-text search over notes — Complexity 5 — medium: a few screens or one new service · Sequencing now — ready to plan next
  #8 fix the crash on logout — Complexity 1 — tiny: one rule or one small piece · Sequencing next — after the current work
Next: /plan-pm to draft a PRD from the backlog, or /intake to add more.
```

Recommend (never invoke) `plan-pm`. Terminate.
