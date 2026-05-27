---
name: improve
description: >
  Lightweight improvement planner. Takes a target skill and a description of
  what to improve, asks follow-up questions, and writes a plan + acceptance
  criteria to improve/[n]-[feature-type]/. Invoke with /improve <description>.
model: claude-sonnet-4-6
allowed_tools:
  - AskUserQuestion
  - Bash
  - Read
  - Skill
  - Write
---

# improve

## Usage

**Invoke**: `/improve <description of what to improve>`. When invoked without a description, prompts the user to select one of three intents: improve an existing skill or workflow, create a new agent (full design flow via `/agent-plan` if available, or lightweight inline plan), or describe something that feels broken.

## Protocol

**Step 1 — Clarify intent**

If invoked without a description, call `AskUserQuestion` with a `questions` array containing one entry: `header: "Intent"`, `question: "What would you like to do?"`, `multiSelect: false`, and exactly three options:
- `{ label: "Improve existing", description: "Improve or extend an existing skill, workflow, or piece of code" }`
- `{ label: "Not sure yet", description: "Describe what feels broken or suboptimal and I'll help scope it" }`
- `{ label: "Create a new agent", description: "Design a brand-new skill/agent" }`

If "Create a new agent" is selected, proceed to **Step 1b** below. Otherwise treat the response as a description of the improvement and continue.

**Step 1b — Agent-creation routing** *(only when "Create a new agent" was chosen in Step 1)*

First, check whether `agent-plan` appears in the available-skills list in the current system-reminder (no tool call needed — it is already in context).

If it **exists**: call `AskUserQuestion`: `header: "Agent path"`, `question: "Which creation path would you like?"`, `multiSelect: false`, options:
- `{ label: "Use /agent-plan (full flow)", description: "Invoke the /agent-plan skill for the complete structured design pipeline" }`
- `{ label: "Stay in /improve (lightweight)", description: "Answer a few quick questions here and produce a plan.md + acceptance.md ready for /agent-build" }`

If the user picks **Use /agent-plan**: invoke the `agent-plan` skill via `Skill` and terminate this `/improve` flow immediately — do not proceed to Step 2.

If it **does not exist**, or if the user picks **Stay in /improve (lightweight)**: ask up to 5 clarifying questions, one `AskUserQuestion` call at a time, covering at minimum:
1. Agent name and one-sentence purpose
2. Trigger conditions and invocation pattern (when does a user call this agent, and how?)
3. Tools the agent needs (e.g. Bash, Read, Write, AskUserQuestion, external MCPs)
4. Constraints or out-of-scope items
5. Desired output format or artifact

Use the answers as the description for all subsequent steps. Set the slug to `create-<agent-name>` (lowercased, hyphenated).

**Step 2 — Improvement clarifying questions** *(only for the improvement path, not the lightweight agent-creation path)*

Call `AskUserQuestion` for each follow-up question, one at a time, up to 5. Always pass a `questions` array (never a bare `question` key). Stop earlier when the picture is clear. Each question should be guided by these principles:

- **Understand the gap** — what is broken, missing, or suboptimal and in which context does it surface?
- **Understand the stakes** — what breaks or degrades if this is left unfixed?
- **Understand constraints** — are there hard limits (line count, backward compatibility, scope)?
- **Understand the desired outcome** — what does success look like after the change?
- **Avoid redundancy** — never ask for information already given in the description or a prior answer.

**Step 3 — Derive n and slug**

Run: `rtk bash -c 'ls .claude/skills/improve/ 2>/dev/null | grep -E "^[0-9]+" | sort -n | tail -1'` → increment by 1 for `n` (default 1 if empty). For the improvement path, slugify the description to ≤3 lowercase hyphenated words for `feature-type`. For the lightweight agent-creation path, use `create-<agent-name>` as the slug. Store the resolved path as `$OUT` (e.g. `.claude/skills/improve/3-refactor-step-flow/`). All subsequent steps use `$OUT`.

**Step 4 — Read and write plan**

Read `.claude/skills/improve/refs/template.md`. Create `$OUT` and write `$OUT/plan.md` populated from the template using the description and clarification answers. For the lightweight agent-creation path, the plan.md must be readable as a standalone brief passable directly to `/agent-build`.

**Step 5 — Acceptance criteria**

For every discrete change in the plan, write one or more testable assertions to `$OUT/acceptance.md`. Each assertion is one line, numbered sequentially. Every change must map to at least one criterion — no exceptions.

**Step 6 — Review and terminate**

Emit `$OUT` as a markdown link.

Call `AskUserQuestion` with a `questions` array: `header: "Next step"`, `question: "What would you like to do next?"`, `multiSelect: false`, `options`:
- **Revise** — ask what to change, then read and edit `$OUT/plan.md` and `$OUT/acceptance.md` in place. Re-emit Step 6.
- **Done** — emit exactly: "Plan and acceptance criteria emitted. Please double-check the plan or run another agent to do an adversarial review."
