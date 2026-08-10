---
name: Engineering Execution Plan Template
description: Plan-mode output format for eng agents — two shapes tiered on the PRD's intake grade (4 sections for medium PRDs, 12 for large); sections are returned as markdown and appended to the PRD by plan-em, no standalone file is created
type: reference
---

# Engineering Execution Plan — Plan Mode

This is the output format for an eng agent running in **plan mode**. The agent writes a structured markdown section directly to the PRD file, appended under `## Engineering — <Agent Name>`. No standalone file is created.

This is an execution document, not a status update.

---

## Which shape to write — tier on the intake grade

The plan's length is proportional to the PRD's size, not fixed. Two shapes:

| Shape | Sections | When |
|-------|----------|------|
| **Medium (default)** | 4 — Design decisions · Integration contracts · Scope mapping · Open questions | Every PRD whose intake complexity grade is `C:` **< 8**, and every PRD whose grade cannot be resolved |
| **Large** | 12 — the medium four plus Summary, PRD reference, Alternatives considered, Phases and dependencies, Developer experience, Migration and breaking changes, Risks and mitigations, Findings — PRD gaps | Only when the intake complexity grade is `C:` **≥ 8** |

**Resolving the grade.** The PRD's frontmatter carries `intake: #<n>`. That number is the row id in the root `INTAKE.md` ledger; the row's **grade** cell reads `C:<band> T:<band> S:<sequencing>` (`.claude/skills/intake/refs/rubric.md`). Read the `C:` band from that row. `plan-em` normally resolves the grade once and injects it with the scoped context — use the injected value when it is present rather than re-reading the ledger.

**Default to medium when in doubt.** No `intake:` key, no matching row, an unparseable grade cell, or no `INTAKE.md` at all → write the medium shape. The medium shape is never wrong for a large PRD; it is only thinner than it could be. Never write the large shape "to be safe" — the cut sections have no downstream consumer, and the tokens are the whole point of the tier.

**Why these four survive and the other eight do not.** The `## Todos — <Agent>` tickets are the build spec (`refs/build/protocol.md` § Spec source) — a build agent never reads plan prose. So a plan section earns its place only if it carries something a ticket structurally cannot: a cross-agent contract, a design rationale that outlives the diff, the feature-to-agent map, or an unresolved question that needs a human. Summary, PRD reference, Alternatives considered, Phases, Developer experience, Migration and Risks all restate the PRD, restate the tickets, or address a reader who never arrives.

Both shapes are read-tolerated everywhere downstream — `script-eng-plan-shape.py` check 8 accepts either, and PRDs written before v5.4 (including the legacy 13-section shape with a "Branching and CI strategy" section) keep validating unchanged.

---

# Medium shape (default) — 4 sections

Write these four, numbered 1–4, and nothing else. Write `None.` only when a section genuinely does not apply.

### 1. Design decisions

One subsection per non-obvious implementation choice. Each decision must name the competing options, show trade-offs, and state the resolution. A decision that is still open is marked **OPEN** and repeated in §4.

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

### 2. Integration contracts

Cover the cross-service and cross-layer contracts introduced or changed by this plan — the shared surfaces the tickets cannot hold: contract tables between agents and the auth-flow narrative. **Do not restate per-identifier detail that a ticket's `files` / `done-when` already carries** — the tickets are the build spec; this section exists for the cross-agent agreement, not a second copy of it. Every subsection is mandatory — write `None.` only when a subsection genuinely does not apply.

**API contracts:** every new or changed API endpoint (REST, GraphQL, or RPC) — method, path or operation name, request shape, response shape, owning agent. Mark `NEW` or `CHANGED`.

| Method | Path / Operation | Request | Response | Owner | Status |
|--------|-----------------|---------|----------|-------|--------|
| POST | `/api/v1/streaks` | `{ userId, date }` | `{ streakId, count }` | eng-backend | NEW |

**Schema changes:** every database schema change, and whether each is additive-only or needs a migration script. Mark `ADDITIVE` or `MIGRATION REQUIRED`.

| Table / Collection | Change | Type |
|-------------------|--------|------|
| `streaks` | New table — `id`, `user_id`, `date`, `count` | MIGRATION REQUIRED |
| `users` | Add column `streak_id` (nullable FK) | ADDITIVE |

**Authentication patterns:** which authentication mechanism this feature uses (JWT, session cookie, API key, OAuth token, …) and whether it introduces a new flow or reuses an existing one. For a new flow, describe the token lifecycle: issue, validate, refresh, revoke.

**Webhooks and hooks:** every webhook emitted or consumed and every framework or platform hook invoked. Webhooks: event name, payload shape, consumer. Hooks: extension point and execution context. `None.` if there are none.

| Type | Name / Event | Payload shape | Consumer / Context |
|------|-------------|---------------|--------------------|
| Webhook (outbound) | `streak.completed` | `{ userId, streak, timestamp }` | third-party integrations |
| Lifecycle hook | `onSessionExpire` | `(session: Session)` | auth middleware |

---

### 3. Scope mapping

Table form. Map every feature ID from the PRD to one or more engineering domains. Domains must stay within the agent's owned stack.

| PRD feature ID | Feature | Domains | Lead agent |
|----------------|---------|---------|-----------|
| F1 | Set daily goal | iOS, backend | eng-ios |
| F2 | Track streak | backend, iOS | eng-backend |
| F3 | Daily reminder | iOS | eng-ios |

---

### 4. Open questions

Numbered. Two kinds of entry live here, because both resolve the same way — a human decides:

- **Open decisions.** Any §1 decision still marked **OPEN**. Each must be answerable with a single choice.
- **PRD gaps.** Anything the PRD, exec table, or codebase scan could not resolve — including an identifier that could not be confirmed against the codebase. Tag each **Critical** (engineering cannot ship without a resolution), **Major** (ships, but a PRD revision is needed mid-flight), or **Minor** (note for future PRDs). Name the required action.

If there are none, write `None.`

**Worked example:**

1. **OPEN — Token identity:** Should the JWT contain `User.id` or `Auth.id`? Both uniquely identify a user; the choice affects middleware and client SDK surface area.
2. **Critical — gap:** PRD §3 F2 acceptance criterion does not name a timezone reference. **Action:** PM clarifies before backend schema is frozen.

---

## Quality gates before save — medium shape

| Gate | Rule |
|------|------|
| Design decisions | §1 has a subsection for every non-obvious implementation choice, each with trade-offs and a resolution or an **OPEN** mark. |
| Integration contracts | §2 has all four subsections (API contracts, schema changes, auth patterns, webhooks/hooks), each with entries or an explicit `None.` |
| PRD coverage | Every assigned PRD feature ID appears in §3. |
| Open questions | Every **OPEN** §1 decision and every unresolved PRD gap appears in §4, each with a severity or a single-decision question. |
| Exact identifiers | Every function, table, column, migration filename and API endpoint named anywhere in the section is verified against the codebase scan — no guessed names. A name that cannot be confirmed is a §4 gap, not a placeholder. |
| No extra sections | Exactly §1–§4. A fifth section means the large shape was written for a medium PRD. |

---

# Large shape — 12 sections (`C:` ≥ 8 only)

Write this only for a PRD whose intake complexity grade is `C:` ≥ 8. It is the medium four (renumbered) plus the eight sections a genuinely large, multi-stack change needs a written record of.

### 1. Summary

Two to three sentences. What is being built, the agent's owned stack (from the PRD's Features & acceptance criteria table and the detected platform), and the projected shipping shape (single release, phased rollout, dark launch). Do not describe work on other platforms — each platform has its own engineering plan.

**Worked example:**
> Ship a habit-tracking core flow on iOS only. Backend introduces one new service (`streak-service`) and extends the existing user profile schema. Android and web are out of scope for this plan.

---

### 2. PRD reference

Bullet list. Cite the PRD path, the version hash or date, and the review pass applied.

- **PRD:** `features/prd-[n]-[slug]/prd-[n]-[slug].md`
- **PRD version:** date or git SHA
- **Review:** `features/prd-[n]-[slug]/reports/review-prd-[n]-[slug].md` (if present) — which findings were resolved before this plan was drafted

---

### 3. Alternatives considered

The approaches genuinely evaluated and rejected — as many as are real, and no invented ones. This is the section future readers reach for when they wonder "why not just do X?" If no alternative was seriously considered, write one sentence explaining why the chosen approach is obviously correct — never `None.`

| Option | Description | Rejected because |
|--------|-------------|-----------------|
| Keep user-defined entities | Require devs to copy-paste auth entities | Fragile, auth details leak into business logic |
| Code-generate entities into Wasp file | Generate entities into AppSpec | Pollutes user's Wasp file, breaks on re-run |
| **Inject into Prisma schema directly** | Append auth entities during Prisma codegen | Auth entities stay hidden; minimal user-facing churn |

---

### 4. Design decisions

Identical to the medium shape's §1 — same format, same worked example, same rule that an unresolved decision is marked **OPEN** and repeated in §12.

---

### 5. Scope mapping

Identical to the medium shape's §3.

---

### 6. Phases and dependencies

Numbered phases. Each phase names its blocking dependency and exit criterion.

**Worked example:**

1. **Phase 1 — Schema and contracts.** Backend defines schema migration and OpenAPI spec for F1, F2, F3. **Blocks:** all client work. **Exit:** OpenAPI spec merged.
2. **Phase 2 — Parallel client + server.** Mobile and backend implement against the spec. **Blocks:** none. **Exit:** F1 + F2 + F3 acceptance criteria pass on staging.
3. **Phase 3 — Web read-only dashboard.** Web reads from the production read replica. **Blocks:** Phase 2 ship. **Exit:** dashboard live on production.

---

### 7. Integration contracts

Identical to the medium shape's §2 — all four subsections mandatory.

---

### 8. Developer experience

Show what the feature looks like from the outside before and after — a code diff or side-by-side comparison. If the change is entirely internal, write `No user-facing API change — internal only.`

---

### 9. Migration and breaking changes

State explicitly whether this plan introduces breaking changes and what the upgrade path is. If none, write `No breaking changes.`

- **Schema migrations:** added, removed or renamed columns? Reversible?
- **API changes:** removed or renamed fields in public APIs or SDKs?
- **Upgrade path:** what existing users must do; name any migration script or command.
- **Rollback plan:** how to revert if the release fails.

---

### 10. Risks and mitigations

Table form. One row per risk that could block ship — **as many as are real**, not a quota. If there is genuinely no ship-blocking risk, write `None — <reason>`.

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| iOS push permission denial cascades onboarding failure | Medium | High | Design fallback in-app banner; F3 graceful degrade |
| Streak timezone bug causes user-visible regressions | Medium | High | Add timezone-stamped fixtures; staging soak with multi-TZ test accounts |

---

### 11. Findings — PRD gaps

Numbered findings, each with a severity (**Critical** / **Major** / **Minor**) and a required action. If `plan-em` ran clarifying questions during drafting, capture the unresolved ones here. If none, write `None.`

**Worked example:**
1. **Critical** — PRD §3 F2 acceptance criterion does not name a timezone reference. **Action:** PM clarifies before backend schema is frozen.
2. **Minor** — PRD §3 acceptance criterion for "notification opt-in" lacks a measurement window. **Action:** PM adds a window in the next PRD revision.

---

### 12. Open questions for human gate

Numbered. Each question answerable with a single decision. Every §4 decision still marked **OPEN** is repeated here. If none, write `None.`

1. **OPEN — Token identity:** Should the JWT contain `User.id` or `Auth.id`? Both uniquely identify a user; the choice affects middleware and client SDK surface area.

---

## Quality gates before save — large shape

| Gate | Rule |
|------|------|
| Summary | §1 states what is being built, the agent's owned stack, and the shipping shape. |
| Alternatives | §3 documents each alternative genuinely considered with a reason for rejecting it — or one sentence why the chosen approach is obviously correct. No invented options. |
| Design decisions | §4 has a subsection for every non-obvious implementation choice, each with trade-offs and a resolution or an **OPEN** mark. |
| PRD coverage | Every assigned PRD feature ID appears in §5. |
| Phases | Every phase names a blocking dependency and an exit criterion. |
| Integration contracts | §7 has all four subsections populated, each with entries or an explicit `None.` |
| Developer experience | §8 shows a before/after or explicitly states no user-facing change. |
| Migration | §9 explicitly states whether breaking changes exist and names the rollback plan. |
| Risks | Every real ship-blocking risk named with a mitigation — as many as are real, or `None — <reason>`. |
| Findings | Every PRD gap has a severity and an action. |
| Open questions | Every **OPEN** §4 decision appears in §12. |
| Exact identifiers | Every function, table, column, migration filename and API endpoint is verified against the codebase scan. A name that cannot be confirmed is a §11 gap, not a placeholder. |
| Grade justifies it | This shape was written because the intake grade reads `C:` ≥ 8. If it does not, the medium shape was required. |
