---
name: integration
description: Gate Step 3 (integration half) — run the integration test suite via the detected runner. Script only, no LLM. Non-zero exit is a blocker; a missing runner is never a blocker.
---

# Step 3 — INTEGRATION

Deterministic, **no LLM**. Runs on the post-sync branch (Step 3 always re-runs after
Step 1's sync-merge), alongside `protocol-unit.md`'s pass. Findings conform to
`../finding-schema.md`; `source: integration`.

## Runner

Use the `run` command resolved for the `integration` component in `devkit/policy.json`
`components[]` (detected at `--init`/`--update` by `preflight-check-03-integration.sh`) —
do not re-detect. Restrict the invocation to the integration-suite subset when the
runner's config distinguishes one (an `integration/` or `test/integration` directory, a
`--testPathPattern`/`-m integration` marker, a pytest `integration` marker, Flutter's
`integration_test/`); else run the component's default suite.

```
rtk <test_runner.command>
```

`test_runner` is `null` → try the stack's conventional invocation before giving up:
`python3 -m pytest`, `npm test`, `go test ./...`, `cargo test`, `flutter test
integration_test/` (first one whose toolchain file is present). Still nothing →
record `skipped: {reason: "no_tooling"}`, `pass_with_warnings` — **a missing runner is
never a blocker.**

## Verdict

- Non-zero exit → `blocker` finding (`source: integration`, `rule:
  integration-test-failure`), first failing test name + assertion quoted.
- Exit 0 → `pass`; totals `{ passed, failed, skipped }` from the runner's own summary
  line/report when parseable, else a pass/fail count only.
- Environment-only failure (unreachable test DB/service dependency, container not
  running) → `pass_with_warnings`, note naming the unreachable dependency — never a
  false block from a broken local environment.

## Minified invocation (§3c)

`integration` is one of the three **selection-capable** components
(`../../../shared/refs/component-catalog.md` legend `ˢᵉˡ`). When
`policies.test_selection` resolves **enabled** (or `--minified`) and not `--full`,
the executor may have resolved a **minified run** for this component per the
5-step rule (`../executor.md` §3c): affected(diff) ∪ critical-floor instead of the
full suite. This section governs what changes when that happens — nothing else in
this protocol changes.

- **Invocation.** Run the `run_minified` command already resolved in the manifest
  (`components[].run_minified`, detected by `preflight-check-03-integration.sh`
  alongside `run`) instead of `run`. Do **not** re-detect or re-resolve it here —
  the executor hands this component a single command to execute, exactly as it
  does for `run`.
- **Every fallback in the §3c rule lands back on `run` (full)** — `force_full_paths`
  hit, `run_minified == null`, an unresolvable affected set, or tier **L** all mean
  this component runs its ordinary `run` command, not `run_minified`.
- **At tier M, `integration` ALWAYS runs full — never `run_minified`
  (§3c.1).** This is the one tier-table cell where `integration` diverges from
  `unit`: as breadth grows past **S**, the residual risk shifts from "this unit is
  wrong" (still covered by `unit`'s selection, which stays precise at file
  granularity) to **cross-module interaction** — exactly `integration`'s domain.
  So tier M pays for the full `integration` suite while `unit` stays selected. This
  is stated here, not only in the executor, so this protocol and `../executor.md`
  can't drift on it: `run_minified` is only ever invoked at tier **S**.
- **Record `selected/total` + `fallback_reason?`.** The result report carries the
  same `totals: {passed, failed, skipped, flaky}` shape as a full run, plus (only
  on a minified — i.e. tier-S — run) `selected`/`total` test counts and, when the
  rule fell back to full (including the tier-M widen above), the `fallback_reason`
  naming which step fired, verbatim in the `../output-schema.md` vocabulary
  (`force-full: <path>` / `run_minified: null` / `fallback: <reason>` /
  `tier: M (widen-to-full)` — the `integration`-only value / `tier: L (<trigger>)`).
- **Verdict semantics never change.** Selection changes **how many** tests ran,
  never how a finding is graded: a failing selected test is a `blocker`
  (`rule: integration-test-failure`) exactly as under a full run, and the
  environment-only-failure `pass_with_warnings` rule above is unaffected —
  nothing here loosens or tightens the Verdict section.

## `--flaky <N>` (per `../_common.md`)

Re-run each failing test up to `N` times via its `repro`, stopping on first pass.
Passes-on-retry → reclassify `medium`, `evidence.flaky: true`,
`evidence.retries: <n>`, counts toward `totals.flaky` not `totals.failed`. Still
failing after `N` retries → genuine `blocker`.

## Short-circuit

A `blocker` here does **not** short-circuit later steps by itself — Steps 4–8
continue so the verdict aggregates the full picture per `../severity-rubric.md`.
