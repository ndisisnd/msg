---
name: RFC Template
description: Structured RFC / engineering plan format for plan-em to populate
type: reference
---

# RFC Template

Populate every section. The RFC is a decision document, not a status update. It must answer "what are we building, why are we building it, what did we consider and reject, who builds what, and what blocks shipping?" without further conversation.

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

### 1. Problem

State the current state, the pain points it causes, and what we are explicitly not trying to solve.

**Current state:** One to two sentences describing what exists today and why it is insufficient.

**Pain points:** Bullet list of specific developer or user frustrations. Each point should be concrete enough that a reader can verify it.

- Pain point one — describe the friction
- Pain point two — describe the friction

**Non-goals (we want to avoid):** Bullet list of things this RFC explicitly will not do. This guards scope and prevents future misinterpretation.

- Not solving X this cycle
- Not breaking Y if possible

**Worked example:**
> **Current state:** Developers must copy-paste a `User` entity with all auth fields into every new project. Auth fields (email, password) are mixed with business logic fields (tasks, address) in the same model.
>
> **Pain points:**
> - Boilerplate copy-paste required on every new project
> - Switching auth methods requires manual schema migrations and data moves
> - Auth implementation details leak into application code
>
> **Non-goals:**
> - We will not redesign the session management layer in this RFC
> - We will not break existing apps if avoidable

---

### 2. Summary

Two to three sentences. State what is being built, the highest-priority platform target, and the projected shipping shape (single release, phased rollout, dark launch).

**Worked example:**
> Ship a habit-tracking core flow on iOS and Android in a single coordinated release. Web ships a read-only stats dashboard one sprint behind mobile. Backend introduces one new service (`streak-service`) and extends the existing user profile schema.

---

### 3. PRD reference

Bullet list. Cite the PRD path, the version hash or date, and any tune audit applied.

- **PRD:** `features/prd-[n]/prd-[n].md`
- **PRD version:** date or git SHA
- **Tune audit:** `features/prd-[n]/tune-[n].md` (if applicable) — list which findings were resolved before RFC drafting

---

### 4. Alternatives considered

Document every meaningful approach that was evaluated and rejected. This is the most important section for future readers who wonder "why not just do X?" If no alternative was seriously considered, write a single sentence explaining why the chosen approach is obviously correct — do not write `None.`

| Option | Description | Rejected because |
|--------|-------------|-----------------|
| Option A | What it would involve | Why it was ruled out |
| Option B | What it would involve | Why it was ruled out |
| **Chosen** | What we are actually doing | Why this wins |

**Worked example:**

| Option | Description | Rejected because |
|--------|-------------|-----------------|
| Keep user-defined entities | Require devs to copy-paste auth entities | Fragile, auth details leak into business logic |
| Code-generate entities into Wasp file | Generate entities into AppSpec | Pollutes user's Wasp file, breaks on re-run |
| **Inject into Prisma schema directly** | Append auth entities during Prisma codegen | Auth entities stay hidden; minimal user-facing churn |

---

### 5. Design decisions

One subsection per non-obvious implementation choice. Each decision must name the competing options, show trade-offs, and state the resolution. If a decision is still open, mark it **OPEN** and move it to §14.

**Format per decision:**

> **Decision:** \<name the choice\>
>
> | Approach | ➕ Pros | ➖ Cons |
> |----------|---------|---------|
> | Approach A | ... | ... |
> | Approach B | ... | ... |
>
> **Resolution:** Chose Approach A because \<reason\>.

**Worked example:**

> **Decision:** Where to inject auth entities
>
> | Approach | ➕ Pros | ➖ Cons |
> |----------|---------|---------|
> | Append to AppSpec | Entities included in `@wasp/entities` automatically | Mutates user's code; may break existing tooling |
> | Append to Prisma file directly | Auth entities stay invisible to users | More maintenance; users must import from Prisma directly |
>
> **Resolution:** Inject into the Prisma file directly. Auth is an implementation detail; keeping it out of AppSpec reduces the surface area users have to understand.

---

### 6. Scope mapping

Table form. Map every feature ID from PRD §5 to one or more engineering domains. Use `refs/scope-matrix.md` to determine domain assignments.

| PRD feature ID | Feature | Domains | Lead agent |
|----------------|---------|---------|-----------|
| F1 | Set daily goal | iOS, Android, backend | mobile-eng |
| F2 | Track streak | backend, iOS, Android | backend-eng |
| F3 | Daily reminder | iOS, Android | mobile-eng |

---

### 7. Agent roster

One row per agent that will be activated. Right-size — propose the minimal set that covers the scope. Adding an extra agent is not free.

| Agent | Domain | Scope | Estimated PR count |
|-------|--------|-------|-------------------|
| mobile-eng-ios | iOS app | F1 UI, F3 notification handler | 3–4 |
| mobile-eng-android | Android app | F1 UI, F3 notification handler | 3–4 |
| backend-eng | API + DB | F2 streak service, schema migration, F1/F3 endpoints | 4–5 |
| web-eng | Web dashboard | Read-only stats view (P1, ships sprint+1) | 2 |

---

### 8. Phases and dependencies

Numbered phases. Each phase names its blocking dependency and exit criterion.

**Worked example:**

1. **Phase 1 — Schema and contracts.** Backend defines schema migration and OpenAPI spec for F1, F2, F3. **Blocks:** all client work. **Exit:** OpenAPI spec merged to `main`.
2. **Phase 2 — Parallel client + server.** Mobile and backend implement against the spec. **Blocks:** none. **Exit:** F1 + F2 + F3 acceptance criteria pass on staging.
3. **Phase 3 — Web read-only dashboard.** Web reads from production read replica. **Blocks:** Phase 2 ship. **Exit:** dashboard live on production.

---

### 9. Developer experience

Show what the feature looks like from the outside before and after. Use a code diff or side-by-side comparison. This section exists to validate that the implementation actually solves the problem stated in §1.

**Before:**
```
<code showing current painful state>
```

**After:**
```
<code showing improved state>
```

If the change is entirely internal (no user-facing API change), write `No user-facing API change — internal only.`

---

### 10. Migration and breaking changes

State explicitly whether this RFC introduces breaking changes and what the upgrade path is. If none, write `No breaking changes.`

- **Schema migrations:** Does this add, remove, or rename database columns? If yes, is the migration reversible?
- **API changes:** Any removed or renamed fields in public APIs or SDKs?
- **Upgrade path:** What do existing users need to do? If a migration script or command is needed, name it here.
- **Rollback plan:** How do we revert if the release fails?

**Worked example:**
> - **Schema migrations:** Adds `Auth` and `SocialAuthProvider` tables. Removes `password`, `email`, `isEmailVerified` from `User`. Migration is reversible.
> - **Upgrade path:** Run `wasp db migrate-auth`. This copies auth fields from `User` → `Auth` and `SocialLogin` → `SocialAuthProvider`, then users delete auth fields from their entity definition.
> - **Rollback plan:** Restore from pre-migration DB snapshot; revert Wasp version pin.

---

### 11. Branching and CI strategy

Bullet list. State the branching model, integration points, and CI gates.

- **Base branch:** `main`.
- **Feature branch:** `feature/prd-[n]-<short-name>`.
- **Per-agent sub-branches:** `feature/prd-[n]-<short-name>/<agent-id>`. Each agent merges to the feature branch via PR.
- **CI gates:** unit tests, integration tests, mobile build green on iOS 16+ and Android API 28+, backend schema migration reversible.
- **Release strategy:** mobile coordinated release through stores; backend behind a feature flag (`prd_[n]_enabled`); web ships independently after mobile.

---

### 12. Risks and mitigations

Table form. One row per risk that could block ship.

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| iOS push permission denial cascades onboarding failure | Medium | High | Design fallback in-app banner; F3 graceful degrade |
| Streak timezone bug causes user-visible regressions | Medium | High | Add timezone-stamped fixtures; staging soak with multi-TZ test accounts |
| Mobile store review delays Android | Low | Medium | Submit Android 3 days before iOS to absorb review cycle |

---

### 13. Findings — PRD gaps

Numbered findings. Each carries a severity and a required action. If `plan-em` ran clarifying questions during drafting, capture the unresolved ones here. If no findings, write `None.` and continue.

**Severity tags:**
- **Critical** — RFC cannot ship without resolution. Block engineering kickoff.
- **Major** — RFC ships but a follow-up PRD revision is required mid-flight.
- **Minor** — Note for future PRDs; no action required this cycle.

**Worked example:**
1. **Critical** — PRD §5 F2 acceptance criterion does not name timezone reference. **Action:** PM clarifies before backend schema is frozen.
2. **Minor** — PRD §6 success metric for "notification opt-in" lacks measurement window. **Action:** PM adds a window in next PRD revision.

---

### 14. Cost and timeline

Bullet list. State engineering days per agent and a target ship date. Round up; reviewers prefer honest over-estimates.

- **mobile-eng-ios:** 8 engineer-days
- **mobile-eng-android:** 8 engineer-days
- **backend-eng:** 6 engineer-days
- **web-eng:** 4 engineer-days (sprint+1)
- **Target ship date:** YYYY-MM-DD (mobile); YYYY-MM-DD (web)

---

### 15. Open questions for human gate

Numbered. Each question must be answerable with a single decision. Mark any design decisions from §5 that remain unresolved as **OPEN** and list them here too. If none, write `None.`

1. **OPEN — Token identity:** Should the JWT contain `User.id` or `Auth.id`? Both uniquely identify a user; the choice affects middleware and client SDK surface area.

---

## Quality gates before save

| Gate | Rule |
|------|------|
| Problem | §1 states current state, at least two pain points, and at least one explicit non-goal. |
| Alternatives | §4 documents at least one rejected option with a reason. |
| Design decisions | §5 has a subsection for every non-obvious implementation choice. Each has trade-offs and a resolution or is marked OPEN. |
| PRD coverage | Every PRD §5 feature ID appears in §6 scope mapping. |
| Agent set | Every agent in §7 has at least one row in §6 it owns. |
| Phases | Every phase names a blocking dependency and an exit criterion. |
| Developer experience | §9 shows a before/after or explicitly states no user-facing change. |
| Migration | §10 explicitly states whether breaking changes exist and names the rollback plan. |
| Risks | At least three risks named, each with a mitigation. |
| Findings | If PRD gaps exist, every finding has severity and action. |
| Timeline | Every agent in §7 has an engineer-day estimate in §14. |
| Open questions | Any OPEN design decision in §5 appears in §15. |
