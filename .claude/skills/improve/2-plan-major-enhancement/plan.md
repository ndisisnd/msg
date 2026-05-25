# Improvement Plan — 2-plan-major-enhancement

**Skill:** plan-em
**Change type:** Refactor

## Problem

Step 2 of plan-em performs "first-layer fixes" — directly editing the PRD for terminology deviations, missing content, and gaps requiring user input. This is scope creep: plan-pm creates the PRD, plan-tune owns PRD editing and auditing, and plan-em should consume a ready PRD, not repair one. Having plan-em also mutate the input document creates overlapping ownership, risks silently overwriting tune decisions, and blurs the EM role (engineering manager reads a spec; they do not revise it). The correct fix is to remove Step 2 entirely and replace it with a gate that invites the user to run plan-tune if the PRD is not yet tuned.

## Proposed changes

| # | What | How | Why necessary | Why ignorable | Rank |
|---|------|-----|---------------|---------------|------|
| 1 | Remove Step 2 (first-layer fixes) from SKILL.md | Delete the entire Step 2 block, renumber Steps 3–6 → Steps 2–5, and update the `Step X/6` progress emission header to `Step X/5` throughout | Step 2 violates ownership boundaries and duplicates plan-tune's job | Not ignorable — leaving it creates conflicting PRD edits and a confused role boundary | P1 |
| 2 | Add a plan-tune gate after Step 1 (pre-flight) | In the new Step 2, after emitting the pre-flight summary, ask via `AskUserQuestion`: "Would you like to run plan-tune before continuing?" with options: **Run plan-tune first** (emit the handoff message and stop) / **Continue without tune** (proceed to agent identification). Insert this as the new Step 2 and shift subsequent steps accordingly | Gives users a natural checkpoint to tune the PRD before expensive agents activate, without plan-em doing the tuning itself | Not ignorable — without this gate there is no prompt to tune and users must know to run it manually | P1 |
| 3 | Update progress emission count from 6 to 5 steps | Every `Step X/6` string becomes `Step X/5` throughout SKILL.md | Step count is wrong after removing Step 2 | Not ignorable — a wrong step count confuses users tracking progress | P1 |
