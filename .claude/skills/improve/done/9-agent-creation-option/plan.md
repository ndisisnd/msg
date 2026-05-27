# Improvement Plan — 9-agent-creation-option

**Skill:** improve
**Change type:** New capability

## Problem

The `/improve` skill only handles improvements to existing skills, workflows, or code. When a user invokes `/improve` without arguments and wants to create a new agent, there is no matching option — they are funnelled into questions designed for iterative improvement and the conversation breaks down. The skill should offer "Create a new agent" as a first-class intent option in Step 1, and then branch: either hand off to `/agent-plan` (full design flow) or stay in `/improve` for a lightweight inline agent-creation path that produces the same `plan.md + acceptance.md` output as any other improve plan.

## Proposed changes

| # | What | How | Why necessary | Why ignorable | Rank |
|---|------|-----|---------------|---------------|------|
| 1 | Add "Create a new agent" option to the Step 1 question | Append a third option `{ label: "Create a new agent", description: "Design a brand-new skill/agent" }` to the `options` array in the Step 1 `AskUserQuestion` call | Without this, users picking agent creation get routed into ill-fitting improvement questions, causing confusion (as happened in the preceding session) | If the team decides /improve and /agent-plan should remain fully separate with no cross-routing | P1 |
| 2 | Add agent-routing sub-step (Step 1b) triggered when "Create a new agent" is chosen | After Step 1 returns "Create a new agent", call `AskUserQuestion` with `header: "Agent path"`, two options: "Use /agent-plan (full flow)" — invoke the agent-plan skill and exit; "Stay in /improve (lightweight)" — continue with inline agent questions | Lets the user choose depth: full design pipeline vs a quick plan | Only if one path is deleted entirely | P1 |
| 3 | Define the lightweight inline agent-creation path | When user picks lightweight: ask up to 5 clarifying questions covering (a) agent name and one-sentence purpose, (b) trigger conditions / invocation pattern, (c) tools the agent needs, (d) constraints or out-of-scope items, (e) desired output format. Then continue through Steps 2–5 as normal with slug `create-<agent-name>` | Provides a useful, consistent output (plan.md + acceptance.md) without requiring the full agent-plan pipeline | If /agent-plan is always the preferred path | P2 |
| 4 | Update the SKILL.md usage line to mention the new option | Change "Refuses without a description" note to also document that no-arg invocation now offers three intents: improve existing / create agent (via /agent-plan) / create agent (lightweight) | Keeps the skill self-documenting; downstream skills that read SKILL.md for routing hints will pick this up | Cosmetic — no runtime impact | P3 |
