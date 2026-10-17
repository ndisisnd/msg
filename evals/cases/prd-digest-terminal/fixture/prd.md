---
name: prd-7.1-grace-window
feature: Grace window
summary: Lets streak-holders complete yesterday's missed day so their streak continues.
deps: []
status: backlog
reviewed: no
created: 2026-10-17
intake: #7.1
---

# PRD-7.1: Grace window

## 1. Product objective

- **Who** — active streak-holders who lose a streak to an accidental miss.
- **What changes** — they can mark yesterday's missed day complete, and their streak continues.

## 2. Out-of-scope

- Social sharing of streaks — separate workstream.

## 3. Features & acceptance criteria

| ID | Feature | Acceptance criterion | Dependencies |
|----|---------|----------------------|--------------|
| F1 | Grace complete | The missed day shows a filled ring on the Home screen after the user confirms the grace action. | — |
| F2 | Grace limit | AC1 The grace action is offered only for yesterday.<br>AC2 After the user uses it, the action is hidden until next week. | F1 |

## 4. Error and edge cases

| ID | Trigger | User-visible behavior |
|----|---------|----------------------|
| E1 · Empty and limits | Grace day already used this week (F2) | Inline banner: "You've used this week's grace day." |

## 5. Open questions

| # | Question | Answer | Status |
|---|----------|--------|--------|
| 1 | Does the grace day reset on Monday? | | Open |
| 2 | Who sees the banner? | Only the streak-holder. | Addressed |

## 6. Feature execution table

_To be populated by plan-em — engineering breakdown of the §3 features._

## 7. Todos

_Populated by eng --plan — implementation tickets, grouped by feature._
