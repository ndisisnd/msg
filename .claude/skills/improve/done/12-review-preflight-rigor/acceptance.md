# Acceptance criteria — 12-review-preflight-rigor

## Change 1 — Broaden eval-set discovery

1. Step 3 in `review/SKILL.md` documents four discovery sources in order: PRD sections, test files in diff, co-located tests for changed files, `schemas.json` from prior `agent-audit` runs, and conventional test directories.
2. When the PRD contains zero "Acceptance Criteria"/"Test Cases"/"Assertions" sections but a test file is present in the diff with at least one assertion, the resulting `eval_set[]` contains at least one entry sourced from the test file.
3. When the same assertion text appears in both the PRD and a discovered test file, `eval_set[]` contains exactly one entry for it (deduplicated by assertion text).
4. When no PRD, tests, or schemas are found, Step 3 still produces a non-empty `eval_set[]` from the diff (existing fallback preserved).

## Change 2 — Expand eval_set_source taxonomy

5. `refs/schema.md` lists `eval_set_source` as an enum of `prd`, `tests`, `schemas`, `diff`, `mixed`.
6. When all assertions come from a single source, `eval_set_source` equals that source label (not `mixed`).
7. When assertions come from two or more sources, `eval_set_source` equals `mixed`.
8. The Step 3 stdout line matches the pattern `Eval-set: <N> assertions (prd: <a>, tests: <b>, schemas: <c>, diff: <d>).` with non-negative integers summing to N.

## Change 3 — Allow runs on main

9. The "Hard refusals" line in `review/SKILL.md` no longer mentions `main`.
10. Step 1 in `review/SKILL.md` does not contain the phrase "hard-refuse" anywhere in its main-branch handling.
11. The Step 1 diff table contains a row whose Arg column reads `Bare invocation on main` and whose Command column resolves to `rtk git diff HEAD~1 HEAD`.
12. `/review <branch>` and `/review <PR#>` invocations from a working tree currently on `main` produce a non-empty diff (when the named branch/PR has changes) without any refusal.

## Change 4 — Collapse flags.md into FLAG-LIST.md

13. `refs/FLAG-LIST.md` contains a `## Domain detection` section listing every filesystem signal previously in `refs/flags.md` (e.g. `pubspec.yaml` → Flutter/Dart, `react` in package.json → React).
14. `refs/FLAG-LIST.md` contains a `## Test runner detection` section listing the runner priority table and the `test_runner` object shape previously in `refs/flags.md`.
15. `refs/flags.md` no longer exists in the repository.
16. `review/SKILL.md` Step 2 references `refs/FLAG-LIST.md` for both detection signals and the flag inventory, and contains no reference to `refs/flags.md`.
17. `review/SKILL.md` Step 4 states that every assembled flag must appear in the inventory loaded from `refs/FLAG-LIST.md`; flags not in the inventory are dropped.
18. `review/SKILL.md`'s References section contains exactly one line for `refs/FLAG-LIST.md` and zero lines for `refs/flags.md`.