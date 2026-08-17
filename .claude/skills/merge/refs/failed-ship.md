---
name: Failed-ship loop
description: What merge does after a failed ship — the rollback / rollout-halt offer, the issues file, the run report, and the fix-loop handoff
type: reference
---

# Failed-ship loop

When a ship **fails** — a non-zero deploy or a verification failure, verdict
`fail`, in **either** mode — the merge already happened, so merge does not
dead-end. In order:

1. **Offer the rollback / rollout-halt — BEFORE the fix loop, always-ask, never
   auto.** The highest-value action after a broken ship is to restore last-good
   (deploy model) or halt the rollout (submission model). The failing platform's
   lever is already resolved — `script-platforms-parse.py` emits
   `<p>.rollback_lever_key` (which lever this model uses) and
   `<p>.rollback_lever` (the command; empty ⇒ unconfigured):
   - **`deploy` model with a configured `rollback_cmd`** → `AskUserQuestion`
     (header **Rollback**): "The `<platform>` `<staging|production>` deploy
     failed. Restore the last-good build now (`rollback_cmd`)?" — **Yes, roll
     back** runs the cmd and records its exit/outcome; **No, continue to fixes**
     proceeds. For a **`server`/backend platform, always carry this line with the
     offer**: *redeploying the last-good build does **not** revert schema
     migrations already applied — check the database state before and after.*
     Merge does not detect migrations; it states the caveat every time so
     the human is never surprised by a half-reverted release.
   - **`submission` model with a configured `rollout_halt_cmd`, once a rollout
     exists** (a `--production` submission in staged rollout / phased release —
     not `--staging`'s internal track, not a rejected-at-upload) →
     `AskUserQuestion` (header **Halt rollout**): "The `<platform>` rollout is
     live/pending (`<track>`). Halt the staged rollout / phased release now
     (`rollout_halt_cmd`)?" — halt ≠ full un-ship; the approved build stays out
     (`submission.md`). If the rollout is not yet live, note the halt may
     need re-running once it begins.
   - **Unconfigured** (no lever, or a `[USER: …]` placeholder) → surface the
     `rollback_possible` note for manual restore and **flag the missing lever as
     a gap**. No offer is fabricated.
   - **Never auto-run** any lever — a false-positive smoke must not revert a good
     release. Under an autonomy contract with no human present, default to
     **decline** and record the offer as declined. Capture
     `{offered, lever, approved, cmd_exit, outcome}` per platform into the run
     report (`output-schema.md`).
2. **Write the issues file** `features/prd-<N>-<slug>/reports/report-prd-<N>-<K>.json`
   — colocated in the PRD's `reports/` folder, sharing `N`/`K` with the run
   report (NO-PRD fallback: `features/reports/report-<K>.json`). Same canonical
   `issues[]` shape pre-merge writes (`followUp.status` camelCase contract kept —
   the key `eng --build` writes back and the `--gui` board reads).
   `followUp.suggested_command` = `eng --build report=<that path>`.
3. **Write the run report**, carrying the `## Issue summary` block and the
   rollback-offer outcome.
4. **Print the terminal `Issue summary` block.**
5. **Hand off to `../../shared/refs/fix-loop.md`** — it owns Offer #1 (`eng --plan`)
   → Offer #2 (`eng --build`) off this issues file; do not re-spell that wording
   here. The rollback offer **precedes** this and never replaces it — a
   rolled-back release still has a broken commit to fix forward. **For
   `--production` the release lock releases at ship-terminal — after step 1,
   before this handoff — so the fix loop never holds the lock.**

The fixed branch comes back through `/pre-merge` and this gate.
