# Acceptance Criteria — 2-plan-major-enhancement

1. SKILL.md contains no Step 2 block titled "First-layer fixes" or equivalent.
2. SKILL.md contains no reference to applying `Edit` to the PRD for terminology corrections, missing content, or `[PREFLIGHT GAP]` markers.
3. The step immediately following the pre-flight summary asks the user via `AskUserQuestion` whether to run plan-tune before continuing.
4. The plan-tune gate offers at least two options: one that emits a handoff message and stops, and one that proceeds without tune.
5. The handoff message for "Run plan-tune first" names the correct command: `/plan-tune features/prd-[n]/prd-[n].md` (or equivalent with the resolved PRD path).
6. All `Step X/6` progress strings in SKILL.md are updated to `Step X/5`.
7. Steps are numbered consecutively 1–5 with no gaps after the removal of the old Step 2.
8. The `## Step-by-step protocol` section in SKILL.md has exactly 5 step headings.
