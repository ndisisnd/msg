---
name: Todo-preference bootstrap
description: First-invocation resolution of plan-em's `todos` preference — detects a pre-existing user task-breakdown skill and writes prefs.json
type: reference
---

# Todo-preference bootstrap (`prefs.json`)

Loaded from `SKILL.md` Step 0 **only on the first invocation** — when `.claude/skills/plan-em/prefs.json` is missing, unreadable, or not valid JSON with a boolean `todos` field. On every later invocation the stored value governs and this file is not read.

`$TODOS` gates the **entire** todo layer, which is owned entirely by `plan-em`: the execution table's Todos column (Step 3), the todo phase (Step 4), and the todo handoff (Step 5). `$TODOS = false` means the pipeline runs plan → build exactly as it did before the todo layer existed — no Todos column, no todo phase, no `## Todos` section.

## First-invocation scan

Determine whether the user already has their own todos / task-breakdown skill, and defer to it if so:

- List skill directories in `.claude/skills/` (this project) and `~/.claude/skills/` (global).
- A skill counts as a **pre-existing user task-breakdown skill** if it is **not** part of the msg skill set (`eng`, `msg`, `plan-em`, `plan-pm`, `plan-tune`, `pre-merge`, `review`, `test`, `shared`) **and** its directory name contains `todo` or `task`, or its `SKILL.md` `description` mentions todo generation / task breakdown / task list.
- **Found** one → `todos: false` (defer to the user's own; msg does not add a competing todo layer).
- **None found** → `todos: true` (msg owns the todo layer).

## Write and continue

Write the result to `.claude/skills/plan-em/prefs.json` (a corrupt file is overwritten, not crashed on):

```json
{ "todos": true }
```

Set `$TODOS` to the written value and continue to Step 1.
