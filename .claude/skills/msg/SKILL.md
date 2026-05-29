---
name: msg
description: Root menu for msg skills
model: claude-sonnet-4-6
allowed_tools:
  - AskUserQuestion
---

# msg

## Usage

**Invoke**: `/msg`. No argument bypasses the menu — every invocation presents the skill picker.

## Skills

| Skill | Description |
|-------|-------------|
| msg-init | One-time project bootstrap |
| plan-pm | PM interview — PRD writer |
| plan-tune | PRD auditor — product/eng |
| plan-em | Engineering plan generator |
| review | Five-mode code review — Quality, Coverage, Functional, Security, Perf |
| docu | Stale doc checker and fixer |
| handoff | Structured mid-flight handoff artifact |
| todo | Parse PRD tables → TODOs.json |
| improve | Improvement planner for any skill |

## Protocol

**Step 1 — Present menu**

Call `AskUserQuestion` once, sourcing options from the Skills table above:

- **Question**: `Which msg skill would you like to use?`
- **Header**: `Skill`
- **multiSelect**: `false`
- **Options** (one per table row, in table order):
  - `label`: Skill column value
  - `description`: Description column value

**Step 2 — Emit selection**

Emit exactly:

```
/<skill> — <description>
```

Where `<skill>` and `<description>` are the values from the selected row. Stop. Do not emit anything else.
