---
name: OPEN-QUESTIONS Template
description: Template for open questions log — written by build subagents when they encounter ambiguity
type: reference
---

# Open Questions

Unresolved questions logged by build subagents during implementation.
Resolve each entry before shipping or carry it forward with a decision.

Each entry uses this template:

```
### [YYYY-MM-DD] Short question title
**Question**: Full question text.
**Severity**: critical | high | medium | low
**Status**: open | in-progress | resolved
**Context**: Where this came up and why it matters.
**Options**: A / B / C (optional).
**Decision**: Outcome, if resolved (optional).
**Raised by**: <subagent or author>
```

Severity guide:
- `critical` — blocks implementation; must resolve before proceeding
- `high` — significant impact on design or behaviour; resolve before shipping
- `medium` — notable but workable; resolve before next milestone
- `low` — minor or cosmetic; resolve when convenient

---

## Open Questions

<!-- Build subagents append entries here. -->

## Resolved

<!-- Move entries here and set Status: resolved once a decision is made. -->
