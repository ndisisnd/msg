---
name: Clarify Questions
description: MCQ bank for prose-input clarification. Used in Step 2 of todo to nail down scope before deriving tasks.
type: reference
---

# Clarify Questions

Ask 2–4 questions, one at a time, drawn from the categories below. Pick the category that matches the gap in the prose. Stop when affected system, desired outcome, and at least one constraint are known.

## Question categories

### A — Affected system or component

Ask when the prose names a problem but not the code area.

| # | Question | Options |
|---|----------|---------|
| A1 | Which part of the system does this touch? | a specific module / cross-cutting infrastructure / a new component / Other |
| A2 | Is this backend, frontend, or both? | backend only / frontend only / both / Other |
| A3 | Does this change a public API surface? | yes — breaking / yes — additive / no — internal only / Other |

### B — Desired outcome

Ask when the prose names a goal but not what "done" looks like.

| # | Question | Options |
|---|----------|---------|
| B1 | What does success look like? | a working feature / a measurable improvement / removal of a blocker / Other |
| B2 | Should this be user-visible? | yes — UI change / yes — behavior change / no — internal only / Other |
| B3 | Is there a target metric? | yes — performance / yes — error rate / no metric / Other |

### C — Constraints

Ask when the prose lacks limits on scope, timeline, or approach.

| # | Question | Options |
|---|----------|---------|
| C1 | How urgent is this? | this week / this sprint / backlog / Other |
| C2 | Is there an approach you want followed? | match existing pattern / use a specific library / open to suggestions / Other |
| C3 | What is out of scope? | refactoring adjacent code / tests / docs / nothing — full scope / Other |

## Worked example

Input prose:

> "We need to add rate limiting to the API. Right now there's no limit on how many requests a single user can make, which is causing occasional load spikes."

Gaps: affected endpoints unclear (A1), success metric unclear (B3), approach unclear (C2).

Questions asked:

1. **A1** — Which endpoints need rate limiting? (all / specific list / Other)
2. **B3** — What is the target rate? (e.g. 100 req/min per user / no specific number / Other)
3. **C2** — Where should the limit values live? (environment variables / config file / Other)

After three answers, scope is resolved. Proceed to derive tasks.

## Stop rules

- Stop after 4 questions even if gaps remain — refuse via Step 3 instead.
- Stop early when all three pillars (system, outcome, constraint) are covered.
- Never ask the same category twice in one run.
