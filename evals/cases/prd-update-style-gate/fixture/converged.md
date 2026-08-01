---
name: prd-12-quiet-hours
feature: Quiet hours
summary: Lets users mute reminder notifications during a nightly window they choose.
deps: []
status: backlog
reviewed: yes
created: 2026-02-11
intake: #12
---

# PRD-12: Quiet hours

## 1. Product objective

- **Who** — users who get reminder notifications overnight and turn reminders off entirely to stop them.
- **What changes** — they can set a nightly window in which reminders are held back and delivered at the window's end.
- **Success signal** — reminder opt-outs fall while reminder delivery volume holds steady.

## 2. Out-of-scope

- Per-reminder overrides — the window applies to every reminder or none.

## 3. Features & acceptance criteria

| ID | Feature | Acceptance criterion | Dependencies |
|----|---------|----------------------|--------------|
| F1 | Set quiet hours | When the user saves a start and end time, the window appears on the Reminders screen within 200ms and reminders due inside it are delivered at the window's end instead. | — |

## 4. Error cases

| ID | Trigger | User-visible behavior |
|----|---------|----------------------|
| E1 | Start time equals end time | Inline field error: "Quiet hours must cover at least one minute." Save button disabled. |

## 5. Open questions

| # | Question | Answer | Status |
|---|----------|--------|--------|
| 1 | Does the window follow the user-profile timezone or the browser timezone when the two disagree? Owner: Staff PM · Due: before eng kickoff. | | Open |
| 2 | How are reminders held across the window delivered? Owner: Staff PM · Due: N/A. | As one digest at the window's end, confirmed with design. | Addressed |
| 3 | Auth constraint confirmed? | The quiet-hours window is stored per user account and only readable in a session authenticated as that user. | Addressed |

## 6. Feature execution table

_To be populated by plan-em — engineering breakdown of the §3 features._

## 7. Todos

_Populated by eng --plan — implementation tickets, grouped by feature._
