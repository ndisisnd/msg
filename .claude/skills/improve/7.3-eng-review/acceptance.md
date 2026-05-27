# Acceptance Criteria — 7.3-eng-review

## Core

1. `.claude/skills/eng/SKILL.md` routes the `--review` flag (Step 0) to `refs/review/protocol.md`, where the review-mode protocol is defined as a fully distinct code path. SKILL.md holds only the shared protocol spine and the router (which hard-fails unless exactly one of `--plan | --build | --review` is present); review-mode specifics live in the ref file.
2. In `review` mode, eng reads existing code, runs tests, audits assertions, scans for gaps and quality issues, and writes a JSON review file. Eng never writes or modifies code in this mode.

## Input contract

3. Review mode input contract requires three fields: `--review`, `prd-path`, and `rows`. Eng hard-refuses invocation if any field is missing.
4. Eng does not accept file paths as input. File paths are derived from the same codebase scan logic used in build mode.

## PRD summary and approval gate

5. After input validation and before any checks run, eng reads the assigned PRD section and exec-table rows and emits a 3–4 line summary.
6. The review-mode summary covers: (1) what code is being reviewed — feature name, assigned rows, file count; (2) how the review will proceed — naming all four checks that will run (test execution, assertion audit, gap scan, quality scan).
7. Eng presents the summary via `AskUserQuestion` with three options: Approve and proceed / Needs correction / I have questions. Eng never proceeds without an explicit "Approve and proceed". If "Needs correction" — rewrites once and re-asks. If "I have questions" — enters user interview then re-presents the summary.

## Platform and coding standards

8. Eng derives the platform identifier from the execution table concern type; it does not accept platform as an input field.
9. After platform derivation, eng invokes the coding standards skill and reads the result into context before the code quality scan. Eng has no hardcoded standards.

## Check 1 — Test execution

10. Eng runs the test suite scoped to files derived from the assigned rows. For each failing test, records: `test_file`, `test_name`, exact `error` message, `exec_table_row`, and the `exec_step` the test traces to.
11. Passing tests are recorded as counts only. Eng does not truncate or summarise error messages — they are recorded verbatim.

## Check 2 — Assertion audit

12. For every Execution step in the assigned rows that contains a verifiable assertion, eng checks that a real, passing test covers it. Gaps are classified: `critical` (no test at all), `major` (partial coverage), `minor` (no edge case coverage). Each gap records: `exec_table_row`, `exec_step`, `gap` description, `severity`.
13. An exec-table step with blank Execution steps content is flagged as a `critical` assertion gap — it is a finding, not a hard failure that stops the run.

## Check 3 — Adversarial gap scan

14. Eng proactively identifies cases not covered by any test: null/empty inputs, boundary values, concurrent access, error propagation, missing auth guards, unvalidated fields, missing rollback paths. Each gap records `gap`, `severity`, and the relevant file and concern.
15. Adversarial posture: eng assumes the code has bugs and works to prove it wrong. It does not stop at the first gap — it completes all four checks before writing output.

## Check 4 — Code quality scan

16. Eng reads each implementation file and flags: naming inconsistencies vs pulled coding standards, structural issues (duplication, excessive cyclomatic complexity, unclear intent), and concrete refactor suggestions.
17. Each suggestion records: `file`, `line_range`, `type` (refactor | naming | duplication | complexity | style), `severity`, `description`, and `suggested_change`. Suggestions are advisory and do not affect the verdict.

## JSON output and verdict

18. After all four checks, eng writes the review output to `features/prd-[n]/reviews/review-<YYYYMMDD-HHmmss>.json` following `refs/review/template-review-output.json`.
19. The JSON includes: `run_id`, `prd_path`, `rows[]`, `timestamp`, `verdict`, `blocker`, `test_results` (with `failures[]`), `assertion_gaps[]`, `suggestions[]`, and `summary` (with `verdict`, counts per severity, and `blocker`).
20. Verdict is `fail` if any test fails or any assertion gap is `critical`. Verdict is `pass` if all tests pass and no assertion gap is `critical` — suggestions are non-blocking.
21. After writing the file, eng emits a short inline summary: verdict, test failure count, assertion gap count, suggestion count, and the path to the JSON file.

## User interview

22. Eng uses `AskUserQuestion` proactively at two moments only: (a) when the user selects "I have questions" at the approval gate; (b) mid-review when scope is genuinely unclear and cannot be resolved from PRD, exec-table, or codebase scan.
23. Each interview question names the specific row or PRD section it concerns and offers 3–4 concrete options. Eng does not ask open-ended questions.
24. Eng asks at most 3 questions per invocation. If more than 3 ambiguities exist, eng surfaces them as a numbered list and asks which to prioritise first.
25. After the interview, eng incorporates the answers and continues the protocol from where it paused — it does not restart.
