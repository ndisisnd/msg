---
name: plan-pm-flash-template
description: Slim PRD skeleton for plan-pm --flash. Canonical headings and frontmatter only, so scan-prd-digest.py parses every downstream slice.
---

# Flash PRD template

Fill and write to `features/prd-<n>-<slug>/prd-<n>-<slug>.md`. Headings and frontmatter fields are the ones the digest generator and plan-tune key on — do not rename or drop them.

```markdown
---
name: prd-<n>-<slug>
feature: <short feature name>
summary: <one-line plain-prose gist — no markdown, no line breaks>
module: <primary module or domain>
platform: <platform(s)>
status: product
depends_on: []
affects: []
product-tuned: no
eng-tuned: no
reviewed: no
created: YYYY-MM-DD
---

# PRD-<n>: <title>

## 2. Out-of-scope
- <item — one-line reason>

## 4. Key user interactions
- F<n>: <entry → step → outcome>   <!-- one-line flow per feature -->

## 5. Error cases
- <case>: <expected behavior>

## 6. Features & acceptance criteria

| ID | Feature | Acceptance criterion | Dependencies |
|----|---------|----------------------|--------------|
| F1 | <feature> | <observable user-goal outcome; `[USER: …]` if unknown> | — |

## 9. Plan tune findings

_Populated by plan-tune (/plan-tune) — audit findings table._

## 10. Glossary
- <term>: <definition>
```

Rules: stable F-IDs; verbatim acceptance criteria; `[USER: …]` for any unknown — never omit. Features live **only** in the §6 table — the digest reads features from that table, never from prose sections. No narrative prose sections (Alternatives, DX, Risks) — flash PRDs carry contract only.
