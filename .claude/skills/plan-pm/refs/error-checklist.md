---
name: Error Checklist
description: The standard list of failure types plan-pm checks every §3 feature against when it drafts §4 Error and edge cases — Tier 1 always, Tier 2 only when the trigger fits — plus the two drafting rules that keep the table short.
type: reference
---

# Error Checklist

Check **every §3 feature** against this list when you draft §4. The list is a check, not a quota: it makes sure no common failure is forgotten, and most types will not apply to a given feature.

The **Type** name is the label you write in the §4 ID cell (`E1 · Network`).

## Tier 1 — check every feature

| Type | Ask of the feature |
|---|---|
| Invalid input | Can the user enter or submit something empty, too long, or wrongly formatted? |
| Network | Can the network or the server fail while this feature runs? |
| Slow response | Does the user wait on something that can be slow? What do they see meanwhile? |
| Double submit | Can the user tap twice, retry, or resend, and create a duplicate? |
| Interrupted | Can the action stop halfway (app closed, connection lost) and leave a half-done state? |
| Empty and limits | What does the user see the first time, with no data, or at a maximum? |
| Permission | Can a permission or a sign-in be missing, denied, or expired? |
| User mistake | Can the user undo it? Is any action irreversible, and is it confirmed first? |

## Tier 2 — check only when the trigger fits

| Type | Check it when the feature… |
|---|---|
| External service | uses a third-party service |
| Conflict and sync | works across devices, is shared between users, or works offline |
| Missing item | opens an item from a link or a notification (the item can be gone) |
| Time and date | depends on days, deadlines, streaks, or schedules |
| Rate limit | lets the user send, post, or request repeatedly |
| Data limits | uploads files or handles large data |
| Abuse and safety | shows user content or lets users contact each other |
| Privacy | could show one user's data to another |
| Money | charges, refunds, or pays out |
| Version mismatch | changes stored data or an API that old app versions still use |
| Device limits | uses the camera, location, storage, or a new OS feature |
| Language and accessibility | adds new text or layout — only when the project supports more than one language or has an accessibility rule |

## Two drafting rules

1. **Write a row only when the error is likely and user-visible.** Skip a type that cannot happen in this feature. Skip it silently — never write an `N/A` row.
2. **Merge rows that share one user-visible behaviour.** One row may name several triggers (for example "network timeout or server error on save"). Give it the type that fits best.

Expect about 2–5 rows per feature. Every §4 row is read by pre-merge's PRD-consistency check and by the manual test plan, so extra rows cost run time downstream.
