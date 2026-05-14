---
name: PRD Template
description: Structured PRD format for plan-pm to populate
type: reference
---

# PRD Template

Populate every section. Do not delete a section — if a section does not apply, write `N/A` with a one-sentence reason. Every requirement in §4 must carry an acceptance criterion that an engineer or AI agent can verify without further conversation.

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

Bulleted list of features, platforms, or behaviors explicitly excluded. Each item has a one-line reason. Include at least platform exclusions and feature boundaries.

**Worked example:**
- Apple Watch and CarPlay — no design resource available this quarter.
- Social sharing of streaks — covered in PRD-4 (separate workstream).
- Backfill of historical habits — out of scope; users start from sign-up date.

### 3. Target platform

Single platform — no exceptions. This PRD covers exactly one platform as chosen in Q1. Any other platform requiring this feature gets its own PRD.

| Field | Value |
|-------|-------|
| Platform | iOS / Android / Web (fill in) |
| Min OS version | e.g., iOS 16.0+ |
| Excluded platforms | List all others with a one-line reason each |

**Worked example:**
| Field | Value |
|-------|-------|
| Platform | iOS |
| Min OS version | iOS 16.0+ |
| Excluded platforms | Android — separate PRD required. Web — out of scope this cycle. |

### 4. Feature specification

Table form. One row per feature. Every row carries an acceptance criterion.

| ID | Feature | Description | Acceptance criterion | Platform |
|----|---------|-------------|---------------------|----------|
| F1 | Set daily goal | User picks a habit name and target frequency | A habit row appears in the user's habit list within 1s of save; persists across app restarts | iOS, Android |
| F2 | Track streak | Increment streak when user logs habit before midnight local time | Streak +1 when log occurs in [00:00, 23:59] local; resets to 0 if 24h elapses without a log | iOS, Android |
| F3 | Daily reminder | Push notification at user-chosen time | Notification fires within ±60s of chosen time on both platforms; tappable to open app | iOS, Android |

**Acceptance criterion rules:**

- Verb is observable. Use "appears", "fires", "persists", "increments". Avoid "supports", "handles", "integrates".
- Includes a quantifier. Time bound, count, or boolean state. Never "fast" or "smooth".
- Names the platform if behavior differs.

### 5. User flows

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

Include a flow for every feature ID in §4. If two features share a screen, show them as separate flows — do not merge.

### 6. Key user interactions

Bulleted list of the core actions a user can take within this feature. Each item is a single sentence starting with "User can …". Derived from Q5 of the interview.

**Worked example:**
- User can add a new habit by entering a name and target frequency.
- User can delete an existing habit from the habit list.
- User can edit a habit's name or frequency after creation.

### 7. Error cases

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

### 8. Open questions

Numbered list. Each question carries: the question, who must answer it, and the deadline.

**Worked example:**
1. What timezone defines "midnight" for streak calculation — device local or user profile? **Owner:** PM. **Needed by:** RFC drafting.
2. Does notification permission denial block onboarding? **Owner:** Design. **Needed by:** Engineering kickoff.

### 9. Glossary

Define every domain term used in the PRD. One row per term.

| Term | Definition |
|------|-----------|
| Streak | An unbroken sequence of consecutive calendar days on which the user logged the habit at least once before midnight local time. |
| Habit | A user-defined recurring activity tracked by name and target frequency. |

## Quality gates before save

Before plan-pm saves the file, every gate below must pass:

| Gate | Rule |
|------|------|
| Platform | §3 names exactly one platform; excluded platforms are listed with reasons. |
| Out-of-scope | At least three explicit exclusions, including platforms. |
| Features | Every row has an acceptance criterion with a quantifier. |
| User flows | At least one ASCII flow per feature ID in §4; every flow shows the happy path. |
| Key user interactions | At least two "User can …" bullets. |
| Error cases | At least two rows; each has a concrete trigger and named UI behavior. |
| Open questions | Every entry has an owner and a deadline. |
| Glossary | Every domain term used in §1–§8 has an entry. |
