# eng — Mode: --plan

Reads the assigned PRD exec-table rows and, in a **single pass**, produces (1) a structured `## Engineering — <Agent>` section, (2) the filled Execution steps + Files columns, and (3) the `## Todos — <Agent>` tickets that decompose each owned F-ID into build-ready units. **No implementation code is written.**

This file defines the plan-mode specifics only. The shared protocol — input validation, PRD + devkit read, summary + approval gate mechanics, codebase scan, platform + coding standards, scope enforcement, user interview — lives in `SKILL.md`. Read SKILL.md's numbered steps as the spine; the sections below slot into the points it marks as mode-specific.

---

## Input contract (plan-specific)

No fields beyond the shared four (`--plan`, `prd-path`, `rows`, `agent`).

**Example invocation:**
```
/eng --plan prd-path=features/prd-4/prd-4.md rows="F2: Track streak — Schema migration; F2: Track streak — API contract"
```

No implementation files are written in this mode. Inline code snippets and pseudocode are permitted — and encouraged — to illustrate proposed changes within the plan document itself. Eng derives all file paths from the codebase scan and exec-table; it does **not** accept file paths as input.

---

## Summary content (Step 3 — Pre-run 1 of 2)

The 3–4 line summary covers:

- Line 1: What is being built — one sentence naming the feature and its user-facing purpose.
- Lines 2–3: How to achieve it in code — the main layers touched and the primary structural change.
- Line 4 (optional): Scope of the assigned rows relative to the full feature, and roughly how many `### F<n>` todo blocks / tickets the pass will write.

---

## Output contract (Step 5)

Produce a structured engineering section following `refs/plan/template-eng-plan.md`. No implementation files are written. Inline code snippets and pseudocode are permitted to illustrate proposed changes within the plan document.

Cover only the features implied by the assigned rows. Every section of the template is required — write `None.` only when a subsection genuinely does not apply.

Also fill in the **Execution steps** column for every row in the PRD's Execution Table where the Agent column matches this invocation, following `refs/build/protocol-exec.md` for format, granularity, and dependency notation. A row with a blank Execution steps cell is a hard failure.

**Exact identifier requirement (hard):** Every proposed change must name the precise artifact to be modified or created, verified against the codebase scan:

| Artifact | Required precision |
|----------|--------------------|
| Functions / methods | Exact name as it appears in source (e.g. `createStreak`, not "the streak creation function") |
| DB tables | Exact table name (e.g. `streaks`, not "a streaks table") |
| DB columns | Exact column names and types (e.g. `user_id UUID NOT NULL`) |
| Migration file | Exact filename following repo convention (e.g. `0043_add_streaks.sql`) |
| API endpoints | Exact HTTP method + path matching existing route conventions (e.g. `POST /api/v1/streaks`) |
| API / RPC operation names | Exact operation name as defined in OpenAPI spec or router |

Getting any identifier wrong is a hard failure — build agents execute against them directly and wrong names cause expensive rework. If the exact name cannot be confirmed from the codebase scan, mark it as a named gap in §12 (Findings), not a guess.

**Self-consistency check (identifiers ↔ Execution steps):** Before writing the section, cross-check §7's Integration contracts tables (API contracts, schema changes, webhooks/hooks) against the Execution steps you filled in. Every exact identifier named in §7 — each endpoint, table, column, migration filename, or webhook/hook name — must also appear in at least one owned row's Execution steps cell. Build agents execute the Execution steps only; they never read §7 prose. An identifier specified only in §7 and absent from every Execution steps cell is invisible to the build phase and will silently never be implemented. Fix any gap found by adding the missing identifier to the relevant row's Execution steps before writing the section — do not write a §7 entry you haven't also wired into a row.

**Return contract:** Write the complete engineering section directly to the PRD file at `prd-path`, appended under `## Engineering — <Agent Name>` (the agent identity for this invocation — the literal `— <Agent Name>` suffix is required; `plan-em` detects build mode by this heading). Do not create a separate output file. Emit a one-line confirmation after writing (e.g. `Written to features/prd-4/prd-4.md → ## Engineering — eng-backend`).

### Todo tickets — written in the same pass

After the engineering section and Execution steps are written, decompose every owned F-ID into `F<n>-T<k>` tickets under a `## Todos — <Agent Name>` block, in the **same pass** — there is no separate todo mode. Read `refs/plan/template-todo.md` fully before writing any ticket; it owns the schema (ids, the eight fields, rendering, rules, the empty-block sentinel, and the ticket-sizing rule) and `eng --build` reads these blocks mechanically, so the shape must match it exactly.

- Use this agent's own `## Engineering — <Agent Name>` section (integration contracts, exact identifiers, filled Execution steps) as the authority on *how*, and the PRD's Features & acceptance criteria F-ID table as the authority on *which* F-IDs are in scope and *why*. Do not re-interpret the features section independently of the engineering section you just wrote.
- Append the agent's `## Todos — <Agent Name>` block under the `## Todos` umbrella heading (created by `plan-em` before the plan wave — do **not** create the umbrella yourself), one `### F<n>` block per owned feature in F-ID order. A feature with no discrete work still gets an explicit `_No discrete work for this feature._` block.
- Every exact identifier this agent owns in §7 (endpoint, table, column, migration filename, test file, webhook/hook) must surface in some ticket's `files` + `done-when`.
- **Ticket sizing (A1):** scope each ticket so its implementation diff fits the commit caps — **<500 changed LOC**, **<300 when the ticket contains a breaking change**. A ticket that cannot fit is **split now**, at plan time, never deferred to build (rule 2 in `template-todo.md`).
- **Self-consistency (tickets ↔ exec table ↔ dependencies):** every `### F<n>` corresponds to an owned exec-table F-ID and vice versa; every `depends-on` id resolves to a real ticket in this PRD's `## Todos`; the graph is acyclic. A mismatch or dangling/cyclic dependency is surfaced as a named gap in §12 (Findings), not silently dropped.

Extend the write confirmation to note the tickets (e.g. `Written to features/prd-4/prd-4.md → ## Engineering — eng-backend + ## Todos — eng-backend (F2: 3 tickets)`).

Ambiguity that cannot be resolved from the PRD, exec-table, or codebase scan is surfaced as a named gap in §12 (Findings) — never resolved by assumption.
