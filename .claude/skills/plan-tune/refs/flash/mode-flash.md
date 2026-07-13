---
name: plan-tune-flash
description: plan-tune --flash — the critical-severity subset of the seven-check certification, auto-fix all, zero gates, consumes the product/eng-audit digest slice. Loaded instead of certification.md when --flash is active.
---

# plan-tune --flash

Obeys `../../../shared/refs/flash-floor.md`. Loaded **instead of** `refs/certification.md`. The win is **critical-only checks + zero gates** — inputs are already sliced, the seven checks are already consumer-bound.

## Inputs — the digest slice

Consume the digest slice the comprehensive certification already reads (`scan-prd-digest.py`): `--slice product` for a product tune, `--slice eng-audit` for an eng tune. No prose read beyond the slice's escape hatch.

## Critical-severity checks only

Run only the **Critical**-severity failure modes of the seven checks (`refs/certification.md`):

**Product tune (checks 1, 2, 3, 6):** empty/placeholder acceptance criterion (check 1 Critical) · timezone basis undefined (check 1 Critical) · unlabeled breaking/DB surface (check 2) · intake core goal entirely unaddressed (check 3 Critical) · a cycle in `depends_on` (check 6 Critical).

**Eng tune (checks 2, 4, 5, 6, 7)** adds: unlabeled breaking/DB surface (check 2) · missing F-ID coverage / guessed identifier / exec collision (check 4 Critical) · ticket dependency cycle or unknown-id (check 5 Critical) · `depends_on` cycle (check 6 Critical) · cross-agent integration-contract mismatch (check 7).

Skip every Major and Minor — those are what the standalone comprehensive certification still covers, one command away.

## Gates & fixes

- **Zero `AskUserQuestion`** when the tune type + PRD path are both supplied (flash forwards a resolved tune type — no auto-select prompt, no Minor ask, no product-decision batching; a genuine product-decision finding is logged `Open`, not paused on).
- **Auto-fix all** surfaced Criticals directly in the **canonical PRD prose** (the digest is derived — edit the source, then the slice regenerates on next read).
- **Verify once** at the end (re-read the affected slice to confirm fixes landed).

## Ledger, self-heal & stamps — unchanged

Findings are still appended to PRD **§9** with the canonical schema; each auto-fixed Critical still writes a `[tune:<category>]` learning to `devkit/AHA.md` (D16, skipped if devkit absent) and the recurrence check still runs; the frontmatter stamp (`product-tuned: yes` / `eng-tuned: yes`) is still written. Fixes are applied to the canonical PRD, never the digest (`flash-floor.md`).
