---
name: PRD Template
description: Structured PRD format for plan-pm to populate
type: reference
---

# PRD Template

Populate every section. Do not delete a section — if a section does not apply, write `N/A` with a one-sentence reason.

## File header

```markdown
---
name: prd-[n]-[feature_slug]
feature: <short feature name>
module: <primary module or domain this PRD touches, e.g. auth | payments | notifications>
affects: []   # prd-[n]-[feature_slug] IDs whose scope this PRD overlaps or may break
depends_on: []  # prd-[n]-[feature_slug] IDs that must ship before this one
platform: <detected platform, e.g. mobile | web | backend>
status: product
tuned: no
created: YYYY-MM-DD
---

# PRD-[n]: <Feature Name>
```

## Required sections

### 1. Out-of-scope

Bulleted list of features or behaviors explicitly excluded. Each item has a one-line reason.

**Worked example:**
- Social sharing of streaks — covered in PRD-4-social-sharing (separate workstream).
- Backfill of historical habits — out of scope; users start from sign-up date.

### 2. Target platform

| Field | Value |
|-------|-------|
| Platform | iOS / Android / Web (fill in) |
| Min OS version | e.g., iOS 16.0+ |

**Worked example:**
| Field | Value |
|-------|-------|
| Platform | iOS |
| Min OS version | iOS 16.0+ |

### 3. User flows

At least one ASCII flow diagram per feature. Each flow must show the happy path from entry point to completion. Use boxes (`[ ]`), arrows (`-->`), and decision diamonds (`< >`). Label every step with the screen name or action.

**Format per feature:**

```
Feature: <feature name>

[Entry point / trigger]
        |
        v
[Screen or step]
        |
        v
< Decision? >
   yes |     | no
       v     v
  [Result A] [Result B]
```

**Worked example:**

```
Feature: Set daily goal

[Home screen — tap "+" button]
        |
        v
[New Habit screen]
  User enters name + frequency
        |
        v
< Name field empty? >
   yes |            | no
       v            v
[Inline error:   [Habit saved to list]
 "Name required"]      |
                       v
               [Home screen — habit
                row appears instantly]
```

### 4. Key user interactions

Bulleted list of the core actions a user can take within this feature. Each item is a single sentence starting with "User can …". Derived from Q5 of the interview.

**Worked example:**
- User can add a new habit by entering a name and target frequency.
- User can delete an existing habit from the habit list.
- User can edit a habit's name or frequency after creation.

### 5. Error cases

Format, rules, and examples: see `refs/template-error.md`.

### 6. Open questions

Bulleted list. Each item is a single unresolved question that must be answered before implementation starts. Sources: overlap with prior PRDs (Step 2), unresolved AHA.md entries, any ambiguity surfaced during the interview.

**Worked example:**
- PRD-2-streak-tracking also handles streak resets — confirm which PRD owns the reset logic before building.
- Target OS minimum not confirmed; assumed iOS 16.0+ pending design sign-off.

### 7. Glossary

Table of domain terms used in this PRD. Cross-reference `GLOSSARY.md`; include any term defined there that appears in this document. Add new terms not yet in `GLOSSARY.md`.

| Term | Definition |
|------|------------|

**Worked example:**

| Term | Definition |
|------|------------|
| Streak | Consecutive days a habit is marked complete. Resets to 0 on a missed day. |
| Habit | A user-defined recurring activity tracked by the app. |

