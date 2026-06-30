---
name: README Template
description: Placeholder README.md created at project init; carries the project name and one-line description from the msg-init interview
type: reference
---

# README Template

The skill writes a README.md from this body, substituting `{{project_name}}` and `{{project_description}}` from the interview answers.

## Template body

```markdown
# {{project_name}}

{{project_description}}

## Status

Project bootstrapped with `msg-init`. PRDs live under `features/prd-[n]-[feature-slug]/`. See `devkit/ARCHITECTURE.md` for the high-level structure and `CLAUDE.md` for working conventions.

## Getting started

[USER: fill in setup instructions once the stack is wired up]

## Documentation

- `devkit/ARCHITECTURE.md` — system design and platform decisions
- `devkit/GLOSSARY.md` — canonical domain term definitions
- `devkit/AHA.md` — institutional knowledge log
- `features/` — product requirement documents and engineering plans
```

## Notes

- Keep the body short. The README is a landing page, not a manual.
- The `[USER: fill in …]` marker is the only acceptable placeholder. Replace it as soon as the project has a real setup path.
