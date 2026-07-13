---
name: plan-pm-flash
description: plan-pm --flash — autonomous PRD authoring from an intake row in ≤1 pause, GLOSSARY+ARCHITECTURE only, no AHA-writeback loop. Loaded instead of protocol-pm.md when --flash is active.
---

# plan-pm --flash

Obeys `../../../shared/refs/flash-floor.md`. Loaded **instead of** `refs/protocol-pm.md`
and `refs/template-prd.md` (use `refs/flash/template-flash.md`). The interview already
happened at `/intake` — flash, like comprehensive, **consumes a graded intake row and
drafts solo**; the flash win is fewer pauses and a slimmer template, not a leaner interview
(there is none to trim).

## Flow — same entry paths, collapsed pauses

1. **Resolve the idea (Step 1, unchanged).** No args → list non-`completed` `INTAKE.md`
   rows → one `AskUserQuestion` to pick. `#n` / matching text → plan directly. Direct prose
   with no row → **skip the /intake bounce in flash** and draft directly, noting the ledger gap.
2. **Scan prior PRDs (Step 2, unchanged).** Cheap frontmatter read; sets `depends_on`/`affects`
   and the breaking-surface flag.
3. **Draft solo (Step 3).** Populate `refs/flash/template-flash.md` from the intake `idea` +
   `goal`. Any unknown detail → `[USER: …]` placeholder, never a silent omission.
4. **Pauses collapse to ≤1.** Batch open questions + the breaking/critical safety pause into a
   **single** `AskUserQuestion` where both apply (≤4 entries). The safety pause itself is
   **never dropped** — if the draft would break a shipped contract or cut DB/data/prod-config,
   it fires even in flash (flash-floor). No open questions and no breaking surface → zero pauses.

## Skipped vs comprehensive (interactivity, not correctness)

The AHA.md writeback · the `/intake` bounce for un-logged prose · the end-of-run follow-up ask.
Devkit reads are **GLOSSARY + ARCHITECTURE only** (not the full set). The **intake lifecycle
stamp still fires** (Step 5 — set the source row `in-progress` + `prd`), and `plan-tune --product`
is still recommended (never invoked) at termination.

## Output — must stay digest-parseable

Write the PRD from `refs/flash/template-flash.md`. It **must** retain, with the standard headings `scan-prd-digest.py` parses:
- The full canonical frontmatter (`name`, `feature`, `summary`, `module`, `platform`, `status`, `created`, the stamps product-tuned/eng-tuned/reviewed, depends_on, affects, and `intake: #<n>` when there is an ancestor row).
- The `## 6. Features & acceptance criteria` **table** with stable **F-IDs** — the digest reads features only from this table, never from prose sections.
- The `## 2. Out-of-scope` section.
- The `## 9. Plan tune findings` section (canonical heading — plan-tune appends here; never "Ledger").

Any feature whose detail is unknown gets a `[USER: …]` placeholder — never a silent omission. One-line `entry → step → outcome` flows suffice for interactions.

## Safety floor

F-ID stability, frontmatter stamps, §9 ledger, sub-PRD numbering rules, the breaking/critical safety pause, the intake lifecycle stamp — all unchanged (`flash-floor.md`).
