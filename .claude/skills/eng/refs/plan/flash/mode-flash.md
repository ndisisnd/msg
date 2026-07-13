---
name: eng-plan-flash
description: eng --plan --flash — compressed proposed-changes template, no approval gate. Loaded instead of refs/plan/protocol.md + template-eng-plan.md when --flash is active.
---

# eng --plan --flash

Obeys `../../../../shared/refs/flash-floor.md`. Loaded **instead of** `refs/plan/protocol.md` and `refs/plan/template-eng-plan.md`. Cook is already **not** called on the comprehensive `--plan` path (T1.3), so flash's only distinct work is the compressed template + no gate.

## Compressed plan document — exactly 5 sections

1. **Summary** — one paragraph: what this plan builds, against which PRD + rows.
2. **Scope mapping** — table: each exec-table row → target files. Use the **exact identifiers** from the exec-table cell text and PRD feature IDs — the exact-identifier rule is **preserved verbatim** from comprehensive; no paraphrasing of file/symbol/F-ID names.
3. **Integration contracts** — the integration-contract section **verbatim** as comprehensive requires it (inputs/outputs/shared types across agents). Not compressed away.
4. **Execution steps** — one column of ordered steps per row (skeleton, not prose).
5. **Findings** — preflight gaps / open questions surfaced while planning.

## Todos — same pass

In the same pass, write the `## Todos — <Agent>` tickets under the `## Todos` umbrella (created by `plan-em`): one `### F<n>` block per owned F-ID, tickets keyed `F<n>-T<k>`. Same schema and **ticket-sizing caps** as comprehensive — `refs/plan/template-todo.md`, not compressed away. Empty features get the `_No discrete work for this feature._` sentinel.

## Gate

**None.** Print the plan document + a one-line summary and proceed. No approval `AskUserQuestion`. (Safety-floor pauses in `flash-floor.md` still fire.)

## Safety floor

Branch contract, scope enforcement, and frontmatter stamps unchanged.
