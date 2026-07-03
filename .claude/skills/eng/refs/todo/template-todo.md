# Todo Schema Template

Defines the schema `--todo` mode writes and `--build` mode consumes. The todo layer sits between the design-level `## Engineering — <Agent>` plan and the build: it turns a confirmed design into a set of discrete, agent-executable **tickets** — each modelled on a typical engineering JIRA / Linear ticket (minus estimation / story points). A ticket is a self-contained unit of work: it states the product objective it serves, the files it touches, what it depends on, and the concrete check that says it's done. A build agent must be able to pick up one ticket and work it end-to-end without re-reading the design prose.

---

## Where todos live

Todos are appended to the **PRD file** (the same file `--plan` wrote `## Engineering — <Agent>` sections to), never to a separate file. The structure is:

```markdown
## Todos

## Todos — <Agent Name>

### F1
- **F1-T1 — Add streaks table**
  - **objective:** Let users see a daily streak so they stay motivated (F1 acceptance: streak count persists across days).
  - **type:** migration · **priority:** P0
  - **files:** `migrations/0043_add_streaks.sql` (add), `models/streak.py` (edit)
  - **depends-on:** none
  - **done-when:** migration applies cleanly on a fresh DB; `streaks` table exists with `user_id UUID`, `count INT`, `updated_at TIMESTAMPTZ`.
- **F1-T2 — Streak increment endpoint**
  - **objective:** Record a streak bump when a user completes their daily goal.
  - **type:** code · **priority:** P0
  - **files:** `routes/streaks.py` (add), `openapi.yaml` (edit)
  - **depends-on:** F1-T1
  - **done-when:** `POST /api/v1/streaks/increment` returns 200 and increments `count`; contract test passes.

### F2
- _No discrete work for this feature._
```

- `## Todos` — the umbrella section, appended **once** after the last `## Engineering — <Agent>` section. It gives the `todos-` anchor namespace the execution table's Todos column points into (`#todos-f1`, `#todos-f2`, …). `plan-em` creates this heading before dispatching todo agents; agents do not create it.
- `## Todos — <Agent Name>` — one per agent, the per-agent sub-heading, mirroring the `## Engineering — <Agent>` convention exactly. Detection scans for this literal heading (`## Todos —`); the todo phase is not complete until every agent that wrote an engineering section has a matching `## Todos —` block.
- `### F<n>` — one subsection per feature the agent owns, holding that feature's tickets. The F-ID matches the PRD's §3 feature table and the execution-table rows.

---

## Ticket schema

Each ticket is a bullet whose title line carries the ticket id and summary, followed by an indented field list. Fields, in order:

| Field | Values | Meaning |
|-------|--------|---------|
| `id` | `F<n>-T<k>` | Stable ticket id, feature-scoped and 1-based per feature (`F1-T1`, `F1-T2`, `F2-T1`). The handle `depends-on` references and the build summary checks off. Written on the title line: `**F1-T1 — <title>**`. |
| `title` | short phrase | One-line summary of the unit of work — what a reviewer would read in a ticket list. On the title line after the id. |
| `objective` | one sentence | The **product / user goal** this ticket serves — traces to the PRD feature's user story or acceptance criterion (the "why"). Keeps the build agent anchored to intent, not just mechanics. |
| `type` | `code \| test \| config \| migration \| doc` | The kind of work. |
| `priority` | `P0 \| P1 \| P2` | Build-order / importance signal — `P0` blocks the feature, `P1` is core, `P2` is nice-to-have. **Deliberately not an estimate** — there is no story-point / sizing field. |
| `files` | `` `path` (add\|edit\|remove) ``, comma-separated | The file(s) touched, each tagged with its own action. A ticket may touch several files with different actions. Exact repo-relative paths where known (same precision bar as `--plan` §7 identifiers). |
| `depends-on` | ticket id(s), or `none` | Other tickets that must complete **before** this one (e.g. an endpoint depends on its migration). `none` when the ticket is independent. Only reference ids that exist in the same PRD's `## Todos`. |
| `done-when` | a concrete, verifiable check | The acceptance condition — a build agent can run or inspect exactly this to confirm the ticket is done (a passing assertion, a migration that applies, an endpoint returning the expected shape). Never vague ("works correctly"); always checkable. |

**Rendering** — one ticket per top-level bullet, fields as an indented sub-list, label-prefixed so a build agent (and the `--gui` parser) can read them positionally:

```
- **<id> — <title>**
  - **objective:** <one sentence>
  - **type:** <type> · **priority:** <P0|P1|P2>
  - **files:** `<path>` (<action>), `<path>` (<action>)
  - **depends-on:** <id(s) | none>
  - **done-when:** <check>
```

---

## Rules

1. **A ticket is a unit of work, not a single file edit.** Group the files that must change together to deliver one coherent objective into one ticket; split into separate tickets when the objectives, dependencies, or acceptance checks genuinely differ. Prefer a ticket a build agent can complete and verify in one pass.
2. **Every ticket names its objective.** The `objective` traces to a specific PRD feature user story or acceptance criterion. A ticket whose objective can't be tied back to the feature's intent is a decomposition error — reconcile it against the `## Engineering — <Agent>` section, don't invent scope.
3. **Ids are stable and unique per PRD.** `F<n>-T<k>` — numbered 1-based within each feature. Ids are the dependency graph's nodes; never reuse or renumber an id once other tickets or the build summary reference it.
4. **`depends-on` references real ids only.** Every id in a `depends-on` must exist elsewhere in the same `## Todos`. A dangling dependency is a coverage gap surfaced by `protocol-todo.md`, not silently written. Dependencies must be acyclic — a build agent walks them in order.
5. **`done-when` is verifiable.** Every `done-when` names something concrete a build agent can check — a command, an assertion, a file-state condition. A `done-when` that can't be checked is a defect, not a ticket.
6. **Empty features are explicit.** A feature whose scope yields no discrete work still gets a `### F<n>` block containing the single line `_No discrete work for this feature._` — never a missing block. This keeps the execution table's `#todos-f<n>` anchor resolvable.
7. **F-IDs stay aligned with the exec table.** Every `### F<n>` under `## Todos` must correspond to an F-ID that has execution-table rows, and vice versa. A mismatch is a coverage gap surfaced by `protocol-todo.md`.
8. **Ticket, not narrative.** Keep each ticket to its fields. Design rationale belongs in the `## Engineering — <Agent>` section; the ticket carries only what's needed to execute and verify it.

---

## The `kind` discriminator

Every ticket — whether it originates from a PRD feature (`--todo` mode above) or from a test/review finding (below) — carries a `kind` field so a consumer (`--build`, the `--gui` board) can always tell a build todo apart from a bug:

| `kind` | Origin | Id shape |
|--------|--------|----------|
| `"todo"` | a PRD `## Todos` `### F<n>` block (the schema above) | `F<n>-T<k>` |
| `"issue"` | a canonical finding in `msg-test/test-<n>.json` (the projection below) | the finding `id`, e.g. `unit-002` |

A ticket with no explicit `kind` is a `"todo"` (back-compat: every `## Todos` block written before this field existed is a todo). The id shape alone is a secondary signal — an `F<n>-T<k>` id is a todo, any other shape is an issue — but `kind` is authoritative.

---

## Finding → issue-ticket projection

`msg-test/test-<n>.json` (written by `/test` Step 6) stores **canonical finding objects** — the same shape `/review` and `/pre-merge` emit, defined in `../../shared/refs/finding-schema.md`. To let `eng --build` walk those findings with the same ticket vocabulary a `--todo` build uses, and to let the `--gui` board render them beside PRD todos, each finding is **projected** into an issue-ticket through the single mapping below.

This projection is cited by **both** `eng --build` (its `test-json` input path — see `refs/build/protocol.md`) and the `--gui` board (`msg/refs/protocol-gui.md` Step 1b). Defining it once here keeps the two consumers from drifting.

**It is a read-time view, never a rewrite.** `msg-test/test-<n>.json` stays canonical findings on disk — the projection is applied in memory each time a finding is consumed. Findings are never re-serialized into ticket shape, so `/review`↔`/test`↔`/pre-merge` interop and the shared dedup/regression keys (`id`, `rule`, `regression_of`) are untouched.

### Field mapping

| Issue-ticket field | Source (canonical finding) |
|--------------------|----------------------------|
| `kind` | literal `"issue"` |
| `id` | finding `id` **verbatim** (`unit-002`) — its non-`F<n>-T<k>` shape itself signals an issue, and keeps `depends-on`/dedup handles stable |
| `title` | finding `message` |
| `objective` | synthesized `Restore correct behavior — <message>` (prefer `suggestion` when present). Does **not** trace to a PRD user story — a bug's intent is the fix, and `context.prd` is often `null` |
| `type` | mapped from `category`: test buckets (`unit`, `e2e`, `functional`, `qa`, `a11y`, `api`, `mobile`, `coverage`, `load`, `perf`, `integration`, `contract`) → `test`; review concerns (`security`, `performance`, `complexity`, …) → `code` |
| `priority` | mapped from `severity`: `blocker`→`P0`, `high`→`P1`, `medium`/`low`→`P2` |
| `files` | `[{ path: <finding.file>, action: "edit" }]`, or `[]` when `file` is `null` (suite-level finding). `action` is always `edit` — `file` is where the *symptom* was observed, not a command to edit that path; Step 2's codebase scan still resolves the real target |
| `depends-on` | `none` — findings carry no dependency graph |
| `done-when` | `<repro> passes and the covering test file is green` (from `repro`; when `repro` is `null`, `the finding no longer reproduces`) |

### Preserved diagnostic fields

A todo has no slot for these, but a bug needs them for the fix flow and the GUI side panel, so they ride **alongside** the projected fields on the issue-ticket (copied verbatim from the finding, never dropped):

`severity`, `category`, `rule`, `evidence.snippet`, `repro`, `regression_of`, `suggestion`, and `evidence.flaky`.

`evidence.flaky: true` in particular changes how `eng --build` treats the ticket (fix only if a reproducible root cause surfaces — see `refs/build/protocol.md`) and how `--gui` tags it, so it must survive the projection.
