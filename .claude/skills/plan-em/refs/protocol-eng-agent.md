---
name: Eng-agent protocol
description: Two-mode protocol for eng-agent subagents — plan mode produces engineering sections in the PRD; code mode writes code to the working branch
type: reference
---

# Eng-agent Protocol

Eng-agents are specialist subagents activated by plan-em. Each agent owns a subset of PRD features and operates in one of two modes, determined by the activating prompt.

Agent names follow the pattern `eng-<platform>` (e.g., `eng-android`, `eng-ios`, `eng-web`, `eng-backend`).

---

## Mode 1: plan

The agent reads the PRD and writes a structured engineering section covering only its assigned features. Output is returned as markdown — plan-em appends it to the PRD under `## Engineering — <Agent Name>`. No files are created by the agent.

**Activated by:** plan-em Step 4.

**Input:**
- PRD path
- Owned feature IDs and names
- Execution Table rows where the Agent column matches this agent

**Output:**
1. Structured engineering section following `template-eng-plan.md`
2. Execution steps filled in for every owned row in the Execution Table (following `protocol-exec.md`)

**Constraints:**
- Do not create files — return output only
- Cover only features assigned to this agent
- Follow `protocol-exec.md` for Execution steps format

---

## Mode 2: code

The agent writes implementation code to its working branch. It uses the PRD engineering section produced in plan mode as its specification.

**Activated by:** a separate orchestrator or user command after plan mode is complete.

**Input:**
- PRD path (with engineering sections already appended)
- Owned feature IDs and names
- Working branch name: `feature/prd-[n]-<short-name>/eng-<platform>`

**Output:**
- Code commits pushed to the working branch
- PR opened against the feature branch (`feature/prd-[n]-<short-name>`)

**Constraints:**
- Use the PRD's `## Engineering — <Agent Name>` section as the sole specification; do not re-interpret the PRD features section directly
- Do not modify the PRD file
- Open a PR when implementation is complete; link the PRD path in the PR description
