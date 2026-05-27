# Acceptance Criteria — 7-dev-agent

## Core architecture

1. SKILL.md exists at `.claude/skills/dev/SKILL.md` with a defined persona, input contract, and a step-by-step protocol that branches on mode at the top level.
2. SKILL.md declares exactly two modes: `plan` and `build`, and the protocol has distinct code paths for each.
3. In `plan` mode, dev emits a proposed changes document listing files to create/modify and what each change does. No code is written.
4. In `build` mode, dev writes code to derived file paths and emits a structured summary listing: files created/modified, platform, concern, and execution table row ID.

## Input contract

5. SKILL.md input contract requires three fields: `mode`, `prd-path`, and `rows`. Dev hard-refuses invocation if any field is missing.
6. Dev does not accept file paths as input. File paths are derived from the codebase scan and execution table.
7. If any assigned execution table row has blank Execution steps, dev blocks and reports a hard failure immediately — before reading any other file or writing any code.

## Codebase discovery

8. In `build` mode, the protocol includes a codebase discovery step that runs before any code is written, scanning files relevant to the assigned execution concerns.
9. Dev derives the platform identifier from the execution table concern type; it does not accept platform as an input field.

## Coding standards

10. The coding standards step runs in both modes, after platform derivation and before any output is generated.
11. Dev has no hardcoded platform knowledge, framework knowledge, or coding standards in SKILL.md.

## Scope discipline

12. If any assigned execution table row is ambiguous or conflicts with the codebase scan, dev blocks, surfaces the specific ambiguity, and waits — it does not guess or proceed.
13. Dev does not add features, refactor out-of-scope code, or implement anything not specified by the assigned execution table rows.
14. SKILL.md declares allowed_tools including at minimum: Bash, Read, Write, Skill, and AskUserQuestion.

## plan-em invocation contract

15. SKILL.md documents the invocation contract for plan-em build mode: the prompt must include `prd-path`, assigned exec-table row identifiers (Feature + Concern pairs), working branch name, and `mode=build`.
16. Dev reads the full execution table from the PRD and filters to its assigned rows before any other step. The execution steps column for each row is treated as the authoritative code spec.

## TDD protocol

17. In `build` mode, dev processes "Tests" concern rows for each feature before any implementation rows (API contract, schema migration, client implementation) for that same feature.
18. For each "Tests" row, dev creates the test file at the derived path and writes syntactically valid test cases from the execution step assertions. No `TODO` placeholders are left in assertions.
19. For AI/LLM-facing behavior, dev writes eval assertions as structured objects (input, expected_shape, must_contain, must_not_contain) stored alongside tests — not as exact-string-match assertions.
20. Implementation code for a feature is only written after all test files for that feature are written.
21. Tests must be runnable once implementation is in place — they are not stubs.

## AHA.md learning log

22. In `build` mode, dev appends to `AHA.md` in the project root when any of the following occur: (a) codebase scan reveals a pattern not in the pulled coding standards; (b) an execution step cannot be implemented as written; (c) a cross-agent dependency is found that is not marked in the execution table; (d) a non-obvious implementation decision is made; (e) a bug is found and fixed during debug mode.
23. AHA entries follow the format: `### [YYYY-MM-DD] <Feature — Concern>: <Summary title>` with `**Issue/Learning**:` and `**Resolution**:` subsections.
24. Dev never overwrites existing AHA.md entries — the file is append-only.
25. The build summary emitted at the end of a run references any AHA entries written during that run.

## Debug mode

26. Debug mode activates when: tests fail after implementation, implementation produces a compile or runtime error, or a cross-agent dependency is missing or blocked.
27. Debug mode runs a structured 5-step cycle per issue: Identify (record exact error) → Isolate (read failing test + implementation, nothing else) → Hypothesize (one specific root cause sentence) → Fix (one targeted change within scope) → Verify (re-run test or build step).
28. After each debug cycle, regardless of outcome, dev writes an AHA entry for the bug and fix attempt.
29. Dev runs at most 3 debug cycles per issue. After 3 failed cycles, dev stops and escalates to the user with: the failing assertion, the 3 hypotheses tried, the 3 fixes applied, and what information is needed to proceed.
30. Debug mode never refactors code outside the failing step's scope. Debug mode never applies more than one change per cycle.
