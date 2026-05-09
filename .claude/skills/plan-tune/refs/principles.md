# Principles

Five categories of rules for producing a PRD. Apply all of them, every time.

---

## 1. Specificity

Reduces ambiguity. PRD is self-contained; no follow-up needed to start building.

- **Search existing patterns before inventing** — check the codebase first, then the web. Ground requirements in real, observed patterns, not invented ones.
- **Exact values over approximations** — write `300ms`, `50 items`, `7 days`. Never `fast`, `a few`, `about a week`.
- **Name the flow, don't describe it** — reference flows by name (e.g. `OnboardingStep3.tsx`, `checkout.confirm`). Do not paraphrase them in prose.
- **Constraints as hard limits, not preferences** — write `must complete in <2s`, not `should be fast`.
- **No weasel words** — strip `may`, `could`, `typically`, `generally`, `often`, `usually`, `where appropriate`.

---

## 2. Scope discipline

Prevents scope inflation beyond the human's intent.

- **Only what was asked** — every requirement traces to an explicit human input. No inference, no extrapolation.
- **Flag additions, don't include them** — if something seems missing, surface it as a question. Do not silently add it to the PRD.
- **One problem, one PRD** — a single PRD addresses one user problem. Do not bundle.
- **Propose splits when scope outgrows one PRD** — if the feature spans multiple problems, surfaces, or ship cycles, recommend splitting into separate PRDs before writing.
- **Scope is fixed unless instructed otherwise** — once the human approves scope, do not expand it during drafting.

---

## 3. Clarity

Output is directly executable by a builder or downstream agent.

- **Write for the builder, not the stakeholder** — assume the reader will implement, not approve. No marketing language, no rationale framing.
- **One requirement, one buildable unit** — each requirement maps to a single PR-sized change. Split compound requirements.
- **Active voice with subject and action** — `the system displays X`, not `X is displayed`. Always name the actor.
- **State exclusions explicitly** — list what is out of scope under a named heading. Do not rely on omission.
- **Domain-standard jargon only** — use terms the engineering team already uses. No invented vocabulary.

---

## 4. Completeness

PRD does not stall the pipeline mid-run.

- **No TBDs in output** — every section is filled. If a value is unknown, ask the human before writing the PRD, not after.
- **Every requirement has an acceptance criterion** — pair each requirement with a verifiable check.
- **Edge cases named, not implied** — list empty states, error states, race conditions, and boundary values explicitly.
- **Dependencies listed explicitly** — name external services, internal modules, feature flags, and data sources by identifier.
- **Error states specified** — for each failure mode, define the user-facing behavior and the system-side log/metric.

---

## 5. Consistency

Downstream agents do not receive conflicting instructions.

- **One term per concept** — pick a single name for each entity, action, or state. Use it everywhere.
- **Numbers and names match across sections** — a value introduced in `Requirements` must match the same value in `Acceptance Criteria` and `Metrics`.
- **Cross-reference shared constraints** — when two sections depend on the same rule, link them; don't restate.
- **Resolve contradictions before output** — scan the draft for conflicts. Reconcile or escalate to the human. Never ship a contradictory PRD.
