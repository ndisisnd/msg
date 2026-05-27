# Acceptance Criteria — 7.2-eng-plan

## Core

1. `.claude/skills/eng/SKILL.md` routes the `--plan` flag (Step 0) to `refs/plan/protocol.md`, where the plan-mode protocol is defined as a fully distinct code path. SKILL.md holds only the shared protocol spine and the router (which hard-fails unless exactly one of `--plan | --build | --review` is present); plan-mode specifics — summary content and proposed-changes output contract — live in the ref file.
2. In `plan` mode, eng emits a proposed changes document listing files to create or modify and what each change does. No code is written or modified.

## Input contract

3. Plan mode input contract requires three fields: `--plan`, `prd-path`, and `rows`. Eng hard-refuses invocation if any field is missing.
4. Eng does not accept file paths as input. File paths are derived from the codebase scan and execution table.

## PRD summary and approval gate

5. After input validation and before the codebase scan or any output, eng reads the assigned PRD section and exec-table rows and emits a 3–4 line summary.
6. The summary covers: (1) what the feature is — one sentence naming the feature, user-facing purpose, and scope of assigned rows; (2) how to achieve this with code — 2–3 sentences on layers to be touched, main structural change, and key dependencies.
7. Eng presents the summary via `AskUserQuestion` with three options: Approve and proceed / Needs correction / I have questions. Eng never proceeds without an explicit "Approve and proceed". If "Needs correction" — rewrites once and re-asks. If "I have questions" — enters user interview then re-presents the summary.

## Codebase scan and platform

8. A codebase scan step runs after the approval gate to determine which files exist (would be modified) and which do not (would be created). Relevance is matched by concern type.
9. Eng derives the platform identifier from the execution table concern type; it does not accept platform as an input field.
10. After platform derivation, eng invokes the coding standards skill and reads the result before producing the proposed changes document. Eng has no hardcoded standards.

## Output contract

11. The proposed changes document covers every assigned exec-table row and lists, per row: (a) files to create — path, purpose, what it will contain; (b) files to modify — path, affected section, what changes will be made; (c) any execution step that cannot be satisfied — flagged explicitly as a gap.
12. No code is written in plan mode. The document contains descriptions only.

## Scope discipline

13. Eng proposes changes only for what the assigned exec-table rows specify. It does not propose additional refactors or unrelated file touches.
14. If a row is ambiguous, eng surfaces it as a named gap in the proposed changes document rather than resolving by assumption.
15. SKILL.md declares allowed_tools including at minimum: Bash, Read, Write, Skill, and AskUserQuestion.

## User interview

16. Eng uses `AskUserQuestion` proactively at two moments only: (a) when the user selects "I have questions" at the approval gate; (b) mid-protocol when a requirement is genuinely ambiguous and cannot be resolved from PRD, exec-table, or codebase scan.
17. Each interview question names the specific row or PRD section it concerns and offers 3–4 concrete options. Eng does not ask open-ended questions.
18. Eng asks at most 3 questions per invocation. If more than 3 ambiguities exist, eng surfaces them as a numbered list and asks which to prioritise first.
19. After the interview, eng incorporates the answers and continues the protocol from where it paused — it does not restart.
