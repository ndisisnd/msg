---
name: CLAUDE Template
description: Template for CLAUDE.md — project-level instructions Claude Code reads on every session start
type: reference
---

# CLAUDE Template

The skill writes CLAUDE.md from this body, substituting `{{project_name}}`, `{{platform}}`, `{{team_type}}`, and `{{conventions}}` from the interview.

## Template body

```markdown
# {{project_name}} — Claude Code Instructions

This file is read by Claude Code on every session start. Keep it short, current, and prescriptive.

## Project

- **Name**: {{project_name}}
- **Platform**: {{platform}}
- **Team**: {{team_type}}

## How to work in this repo

### Conventions

{{conventions}}

### File map

- `features/prd-[n]/prd-[n].md` — Product requirements per feature
- `features/prd-[n]/rfc-[n].md` — Engineering plan per feature
- `ARCHITECTURE.md` — High-level system design and platform decisions
- `GLOSSARY.md` — Canonical domain terms; reference before introducing new vocabulary
- `AHA.md` — Past mistakes; check before repeating a pattern that bit the team

### Defaults

- Target platform for new features: {{platform}}. State the platform explicitly if a feature targets something else.
- When a domain term appears, check `GLOSSARY.md` for the canonical definition before defining it inline.

## Working with msg skills

- `/msg-init` — One-time project bootstrap (already run if you are reading this)
- `/plan-pm` — Interview-driven PRD generation
- `/plan-tune` — Adversarial audit of an existing PRD
- `/plan-em` — RFC engineering plan generation from an approved PRD
- `/msg-commit` — Conventional commit message from staged diff
```

## Notes

- The persona, values, and stack details are intentionally minimal at init. The user fills them in as the project takes shape.
- Do not insert content the user did not provide. Empty sections are acceptable; invented sections are not.
