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

{{arch_overview}}

## Component map

| Component | Responsibility | Owner / Stack |
|-----------|----------------|---------------|
| [USER: component] | [USER: responsibility] | [USER: stack] |

## External dependencies

| Service | Purpose | Auth model |
|---------|---------|------------|
| {{arch_external}} | [USER: purpose] | [USER: auth model] |

## Data stores

{{arch_data_stores}}

## Cross-cutting concerns

- **Authentication**: {{arch_auth}}
- **Authorisation**: [USER: model]
- **Observability**: [USER: logging, metrics, tracing approach]
- **Deployment**: {{arch_deployment}}

## Decisions log

Record significant architectural decisions inline with the date and reasoning. Avoid burying these in commit messages.

### [YYYY-MM-DD] Decision title
**Context**: What forced the decision.
**Decision**: What was chosen.
**Consequences**: Trade-offs accepted.
```

## Notes

- System overview, external dependencies, data stores, authentication, and deployment are pre-populated from the Step 3 architecture interview. The Component map table and authorisation/observability remain as `[USER: …]` gaps for the user to fill in as the system takes shape.
- `plan-pm` reads the Primary platform line to default platform questions during PRD interviews.
- `plan-em` reads the Component map and Data stores sections to map PRD features to engineering domains.
