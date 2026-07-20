---
name: unit
description: Gate Step 3 (unit half) — run the unit test suite via the detected runner. Script only, no LLM. Non-zero exit is a blocker; a missing runner is never a blocker.
---

# Step 3 — UNIT

Deterministic, **no LLM**. Runs on the post-sync branch (Step 3 always re-runs after
Step 1's sync-merge). Findings conform to `../finding-schema.md`; `source: unit`.

## Runner

Read `test_runner` from the Step 1 tooling fingerprint
(`pre-merge-tooling-detect.sh`) — do not re-detect. Restrict the invocation to the
unit-suite subset when the runner's config distinguishes one (e.g. a `unit/` test
directory, a `--testPathPattern`/`-m unit` marker, a pytest `unit` marker); else run
the runner's default suite (today's tooling fingerprint does not yet split
unit-only/integration-only commands — the per-component detect scripts that add that
split land in Phase 2).

```
rtk <test_runner.command>
```

`test_runner` is `null` → try the stack's conventional invocation before giving up:
`python3 -m pytest`, `npm test`, `go test ./...`, `cargo test`, `flutter test` (first
one whose toolchain file is present). Still nothing → record `skipped: {reason:
"no_tooling"}`, `pass_with_warnings` — **a missing runner is never a blocker.**

## Verdict

- Non-zero exit → `blocker` finding (`source: unit`, `rule: unit-test-failure`), first
  failing test name + assertion quoted.
- Exit 0 → `pass`; totals `{ passed, failed, skipped }` from the runner's own summary
  line/report when parseable, else a pass/fail count only.

## `--flaky <N>` (per `../_common.md`)

Re-run each failing test up to `N` times via its `repro`, stopping on first pass.
Passes-on-retry → reclassify `medium`, `evidence.flaky: true`,
`evidence.retries: <n>`, counts toward `totals.flaky` not `totals.failed`. Still
failing after `N` retries → genuine `blocker`.

## Short-circuit

A `blocker` here does **not** short-circuit later steps by itself (only Step 2
mechanical does) — it still fails the run; Steps 4–8 continue so the verdict
aggregates the full picture per `../severity-rubric.md`.
