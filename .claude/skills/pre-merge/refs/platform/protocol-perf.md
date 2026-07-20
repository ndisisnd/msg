---
name: perf
description: Pre-merge performance-budget component — Core Web Vitals / Lighthouse and bundle-size against configured budgets. Runs isolated. Parse to canonical findings.
---

# perf component

Guard, error rule, envelope: `../_common.md`. **Runs isolated** (no overlap with other
components or `load`). `perf_runner` is a `{runtime, bundle}` pair (runtime: Lighthouse CI
`lhci` / Playwright+web-vitals; bundle: size-limit / bundlesize) from the fingerprint.
Run all detected; either sub-check alone is enough to run the component.

## Budgets

Runtime: read `lhci` config (`.lighthouserc.*` `assert.assertions` / `budgets`); else
defaults — perf score ≥ 80, LCP ≤ 2500 ms, CLS ≤ 0.1, FID/INP ≤ 200 ms, FCP ≤ 1800 ms,
TTI ≤ 3800 ms. Bundle: always from the runner's own config (`size-limit` in `package.json`
or `bundlesize.files`); no config → `pass_with_warnings`, note `"no size budgets configured"`
(never invent thresholds).

## Parse

- All assertions/entries within budget → `pass`.
- Any breach → one finding per breached metric/entry, `severity: high` (`medium` if marginal or thresholds fell back to defaults).
- Runner crash / missing build artifact → `pass_with_warnings`.

Finding fields: `rule` = metric name (`LCP`/`CLS`/…) or `bundle-size`; `message` =
observed-vs-budget (`"LCP=3200ms exceeds budget 2500ms"`); `evidence.file` = Lighthouse
HTML report (runtime) or `null` (bundle); `suggestion` keyed to the metric.
**Partial-results rule:** if one sub-check passes and the other errors, verdict =
`pass_with_warnings`, the error recorded in `errors[]`.

Component fields: `runners[]`, `errors[]`, `thresholds`, `totals`.
