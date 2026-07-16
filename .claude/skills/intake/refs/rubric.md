---
name: Intake Grading Rubric
description: The three-dimension banded rubric intake stamps into every INTAKE.md row's grade cell — complexity, token-cost, sequencing — plus the single-turn / banded-only / no-fake-precision constraint.
type: reference
---

# Intake Grading Rubric (F1)

Every captured idea is graded on three banded dimensions, stored compactly in the
row's `grade` cell — e.g. `C:5 T:8 S:blocked-by-#4`.

## The hard constraint (never relaxed)

**Grading is a SINGLE-TURN LLM judgment at capture time. No analysis pass. No
codebase reads. Banded estimates and ranges ONLY — never a fake-precise number.**

- ✅ `C:5` · `T:8` · `S:blocked-by-#4`
- ❌ `~1,240 LOC` · `3.5 engineer-days` · `12 files touched`

A grade is a triage signal to sequence the backlog and warn about oversize ideas —
it is not an estimate. If you catch yourself wanting to read files to grade, stop:
that judgment belongs to `plan-em`, downstream. Grade from the idea + goal + the
other rows already in `INTAKE.md`, and from `devkit/AHA.md` calibration when present.

**`C:` and `T:` are Fibonacci bands, not quantities.** `8` is a band label that
happens to sort — it is not eight of anything, and it must never be read, written
or defended as an estimate. The gaps in the ladder are the point: they force a
choice between two neighbouring bands instead of inviting a split-the-difference
number. `C:8` says "this is in the second-largest band"; it never says "this is
twice `C:3`+`C:1`".

## The three dimensions

| Dim | Cell | Scale | Bands |
|---|---|---|---|
| **Complexity** | `C:` | `1 / 2 / 3 / 5 / 8 / 13` | counts **moving parts** — see the anchors below. `13` = max |
| **Token cost** | `T:` | `1 / 2 / 3 / 5 / 8 / 13` | derived from complexity + platform count: more platforms → more eng agents; more tickets → more pair reviews; migrations → a stricter gate. A **band**, not a total. `13` = max |
| **Sequencing** | `S:` | `now / next / later / blocked-by-#n` | position vs the other `INTAKE.md` rows + existing PRD `depends_on`/`affects` edges. `blocked-by-#n` cites an intake row `#` (or a `prd-<n>`). Feeds `plan-pm --roadmap`, which sequences from this graded backlog |

`S:` is **not** on the Fibonacci scale and never will be — it's a position in a
queue, not a size. Nothing about it changes when `C:`/`T:` change.

## Complexity anchors — count moving parts, not footprint

A **moving part** is any of: a distinct business-logic rule · an application-logic
unit (module, screen, endpoint, job) · an integration point (a third-party API, a
queue, a new table) · a platform · a migration or breaking-surface change.

Counting moving parts is not fake precision — you are counting the things the
**idea itself already names**, at capture time, from the idea and goal. You are not
predicting files, lines, or days. If the count needs a codebase read to settle,
you're over-thinking it: take the band the idea reads as and move on.

| `C:` | Anchor |
|---|---|
| `1` | **One moving part.** A single rule or a single unit, one platform, no integration, no migration. |
| `2` | **Two or three moving parts**, one platform, no new integration point. |
| `3` | **Several moving parts** (roughly 3–5) across a few units, one platform, no migration. |
| `5` | **Many moving parts** (roughly 5–8) — or any count plus a new integration point, or a second platform. |
| `8` | Moving parts **spanning platforms**, **or** a migration, **or** a breaking surface — the count is high enough that no one reviewer holds it all at once. |
| `13` | **Cross-platform AND migration/breaking surface**, or a moving-part count so high the idea is really several ideas wearing a coat. |

**Size scales with the count, not the footprint.** A single module carrying six
distinct business rules is `5`, not `1` — six rules are six things to get right,
six things to review, and six things to regress, however few files they live in.
Conversely, a change that touches many files to do one thing (a rename, a mechanical
sweep) is `1` or `2`: one moving part, wide blast radius, nothing to reason about.
Grade the reasoning, not the diff.

### Worked example — one module, many rules

> *"Add promo codes to checkout: percentage codes, fixed-amount codes, per-user
> single-use enforcement, expiry dates, minimum-basket thresholds, and stacking
> rules for when two codes apply."*

This lands in one module — `checkout/promo.ts` — and an old footprint-keyed rubric
would call it `S`/`1` on that basis alone. It isn't. Count the moving parts: six
distinct business rules (percentage, fixed, single-use, expiry, threshold,
stacking), each independently wrong-able, each needing its own regression. No new
platform, no integration point, no migration.

**`C:5`.** One module, six rules. The footprint is small and the reasoning is not.
This is the case the anchors exist to catch — **a single-module idea must be able to
grade above `1`**, or the rubric is just measuring file counts.

## Complexity drives the split gate

A **`C:` ≥ 8 complexity grade is actionable, not just descriptive.** It triggers the
split question at capture — "this grades 8 — break it into smaller ideas?" — the
same muscle as hybrid-ask detection (`refs/protocol-intake.md`).

**Why the gate exists: reviewability.** An idea that stays whole above `8` produces
tickets whose moving parts no single review holds at once — the reviewer either
rubber-stamps what they can't fully reason about, or the ticket sits. Splitting at
the front door is cheaper than splitting at build time, and the split is what makes
each piece reviewable. The gate is not defending a line count; it is defending the
point at which a human (or a pair-review agent) can still say "yes, all of this is
correct" in one pass.

On accept → replace the one `≥8` row with the split rows (each re-graded, typically
`3`/`5`). On decline → keep the single `≥8` row (the downstream reviewability
pressure is now a known, recorded risk).

**The gate fires at `≥ 8`, not at `13`.** Six bands spread across the range that
four bands used to cram into one, so firing on the top band alone would catch *less*
than the old top band did — same ideas, finer ruler, fewer catches. `≥ 8` restores
the catch rate. The threshold rests on an asymmetry: **a false fire costs one
declined question; a miss costs an oversize ticket nobody catches until build.**
That asymmetry holds only while decline stays cheap and available — if the gate ever
becomes a forced split rather than a question, `≥ 8` is the wrong threshold and this
must be revisited.

## Token-cost calibration

`T:` is a rough function of `C:` and platform count:

| Complexity | 1 platform | 2+ platforms |
|---|---|---|
| `1` | `1` | `2` |
| `2` | `2` | `3` |
| `3` | `3` | `5` |
| `5` | `5` | `8` |
| `8` | `8` | `13` |
| `13` | `13` | `13` |

Migrations bump one band up the ladder (`C:5` + migration on one platform → `T:8`).
`13` is the ceiling on both scales — it absorbs every bump. These are defaults —
adjust on obvious signals, but stay in bands.

## AHA calibration

When `devkit/AHA.md` exists, read it once before grading. A recurring learning
(e.g. "date features always need timezone-boundary handling") is a signal to grade
a superficially-`2` date feature as `3` or `5` — the learning names a moving part
the idea didn't. The self-healing loop (G5) keeps AHA current; intake consuming it
closes the calibration side of that loop.
