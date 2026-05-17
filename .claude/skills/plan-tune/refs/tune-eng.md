---
name: Tune Eng Checklist
description: Dimension 5 eng plan integrity checks — applies only in Eng tune when PRD contains Engineering sections
type: reference
---

# Tune Eng Checklist

## Dimension 5 — Eng Plan Integrity (Eng tune only)

Apply only when running an Eng tune (PRD contains `## Engineering — <Agent Name>` sections). Read each engineering section against the PRD requirements and against the quality gates in `refs/template-eng-plan.md`. One finding per issue.

### 5a — Feature coverage

Every feature ID in the PRD must appear in at least one engineering section's scope mapping table (§5 of the eng plan template).

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
| Platform match | An engineering section targets a platform not listed in the PRD platform priorities table | Major |
| Acceptance criterion ↔ Eng plan | A PRD acceptance criterion has no corresponding implementation detail in any engineering section | Major |

### 5c — Integration contract completeness

Read each engineering section's integration contracts (§7 of the eng plan template).

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

Check each engineering section against the quality gates in `refs/template-eng-plan.md` (Summary, Alternatives considered, Design decisions, PRD coverage, Phases, Integration contracts, Developer experience, Migration, Risks, Timeline, Open questions).

| Check | Fail condition | Severity if fails |
|-------|----------------|-------------------|
| Summary present | §1 absent or does not name the target platform and shipping shape | Major |
| Alternatives considered | §3 absent or writes `None.` without a sentence explaining why one approach is obviously correct | Minor |
| At least three risks | §11 has fewer than three rows | Minor |
| Timeline estimate | §13 absent or has no engineer-day estimate | Minor |
