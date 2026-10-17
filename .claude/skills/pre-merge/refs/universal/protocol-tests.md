---
name: tests
description: The unit and integration components — run each test suite via the configured runner. Script only, no LLM. Non-zero exit is a blocker; a missing runner or an unreachable test environment is never a blocker.
---

# `unit` · `integration` — the tests stage

Deterministic, **no LLM**. Both components run on the post-sync branch (they always
re-run after SYNC's merge). Findings conform to `../finding-schema.md`;
`source: unit` or `source: integration`.

## Shared rules (both levels)

### Runner

Use the `run` command resolved for the component in `devkit/policy.json`
`components[]` (detected at setup / `--update` by `script-preflight-02-unit.sh` and
`script-preflight-03-integration.sh`). Do not re-detect.

```
<test_runner.command>
```

**No configured runner ⇒ not run.** `test_runner` is `null` (or the component has no
`run` command) ⇒ write a `skipped` result report, `skip_reason: "no_test_command"`,
and the report line reads *"not run: no test command"*. Never guess a command
(`npm test`, `pytest`, …) and never run a guessed suite: a guessed suite can run the
same tests twice and report one failure twice. A missing runner is never a blocker.

### Verdict

- Non-zero exit → `blocker` finding (`rule: unit-test-failure` or
  `integration-test-failure`), first failing test name + assertion quoted.
- Exit 0 → `pass`; totals `{ passed, failed, skipped }` from the runner's own summary
  line/report when parseable, else a pass/fail count only.
- **Environment-only failure** (unreachable test DB or service dependency, container
  not running) → `pass_with_warnings`, with a note naming the unreachable dependency.
  Never a false block from a broken local environment. When the diff touches the
  component's surface, the error also carries the `component-errored` finding
  (`../_common.md`). The same failure grades the same at both levels.

### `--flaky <N>` (per `../_common.md`)

Re-run each failing test up to `N` times via its `repro`, stopping on first pass.
Passes-on-retry → reclassify `medium`, `evidence.flaky: true`,
`evidence.retries: <n>`, counts toward `totals.flaky` not `totals.failed`. Still
failing after `N` retries → genuine `blocker`.

### Minified invocation

Both components are selection-capable. When the executor resolved a **minified** run,
execute `components[].run_minified` instead of `run` and record `selected`/`total`
(plus `fallback_reason` when the rule fell back to full). The rule, the size tiers,
every fallback, and the recording contract live in **one place** —
`../executor.md` §3c. A component executes whichever command it is handed; it never
decides selection itself. Selection changes **how many** tests ran, never how a
finding is graded.

### Short-circuit

A `blocker` here does **not** abort the pipeline. Only the **critical class**
(`mechanical`, `security`, `migration`) short-circuits a run — the one rule lives in
`../severity-rubric.md` § *Fail-fast by component `criticality`*. A test failure is
`blocking`: it fails the verdict and blocks its dependents (`coverage`), while
independent components finish so the verdict aggregates the full picture.

## `unit`

Restrict the invocation to the unit-suite subset when the runner's config
distinguishes one (a `unit/` test directory, a `--testPathPattern` / `-m unit`
marker, a pytest `unit` marker); else run the component's default suite.

## `integration`

Restrict the invocation to the integration-suite subset when the runner's config
distinguishes one (an `integration/` or `test/integration` directory, a
`--testPathPattern` / `-m integration` marker, a pytest `integration` marker,
Flutter's `integration_test/`); else run the component's default suite. When `unit`
and `integration` resolve to the same command with no subset, `integration` writes
`skipped`, `skip_reason: "same_suite_as_unit"`, so one suite never runs twice.

Tier rule: `integration` runs `run_minified` at tier **S** only. At tier **M** it runs
full (`fallback_reason: "tier: M (widen-to-full)"`), because past the smallest tier
the residual risk is cross-module interaction, while `unit`'s file-precise selection
still covers "this unit is wrong".
