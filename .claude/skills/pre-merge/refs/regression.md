---
name: regression
description: Gate Step 4 — run the accumulated regression suite, then spawn an ENG SUBAGENT to author this PRD's regression tests. Pre-merge runs and grades; it never authors the tests it grades (D9). Prior-test edits need a PRD-clause citation (D5).
---

# Step 4 — REGRESSION (D9 + D5)

The regression suite is the "doesn't break production" net that compounds across
PRDs. Pre-merge **runs and grades**; a spawned eng subagent **authors** — the gate
stays adversarial to what it grades by never writing the tests it runs.

Runs (and re-runs) **post-sync** — Step 1's merge may have changed behavior.

## 1 — Run the accumulated suite

Execute every test under `tests/regression/prd-*/` using the detected unit/integration
runner (the suite is plain test files — run them the same way as Step 3). Parse
failures into findings per `refs/finding-schema.md` (`source: pre-merge:regression`,
`category: unit`, `severity: high` for a named failure). A regression failure means
this branch broke an assertion an earlier PRD locked in — treat it as `high`.

## 2 — Author this PRD's regression tests (spawned eng subagent)

Spawn **one `eng` subagent** (via `Agent`) whose mandate is: from this PRD's
acceptance criteria (§6) + its todo tickets, author regression tests that lock in
the behavior this PRD ships, persisted to `tests/regression/prd-<n>/`. The subagent:

- Writes **test files only** — persisting to `tests/regression/prd-<n>/`. Source-code modification is **refused** (`out_of_scope_modify`), same as pre-merge itself.
- Derives assertions from the PRD acceptance criteria + tickets — the same done-set the PRD-consistency stage (Step 7) checks against.
- Returns the list of files it wrote/edited as structured output.
- **Commits its tests to the feature branch** once pre-merge has run them green (a `test(regression): lock in prd-<n> behavior` commit, cap-gated like any eng commit) — so the Step 9 PR carries the suite. The commit is the subagent's (an eng write), not pre-merge's; pre-merge's sole direct write stays the sync-merge.

Then **pre-merge runs the newly-authored tests and grades them** — it does not
trust them unrun. New failures are findings exactly like the accumulated suite.

## 3 — Editing a stale prior-PRD regression test (D5)

When this PRD legitimately changes behavior an **older** regression test asserts,
the eng subagent MAY edit that prior test — but under a strict contract:

- Each edit is emitted as a **finding in the verdict JSON** citing the PRD clause (F-ID / §6 criterion) that justifies the behavior change (`source: pre-merge:regression`, `category: unit`, `rule: regression-test-edited`, `severity: low` when a citation is present — it is a logged, sanctioned change).
- An edit with **no citable clause** is a `high` finding (`rule: regression-edit-uncited`) — the subagent changed a production guarantee with no spec authority. The human sees it in the fail-ticket.

The subagent never deletes a prior regression test — only edits with citation.

## Compounding

Because each PRD's tests land in `tests/regression/prd-<n>/`, the suite grows every
ship. Step 4's "run the accumulated suite" therefore gets stricter over time — the
intended ratchet.
