# Acceptance Criteria — 15-review-test-split

## Change 1 — Strip test execution from review Coverage mode

1. `refs/modes/coverage.md` contains no reference to `test_runner.command`, `test_runner.coverage_output`, or any Bash execution of a test runner.
2. Coverage mode detects whether a sibling test file (`.test.*`, `.spec.*`, or matching `__tests__/` path) exists for each changed source file in the diff.
3. Coverage mode checks whether eval_set assertions are textually referenced in the detected test files (static read only — no execution).
4. Coverage mode emits `gaps[]` entries for (a) changed files with no sibling test file, and (b) eval_set assertions with no apparent test file reference.
5. Coverage mode verdict is `warn` for gaps, `pass` when all changed files have sibling test files and all eval_set assertions are referenced.

## Change 2 — Remove `test_runner` from review Step 2 fingerprint

6. `SKILL.md` Step 2 does not produce a `test_runner` output and does not reference `shared/refs/tooling-detection.md#test-runner-detection`.
7. `refs/schema.md` Fingerprint object does not contain a `test_runner` field.
8. No downstream step in `SKILL.md` or any mode ref reads `test_runner` from the fingerprint.

## Change 3 — Reclassify executable assertions in Functional mode as n/a

9. `refs/modes/functional.md` Step 3 does not reference `/tmp/`, `review-functional-`, ephemeral script generation, or Bash execution.
10. For `executable`-class assertions, the mode emits a finding with `applicable: true`, `severity: n/a`, and `note` containing "run /test for verification".
11. `intent` and `negative` assertion class protocols in Step 3 are unchanged from the current `refs/modes/functional.md`.
12. The tautology check (Step 0), assertion classification (Step 1), and full file reads (Step 2) are retained verbatim.
13. When every applicable assertion in the diff is reclassified `n/a` (all-executable, all-deferred case), the mode verdict is `warn` with note `"all assertions deferred to /test"`. The verdict must NOT be `pass` — an empty applicable tally is not evidence of success.

## Change 4 — Emit eval_set handoff artifact from review

14. review `SKILL.md` writes the resolved `eval_set[]` (with `eval_set_source` and per-assertion `class` once Functional classification has run) to `<run_dir>/eval_set.json` after Step 3 / before Functional mode emits its findings.
15. The path to `eval_set.json` appears in review's top-level run output under a new field `eval_set_path`, so the user (or pre-merge) can pass it to `/test`.
16. Functional mode findings with `severity: n/a` and the `"run /test for verification"` note include the `eval_set_path` value in their `note` field (e.g. `"run /test --eval-set <path> for verification"`) so the handoff is discoverable from the report alone.

## Change 5 — Create `/test` skill SKILL.md

17. `.claude/skills/test/SKILL.md` exists and is a runnable skill (has YAML frontmatter with `name`, `description`, `allowed_tools`).
18. SKILL.md defines a trigger on `/test` with optional flags `--base <ref>`, `--prd <path>`, and `--eval-set <path>`. When `--eval-set` is supplied, `/test` consumes the provided eval_set verbatim and skips re-bootstrapping from PRD/diff. When absent, it bootstraps from `--prd` (and/or diff) using the same protocol review uses.
19. SKILL.md defines three execution buckets in order: unit/integration, e2e, functional assertions.
20. SKILL.md references `../shared/refs/tooling-detection.md` for tooling fingerprinting (not its own detection logic).
21. SKILL.md includes a human gate step (show test matrix, get approval) before fan-out.
22. SKILL.md emits a JSON findings document conforming to `refs/schema.md`.
23. SKILL.md explicitly refuses to modify source code.

## Change 6 — Create `/test` mode refs

24. `.claude/skills/test/refs/modes/unit.md` exists and covers: runner invocation via `test_runner.command`, output parsing, coverage report reading, and verdict logic (block if test fails, warn if coverage gaps, pass otherwise).
25. `.claude/skills/test/refs/modes/e2e.md` exists and covers: `e2e_runner.command` invocation, spec scoping to diff, output parsing, and verdict logic.
26. `.claude/skills/test/refs/modes/functional.md` exists and contains the full executable assertion execution path extracted from review's `refs/modes/functional.md` Step 3: ephemeral script generation, execution, exit-code verdict, and evidence (`file` + `line`) requirements.
27. `test/refs/modes/functional.md` also handles `intent` and `negative` assertion classes (identical to review's Functional mode) so the `/test` skill can evaluate all assertion types.

## Change 7 — Create `/test` output schema

28. `.claude/skills/test/refs/schema.md` exists and defines a finding shape with fields: `id`, `severity` (`blocker` | `high` | `medium` | `low`), `category`, `evidence` (`file`, `line`, `tool`, `snippet`), `repro` (shell command string).
29. Top-level verdict field is `fail` | `pass_with_warnings` | `pass` | `refused`, consistent with pre-merge's verdict enum.
30. Schema is self-contained — does not import or reference pre-merge's `finding-schema.md`.

## Change 8 — Update pre-merge to delegate to `/test` (P1)

31. `pre-merge-plan.md` Step 5 fan-out does not spawn independent integration or e2e subagents; it invokes `/test` instead.
32. pre-merge passes `--base`, `--prd`, and `--eval-set <path>` (sourced from review's `eval_set_path` when review ran upstream in the same pipeline) plus diff context when invoking `/test`.
33. pre-merge consumes `/test`'s JSON output and merges findings into its own aggregation step, preserving `id`, `severity`, `category`, `evidence`, and `repro` fields.
34. pre-merge retains its own direct bucket subagents for build, security, and bundle.
