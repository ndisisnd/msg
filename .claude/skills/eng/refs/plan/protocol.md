# eng — Mode: --plan

Reads the assigned PRD exec-table rows and, in a **single pass**, produces (1) a structured `## Engineering — <Agent>` section, (2) the `## Todos — <Agent>` tickets that decompose each owned F-ID into build-ready units — **the single and final build spec** — and (3) the exec-table cells that index them (Execution steps = ticket-id pointer, Files = the tickets' file set). **No implementation code is written.**

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

Cover only the features implied by the assigned rows. Every section of the chosen shape is required — write `None.` only when a subsection genuinely does not apply.

### Which shape — tier on the intake grade

The engineering section has **two shapes**, and the PRD's size picks one. The template owns the section lists; this is the rule that selects between them:

| Intake complexity grade | Shape | Sections |
|-------------------------|-------|----------|
| `C:` **< 8**, or unresolvable | **Medium — the default** | 4: Design decisions · Integration contracts · Scope mapping · Open questions |
| `C:` **≥ 8** | Large | 12: the medium four plus Summary, PRD reference, Alternatives considered, Phases and dependencies, Developer experience, Migration and breaking changes, Risks and mitigations, Findings — PRD gaps |

**How to resolve the grade.** The PRD frontmatter carries `intake: #<n>` — the row id in the root `INTAKE.md` ledger, whose **grade** cell reads `C:<band> T:<band> S:<sequencing>`. Read the `C:` band from that row. On an orchestrated run `plan-em` resolves it once and injects it with the scoped context; prefer the injected value over re-reading the ledger.

**Default to medium.** No `intake:` key, no matching row, an unparseable grade, or no `INTAKE.md` → write the medium shape. Never write the large shape defensively: the eight extra sections have no downstream consumer (build agents read tickets, never plan prose), and not writing them is the point of the tier.

Both shapes validate. `script-eng-plan-shape.py` check 8 accepts either, and PRDs already carrying the older 12- or 13-section shape keep passing untouched.

Also fill in the **Execution steps** and **Files** columns for every row in the PRD's execution table where the Agent column matches this invocation — after the tickets are written, since Execution steps is a pointer to their ids (`→ F2-T1, F2-T2`) and Files is the union of their `files`. Format and rules: `refs/build/protocol-exec.md`.

**Exact identifier requirement (hard):** Every proposed change must name the precise artifact to be modified or created, verified against the codebase scan:

| Artifact | Required precision |
|----------|--------------------|
| Functions / methods | Exact name as it appears in source (e.g. `createStreak`, not "the streak creation function") |
| DB tables | Exact table name (e.g. `streaks`, not "a streaks table") |
| DB columns | Exact column names and types (e.g. `user_id UUID NOT NULL`) |
| Migration file | Exact filename following repo convention (e.g. `0043_add_streaks.sql`) |
| API endpoints | Exact HTTP method + path matching existing route conventions (e.g. `POST /api/v1/streaks`) |
| API / RPC operation names | Exact operation name as defined in OpenAPI spec or router |

Getting any identifier wrong is a hard failure — build agents execute against them directly and wrong names cause expensive rework. If the exact name cannot be confirmed from the codebase scan, mark it as a named gap in **Open questions** (medium shape §4; large shape §11 Findings — PRD gaps), not a guess.

**Identifiers land on tickets, not in prose.** Build agents execute the **tickets** and nothing else — they never read the Integration-contracts prose. So every exact identifier this agent owns must appear in some ticket's `files` / `done-when` (the rule below), and Integration contracts carries only what a ticket cannot: the cross-agent contract tables and the auth-flow narrative. Do not restate a ticket's identifiers there as a second copy; one spec, one place.

**Return contract:** Write the complete engineering section directly to the PRD file at `prd-path`, appended under `## Engineering — <Agent Name>` (the agent identity for this invocation — the literal `— <Agent Name>` suffix is required; `plan-em` detects build mode by this heading). Do not create a separate output file. Emit a one-line confirmation after writing (e.g. `Written to features/prd-4/prd-4.md → ## Engineering — eng-backend`).

### Todo tickets — written in the same pass

After the engineering section is written, decompose every owned F-ID into `F<n>-T<k>` tickets under a `## Todos — <Agent Name>` block, in the **same pass** — there is no separate todo mode. Read `refs/plan/template-todo.md` fully before writing any ticket; it owns the schema (ids, the seven fields, rendering, rules, the empty-block sentinel, and the ticket-sizing rule) and `eng --build` reads these blocks mechanically, so the shape must match it exactly.

- Use this agent's own `## Engineering — <Agent Name>` section (integration contracts, exact identifiers) as the authority on *how*, and the PRD's Features & acceptance criteria F-ID table as the authority on *which* F-IDs are in scope and *why*. Do not re-interpret the features section independently of the engineering section you just wrote.
- Append the agent's `## Todos — <Agent Name>` block under the `## Todos` umbrella heading (created by `plan-em` before the plan wave — do **not** create the umbrella yourself), one `### F<n>` block per owned feature in F-ID order. A feature with no discrete work still gets an explicit `_No discrete work for this feature._` block.
- Every exact identifier this agent owns in Integration contracts (endpoint, table, column, migration filename, test file, webhook/hook) must surface in some ticket's `files` + `done-when`.
- **Then fill the exec-table cells** (§ Output contract above): each owned row's Execution steps pointer and Files set, derived from the tickets just written.

Extend the write confirmation to note the tickets (e.g. `Written to features/prd-4/prd-4.md → ## Engineering — eng-backend + ## Todos — eng-backend (F2: 3 tickets)`).

Ambiguity that cannot be resolved from the PRD, exec-table, or codebase scan is surfaced as a named gap in **Open questions** (medium §4 / large §11) — never resolved by assumption.

---

## Closing check — validate the plan's shape mechanically

The plan's three outputs (engineering section, tickets, exec-table cells) are bound together by contracts that all fail **silently** — a dangling ticket pointer, a cyclic `depends-on`, or a guessed file path produce a plausible-looking plan that only explodes during the build wave. Do not grade them by eye. After the write confirmation, run:

```bash
V=.claude/scripts/script-eng-plan-shape.py; [ -f "$V" ] || V="$HOME/.claude/scripts/script-eng-plan-shape.py"; python3 "$V" "<prd-path>" --agent "<Agent Name>"
```

Exit 0 (`SUMMARY … failures=0`) means the pass is shape-clean. Exit 1 prints one `FAIL check=<n> code=<slug> ref=<locator> detail=…` line per defect; **fix every one and re-run** — the pass is not done while any FAIL stands. The eight checks: both contract headings byte-exact · the ticket schema · `### F<n>` blocks ↔ the exec-table F-IDs this agent owns · `depends-on` resolves and is acyclic · the empty-feature sentinel · every Execution-steps pointer resolves and every ticket is pointed at · **files-vs-reality** (`(edit)`/`(remove)` paths must exist, `(add)` paths must not — this is what catches a guessed or stale identifier) · **the engineering section's shape** is one of the two sanctioned ones (check 8: the medium four, or the large twelve — a missing core section or an invented heading fails; a section with no `###` subheadings at all is skipped, not failed).

A defect the script cannot fix — a genuinely unresolvable path or F-ID — is surfaced as a named gap in **Open questions** (medium §4 / large §11), never left as a silent FAIL.
