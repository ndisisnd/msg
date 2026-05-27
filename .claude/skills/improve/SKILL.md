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
  - Write
---

# improve

## Usage

**Invoke**: `/improve <description of what to improve>`. Refuses without a description.

## Protocol

**Step 1 — Clarify**

If invoked without a description, call `AskUserQuestion` with a `questions` array containing one entry: `header: "Improve"`, `question: "What would you like to improve?"`, `multiSelect: false`, and at least two placeholder options (e.g. "Describe below" and "Not sure yet") — the user will use the auto-added "Other" field to type freely. Wait for the response before proceeding.

Call `AskUserQuestion` for each follow-up question, one at a time, up to 5. Always pass a `questions` array (never a bare `question` key). Stop earlier when the picture is clear. Each question should be guided by these principles:

- **Understand the gap** — what is broken, missing, or suboptimal and in which context does it surface?
- **Understand the stakes** — what breaks or degrades if this is left unfixed?
- **Understand constraints** — are there hard limits (line count, backward compatibility, scope)?
- **Understand the desired outcome** — what does success look like after the change?
- **Avoid redundancy** — never ask for information already given in the description or a prior answer.

**Step 2 — Derive n and slug**

Run: `rtk bash -c 'ls .claude/skills/improve/ 2>/dev/null | grep -E "^[0-9]+" | sort -n | tail -1'` → increment by 1 for `n` (default 1 if empty). Slugify the description to ≤3 lowercase hyphenated words for `feature-type`. Store the resolved path as `$OUT` (e.g. `.claude/skills/improve/3-refactor-step-flow/`). All subsequent steps use `$OUT`.

**Step 3 — Read and write plan**

Read `.claude/skills/improve/refs/template.md`. Create `$OUT` and write `$OUT/plan.md` populated from the template using the description and clarification answers.

**Step 4 — Acceptance criteria**

For every discrete change in the plan, write one or more testable assertions to `$OUT/acceptance.md`. Each assertion is one line, numbered sequentially. Every change must map to at least one criterion — no exceptions.

**Step 5 — Review and terminate**

Emit `$OUT` as a markdown link.

Call `AskUserQuestion` with a `questions` array: `header: "Next step"`, `question: "What would you like to do next?"`, `multiSelect: false`, `options`:
- **Revise** — ask what to change, then read and edit `$OUT/plan.md` and `$OUT/acceptance.md` in place. Re-emit Step 5.
- **Done** — emit exactly: "Plan and acceptance criteria emitted. Please double-check the plan or run another agent to do an adversarial review."
