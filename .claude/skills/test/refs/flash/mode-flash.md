---
name: test-flash
description: test's --flash execution path — unit + functional buckets only, in-process (no subagents), no plan gate, consumes the shared verify-prelude. Loaded instead of the full bucket set when --flash is active.
---

# test --flash

Obeys `../../../shared/refs/flash-floor.md`. A flash run reads **only** this file + `refs/modes/_common.md` + `refs/modes/unit.md` + `refs/modes/functional.md` — no other bucket file. The win is **2 buckets in-process vs the parallel fan-out of up to 10**.

## Steps

1. **Scope** — `--changed-only` is implied against the merge base (or `--base` if supplied). Resolve the changed-file set once.
2. **Consume the verify-prelude (B4).** If a **fresh** `.claude/msg/cache/verify-prelude.json` exists (`../../../shared/refs/verify-prelude.md` freshness rule: HEAD + base match), take its `tooling` (skip re-detection) and `eval_set_path` (wire straight into the functional bucket as if `--eval-set` were passed). No fresh prelude → self-setup exactly as comprehensive (`test-tooling-detect.sh` + PRD/eval bootstrap).
3. **No plan gate.** Skip the Step 3 confirmation `AskUserQuestion` — auto-proceed. **0 subagents** — run both buckets **in-process** on the main thread.
4. **Unit bucket** — `refs/modes/unit.md`, scoped to changed files. Runner stdout capped ~50 lines/bucket; full log to a file, path printed.
5. **Functional bucket** — `refs/modes/functional.md`, running only the `executable` assertions from the eval_set (prelude or `--eval-set`).
6. **Emit** — aggregate to the canonical schema (`refs/schema.md`), print a summary + the JSON file path (no full JSON echo). On a non-clean verdict, write the Step 6 fail ticket exactly as comprehensive (same shape) — this is the only conditional write; no second gate in flash (auto-proceed).

## What flash drops (execution count, not correctness)

e2e, qa, load, a11y, perf, api, mobile, coverage buckets; parallel subagent dispatch; the plan-confirmation gate; the full-JSON stdout echo.

## Safety floor

Unchanged (`flash-floor.md`): fail ticket still written on non-clean verdict, no source edits, writes confined to `features/`/`/tmp/`/`msg-test/`, no push/merge.
