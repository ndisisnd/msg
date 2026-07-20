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

## `--flaky <N>` (per `../_common.md`)

Re-run each failing test up to `N` times via its `repro`, stopping on first pass.
Passes-on-retry → reclassify `medium`, `evidence.flaky: true`,
`evidence.retries: <n>`, counts toward `totals.flaky` not `totals.failed`. Still
failing after `N` retries → genuine `blocker`.

## Short-circuit

A `blocker` here does **not** short-circuit later steps by itself — Steps 4–8
continue so the verdict aggregates the full picture per `../severity-rubric.md`.
