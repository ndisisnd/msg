# eng — Mode: --build

Reads the assigned exec-table rows and the PRD's engineering section (produced in `--plan` mode), then writes implementation code to the working branch.

This file defines the build-mode specifics only. The shared protocol — input validation, PRD + devkit read, summary + approval gate mechanics, codebase scan, platform + coding standards, scope enforcement, user interview — lives in `SKILL.md`. Read SKILL.md's numbered steps as the spine; the sections below slot into the points it marks as mode-specific.

---

## Input contract (build-specific)

Beyond the shared three (`--build`, `prd-path`, `rows`), build mode requires one additional field:

| Field | Value |
|-------|-------|
| `branch` | Target feature branch. Eng creates a working sub-branch from this; the PR targets it. |

**Example invocation:**
```
/eng --build prd-path=features/prd-4/prd-4.md rows="Streaks:Schema-migration Streaks:API-contract" branch=feat/prd-4-habit-tracking
```

**Hard-refuse if `branch` is missing — check this before reading any file.** Emit `Hard failure: missing required field 'branch' for --build mode` and stop. Do not proceed to pre-flight.

---

## Summary content (Step 3 — Pre-run 1 of 2)

The 3–4 line summary covers:

- Line 1: What is being implemented — one sentence naming the feature and platform.
- Lines 2–3: Which exec-table rows are owned and what code will be written (files created or modified, test coverage expected).
- Line 4 (optional): Any rows blocked by another agent's output; name the blocking agent and row.

---

## Work steps (Step 5)

Use the PRD's `## Engineering — <Agent Name>` section as the sole specification. Do not re-interpret the PRD features section directly.

1. **Create working sub-branch.** The `branch` field is the PR target. Derive a sub-branch name: `{branch}/{row-slug}` where `row-slug` is a lowercase hyphenated slug of the first assigned row (e.g., `feat/prd-4-habit-tracking/streaks-schema`). If the target branch does not exist, create it from `main` first. Check out the sub-branch and do all work there. Do not push until the commit step.
2. **Read Execution steps.** For each assigned exec-table row, read the Execution steps column. If a cell is blank, surface it as a blocking gap via `AskUserQuestion` — do not proceed on that row until resolved.
3. **Discover testing tools.** Before writing any test file, scan existing test files in the relevant feature area for:
   - Test runner and framework (e.g., `pytest`, `jest`, `go test`, `flutter_test`)
   - Assertion libraries and matchers in use
   - Test file naming convention and directory layout
   - Factory, fixture, or mock patterns used in existing tests
   - Shared setup helpers (e.g., `beforeEach`, `setUp`, conftest fixtures)

   Record findings and apply them to every test file written in step 4. If no existing test files exist, check `CLAUDE.md` and `devkit/ARCHITECTURE.md` for the declared test stack.

4. **Execute rows in TDD order.** Rows with `blocked by:` annotations must wait for the named dependency. Within unblocked rows, process by feature group. For each group, complete all four phases before moving to the next group:

   **a. Write tests.** For each Tests concern row in this group, create the test file using the conventions and tooling discovered in step 3. Write syntactically valid, runnable assertions derived from the Execution steps. No `TODO` placeholders. Tests must compile or parse without errors. Do not write tests for rows without a Tests entry in the exec-table — a missing Tests row is a planner gap, not eng's to fill.

   **b. Verify red.** Run only the test files just written. Confirm they fail with assertion failures — not compile errors or import errors. If a test errors instead of fails, fix the setup until it fails cleanly on a real assertion. A test that errors is not a red test; do not proceed to implementation until this is resolved.

   **c. Write implementation.** For each implementation row in this group, in order: Schema migration → API contract → Authentication → Webhook → Client implementation. Create or modify the files named in the Execution steps. Apply coding standards from `/cook`. Reuse existing components from `DESIGN-SYSTEM.md` before creating new ones.

   **d. Verify green.** Re-run the test files for this group. If all pass, continue to the next feature group. If any fail, enter Debug mode (see below). Do not move to the next feature group until this group's tests are green.

5. **Commit.** After all feature groups are green, commit with a conventional commit message referencing the feature and rows (e.g., `feat(streaks): add schema migration and API contract`).
6. **Open PR.** When all assigned rows are complete and tests pass, open a PR from the working sub-branch to `{branch}`. Link the PRD path in the PR description. Do not open a PR against `main`.

---

## Debug mode

Activates when: tests fail at the verify-green phase (step 4d), or code produces a compile/runtime error during implementation (step 4c).

Run the following cycle per failing issue. Apply one change per cycle. Max 3 cycles per issue.

1. **Identify** — record the exact failing assertion or error message.
2. **Isolate** — read only the failing test file and its implementation counterpart. Nothing else.
3. **Hypothesize** — write one specific root-cause sentence.
4. **Fix** — make one targeted change within the failing row's scope only. No refactors outside it.
5. **Verify** — re-run the test or build step.
6. **Log** — append an AHA entry regardless of outcome (see AHA.md below).

After 3 failed cycles, stop. Emit a structured escalation:

```
Debug escalation — <Row>
Failing assertion: <exact text>
Cycles tried: 3
Hypotheses: (1) <h1>  (2) <h2>  (3) <h3>
Fixes applied: (1) <f1>  (2) <f2>  (3) <f3>
Needed to continue: <what information or change is required>
```

Mark the affected row's Tests column as `❌ Escalated` in the build summary.

---

## AHA.md

Throughout the build, append to `AHA.md` in the project root when any of the following occur:

- Codebase scan reveals a pattern not in the pulled coding standards.
- An execution step cannot be implemented as written.
- A cross-agent dependency is discovered mid-build not marked in the exec-table.
- A non-obvious implementation decision is made.
- A debug cycle runs (regardless of outcome).

**Format:**

```
### [YYYY-MM-DD] <Feature — Concern>: <Summary title>

**Issue/Learning**: <what happened>
**Resolution**: <what was done, or "unresolved — see debug escalation">
```

AHA.md is append-only. Never overwrite existing entries. Reference any AHA entries written during the run in the build summary.

---

## Output contract (Step 5)

Emit a build summary after all rows are complete:

```markdown
## Build summary — <Agent Name>

| Row | Files created | Files modified | Tests | Status |
|-----|--------------|---------------|-------|--------|
| F2: Track streak — Schema migration | `migrations/0043_add_streaks.sql` | `models/streak.py` | ✅ 2/2 pass | ✅ Done |
| F2: Track streak — API contract | — | `routes/streaks.py`, `openapi.yaml` | ✅ 3/3 pass | ✅ Done |

**PR:** <link>
**Branch:** <working sub-branch name>
**Target:** <feature branch (branch field value)>
**Blocked rows:** <list any rows not completed and why>
**AHA entries:** <list any entries written to AHA.md, or "None">
```

**Constraints:**
- Use the PRD's `## Engineering — <Agent Name>` section as the sole specification.
- Do not modify the PRD file.
- Do not open a PR against `main` — always target the feature branch.
- Do not modify files outside the scope of the assigned exec-table rows.
