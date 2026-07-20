---
name: manual-test-plan
description: Gate component 18 (prd group, advisory, EMIT-ONLY) — generate a significance-rated human-test checklist mapping every in-scope acceptance criterion, error_case, and edge_case to a plain-language do-X → see-Y step. Reuses prd-consistency's (C11) per-item evidence grades for the automation-gap term; never blocks the PR. Generated once at pre-merge; rendered by both human gates (C20/R2, post-merge --staging).
---

# Component 18 — MANUAL-TEST-PLAN (prd group, emit-only)

Gives pre-merge post-merge's **walk-the-list** affordance: a human-testable checklist
mapping the PRD's product intent to plain-language `do X → see Y` steps, each carrying
a **significance rating**, generated **once** at pre-merge and rendered by both human
gates. It is `advisory` and **EMIT-ONLY — it never blocks the PR and never changes the
verdict** (AC-MTP1). It runs only with a `--prd` (the whole `prd` group is skipped on a
no-PRD hotfix). `depends_on: [prd-consistency]` — it **reuses** that component's per-item
evidence grades rather than re-walking the diff (AC-MTP8).

## Read the PRD via digest slice

Do not read the whole PRD. Run the `eval` slice — it carries all three item sources:

```bash
G=.claude/scripts/scan-prd-digest.py; [ -f "$G" ] || G="$HOME/.claude/scripts/scan-prd-digest.py"
python3 "$G" "<prd-path>" --slice eval
```

Consume `features[]` (each F-ID + acceptance criterion), `error_cases[]` (id + trigger
+ specified behavior), and `edge_cases[]` (id + scenario + expected behavior). Every
in-scope item across all three sources becomes one checklist row (AC-MTP2).

## Read prd-consistency's per-item evidence grades (the automation-gap input)

`prd-consistency` (C11) writes a machine artifact this component consumes — do **not**
re-derive it:

```
.pre-merge/<ts>/prd-consistency-grades.json   # { grades: [ {id, kind, evidence}, … ] }
```

Each `grades[]` entry tags an acceptance criterion or error_case with its evidence:
`tested` | `untested` | `unmet` (acceptance) · `handled_tested` | `handled_untested` |
`unhandled` (error_case). This is the **automation-gap** signal — what automation could
or could not verify — reused verbatim (AC-MTP3/MTP8).

## Significance = user_impact × automation_gap

Each checklist item's rating is the product of two axes:

**automation_gap** — reused from C11's grade for that item (no diff re-walk):

| C11 evidence | automation_gap |
|---|---|
| acceptance `tested` · error_case `handled_tested` | **low** — automation covers it |
| acceptance `untested` / `unmet` | **high** — automation could not verify it |
| error_case `handled_untested` / `unhandled` | **high** — automation could not verify it |
| `edge_case` (C11 does not grade these) | **high** — no automation grade exists, so treat as unverified |

**user_impact** — from the PRD: the feature/flow's **priority** + the **core-flow
(critical) tag** (D29's critical-tag on the canonical e2e flows). A criterion on a
core/critical flow or a high-priority feature = **high**; otherwise **low**.

**Rating** (the product — automation_gap is the dominant axis so the HIGH tier equals
exactly C11's untested/unmet set, per AC-MTP4):

| automation_gap | user_impact | significance |
|---|---|---|
| **high** | high or low | 🔴 **HIGH** — automation could not verify this; a human must |
| low | high | 🟡 **MEDIUM** — automation covers it, but it is a core flow — spot-check |
| low | low | 🟢 **LOW** — automation covers it and it is non-core |

The 🔴 HIGH set is precisely C11's `acceptance-untested` / `error-case-untested` /
`unmet` / `unhandled` items (plus ungraded edge_cases) re-rendered as human tasks —
the same data, second use (AC-MTP4). Order/group the list by significance, **HIGH
first**; within a tier, order by user_impact (core flows first).

## Each item — a plain-language step

Reuse `post-merge/refs/human-test-script.md`'s **plain-language style**: each row is an
**action + the expected observation** in everyday language a non-technical person can
follow ("add a task with an empty title and press save — you see the inline error
'Title is required' and the task is not added"), not jargon ("exercise the F1 validation
path"). Point steps at the pokeable preview/app, not internal test names.

**Anti-fabrication (inherited from `human-test-script.md`).** Never invent a step for
behavior the PRD did not specify. If an item yields no concrete, observable
verification step from its acceptance criterion / trigger / behavior text, **flag it as
such** (`step: null`, `note: "no concrete verification step in the PRD"`) — never
fabricate one (AC-MTP2).

## Outputs — report section AND machine artifact (emit-only)

Write the checklist to **both** sinks (AC-MTP6); neither touches the verdict:

1. **Run report `## How to verify`** — the section (`../../shared/refs/report-schema.md`)
   is upgraded from prose to a **structured, significance-rated list**: grouped by
   rating (🔴 HIGH → 🟡 MEDIUM → 🟢 LOW), each row showing the item id, the plain-language
   step, and its rating. Best-effort write (a failed report write never fails the run).
2. **Machine artifact** — `.pre-merge/<ts>/manual-test-plan.json`, the structured list
   the downstream human gates consume (C20/R2 renders it as the preview-approval
   checklist; post-merge `--staging` consumes it instead of re-deriving from prose —
   both wired in P6, not here):

```json
{
  "check": "manual-test-plan",
  "prd": "<prd-path>",
  "generated_at": "<ISO-8601>",
  "degraded": false,
  "items": [
    { "id": "F3", "kind": "acceptance", "significance": "high",
      "user_impact": "high", "automation_gap": "high",
      "step": "Delete a task, then click Undo within 5s — the task returns to its original position.",
      "note": null },
    { "id": "E5", "kind": "error_case", "significance": "high",
      "user_impact": "high", "automation_gap": "high",
      "step": "Edit the same task in two tabs, save the stale one — you see 'This task changed in another tab.'",
      "note": null },
    { "id": "F1", "kind": "acceptance", "significance": "medium",
      "user_impact": "high", "automation_gap": "low",
      "step": "Add a task — it appears at the top of the list immediately.", "note": null }
  ]
}
```

Each item carries its `significance` + both axes (`user_impact`, `automation_gap`) so
the render sites can re-sort/filter without recomputing. `kind` ∈
`acceptance` | `error_case` | `edge_case`.

## Degrade path — C11 absent or errored (AC-MTP8)

If `prd-consistency-grades.json` is **absent** or unreadable (C11 didn't run, or
errored), do **not** fabricate automation grades. Degrade to a **priority-only** rated
list: rank each item by `user_impact` alone (core-flow/priority → higher), set
`automation_gap: "unknown"`, and stamp `degraded: true` + a one-line note in the report
and artifact ("prd-consistency grades unavailable — rated by PRD priority only"). The
list still emits; it is never blocked or omitted.

## Never blocks (emit-only invariant)

`manual-test-plan` contributes **no** blocker/high/medium finding to the gate verdict —
its result report is always `pass` (or `skipped` when no `--prd`), and the checklist is
context, not a gate signal. Nothing in this component can flip a `pass` to a `fail`
(AC-MTP1). The executor's fail-fast never considers it (its `criticality: advisory`).
