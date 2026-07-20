---
name: prd-consistency
description: Gate Step 7 — one spec-match pass. Every F-ID's acceptance criteria demonstrably met by the diff, nothing out-of-scope shipped. Replaces /review's Functional mode.
---

# Step 7 — PRD-CONSISTENCY

A single spec-match pass against the PRD supplied via `--prd`. Replaces `/review`'s
Functional mode with one adversarial diff-vs-spec check — no eval-set scripting, no
separate Coverage mode. Skipped (noted) when no `--prd` is supplied.

## Read the PRD via digest slice

Do not read the whole PRD. Run the `eval` digest slice for the acceptance criteria +
error cases:

```bash
G=.claude/scripts/scan-prd-digest.py; [ -f "$G" ] || G="$HOME/.claude/scripts/scan-prd-digest.py"
python3 "$G" "<prd-path>" --slice eval
```

Consume `features[]` (each with its F-ID + verbatim acceptance criterion) and
`error_cases[]`. Escape hatch: assertions in a non-standard section the slice omits
(digest `unparsed_sections`) → read only that section's `prose_lines` range.

**Vacuous-pass guard:** `features: []` with a `--prd` supplied is never a pass — the
digest failed to parse the features section (e.g. prose instead of a table). Read the
PRD's features/acceptance section directly and run the checks from that; if it truly
defines no acceptance criteria, record the stage as `skipped` with
`reason: "no_criteria"` — do not emit a green check over zero criteria.

## Two checks

1. **Coverage** — for each in-scope F-ID, is its acceptance criterion **demonstrably met by the diff** (a code path or a test that satisfies it exists in this branch)? An unmet or unverifiable criterion → `high` finding (`rule: acceptance-unmet`, `source: pre-merge:prd-consistency`, `category: functional`), message naming the F-ID and the criterion.
2. **Scope** — does the diff ship anything **not** traceable to an in-scope F-ID (a feature, endpoint, or surface the PRD doesn't cover)? Out-of-scope shipped code → `medium` finding (`rule: out-of-scope`, `category: scope-creep`), naming the file/surface.

No mechanical stage — this is a single semantic pass; findings carry evidence (the
diff hunk or the covering test) per `../finding-schema.md`. Stage verdict = worst
finding severity.
