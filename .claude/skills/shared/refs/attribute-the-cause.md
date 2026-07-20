---
name: attribute-the-cause
description: The shared finding pattern — name the specific cause, not the symptom, and suggest a fix. Factored once (D22/F5); referenced by perf bundle attribution (C14), api consumer naming (C15), load bottleneck naming (C16).
type: reference
---

# Attribute the cause, not the symptom

A shared finding-framing pattern: a threshold breach or regression must point at the
**specific thing that caused it** and suggest a remedy — never restate the metric. A
finding the eng agent can act on names the culprit; `"bundle too big"` / `"p95 too
slow"` / `"schema violation at line 40"` are symptoms, not causes.

## The rule

- **Correlate the breach with its cause.** Use the evidence already gathered (the diff,
  the bundle stats, the trace/query log, the spec diff) to identify the single
  operation, import, query, or change responsible — don't stop at the aggregate number.
- **Name it in the finding.** The `message`/`suggestion` names the culprit + a concrete
  next step; the raw metric goes in `evidence`, not the headline.
- **Degrade honestly.** When the causal signal is unavailable (no bundle stats, no
  trace, no consumer registry), fall back to the breach + location — never **fabricate**
  a cause to look actionable.

## Consumers (each names its own culprit)

- **perf (C14)** — a bundle-size increase names the **specific import/dependency** that
  grew it + a lighter alternative, not `"bundle too big"`.
- **api (C15)** — a contract break names the **affected consumer** and what breaks for
  them, not `"oas3-schema violation at line 40"`.
- **load (C16)** — a threshold breach names the **bottleneck** (slowest endpoint, the
  query/span, the error cluster) + a suggestion, not `"p95 1200ms > 500ms"`.

Sibling of `name-the-user-impact.md`: this one points at the **cause** (what to fix);
that one leads with the **user impact** (why it matters). A finding can do both.
