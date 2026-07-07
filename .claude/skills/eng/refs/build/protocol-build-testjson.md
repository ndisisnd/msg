---
name: eng --build — test-json source
description: Lazily loaded when eng --build is invoked with test-json=<path>. Defines the bug-list (issue-ticket) build source — required fields, rejections, path derivation, branch defaulting, work-step deltas, Issue-keyed summary, and loop-closing. A plain PRD/exec-table --build never loads this.
type: reference
---

# eng --build — `test-json` source

Loaded only when `--build` is invoked with `test-json=<path>` (see `protocol.md` § Input contract). Drives the build from a `/test` bug list instead of an exec-table. The spec is a **bug list**, not a feature to build, so there is no red test to write — it already exists (it's literally what `/test` recorded).

## Required fields and rejections

| Field | Value |
|-------|-------|
| mode flag | `--build` |
| `test-json` | Path to the `msg-test/test-N.json` file whose `issues[]` this build resolves |
| `branch` | Feature branch the commits land on. Defaults to the file's own `context.branch` when not passed (see **Branch default**); must still exist before work starts |
| `agent` | *(optional)* Defaults to a single generic identity `eng-fix` — a bug list has no roster to assign owners from |

- `test-json` is a **`--build`-only** source. `--plan` (and `--todo`) with `test-json` is a hard failure: `Hard failure: test-json is a --build-only input source`.
- Supplying **both `prd-path` and `test-json`** is a hard failure — ambiguous input source: `Hard failure: pass either prd-path+rows or test-json, not both (ambiguous input source).`
- A `test-json` path that does not exist or cannot be parsed as JSON is an input-validation failure (`Hard failure: test-json <path> not found or unparseable`) — the findings can't be projected, so there is nothing to build.

**Path derivation.** Eng derives all *implementation* file paths from the codebase scan and the projected issue-tickets. `test-json`'s `issues[].file` is where a *symptom* was observed, **not** a command to blindly edit that path — Step 2's codebase scan and Step 6's scope enforcement still run per issue exactly as they do per row.

**Branch default.** When build is driven by `test-json` and `branch` is not explicitly passed, default it to the file's own `context.branch` — the branch `/test` was already running against when it found the issues — rather than asking the user to repeat what the file records. The `branch`-must-exist rule (`protocol.md` Work-step 1) still applies unchanged: a defaulted branch that doesn't exist is still a hard failure.

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
- **The build summary table is keyed by `Issue`** (below) and, on completion, `eng --build` **writes the loop closed** in the `test-json` file (below).

## Output contract — table keyed by `Issue`

When the build was driven by `test-json`, swap the summary table's **`Row`** column for **`Issue`** (the finding `id`, e.g. `unit-002`); keep `Files created`, `Files modified`, `Tests`, and `Status` as-is:

```markdown
| Issue | Files created | Files modified | Tests | Status |
|-------|--------------|---------------|-------|--------|
| <finding-id> | — | `<path>` | ✅ repro green | ✅ Done |
```

## Closing the loop

On completion, `eng --build` **updates the `test-json` file's own `followUp.status`** (camelCase — the key `server.py`/the `--gui` board reads) so the ticket reflects that it was acted on rather than sitting permanently `open`:

- every issue verified green → `"resolved"`
- one or more issues escalated (3-cycle debug escalation) or left unreproduced (flaky) → `"partially_resolved"`

This is the **only** write build mode makes to `msg-test/test-<n>.json`; the `issues[]` array and every other field stay untouched (the file remains canonical findings — the projection was read-time only). The `--gui` board reads this `followUp.status` back to render an honest Open/Resolved state per test-issue card.
