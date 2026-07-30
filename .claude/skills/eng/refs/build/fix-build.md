---
name: eng --build — report source
description: Lazily loaded when eng --build is invoked with report=<path>. Defines the bug-list (issue-ticket) build source — required fields, rejections, path derivation, branch defaulting, work-step deltas, Issue-keyed summary, and loop-closing. A plain PRD/exec-table --build never loads this.
type: reference
---

# eng --build — `report` source

Loaded only when `--build` is invoked with `report=<path>` (see `protocol.md` § Input contract). Drives the build from a `/pre-merge` issues file instead of an exec-table. The spec is a **bug list**, not a feature to build, so there is no red test to write — it already exists (it's literally what `/pre-merge` recorded).

## Orchestration routing

`--build report=<path>` routes **by default** to `fix-build-orchestrated.md` — an Opus orchestrator session that projects `issues[]` into issue-tickets (§ Finding → issue-ticket projection below) and fans the fixes out to per-issue subagents. Pass `orchestrate=off` (`eng --build report=<path> orchestrate=off`) to skip the orchestrator and run the flat single-agent flow documented in the rest of this file instead. The orchestrated ref cites this file's projection and loop-closing sections rather than duplicating them.

## Required fields and rejections

| Field | Value |
|-------|-------|
| mode flag | `--build` |
| `report` | Path to the `report-prd-<N>-<K>.json` issues file whose `issues[]` this build resolves |
| `branch` | Feature branch the commits land on. Defaults to the file's own `context.branch` when not passed (see **Branch default**); must still exist before work starts |
| `agent` | *(optional)* Defaults to a single generic identity `eng-fix` — a bug list has no roster to assign owners from |
| `orchestrate` | *(optional)* Defaults to `on` (routes to `fix-build-orchestrated.md`, see § Orchestration routing above). `orchestrate=off` runs the flat flow documented in this file |

- `report` is valid on **both modes**: `--build` loads this file (or the orchestrated ref) to fix the findings, and `--plan report` loads `../plan/fix-plan.md` to plan them first. It is no longer build-only.
- Supplying **both `prd-path` and `report`** is a hard failure — ambiguous input source: `Hard failure: pass either prd-path+rows or report, not both (ambiguous input source).`
- Input validity is **not** eyeballed: `script-project-findings.py` (§ Finding → issue-ticket projection) is the validator, and it is the same call that produces the tickets. A missing, unparseable, empty, or malformed issues file is its non-zero exit — emit the `Hard failure:` line it prints and stop, since the findings can't be projected and there is nothing to build.

**Path derivation.** Eng derives all *implementation* file paths from the codebase scan and the projected issue-tickets. `report`'s `issues[].file` is where a *symptom* was observed, **not** a command to blindly edit that path — Step 2's codebase scan and Step 6's scope enforcement still run per issue exactly as they do per row.

**Branch default.** When build is driven by `report` and `branch` is not explicitly passed, default it to the file's own `context.branch` — the branch `/pre-merge` was gating when it found the issues — rather than asking the user to repeat what the file records. The `branch`-must-exist rule (`protocol.md` Work-step 1) still applies unchanged: a defaulted branch that doesn't exist is still a hard failure.

## Work-step deltas (Step 5)

The numbered Work steps in `protocol.md` still run, with these deltas:

- **Item 0 is skipped entirely.** There is no exec-table and no `## Engineering —` section to cross-check against.
- **Item 2 reads each issue, not Execution steps.** For each projected issue-ticket (from Step 2's projection of `issues[]`), read the finding's `message`, `evidence.snippet`, and `repro` — that triad *is* the spec for the fix.
- **Item 4's TDD flow collapses from four phases to three**, because the failing test already exists. Per issue, in `severity` order (`blocker`→`high`→`medium`→`low`; findings carry no `depends-on`, so severity alone orders them):
  - **(a) reproduce** — run the issue's `repro` command (or exercise the covering test) and confirm it still fails the same way. This replaces "write tests" + "verify red".
  - **(b) fix** — implement the change, applying the Step 4 coding standards (injected payload, or `/cook` on a standalone run) exactly as today (Item 4c).
  - **(c) verify green** — re-run `repro`, then the covering test file, same as the existing verify-green phase (Item 4d). A still-failing issue enters Debug mode (`protocol-build-debug.md`) unchanged.
- **Flaky issues are not forced.** An issue carrying `evidence.flaky: true` (a `--flaky <N>`-classified warning, not a confirmed break) is fixed **only if phase (a) surfaces a clear, reproducible root cause**. If it won't reproduce, leave it noted in the build summary (`⚠ flaky — not reproduced, left as-is`) rather than forcing a green — that is the whole point of flaky-classification.
- **Debug mode and its 3-cycle escalation apply per issue**, exactly as they do per row (see `protocol-build-debug.md`).
- **The build summary table is keyed by `Issue`** (below) and, on completion, `eng --build` **writes the loop closed** in the issues file (below).

## Output contract — table keyed by `Issue`

When the build was driven by `report`, swap the summary table's **`Row`** column for **`Issue`** (the finding `id`, e.g. `unit-002`); keep `Files created`, `Files modified`, `Tests`, and `Status` as-is:

```markdown
| Issue | Files created | Files modified | Tests | Status |
|-------|--------------|---------------|-------|--------|
| <finding-id> | — | `<path>` | ✅ repro green | ✅ Done |
```

## Closing the loop

On completion, `eng --build` records that the findings were acted on rather than leaving them permanently `open`, by updating the issues file's own `followUp.status`. **Never hand-edit the JSON** — run the one script that owns this write:

```bash
C=.claude/scripts/script-eng-close-loop.py; [ -f "$C" ] || C="$HOME/.claude/scripts/script-eng-close-loop.py"; python3 "$C" "<report-path>" resolved|partially_resolved
```

- every issue verified green → `resolved`
- one or more issues escalated (3-cycle debug escalation) or left unreproduced (flaky) → `partially_resolved`

This is the **only** write build mode makes to `report-prd-<N>-<K>.json`, and the script makes that physically true rather than promised: it splices the status into the original bytes, asserts everything outside that span is byte-identical and the reparsed document differs in no other field, then replaces the file atomically — any drift aborts before the write. Exit 0 prints `CLOSED …` + `VERIFIED …`; a non-zero exit prints a `Hard failure:` line to emit verbatim. The `--gui` board reads `followUp.status` back to render an honest Open/Resolved state per gate-issue card.

## The `kind` discriminator

Every ticket — whether it originates from a PRD feature (a `## Todos` `### F<n>` block, schema in `refs/plan/template-todo.md`) or from a `/pre-merge` gate finding (the projection below) — carries a `kind` field so a consumer (`--build`, the `--gui` board) can always tell a build todo apart from a bug:

| `kind` | Origin | Id shape |
|--------|--------|----------|
| `"todo"` | a PRD `## Todos` `### F<n>` block (`refs/plan/template-todo.md`) | `F<n>-T<k>` |
| `"issue"` | a canonical finding in `report-prd-<N>-<K>.json` (the projection below) | the finding `id`, e.g. `unit-002` |

A ticket with no explicit `kind` is a `"todo"` (back-compat). The id shape alone is a secondary signal — an `F<n>-T<k>` id is a todo, any other shape is an issue — but `kind` is authoritative.

## Finding → issue-ticket projection

`report-prd-<N>-<K>.json` (written by `/pre-merge` on a non-clean verdict) stores **canonical finding objects** — the shape defined in `../../../shared/refs/finding-schema.md`. To walk them with the same ticket vocabulary a PRD-todo build uses, each finding is **projected** into an issue-ticket.

**The projection has exactly one implementation:** `.claude/scripts/script-project-findings.py`. Run it; never re-derive the mapping by hand. Its module docstring is the field-mapping documentation (`kind`/`id`/`title`/`objective`/`type`/`files`/`dependsOn`/`doneWhen`, plus the preserved diagnostic fields `severity`, `category`, `source`, `rule`, `evidence.snippet`, `repro`, `regression_of`, `suggestion`, `flaky` that a todo has no slot for but the fix flow and the GUI side panel need). The `--gui` board (`msg/refs/protocol-gui.md` Step 1b) loads the same file, so the two consumers of this contract cannot drift.

```bash
P=.claude/scripts/script-project-findings.py; [ -f "$P" ] || P="$HOME/.claude/scripts/script-project-findings.py"; python3 "$P" "<report-path>"
```

**The script is also the input validator** — the required-fields and rejection checks above are its exit codes, not a manual read: exit 0 emits `{"file", "count", "tickets": […]}` on stdout; exit 2 prints `Hard failure: report <path> not found or unparseable`; exit 1 prints `Hard failure: report <path> has no findings to plan` or `… finding <id> is malformed: <detail>`. Emit the printed line verbatim and stop.

**It is a read-time view, never a rewrite.** The script only reads; `report-prd-<N>-<K>.json` stays canonical findings on disk, so the `/pre-merge` ↔ `eng --build` interop and the shared dedup/regression keys (`id`, `rule`, `regression_of`) are untouched. `evidence.flaky: true` survives the projection as `flaky` and changes how this build treats the ticket (fix only if a reproducible root cause surfaces — see § Work-step deltas above).
