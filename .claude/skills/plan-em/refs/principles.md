# Principles

Five categories of rules for producing an RFC engineering plan. Apply all of them, every time.

---

## 1. Complexity discipline

Engineer sufficiently — neither under nor over. Cost of complexity compounds; cost of duplication is local.

- **Right-size, don't gold-plate** — match the solution to the problem. Two services where one would do is over-engineering; one service where two are needed is under-engineering.
- **Distinguish essential from accidental complexity** — before adding anything, ask whether it solves a real problem or one we created (Brooks).
- **DRY when the duplication is real** — extract on the third occurrence, not the second. Premature abstraction costs more than duplication.
- **Make the change easy, then make the easy change** — refactor first, implement second. Never combine structural and behavioral changes in the same diff (Beck).
- **No speculative generality** — do not design for hypothetical future requirements. Add abstraction when the second concrete need appears.
- **Check prior PRDs and RFCs before mapping** — scan `features/prd-*/` for overlap with the input PRD's features. Reuse or refactor existing modules before authorising a parallel implementation; record every overlap by ID in §8 of the RFC.

---

## 2. Risk and blast radius

Reversible decisions are cheap; irreversible ones are not. Plan for the worst case, not the average.

- **Boring by default** — every project gets about three innovation tokens. Spend them deliberately; everything else uses proven technology (McKinley).
- **Estimate blast radius up front** — for every decision, name the worst case and how many systems and people it affects.
- **Prefer reversible over revolutionary** — feature flags, canaries, A/B tests, incremental rollouts. Make the cost of being wrong low.
- **Strangler fig over rewrite** — incremental migrations beat big-bang replacements. Run old and new in parallel until traffic shifts.
- **One innovation token per RFC, max** — if the plan introduces more than one unfamiliar technology, split it or pick one.

---

## 3. Explicit and defensive

Plans are read by tired humans and downstream agents. Leave nothing implicit.

- **Bias toward explicit** — name the contract, the actor, the failure mode. Implicit conventions break under pressure.
- **Enumerate edge cases, don't gesture at them** — empty states, error states, boundary values, race conditions. List each with the expected behavior.
- **Design for tired humans at 3am** — not your best engineer on their best day. The plan must be operable under fatigue.
- **Test coverage is a first-class deliverable** — every requirement names the test type (unit, integration, e2e) and the assertion. Plan tests with the feature, not after.
- **State exclusions** — list what is out of scope by name. Do not rely on omission.

---

## 4. Failure and operations

Production is the source of truth. Reliability is a resource to spend, not a target to chase.

- **Own code in production** — no dev/ops wall. The team that writes it operates it (Majors).
- **Failure is information** — design for blameless postmortems, error budgets, and chaos drills. Incidents are learning events, not blame events.
- **Error budgets over uptime targets** — an SLO of 99.9% means 0.1% to spend on shipping. Treat reliability as resource allocation (Google SRE).
- **Specify observability with the feature** — every requirement names the log line, metric, or trace that confirms it works in production.
- **Define the rollback before the rollout** — every change has a documented backout path with measurable success criteria.

---

## 5. Team and organization

Architecture and team design are the same problem. Plan both, deliberately.

- **Diagnose team state first** — falling behind, treading water, repaying debt, or innovating. Match the intervention to the state (Larson).
- **Conway's Law is a constraint, not a slogan** — service boundaries follow team boundaries. Design both intentionally (Skelton/Pais).
- **Developer experience is product quality** — slow CI, painful local dev, and brittle deploys are leading indicators of declining software quality.
- **Apply the two-week smell test** — if a competent engineer cannot ship a small feature in two weeks, the bottleneck is onboarding or architecture, not effort.
- **Surface glue work** — invisible coordination work is real work. Name it in the plan, assign it explicitly, and rotate it (Reilly).
