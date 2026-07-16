---
name: msg-protocol-cto
description: >
  The cto-mode Step 2 interview for /msg --init — advisory posture. Takes the user's
  project description and RECOMMENDS the technical decisions (architecture, coding
  language, conventions, release flow, design system) via a guided AskUserQuestion
  loop, then derives every remaining init.sh variable from its own recommendations
  rather than asking for them. Selected by `--init --cto`, or by the Step 2 mode
  gate. The direct-execution alternative is refs/protocol-eng.md.
type: reference
---

# Protocol: --init, cto mode (Step 2 interview)

**Posture: advisory.** The user describes what they want to build; **you make the
technical recommendations and explain them.** Assume the user is non-technical, or
technical outside this stack — they want a sound baseline architecture and do not
know which questions to ask. Asking them "PostgreSQL or DynamoDB?" is the failure
mode this mode exists to prevent. Recommend, justify, let them override.

This protocol owns **Step 2 only**. Steps 1, 3, 4 and 5 stay in
[`protocol-init.md`](protocol-init.md); it invokes this file and resumes at Step 3
with the variables below resolved. Every variable named here is one `init.sh`
consumes — **the mode is invisible downstream of Step 3.**

## The five objectives

The loop terminates when all five are resolved. Each names the variables it owns —
that is the traceability contract: an objective is resolved when every variable in
its row has a value you can defend.

| # | Objective | Resolves |
|---|---|---|
| 1 | **Architecture** — components, external services, data stores, auth, deployment, platform | `ARCH_OVERVIEW`, `ARCH_EXTERNAL`, `ARCH_DATA_STORES`, `ARCH_AUTH`, `ARCH_DEPLOYMENT`, `PLATFORM`, `PLATFORMS` |
| 2 | **Coding language** — language/framework the project is written in | `LANGUAGE` |
| 3 | **Conventions** — house rules future agents code against | `CONVENTIONS` |
| 4 | **Release flow** — staged vs direct, and the branches | `RELEASE_FLOW`, `PROD_BRANCH`, `STAGING_BRANCH` |
| 5 | **Design system** — component library, tokens, component conventions | `DS_LIBRARY`, `DS_TOKENS`, `DS_CONVENTIONS` |

`PROJECT_NAME` and `PROJECT_DESCRIPTION` come from the brief (Call 1) — they are
input, not an objective; nothing about them is a technical recommendation.

**`ARCH_AUTH` is cto's** (ruling, M3). The architecture objective covers
authentication, so cto is a filler for the key and the key survives the removal
rule. eng mode does not ask it and falls back to `init.sh`'s `[USER: authentication
model]` stub — that fallback is what keeps the key safe to delete the *question*
from. Recommend `None` outright when the project has no user accounts; "no auth" is
a real recommendation, not a skipped objective.

## Decision rules

These are the stances the recommendations are made from. They are **rules a
recommendation can be checked against**, not preferences — if you cannot point at
the rule that produced a recommendation, you have not made one.

1. **Less code is more.** Recommend whatever leaves less code in the repo. Platform
   default > dependency > bespoke implementation, in that order. A component
   library beats a hand-rolled design system unless a stated constraint rules it
   out.
2. **Bias to agentic coding.** Future agents, not just humans, work in this repo.
   Prefer static types over dynamic, one obvious way over several, a single
   build/test command over a bespoke pipeline, conventional layout over clever
   indirection. An agent that can verify its own change is worth more than a
   terse stack.
3. **Comments exist for human understanding.** Recommend a convention where
   comments carry the *why* — a constraint, a rejected alternative, a footgun.
   Never ritual docblocks that restate the signature. This is a `CONVENTIONS` line,
   and it is not optional.
4. **Boring by default.** Recommend the most widely-deployed option that meets the
   stated need. Novelty needs a stated reason, and the reason has to be about this
   project rather than about the technology.
5. **Every recommendation is falsifiable.** State the option, the reason, and the
   condition under which you would choose differently ("Postgres — relational data,
   one writer; I'd say DynamoDB instead if you expect >10k writes/sec"). **An
   unopinionated "it depends" recommendation is a protocol failure.** So is a
   recommendation with no stated switch condition — that is a preference wearing a
   rule's clothes.

Rules 1–4 are defaults, not laws. A user constraint overrides any of them; an
overridden rule should be named as overridden, not silently dropped.

## The loop

**No fixed question table.** Unlike eng mode, the questions are LLM-driven — shaped
by what the user says against the five objectives. Ask what this project's gaps
demand, in the user's vocabulary, never in the stack's.

**Call 1 — the brief (always fires).**

| Q | Question | Format |
|---|----------|--------|
| 1 | What are you building, and who is it for? | Free text |
| 2 | What must it do on day one? | Free text |
| 3 | Any hard constraints? (a company that must be used, a platform it must run on, a deadline, a budget) | Free text or "None" |

If the user passed a project brief at invocation, seed these from it and ask only
what the brief left open. `PROJECT_NAME`/`PROJECT_DESCRIPTION` fall out of Q1 —
propose them and let the user correct.

**Calls 2–4 — recommend, don't ask.** After Call 1, resolve every objective you
can from the brief alone and put the rest in front of the user **as
recommendations**. Each question is one decision, the recommendation is the first
option and is labelled `(Recommended)`, and the description carries the reason and
the switch condition per rule 5. Batch 2–4 decisions per call.

Only surface a decision the user could plausibly have a view on — a business
constraint, a cost, a company they already use, a platform they must ship to.
Resolve everything else yourself and report it in the summary. A user who does not
know what a design token is should not be asked where they live; they should be
told what you chose and why.

**Termination.** The loop ends when all five objectives are resolved. Bound:
**≤4 `AskUserQuestion` calls total** (Call 1 plus at most three). On reaching the
ceiling with objectives outstanding, **resolve them by taking your own
recommendation** — never ask a fifth time, never leave a variable unset — and say
so explicitly in the summary.

## Deriving the rest

On completion, derive every remaining `init.sh` variable from the recommendations.
Nothing here is asked.

- **`PLATFORM`** — the primary stack the architecture implies. When `STACK_HINTS`
  resolved at Step 1, that is evidence about an existing repo; a recommendation
  that contradicts it needs a stated reason.
- **`PLATFORMS`** — space-separated keys (`web`, `ios`, `android`, `macos`) for the
  surfaces the architecture ships to. Empty → `init.sh` scaffolds all four default
  rows to prune.
- **`LANGUAGE`** — objective 2's answer. When `LANG_DEFAULT` (from
  `init-setup.sh`) names a language, that is the existing repo's fact — recommend
  against it only with a stated migration reason.
- **`CONVENTIONS`** — written from objective 3, and it must actually carry the
  house rules (rule 3's comment convention among them). Not "None recorded yet" —
  that is eng mode's default and a cto bootstrap that emits it has skipped an
  objective.
- **`ARCH_*`** — written from objective 1's recommendations, in prose the user can
  read back. `ARCH_AUTH` included (see above).
- **`DS_*`** — written from objective 5. When the architecture ships no UI surface,
  set all three to "Not applicable — no UI layer." — that is a *derivation*, not a
  skip, and it is also how a backend project that does ship an admin panel gets a
  design system anyway (the objective sees the surface even when `PLATFORM` doesn't).
- **`PROD_BRANCH`** — detected, never asked or hardcoded:

  ```bash
  git rev-parse --abbrev-ref HEAD 2>/dev/null                              # current branch
  git show-ref --verify --quiet refs/heads/staging && echo HAS_STAGING     # staging present?
  git show-ref --verify --quiet refs/heads/main    && echo HAS_MAIN
  git show-ref --verify --quiet refs/heads/master  && echo HAS_MASTER
  ```

  `main` if present, else `master` if present, else the current branch.
- **`RELEASE_FLOW`** — objective 4. Default recommendation is **Staged** when the
  project ships to users on a schedule, **Direct** for a solo project shipping
  continuously; a `staging` branch already present is strong evidence for Staged.
- **`STAGING_BRANCH`** — `"staging"` when Staged, **`null`** when Direct. Must emit
  `null` for direct; the policy seed distinguishes them.

## Summary before hand-back

Print a compact table of every recommendation — decision, what you chose, why —
before returning. The user is accepting an architecture they did not specify; they
get to see it in one place first. This is a summary, not a gate: do not
`AskUserQuestion` on it. The user can correct anything by saying so, and every
file `init.sh` writes is editable afterwards.

## Hand back

Return to [`protocol-init.md`](protocol-init.md) Step 3 with every variable above
resolved. Step 3's env block is the contract — cross-check that none is unset
before invoking `init.sh`.
