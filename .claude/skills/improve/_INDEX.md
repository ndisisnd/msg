# Improve Plan Index

Tracks every plan under `.claude/skills/improve/`. Status is derived from the folder a plan lives in:

- **In-progress** — plan dir at the improve root
- **Done** — `done/`
- **Backlog** — `backlog/`
- **Archived** — `archive/`

IDs are unique and monotonically increasing. IDs are not strictly sequential — gaps appear where plans were archived or merged before being assigned a number.

| ID | Name | Description | Status |
|----|------|-------------|--------|
| 1 | [split-protocol-refs](done/1-split-protocol-refs/plan.md) | Split flat `plan-em` protocol refs into plan-mode and build-mode files so each invocation loads only what it uses. | Done |
| 2 | [plan-major-enhancement](done/2-plan-major-enhancement/plan.md) | Remove plan-em Step 2 "first-layer fixes" — plan-em consumes a tuned PRD, not repairs one. | Done |
| 3 | [msg-root-skill](done/3-msg-root-skill/plan.md) | Add a root `msg` skill as the project entry point and menu for every msg sub-skill. | Done |
| 4 | [msg-health](backlog/4-msg-health/plan.md) | Add `msg health` sub-command that verifies skills, hooks, and config files are intact. | Backlog |
| 5 | [msg-insights](backlog/5-msg-insights/plan.md) | Add `msg insights` sub-command that surfaces rtk token savings and skill usage patterns. | Backlog |
| 6 | [msg-learnings](backlog/6-msg-learnings/plan.md) | Add `msg learnings` sub-command that surfaces accumulated feedback and project memories for review. | Backlog |
| 7.1 | [eng-build](done/7.1-eng-build/plan.md) | New `eng --build` mode: platform-agnostic code writer that consumes exec-table rows and writes code to pass pre-written tests. | Done |
| 7.2 | [eng-plan](done/7.2-eng-plan/plan.md) | New `eng --plan` mode: translates completed exec-table steps into a human-reviewable proposed-changes doc before build. | Done |
| 7.3 | [eng-review](archive/7.3-eng-review/plan.md) | New `eng --review` mode as a post-build quality gate. Superseded by the standalone `/review` skill (plan 12-review). | Archived |
| 8 | [handoff](done/8-handoff/plan.md) | New `handoff` skill that emits a structured, agent-readable mid-flight handoff artifact. | Done |
| 9 | [agent-creation-option](done/9-agent-creation-option/plan.md) | Add "Create a new agent" intent to `/improve` Step 1, branching to `/agent-plan` or an inline create path. | Done |
| 10 | [preflight](10-preflight/plan.md) | New `preflight` skill — pre-PR quality gate run after `eng --build` and before `gh pr create`, fully agentized. | In-progress |
| 11 | [docu](done/11-docu/plan.md) | New `docu` skill that scans a diff and offers targeted inline fixes for stale references in README/ARCHITECTURE/PRD/AHA. | Done |
| 12 | [review](done/12-review/plan.md) | New `/review` orchestrator that fingerprints the codebase, bootstraps an eval-set, then fans out to `/cook` across five review modes. | Done |
| 16 | [functional-mode-rigor](done/16-functional-mode-rigor/plan.md) | Tighten `review` Functional mode: define pass/warn/block rubric, require evidence, handle N/A and negative assertions, kill self-derived tautologies. | Done |
| 17 | [review-preflight-rigor](done/17-review-preflight-rigor/plan.md) | Fix three preflight defects in `/review`: eval-set sources, `main`-branch refusal, and flag source. | Done |
| 13 | [quality-mode-rigor](done/13-quality-mode-rigor/plan.md) | Fix three `/review` Quality-mode defects: misadvertised checks, discarded scope-creep signal, missing flag backing. | Done |
| 14 | [mechanical-checks](done/14-mechanical-checks/plan.md) | Merge local-machine testing primitives into `/review`: lint/format/typecheck into Quality, dedicated secret scan into Security; no git hooks. | Done |
| 15 | [review-test-split](15-review-test-split/plan.md) | Strip test execution from `/review` (Coverage + Functional modes) and extract it into a new standalone `/test` skill that pre-merge delegates to. | In-progress |
