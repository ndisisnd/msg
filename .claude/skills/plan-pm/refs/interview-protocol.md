---
name: Interview Protocol
description: Structured interview questions for plan-pm — one question at a time via AskUserQuestion
type: reference
---

# Interview Protocol

Run 5–8 questions one at a time using `AskUserQuestion`. Each question presents 3–4 multiple-choice options plus "Other" for free text. Capture every answer in conversation context before moving to the next question.

## Question order

Run in this sequence. Skip a question only if the answer was already given in the initial brief.

### Q1 — Platform (always first)

Ask which platforms this feature targets. This gates every subsequent scope decision.

Options (pick the most relevant 3–4):
- iOS only
- Android only
- iOS + Android (mobile parity)
- Web only
- Mobile (iOS + Android) + Web
- Other / TBD

### Q2 — Target user

Ask who the primary user is — and who the feature explicitly does NOT serve.

Options (tailor to the product context):
- New users (first 7 days)
- Returning / power users
- Specific role or segment (e.g., admins, creators, teams)
- All users equally
- Other

Follow up if the "out-of-scope user" is not obvious from the answer.

### Q3 — Core features

Ask which capabilities are must-have for this release. Present 3–4 concrete options derived from the brief, plus Other.

For each feature the user selects, mentally note that it will need an acceptance criterion and a size estimate in the PRD.

### Q4 — Out-of-scope

Ask what is explicitly excluded from this release. Offer at least one platform exclusion option and one feature-boundary option.

Options (tailor to context):
- Other platforms not selected in Q1
- A related feature the user might expect but is not in scope
- A backend or infrastructure concern
- A future-phase item
- Other

### Q5 — Open questions

Ask whether there are known unknowns or dependencies the PRD should flag. Present concrete examples from the brief as options.

Options (tailor to context):
- Data / analytics source to be confirmed
- Design or UX decision not yet made
- Third-party or API dependency unclear
- No open questions — PRD is self-contained
- Other

### Optional follow-up questions (Q6–Q8)

Use additional questions if any of the following are unclear after Q1–Q5:

- **Edge cases**: How should the feature behave at limits (empty state, max values, offline)?
- **Glossary**: Are there domain terms that need a precise definition in the PRD?
- **Constraints**: Any hard deadlines, legal, accessibility, or compliance requirements?

## Format rules

- One `AskUserQuestion` call per question. Never batch multiple questions in one call.
- Label each question with its topic in the `header` field (e.g., "Platform", "Target user").
- If the user selects "Other", treat the free-text input as a verbatim answer and continue.
- After all questions are answered, proceed to Step 3 (PRD numbering and scaffolding).
