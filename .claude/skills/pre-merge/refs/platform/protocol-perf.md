---
name: perf
description: Pre-merge performance component — cold-load Core Web Vitals / Lighthouse AND interaction latency under e2e-flow-driven heavy state, plus bundle size, against configured budgets and a no-regression ratchet vs base. Bundle findings attribute the culprit import. Parse to canonical findings.
---

# perf component

Guard, error rule, envelope: `../_common.md`. **Runs isolated** (no overlap with other
components or `load`). `perf_runner` is a `{runtime, bundle}` pair (runtime: Lighthouse CI
`lhci` / Playwright+web-vitals; bundle: size-limit / bundlesize) from the fingerprint.
Run all detected; either sub-check alone is enough to run the component. `perf` measures
**how it feels to use**, not just how fast it opens.

## Interaction perf under load (C14/rec 1 — not just cold-load)

Cold-load metrics (LCP/FCP/TTI) miss "fast to open, janky to use" (the todo list that
freezes after 300 items). So `perf` also drives the app to a **realistic heavy state via
the e2e flows** and measures **interaction latency**: **INP under load**, **long-task
duration**, **scroll jank** — not only Lighthouse's cold-load numbers.

The flow set is **owned by `e2e`** (D29 — `e2e` defines the canonical flows + critical
tags; `a11y`/`perf`/`preview`/`smoke` **consume** them, none reinvents its own list). On a
backend-only repo with **no e2e flows**, perf **degrades to the cold-load path** (Lighthouse
only) — no fabricated flows. Interaction findings lead with the janky interaction per
`../../../shared/refs/name-the-user-impact.md` (*"list freezes after 300 items —
INP 420ms"*), the metric id secondary.

## Budgets (the hard blocking bar — config-driven criticality unchanged)

Runtime: read `lhci` config (`.lighthouserc.*` `assert.assertions` / `budgets`); else
defaults — perf score ≥ 80, LCP ≤ 2500 ms, CLS ≤ 0.1, FID/INP ≤ 200 ms, FCP ≤ 1800 ms,
TTI ≤ 3800 ms; interaction defaults — INP-under-load ≤ 200 ms, long-task ≤ 50 ms. Bundle:
always from the runner's own config (`size-limit` in `package.json` or `bundlesize.files`).
A **configured budget breach remains the hard blocking bar** (the catalog `†` config-driven
criticality is unchanged — AC-PERF3); the ratchet below is **additive**, not a replacement.

## No-regression ratchet vs base (C14/rec 2 — even with no budget)

`perf` gets a **no-regression ratchet** — key runtime metrics **and** bundle size may not
**materially worsen vs base even with no absolute budget configured** (AC-PERF2), closing
the "advisory unless budgets set → runs but never gates" hole. This is the shared
**ratchet-vs-base** pattern (`../../../shared/refs/ratchet-vs-base.md`, with coverage C10 +
api C15): measure the base, compare **like-for-like** (same device/network profile, same
flows), apply a **noise margin** so measurement jitter is **not** a false regression
(AC-PERF5). A move past the margin in the worse direction is a finding (`high` when a budget
is also set, else `medium`), naming the vs-base delta. No base numbers available → skip the
ratchet with a note (`reason: "no_base_perf"`), never fabricate a regression. A bad absolute
level with **no** worsening vs base is not a ratchet finding — direction, not level.

## Bundle attribution (C14/rec 3)

A bundle-size finding **attributes the increase to the specific import/dependency** that
caused it and **suggests a lighter alternative** — not just `"bundle too big"` — per
`../../../shared/refs/attribute-the-cause.md` (AC-PERF4). Use the bundle stats/treemap to
name the culprit (`route`, `culprit`, `baseline_kb`, `current_kb` in `evidence`); no stats
available → degrade to the size + route, never fabricate a culprit.

## Parse

- All assertions/entries within budget **and** no ratchet regression → `pass`.
- Any budget breach → one finding per breached metric/entry, `severity: high` (`medium` if
  marginal or thresholds fell back to defaults).
- A ratchet regression (no budget) → `medium` finding naming the vs-base delta.
- Runner crash / missing build artifact → `pass_with_warnings`.

Finding fields: `rule` = metric name (`LCP`/`CLS`/`INP-under-load`/`long-task`/…),
`bundle-size`, or `perf-regression` (ratchet); `message` = observed-vs-budget or
vs-base delta (`"LCP=3200ms exceeds budget 2500ms"`); `evidence.file` = Lighthouse HTML
report (runtime) or `null` (bundle); `evidence.culprit` = the attributed import (bundle);
`suggestion` keyed to the metric / lighter alternative. **Partial-results rule:** if one
sub-check passes and the other errors, verdict = `pass_with_warnings`, the error recorded
in `errors[]`.

Component fields: `runners[]`, `errors[]`, `thresholds`, `base_metrics` (+ `delta`, or
`no_base_perf`), `interaction` (flow-driven results), `totals`.
