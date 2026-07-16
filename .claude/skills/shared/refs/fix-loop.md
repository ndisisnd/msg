---
name: fix-loop
description: The shared post-failure offer sequence pre-merge and post-merge run after a FAILED gate — offer to plan the fixes (eng --plan), then offer to build them (orchestrated eng --build) off the same report's issues file. Autonomy-aware; the issues file's followUp.suggested_command is the decline fallback.
type: reference
---

# Fix loop — post-failure offer sequence

Shared by `pre-merge` and `post-merge`. After a **FAILED** run, once the report
and its issues file are written (report-schema producer
obligations already met), the caller runs this two-offer sequence to walk the
user from *"the run found issues"* to *"the fixes are planned and built"*
without leaving the report. A clean run (verdict `pass`/`pass_with_warnings`) runs
nothing here — the sequence is fail-only.

The issues file is `report-prd-<N>-<K>.json` (no-PRD fallback
`report-<K>.json`) — the report's machine/issues form, colocated with the
human `.md` under the same `reports/` folder and stem (canonical-finding
`issues[]`, `followUp.status` contract; `K` = `max(existing K)+1` per
`report-schema.md`). The same `N`/`K` threads the fix plan and the fix build
below.

## Offer #1 — plan the fixes

After the report + issues file are written, present via **AskUserQuestion**:

- **Question:** `<N> issue(s) found. Plan the fixes with eng?` (`<N>` = count of the issues file's `issues[]`).
- **Options:**
  - `Yes — plan the fixes` → invoke `eng --plan report=features/prd-<N>-<slug>/reports/report-prd-<N>-<K>.json`
  - `No — stop here`

`eng --plan report=<path>` writes the fix-plan artifact
`report-prd-<N>-<K>-fix-plan.md` (same stem, colocated in the same `reports/`
folder as the issues file it fixes) per
`.claude/skills/eng/refs/plan/report-fix.md`.

## Offer #2 — build the fixes

After the fix plan is written, present via **AskUserQuestion**:

- **Question:** `Fix plan ready (<M> tickets). Build the fixes now?` (`<M>` = fix-plan ticket count).
- **Options:**
  - `Yes — build the fixes` → invoke orchestrated `eng --build report=features/prd-<N>-<slug>/reports/report-prd-<N>-<K>.json`
  - `No — I'll build later`

The orchestrated build runs per
`.claude/skills/eng/refs/build/report-fix-orchestrated.md` — an Opus
session that spawns one fix subagent per issue, routed by model on the complexity
rubric.

## Autonomy contract

Under an autonomy contract (a roadmap orchestrator running hands-off), **both
offers are pre-approved** — proceed through Offer #1 → `eng --plan` → Offer #2 →
orchestrated `eng --build` without asking.

## Decline fallback + re-entry

- **Decline fallback.** The caller keeps `followUp.suggested_command` in the
  issues file as the deep-link fallback if the user declines either offer —
  the user can resume the loop later straight from the issues file.
- **Re-entry.** After the fix build closes the loop (writes `followUp.status`
  `resolved` / `partially_resolved`), the user **re-runs the gate**
  (`/pre-merge` or `/post-merge`) from where they exited — the fixed branch comes
  back through the same gate.

## References

- `report-prd-<N>-<K>.json` (no-PRD fallback `report-<K>.json`) — the issues file (canonical `issues[]`, `followUp` contract), colocated with the run's `.md` report
- `report-prd-<N>-<K>-fix-plan.md` — the fix-plan artifact (same stem)
- `.claude/skills/eng/refs/plan/report-fix.md` — Offer #1 target: writes the fix plan
- `.claude/skills/eng/refs/build/report-fix-orchestrated.md` — Offer #2 target: orchestrated per-issue fix build
- `report-schema.md`, `finding-schema.md` — sibling shared refs (run-report + path/numbering contract, finding shape)
