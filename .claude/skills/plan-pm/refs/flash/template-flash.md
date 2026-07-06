---
name: plan-pm-flash-template
description: Slim PRD skeleton for plan-pm --flash. Standard headings only, so scan-prd-digest.py parses every downstream slice.
---

# Flash PRD template

Fill and write to `features/prd-<n>-<slug>/prd-<n>-<slug>.md`. Headings are the ones the digest generator keys on — do not rename them.

```markdown
---
prd: <n>-<slug>
platform: <platform(s)>
depends_on: []
affects: []
product-tuned: no
eng-tuned: no
reviewed: no
---

# PRD <n> — <title>

## 1. <Feature title>   <!-- one `## N.` section per feature -->
**F<n>.** <one-line intent>
**Acceptance:**
- <criterion 1>
- <criterion 2>
**Flow:** <entry → step → outcome>

## Out of scope
- <item>

## Glossary
- <term>: <definition>

## Error cases
- <case>: <expected behavior>

## 9. Ledger
<!-- audit findings + stamps appended here by plan-tune -->
```

Rules: stable F-IDs, verbatim acceptance criteria, `[USER: …]` for any unknown — never omit. No narrative prose sections (Alternatives, DX, Risks) — flash PRDs carry contract only.
