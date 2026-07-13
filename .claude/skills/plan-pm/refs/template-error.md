---
name: Error Case Template
description: Format, rules, and examples for §6 Error cases in plan-pm PRDs
type: reference
---

# Error Case Template

## Format

Table form. One row per error state. Every row requires a user-visible message or behavior.

| ID | Trigger | User-visible behavior |
|----|---------|----------------------|

## Rules

- Trigger is a concrete condition, not a category. "Network timeout on save" not "network error."
- User-visible behavior names the exact UI element (toast, banner, inline error) and the copy.
- Never "gracefully handle" — name the specific behavior.
- At least two rows. Drafted autonomously per feature (invalid input, network/permission failures, empty states, auth expiry, external-service failure, rate limits, race conditions, timezone/date boundaries).

## Example

| ID | Trigger | User-visible behavior |
|----|---------|----------------------|
| E1 | Network timeout on habit save | Toast: "Couldn't save. Check your connection and try again." Save button re-enabled. |
| E2 | Notification permission denied | Inline banner: "Enable notifications in Settings to get reminders." No crash. |
| E3 | Empty habit name on submit | Inline field error: "Name is required." Form not submitted. |
