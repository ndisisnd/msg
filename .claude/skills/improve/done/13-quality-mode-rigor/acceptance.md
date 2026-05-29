# Acceptance Criteria — 13-quality-mode-rigor

## Change 1 — Inline Quality-mode rubric

1. `.claude/skills/review/refs/modes/quality.md` contains a `## Orchestrator rubric` section that explicitly lists the five concerns: dead code, duplication/DRY, readability, naming, complexity.
2. `.claude/skills/review/refs/modes/quality.md` contains a `## Sub-agent prompt amendment` section with a verbatim rubric clause that an orchestrator can append to a `/cook` sub-agent prompt.
3. The rubric clause in (2) instructs the sub-agent to tag findings with a `category` field corresponding to each of the five concerns.
4. `.claude/skills/review/SKILL.md` Step 6 mentions that Quality-mode sub-agents (and only Quality-mode sub-agents) receive the rubric amendment.
5. The "References" section of `.claude/skills/review/SKILL.md` notes that the Quality mode rubric extends `/cook`'s flag coverage with orchestrator-owned checks.
6. No new entries are added to `/cook`'s flag inventory (`/Users/andychan/Desktop/Drive/cook/FLAG-LIST.md` is unchanged).

## Change 2 — Scope-creep wiring

7. `.claude/skills/review/SKILL.md` Step 6 specifies that Quality-mode sub-agents receive `uncovered_changes[]` as an input alongside the diff.
8. The rubric amendment in `.claude/skills/review/refs/modes/quality.md` includes an explicit clause requiring a `warn`-severity finding with `category: "scope-creep"` for every entry in `uncovered_changes[]`.
9. The scope-creep clause requires `suggestion` to recommend either removing the change or extending the PRD.
10. `.claude/skills/review/refs/modes/quality.md` `## Execution` section documents `uncovered_changes[]` as an input.
11. `.claude/skills/review/refs/schema.md` is **not** modified solely for scope-creep wiring (findings ride on the existing `findings[]` array).

## Change 3 — Category dedup

12. `.claude/skills/review/refs/schema.md` sub-skill interface contract adds a required `category` field on every finding.
13. The `category` field documentation includes the recommended enum: `"contract"`, `"architecture"`, `"error-handling"`, `"debug"`, `"dead-code"`, `"duplication"`, `"readability"`, `"naming"`, `"complexity"`, `"scope-creep"`, `"security"`, `"performance"`, `"other"`.
14. `.claude/skills/review/refs/modes/quality.md` requires every Quality sub-agent emit `category` on every finding.
15. `.claude/skills/review/SKILL.md` Step 6 documents a post-collection dedup pass: findings sharing `(file, line, category)` are collapsed to one entry.
16. The dedup pass keeps the entry with the highest severity (`block` > `warn` > `info`).
17. The dedup pass concatenates distinct `source` values from collapsed findings into a comma-separated string on the surviving finding.
18. `.claude/skills/review/refs/schema.md` documents the orchestrator dedup pass as part of the orchestrator's contract.

## Negative / boundary assertions

19. No other review modes (Coverage, Functional, Security, Performance) are modified by this change.
20. No new files are created under `.claude/skills/review/refs/` beyond the existing structure (changes are edits to `SKILL.md`, `refs/modes/quality.md`, and `refs/schema.md` only).
21. No severity-reweighting logic is introduced (severity remains explicitly out of scope).
