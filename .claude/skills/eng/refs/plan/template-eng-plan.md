---
name: Engineering Execution Plan Template
description: Plan-mode output format for eng agents — sections are returned as markdown and appended to the PRD by plan-em; no standalone file is created
type: reference
---

# Engineering Execution Plan — Plan Mode

This is the output format for an eng agent running in **plan mode**. The agent writes a structured markdown section directly to the PRD file, appended under `## Engineering — <Agent Name>`. No standalone file is created.

Populate every section. This is an execution document, not a status update. It must answer "what are we building, what did we consider and reject, who builds what, and what blocks shipping?" without further conversation.

## Required sections

### 1. Summary

Two to three sentences. State what is being built, the agent's owned stack (from PRD §3), and the projected shipping shape (single release, phased rollout, dark launch). Do not describe work on other platforms — each platform has its own engineering plan.

**Worked example:**
> Ship a habit-tracking core flow on iOS only. Backend introduces one new service (`streak-service`) and extends the existing user profile schema. Android and web are out of scope for this plan.

---

### 2. PRD reference

Bullet list. Cite the PRD path, the version hash or date, and any tune audit applied.

- **PRD:** `features/prd-[n]/prd-[n].md`
- **PRD version:** date or git SHA
- **Tune audit:** `features/prd-[n]/tune-[n].md` (if applicable) — list which findings were resolved before engineering plan drafting

---

### 3. Alternatives considered

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

### 4. Design decisions

One subsection per non-obvious implementation choice. Each decision must name the competing options, show trade-offs, and state the resolution. If a decision is still open, mark it **OPEN** and move it to §13.

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

### 5. Scope mapping

Table form. Map every feature ID from the PRD to one or more engineering domains. Domains must stay within the agent's owned stack.

| PRD feature ID | Feature | Domains | Lead agent |
|----------------|---------|---------|-----------|
| F1 | Set daily goal | iOS, backend | eng-ios |
| F2 | Track streak | backend, iOS | eng-backend |
| F3 | Daily reminder | iOS | eng-ios |

---

### 6. Phases and dependencies

Numbered phases. Each phase names its blocking dependency and exit criterion.

**Worked example:**

1. **Phase 1 — Schema and contracts.** Backend defines schema migration and OpenAPI spec for F1, F2, F3. **Blocks:** all client work. **Exit:** OpenAPI spec merged to `main`.
2. **Phase 2 — Parallel client + server.** Mobile and backend implement against the spec. **Blocks:** none. **Exit:** F1 + F2 + F3 acceptance criteria pass on staging.
3. **Phase 3 — Web read-only dashboard.** Web reads from production read replica. **Blocks:** Phase 2 ship. **Exit:** dashboard live on production.

---

### 7. Integration contracts

Cover all cross-service and cross-layer contracts introduced or changed by this plan. Every subsection is mandatory — write `None.` only when a subsection genuinely does not apply to this feature.

**API contracts:** List every new or changed API endpoint (REST, GraphQL, or RPC). For each, state the method, path or operation name, request shape, response shape, and the owning agent. Mark `NEW` or `CHANGED`.

| Method | Path / Operation | Request | Response | Owner | Status |
|--------|-----------------|---------|----------|-------|--------|
| POST | `/api/v1/streaks` | `{ userId, date }` | `{ streakId, count }` | eng-backend | NEW |

**Schema changes:** List every database schema change. State whether each change is additive-only or requires a migration script. Mark `ADDITIVE` or `MIGRATION REQUIRED`.

| Table / Collection | Change | Type |
|-------------------|--------|------|
| `streaks` | New table — `id`, `user_id`, `date`, `count` | MIGRATION REQUIRED |
| `users` | Add column `streak_id` (nullable FK) | ADDITIVE |

**Authentication patterns:** State which authentication mechanism this feature uses (JWT, session cookie, API key, OAuth token, etc.) and whether it introduces a new flow or reuses an existing one. If a new auth flow is introduced, describe the token lifecycle: how the token is issued, validated, refreshed, and revoked.

**Webhooks and hooks:** List every webhook emitted or consumed and every framework or platform hook invoked. For webhooks: name the event, payload shape, and consumer. For hooks: name the extension point and execution context. Write `None.` if this feature introduces no webhooks or hooks.

| Type | Name / Event | Payload shape | Consumer / Context |
|------|-------------|---------------|--------------------|
| Webhook (outbound) | `streak.completed` | `{ userId, streak, timestamp }` | third-party integrations |
| Lifecycle hook | `onSessionExpire` | `(session: Session)` | auth middleware |

---

### 8. Developer experience

Show what the feature looks like from the outside before and after. Use a code diff or side-by-side comparison.

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

### 9. Migration and breaking changes

State explicitly whether this plan introduces breaking changes and what the upgrade path is. If none, write `No breaking changes.`

- **Schema migrations:** Does this add, remove, or rename database columns? If yes, is the migration reversible?
- **API changes:** Any removed or renamed fields in public APIs or SDKs?
- **Upgrade path:** What do existing users need to do? If a migration script or command is needed, name it here.
- **Rollback plan:** How do we revert if the release fails?

**Worked example:**
> - **Schema migrations:** Adds `Auth` and `SocialAuthProvider` tables. Removes `password`, `email`, `isEmailVerified` from `User`. Migration is reversible.
> - **Upgrade path:** Run `wasp db migrate-auth`. This copies auth fields from `User` → `Auth` and `SocialLogin` → `SocialAuthProvider`, then users delete auth fields from their entity definition.
> - **Rollback plan:** Restore from pre-migration DB snapshot; revert Wasp version pin.

---

### 10. Branching and CI strategy

Bullet list. State the branching model, integration points, and CI gates.

- **Base branch:** `main`.
- **Feature branch:** `feat/prd-[n]-<short-name>`.
- **Commit mode:** under `ship` (default `direct`), build agents commit straight to the feature branch (agents own disjoint file sets, so parallel commits are safe). Under standalone `eng --build` with `commit_mode: sub-branch`, each agent works a per-agent sub-branch `feat/prd-[n]-<short-name>/<agent-id>` and merges to the feature branch via PR.
- **CI gates:** unit tests, integration tests, build green on the target platform (e.g., iOS 16+), backend schema migration reversible.
- **Release strategy:** target platform release through its store or deploy channel; backend behind a feature flag (`prd_[n]_enabled`).

---

### 11. Risks and mitigations

Table form. One row per risk that could block ship.

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| iOS push permission denial cascades onboarding failure | Medium | High | Design fallback in-app banner; F3 graceful degrade |
| Streak timezone bug causes user-visible regressions | Medium | High | Add timezone-stamped fixtures; staging soak with multi-TZ test accounts |
| Mobile store review delays Android | Low | Medium | Submit Android 3 days before iOS to absorb review cycle |

---

### 12. Findings — PRD gaps

Numbered findings. Each carries a severity and a required action. If `plan-em` ran clarifying questions during drafting, capture the unresolved ones here. If no findings, write `None.` and continue.

**Severity tags:**
- **Critical** — Engineering plan cannot ship without resolution. Block engineering kickoff.
- **Major** — Engineering plan ships but a follow-up PRD revision is required mid-flight.
- **Minor** — Note for future PRDs; no action required this cycle.

**Worked example:**
1. **Critical** — PRD §5 F2 acceptance criterion does not name timezone reference. **Action:** PM clarifies before backend schema is frozen.
2. **Minor** — PRD §6 success metric for "notification opt-in" lacks measurement window. **Action:** PM adds a window in next PRD revision.

---

### 13. Open questions for human gate

Numbered. Each question must be answerable with a single decision. Mark any design decisions from §4 that remain unresolved as **OPEN** and list them here too. If none, write `None.`

1. **OPEN — Token identity:** Should the JWT contain `User.id` or `Auth.id`? Both uniquely identify a user; the choice affects middleware and client SDK surface area.

---

## Quality gates before save

| Gate | Rule |
|------|------|
| Summary | §1 states what is being built, the agent's owned stack, and shipping shape. |
| Alternatives | §3 documents at least one rejected option with a reason. |
| Design decisions | §4 has a subsection for every non-obvious implementation choice. Each has trade-offs and a resolution or is marked OPEN. |
| PRD coverage | Every assigned PRD feature ID appears in §5 (Scope mapping). |
| Phases | Every phase names a blocking dependency and an exit criterion. |
| Integration contracts | §7 has all four subsections populated (API contracts, schema changes, auth patterns, webhooks/hooks). Every subsection either has entries or explicitly states `None.` |
| Developer experience | §8 shows a before/after or explicitly states no user-facing change. |
| Migration | §9 explicitly states whether breaking changes exist and names the rollback plan. |
| Risks | At least three risks named, each with a mitigation. |
| Findings | If PRD gaps exist, every finding has severity and action. |
| Open questions | Any OPEN design decision in §4 appears in §13. |
| Exact identifiers | Every function name, table name, column name, migration filename, and API endpoint is verified against the codebase scan — no guessed or approximate names. Any name that cannot be confirmed is a gap in §12, not a placeholder. |
