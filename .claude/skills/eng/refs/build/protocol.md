# eng — Mode: --build

Reads the assigned exec-table rows and the PRD's engineering section (produced in `--plan` mode), then writes implementation code to the working branch.

This file defines the build-mode specifics only. The shared protocol — input validation, PRD + devkit read, summary + approval gate mechanics, codebase scan, platform + coding standards, scope enforcement, user interview — lives in `SKILL.md`. Read SKILL.md's numbered steps as the spine; the sections below slot into the points it marks as mode-specific.

---

## Input contract (build-specific)

Beyond the shared four (`--build`, `prd-path`, `rows`, `agent`), build mode requires one additional field, plus one optional commit-mode field:

| Field | Value |
|-------|-------|
| `branch` | The **feature branch** that already exists (created by the orchestrator/`plan-em`/`ship`). This is the branch your work must land on. |
| `commit_mode` | *(optional)* `direct` or `sub-branch`. Default `direct`. See **Branch contract** below. |

### Branch contract (what `branch` means)

`branch` is the **feature branch the orchestrator created and will review** — it is the destination for this build's commits, **not** merely a PR target. There are two commit modes:

- **`direct` (default — used by `ship`):** Commit your work **directly onto `branch`**. Do **not** cut a sub-branch and do **not** open a PR. The orchestrator reviews/tests `branch` itself, so your commits must be on it. When several build agents run in parallel against one `branch`, each agent owns a **disjoint set of files** (the exec-table groups rows by agent), so committing to the shared branch is safe as long as you touch only the files your assigned rows specify (Step 6 scope enforcement guarantees this).
- **`sub-branch` (direct human invocation):** Cut a working sub-branch `{branch}/{row-slug}` from `branch`, do all work there, commit, and open a PR from the sub-branch into `branch`. Use this only when a human runs `eng --build` standalone and wants a reviewable PR per agent.

If `commit_mode` is absent, default to `direct`.

**Example invocation (ship/default — direct):**
```
/eng --build prd-path=features/prd-4-habit-tracking/prd-4-habit-tracking.md rows="F2: Track streak — Schema migration; F2: Track streak — API contract" branch=feat/prd-4-habit-tracking
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

0. **Cross-check plan section vs exec-table.** Before reading any file, confirm the §Engineering section is consistent with the current exec-table:
   - Every assigned row must appear in the exec-table with a non-blank Execution steps cell.
   - The `## Engineering — <Agent Name>` section must reference each assigned row (by row label or feature ID).
   If any row is missing from the exec-table, has a blank Execution steps cell, or is absent from the §Engineering section, surface it as a blocking gap via `AskUserQuestion` — do not proceed until resolved. Do not guess or infer intent; `plan-tune --eng` may have edited the table after the section was written.

1. **Check out the work branch (per `commit_mode`).** `branch` already exists — it is created once by the orchestrator (`plan-em`/`ship`) before any build agent starts; do **not** create it yourself (parallel build agents racing to create the same branch from `main` corrupts the tree). If `branch` does not exist, this is a hard failure: emit `Hard failure: target branch '<branch>' does not exist — the orchestrator must create it before build agents run` and stop. Then:
   - **`commit_mode: direct` (default):** check out `branch` itself and do all work on it. Your commits land directly on the feature branch the orchestrator reviews. Touch only the files your assigned rows specify (Step 6) so parallel agents on the same branch stay file-disjoint.
   - **`commit_mode: sub-branch`:** derive a sub-branch name `{branch}/{row-slug}` (where `row-slug` is a lowercase hyphenated slug of the first assigned row, e.g. `feat/prd-4-habit-tracking/streaks-schema`), cut it from `branch`, check it out, and do all work there.
   Do not push until the commit step.
2. **Read Execution steps.** For each assigned exec-table row, read the Execution steps column. If a cell is blank, surface it as a blocking gap via `AskUserQuestion` — do not proceed on that row until resolved.
3. **Discover testing tools.** Before writing any test file, scan existing test files in the relevant feature area for:
   - Test runner and framework (e.g., `pytest`, `jest`, `go test`, `flutter_test`)
   - Assertion libraries and matchers in use
   - Test file naming convention and directory layout
   - Factory, fixture, or mock patterns used in existing tests
   - Shared setup helpers (e.g., `beforeEach`, `setUp`, conftest fixtures)

   Record findings and apply them to every test file written in step 4. If no existing test files exist, check `CLAUDE.md` and `devkit/ARCHITECTURE.md` for the declared test stack.

4. **Execute rows in TDD order.** Rows with `blocked by:` annotations must wait for the named dependency. Within unblocked rows, process by feature group. For each group, complete all four phases before moving to the next group:

   **a. Write tests.** For each Tests concern row in this group, create the test file using the conventions and tooling discovered in step 3. Write syntactically valid, runnable assertions derived from the Execution steps. No `TODO` placeholders. Tests must compile or parse without errors. Do not write tests for rows without a Tests entry in the exec-table — a missing Tests row is a planner gap, not eng's to fill. **If a feature group owns implementation rows but no Tests row, do not silently ship it untested:** emit a visible warning (`⚠ No Tests row for group '<feature>' — shipping implementation without coverage`), record it in the build summary's Blocked/Notes and in `devkit/AHA.md`, then proceed.

   **b. Verify red.** Run only the test files just written. Confirm they fail with assertion failures — not compile errors or import errors. If a test errors instead of fails, fix the setup until it fails cleanly on a real assertion. A test that errors is not a red test; do not proceed to implementation until this is resolved.

   **c. Write implementation.** For each implementation row in this group, in order: Schema migration → API contract → Authentication → Webhook → Client implementation. Create or modify the files named in the Execution steps. Apply coding standards from `/cook`. Reuse existing components from `DESIGN-SYSTEM.md` before creating new ones.

   **d. Verify green.** Re-run the test files for this group. If all pass, continue to the next feature group. If any fail, enter Debug mode (see below). Do not move to the next feature group until this group's tests are green.

5. **Full-suite gate.** After all feature groups are green, run the project's **full** test suite and lint/typecheck once (discover the commands from `CLAUDE.md`, `devkit/ARCHITECTURE.md`, or the package manifest — e.g. `npm test`/`npm run lint`, `pytest`, `flutter test`). The per-group runs only covered the files this agent wrote; this catches breakage in sibling code. Any new failure introduced by this agent's changes goes to Debug mode (max 3 cycles) before committing. A pre-existing failure unrelated to the assigned rows is noted in the build summary, not fixed (out of scope). If the project has no test or lint command, state that in the build summary and continue.
   *Caller override: orchestrators (e.g. `ship`) may suppress this gate and run a dedicated test stage instead. When suppressed, skip to step 6.*
6. **Confirm before commit.** Emit a one-line change summary (files touched, tests added, full-suite result) and ask via `AskUserQuestion` whether to commit and open the PR. Proceed only on an explicit "Yes". This is the single human gate between writing code and publishing it.
   *Caller override: when invoked with an autonomy contract (e.g. by `ship`), this gate is treated as pre-approved; proceed without prompting.*
7. **Commit (to the work branch).** On approval, commit with a conventional commit message referencing the feature and rows (e.g., `feat(streaks): add schema migration and API contract`). In `direct` mode this commit lands on `branch`; in `sub-branch` mode it lands on the sub-branch. Either way, the feature branch ends with your commits on it (directly in `direct` mode, or via the PR you open in `sub-branch` mode).
8. **Open PR (`sub-branch` mode only).** In `sub-branch` mode, when all assigned rows are complete and tests pass, open a PR from the working sub-branch to `{branch}`; link the PRD path in the PR description; never open a PR against `main`. **In `direct` mode, skip this step** — there is no sub-branch and no PR; the orchestrator reviews `branch` directly.

---

## Debug mode

Activates when: tests fail at the verify-green phase (step 4d), or code produces a compile/runtime error during implementation (step 4c).

Run the following cycle per failing issue. Apply one change per cycle. Max 3 cycles per issue.

1. **Identify** — record the exact failing assertion or error message.
2. **Isolate** — read the failing test file, its implementation counterpart, and any shared helper, fixture, or module they directly import that the failure points at. Follow the failure, not the whole codebase — do not browse unrelated files.
3. **Hypothesize** — write one specific root-cause sentence.
4. **Fix** — make one targeted change within the failing row's scope only. No refactors outside it.
5. **Verify** — re-run the test or build step.
6. **Log** — append an AHA entry regardless of outcome (see AHA.md below). If this is the 3rd failed cycle (escalation), tag the entry with `severity: escalated` (see AHA.md format).

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

Throughout the build, append to `devkit/AHA.md` (the same file pre-flight reads, so learnings resurface in future plan runs) when any of the following occur:

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
**Severity**: <omit unless this entry was written at debug escalation — then set to `escalated`>
```

`devkit/AHA.md` is append-only. Never overwrite existing entries. Reference any AHA entries written during the run in the build summary.

---

## OPEN-QUESTIONS.md

Throughout the build, append to `devkit/OPEN-QUESTIONS.md` (read by `plan-pm` and `plan-em` pre-flight, and by `handoff`) when eng cannot resolve an ambiguity itself and must proceed on an assumption. This is distinct from `devkit/AHA.md`: AHA logs what eng *learned or decided*; OPEN-QUESTIONS logs what eng *could not decide* and is flagging for a human or a future planning run.

Append when any of the following occur:
- An execution step's intent is genuinely ambiguous (not just under-specified enough to infer from the PRD/CLAUDE.md/ARCHITECTURE.md) and eng proceeds on a stated assumption.
- A product or design decision surfaces mid-build that the PRD didn't anticipate and that would affect scope beyond the current row.
- A debug escalation (3 failed cycles, see Debug mode above) leaves a row unresolved — log here in addition to AHA, since it blocks a decision rather than just recording a learning.

**Format** (matches `devkit/OPEN-QUESTIONS.md`'s own template):

```
### [YYYY-MM-DD] Short question title

**Question**: Full question text.
**Severity**: critical | high | medium | low
**Status**: open
**Context**: Where this came up and why it matters.
**Options**: A / B / C (optional).
**Raised by**: eng-<agent name>
```

Append under the `## Open Questions` heading only — never write to `## Resolved` (that section is curated by humans or `plan-em`/`plan-tune`, not by build agents). `devkit/OPEN-QUESTIONS.md` is append-only, same as AHA.md. Reference any entries written during the run in the build summary.

---

## Output contract (Step 5)

Emit a build summary after all rows are complete:

```markdown
## Build summary — <Agent Name>

| Row | Files created | Files modified | Tests | Status |
|-----|--------------|---------------|-------|--------|
| F2: Track streak — Schema migration | `migrations/0043_add_streaks.sql` | `models/streak.py` | ✅ 2/2 pass | ✅ Done |
| F2: Track streak — API contract | — | `routes/streaks.py`, `openapi.yaml` | ✅ 3/3 pass | ✅ Done |

**PR:** <link, or "none — direct commit mode">
**Branch:** <branch the commits landed on — the feature branch in `direct` mode, or the sub-branch name in `sub-branch` mode>
**Target:** <feature branch (branch field value)>
**Full-suite gate:** <pass / fail summary, or "no test/lint command">
**Warnings:** <e.g. groups shipped without a Tests row, uncovered stacks from /cook, or "None">
**Blocked rows:** <list any rows not completed and why>
**AHA entries:** <list any entries written to devkit/AHA.md, or "None">
**Open questions:** <list any entries written to devkit/OPEN-QUESTIONS.md, or "None">
```

**Constraints:**
- Use the PRD's `## Engineering — <Agent Name>` section as the sole specification.
- Do not modify the PRD file.
- Your commits must land on the feature branch (`branch`): directly in `direct` mode, or via a PR into it in `sub-branch` mode. Never commit to or open a PR against `main`.
- Do not modify files outside the scope of the assigned exec-table rows — this also keeps parallel `direct`-mode agents file-disjoint on the shared branch.
