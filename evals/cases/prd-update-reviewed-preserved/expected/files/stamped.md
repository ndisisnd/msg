---
name: prd-15-bulk-delete
feature: Bulk delete
summary: Lets a user select several tasks and delete them in one action.
deps: []
status: backlog
reviewed: yes
created: 2026-03-06
intake: #15
---

# PRD-15: Bulk delete

## 1. Product objective

- **Who** — users clearing out a long backlog of finished tasks.
- **What changes** — they can select many tasks and delete them in one action instead of one at a time.
- **Success signal** — the number of single-task deletes in a session falls.

## 2. Out-of-scope

- Bulk edit of any field other than deletion — separate workstream.

## 3. Features & acceptance criteria

| ID | Feature | Acceptance criterion | Dependencies |
|----|---------|----------------------|--------------|
| F1 | Delete selected | When the user confirms Delete on a multi-task selection, every selected task disappears from the list within 200ms and a single undo toast covers the whole batch. | — |

## 4. Error cases

| ID | Trigger | User-visible behavior |
|----|---------|----------------------|
| E1 | Delete confirmed with no task selected | Confirm button stays disabled; no request is sent. |

## 5. Open questions

| # | Question | Answer | Status |
|---|----------|--------|--------|
| 1 | How long does the batch undo window stay open? | Five seconds, matching single-task delete. | Addressed |

## 6. Feature execution table

_To be populated by plan-em — engineering breakdown of the §3 features._

## 7. Todos

_Populated by eng --plan — implementation tickets, grouped by feature._
