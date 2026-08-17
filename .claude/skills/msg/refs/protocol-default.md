---
name: msg default picker
description: The /msg (no args) protocol — two AskUserQuestion steps that route to a skill and emit one line
type: reference
---

# Protocol: default (no args)

Dispatched from `msg/SKILL.md` on bare `/msg`. The category/skill rows come from
the SKILL.md **Skills** table — the canonical menu; this protocol never restates it.

**Step 1 — Category**

Call `AskUserQuestion` with one question:

- **Question**: `Which area do you need help with?`
- **Header**: `Category`
- **multiSelect**: `false`
- **Options**:
  - `label`: `Planning`, `description`: `Bootstrap, idea capture, spec writing, PRD audit, engineering planning`
  - `label`: `Build & Ship`, `description`: `Implement code and run the CI gate`
  - `label`: `Delivery`, `description`: `Task lists, commits`

**Step 2 — Skill**

`AskUserQuestion` allows 2–4 options per question.

- **Question**: `Which skill?`
- **Header**: `Skill`
- **multiSelect**: `false`
- **Options**: the rows in the selected category, in table order (`label` = Skill, `description` = Description).

**Paging (Planning has 5 rows).** When a category has more than 4 rows (Planning: msg --init · intake · plan-pm · plan-review · plan-em), present the first 4 in table order plus a final `More…` option; if the user picks `More…`, re-ask with the remaining rows. Every other category has ≤4 rows and is asked in one call.

**Step 3 — Emit**

Emit exactly:

```
/<skill> — <description>
```

Stop. Do not emit anything else.
