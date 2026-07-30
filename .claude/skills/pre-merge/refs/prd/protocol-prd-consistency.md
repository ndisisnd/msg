---
name: prd-consistency
description: The prd-consistency component — a three-check, evidence-graded product-alignment pass (coverage · error-cases · scope). Advisory, never blocking: an LLM reading a diff can grade whether a criterion was attempted and tested, not whether it is correct. Emits a machine-readable per-item evidence grade that manual-test-plan (C22) turns into the human-test checklist.
---

# `prd-consistency` — the product-alignment pass (advisory)

A **three-check, evidence-graded** product-alignment pass against the PRD —
**coverage · error-cases · scope**. It grades every criterion by *evidence strength*
rather than a binary present/absent.

## When it runs — PRD auto-discovery, not a flag

The `prd` group's `active_when: prd` gate resolves from **PRD auto-discovery**: a
`features/prd-<N>-*/` directory matched to the current branch enables `prd-consistency`
and `manual-test-plan` by default. `--prd <path>` remains an **explicit override** —
for an unmatched branch name, an ambiguous match, or a deliberate second PRD. **No PRD
discovered and none supplied ⇒ the whole `prd` group is pruned**, exactly as a no-PRD
hotfix always behaved.

## It is advisory — and why that is the honest grade

An LLM reading a diff can answer *"is there evidence someone attempted this criterion,
and does a test exist for it?"* It **cannot certify that the behaviour is correct**.
Grading a hard block on that judgment blocks real work on a machine's misreading, which
is the failure mode this component is de-gated to avoid. So:

- Every finding here is **recorded, never blocking** (`criticality: advisory` in
  `../../../shared/refs/component-catalog.md`). It contributes context to the verdict,
  never a `fail`.
- The findings' real destination is the **human**: the per-item grades below feed
  `manual-test-plan`, which rates every untested/unmet item 🔴 HIGH, and that checklist
  is walked at merge's **staging human-test script**. The person who *can* judge
  correctness walks exactly what automation could not verify.
- Staging is fix-forward by design — an unmet item found at the walk-through becomes a
  fix commit, not a blocked merge — so the judgment lands where it can be acted on
  without a false block upstream.

Stays a **static pass** — it checks test *existence*, not test results, so it takes no
dependency on the test components. A *failing* covering test already fails the gate via
its own component (`unit`/`integration`/`e2e`); on a clean run "has a covering test" =
verified. It stops silently greening implemented-but-untested product intent.

## Read the PRD via digest slice

Do not read the whole PRD. Run the `eval` digest slice for the acceptance criteria +
error cases:

```bash
G=.claude/scripts/script-prd-digest.py; [ -f "$G" ] || G="$HOME/.claude/scripts/script-prd-digest.py"
python3 "$G" "<prd-path>" --slice eval
```

Consume `features[]` (each with its F-ID + verbatim acceptance criterion) and
`error_cases[]` (id + trigger + specified behavior). *(The slice also carries
`edge_cases[]` — those are `manual-test-plan`'s (C22), not consumed here.)* Escape
hatch: assertions in a non-standard section the slice omits (digest
`unparsed_sections`) → read only that section's `prose_lines` range.

**Vacuous-pass guard:** `features: []` with a PRD in play is never a pass — the digest
failed to parse the features section (e.g. prose instead of a table). Read the PRD's
features/acceptance section directly and run the checks from that; if it truly defines
no acceptance criteria, record the component as `skipped` with `reason: "no_criteria"`
— do not emit a green check over zero criteria.

## Three checks

### 1 · Coverage — evidence-strength grading

For each in-scope F-ID's acceptance criterion, judge it against the diff by
**evidence strength** — is there a code path that satisfies it, and is there a test
that covers it?

| Evidence | Finding |
|---|---|
| **met + tested** — a code path satisfies it **and** a covering test exists | — |
| **met + untested** — code path only, no covering test | `medium`, `rule: acceptance-untested`, `category: functional` |
| **unmet** — no code path (and no test) satisfying it | `high`, `rule: acceptance-unmet`, `category: functional` |

Grading is **static**: "has a covering test" means a test *exists* that exercises the
criterion — never that it passed. `source: pre-merge:prd-consistency`; message names
the F-ID + the criterion + the evidence gap.

### 2 · Error-cases — symmetric grading

Consume **every** `error_cases[]` entry from the eval slice — none is loaded-but-ignored.
For each, judge whether the diff **handles** the specified failure behavior and whether
a test covers that handling:

| Evidence | Finding |
|---|---|
| **handled + tested** — code implements the specified behavior **and** a test covers it | — |
| **handled + untested** — behavior implemented, no covering test | `medium`, `rule: error-case-untested`, `category: error-handling` |
| **unhandled** — the diff does not implement the specified failure behavior | `high`, `rule: error-case-unhandled`, `category: error-handling` |

This verifies **both halves of product intent**: happy-path (acceptance criteria) *and*
error-path (specified failure behaviors). `source: pre-merge:prd-consistency`; message
names the error-case id + trigger.

### 3 · Scope — creep is flagged, not blocked

Does the diff ship any product surface — a feature, endpoint, or user-facing surface —
**not** traceable to an in-scope F-ID? Untraceable product surface → `high`
(`rule: out-of-scope`, `category: scope-creep`), naming the file/surface — **advisory
like every other finding here**: whether a surface is genuinely out of scope or simply
under-specified in the PRD is a product judgment, so it routes to the same human
walk-through rather than blocking the PR. Surface-scoped — it does **not** fire on
incidental non-product changes (refactors, config, test scaffolding, dependency bumps
that ship no new product surface). Resolution = spec it into the PRD or remove it.

## Per-item evidence grades (machine artifact — consumed by manual-test-plan / C22)

Beyond the prose findings, this component emits a **machine-readable per-item evidence
grade** so `manual-test-plan` (C22) reuses the grades instead of re-walking the diff.
Write it to **`.pre-merge/<ts>/prd-consistency-grades.json`** (the run timestamp dir; a
gitignored runtime artifact) alongside the check's result report:

```json
{
  "check": "prd-consistency",
  "prd": "<prd-path>",
  "grades": [
    { "id": "F1", "kind": "acceptance", "evidence": "tested" },
    { "id": "F2", "kind": "acceptance", "evidence": "untested" },
    { "id": "F3", "kind": "acceptance", "evidence": "unmet" },
    { "id": "E1", "kind": "error_case", "evidence": "handled_tested" },
    { "id": "E2", "kind": "error_case", "evidence": "handled_untested" },
    { "id": "E5", "kind": "error_case", "evidence": "unhandled" }
  ]
}
```

- One entry per in-scope F-ID acceptance criterion (`kind: acceptance`) and per
  `error_cases[]` entry (`kind: error_case`) — every graded item appears, pass or
  finding, so the consumer sees the full picture, not just the failures.
- `evidence` is the exact tag driving the grade above:
  `acceptance` → `tested` | `untested` | `unmet`;
  `error_case` → `handled_tested` | `handled_untested` | `unhandled`.
- The mapping is 1:1 with the finding grades: `untested`/`unmet` and
  `handled_untested`/`unhandled` are precisely the criteria that produced a
  `medium`/`high` finding this run — C22 re-renders those same items as the HIGH
  human-test tasks (same data, second use). **This artifact is the point of the
  component**, so it is written on every path, whatever the verdict.

## Verdict

One semantic pass; findings carry evidence (the diff hunk or the covering test) per
`../finding-schema.md`. Component verdict = worst finding severity across the three
checks — but the component is `advisory`, so that verdict **never aborts the pipeline
and never flips the gate to `fail`** on its own. The grades artifact is written
regardless.
