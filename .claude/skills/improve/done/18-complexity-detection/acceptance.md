# Acceptance Criteria — 18-complexity-detection

## Change 1 — Tier definitions in plan-template.md

1. `plan-template.md` contains a **Tier** section listing Simple, Standard, and Complex tiers.
2. Each tier declares which plan sections are required, optional, or forbidden.
3. Simple tier explicitly forbids persona and workflow diagram.
4. Simple tier caps refs at 0–1 and forbids folder nesting beyond flat.
5. Complex tier requires persona, workflow diagram, at least 3 refs, and allows sub-skills and 2-level nesting.

## Change 2 — Complexity inference in interview.md

6. After the last interview question, `interview.md` specifies a Tier Inference step.
7. The inference step uses a decision table mapping workflow step count, persona signal, and sub-skill signal to a tier.
8. The inferred tier is emitted as `[TIER: Simple/Standard/Complex]` with a one-line rationale.
9. If the user states a tier explicitly in their initial prompt, the inference step is skipped.

## Change 3 — Human checkpoint in SKILL.md

10. SKILL.md protocol includes a step after the interview phase that surfaces the inferred tier and rationale to the user.
11. The checkpoint asks the user to confirm or override before plan generation begins.
12. An override input from the user replaces the inferred tier for all subsequent plan output.

## Change 4 — Calibration rule in principles.md

13. `principles.md` contains a **Calibration** section with a rule that constrains output shape to the confirmed tier.
14. The rule explicitly prohibits adding sections, ref files, or folder nesting beyond the tier's declared shape.

## Change 5 — Per-dimension override table in plan-template.md

15. `plan-template.md` contains an override table listing persona, workflow-diagram, ref-count, sub-skills, and folder-nesting dimensions.
16. Each row shows the default value per tier and an override column.
17. The override column is populated only when a strong signal contradicts the base tier (not by default).

## Backward compatibility

18. Existing skills built from prior agent-plan outputs are unaffected — no changes to how agent-build consumes plans.
19. The tier checkpoint is additive: plans that skip it (e.g. legacy runs) still produce valid output.
