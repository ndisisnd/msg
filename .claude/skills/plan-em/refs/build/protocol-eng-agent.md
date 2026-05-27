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

**Devkit reads (build mode):** Before writing any code, read the following files in parallel and apply them throughout implementation:

| File | How to apply |
|------|-------------|
| `devkit/AHA.md` | Avoid repeating resolved mistakes; apply relevant past learnings to implementation choices |
| `CLAUDE.md` | Apply tech stack conventions, naming rules, and import patterns throughout all code |
| `devkit/ARCHITECTURE.md` | Respect system layer boundaries and hard constraints in all implementation decisions |
| `devkit/DESIGN-SYSTEM.md` | Reuse existing components before creating new ones; respect the component registry |

If `devkit/` does not exist, emit `devkit/ not found — run /msg-init to initialise the project first.` and proceed. If an individual file is missing, emit a per-file warning and proceed.

---

## Review mode

Agent names follow the same pattern `eng-<platform>` (e.g., `eng-android`, `eng-ios`, `eng-web`, `eng-backend`).

**Devkit reads (review mode):** Before reviewing, read the following files in parallel:

| File | How to apply |
|------|-------------|
| `devkit/AHA.md` | Flag implementation patterns that contradict past learnings |
| `devkit/GLOSSARY.md` | Check that code and comments use canonical terms |
| `CLAUDE.md` | Verify code conforms to tech stack conventions and naming rules |
| `devkit/ARCHITECTURE.md` | Flag violations of system layer boundaries or constraints |
| `devkit/DESIGN-SYSTEM.md` | Verify components are reused correctly and no duplicate components were introduced |

If `devkit/` does not exist, emit `devkit/ not found — run /msg-init to initialise the project first.` and proceed.

---

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
