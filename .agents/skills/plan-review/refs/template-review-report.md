---
name: Review Report Template
description: The external findings ledger plan-review writes per PRD — one file, one growing table, created on the first run and appended to thereafter
type: reference
---

# Review Report Template

`plan-review`'s findings do not live in the PRD. Each PRD gets one report at:

```
<prd-dir>/reports/review-prd-[n]-[slug].md
```

`<prd-dir>` is the PRD's own folder, in whatever lane it currently sits — the report travels with the PRD when `merge --production` relocates the folder, because it lives inside it.

**The frontmatter stamp is still the gate signal.** `reviewed: yes` in the *PRD's* frontmatter is what `script-cert-status.sh` and `plan-em`'s preconditions read. This report is the evidence trail behind that stamp, never a second gate.

## Why the findings moved out

A PRD is a contract that downstream stages read on every run. Audit history is append-only and grows without bound, so keeping it inline meant every consumer of the contract paid to re-read the whole audit trail. Moving it out shrinks the PRD without losing anything: the ledger is still one growing table, still deduped, still monotonically numbered.

## Do not confuse it with the eng review artifact

`reports/` also holds `review-prd-<N>-<K>.json` — the **eng** review evidence written per build packet by `eng --review`, introduced in v5.3. The two are different files with different shapes:

| File | Written by | Format | Contains |
|---|---|---|---|
| `review-prd-[n]-[slug].md` | `plan-review` | Markdown, one findings table | PRD contract certification findings |
| `review-prd-<N>-<K>.json` | `eng --review` | JSON | Per-packet build review evidence |

Any glob that means to match one must not match the other. The markdown ledger ends in `.md` and its suffix is the PRD **slug**; the eng artifact ends in `.json` and its suffix is a numeric packet **index**.

## The file

`script-ledger.py` creates this scaffold on the first run and appends to the table thereafter — never hand-write it, and never create a second file or a second table.

```markdown
---
name: review-prd-[n]-[slug]
prd: prd-[n]-[slug]
created: YYYY-MM-DD
last-run: YYYY-MM-DD
---

# Review findings — prd-[n]-[slug]

One growing table, appended across runs. Row numbers are monotonic and never
reset; an open row's `Status` is recomputed on each run.

## Findings

| # | Date | Severity | What is wrong | Suggested fix | Why it matters | Status |
|---|---|---|---|---|---|---|
```

`created` is set once, on the run that creates the file. `last-run` is rewritten on every run, so the report says when it was last audited even when that run found nothing.

## Column contract

| Column | Meaning |
|--------|---------|
| `#` | Monotonic finding number, continued across runs — never reset to 1. |
| `Date` | The run that first raised this finding, or the last run that re-confirmed it still open. |
| `Severity` | `Critical` / `Major` / `Minor`, per the rubric in `certification.md`. `—` on the clean-marker row. |
| `What is wrong` | Terse: the section plus which check fired. This cell is also the dedup key — a repeat run recognises a finding by this text and updates that row in place rather than adding a second one. |
| `Suggested fix` | The concrete action. `—` when there is none. |
| `Why it matters` | The named downstream consumer that breaks. `—` when there is none. |
| `Status` | `Open` / `Still open` / `Fixed` / `Clean`. |

**There is no `Auditor` column.** The tune waves fused into one mode with one auditor, so the column carried no information. PRDs written before v5.4 carry their findings inline as a `## 7. Plan review findings` section whose table *does* have that column — those files keep their eight-column table and are still appended to in place. Nothing is migrated.

## Status recomputation

On every run, before appending:

- A finding raised again this run → that row's `Status` becomes `Still open` and its `Date` becomes today. No new row.
- A finding not reported this run → its row is left untouched. That is how a row already marked `Fixed` stays `Fixed`.
- A run with no findings at all → one `Clean` marker row, so the table records that the audit ran and found nothing.
