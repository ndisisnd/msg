---
name: todo
description: Parses PRD feature execution tables, open-questions files, or user prose and appends structured tasks to TODOs.json. For prose, asks clarifying questions before generating tasks. Gates on user approval before every write. Activates via /todo.
model: claude-sonnet-4-6
allowed_tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# todo

## Usage

**Invoke**: `/todo <file-path | prose>` — pass a PRD path, open-questions path, free-form prose, or nothing (the skill will prompt).

- Slash command `/todo`
- Natural-language: "add todo", "create tasks from this", "break this down into tasks"
- Context: user pastes a PRD feature table or open-questions list after `/todo`

## Inputs

| Name | Format | Source |
|------|--------|--------|
| prd_file | Markdown file containing a `## Execution Table` section (as written by `plan-em`) | file path in user message |
| open_questions_file | Markdown file containing a numbered or bulleted question list | file path in user message |
| prose | Free-form text describing work to be done | user message after `/todo` |

## Outputs

| Name | Format | Destination |
|------|--------|-------------|
| task_list | Array of task objects appended to `TODOs.json` | `TODOs.json` in working directory |

Task object shape:

```json
{
  "id": "todo-N",
  "status": "todo | in-progress | done",
  "agents": "string or null",
  "description": "specific, action-oriented task",
  "source": "<origin>:<stable-key>"
}
```

`source` is a stable origin identity used to de-duplicate on re-run (see `refs/parsing-rules.md`). The same source item always produces the same `source` string, so re-running `/todo` on the same PRD never doubles tasks.

## Progress emission

Emit `Step X/6 — <title>` at the start of each step, unconditionally.

## Step-by-step protocol

**Step 1/6 — Read input and detect type**
Read the content provided after `/todo`. If a file path is given, read the file. Classify the input as one of: `prd` (contains a feature execution table), `open-questions` (contains a numbered or bulleted question list), or `prose` (free-form text). Produce `input_type` and `raw_content`.

**Step 2/6 — Ask clarifying questions (prose only)**
If `input_type` is `prd` or `open-questions`, skip this step.
If `input_type` is `prose`, ask 2–4 targeted MCQs via `AskUserQuestion` covering: affected system or component, desired outcome, and constraints (timeline, scope, approach). Use `refs/clarify-questions.md` as the question bank. Produce `clarified_context`.

**Step 3/6 — Resolve or refuse on ambiguity**
If `input_type` is `prose` and scope is still undefined after answers, refuse and exit with: "Cannot derive tasks — scope is ambiguous. Restate with a specific system, outcome, and constraint." Otherwise proceed with `clarified_context`.

**Step 4/6 — Derive tasks**
Parse the source per `refs/parsing-rules.md`:
- `prd`: read each row of the feature execution table; one row → one task.
- `open-questions`: convert each question requiring code changes into a task; skip exploratory-only questions and note them as dropped.
- `prose`: derive tasks from `clarified_context`.

Assign each task a stable `source` per `refs/parsing-rules.md` (origin file basename or `prose`, plus a slug of the source item). Apply `refs/task-filter.md` to drop non-technical items. Each dropped item is recorded with its reason. Produce `derived_tasks` (array) and `dropped_items` (array of `{item, reason}`).

**Step 5/6 — Preview and gate**
Render `derived_tasks` as a table with columns `id`, `status`, `agents`, `description`. If `dropped_items` is non-empty, list them under the table with each reason. Ask inline:

> "Approve and append N tasks to TODOs.json? (1) approve  (2) abort"

On `abort`, exit without writing. On `approve`, proceed.

**Step 6/6 — Append to TODOs.json**
Run `scripts/append-tasks.sh` with the approved task array. The script creates `TODOs.json` if absent (as `[]`), de-duplicates incoming tasks against existing ones by `source` (and within the batch), reads the highest existing `id`, assigns sequential `todo-N` ids to the survivors continuing from there, and appends via `jq`. Emit the absolute path of the written file, the count appended, and the count skipped as duplicates.

## References

- `refs/schema.json` — task object schema with field definitions and allowed status values
- `refs/clarify-questions.md` — question bank for prose-input clarification (Step 2)
- `refs/parsing-rules.md` — input-type detection rules and per-type parsing recipes (Steps 1, 4)
- `refs/task-filter.md` — technical vs non-technical classification heuristic (Step 4)

## Scripts

- `scripts/append-tasks.sh` — appends a JSON array of tasks to `TODOs.json` via `jq`, handling file creation and `id` sequencing
