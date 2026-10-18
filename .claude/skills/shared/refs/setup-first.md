---
name: setup-first
description: The one rule every msg skill follows when the project has no devkit/ — run /msg --init first, then continue the command the user asked for. Cited by intake, plan-pm, plan-review, plan-em, eng, pre-merge and merge.
type: reference
---

# Setup runs by itself — no `devkit/` ⇒ `/msg --init` first

`devkit/` is the project setup every msg skill reads. Only `/msg --init` creates it.
A skill never refuses, and never sends the user away, because it is missing.

## The rule

At the start of a run, before any other read:

```bash
[ -d devkit ] && echo SETUP=yes || echo SETUP=no
```

| `SETUP` | Do |
|---|---|
| `yes` | continue — the skill's own steps run as written |
| `no` | say one line — "This project is not set up yet — running `/msg --init` first, then `<the command>`." — run `Skill("msg", "--init")`, then continue the command the user asked for, in the same run |

- **One interview.** `/msg --init` asks its setup questions (≤4 prompts; `msg/refs/protocol-eng.md`).
  The user answers them once; the skill then carries on.
- **Setup stopped** (the user cancels, or `init.sh` fails) ⇒ stop the command too. Nothing
  runs on a half-set-up project.
- **No hand-off chatter.** When `/msg --init` runs as this pre-step it ends after its
  manifest. Its "Next: …" line and closing message are skipped, because the user's command
  is the next step.
- **Two setup layers stay.** `/msg --init` writes the project files. pre-merge and merge
  still run their own first-run setup after it, for their own settings
  (`policy-schema.md` §0).
- **A single missing file** inside an existing `devkit/` is not this rule: the skill's own
  absent-file note stands, and `/msg --update` adds the file.
