---
name: RFC Template
description: Structured RFC / engineering plan format for plan-em to populate
type: reference
---

# RFC Template

Populate every section. The RFC is a decision document, not a status update. It must answer "what are we building, who builds what, and what blocks shipping?" without further conversation.

## File header

```markdown
---
name: rfc-[n]
feature: <short feature name, must match prd-[n].md>
prd: prd-[n].md
author: plan-em
status: draft | approved
created: YYYY-MM-DD
---

# RFC-[n]: <Feature Name>
```

## Required sections

### 1. Summary

Two to three sentences. State what is being built, the highest-priority platform target, and the projected shipping shape (single release, phased rollout, dark launch).

**Worked example:**
> Ship a habit-tracking core flow on iOS and Android in a single coordinated release. Web ships a read-only stats dashboard one sprint behind mobile. Backend introduces one new service (`streak-service`) and extends the existing user profile schema.

### 2. PRD reference

Bullet list. Cite the PRD path, the version hash or date, and any tune audit applied.

- **PRD:** `features/prd-[n]/prd-[n].md`
- **PRD version:** date or git SHA
- **Tune audit:** `features/prd-[n]/tune-[n].md` (if applicable) — list which findings were resolved before RFC drafting

### 3. Scope mapping

Table form. Map every feature ID from PRD §5 to one or more engineering domains. Use `refs/scope-matrix.md` to determine domain assignments.

| PRD feature ID | Feature | Domains | Lead agent |
|----------------|---------|---------|-----------|
| F1 | Set daily goal | iOS, Android, backend | mobile-eng |
| F2 | Track streak | backend, iOS, Android | backend-eng |
| F3 | Daily reminder | iOS, Android | mobile-eng |

### 4. Agent roster

One row per agent that will be activated. Right-size — propose the minimal set that covers the scope. Adding an extra agent is not free.

| Agent | Domain | Scope | Estimated PR count |
|-------|--------|-------|-------------------|
| mobile-eng-ios | iOS app | F1 UI, F3 notification handler | 3–4 |
| mobile-eng-android | Android app | F1 UI, F3 notification handler | 3–4 |
| backend-eng | API + DB | F2 streak service, schema migration, F1/F3 endpoints | 4–5 |
| web-eng | Web dashboard | Read-only stats view (P1, ships sprint+1) | 2 |

### 5. Phases and dependencies

Numbered phases. Each phase names its blocking dependency and exit criterion.

**Worked example:**

1. **Phase 1 — Schema and contracts.** Backend defines schema migration and OpenAPI spec for F1, F2, F3. **Blocks:** all client work. **Exit:** OpenAPI spec merged to `main`.
2. **Phase 2 — Parallel client + server.** Mobile and backend implement against the spec. **Blocks:** none. **Exit:** F1 + F2 + F3 acceptance criteria pass on staging.
3. **Phase 3 — Web read-only dashboard.** Web reads from production read replica. **Blocks:** Phase 2 ship. **Exit:** dashboard live on production.

### 6. Branching and CI strategy

Bullet list. State the branching model, integration points, and CI gates.

- **Base branch:** `main`.
- **Feature branch:** `feature/prd-[n]-<short-name>`.
- **Per-agent sub-branches:** `feature/prd-[n]-<short-name>/<agent-id>`. Each agent merges to the feature branch via PR.
- **CI gates:** unit tests, integration tests, mobile build green on iOS 16+ and Android API 28+, backend schema migration reversible.
- **Release strategy:** mobile coordinated release through stores; backend behind a feature flag (`prd_[n]_enabled`); web ships independently after mobile.

### 7. Risks and mitigations

Table form. One row per risk that could block ship.

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| iOS push permission denial cascades onboarding failure | Medium | High | Design fallback in-app banner; F3 graceful degrade |
| Streak timezone bug causes user-visible regressions | Medium | High | Add timezone-stamped fixtures; staging soak with multi-TZ test accounts |
| Mobile store review delays Android | Low | Medium | Submit Android 3 days before iOS to absorb review cycle |

### 8. Findings — PRD gaps

Numbered findings. Each carries a severity and a required action. If `plan-em` ran clarifying questions during drafting, capture the unresolved ones here. If no findings, write `None.` and continue.

**Severity tags:**
- **Critical** — RFC cannot ship without resolution. Block engineering kickoff.
- **Major** — RFC ships but a follow-up PRD revision is required mid-flight.
- **Minor** — Note for future PRDs; no action required this cycle.

**Worked example:**
1. **Critical** — PRD §5 F2 acceptance criterion does not name timezone reference. **Action:** PM clarifies before backend schema is frozen.
2. **Minor** — PRD §6 success metric for "notification opt-in" lacks measurement window. **Action:** PM adds a window in next PRD revision.

### 9. Cost and timeline

Bullet list. State engineering days per agent and a target ship date. Round up; reviewers prefer honest over-estimates.

- **mobile-eng-ios:** 8 engineer-days
- **mobile-eng-android:** 8 engineer-days
- **backend-eng:** 6 engineer-days
- **web-eng:** 4 engineer-days (sprint+1)
- **Target ship date:** YYYY-MM-DD (mobile); YYYY-MM-DD (web)

### 10. Open questions for human gate

Numbered. Each question must be answerable with a single `AskUserQuestion`. If none, write `None.`

## Quality gates before save

| Gate | Rule |
|------|------|
| PRD coverage | Every PRD §5 feature ID appears in §3 scope mapping. |
| Agent set | Every agent in §4 has at least one row in §3 it owns. |
| Phases | Every phase names a blocking dependency and an exit criterion. |
| Risks | At least three risks named, each with a mitigation. |
| Findings | If PRD gaps exist, every finding has severity and action. |
| Timeline | Every agent in §4 has an engineer-day estimate in §9. |
