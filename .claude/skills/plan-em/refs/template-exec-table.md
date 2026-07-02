---
name: Execution Table Template
description: Feature execution breakdown table — plan-em pre-populates Feature and Agent; subagents fill in Execution steps
type: reference
---

# Execution Table Template

The execution table is a flat breakdown of every feature into its discrete execution concerns. `plan-em` creates the skeleton (Feature + Agent pre-populated, Execution steps blank) after the agent roster is approved. Subagents then fill in their assigned rows.

## Table structure

Base form (todo layer off — `plan-em` Step 0 resolved `$TODOS = false`):

| Feature | Execution steps | Agent |
|---------|----------------|-------|

With the todo layer on (`$TODOS = true`), a **Todos** column is inserted between Execution steps and Agent:

| Feature | Execution steps | Todos | Agent |
|---------|----------------|-------|-------|

**Column definitions:**

- **Feature** — `<ID>: <name> — <execution concern>`. Combines the PRD feature ID, feature name, and the specific execution concern for this row (e.g., `F1: Set daily goal — API contract`). One row per execution concern per feature.
- **Execution steps** — Left blank by `plan-em`. The assigned agent fills this in later; the step format is defined per-agent.
- **Todos** *(only when `$TODOS = true`)* — Populated by `plan-em` when it builds the skeleton: an anchor link to the feature's `### F<n>` subsection under the `## Todos` section, `[F<n>](#todos-f<n>)`. All rows sharing an F-ID point to the same anchor. A forward pointer — the `### F<n>` blocks are written later in the todo phase. Omitted entirely when the todo layer is off.
- **Agent** — Pre-populated by `plan-em` from the approved agent roster. Matches the agent responsible for this concern.

## Execution concerns to cover

For each feature, create one row per applicable concern. Always evaluate:

| Concern | When to include |
|---------|----------------|
| API contract | Feature exposes or consumes any endpoint |
| Schema migration | Feature reads or writes any database table |
| Authentication | Feature introduces or extends an auth flow |
| Webhook / hook | Feature emits events or hooks into a platform lifecycle |
| Client implementation | Feature has UI or client-side logic |
| Tests | Always — one row per agent covering their owned concerns |

Add rows for any additional concern surfaced by the codebase scan or integration contracts section.

## How plan-em builds the skeleton

After the agent roster is approved:

1. For each feature in the PRD, enumerate its applicable execution concerns (using the table above as a checklist).
2. Assign each concern to the agent that owns it (from the scope mapping).
3. Write one row per `(feature, concern)` pair — Feature and Agent pre-populated, Execution steps blank. When `$TODOS = true`, also fill each row's **Todos** cell with `[F<n>](#todos-f<n>)` for that row's F-ID.

Append the skeleton to the PRD as a new section immediately before the engineering sections. With the todo layer on (`$TODOS = true`):

```markdown
## Execution Table

| Feature | Execution steps | Todos | Agent |
|---------|----------------|-------|-------|
| F1: Set daily goal — API contract | | [F1](#todos-f1) | backend-eng |
| F1: Set daily goal — Schema migration | | [F1](#todos-f1) | backend-eng |
| F1: Set daily goal — iOS UI | | [F1](#todos-f1) | mobile-eng-ios |
| F1: Set daily goal — Tests | | [F1](#todos-f1) | backend-eng |
| F1: Set daily goal — Tests | | [F1](#todos-f1) | mobile-eng-ios |
| F2: Track streak — Schema migration | | [F2](#todos-f2) | backend-eng |
| F2: Track streak — API contract | | [F2](#todos-f2) | backend-eng |
| F2: Track streak — iOS UI | | [F2](#todos-f2) | mobile-eng-ios |
| F3: Daily reminder — iOS push | | [F3](#todos-f3) | mobile-eng-ios |
| F3: Daily reminder — Tests | | [F3](#todos-f3) | mobile-eng-ios |
```

With the todo layer off (`$TODOS = false`), drop the Todos column entirely:

```markdown
## Execution Table

| Feature | Execution steps | Agent |
|---------|----------------|-------|
| F1: Set daily goal — API contract | | backend-eng |
```

## How agents fill in execution steps

Each subagent receives the PRD path and the list of feature IDs it owns. When writing its engineering section, the agent must also fill in the Execution steps column for every row where the Agent column matches its name. The step format, granularity rules, cross-agent dependency notation, and worked examples are defined in `refs/protocol-exec.md` — read that before writing a single step.

## Quality gate

Every row the agent owns must have its Execution steps filled in before the agent returns its output. Blank execution steps in an agent's rows are a hard failure.
