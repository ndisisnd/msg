# Improvement Plan — 18-complexity-detection

**Skill:** agent-plan
**Change type:** New capability

## Problem

`agent-plan` always emits the same output shape regardless of skill complexity: a persona, a workflow diagram, multiple ref files, and a nested folder structure. A single-step task agent (e.g. "commit formatter") gets the same scaffold as a multi-agent orchestrator. This wastes plan tokens, bloats `agent-build` context, and trains builders to expect complexity that isn't there. The output shape should be inferred from signals collected during the interview and declared as a tier before the plan is written.

## Proposed changes

| # | What | How | Why necessary | Why ignorable |  Rank |
|---|------|-----|---------------|---------------|-------|
| 1 | Define three output tiers in `plan-template.md` | Add a **Tier** section above the existing template with three named shapes — **Simple**, **Standard**, **Complex** — each declaring which sections are required, optional, or forbidden (e.g. Simple forbids persona and workflow diagram; Complex requires sub-skill declarations and nested refs/) | Without declared shapes, the model has no anchor to calibrate against; calibration rules in principles.md would have nothing to reference | Only if all planned skills are known to be complex | P1 |
| 2 | Add complexity inference after signal collection in `interview.md` | After the last interview question resolves, add a **Tier Inference** step: count workflow steps from Q1/Q4 answers, check for persona signal (Q6), check for sub-skill/composition signal (Q5/Q8). Map to a tier using a decision table. Emit the inferred tier as `[TIER: Simple/Standard/Complex]` before producing the plan | Inference must happen in the interview layer where signals are richest; doing it later (in SKILL.md protocol) would require re-reading answers | Skip if the user explicitly states a tier in their initial prompt | P1 |
| 3 | Expose inferred tier as a human checkpoint in SKILL.md | After the interview phase completes, SKILL.md protocol emits the inferred tier with a one-line rationale and asks the user to confirm or override before continuing to plan generation | Prevents the model from silently picking the wrong tier on ambiguous input; overrides cover cases where signals are misleading | Not ignorable — checkpoint is the override mechanism, which the user explicitly requested | P2 |
| 4 | Add calibration rule to `principles.md` | Add one rule under a new **Calibration** heading: "Output shape must match the confirmed tier. Do not add sections, ref files, or folder nesting beyond the tier's declared shape." | Without an explicit constraint in principles.md, the model defaults to maximal structure; a rule here acts as a persistent negative instruction | Only if plan-template.md tier definitions are strict enough to self-enforce (unlikely without a rule) | P2 |
| 5 | Add per-dimension override table to `plan-template.md` | Below the tier definitions, add a small override table listing dimensions (persona, workflow-diagram, ref-count, sub-skills, folder-nesting) with allowed values per tier and an override column. Strong signals (e.g. composition detected even in a Standard skill) populate the override column. | Supports the user-requested "hybrid" model — tiers are defaults, individual dimensions can shift when signals are clear | Deferrable if the three-tier definitions alone produce acceptable output in practice | P3 |

---

## Tier definitions (reference for the plan writer)

| Tier | Persona | Workflow diagram | Refs | Sub-skills | Folder nesting |
|------|---------|-----------------|------|------------|----------------|
| Simple | Forbidden | Forbidden | 0–1 | Forbidden | Flat only |
| Standard | Optional | Required | 1–4 | Optional | 1 level |
| Complex | Required | Required | 3+ | Allowed | 2 levels |
