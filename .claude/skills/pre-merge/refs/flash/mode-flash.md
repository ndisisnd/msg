---
name: pre-merge-flash
description: pre-merge's --flash execution path — build + security buckets only (bundle iff baseline), no gate, integration/e2e emit skip records, consumes the shared verify-prelude. Loaded instead of the full bucket matrix when --flash is active.
---

# pre-merge --flash

Obeys `../../../shared/refs/flash-floor.md`. The win is **2 buckets (build + security) vs 5**, and no confirmation gate.

## Buckets

| Bucket | Flash behavior |
|--------|----------------|
| build | Runs. |
| security | Runs (deep security). |
| bundle-size | Runs **only if** a bundle baseline exists; otherwise skipped with `skipped: {reason: "no_baseline"}`. |
| integration | **Skipped** — emits `skipped: {reason: "covered_by_test_run"}` (the T1.11 `--test-json` skip shape; reuses that path, does not invent a new one). |
| e2e | **Skipped** — same `skipped` record shape. |

## Steps

1. **Consume the verify-prelude (B4).** If a **fresh** `.claude/msg/cache/verify-prelude.json` exists (`../../../shared/refs/verify-prelude.md`), take `diff` + `tooling` from it instead of re-resolving/re-detecting. Composes with `--test-json`: a fresh test aggregate still drives the integration/e2e skip records. No fresh prelude → self-setup exactly as comprehensive.
2. **No gate.** Print the check matrix, then **auto-run** — skip the confirmation `AskUserQuestion`. (The safety-floor refusals below still fire and still stop the run.)
3. **Run build + security** (+ bundle iff baseline). Bucket stdout capped; raw logs to `.pre-merge/<ts>/<bucket>.log`, path printed.
4. **Emit** the single JSON document (`refs/output-schema.md`) with the two `skipped` records included. Verdict enum unchanged.

## Safety floor — never relaxed

Refusal patterns (`refs/refusal-patterns.md`) and the verdict enum are **identical** to comprehensive: no source edits, no `git push`/`gh pr merge`/`git merge`, no run without a non-empty diff, no `blocker` without quoted tool evidence. DB-touch and breaking-change pauses fire in flash exactly as comprehensive.
