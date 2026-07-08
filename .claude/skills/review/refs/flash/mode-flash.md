---
name: review-flash
description: review's --flash execution path — mechanical gates plus ONE combined semantic agent, auto-proceed, top-10 high-severity findings. Loaded instead of the comprehensive mode files when --flash is active.
---

# review --flash

Obeys `../../../shared/refs/flash-floor.md`. Loaded **instead of** `refs/modes/*` — a flash run reads this file and zero comprehensive mode files. The win is **1 semantic subagent vs ≤4**; the input side is already slim post-v2.

## Steps

1. **Resolve diff** — same as comprehensive Step 1 (`refs/schema.md` unaffected).
2. **Fingerprint-lite** — run `.claude/scripts/test-tooling-detect.sh`; take `mechanical_runners[]` + `secret_scanner` from its JSON. No full domain fingerprint, no `FLAG-LIST.md` load.
3. **Mechanical gates — identical to comprehensive.** Lint / format / typecheck (`mechanical_runners[]`) and the secret scan (`secret_scanner`) run with the **same** short-circuit behavior: any `block` stops the run before the semantic stage.
4. **No confirm gate.** Skip the Step 5 `AskUserQuestion` entirely — auto-proceed. Print the surface as **one line**: `Flash review → 1 agent over <N> files (min-severity high).`
5. **One combined semantic agent.** Spawn exactly **1** subagent with the distilled rubric below + the single injected cook payload the comprehensive path already compiles once (or none if no stack detected) — **0 per-mode cook fan-out**. Conditional-mode triggers (Migration, A11y/i18n) are the same static greps as SKILL.md Step 6; flash inherits them — a match just adds a bullet to the one agent's rubric, never a second subagent.
6. **Emit.** Cap at **top 10** findings after dedup; `--min-severity high` is the default floor (overridable). Single stdout transit + two file writes: `features/prd-<n>/review/review-<ts>.json` (when PRD known) and the run report `report-[n].md` per `../../../shared/refs/report-schema.md` (PRD's `reports/` dir, else `features/reports/`; best-effort, never blocks the run). Findings use the compact projection below.

## Distilled rubric (~300 words, the one agent's prompt)

Review the diff for, in priority order:
- **Correctness / quality** — logic errors, unhandled errors, broken contracts, obvious bugs, scope creep vs the PRD (`uncovered_changes[]` if available).
- **Security** — injection, auth/authz gaps, unvalidated input, secret leakage the mechanical scan missed.
- **Performance** — N+1 queries, unbounded loops/allocations, missing indexes, needless sync I/O.
Report only `high`+ by default. For each: `{severity, category, rule, message, file, line, suggestion}`.

## Compact schema — a projection, NOT a new schema

The emitted finding is the subset `{severity, category, rule, message, file, line, suggestion}` of the canonical `../../../shared/refs/finding-schema.md`. Same field meanings, same severity enum, same dedup key `(category, file, line, rule)` — flash just omits the fields comprehensive carries for aggregation. Verdict = worst across the emitted set (`block > warn > pass`).

## Verify-prelude producer (B4)

Flash review is still the prelude **producer** (`../../../shared/refs/verify-prelude.md`): after Steps 1-2 it writes a lite `.claude/msg/cache/verify-prelude.json` with the resolved `diff` + `tooling`, keyed on HEAD + base, so a following `test --flash` / `pre-merge --flash` consumes it. `eval_set_path` is `null` unless flash needed acceptance criteria — flash reads the PRD `eval` slice (`scan-prd-digest.py --slice eval`) **only** if the rubric requires PRD acceptance criteria; otherwise it skips eval-set derivation.

## Safety floor

Unchanged (`flash-floor.md`): secret scan runs, no source edits, no doc checks, no push/merge, refusals intact.
