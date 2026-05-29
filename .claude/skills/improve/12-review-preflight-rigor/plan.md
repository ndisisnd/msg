# Improvement Plan — 12-review-preflight-rigor

**Skill:** review
**Change type:** Bug fix + clarity (three independent corrections to preflight/fingerprint behavior)

## Problem

Three defects in `review`'s preflight pipeline (Steps 1–3 of [SKILL.md](../../review/SKILL.md)) cause it to miss inputs, refuse valid environments, and consult a non-canonical flag source:

1. **Step 3 eval-set bootstrap only reads the PRD.** Test files, schemas.json artifacts, and conventional test dirs near changed files are ignored — so assertions already encoded by the engineer (or by `agent-audit`) get re-derived from the diff, producing weaker and inconsistent eval-sets.
2. **Step 1 hard-refuses runs on `main`.** `review` is meant to be platform/workflow-agnostic, but the refusal forces users on trunk-based or solo workflows out of the skill entirely.
3. **Step 2 fingerprints against `refs/flags.md`.** That file is a hand-curated detection+mapping table that can drift from the actual `/cook` vocabulary. The authoritative inventory of valid flags is `refs/FLAG-LIST.md` (generated from `vocab/tag-vocabulary.json`). The right fix is to collapse the two files: move the filesystem-detection signals into `FLAG-LIST.md` as a new section, then delete `flags.md`. Single source of truth, no drift possible.

## Proposed changes

| # | What | How | Why necessary | Why ignorable | Rank |
|---|------|-----|---------------|---------------|------|
| 1 | Broaden Step 3 eval-set discovery beyond the PRD | Before falling back to diff-derived assertions, also: (a) extract assertions from test files in the diff (`*.test.*`, `*.spec.*`, `__tests__/`); (b) for each changed source file, look for a co-located test file even if not in the diff and extract its assertions; (c) read `schemas.json` from the PRD's `agent-audit` run dir if present; (d) scan conventional test dirs (`tests/`, `e2e/`, `integration/`) for files tagged to the PRD slug. Merge results into `eval_set[]`, deduplicate by assertion text. | Engineers already encode acceptance behavior in tests and schemas; ignoring them means review either re-invents weaker assertions or misses cases the diff doesn't make obvious. Especially important post-`agent-audit` where assertions are already graded. | Only if the project has no test infrastructure at all — in which case discovery is a cheap no-op and the diff-derived fallback still runs. | P1 |
| 2 | Expand `eval_set_source` taxonomy | Extend the enum to: `"prd"`, `"tests"`, `"schemas"`, `"diff"`, `"mixed"`. Emit the dominant source if all assertions come from one place; emit `"mixed"` otherwise. Update the Step 3 stdout line to: `Eval-set: <N> assertions (prd: <a>, tests: <b>, schemas: <c>, diff: <d>).` | Without source attribution the user can't tell whether review respected their hand-written tests or silently fell back to diff-guessing. | If only one source is ever populated, the breakdown is noise — but the cost of always emitting it is one line. | P2 |
| 3 | Remove `main`-branch hard-refusal; default to `HEAD~1` | In Step 1, drop the `if branch == main: refuse` check. When the bare `/review` form is invoked and the current branch is `main` (detected via `rtk git branch --show-current`), use `rtk git diff HEAD~1 HEAD` instead of `rtk git diff HEAD`. All other invocations (`/review <branch>`, `/review <PR#>`) work unchanged regardless of current branch. Update the "Hard refusals" line in SKILL.md to remove the main-branch clause. Update the Step 1 diff table to add a `Bare invocation on main` row. | `review` is workflow-agnostic; trunk-based and solo developers commit directly to main and need review on the last commit. The refusal is a relic that blocks valid use. | None — the change is strictly additive (existing flows unchanged). | P1 |
| 4 | Collapse `flags.md` into `FLAG-LIST.md`, then delete `flags.md` | (a) Prepend two new sections to `refs/FLAG-LIST.md`: a `## Domain detection` section porting the filesystem-signal table from `flags.md` (e.g. `pubspec.yaml` → Flutter/Dart), and a `## Test runner detection` section porting the runner-priority table + `test_runner` object shape. (b) Update SKILL.md Step 2 to read all detection signals and the flag inventory from `refs/FLAG-LIST.md` (single source). (c) Update SKILL.md Step 4 to assemble per-mode flags exclusively from the inventory loaded in Step 2 — any candidate flag absent from the inventory is silently dropped. (d) Delete `refs/flags.md`. (e) Update SKILL.md's References section: replace the `refs/flags.md` line with a single `refs/FLAG-LIST.md — domain & runner detection signals + authoritative `/cook` flag inventory` entry. | `flags.md` is hand-maintained and can drift from `/cook`'s actual vocabulary (`FLAG-LIST.md` is generated from `vocab/tag-vocabulary.json`). Splitting detection from inventory across two files invites drift; collapsing into one canonical file makes drift structurally impossible. | None — pure consolidation; no behavior change beyond what change #1–#3 already require. | P1 |

## Out of scope

- Regenerating `flags.md` from `vocab/tag-vocabulary.json` (separate skill/tooling concern).
- Changing `/cook`'s own flag-resolution behavior.
- Adding new review modes or assertions about the modes themselves.
- Rewriting `refs/schema.md` beyond the `eval_set_source` enum bump in change #2.