---
name: fix-loop
description: The shared post-failure sequence pre-merge and merge run after a FAILED gate — plan the fixes (eng --plan), then build them (orchestrated eng --build) off the same report's issues file. pre-merge runs it automatically in the main conversation, up to 2 rounds, with named stop rules; merge runs it as two offers. The issues file's followUp.suggested_command is the fallback.
type: reference
---

# Fix loop — after a failed gate

Shared by `pre-merge` and `merge`. After a **FAILED** run, once the report
and its issues file are written (report-schema producer
obligations already met), the caller walks the run from *"the run found issues"*
to *"the fixes are planned and built"* off the same report. A clean run (verdict
`pass`/`pass_with_warnings`) runs nothing here — the sequence is fail-only.

The issues file is `report-prd-<N>-<K>.json` (no-PRD fallback
`report-<K>.json`) — the report's machine/issues form, colocated with the
human `.md` under the same `reports/` folder and stem (canonical-finding
`issues[]`, `followUp.status` contract; `K` = `max(existing K)+1` per
`report-schema.md`). The same `N`/`K` threads the fix plan and the fix build
below.

The two steps are the same for both callers:

- **Plan** — `eng --plan report=features/prd-<N>-<slug>/reports/report-prd-<N>-<K>.json`
  writes the fix-plan artifact `report-prd-<N>-<K>-fix-plan.md` (same stem, same
  `reports/` folder) per `.claude/skills/eng/refs/plan/fix-plan.md`.
- **Build** — orchestrated `eng --build report=<the same path>` per
  `.claude/skills/eng/refs/build/fix-build-orchestrated.md` — an Opus session that
  spawns one fix subagent per issue, routed by model on the complexity rubric.

Both steps run in the **main conversation**, never inside a gate subagent: a
subagent cannot ask the user anything, and the steps it starts can pause for a
human.

## pre-merge — automatic, up to 2 rounds

After a `fail` verdict is relayed (`gate-dispatch.md` § *Hand-back after a fail*),
the main conversation runs the fix rounds **with no question**:

1. **Plan** the fixes (above).
2. **Build** the fixes (above). eng's end-of-build "Commit?" question is
   pre-approved inside this loop.
3. **Run the gate again** — a fresh `/pre-merge` dispatch on the fixed branch.
   A pass ends the loop: pre-merge prints its verdict and "Next: /merge".

**Limit: 2 fix rounds.** After round 2, a gate that still fails hands to the user.

**Stop early and hand to the user** when any of these happens:

| Stop rule | Why |
|---|---|
| **No progress** — after a round, an issue from the previous round is still open (same `(category, file, rule)`) | another round would repeat the same fix |
| **A safety pause fires** — eng's database/data pause (`script-eng-db-touch.sh`) or a breaking-change pause | these pauses are never pre-approved; the user answers them |
| **A merge conflict** — the re-run's sync stops with `sync_conflict` | the user resolves it (`pre-merge/refs/sync.md`) |
| **A bug reaches eng's limit** — 3 fix attempts used, the bug is escalated | `eng/refs/build/protocol-build-debug.md` |

**The hand-off message** says, in plain words, why the loop stopped (the stop rule,
or "2 rounds used"), what is still open (the issue count and the report path), and
the next command — for example `eng --build report=<path>` to try again by hand, or
`/pre-merge` after the user resolves the pause or the conflict.

## merge — two offers

`merge` runs the same two steps as **offers**, after its own recovery offer.

### Ordering — merge's rollback offer runs first

This loop is entered **after** any caller-owned recovery offer, never instead of
one. On a failed **ship**, `merge` presents its **rollback / rollout-halt
offer first** (restore last-good for a `deploy` platform, halt the staged rollout
for a `submission` platform — always-ask, never auto, D12; `merge/refs/failed-ship.md`
§ *Failed-ship loop* step 1), and only then hands off here. The two are
complementary, not alternatives: rolling back mitigates the live blast radius;
this loop still fixes the broken commit forward. A rolled-back release therefore
**still runs Offer #1 → Offer #2** (AC-RB3). This ref owns only the fix steps; it
never rolls anything back.

### Offer #1 — plan the fixes

After the report + issues file are written, present via **AskUserQuestion**:

- **Question:** `<N> issue(s) found. Plan the fixes with eng?` (`<N>` = count of the issues file's `issues[]`).
- **Options:**
  - `Yes — plan the fixes` → the **Plan** step above
  - `No — stop here`

### Offer #2 — build the fixes

After the fix plan is written, present via **AskUserQuestion**:

- **Question:** `Fix plan ready (<M> tickets). Build the fixes now?` (`<M>` = fix-plan ticket count).
- **Options:**
  - `Yes — build the fixes` → the **Build** step above
  - `No — I'll build later`

### Autonomy contract

Under an autonomy contract (a caller running hands-off, e.g. plan-em's orchestrator), **both
offers are pre-approved** — proceed through Offer #1 → `eng --plan` → Offer #2 →
orchestrated `eng --build` without asking.

## Fallback + re-entry

- **Fallback.** The caller keeps `followUp.suggested_command` in the issues file
  as the deep-link fallback when the loop stops or an offer is declined — the user
  can resume straight from the issues file.
- **Re-entry.** After the fix build closes the loop (writes `followUp.status`
  `resolved` / `partially_resolved`), the fixed branch comes back through the same
  gate (`/pre-merge`, or `/merge`).

## References

- `report-prd-<N>-<K>.json` (no-PRD fallback `report-<K>.json`) — the issues file (canonical `issues[]`, `followUp` contract), colocated with the run's `.md` report
- `report-prd-<N>-<K>-fix-plan.md` — the fix-plan artifact (same stem)
- `.claude/skills/eng/refs/plan/fix-plan.md` — the Plan step: writes the fix plan
- `.claude/skills/eng/refs/build/fix-build-orchestrated.md` — the Build step: orchestrated per-issue fix build
- `report-schema.md`, `finding-schema.md` — sibling shared refs (run-report + path/numbering contract, finding shape)
