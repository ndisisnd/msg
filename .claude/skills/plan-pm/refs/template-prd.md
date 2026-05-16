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
name: prd-[n]
feature: <short feature name>
status: draft | approved
created: YYYY-MM-DD
---

# PRD-[n]: <Feature Name>
```

## Required sections

### 1. Problem statement

One sentence. Name the user pain and its context.

**Worked example:**
> First-time users abandon the habit-tracking flow at the streak-setup step because they don't understand what counts as a streak.

### 2. Out-of-scope

Bulleted list of features or behaviors explicitly excluded. Each item has a one-line reason.

**Worked example:**
- Social sharing of streaks — covered in PRD-4 (separate workstream).
- Backfill of historical habits — out of scope; users start from sign-up date.

### 3. Target platform

| Field | Value |
|-------|-------|
| Platform | iOS / Android / Web (fill in) |
| Min OS version | e.g., iOS 16.0+ |

**Worked example:**
| Field | Value |
|-------|-------|
| Platform | iOS |
| Min OS version | iOS 16.0+ |

### 4. User flows

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

### 5. Key user interactions

Bulleted list of the core actions a user can take within this feature. Each item is a single sentence starting with "User can …". Derived from Q5 of the interview.

**Worked example:**
- User can add a new habit by entering a name and target frequency.
- User can delete an existing habit from the habit list.
- User can edit a habit's name or frequency after creation.

### 6. Error cases

Table form. One row per error state. Every row requires a user-visible message or behavior.

| ID | Trigger | User-visible behavior |
|----|---------|----------------------|
| E1 | Network timeout on habit save | Toast: "Couldn't save. Check your connection and try again." Save button re-enabled. |
| E2 | Notification permission denied | Inline banner: "Enable notifications in Settings to get reminders." No crash. |
| E3 | Empty habit name on submit | Inline field error: "Name is required." Form not submitted. |

**Error case rules:**
- Trigger is a concrete condition, not a category. Not "network error" — "network timeout on save."
- User-visible behavior names the exact UI element (toast, banner, inline error) and the copy.
- Never "gracefully handle" — name the specific behavior.

## Quality gates before save

Before plan-pm saves the file, every gate below must pass:

| Gate | Rule |
|------|------|
| Out-of-scope | At least two explicit exclusions with reasons. |
| User flows | At least one ASCII flow per feature; every flow shows the happy path. |
| Key user interactions | At least two "User can …" bullets. |
| Error cases | At least two rows; each has a concrete trigger and named UI behavior. |
