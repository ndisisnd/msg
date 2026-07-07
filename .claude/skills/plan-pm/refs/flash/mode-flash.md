---
name: plan-pm-flash
description: plan-pm --flash — PRD authoring in 2 combined AUQ calls, GLOSSARY+ARCHITECTURE only, no epic/open-questions/AHA-writeback loops. Loaded instead of protocol-pm.md + protocol-interview.md when --flash is active.
---

# plan-pm --flash

Obeys `../../../shared/refs/flash-floor.md`. Loaded **instead of** `refs/protocol-pm.md`, `refs/protocol-interview.md`, and `refs/template-prd.md` (use `refs/flash/template-flash.md`). plan-pm *writes* the PRD, so the digest slices don't apply to its input — the win here is **interview turns** (2 vs the batched ≤4), not tokens.

## Interview — exactly 2 combined AskUserQuestion calls

1. **Call 1 — feature table.** One `multiSelect` gathering the PM-derived feature set: each option a proposed feature (title + one-line intent). The user picks/deselects; "Other" adds bespoke ones. From this, derive F-IDs and per-feature acceptance criteria.
2. **Call 2 — error / interaction / dependency checklist.** One `multiSelect` covering PM-derived error cases, key interactions, and cross-feature dependencies to confirm.

No third question on the happy path.

## Skipped vs comprehensive (interactivity, not correctness)

Epic-split ask · the open-questions elicitation loop · AHA.md writeback · the end-of-run next-step ask. Devkit reads are **GLOSSARY + ARCHITECTURE only** (not the full set).

## Output — must stay digest-parseable

Write the PRD from `refs/flash/template-flash.md`. It **must** retain, with the standard headings `scan-prd-digest.py` parses:
- The full canonical frontmatter (`name`, `feature`, `summary`, `module`, `platform`, `status`, `created`, plus the stamps product-tuned/eng-tuned/reviewed, depends_on, affects).
- The `## 6. Features & acceptance criteria` **table** with stable **F-IDs** — the digest reads features only from this table, never from prose sections.
- The `## 2. Out-of-scope` section.
- The `## 9. Plan tune findings` section (canonical heading — plan-tune appends here; never "Ledger").

Any feature whose detail is unknown gets a `[USER: …]` placeholder — never a silent omission. One-line `entry → step → outcome` flows suffice for interactions.

## Safety floor

F-ID stability, frontmatter stamps, §9 ledger, sub-PRD numbering rules — all unchanged (`flash-floor.md`).
