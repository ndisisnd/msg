# Acceptance Criteria — 7.1-eng-build

## Core

1. SKILL.md exists at `.claude/skills/eng/SKILL.md` and declares `build` as one of its modes with a fully distinct protocol code path.
2. In `build` mode, eng writes code to derived file paths and emits a structured summary listing: files created, files modified, platform, concern, and execution table row ID.

## Input contract

3. Build mode input contract requires three fields: `mode=build`, `prd-path`, and `rows`. Eng hard-refuses invocation if any field is missing.
4. Eng does not accept file paths as input. File paths are derived from the codebase scan and execution table.
5. If any assigned execution table row has blank Execution steps, eng blocks and reports a hard failure immediately — before reading any other file or writing any code.

## PRD summary and approval gate

6. After input validation and before codebase discovery or code writing, eng reads the assigned PRD section and exec-table rows and emits a 3–4 line summary.
7. The summary covers: (1) what the feature is — one sentence naming the feature, user-facing purpose, and scope of assigned rows; (2) how to achieve this with code — 2–3 sentences on layers to be touched, main structural change, and key dependencies.
8. Eng presents the summary via `AskUserQuestion` with three options: Approve and proceed / Needs correction / I have questions. Eng never proceeds without an explicit "Approve and proceed". If "Needs correction" — rewrites once and re-asks. If "I have questions" — enters user interview then re-presents the summary.

## Codebase discovery

9. A codebase discovery step runs after the approval gate and before any code is written, scanning files relevant to the assigned execution concerns.
10. Eng derives the platform identifier from the execution table concern type; it does not accept platform as an input field.

## Coding standards

11. After platform derivation, eng invokes the coding standards skill and reads the result into context before writing any code.
12. Eng has no hardcoded platform knowledge, framework knowledge, or coding standards in SKILL.md.

## Output contract

13. After writing all code, eng emits a structured build summary: files created, files modified, platform, concern, and execution table row ID per item.
14. The build summary is the handoff artifact for review mode or a human reviewer — it is always emitted, even if no files were modified.

## Scope discipline

15. If any assigned execution table row is ambiguous or conflicts with the codebase scan, eng blocks, surfaces the specific ambiguity, and waits — it does not guess or proceed.
16. Eng does not add features, refactor out-of-scope code, or implement anything not specified by the assigned execution table rows.
17. SKILL.md declares allowed_tools including at minimum: Bash, Read, Write, Skill, and AskUserQuestion.

## plan-em invocation contract

18. SKILL.md documents the invocation contract for plan-em build mode: prompt must include `prd-path`, assigned exec-table row identifiers (Feature + Concern pairs), working branch name, and `mode=build`.
19. Eng reads the full execution table from the PRD and filters to its assigned rows before any other step. The Execution steps column for each row is treated as the authoritative code spec.

## TDD protocol

20. Eng processes "Tests" concern rows for each feature before any implementation rows (API contract, schema migration, client implementation) for that same feature.
21. For each "Tests" row, eng creates the test file at the derived path and writes syntactically valid test cases from the execution step assertions. No `TODO` placeholders are left in assertions.
22. For AI/LLM-facing behavior, eng writes eval assertions as structured objects (input, expected_shape, must_contain, must_not_contain) stored alongside tests — not as exact-string-match assertions.
23. Implementation code for a feature is only written after all test files for that feature are written.
24. Tests must be runnable once implementation is in place — they are not stubs.

## AHA.md learning log

25. Eng appends to `AHA.md` in the project root when any of the following occur: (a) codebase scan reveals a pattern not in the pulled coding standards; (b) an execution step cannot be implemented as written; (c) a cross-agent dependency is found that is not marked in the execution table; (d) a non-obvious implementation decision is made; (e) a bug is found and fixed during debug mode.
26. AHA entries follow the format: `### [YYYY-MM-DD] <Feature — Concern>: <Summary title>` with `**Issue/Learning**:` and `**Resolution**:` subsections.
27. Eng never overwrites existing AHA.md entries — the file is append-only.
28. The build summary references any AHA entries written during the run.

## Debug mode

29. Debug mode activates when: tests fail after implementation, implementation produces a compile or runtime error, or a cross-agent dependency is missing or blocked.
30. Debug mode runs a structured 5-step cycle per issue: Identify (record exact error) → Isolate (read failing test + implementation only) → Hypothesize (one specific root-cause sentence) → Fix (one targeted change within scope) → Verify (re-run test or build step). After each cycle, eng writes an AHA entry regardless of outcome.
31. Eng runs at most 3 debug cycles per issue. After 3 failed cycles, eng stops and escalates with: the failing assertion, 3 hypotheses tried, 3 fixes applied, and what information is needed to proceed.
32. Debug mode never refactors code outside the failing step's scope. Debug mode never applies more than one change per cycle.

## User interview

33. Eng uses `AskUserQuestion` proactively at two moments only: (a) when the user selects "I have questions" at the approval gate; (b) mid-protocol when a requirement is genuinely ambiguous and cannot be resolved from PRD, exec-table, or codebase scan.
34. Each interview question names the specific row or PRD section it concerns and offers 3–4 concrete options. Eng does not ask open-ended questions.
35. Eng asks at most 3 questions per invocation. If more than 3 ambiguities exist, eng surfaces them as a numbered list and asks which to prioritise first.
36. After the interview, eng incorporates the answers and continues the protocol from where it paused — it does not restart.
