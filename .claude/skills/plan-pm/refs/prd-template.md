---
name: PRD Template
description: Structured PRD format for plan-pm to populate
type: reference
---

# PRD Template

Populate every section. Do not delete a section — if a section does not apply, write `N/A` with a one-sentence reason. Every requirement in §5 must carry an acceptance criterion that an engineer or AI agent can verify without further conversation.

## File header

```markdown
---
name: prd-[n]
feature: <short feature name>
author: plan-pm
status: draft | approved
created: YYYY-MM-DD
---

# PRD-[n]: <Feature Name>
```

## Required sections

### 1. Problem statement

One paragraph. Name the user pain in concrete terms. Cite evidence (interview quote, support ticket volume, conversion drop, market signal). Do not write "users want X" without naming who and how you learned it.

**Worked example:**
> First-time users abandon the habit-tracking flow at the streak-setup step. 47% of new sign-ups in the last 30 days dropped off on this screen (analytics dashboard `funnels/onboarding`). User interviews (n=8) cited "I don't know what counts as a streak" as the top reason.

### 2. Target user

Two parts:

- **In scope**: Named user segment with at least one verifiable attribute (role, tenure, device, behavior).
- **Out of scope**: At least one user segment this feature does not serve. Forces explicit rejection.

**Worked example:**
- **In scope**: New users in their first 7 days post-signup, on iOS and Android, who have completed onboarding but have not logged a habit yet.
- **Out of scope**: Power users with 30+ days of streak history. Web-only users (no mobile app installed).

### 3. Out-of-scope

Bulleted list of features, platforms, or behaviors explicitly excluded. Each item has a one-line reason. Include at least platform exclusions and feature boundaries.

**Worked example:**
- Apple Watch and CarPlay — no design resource available this quarter.
- Social sharing of streaks — covered in PRD-4 (separate workstream).
- Backfill of historical habits — out of scope; users start from sign-up date.

### 4. Platform priorities

Table form. One row per platform. Priority and reason are required.

| Platform | Priority | Reason |
|----------|----------|--------|
| iOS | P0 | 62% of current users on iOS |
| Android | P0 | 35% of users; release parity required |
| Web | P1 | Read-only stats dashboard only |

### 5. Feature specification

Table form. One row per feature. Every row carries an acceptance criterion and a size estimate.

| ID | Feature | Description | Acceptance criterion | Size | Platform |
|----|---------|-------------|---------------------|------|----------|
| F1 | Set daily goal | User picks a habit name and target frequency | A habit row appears in the user's habit list within 1s of save; persists across app restarts | S | iOS, Android |
| F2 | Track streak | Increment streak when user logs habit before midnight local time | Streak +1 when log occurs in [00:00, 23:59] local; resets to 0 if 24h elapses without a log | M | iOS, Android |
| F3 | Daily reminder | Push notification at user-chosen time | Notification fires within ±60s of chosen time on both platforms; tappable to open app | M | iOS, Android |

**Acceptance criterion rules:**

- Verb is observable. Use "appears", "fires", "persists", "increments". Avoid "supports", "handles", "integrates".
- Includes a quantifier. Time bound, count, or boolean state. Never "fast" or "smooth".
- Names the platform if behavior differs.

**Size key:**

| Size | Effort |
|------|--------|
| XS | Hours |
| S | 1–2 days |
| M | 3–5 days |
| L | 1–2 weeks |
| XL | 2+ weeks |

Sizes are PM estimates. Engineering validates during RFC.

### 6. Open questions

Numbered list. Each question carries: the question, who must answer it, and the deadline.

**Worked example:**
1. What timezone defines "midnight" for streak calculation — device local or user profile? **Owner:** PM. **Needed by:** RFC drafting.
2. Does notification permission denial block onboarding? **Owner:** Design. **Needed by:** Engineering kickoff.

### 7. Glossary

Define every domain term used in the PRD. One row per term.

| Term | Definition |
|------|-----------|
| Streak | An unbroken sequence of consecutive calendar days on which the user logged the habit at least once before midnight local time. |
| Habit | A user-defined recurring activity tracked by name and target frequency. |

### 8. Appendices (optional)

- Interview transcripts
- Mockups or design links
- Competitive analysis
- Prior PRDs this supersedes

## Quality gates before save

Before plan-pm saves the file, every gate below must pass:

| Gate | Rule |
|------|------|
| Target user | Both in-scope and out-of-scope segments are named. |
| Out-of-scope | At least three explicit exclusions, including platforms. |
| Features | Every row has an acceptance criterion with a quantifier and a size (XS/S/M/L/XL). |
| Open questions | Every entry has an owner and a deadline. |
| Glossary | Every domain term used in §1–§6 has an entry. |
