---
name: Intake Grading Rubric
description: The three-dimension banded rubric intake stamps into every INTAKE.md row's grade cell — complexity, token-cost, sequencing — plus the single-turn / banded-only / no-fake-precision constraint.
type: reference
---

# Intake Grading Rubric (F1)

Every captured idea is graded on three banded dimensions, stored compactly in the
row's `grade` cell — e.g. `C:L T:$$ S:blocked-by-#4`.

## The hard constraint (never relaxed)

**Grading is a SINGLE-TURN LLM judgment at capture time. No analysis pass. No
codebase reads. Banded estimates and ranges ONLY — never a fake-precise number.**

- ✅ `C:L` · `T:$$` · `S:blocked-by-#4`
- ❌ `~1,240 LOC` · `3.5 engineer-days` · `12 files touched`

A grade is a triage signal to sequence the backlog and warn about oversize ideas —
it is not an estimate. If you catch yourself wanting to read files to grade, stop:
that judgment belongs to `plan-em`, downstream. Grade from the idea + goal + the
other rows already in `INTAKE.md`, and from `devkit/AHA.md` calibration when present.

## The three dimensions

| Dim | Cell | Scale | Bands |
|---|---|---|---|
| **Complexity** | `C:` | `S / M / L / XL` | `S` = single module, <~200 LOC · `M` = one platform, several modules, no migration · `L` = multi-module OR a migration · `XL` = cross-platform AND/OR migration + breaking surface |
| **Token cost** | `T:` | `$ / $$ / $$$` | derived from complexity + platform count: more platforms → more eng agents; more tickets → more pair reviews; migrations → a stricter gate. A **band**, not a total |
| **Sequencing** | `S:` | `now / next / later / blocked-by-#n` | position vs the other `INTAKE.md` rows + existing PRD `depends_on`/`affects` edges. `blocked-by-#n` cites an intake row `#` (or a `prd-<n>`). Feeds `plan-pm --roadmap`, which sequences from this graded backlog |

## Complexity drives the XL-split gate

An **`XL` complexity grade is actionable, not just descriptive.** It triggers the
split question at capture — "this grades XL — break it into smaller ideas?" — the
same muscle as hybrid-ask detection (`refs/protocol-intake.md`). This is the
front-door defence of the A5 commit caps: an XL idea that stays whole produces
oversize tickets downstream that blow the `<500`/`<300` LOC caps. Splitting at the
front door is cheaper than splitting at build time.

On accept → replace the one XL row with the split rows (each re-graded, typically
`M`/`L`). On decline → keep the single `XL` row (the downstream cap pressure is now
a known, recorded risk).

## Token-cost calibration

`T:` is a rough function of `C:` and platform count:

| Complexity | 1 platform | 2+ platforms |
|---|---|---|
| S | `$` | `$` |
| M | `$` | `$$` |
| L | `$$` | `$$$` |
| XL | `$$$` | `$$$` |

Migrations bump one band (`L`+migration on one platform → `$$$`). These are
defaults — adjust on obvious signals, but stay in bands.

## AHA calibration

When `devkit/AHA.md` exists, read it once before grading. A recurring learning
(e.g. "date features always need timezone-boundary handling") is a signal to grade
a superficially-`M` date feature as `L`. The self-healing loop (G5) keeps AHA
current; intake consuming it closes the calibration side of that loop.
