---
name: prd-9-grace-window
feature: Grace window
summary: Lets streak-holders retroactively complete a missed day within a grace window.
module: habits
affects: []
depends_on: []
platform: mobile
status: product
product-tuned: no
eng-tuned: no
reviewed: no
created: 2026-08-01
---

# PRD-9: Grace window

## 1. Product objective

- **Who** — active streak-holders who lose a streak to an accidental miss.
- **What changes** — they can retroactively complete a missed day.
- **Success signal** — 30-day retention among streak-holders rises.

## 2. Out-of-scope

- Social sharing of streaks — separate workstream.

## 3. Features & acceptance criteria

| ID | Feature | Acceptance criterion | Dependencies |
|----|---------|----------------------|--------------|
| F1 | Grace complete | The missed day shows a filled ring on the Home screen within 200ms of confirming the grace action. | — |

## 4. Error cases

| ID | Trigger | User-visible behavior |
|----|---------|----------------------|
| E1 | Grace day already used this week | Inline banner: "You've used this week's grace day." |

## 5. Open questions

| # | Question | Answer | Status |
|---|----------|--------|--------|

## 6. Feature execution table

_To be populated by plan-em — engineering breakdown of the §3 features._

## 7. Plan review findings

_Populated by plan-review (/plan-review) — audit findings table._

## 8. Todos

_Populated by eng --plan — implementation tickets, grouped by feature._
