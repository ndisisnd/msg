---
name: ratchet-vs-base
description: The shared no-regression ratchet pattern — a component may gate a metric getting worse vs the base branch even with no absolute budget configured. Factored once (D21/F5); referenced by coverage (C10), perf (C14), api contract-compat (C15).
type: reference
---

# The no-regression ratchet (vs base)

A shared grading pattern: a component may **gate direction, not level** — a metric
that **materially worsens vs the base branch** is a finding **even when no absolute
budget/threshold is configured**. Configured budgets stay the hard blocking bar; the
ratchet is **additive**, closing the "advisory unless a budget is set → runs but never
gates" hole. Each consumer names its own metric — this file names the mechanics they
share, not the numbers.

## Mechanics (every consumer honors these)

1. **Measure the base.** Fetch the base branch's number (an existing report, or
   recompute on base) — the ratchet needs a baseline to compare against.
2. **Compare like-for-like.** Same runner, same profile (device/network for perf, same
   exclusion set + metric for coverage, same spec pair for api), so the delta reflects
   the PR, not the harness. A cross-profile compare is not a ratchet.
3. **Apply a noise margin.** A change inside the measurement's jitter band is **not** a
   regression — the margin prevents false positives from run-to-run variance. Only a
   move beyond the margin is a finding.
4. **A regression is a finding even with no budget.** A move past the margin in the
   worse direction is a finding (severity per the consumer: `high` when a budget is
   also set, else `medium`/`low`), naming the **delta vs base**. A bad *absolute* level
   with **no** worsening vs base is **not** a ratchet finding — direction, not level.
5. **No base → skip, never fabricate.** If the base number is unavailable (first run,
   no base report, base recompute impossible), **skip the ratchet with a noted reason**
   (e.g. `no_base_<metric>`) — never invent a regression.

## Consumers

- **coverage (C10)** — total coverage may not decrease vs base (`coverage-regression`).
- **perf (C14)** — runtime metrics + bundle size may not worsen vs base.
- **api (C15)** — the ratchet is **contract compatibility**: the PR spec may not become
  backward-incompatible vs the base spec.
