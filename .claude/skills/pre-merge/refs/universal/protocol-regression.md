---
name: regression
description: The regression component — run the accumulated regression suite, then spawn an ENG SUBAGENT to author this PRD's regression tests. Pre-merge runs and grades; it never authors the tests it grades (D9). Prior-test edits need a PRD-clause citation (D5).
---

# `regression` — the accumulated net (D9 + D5)

The regression suite is the "doesn't break production" net that compounds across
PRDs. Pre-merge **runs and grades**; a spawned eng subagent **authors** — the gate
stays adversarial to what it grades by never writing the tests it runs.

It is tail-pinned: it depends on every other universal/prd component, and it runs
(and re-runs) **post-sync** — the SYNC merge may have changed behavior.

## 1 — Run the accumulated suite

Execute every test under `tests/regression/prd-*/` using the detected unit/integration
runner (the suite is plain test files — run them the same way `unit` does). Parse
failures into findings per `../finding-schema.md` (`source: pre-merge:regression`,
`category: unit`, `severity: high` for a named failure). A regression failure means
this branch broke an assertion an earlier PRD locked in — treat it as `high`.

### Under a minified run

`regression`'s **accumulated** half is selection-capable. When the executor resolved a
minified run, this half runs `run_minified` at the size tier the executor computed;
the rule, the tiers, the fail-open fallbacks, and the recording contract live in
**one place** — `../executor.md` §3c. The component-specific reading of those tiers:

| Tier | Accumulated suite (`tests/regression/prd-*/`) |
|---|---|
| **S** | critical-tagged ∪ affected |
| **M** | critical-tagged ∪ affected **∪ the tests of 1-hop dependent modules** |
| **L**, or selection off / `run_minified: null` / a fail-open fallback | **full** — the whole accumulated tree |

M widens by exactly one dependency hop because accumulated regression tests are the
"a distant page broke" detectors: as breadth grows the residual risk moves from the
touched module to its immediate dependents.

## 2 — Author this PRD's regression tests (spawned eng subagent)

Spawn **one `eng` subagent** (via `Agent`) whose mandate is: from this PRD's
acceptance criteria (§3) + its todo tickets, author regression tests that lock in
the behavior this PRD ships, persisted to `tests/regression/prd-<n>/`. The subagent:

- Writes **test files only** — persisting to `tests/regression/prd-<n>/`. Source-code modification is **refused** (`out_of_scope_modify`), same as pre-merge itself.
- Derives assertions from the PRD acceptance criteria + tickets — the same done-set `prd-consistency` checks against.
- Returns the list of files it wrote/edited as structured output.
- **Tags at authoring time (born-tagged).** Any test it authors from a PRD acceptance criterion the PRD marks **P0/critical** carries the platform's critical marker (`policies.test_selection.critical_markers`, defaults in `../../../shared/refs/component-catalog.md`) **in the same authoring commit** — not a follow-up pass. New regression tests are therefore *born tagged*, which is the **primary** defense against tag drift; `/pre-merge --update-criticality` (`../protocol-update-criticality.md`) is the safety net for everything that drifts anyway. Tags live in test code, reviewed in the PR like any other line; the gate never writes one.
- **Commits its tests to the feature branch** once pre-merge has run them green (a `test(regression): lock in prd-<n> behavior` commit, cap-gated like any eng commit) — so the PR carries the suite. The commit is the subagent's (an eng write), not pre-merge's; pre-merge's sole direct write stays the sync-merge.

Then **pre-merge runs the newly-authored tests and grades them** — it does not
trust them unrun. New failures are findings exactly like the accumulated suite.

**This half is never selected away.** The newly authored tests **always run in full**,
at every tier, under every flag. Selection applies to the *accumulated* half only (§1)
— the tests that lock in the behavior this PRD is shipping are exactly the ones the
run cannot have measured yet, so there is no affected set that could justify pruning
them.

## 3 — Editing a stale prior-PRD regression test (D5)

When this PRD legitimately changes behavior an **older** regression test asserts,
the eng subagent MAY edit that prior test — but under a strict contract:

- Each edit is emitted as a **finding in the verdict JSON** (per `../finding-schema.md`) citing the PRD clause (F-ID / §3 criterion) that justifies the behavior change (`source: pre-merge:regression`, `category: unit`, `rule: regression-test-edited`, `severity: low` when a citation is present — it is a logged, sanctioned change).
- An edit with **no citable clause** is a `high` finding (`rule: regression-edit-uncited`) — the subagent changed a production guarantee with no spec authority. The human sees it in the issues file.

The subagent never deletes a prior regression test — only edits with citation.

## Compounding

Because each PRD's tests land in `tests/regression/prd-<n>/`, the suite grows every
ship. The accumulated run therefore gets stricter over time — the intended ratchet.
