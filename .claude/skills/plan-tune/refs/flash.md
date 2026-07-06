---
name: plan-tune-flash
description: plan-tune --flash — critical-severity checks only, auto-fix all, zero gates, consumes the product/eng-audit digest slice. Loaded instead of tune-product.md / tune-eng.md when --flash is active.
---

# plan-tune --flash

Obeys `../../shared/refs/flash-floor.md`. Loaded **instead of** `refs/tune-product.md` / `refs/tune-eng.md`. The win is **critical-only checks + zero gates** — inputs are already sliced.

## Inputs — the digest slice

Consume the digest slice the comprehensive tune already reads (`scan-prd-digest.py`): `--slice product` for a product tune, `--slice eng-audit` for an eng tune. No `template-eng-plan.md` read.

## Critical-severity checks only

**Product tune:** placeholder / vague acceptance criteria · feature ↔ out-of-scope contradiction · conflicting acceptance criteria · timezone basis missing · glossary conflicts.

**Eng tune** adds: feature coverage gaps · missing/broken integration contracts · missing migration path.

Skip all non-critical severities (they're what the standalone comprehensive tune still covers, one command away).

## Gates & fixes

- **Zero `AskUserQuestion`** when the tune type + PRD path are both supplied.
- **Auto-fix all** findings directly in the **canonical PRD prose** (the digest is derived — edit the source, then the slice regenerates on next read).
- **Verify once** at the end (re-read the affected slice to confirm fixes landed).

## Ledger & stamps — unchanged

Findings are still appended to PRD **§9** with severity tags; the frontmatter stamp (`product-tuned: yes` / `eng-tuned: yes`) is still written. Fixes are applied to the canonical PRD, never the digest (`flash-floor.md`).
