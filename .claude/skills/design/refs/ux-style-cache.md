---
name: UX Style Cache
description: Cached visual style preference; written on first run, read every run, reset by --reset
type: reference
---

# UX style cache

This file holds the user's visual style preference. The skill writes it once on the first run, reads it on every later run, and never re-asks until `/design --reset` deletes it.

## Current value

```
status: unset
```

The seed value is `status: unset`. Treat `unset` as "no preference saved yet" — ask the style question and overwrite this block.

## Read rule

- File holds a populated `style:` line → load it silently; do not ask the style question.
- File is missing, or holds `status: unset` → ask one `AskUserQuestion` (single-select, ≤4 options: Minimal / Bold / Corporate / Data-dense), then overwrite this file.

## Write format

Write exactly two lines after the heading — a `style:` value and a one-line elaboration:

```
style: data-dense
note: maximize information per screen; tight spacing; small type scale; minimal chrome
```

## Style vocabulary

| Style | What it means |
|-------|---------------|
| Minimal | Generous whitespace, few elements, restrained type and color. |
| Bold | High contrast, large type, confident color use within DS roles. |
| Corporate | Restrained palette, conventional layout, trust-forward and dense. |
| Data-dense | Maximum information per screen, tight spacing, compact components. |

**Applied**: A first run with no cache asks the style question, the user picks "Bold", and the skill writes `style: bold` plus a one-line note — every later run reads "bold" without asking again.
