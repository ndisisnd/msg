---
name: Execution Table Template
description: Feature execution breakdown table — plan-em pre-populates Feature and Agent; subagents fill in Execution steps
type: reference
---

# Execution Table Template

The execution table is a flat breakdown of every feature into its discrete execution concerns. `plan-em` creates the skeleton (Feature + Agent pre-populated, Execution steps blank) after the agent roster is approved. Subagents then fill in their assigned rows.

## Table structure

| Feature | Execution steps | Agent |
|---------|----------------|-------|

**Column definitions:**

- **Feature** — `<ID>: <name> — <execution concern>`. Combines the PRD feature ID, feature name, and the specific execution concern for this row (e.g., `F1: Set daily goal — API contract`). One row per execution concern per feature.
- **Execution steps** — Left blank by `plan-em`. The assigned agent fills this in later; the step format is defined per-agent.
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
3. Write one row per `(feature, concern)` pair — Feature and Agent pre-populated, Execution steps blank.

Append the skeleton to the PRD as a new section immediately before the engineering sections:

```markdown
## Execution Table

| Feature | Execution steps | Agent |
|---------|----------------|-------|
| F1: Set daily goal — API contract | | backend-eng |
| F1: Set daily goal — Schema migration | | backend-eng |
| F1: Set daily goal — iOS UI | | mobile-eng-ios |
| F1: Set daily goal — Tests | | backend-eng |
| F1: Set daily goal — Tests | | mobile-eng-ios |
| F2: Track streak — Schema migration | | backend-eng |
| F2: Track streak — API contract | | backend-eng |
| F2: Track streak — iOS UI | | mobile-eng-ios |
| F3: Daily reminder — iOS push | | mobile-eng-ios |
| F3: Daily reminder — Tests | | mobile-eng-ios |
```

## How agents fill in execution steps

Each subagent receives the PRD path and the list of feature IDs it owns. When writing its engineering section, the agent must also fill in the Execution steps column for every row where the Agent column matches its name. The step format itself is defined per-agent — this template only guarantees the skeleton.

## Quality gate

Every row the agent owns must have its Execution steps filled in before the agent returns its output. Blank execution steps in an agent's rows are a hard failure.
