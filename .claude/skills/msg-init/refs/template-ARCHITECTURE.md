---
name: ARCHITECTURE Template
description: Template for ARCHITECTURE.md — high-level system design stub read by plan-pm and plan-em
type: reference
---

# ARCHITECTURE Template

The skill writes ARCHITECTURE.md from this body, substituting `{{project_name}}` and `{{platform}}` from the interview.

## Template body

```markdown
# {{project_name}} — Architecture

High-level system design and platform decisions for {{project_name}}. Read by `plan-pm` for platform defaults and by `plan-em` when scoping engineering work.

## Primary platform

{{platform}}

## System overview

[USER: fill in a one-paragraph description of the system's major components and how they communicate]

## Component map

| Component | Responsibility | Owner / Stack |
|-----------|----------------|---------------|
| [USER: component] | [USER: responsibility] | [USER: stack] |

## External dependencies

| Service | Purpose | Auth model |
|---------|---------|------------|
| [USER: service] | [USER: purpose] | [USER: auth model] |

## Data stores

[USER: list databases, caches, queues, blob stores, and what each holds]

## Cross-cutting concerns

- **Authentication**: [USER: model]
- **Authorisation**: [USER: model]
- **Observability**: [USER: logging, metrics, tracing approach]
- **Deployment**: [USER: CI/CD pipeline and environments]

## Decisions log

Record significant architectural decisions inline with the date and reasoning. Avoid burying these in commit messages.

### [YYYY-MM-DD] Decision title
**Context**: What forced the decision.
**Decision**: What was chosen.
**Consequences**: Trade-offs accepted.
```

## Notes

- Every `[USER: …]` marker is a deliberate gap. The user fills these in as the system takes shape.
- `plan-pm` reads the Primary platform line to default platform questions during PRD interviews.
- `plan-em` reads the Component map and Data stores sections to map PRD features to engineering domains.
