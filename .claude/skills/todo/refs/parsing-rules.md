---
name: Parsing Rules
description: Input-type detection rules and per-type parsing recipes for converting source content into task descriptions.
type: reference
---

# Parsing Rules

## Input-type detection (Step 1)

Apply checks in order. First match wins.

| Order | Check | Type |
|-------|-------|------|
| 1 | Input is a file path ending in `.md` AND content contains a Markdown table with a header row including `Feature`, `Phase`, or `Execution` | `prd` |
| 2 | Input is a file path ending in `.md` AND content is a numbered or bulleted list where ≥3 items end with `?` | `open-questions` |
| 3 | Input is a file path AND none of the above match | refuse — unrecognized file shape |
| 4 | Input is not a file path | `prose` |

If a file path is given but the file does not exist, refuse and exit.

## Per-type parsing

### PRD feature execution table

Treat the table as the source of truth. One row → one task.

- Read the row's primary descriptor column (commonly `Feature`, `Task`, or `Deliverable`).
- Combine it with any phase or scope columns into a single action-oriented sentence.
- Drop rows where status indicates the work is already complete (`done`, `shipped`, `merged`).

Example row:

| Feature | Phase | Owner | Status |
|---------|-------|-------|--------|
| User profile avatar upload | P1 | backend | todo |

Derived task:

> "Implement user profile avatar upload (backend, P1)"

### Open-questions file

Each question is evaluated independently.

- Convert questions that require code changes into tasks. Phrase as the work needed to answer them.
- Skip questions that are purely exploratory ("should we consider X?", "what would happen if Y?") — record them as dropped with reason `exploratory-only`.
- Skip questions about people or process — drop with reason `non-technical`.

Example question:

> "How should we handle session expiry when the user has unsaved form data?"

Derived task:

> "Design and implement session-expiry handling that preserves unsaved form data"

### Prose

Use `clarified_context` from Step 2, not the raw prose. Extract distinct work items from the clarified description. One work item → one task.

- Each task names the system, the change, and (when known) the constraint.
- Combine related sub-actions into one task only when they would always ship together.
- Split into separate tasks when items can be merged independently.

Example clarified context:

> "Add per-user rate limiting on all API endpoints, target 100 req/min, configured via env vars."

Derived tasks:

1. "Implement per-user rate limiting middleware for all API endpoints"
2. "Expose rate limit threshold as environment variable (default 100 req/min)"
3. "Write tests for rate limit enforcement at the per-user threshold"

## Task description rules

Every derived task must:

- Start with a verb (Implement, Add, Write, Design, Fix, Remove, Refactor).
- Name the affected system or component.
- Be specific enough that a reader could begin work without re-reading the source.
- Be under 120 characters.
