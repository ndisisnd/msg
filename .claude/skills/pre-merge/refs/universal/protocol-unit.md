---
name: unit
description: Gate Step 3 (unit half) — run the unit test suite via the detected runner. Script only, no LLM. Non-zero exit is a blocker; a missing runner is never a blocker.
---

# Step 3 — UNIT

Deterministic, **no LLM**. Runs on the post-sync branch (Step 3 always re-runs after
Step 1's sync-merge). Findings conform to `../finding-schema.md`; `source: unit`.

## Runner

Use the `run` command resolved for the `unit` component in `devkit/policy.json`
`components[]` (detected at `--init`/`--update` by `preflight-check-02-unit.sh`) — do
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

## Minified invocation (§3c)

`unit` is one of the three **selection-capable** components (`../../../shared/refs/component-catalog.md`
legend `ˢᵉˡ`). When `policies.test_selection` resolves **enabled** (or `--minified`)
and not `--full`, the executor may have resolved a **minified run** for this
component per the 5-step rule (`../executor.md` §3c): affected(diff) ∪
critical-floor instead of the full suite. This section governs what changes when
that happens — nothing else in this protocol changes.

- **Invocation.** Run the `run_minified` command already resolved in the manifest
  (`components[].run_minified`, detected by `preflight-check-02-unit.sh` alongside
  `run`) instead of `run`. Do **not** re-detect or re-resolve it here — the executor
  hands this component a single command to execute, exactly as it does for `run`.
- **Every fallback in the §3c rule lands back on `run` (full)** — `force_full_paths`
  hit, `run_minified == null`, an unresolvable affected set, or tier **L** all mean
  this component runs its ordinary `run` command, not `run_minified`. This protocol
  never decides the fallback itself; it only executes whichever command the rule
  handed it.
- **Record `selected/total` + `fallback_reason?`.** The result report (§4 of
  `../executor.md` / `check-report-schema.md`'s `result` section) carries the same
  `totals: {passed, failed, skipped, flaky}` shape as a full run, plus (only on a
  minified run) `selected`/`total` test counts and, when step 1–4 fell back to full,
  the `fallback_reason` naming which step fired, verbatim in the
  `../output-schema.md` vocabulary (`force-full: <path>` / `run_minified: null` /
  `fallback: <reason>` / `tier: L (<trigger>)`). A full or
  selection-off run carries neither field — this is strictly additive.
- **Verdict semantics never change.** Selection changes **how many** tests ran,
  never how a finding is graded: a failing selected test is a `blocker`
  (`rule: unit-test-failure`) exactly as under a full run — nothing here loosens or
  tightens the Verdict section above. `pass`/`pass_with_warnings`/`fail` resolve
  identically whether the run was full or minified.

## Short-circuit

A `blocker` here does **not** short-circuit later steps by itself (only Step 2
mechanical does) — it still fails the run; Steps 4–8 continue so the verdict
aggregates the full picture per `../severity-rubric.md`.
