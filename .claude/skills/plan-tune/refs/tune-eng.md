---
name: Tune Eng Checklist
description: Dimension 5 eng plan integrity checks — applies only in Eng tune when PRD contains Engineering sections
type: reference
---

# Tune Eng Checklist

## Dimension 5 — Eng Plan Integrity (Eng tune only)

Apply only when running an Eng tune (PRD contains `## Engineering — <Agent Name>` sections). Read each engineering section against the PRD requirements and against the quality gates in `.claude/skills/eng/refs/plan/template-eng-plan.md`. One finding per issue. The eng-plan subsections referenced below (scope mapping, integration contracts, migration, open questions) are matched by their **titles** in that template, so they survive renumbering. PRD product sections are likewise referenced by title (Features & acceptance criteria, Open questions, etc.), never by number.

### 5a — Feature coverage

Every feature ID in the PRD must appear in at least one engineering section's scope mapping table (the scope-mapping subsection of the eng plan template).

| Check | Fail condition | Severity if fails |
|-------|----------------|-------------------|
| Full feature coverage | Any PRD feature ID absent from all `## Engineering —` scope mapping tables | Critical |
| No phantom features | An engineering section covers a feature ID not present in the PRD | Major |
| Agent ownership | Any PRD feature with no named owning agent across all engineering sections | Major |

### 5b — PRD ↔ Eng consistency

Read every engineering design decision against PRD constraints, acceptance criteria, and platform priorities.

| Check | What to look for | Severity if fails |
|-------|-----------------|-------------------|
| Design decision ↔ PRD constraint | An engineering design decision contradicts or ignores a stated PRD constraint | Critical |
| Eng scope ↔ Out-of-scope | An engineering section implements behavior listed as out-of-scope in the PRD | Critical |
| Platform match | An engineering section targets a platform other than the PRD frontmatter `platform` value | Major |
| Acceptance criterion ↔ Eng plan | A PRD acceptance criterion has no corresponding implementation detail in any engineering section | Major |

### 5c — Integration contract completeness

Read each engineering section's integration contracts (the integration-contracts subsection of the eng plan template).

| Check | Fail condition | Severity if fails |
|-------|----------------|-------------------|
| API contracts | Any client-server feature in an engineering section with no API contract row (method, path, request, response) | Critical |
| Schema changes | Any schema change listed without stating whether it is `ADDITIVE` or `MIGRATION REQUIRED` | Major |
| Auth pattern | Any user-data feature in an engineering section without a stated authentication mechanism | Critical |
| Webhook/hook coverage | Any webhook or hook referenced in prose but absent from the contracts table | Major |

### 5d — Migration and breaking change coverage

| Check | Fail condition | Severity if fails |
|-------|----------------|-------------------|
| Breaking change acknowledgement | An engineering section introduces a schema or API breaking change with no stated rollback plan | Critical |
| Migration path | A `MIGRATION REQUIRED` schema change has no named migration script or upgrade path | Critical |
| Backward-compat shim | A breaking change marks no backward-compat period or deprecation window | Major |

### 5e — Open question ownership

| Check | Fail condition | Severity if fails |
|-------|----------------|-------------------|
| OPEN decision owner | Any design decision marked `OPEN` in an engineering section has no named owner or stated resolution path | Major |
| Duplicate open questions | The same open question appears in multiple engineering sections without a cross-reference to avoid duplicate work | Minor |
| Phase blocked by OPEN decision | A phase exit criterion depends on an OPEN design decision with no resolution timeline | Critical |

### 5f — Eng plan completeness (quality gate audit)

Read the canonical `## Quality gates before save` table directly from `.claude/skills/eng/refs/plan/template-eng-plan.md` for every run — do not hand-copy or restate its rules here, so this check never drifts from eng's own definition of "complete." Apply every gate in that table to each engineering section, except the three already covered elsewhere in Dimension 5 (skip them here to avoid duplicate findings): PRD coverage → 5a, Integration contracts → 5c, Migration → 5d.

For each remaining gate that fails, draft one finding citing the gate name from the canonical table and the exact rule text it violates.

| Check | Fail condition | Severity if fails |
|-------|----------------|-------------------|
| Summary | Canonical "Summary" gate fails | Major |
| Alternatives | Canonical "Alternatives" gate fails | Minor |
| Design decisions | Canonical "Design decisions" gate fails | Major |
| Phases | Canonical "Phases" gate fails | Major |
| Developer experience | Canonical "Developer experience" gate fails | Minor |
| Risks | Canonical "Risks" gate fails (fewer than three rows, or a row with no mitigation) | Minor |
| Findings | Canonical "Findings" gate fails | Minor |
| Open questions | Canonical "Open questions" gate fails | Major |
| Exact identifiers | Canonical "Exact identifiers" gate fails (a guessed or approximate name) | Critical |

### 5g — Cross-PRD breaking-change consistency

Read this PRD's own frontmatter `affects` and `depends_on` lists (`template-prd.md` file header). Cross-check them against this same PRD's `## Engineering —` sections — specifically the breaking changes surfaced by 5d and the scope mapping from 5a. This check reads only the input PRD's own frontmatter and its own engineering sections; it does not open other PRD files. Reconciling against the actual prior PRD files is `plan-em`'s Step 1 pre-flight responsibility (`plan-em/SKILL.md:88–106`) — this check exists to catch drift introduced or missed after that pre-flight already ran, e.g. when a later tune run edits an engineering section without re-running plan-em.

| Check | Fail condition | Severity if fails |
|-------|----------------|-------------------|
| Breaking change registered | An engineering section names a breaking change to a schema, API contract, or module (per 5d) whose owning PRD is not listed in this PRD's frontmatter `affects` | Critical |
| Dependency accounted for | A frontmatter `depends_on` entry names a PRD ID that no engineering section's scope mapping or integration contracts reference or build against | Major |
