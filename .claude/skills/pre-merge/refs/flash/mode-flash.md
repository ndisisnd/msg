---
name: pre-merge-flash
description: pre-merge's --flash path — collapses the analysis stages to mechanical + unit/int + security only, floor intact. Sync (1), preview when triggered (8), and PR open (9) still run. Flash never gates.
---

# pre-merge --flash

Obeys `../../../shared/refs/flash-floor.md`. Flash **collapses analysis stages**
(regression, the platform-bucket matrix, PRD-consistency) — it never collapses a
gate or a floor. The win is fewer stages, no confirmation gate.

## Runs vs skips

| Step | Flash |
|------|-------|
| 0 Platform mode | Runs (resolve profile — still needed for preview_kind). |
| Diff + tooling | Runs (consume prelude if fresh, else self-setup). |
| 1 SYNC (D7) | **Runs** — floor. No `staging` → refuse `no_staging`. |
| 2 MECHANICAL | **Runs** (scripts, cheap). |
| 3 UNIT + INTEGRATION | **Runs** (re-run post-sync). |
| 4 REGRESSION | **Skipped** — noted `skipped: {reason: "flash"}`. |
| 5 PLATFORM BUCKETS | **Skipped** — the whole matrix; noted `skipped: {reason: "flash"}`. |
| 6 SECURITY | **Runs** — safety floor, never relaxed. |
| 6 MIGRATION | **Runs** — floor, when the diff touches migrations. |
| 7 PRD-CONSISTENCY | **Skipped** — noted. |
| 8 PREVIEW DEPLOY | **Runs when triggered** (D6 / always in strict) — the human gate is never skipped. Blocks on approval. |
| 9 OPEN PR | **Runs** — opens feature→staging on a clean verdict. |

## Steps

1. **No confirmation gate** — auto-proceed. The Step 1 sync-conflict pause and the
   Step 8 preview approval are floor gates and still fire.
2. Run steps 2, 3, 6 (mechanical, unit-int, security/migration). Cap stage stdout
   ~50 lines; full logs to `.pre-merge/<ts>/<stage>.log`, path printed.
3. Aggregate + emit the single JSON (`refs/output-schema.md`) with the skipped
   records above. Verdict enum unchanged. Write the run report (best-effort) and,
   on a non-clean verdict, the `msg-gate/gate-<n>.json` fail-ticket — same shape as
   comprehensive.

## Safety floor — never relaxed

Refusals (`refs/refusal-patterns.md`) and the verdict enum are identical to
comprehensive: no source edits (bar the sync-merge), no `git push`/`gh pr merge`/`git
merge` into main, no run without a non-empty diff or without `staging`, no `blocker`
without quoted evidence. Security, migration, the sync-conflict pause, the preview
human gate, and DB-touch / breaking-change pauses all fire in flash exactly as
comprehensive. Flash drops analysis breadth, never a gate.
