---
name: roadmap Template
description: Template for roadmap/roadmap.md — the hand-authored phase sequencing of a project's PRDs. Scaffolded by /msg --init as roadmap/TEMPLATE-roadmap.md; the human copies it to roadmap/roadmap.md and maintains it by hand. Read by the /msg --gui Roadmap tab.
type: reference
---

# roadmap Template

`roadmap/roadmap.md` is the **hand-authored** phase plan for a project's PRDs —
which PRDs ship together, in what order, and what each wave unlocks. No skill
generates it: the human writes and maintains it, and msg only reads it.

`init.sh` writes the `## Template body` block below verbatim to
`<root>/roadmap/TEMPLATE-roadmap.md`, idempotently. Copy it to
`roadmap/roadmap.md` and fill it in when the project has enough PRDs to sequence.

## Who reads it

| Reader | What it does with the file |
|---|---|
| `/msg --gui` Roadmap tab | Renders the phases and their PRD bullets as a board |
| The human sequencing the work | Decides what to plan and build next |

## Format rules (keep these, or the GUI stops parsing it)

- One `## Phase <k> — <name>` heading per phase, numbered from `0`. Phase `0` is
  the informational "already shipped" anchor; it is not executed.
- Exactly one `Goal:` line directly under each phase heading — one sentence
  naming the outcome that wave unlocks.
- One `- prd-<n>-<slug> — <feature> — <state> — <one-line rationale>` bullet per
  PRD, under the phase it belongs to. `<state>` is free text (`shipped`, `in
  build`, `planned`, …). Sub-PRDs use the dotted id (`prd-2.1-<slug>`).
- A PRD appears in exactly one phase. A PRD that depends on another belongs in a
  later phase than the one it depends on.
- The optional `## Roadmap tune log` at the bottom records what changed on each
  edit, most recent entry first.

## Template body

```
---
name: roadmap
generated: <YYYY-MM-DD>
prd_count: <N>
phase_count: <K excluding Phase 0>
---

# Roadmap

## Phase 0 — Shipped
Goal: Already delivered — informational, not executed.
- prd-<n>-<slug> — <feature> — shipped — <note>

## Phase 1 — <name>
Goal: <one line — the outcome this wave unlocks>
- prd-<n>-<slug> — <feature> — <state> — <one-line placement rationale>
- ...

## Phase 2 — <name>
Goal: <one line>
- ...

## Roadmap tune log
### [<YYYY-MM-DD>] <summary of this edit>
- <phase move, added PRD, removed PRD, or renamed phase>
```
