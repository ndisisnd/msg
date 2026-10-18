---
name: eng --build — report source
description: Lazily loaded when eng --build is invoked with report=<path>. Defines the bug-list (issue-ticket) build source — required fields, rejections, path derivation, branch defaulting, the deltas on the build loop, the one return format, escalations, and loop-closing. A plain PRD/exec-table --build never loads this.
type: reference
---

# eng --build — `report` source

Loaded only when `--build` is invoked with `report=<path>`. Drives the build from an issues file (`report-prd-<N>-<K>.json`) instead of an exec-table. The spec is a **bug list**, not a feature, so there is no red test to write — the failure already exists.

## Orchestration routing

`--build report=<path>` routes **by default** to `fix-build-orchestrated.md` — the fix coordinator, which projects `issues[]` into issue-tickets and fans the fixes out to one fixer subagent per issue. `orchestrate=off` skips the coordinator and runs the flat single-agent flow in the rest of this file.

**A fixer spawned by the coordinator always runs with `orchestrate=off`.** It runs the flat flow for its one issue and never starts another coordinator. The fix loop has one layer.

## Required fields and rejections

| Field | Value |
|-------|-------|
| mode flag | `--build` |
| `report` | Path to the `report-prd-<N>-<K>.json` issues file whose `issues[]` this build resolves |
| `branch` | Feature branch the commits land on. Defaults to the file's own `context.branch` (§ Branch default); must already exist |
| `agent` | *(optional)* Defaults to `eng-fix` — a bug list has no roster |
| `orchestrate` | *(optional)* `on` (default) routes to `fix-build-orchestrated.md`; `off` runs the flat flow |
| `attempts_left` | *(optional, set by the coordinator)* This issue's remaining fix attempts. Default 3 (`protocol-build-debug.md` § The limit) |

- `report` is valid on both modes: `--build` fixes the findings; `--plan report` (`../plan/fix-plan.md`) plans them first.
- Both `prd-path` and `report` → `Hard failure: pass either prd-path+rows or report, not both (ambiguous input source).`
- Input validity is checked by `script-project-findings.py` (§ Finding → issue-ticket projection) — the same call that produces the tickets. A missing, unparseable, empty or malformed issues file is its non-zero exit: emit the `Hard failure:` line it prints and stop.

**Path derivation.** All implementation paths come from the codebase scan and the projected tickets. An issue's `file` is where a *symptom* was observed, not a path to edit blindly. Scope enforcement still runs per issue.

**Branch default.** When `branch` is not passed, use the file's own `context.branch` — the branch the gate was checking. It must still exist; a missing branch is a hard failure.

## Deltas on the build loop

The build loop (`protocol-packet.md`) runs; a manual flat run also runs the solo-only steps in `protocol.md` (branch, standards, progress messages, "Commit?"), except its ticket check (step 2). The deltas:

- **Loop Step 1 reads issues, not `## Todos`.** Each projected issue-ticket's `message`, `evidence.snippet` and `repro` *is* the spec for its fix.
- **Loop Step 3 collapses to three phases**, per issue, in `severity` order (`blocker` → `high` → `medium` → `low`; findings carry no `depends-on`):
  - **(a) reproduce** — run the issue's `repro` (or its covering test) and confirm it still fails the same way. This replaces "write tests" + "red".
  - **(b) fix** — implement the change with the coding standards. **This is attempt 1** of the issue's limit.
  - **(c) verify** — re-run `repro`, then the covering test file. Still red → debug mode (`protocol-build-debug.md`) with the attempts that remain.
- **Flaky issues are not forced.** An issue with `flaky: true` is fixed only when (a) shows a clear, reproducible root cause. Otherwise leave it, noted `⚠ flaky — not reproduced, left as-is`.
- **Loop Step 7 — one commit per issue.**

## Output — one return format

A **fixer spawned by the coordinator** returns exactly this JSON object and nothing else. The coordinator parses this shape (`fix-build-orchestrated.md` § Subagent contract):

```json
{
  "issue": "<finding id>",
  "status": "done" | "escalated" | "flaky",
  "attempts": <fix attempts used in this run>,
  "files": ["<path>"],
  "commits": ["<sha>"],
  "tests": "repro green" | "still red: <failing check>",
  "review": {"verdict": "pass" | "warn" | "block", "artifact": "<reports/review-prd-<N>-<K>-fix-<id>.json>"},
  "escalation": "<the escalation block text>" | null
}
```

A **flat run** with no coordinator prints the build loop's summary (`protocol-packet.md` § Output) with the table keyed by `Issue`:

```markdown
**Result:** <✅ done | ⛔ blocked> · <k>/<n> issues fixed · review <verdict>

| Issue | Files created | Files modified | Tests | Status |
|-------|--------------|---------------|-------|--------|
| <finding-id> | — | `<path>` | ✅ repro green | ✅ Done |
```

## Escalations

A bug that reaches its limit is escalated (`protocol-build-debug.md` § Escalation). Its block is saved for the separate investigation in `report-prd-<N>-<K>-escalation.md`, next to the issues file under the same stem. A flat run writes it; a fixer returns the block in `escalation` and the coordinator writes it. When the file already exists from an earlier run, add a new dated section at its end.

The closing message names the next step for each escalated bug: `<issue id> needs a deeper investigation in a separate session. Start a new session and run /eng --plan report=<issues path>.` That plan reads the escalation file (`../plan/fix-plan.md`).

## Closing the loop

When every issue is done, escalated or left flaky, record it in the issues file's own `followUp.status`. **Never hand-edit the JSON** — run the one script that owns this write. **A fixer spawned by the coordinator never closes the loop**; the coordinator does it once for the whole run.

```bash
C=.claude/scripts/script-eng-close-loop.py; [ -f "$C" ] || C="$HOME/.claude/scripts/script-eng-close-loop.py"; python3 "$C" "<report-path>" resolved|partially_resolved
```

- every issue verified green → `resolved`
- one or more issues escalated or left unreproduced (flaky) → `partially_resolved`

This is the **only** write build mode makes to `report-prd-<N>-<K>.json`. The script splices the status into the original bytes, asserts every other byte and field is unchanged, then replaces the file atomically — any drift aborts before the write. Exit 0 prints `CLOSED …` + `VERIFIED …`; a non-zero exit prints a `Hard failure:` line to emit verbatim. The `--gui` board reads `followUp.status` back to show each gate issue as Open or Resolved.

## The `kind` discriminator

Every ticket carries a `kind` field, so a consumer (`--build`, the `--gui` board) can tell a build todo from a bug:

| `kind` | Origin | Id shape |
|--------|--------|----------|
| `"todo"` | a PRD `## Todos` `### F<n>` block (`refs/plan/template-todo.md`) | `F<n>-T<k>` |
| `"issue"` | a canonical finding in `report-prd-<N>-<K>.json` (the projection below) | the finding `id`, e.g. `unit-002` |

A ticket with no explicit `kind` is a `"todo"`. The id shape is a secondary signal; `kind` is authoritative.

## Finding → issue-ticket projection

`report-prd-<N>-<K>.json` stores **canonical finding objects** (`../../../shared/refs/finding-schema.md`). Each finding is **projected** into an issue-ticket so the fix build uses the same ticket vocabulary as a PRD build.

**The projection has exactly one implementation:** `.claude/scripts/script-project-findings.py`. Run it; never re-derive the mapping by hand. Its module docstring is the field-mapping documentation. The `--gui` board (`msg/refs/protocol-gui.md` Step 1b) loads the same file, so the two consumers cannot drift.

```bash
P=.claude/scripts/script-project-findings.py; [ -f "$P" ] || P="$HOME/.claude/scripts/script-project-findings.py"; python3 "$P" "<report-path>"
```

Exit 0 emits `{"file", "count", "tickets": […]}`; exit 2 prints `Hard failure: report <path> not found or unparseable`; exit 1 prints `Hard failure: report <path> has no findings to plan` or `… finding <id> is malformed: <detail>`. Emit the printed line verbatim and stop.

**It is a read-time view, never a rewrite.** The file stays canonical findings on disk, so the dedup and regression keys (`id`, `rule`, `regression_of`) are untouched. `evidence.flaky: true` survives as `flaky` (§ Deltas).
