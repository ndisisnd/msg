---
name: prd-14-export-csv
feature: CSV export
summary: Lets a user download their task list as a CSV file.
deps: [prd-11-task-list]
status: complete
reviewed: yes
created: 2026-03-04
intake: #14
---

# PRD-14: CSV export

## 1. Product objective

- **Who** — users who keep a parallel copy of their tasks in a spreadsheet.
- **What changes** — they can download the current task list as a CSV in one click.
- **Success signal** — the manual copy-paste path stops being used, measured as exports per active user.

## 2. Out-of-scope

- Scheduled or recurring exports — one-off download only.

## 3. Features & acceptance criteria

| ID | Feature | Acceptance criterion | Dependencies |
|----|---------|----------------------|--------------|
| F1 | Download CSV | When the user selects Export, a `.csv` file containing every task currently in the list downloads within 2 seconds. | — |

## 4. Error cases

| ID | Trigger | User-visible behavior |
|----|---------|----------------------|
| E1 | Export requested on an empty list | Toast: "Nothing to export yet." No file downloaded. |

## 5. Open questions

| # | Question | Answer | Status |
|---|----------|--------|--------|
| 1 | Which columns does the CSV carry? | Title, status, due date, labels — confirmed with design. | Addressed |

## 6. Feature execution table

_To be populated by plan-em — engineering breakdown of the §3 features._

## 7. Todos

_Populated by eng --plan — implementation tickets, grouped by feature._
