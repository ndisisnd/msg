---
name: perf
description: Pre-merge performance component — cold-load Core Web Vitals / Lighthouse plus bundle size, graded against configured budgets. A no-regression ratchet vs base runs only when comparable base numbers exist. Parse to canonical findings.
---

# perf component

Guard, error rule, envelope: `../_common.md`. **Runs isolated** (no overlap with other
components or `load`). `perf_runner` is a `{runtime, bundle}` pair (runtime: Lighthouse CI
`lhci` / Playwright+web-vitals; bundle: size-limit / bundlesize) from the component's
resolved tooling. Run all detected; either sub-check alone is enough to run the component.

## What it measures

**Cold-load runtime metrics + bundle size.** That is the documented behaviour: the
runner's own scenario (Lighthouse's cold load, or whatever the project's `lhci`/
web-vitals config declares) plus the bundle stats. `perf` does not drive the app to a
heavy state on its own and does not maintain a flow list — where a project wants
interaction-under-load numbers (INP under load, long tasks, scroll jank), it declares
that scenario in its **own runner config** and `perf` reads the results back like any
other assertion.

## Budgets (the hard blocking bar — config-driven criticality)

Runtime: read `lhci` config (`.lighthouserc.*` `assert.assertions` / `budgets`); else
defaults — perf score ≥ 80, LCP ≤ 2500 ms, CLS ≤ 0.1, FID/INP ≤ 200 ms, FCP ≤ 1800 ms,
TTI ≤ 3800 ms. Bundle: always from the runner's own config (`size-limit` in
`package.json` or `bundlesize.files`). A **configured budget breach is the hard
blocking bar** (the catalog `†` config-driven criticality); the ratchet below is an
extra, not a replacement.

## No-regression ratchet vs base — only when base numbers exist

Key runtime metrics and bundle size may not **materially worsen vs base**, so a repo
with no absolute budget still gets a direction signal. This is the shared
**ratchet-vs-base** pattern (`../../../shared/refs/ratchet-vs-base.md`). It needs
like-for-like base numbers — same device/network profile, same scenario — measured or
retrievable for the base branch.

- **Base numbers available** → compare, apply a noise margin so jitter is not a false
  regression, and grade a move past the margin in the worse direction (`high` when a
  budget is also set, else `medium`), naming the vs-base delta.
- **No comparable base numbers** (the common case) → **skip the ratchet with a note**
  (`reason: "no_base_perf"`). Never fabricate a regression, and never infer one from
  absolute level: a bad number that did not move is not a ratchet finding.

## Parse

- All assertions/entries within budget **and** no ratchet regression → `pass`.
- Any budget breach → one finding per breached metric/entry, `severity: high` (`medium` if
  marginal or thresholds fell back to defaults).
- A ratchet regression (no budget) → `medium` finding naming the vs-base delta.
- Runner crash / missing build artifact → `pass_with_warnings` (plus the
  `component-errored` finding when the diff touches this surface — `../_common.md`).

**Bundle findings name the culprit when the stats say so.** With a bundle
stats/treemap available, attribute the increase to the import/dependency that caused
it and suggest a lighter alternative (`route`, `culprit`, `baseline_kb`, `current_kb`
in `evidence`), per `../../../shared/refs/attribute-the-cause.md`. **No stats → report
the size + route and stop** — never a guessed culprit.

Finding fields: `rule` = metric name (`LCP`/`CLS`/…), `bundle-size`, or
`perf-regression` (ratchet); `message` = observed-vs-budget or vs-base delta
(`"LCP=3200ms exceeds budget 2500ms"`); `evidence.file` = Lighthouse HTML report
(runtime) or `null` (bundle); `evidence.culprit` = the attributed import when stats
resolved it; `suggestion` keyed to the metric. **Partial-results rule:** if one
sub-check passes and the other errors, verdict = `pass_with_warnings`, the error
recorded in `errors[]`.

Component fields: `runners[]`, `errors[]`, `thresholds`, `base_metrics` (+ `delta`, or
`no_base_perf`), `totals`.
