---
name: Interview Protocol
description: Structured interview questions for plan-pm — one question at a time via AskUserQuestion
type: reference
---

# Interview Protocol

Run questions one at a time using `AskUserQuestion`. Each question presents options plus "Other" for free text. Capture every answer in conversation context before moving to the next question.

## Pre-interview: detect platform

Run the following to extract the platform from `devkit/ARCHITECTURE.md`:

```bash
bash -c '[[ -f devkit/ARCHITECTURE.md ]] || exit 0; for e in "Expo:\bExpo\b" "Flutter:\bFlutter\b" "React Native:\bReact Native\b" "iOS:\biOS\b" "Android:\bAndroid\b" "Desktop:\b(Electron|Tauri)\b" "Web:\b(web app|web application|web frontend|web client|browser|SPA|PWA)\b" "Backend:\b(REST API|GraphQL|microservice|server-side|backend|API server)\b"; do grep -qiE "${e#*:}" devkit/ARCHITECTURE.md && echo "${e%%:*}"; done'
```

Store each line of output as a platform label. If the output is empty, set `platform` to `"TBD"` and record it as an open question in §7 of the PRD.

Do not ask the user about the platform.

## Question order

Run in this sequence. Skip a question only if the answer was already given in the initial brief.

### Q1 — Feature selection

Ask how the user wants to define the feature set for this release.

Options:
- Recommend core features for me
- I'll list the features myself

**In both modes**, the PM derives feature recommendations from the brief. These are core features only — stay inside the scope of the brief. Do not suggest adjacent opportunities.

Flow:
1. If "I'll list": prompt the user to list their features (free text). Capture their list.
2. Derive 3–5 concrete, non-overlapping feature candidates from the brief and platform context.
3. Combine the user's list (if any) and PM recommendations into a single table. Deduplicate entries with the same intent. Use this format:

| ID | Feature | Description | Source |
|----|---------|-------------|--------|
| F1 | | | User / PM |

4. Present the table inline. Then ask via `AskUserQuestion` (multiSelect: true): "Which of these features should be in scope for this release?" List each feature as a selectable option.
5. The user's selections are the confirmed feature list.

### Q2 — Out-of-scope

Ask what should be explicitly excluded from this release. Use `multiSelect: true`.

Non-targeted platforms (everything except `platform` from pre-flight) are always added to §2 (Out-of-scope) automatically — do not present them as Q2 options.

Derive 2–4 options from the confirmed feature list and brief. Common candidates:
- A feature or scope item mentioned in the brief but not included in the confirmed list
- Admin or backend tooling (user-facing surface only for this release)
- Third-party integrations not confirmed as dependencies
- A deferred edge case or error state (to be handled in a follow-up release)
- Other — I'll describe

### Q3 — Dependencies

Ask what this feature depends on. Derive 3–4 options from the confirmed feature list. Always include:
- Design doc or screenshot (if one exists, record its path)
- 2–3 candidate infrastructure or service dependencies implied by the features (e.g., push notification feature → notification service; auth feature → OAuth provider)
- Other

Use `multiSelect: true`. User confirms which apply.

### Q4 — Error cases

Derive as many concrete error cases as applicable to the confirmed features. Work through each feature systematically: invalid input, network failures, permission errors, empty states, authentication expiry, external service failures, rate limiting, race conditions. Keep generating until additional cases would be unlikely or low-impact enough to add noise rather than value. Present all of them via `AskUserQuestion` with `multiSelect: true`.

Rules for generating candidates:
- Each option is one concrete, triggerable condition — not a category. "Network timeout on save" not "network error."
- Derive from the specific confirmed features, not generic defaults.
- Include an "Other" option.

### Q5 — Key user interactions

Ask which core user actions this feature must support. Derive options from the confirmed feature list. Use `multiSelect: true`.

Options (tailor to context):
- User can add a new entry
- User can edit an existing entry
- User can delete an entry
- User can search or filter the list
- Other

After Q5 is answered, proceed to Step 4 (PRD numbering and scaffolding).

## Format rules

- One `AskUserQuestion` call per question. Never batch multiple questions in one call.
- Label each question with its topic in the `header` field (e.g., "Features", "Out-of-scope", "Dependencies", "Error cases", "Interactions").
- If the user selects "Other", treat the free-text input as a verbatim answer and continue.
- The feature table is emitted inline before Q1's selection step — it is not an `AskUserQuestion`.
- Q1, Q2, Q3, Q4, and Q5 all use `multiSelect: true`.
- After all questions are confirmed, proceed to Step 4 (PRD numbering and scaffolding).
