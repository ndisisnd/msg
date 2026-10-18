---
name: Intake Grading Rubric
description: The two-dimension banded rubric intake stamps into every INTAKE.md row's grade cell — complexity and sequencing — plus the plain-English band labels, the single-turn / banded-only rule, and the split threshold.
type: reference
---

# Intake Grading Rubric

Every idea gets a compact `grade` cell: `C:<band> S:<position>` — e.g. `C:5 S:blocked-by-#4`.

## The hard constraint

- Grade in a **single-turn judgment** at capture. No analysis pass.
- Ground the grade in the idea, the goal, the light context scan (`protocol-intake.md` § Pre-run) and `devkit/AHA.md`. Never read extra files just to grade — deep sizing is `plan-em`'s job.
- **Bands only.** ✅ `C:5` · `S:blocked-by-#4` — ❌ `~1,240 LOC` · `3.5 engineer-days` · `12 files touched`.
- A legacy cell may still carry a `T:<band>` token. Read it as noise and never write it. A re-grade drops it.

## The two dimensions

| Dim | Cell | Scale |
|---|---|---|
| **Complexity** | `C:` | `1 / 2 / 3 / 5 / 8 / 13` — Fibonacci **bands**, not quantities. `8` is not eight of anything. |
| **Sequencing** | `S:` | `now / next / later / blocked-by-#n` — a queue position vs the other open rows and existing PRD `depends_on`/`affects` edges. `blocked-by-#n` cites an intake row `#` (or a `prd-<n>`). |

## Complexity anchors — count moving parts, not footprint

A **moving part** is a distinct business rule · a module, screen, endpoint or job · an integration point (third-party API, queue, new table) · a platform · a migration or breaking-surface change. Count only the parts the idea itself names.

| `C:` | Anchor | Plain-English label (terminal output) |
|---|---|---|
| `1` | One moving part, one platform, no integration, no migration. | Complexity 1 — tiny: one rule or one small piece |
| `2` | Two or three moving parts, one platform, no new integration. | Complexity 2 — small: a couple of linked changes |
| `3` | Roughly 3–5 moving parts across a few units, one platform, no migration. | Complexity 3 — modest: one screen or flow with a few rules |
| `5` | Roughly 5–8 moving parts, or a new integration point, or a second platform. | Complexity 5 — medium: a few screens or one new service |
| `8` | Parts spanning platforms, or a migration, or a breaking surface. | Complexity 8 — large: crosses platforms or changes data shape |
| `13` | Cross-platform **and** migration/breaking, or really several ideas in one. | Complexity 13 — very large: several ideas in one |

Size scales with the count, not the footprint. One module with six promo-code rules (percentage, fixed, single-use, expiry, minimum basket, stacking) is `C:5`. A rename across many files is `C:1`.

| `S:` | Plain-English label (terminal output) |
|---|---|
| `now` | Sequencing now — ready to plan next |
| `next` | Sequencing next — after the current work |
| `later` | Sequencing later — not soon |
| `blocked-by-#n` | Sequencing blocked — waits for row #n |

**Labels are terminal-only.** Every grade shown to the user carries its label, e.g. `C:5 S:now` → "Complexity 5 — medium: a few screens or one new service · Sequencing now — ready to plan next". The `INTAKE.md` cell stays compact (`C:5 S:now`) because scripts parse it.

## The split threshold

`C:` ≥ `8` marks an idea as a split candidate. Intake decides the split itself with `principles.md` (no fixed question):

- Split when the idea has parts that can each ship and be reviewed alone. Re-grade each part (typically `3` or `5`).
- Keep it whole when the parts cannot ship apart. Say so in the summary, so the size is a known fact.
- Ask only when `principles.md` says the split is unclear.

## AHA calibration

When `devkit/AHA.md` exists, read it once before grading. A recurring learning that names a hidden moving part (e.g. "date features always need timezone handling") raises the band.
