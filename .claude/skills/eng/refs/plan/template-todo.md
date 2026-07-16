# Todo Ticket Schema

Defines the `## Todos — <Agent>` ticket schema that `eng --plan` writes (in the same pass as the `## Engineering — <Agent>` section) and `eng --build` consumes. A ticket turns a slice of the confirmed design into a discrete, agent-executable unit of work — modelled on a JIRA / Linear ticket (minus estimation / story points): it states the product objective it serves, the files it touches, what it depends on, and the concrete check that says it's done. A build agent must be able to pick up one ticket and work it end-to-end without re-reading the design prose.

---

## Where todos live

Todos are appended to the **PRD file** (the same file the `## Engineering — <Agent>` sections go in), never a separate file. The structure:

```markdown
## Todos

## Todos — <Agent Name>

### F1
- **F1-T1 — Add streaks table**
  - **objective:** Let users see a daily streak so they stay motivated (F1 acceptance: streak count persists across days).
  - **type:** migration
  - **files:** `migrations/0043_add_streaks.sql` (add), `models/streak.py` (edit)
  - **depends-on:** none
  - **done-when:** migration applies cleanly on a fresh DB; `streaks` table exists with `user_id UUID`, `count INT`, `updated_at TIMESTAMPTZ`.
- **F1-T2 — Streak increment endpoint**
  - **objective:** Record a streak bump when a user completes their daily goal.
  - **type:** code
  - **files:** `routes/streaks.py` (add), `openapi.yaml` (edit)
  - **depends-on:** F1-T1
  - **done-when:** `POST /api/v1/streaks/increment` returns 200 and increments `count`; contract test passes.

### F2
- _No discrete work for this feature._
```

- `## Todos` — the umbrella section, appended **once**, after the execution-table skeleton. It gives the `todos-` anchor namespace the execution table's Todos column points into (`#todos-f1`, `#todos-f2`, …). `plan-em` creates this heading before dispatching the plan wave; agents do not create it.
- `## Todos — <Agent Name>` — one per agent, mirroring the `## Engineering — <Agent>` convention exactly (the literal `— <Agent Name>` suffix is required). Detection scans for this literal heading (`## Todos —`).
- `### F<n>` — one subsection per feature the agent owns, holding that feature's tickets. The F-ID matches the PRD's Features & acceptance criteria table and the execution-table rows.

---

## Ticket schema

Each ticket is a bullet whose title line carries the ticket id and summary, followed by an indented field list. Fields, in order:

| Field | Values | Meaning |
|-------|--------|---------|
| `id` | `F<n>-T<k>` | Stable ticket id, feature-scoped and 1-based per feature (`F1-T1`, `F1-T2`, `F2-T1`). The handle `depends-on` references and the build summary checks off. On the title line: `**F1-T1 — <title>**`. |
| `title` | short phrase | One-line summary of the unit of work — what a reviewer reads in a ticket list. On the title line after the id. |
| `objective` | one sentence | The **product / user goal** this ticket serves — traces to the PRD feature's user story or acceptance criterion (the "why"). Keeps the build agent anchored to intent, not just mechanics. |
| `type` | `code \| test \| config \| migration \| doc` | The kind of work. |
| `files` | `` `path` (add\|edit\|remove) ``, comma-separated | The file(s) touched, each tagged with its own action. Exact repo-relative paths where known (same precision bar as `--plan` §7 identifiers). |
| `depends-on` | ticket id(s), or `none` | Other tickets that must complete **before** this one (e.g. an endpoint depends on its migration). `none` when independent. Only reference ids that exist in the same PRD's `## Todos`. |
| `done-when` | a concrete, verifiable check | The acceptance condition — a build agent can run or inspect exactly this to confirm the ticket is done. Never vague ("works correctly"); always checkable. |

**Deliberately not an estimate** — there is no story-point / sizing field in this schema.

**Rendering** — one ticket per top-level bullet, fields as an indented sub-list, label-prefixed so a build agent (and the `--gui` parser) reads them positionally:

```
- **<id> — <title>**
  - **objective:** <one sentence>
  - **type:** <type>
  - **files:** `<path>` (<action>), `<path>` (<action>)
  - **depends-on:** <id(s) | none>
  - **done-when:** <check>
```

---

## Rules

1. **A ticket is a unit of work, not a single file edit.** Group the files that must change together to deliver one coherent objective into one ticket; split when objectives, dependencies, or acceptance checks genuinely differ. Prefer a ticket a build agent can complete and verify in one pass.
2. **Ticket sizing — a coherent reviewable unit, not a line count.** Scope every `F<n>-T<k>` ticket to one reviewable objective — split it when the objective, dependencies, or acceptance checks would otherwise span unrelated concerns. Never scope or split a ticket against a predicted LOC number: a line count guessed before the code exists is exactly the fake-precise estimate `intake/refs/rubric.md` forbids. LOC becomes a real, measured fact only once a diff exists — that's the build agent's judgment call at the commit gate (`eng-commit-cap.sh`), not a plan-time criterion.
3. **Every ticket names its objective.** The `objective` traces to a specific PRD feature user story or acceptance criterion. A ticket whose objective can't be tied back to the feature's intent is a decomposition error — reconcile it against the `## Engineering — <Agent>` section, don't invent scope.
4. **Ids are stable and unique per PRD.** `F<n>-T<k>` — numbered 1-based within each feature. Ids are the dependency graph's nodes; never reuse or renumber an id once other tickets or the build summary reference it.
5. **`depends-on` references real ids only.** Every id in a `depends-on` must exist elsewhere in the same `## Todos`. A dangling dependency is a coverage gap, not silently written. Dependencies must be **acyclic** — a build agent walks them in order.
6. **`done-when` is verifiable.** Every `done-when` names something concrete a build agent can check — a command, an assertion, a file-state condition. A `done-when` that can't be checked is a defect, not a ticket.
7. **Empty features are explicit.** A feature whose scope yields no discrete work still gets a `### F<n>` block containing the single line `_No discrete work for this feature._` — never a missing block. This keeps the execution table's `#todos-f<n>` anchor resolvable.
8. **F-IDs stay aligned with the exec table.** Every `### F<n>` under `## Todos` must correspond to an F-ID that has execution-table rows, and vice versa. A mismatch is a coverage gap.
9. **Ticket, not narrative.** Keep each ticket to its fields. Design rationale belongs in the `## Engineering — <Agent>` section; the ticket carries only what's needed to execute and verify it.

A ticket with no explicit `kind` is a `"todo"`; the finding→issue-ticket projection that `eng --build report=features/prd-<N>-<slug>/reports/report-prd-<N>-<K>.json` consumes lives in `refs/build/report-fix.md`.
