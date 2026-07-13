---
name: plan-em-flash
description: plan-em --flash — one generalist eng agent (≤2 platforms), one merged gate, preflight-lite via the plan slice, synthesis from agent returns only. Loaded instead of protocol-em.md when --flash is active.
---

# plan-em --flash

Obeys `../../../shared/refs/flash-floor.md`. Loaded **instead of** `refs/protocol-em.md`. The win is **1 generalist agent + one merged gate + no synthesis re-read** — inputs are already sliced.

## Preflight-lite

Read the digest **`plan` slice** (`scan-prd-digest.py --slice plan`) + ARCHITECTURE + GLOSSARY only. Keep preflight to ≤10 lines of gaps. Multi-PRD scan is **frontmatter-only** (don't open sibling PRD bodies).

## Roster

- **≤2 platforms → exactly 1 generalist eng agent** covering all rows.
- **>2 platforms → per-platform roster preserved** (comprehensive fan-out).

## Gates — roster approval only

**Roster approval is the single gate** (≤1 `AskUserQuestion` on the happy path). The certification precondition is **not** a question — flash still runs it (safety floor, never collapsed): if `product-tuned: yes` with no unresolved Criticals, it's already certified and skipped; otherwise run `plan-tune --product --flash` inline before the plan wave (and `plan-tune --eng --flash` before the build wave). Relationship confirmation is gone — flash consumes the certified graph silently and asks only on a genuine conflict (I3), which is rare enough not to count against the happy-path gate budget.

## Synthesis — from agent returns only

Synthesize the engineering sections from the **agent returns**, with **0 PRD/synth-slice reads at synthesis** (comprehensive reads the `synth` slice; flash goes further and reads nothing). Write the `## Engineering — <agent>` sections + exec table directly. The exec table carries the **Todos** column (always present); create the `## Todos` umbrella once and each `eng --plan` agent writes its `## Todos — <agent>` tickets in the same pass (schema in `eng/refs/plan/template-todo.md`).

## Skipped vs comprehensive

AHA.md writeback · the full-PRD synthesis re-read.

## Safety floor — unchanged

Exec table, branch convention (`feat/prd-<n>-*`), and the **breaking-change pause** are unchanged (`flash-floor.md`). The breaking-change and DB-touch pauses still fire in flash.
