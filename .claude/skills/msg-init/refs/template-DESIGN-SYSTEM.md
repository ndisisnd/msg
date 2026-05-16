---
name: DESIGN-SYSTEM Template
description: Template for DESIGN-SYSTEM.md — component registry read by plan-pm and plan-em to identify impacted or reused UI components
type: reference
---

# DESIGN-SYSTEM Template

The skill writes DESIGN-SYSTEM.md from this body, substituting `{{project_name}}` from the interview.

## Template body

```markdown
# {{project_name}} — Design System

Component registry for {{project_name}}. Read by `plan-pm` when assessing UI impact of proposed features, and by `plan-em` when scoping frontend engineering work.

## Components

| Component | Directory | Data ingested |
|-----------|-----------|---------------|
| [USER: component name] | [USER: e.g. src/components/Button] | [USER: props, state, or API data the component consumes] |

## Design tokens

[USER: list colour, spacing, typography tokens and where they live — e.g. src/tokens/colors.ts]

## Component library

[USER: note any external component library in use — e.g. shadcn/ui, MUI, Tailwind UI, native iOS UIKit — and the version pinned]

## Conventions

[USER: naming conventions, folder structure rules, theming approach, and any constraints on adding new components]
```

## Notes

- Every `[USER: …]` marker is a deliberate gap. Fill these in as the design system takes shape.
- `plan-pm` reads the Components table to identify which components a proposed feature impacts or can reuse, and surfaces this in §3 (User flows) and §4 (Key user interactions).
- `plan-em` reads the Components table and Design tokens section to scope frontend engineering work and flag data-ingestion changes that components would require.
