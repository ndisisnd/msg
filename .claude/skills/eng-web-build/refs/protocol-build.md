---
name: Build Protocol
description: How eng-web-build reads the approved implementation plan and executes it step by step with human gates
type: reference
---

# Build Protocol

Invoked when `eng-web-build` starts. The agent reads the approved implementation plan produced by `eng-web-plan`, emits the full step list, then executes each step only after explicit human approval. No step runs without a gate.

---

## Inputs

| Name | Source |
|------|--------|
| PRD path | Passed at invocation |
| Implementation plan | `## Implementation Plan — eng-web` section in the PRD or conversation context |

---

## Steps

### Step 1 — Read the implementation plan

Read the PRD at the given path. Locate the `## Implementation Plan — eng-web` section produced by `eng-web-plan`. If the section is missing, halt and report: `"[BUILD BLOCKED] No implementation plan found — run eng-web-plan first."`

Extract the ordered step list. Each entry has:
- A step number
- A feature and concern label
- Execution steps
- A `Depends on:` line

### Step 2 — Emit the full step list

Output the complete numbered step list to the user before executing anything. Format each entry as:

```
N. <Feature — Concern>
   <execution step 1>
   <execution step 2>
   ...
   Depends on: <none | Step N | External: ...>
```

Do not begin execution until the list is fully emitted.

### Step 3 — Execute with human gates

For each step in sequence:

1. Announce: `"Step N: <Feature — Concern> — proceed?"` via `AskUserQuestion` with options: **Proceed** / **Skip** / **Stop**.
2. On **Proceed**: implement the step. Report what was done before advancing.
3. On **Skip**: note the skip and advance to the next step. Flag any downstream steps that depended on this one.
4. On **Stop**: halt immediately. Do not advance. Await guidance.

**Constraints:**
- Never advance to the next step without explicit approval.
- Never deviate from the committed architecture without raising an escalation before proceeding.
- Commit code per team convention after each step that produces file changes.
- If a step is blocked by an external dependency (flagged `External:` in the plan), announce the blocker and ask the user how to proceed before attempting the step.

---

## Quality gate

| Check | Rule |
|-------|------|
| Plan present | Implementation plan section found before any execution begins. |
| Full list emitted | All steps shown to user before Step 3 starts. |
| Gate on every step | No step executes without an explicit Proceed. |
| Escalation on deviation | Any deviation from the plan raises an explicit escalation — not a silent change. |
