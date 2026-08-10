---
name: name-the-user-impact
description: The shared finding pattern — lead with the user impact + the flow/state affected, with the technical id secondary. Factored once (D20/D21/F5); referenced by a11y (C13), perf (C14), api (C15), mobile (C18).
type: reference
---

# Name the user impact (flow first, id second)

A shared finding-framing pattern: a finding leads with **what a user loses and in which
flow/state**, with the technical identifier (test name, schema path, metric, WCAG rule)
**secondary**. `"swipe-to-delete broken on iOS 17"` beats `"testSwipeDelete failed"`;
the human reviewing the gate should read impact before implementation.

## The rule

- **Headline the impact + flow.** The `message` states the user-facing consequence and
  the flow/state/platform where it bites (reuse the e2e-flow / state context the
  component already reached — D29). The test/rule/schema id lives in `rule` and
  `evidence`, not the headline.
- **Keep the id, don't lead with it.** The mechanical identifier stays on the finding
  (it's the dedup/regression key — `finding-schema.md`), just not first.
- **Degrade honestly.** When no flow/state context is available, state the impact you
  can support (component + platform) — never **invent** a user story the evidence
  doesn't back.

## Consumers

- **a11y (C13)** — the barrier a user hits in a real interactive state, not just a rule
  id (`color-contrast at node …`).
- **perf (C14)** — the interaction that janks under load ("list freezes after 300
  items"), not just `INP=420ms`.
- **api (C15)** — pairs with `attribute-the-cause.md`: the consumer that breaks + what
  they lose.
- **mobile (C18)** — the broken user flow + platform/OS, test name secondary.
