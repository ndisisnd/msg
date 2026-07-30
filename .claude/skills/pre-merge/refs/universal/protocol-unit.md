---
name: unit
description: The unit component — run the unit test suite via the detected runner. Script only, no LLM. Non-zero exit is a blocker; a missing runner is never a blocker.
---

# `unit` — the unit-test component

Deterministic, **no LLM**. Runs on the post-sync branch (it always re-runs after
SYNC's merge). Findings conform to `../finding-schema.md`; `source: unit`.

## Runner

Use the `run` command resolved for the `unit` component in `devkit/policy.json`
`components[]` (detected at `--init`/`--update` by `script-preflight-02-unit.sh`) — do
not re-detect. Restrict the invocation to the unit-suite subset when the runner's config
distinguishes one (e.g. a `unit/` test directory, a `--testPathPattern`/`-m unit`
marker, a pytest `unit` marker); else run the component's default suite.

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

## Minified invocation

`unit` is selection-capable. When the executor resolved a **minified** run for this
component, execute `components[].run_minified` instead of `run` and record
`selected`/`total` (plus `fallback_reason` when the rule fell back to full). The
selection rule, the size tiers, every fallback, and the recording contract live in
**one place** — `../executor.md` §3c. This component executes whichever command it is
handed; it never decides selection itself.

Selection changes **how many** tests ran, never how a finding is graded: a failing
selected test is the same `blocker` it would be under a full run.

## Short-circuit

A `blocker` here does **not** abort the pipeline. Only the **critical class**
(`mechanical`, `security`, `migration`) short-circuits a run — the one rule lives in
`../severity-rubric.md` § *Fail-fast by component `criticality`*. A `unit` failure is
`blocking`: it fails the verdict and blocks its dependents (`coverage`), while
independent components finish so the verdict aggregates the full picture.
