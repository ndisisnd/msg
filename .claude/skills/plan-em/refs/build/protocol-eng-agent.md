---
name: Eng-agent protocol — build mode
description: Build-mode protocol for eng-agent subagents — writes implementation code to the working branch using the PRD engineering section as specification
type: reference
---

# Eng-agent Protocol — Build Mode

Eng-agents are specialist subagents activated after plan mode is complete. Each agent owns a subset of PRD features and writes implementation code.

Agent names follow the pattern `eng-<platform>` (e.g., `eng-android`, `eng-ios`, `eng-web`, `eng-backend`).

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
