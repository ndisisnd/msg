# Acceptance Criteria — 1-split-protocol-refs

1. `refs/plan/template-eng-plan.md` exists and contains the full content previously in `refs/template-eng-plan.md`.
2. `refs/plan/protocol-eng-agent.md` exists and contains only the Mode 1 (plan) section from the original `refs/protocol-eng-agent.md`.
3. `refs/build/protocol-exec.md` exists and contains the full content previously in `refs/protocol-exec.md`.
4. `refs/build/protocol-eng-agent.md` exists and contains only the Mode 2 (code) section from the original `refs/protocol-eng-agent.md`.
5. `refs/protocol-eng-agent.md` is deleted after both subfolder files are created.
6. `refs/template-eng-plan.md` is deleted after being moved to `refs/plan/`.
7. `refs/protocol-exec.md` is deleted after being moved to `refs/build/`.
8. `refs/principles.md` and `refs/template-exec-table.md` remain at `refs/` (unchanged, not moved).
9. SKILL.md Step 4 contains explicit mode detection logic: plan mode is detected when the PRD has no existing `## Engineering —` sections; build mode is detected when one or more such sections exist.
10. SKILL.md Step 4 uses the variable `$MODE` (or equivalent named identifier) to select `refs/plan/` or `refs/build/` when constructing agent prompts.
11. SKILL.md Step 4 agent prompt for plan mode references `refs/plan/template-eng-plan.md` instead of the old flat path.
12. SKILL.md Step 4 agent prompt for plan mode references `refs/plan/protocol-eng-agent.md` instead of the old flat path.
13. SKILL.md Step 4 agent prompt for build mode references `refs/build/protocol-eng-agent.md`.
14. SKILL.md Step 4 agent prompt for build mode references `refs/build/protocol-exec.md`.
15. The References section at the bottom of SKILL.md lists all six ref files at their new paths and annotates each with its mode (plan / build / shared).
