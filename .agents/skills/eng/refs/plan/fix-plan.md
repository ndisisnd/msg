---
name: eng --plan — issues-file source
description: Lazily loaded when eng --plan is invoked with report=<path>. Defines the fix-plan source — required fields, rejections, the read-time finding→issue-ticket projection (cited, not duplicated), the report-prd-<N>-<K>-fix-plan.md output in fix-execution-table + fix-ticket form, and the per-ticket complexity tag the orchestrated fix-build reads. A plain PRD/exec-table --plan never loads this.
type: reference
---

# eng --plan — issues-file source

Loaded only when `--plan` is invoked with `report=<path>` (see `../../SKILL.md` § Input contract). Plans the fixes for a `/pre-merge` (or `/merge`) failed run instead of decomposing PRD exec-table rows. The spec is a **bug list** — canonical findings already recorded in the issues file `report-prd-<N>-<K>.json` — so this pass produces no `## Engineering —` section and no PRD write: it projects the findings into fix tickets and emits a standalone **fix plan** the orchestrated fix-build (`../build/fix-build-orchestrated.md`) then executes.

This is the target of the fix loop's Offer #1 (`../../../shared/refs/fix-loop.md`), invoked as `eng --plan report=features/prd-<N>-<slug>/reports/report-prd-<N>-<K>.json`.

## Required fields and rejections

| Field | Value |
|-------|-------|
| mode flag | `--plan` |
| `report` | Path to the issues file `report-prd-<N>-<K>.json` whose `issues[]` this plan fixes |
| `agent` | *(optional)* Defaults to a single generic identity `eng-fix` — a bug list has no roster to assign owners from (same default the `report` build uses) |

- Supplying **both `prd-path` and `report`** is a hard failure — ambiguous input source: `Hard failure: pass either prd-path+rows or report, not both (ambiguous input source).`
- Input validity is **mechanical, not eyeballed**: `script-project-findings.py` (below) is the validator and the projector in one call. Its non-zero exits are the three rejections — `Hard failure: report <path> not found or unparseable` (missing/unparseable), `Hard failure: report <path> has no findings to plan` (empty `issues[]`, and a clean run never writes an issues file so an empty one is malformed input, not a no-op), and `Hard failure: report <path> finding <id|index> is malformed: <detail>` (a finding missing a required field of `../../../shared/refs/finding-schema.md` — `id`, `source`, `severity`, `category`, `rule`, `message`). Emit the printed line verbatim and stop; a malformed finding can't be projected or complexity-graded.

**No file paths as input.** As in a PRD `--plan`, eng derives file paths from the codebase scan and the projected tickets, never from input. A finding's `file` marks where the *symptom* was observed, not a path to edit — it rides onto the ticket's `files` (below) but the fix-build's Step 2 scan still resolves the real target.

## Reading the issues file + projection

Project each entry of `issues[]` into an issue-ticket by running the **single** projection implementation — `.claude/scripts/script-project-findings.py`, cited by `../build/fix-build.md` § Finding → issue-ticket projection (field mapping + preserved diagnostic fields + the `kind` discriminator live in its docstring):

```bash
P=.claude/scripts/script-project-findings.py; [ -f "$P" ] || P="$HOME/.claude/scripts/script-project-findings.py"; python3 "$P" "<report-path>"
```

**Do not re-derive the mapping and do not re-serialize the findings** — the script only reads, so the issues file stays canonical on disk. This plan pass consumes exactly the tickets the build pass consumes, then writes its own fix-plan artifact.

Each projected issue-ticket already carries `kind: "issue"`, its verbatim finding `id`, `title`, `objective`, `type`, `files`, `depends-on`, `done-when`, and the preserved diagnostic fields (`severity`, `category`, `source`, `rule`, `evidence.snippet`, `repro`, `regression_of`, `suggestion`, `evidence.flaky`). This pass adds exactly one field: the **`complexity` tag** (below).

## Fix-plan output — `report-prd-<N>-<K>-fix-plan.md`

Write the plan to `report-prd-<N>-<K>-fix-plan.md`, colocated in the same `reports/` folder as the input issues file and sharing its **exact stem — same `N` and `K`** (`report-prd-12-3.json` → `report-prd-12-3-fix-plan.md`). This is the only file this pass writes; there is no PRD to append to. Emit a one-line confirmation after writing (e.g. `Written to features/prd-12-<slug>/reports/report-prd-12-3-fix-plan.md → 4 fix tickets`).

The plan reuses the sibling **feature-execution-table** (`../../../plan-em/refs/template-exec-table.md`) and **ticket** (`template-todo.md`) formats, with the deltas below — mirroring how `../build/fix-build.md` swaps its summary columns for a bug list.

### Fix execution table

Same five-column shape as the exec table, with two column swaps for a bug list — **`Feature` → `Issue(s)`** and **`Agent` → `Complexity`** (a fix plan has no roster; the single `eng-fix` identity is implicit, so the fifth column carries the complexity tag the orchestrator routes on instead):

```markdown
## Fix execution table

| Issue(s) | Fix steps | Files | Ticket | Complexity |
|----------|-----------|-------|--------|-----------|
| unit-002 | reproduce → validate email presence before the DB write → verify green | `src/api/users.ts` | [unit-002](#fix-unit-002) | simple |
| sec-001, sec-004 | reproduce → move both keys to env + rotate → verify green | `src/lib/stripe.ts` | [fix-sec-credentials](#fix-sec-credentials) | complex |
```

- **Issue(s)** — the finding `id`(s) this row resolves. One id per row for the common case; a comma-separated list when the row is a coherent group (below).
- **Fix steps** — the reproduce → fix → verify-green shape the fix-build runs per issue (`../build/fix-build.md` § Work-step deltas). Left terse; the ticket's `repro`/`done-when` carry the exact commands.
- **Files** — the projected `files` path(s), repo-relative. Blank/`—` when every grouped finding is suite-level (`file: null`).
- **Ticket** — anchor into the `## Fix tickets` block below: `[<id>](#fix-<id>)` for a single issue, `[<group-slug>](#fix-<group-slug>)` for a group.
- **Complexity** — `simple` | `complex`, mirroring the ticket's own `complexity` field (below). The ticket field is authoritative; this column is the at-a-glance view.

### Fix tickets

One ticket per table row, in the same bullet + indented-field rendering as `template-todo.md`, under a `## Fix tickets` section (the fix-plan analog of `## Todos`). Because `kind` is `"issue"`, ids are the finding ids verbatim (or a group slug), **not** `F<n>-T<k>`:

```markdown
## Fix tickets

- **unit-002 — Assertion failed: POST /users with empty email did not return 400** <a id="fix-unit-002"></a>
  - **kind:** issue · **complexity:** simple
  - **objective:** Restore correct behavior — validate email presence before the DB write.
  - **type:** test
  - **files:** `src/api/users.ts` (edit)
  - **depends-on:** none
  - **done-when:** `rtk npx vitest run test/users.test.ts` passes and the covering test file is green.
  - **diagnostics:** severity `high` · category `unit` · source `pre-merge:unit-int` · rule `rejects blank email on POST /users` · repro `rtk npx vitest run test/users.test.ts`
```

- Every projected field is carried through unchanged; the preserved diagnostic fields ride on a single `diagnostics:` line so the fix-build (and the `--gui` side panel) read them positionally without bloating the ticket.
- `objective`, `done-when`, `files`, `depends-on` come straight from the projection — do not re-invent them. `depends-on` is `none` for a bug list (findings carry no dependency graph).
- A ticket with `evidence.flaky: true` keeps that on its `diagnostics:` line — it changes how the fix-build treats the ticket (fix only if a reproducible root cause surfaces).

### One ticket per issue, or per coherent group

Default to **one ticket per issue** — findings are already atomic. Group multiple findings into one ticket **only** when they are genuinely one unit of work: same `file` and same `rule`/`category` cluster, or a single root cause with several symptoms (e.g. two `sec-001`/`sec-004` credential findings in the same module fixed by one env-var move). A group ticket:

- lists every member id in the table's `Issue(s)` cell and carries a stable `fix-<slug>` id + anchor;
- takes the **highest** member `severity` and the **most conservative** member `complexity` (any `complex` member ⇒ the group is `complex`);
- keeps every member's diagnostics (list them per-member on the `diagnostics:` line).

Never group across unrelated files, categories, or root causes — the fix-build commits one issue's fix at a time, and an over-broad group breaks the one-commit-per-issue contract it inherits.

## Complexity tag (per ticket)

Tag **every** fix ticket `complexity: simple | complex`. The orchestrated fix-build reads this tag to route each fix to the right model tier and **falls back to grading itself if the tag is absent** — so absence degrades gracefully but is never the intended output.

**The rubric is defined once and it is executable** (`../build/fix-build-orchestrated.md` § Complexity rubric, implemented in `.claude/scripts/script-eng-fix-grade.py`). Do not grade by eye and do not restate the predicate here — run it:

```bash
G=.claude/scripts/script-eng-fix-grade.py; [ -f "$G" ] || G="$HOME/.claude/scripts/script-eng-fix-grade.py"; python3 "$G" "<report-path>"
```

Take each `GRADE … complexity=…` line as the ticket's tag. **You may escalate `simple` → `complex`, never downgrade `complex` → `simple`** — that is this pass's only power over the grade, and it is where the old rubric's judgment clause went. A group ticket is graded from its combined `files` set (pipe the group's ticket JSON in on `-`) and takes `complex` if any member is `complex`.

## References

- `../build/fix-build.md` — the canonical finding→issue-ticket projection + `kind` discriminator (cited above, not duplicated); the fix-build source that consumes this plan's tickets and `complexity` tags.
- `../build/fix-build-orchestrated.md` — the orchestrated per-issue fix-build (Offer #2) that reads each ticket's `complexity` tag and falls back to self-grading when absent.
- `template-todo.md` — the ticket schema/rendering reused above. `../../../plan-em/refs/template-exec-table.md` — the execution-table shape the fix table swaps columns on.
- `../../../shared/refs/finding-schema.md` — the canonical finding shape read from the issues file `report-prd-<N>-<K>.json`.
- `../../../shared/refs/fix-loop.md` — the post-failure offer sequence that invokes this pass (Offer #1) and the fix-build (Offer #2).
