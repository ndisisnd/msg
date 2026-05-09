---
name: Interview Protocol
description: Structured interview questions for plan-pm — one question at a time via AskUserQuestion
type: reference
---

# Interview Protocol

Run questions one at a time using `AskUserQuestion`. Each question presents 3–4 multiple-choice options plus "Other" for free text. Capture every answer in conversation context before moving to the next question.

## Pre-interview: detect platform

Before asking Q1, check for `CLAUDE.md` and `ARCHITECTURE.md` in the project root. If either file names a default platform (e.g., "iOS app", "web service", "React Native"), store it as `platform`. Use it to pre-select the default option in Q1.

## Question order

Run in this sequence. Skip a question only if the answer was already given in the initial brief.

### Q1 — Platform (always first, single-select)

Ask which platform this feature targets. **Only one platform may be selected.** If a default was detected in the pre-interview step, present it as the first option.

Options (pick the most relevant 3–4, list detected default first if any):
- iOS only
- Android only
- Web only
- Mobile (iOS + Android) — parity release
- Mobile + Web
- Other / TBD

### Q2 — Feature selection mode

Ask how the user wants to define the feature set for this release.

Options:
- Recommend core features for me — PM generates 3–4 suggested features from the brief; user reviews and approves
- I'll list the features myself — user enumerates features directly
- Start from a design screenshot or doc — user provides a design artifact as the source of truth
- Other

If the user selects **"Recommend core features for me"**:
1. Derive 3–4 concrete feature candidates from the brief and platform context.
2. Present them inline (not as another `AskUserQuestion`) with a clear **[RECOMMENDED — please review]** flag.
3. Ask the user to confirm, remove, or add features before the feature table is built.

If the user selects **"I'll list the features myself"**:
- Prompt the user: "List your features one per line. Include a short description for each."

### Feature table (after Q2 is resolved)

Once the feature list is confirmed, generate a feature table using the format in `refs/feature-table-template.md`. Present the populated table inline for the user to review before moving to Q3.

### Q3 — Dependencies

Ask what this feature depends on. Present two categories:

**Fixed dependency (always present):**
- Design screenshot or design doc — ask whether one exists; if yes, ask the user to paste the path or describe it

**Non-fixed dependencies (generated from feature list):**
- Derive 2–3 candidate infrastructure or service dependencies implied by the confirmed features (e.g., push notification feature → notification service; web scraping feature → scraping service/API; auth feature → OAuth provider).
- Present them as checkboxes. User confirms which apply.
- Allow "Other" for dependencies not listed.

### Summary and confirmation

After Q3, emit a 3–4 line summary of the feature in this format:

```
Feature: <short name>
Platform: <platform from Q1>
Core features: <comma-separated list>
Dependencies: <comma-separated list, or "none">
```

Ask the user: **"Is this summary correct?"**

- If **yes**: proceed to Step 3 (PRD numbering and scaffolding).
- If **no**: ask the user what to change (free text via `AskUserQuestion`), apply the correction, and re-emit the summary. Repeat until confirmed.

## Format rules

- One `AskUserQuestion` call per question. Never batch multiple questions in one call.
- Label each question with its topic in the `header` field (e.g., "Platform", "Feature mode").
- If the user selects "Other", treat the free-text input as a verbatim answer and continue.
- The feature table and summary are emitted as inline text (not `AskUserQuestion`).
- After all questions are confirmed, proceed to Step 3 (PRD numbering and scaffolding).
