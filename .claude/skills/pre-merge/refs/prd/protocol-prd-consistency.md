---
name: prd-consistency
description: Gate Step 7 — a three-check, evidence-graded product-alignment pass (coverage · error-cases · scope). Each in-scope F-ID acceptance criterion and each PRD error_case is graded by evidence strength; scope-creep blocks. Emits a machine-readable per-item evidence grade that manual-test-plan (C22) reuses. Replaces /review's Functional mode.
---

# Step 7 — PRD-CONSISTENCY

A **three-check, evidence-graded** product-alignment pass against the PRD supplied
via `--prd` — **coverage · error-cases · scope**. Replaces `/review`'s Functional
mode with one adversarial diff-vs-spec check that grades every criterion by
*evidence strength* rather than a binary present/absent. No eval-set scripting.
Skipped (noted) when no `--prd` is supplied.

Stays a **static Wave-1 pass** — it checks test *existence*, not test results, so it
takes no new dependency (AC-PC2). A *failing* covering test already fails the gate via
its own component (`unit`/`integration`/`e2e`); on a clean run "has a covering test" =
verified. `prd-consistency` never re-verifies correctness (that is those components'
lane) — it stops silently greening implemented-but-untested product intent.

## Read the PRD via digest slice

Do not read the whole PRD. Run the `eval` digest slice for the acceptance criteria +
error cases:

```bash
G=.claude/scripts/scan-prd-digest.py; [ -f "$G" ] || G="$HOME/.claude/scripts/scan-prd-digest.py"
python3 "$G" "<prd-path>" --slice eval
```

Consume `features[]` (each with its F-ID + verbatim acceptance criterion) and
`error_cases[]` (id + trigger + specified behavior). *(The slice also carries
`edge_cases[]` — those are `manual-test-plan`'s (C22), not consumed here.)* Escape
hatch: assertions in a non-standard section the slice omits (digest
`unparsed_sections`) → read only that section's `prose_lines` range.

**Vacuous-pass guard:** `features: []` with a `--prd` supplied is never a pass — the
digest failed to parse the features section (e.g. prose instead of a table). Read the
PRD's features/acceptance section directly and run the checks from that; if it truly
defines no acceptance criteria, record the stage as `skipped` with
`reason: "no_criteria"` — do not emit a green check over zero criteria.

## Three checks

### 1 · Coverage — evidence-strength grading (AC-PC1)

For each in-scope F-ID's acceptance criterion, judge it against the diff by
**evidence strength** — is there a code path that satisfies it, and is there a test
that covers it?

| Evidence | Verdict | Finding |
|---|---|---|
| **met + tested** — a code path satisfies it **and** a covering test exists | pass | — |
| **met + untested** — code path only, no covering test | `medium` | `rule: acceptance-untested`, `category: functional` |
| **unmet** — no code path (and no test) satisfying it | `high` | `rule: acceptance-unmet`, `category: functional` |

Grading is **static** (AC-PC2): "has a covering test" means a test *exists* that
exercises the criterion — never that it passed (a failing test is its own
component's `blocker`). `source: pre-merge:prd-consistency`; message names the F-ID +
the criterion + the evidence gap.

### 2 · Error-cases — symmetric grading (AC-PC3/PC4)

Consume **every** `error_cases[]` entry from the eval slice — none is loaded-but-ignored
(AC-PC4). For each, judge whether the diff **handles** the specified failure behavior
and whether a test covers that handling:

| Evidence | Verdict | Finding |
|---|---|---|
| **handled + tested** — code implements the specified behavior **and** a test covers it | pass | — |
| **handled + untested** — behavior implemented, no covering test | `medium` | `rule: error-case-untested`, `category: error-handling` |
| **unhandled** — the diff does not implement the specified failure behavior | `high` | `rule: error-case-unhandled`, `category: error-handling` |

This closes the old hole where `error_cases[]` was loaded and dropped — now
`prd-consistency` verifies **both halves of product intent**: happy-path (acceptance
criteria) *and* error-path (specified failure behaviors). `source:
pre-merge:prd-consistency`; message names the error-case id + trigger.

### 3 · Scope — creep blocks (AC-PC5)

Does the diff ship any product surface — a feature, endpoint, or user-facing surface —
**not** traceable to an in-scope F-ID? Untraceable product surface → `high`
(`rule: out-of-scope`, `category: scope-creep`), naming the file/surface. Escalated
from `medium`: shipping unspecified product surface now **blocks**. Surface-scoped —
it does **not** fire on incidental non-product changes (refactors, config, test
scaffolding, dependency bumps that ship no new product surface). Resolution = spec it
into the PRD or remove it.

## Per-item evidence grades (machine artifact — consumed by manual-test-plan / C22)

Beyond the prose findings, this component emits a **machine-readable per-item evidence
grade** so `manual-test-plan` (C22) reuses the grades instead of re-walking the diff
(AC-MTP3/MTP8). Write it to **`.pre-merge/<ts>/prd-consistency-grades.json`** (the run
timestamp dir; a gitignored runtime artifact) alongside the check's result report:

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
  human-test tasks (same data, second use).

## Verdict

No mechanical stage — this is a single semantic pass; findings carry evidence (the
diff hunk or the covering test) per `../finding-schema.md`. **Stage verdict = worst
finding severity across all three checks** (AC-PC6) — a 3-check pass:
coverage · error-cases · scope. The grades artifact is written **regardless** of
verdict (it is emit-only context for C22, not part of the gate signal).
