---
name: Eng-agent protocol — plan mode
description: Plan-mode protocol for eng-agent subagents — produces structured engineering sections returned as markdown for plan-em to append to the PRD
type: reference
---

# Eng-agent Protocol — Plan Mode

Eng-agents are specialist subagents activated by plan-em. Each agent owns a subset of PRD features and operates in plan mode.

Agent names follow the pattern `eng-<platform>` (e.g., `eng-android`, `eng-ios`, `eng-web`, `eng-backend`).

---

## Mode 1: plan

The agent reads the PRD and writes a structured engineering section covering only its assigned features. Output is returned as markdown — plan-em appends it to the PRD under `## Engineering — <Agent Name>`. No files are created by the agent.

**Activated by:** plan-em Step 4.

**Devkit reads (plan mode):** Before reading the PRD, read the following files in parallel and apply them throughout the engineering section:

| File | How to apply |
|------|-------------|
| `devkit/AHA.md` | Avoid repeating resolved mistakes; surface relevant past learnings in §12 (Findings) |
| `devkit/GLOSSARY.md` | Use canonical terms throughout; flag any PRD terms that deviate |
| `CLAUDE.md` | Apply tech stack constraints and conventions to all design decisions |
| `devkit/ARCHITECTURE.md` | Validate scope against system layers; flag conflicts in §12 (Findings) |
| `devkit/DESIGN-SYSTEM.md` | Note impacted or reusable components in §5 (Scope mapping) |

If `devkit/` does not exist, emit `devkit/ not found — run /msg-init to initialise the project first.` and proceed. If an individual file is missing, emit a per-file warning and proceed.

**Input:**
- PRD path
- Owned feature IDs and names
- Execution Table rows where the Agent column matches this agent

**Output:**
1. Structured engineering section following `refs/plan/template-eng-plan.md`
2. Execution steps filled in for every owned row in the Execution Table (following `refs/build/protocol-exec.md`)

**Constraints:**
- Do not create files — return output only
- Cover only features assigned to this agent
- Follow `refs/build/protocol-exec.md` for Execution steps format
