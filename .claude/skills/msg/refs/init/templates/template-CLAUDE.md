---
name: CLAUDE Template
description: Template for CLAUDE.md — project-level instructions Claude Code reads on every session start
type: reference
---

# CLAUDE Template

The skill writes CLAUDE.md from this body, substituting `{{project_name}}`, `{{platform}}`, `{{language}}`, and `{{conventions}}` from Step 2.

## Template body

```markdown
# {{project_name}} — Claude Code Instructions

This file is read by Claude Code on every session start. Keep it short, current, and prescriptive.

## Project

- **Name**: {{project_name}}
- **Platform**: {{platform}}
- **Language**: {{language}}

## How to work in this repo

### Conventions

{{conventions}}

### File map

- `features/prd-[n]-[feature-slug]/prd-[n]-[feature-slug].md` — Product requirements and engineering sections per feature
- `devkit/ARCHITECTURE.md` — High-level system design and platform decisions
- `devkit/GLOSSARY.md` — Canonical domain terms; reference before introducing new vocabulary
- `devkit/AHA.md` — Past mistakes; check before repeating a pattern that bit the team

### Defaults

- Target platform for new features: {{platform}}. State the platform explicitly if a feature targets something else.
- When a domain term appears, check `devkit/GLOSSARY.md` for the canonical definition before defining it inline.

## Working with msg skills

- `/msg --init` — One-time project bootstrap (already run if you are reading this)
- `/intake` — Capture + grade feature ideas and bugs into the `INTAKE.md` backlog (owns the requirements interview)
- `/plan-pm` — Autonomous PRD writer — drafts the full PRD from a graded intake row
- `/plan-tune` — Contract certifier — seven consumer-bound checks on an existing PRD (auto-run by `/plan-em`)
- `/plan-em` — Engineering plan generation from an approved PRD
- `/commit-this` — Conventional commit message from staged diff
```

## Notes

- The persona, values, and stack details are intentionally minimal at init. The user fills them in as the project takes shape.
- Do not insert content the user did not provide. Empty sections are acceptable; invented sections are not.
