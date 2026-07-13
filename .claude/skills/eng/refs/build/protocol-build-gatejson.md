---
name: eng --build — gate-json source
description: Lazily loaded when eng --build is invoked with gate-json=<path>. Defines the bug-list (issue-ticket) build source — required fields, rejections, path derivation, branch defaulting, work-step deltas, Issue-keyed summary, and loop-closing. A plain PRD/exec-table --build never loads this.
type: reference
---

# eng --build — `gate-json` source

Loaded only when `--build` is invoked with `gate-json=<path>` (see `protocol.md` § Input contract). Drives the build from a `/pre-merge` gate fail-ticket instead of an exec-table. The spec is a **bug list**, not a feature to build, so there is no red test to write — it already exists (it's literally what `/pre-merge` recorded).

## Required fields and rejections

| Field | Value |
|-------|-------|
| mode flag | `--build` |
| `gate-json` | Path to the `msg-gate/gate-N.json` file whose `issues[]` this build resolves |
| `branch` | Feature branch the commits land on. Defaults to the file's own `context.branch` when not passed (see **Branch default**); must still exist before work starts |
| `agent` | *(optional)* Defaults to a single generic identity `eng-fix` — a bug list has no roster to assign owners from |

- `gate-json` is a **`--build`-only** source. `--plan` with `gate-json` is a hard failure: `Hard failure: gate-json is a --build-only input source`.
- Supplying **both `prd-path` and `gate-json`** is a hard failure — ambiguous input source: `Hard failure: pass either prd-path+rows or gate-json, not both (ambiguous input source).`
- A `gate-json` path that does not exist or cannot be parsed as JSON is an input-validation failure (`Hard failure: gate-json <path> not found or unparseable`) — the findings can't be projected, so there is nothing to build.

**Path derivation.** Eng derives all *implementation* file paths from the codebase scan and the projected issue-tickets. `gate-json`'s `issues[].file` is where a *symptom* was observed, **not** a command to blindly edit that path — Step 2's codebase scan and Step 6's scope enforcement still run per issue exactly as they do per row.

**Branch default.** When build is driven by `gate-json` and `branch` is not explicitly passed, default it to the file's own `context.branch` — the branch `/pre-merge` was gating when it found the issues — rather than asking the user to repeat what the file records. The `branch`-must-exist rule (`protocol.md` Work-step 1) still applies unchanged: a defaulted branch that doesn't exist is still a hard failure.

## Work-step deltas (Step 5)

The numbered Work steps in `protocol.md` still run, with these deltas:

- **Item 0 is skipped entirely.** There is no exec-table and no `## Engineering —` section to cross-check against.
- **Item 2 reads each issue, not Execution steps.** For each projected issue-ticket (from Step 2's projection of `issues[]`), read the finding's `message`, `evidence.snippet`, and `repro` — that triad *is* the spec for the fix.
- **Item 4's TDD flow collapses from four phases to three**, because the failing test already exists. Per issue, in `priority` order (`P0`→`P1`→`P2`; findings carry no `depends-on`, so priority alone orders them):
  - **(a) reproduce** — run the issue's `repro` command (or exercise the covering test) and confirm it still fails the same way. This replaces "write tests" + "verify red".
  - **(b) fix** — implement the change, applying the Step 4 coding standards (injected payload, or `/cook` on a standalone run) exactly as today (Item 4c).
  - **(c) verify green** — re-run `repro`, then the covering test file, same as the existing verify-green phase (Item 4d). A still-failing issue enters Debug mode (`protocol-build-debug.md`) unchanged.
- **Flaky issues are not forced.** An issue carrying `evidence.flaky: true` (a `--flaky <N>`-classified warning, not a confirmed break) is fixed **only if phase (a) surfaces a clear, reproducible root cause**. If it won't reproduce, leave it noted in the build summary (`⚠ flaky — not reproduced, left as-is`) rather than forcing a green — that is the whole point of flaky-classification.
- **Debug mode and its 3-cycle escalation apply per issue**, exactly as they do per row (see `protocol-build-debug.md`).
- **The build summary table is keyed by `Issue`** (below) and, on completion, `eng --build` **writes the loop closed** in the `gate-json` file (below).

## Output contract — table keyed by `Issue`

When the build was driven by `gate-json`, swap the summary table's **`Row`** column for **`Issue`** (the finding `id`, e.g. `unit-002`); keep `Files created`, `Files modified`, `Tests`, and `Status` as-is:

```markdown
| Issue | Files created | Files modified | Tests | Status |
|-------|--------------|---------------|-------|--------|
| <finding-id> | — | `<path>` | ✅ repro green | ✅ Done |
```

## Closing the loop

On completion, `eng --build` **updates the `gate-json` file's own `followUp.status`** (camelCase — the key `server.py`/the `--gui` board reads) so the ticket reflects that it was acted on rather than sitting permanently `open`:

- every issue verified green → `"resolved"`
- one or more issues escalated (3-cycle debug escalation) or left unreproduced (flaky) → `"partially_resolved"`

This is the **only** write build mode makes to `msg-gate/gate-<n>.json`; the `issues[]` array and every other field stay untouched (the file remains canonical findings — the projection was read-time only). The `--gui` board reads this `followUp.status` back to render an honest Open/Resolved state per gate-issue card.

## The `kind` discriminator

Every ticket — whether it originates from a PRD feature (a `## Todos` `### F<n>` block, schema in `refs/plan/template-todo.md`) or from a `/pre-merge` gate finding (the projection below) — carries a `kind` field so a consumer (`--build`, the `--gui` board) can always tell a build todo apart from a bug:

| `kind` | Origin | Id shape |
|--------|--------|----------|
| `"todo"` | a PRD `## Todos` `### F<n>` block (`refs/plan/template-todo.md`) | `F<n>-T<k>` |
| `"issue"` | a canonical finding in `msg-gate/gate-<n>.json` (the projection below) | the finding `id`, e.g. `unit-002` |

A ticket with no explicit `kind` is a `"todo"` (back-compat). The id shape alone is a secondary signal — an `F<n>-T<k>` id is a todo, any other shape is an issue — but `kind` is authoritative.

## Finding → issue-ticket projection

`msg-gate/gate-<n>.json` (written by `/pre-merge` on a non-clean verdict) stores **canonical finding objects** — the same shape `/pre-merge` emits, defined in `../../../shared/refs/finding-schema.md`. To let `eng --build` walk those findings with the same ticket vocabulary a PRD-todo build uses, and to let the `--gui` board render them beside PRD todos, each finding is **projected** into an issue-ticket through the single mapping below.

This projection is cited by **both** `eng --build` (its `gate-json` input path — this file) and the `--gui` board (`msg/refs/protocol-gui.md` Step 1b). Defining it once here keeps the two consumers from drifting.

**It is a read-time view, never a rewrite.** `msg-gate/gate-<n>.json` stays canonical findings on disk — the projection is applied in memory each time a finding is consumed. Findings are never re-serialized into ticket shape, so the `/pre-merge` ↔ `eng --build` interop and the shared dedup/regression keys (`id`, `rule`, `regression_of`) are untouched.

### Field mapping

| Issue-ticket field | Source (canonical finding) |
|--------------------|----------------------------|
| `kind` | literal `"issue"` |
| `id` | finding `id` **verbatim** (`unit-002`) — its non-`F<n>-T<k>` shape itself signals an issue, and keeps `depends-on`/dedup handles stable |
| `title` | finding `message` |
| `objective` | synthesized `Restore correct behavior — <message>` (prefer `suggestion` when present). Does **not** trace to a PRD user story — a bug's intent is the fix, and `context.prd` is often `null` |
| `type` | mapped from `category`: test buckets (`unit`, `e2e`, `functional`, `qa`, `a11y`, `api`, `mobile`, `coverage`, `load`, `perf`, `integration`, `contract`) → `test`; code/security concerns (`security`, `performance`, `complexity`, …) → `code` |
| `priority` | mapped from `severity`: `blocker`→`P0`, `high`→`P1`, `medium`/`low`→`P2` |
| `files` | `[{ path: <finding.file>, action: "edit" }]`, or `[]` when `file` is `null` (suite-level finding). `action` is always `edit` — `file` is where the *symptom* was observed, not a command to edit that path; Step 2's codebase scan still resolves the real target |
| `depends-on` | `none` — findings carry no dependency graph |
| `done-when` | `<repro> passes and the covering test file is green` (from `repro`; when `repro` is `null`, `the finding no longer reproduces`) |

### Preserved diagnostic fields

A todo has no slot for these, but a bug needs them for the fix flow and the GUI side panel, so they ride **alongside** the projected fields on the issue-ticket (copied verbatim from the finding, never dropped):

`severity`, `category`, `source`, `rule`, `evidence.snippet`, `repro`, `regression_of`, `suggestion`, and `evidence.flaky`.

`source` is the originating gate stage (`pre-merge:mechanical`, `pre-merge:bucket:e2e`, …); the `--gui` board renders it as a per-issue gate-step badge, so it must survive the projection.

`evidence.flaky: true` in particular changes how `eng --build` treats the ticket (fix only if a reproducible root cause surfaces — see § Work-step deltas above) and how `--gui` tags it, so it must survive the projection.
