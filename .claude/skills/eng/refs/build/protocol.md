# eng — Mode: --build

Reads the assigned exec-table rows and the PRD's engineering section (produced in `--plan` mode), then writes implementation code to the working branch.

This file defines the build-mode specifics only. The shared protocol — input validation, PRD + devkit read, summary + approval gate mechanics, codebase scan, platform + coding standards, scope enforcement, user interview — lives in `SKILL.md`. Read SKILL.md's numbered steps as the spine; the sections below slot into the points it marks as mode-specific.

---

## Input contract (build-specific)

Beyond the shared three (`--build`, `prd-path`, `rows`), build mode requires one additional field:

| Field | Value |
|-------|-------|
| `branch` | Working branch name: `feat/prd-[n]-<short-name>` |

**Example invocation:**
```
/eng --build prd-path=features/prd-4/prd-4.md rows="Streaks:Schema-migration Streaks:API-contract" branch=feat/prd-4-habit-tracking
```

Hard-refuse if `branch` is missing.

---

## Summary content (Step 3 — Pre-run 1 of 2)

The 3–4 line summary covers:

- Line 1: What is being implemented — one sentence naming the feature and platform.
- Lines 2–3: Which exec-table rows are owned and what code will be written (files created or modified, test coverage expected).
- Line 4 (optional): Any rows blocked by another agent's output; name the blocking agent and row.

---

## Work steps (Step 5)

Use the PRD's `## Engineering — <Agent Name>` section as the sole specification. Do not re-interpret the PRD features section directly.

1. **Check out branch.** Verify the `branch` field exists in the repo. If not, create it from `main`. Do not push until Step 6.5.
2. **Read Execution steps.** For each assigned exec-table row, read the Execution steps column. If a cell is blank, surface it as a blocking gap via `AskUserQuestion` — do not proceed on that row until resolved.
3. **Execute rows in dependency order.** Rows with `blocked by:` annotations must wait for the named dependency. Within unblocked rows, execute in concern-type order: Schema migration → API contract → Authentication → Webhook → Client implementation → Tests.
4. **Write code.** For each row, create or modify the files named in the Execution steps. Apply coding standards loaded in Step 5. Reuse existing components from DESIGN-SYSTEM.md before creating new ones.
5. **Write or update tests.** Every row of concern type Tests must be fully implemented. For non-test rows, write unit tests covering the happy path and at least one error case unless the row's Execution steps explicitly state no tests are required.
6. **Commit.** After each row is complete, commit with a conventional commit message referencing the feature and row (e.g., `feat(streaks): add schema migration 0043_add_streaks`).
7. **Open PR.** When all assigned rows are complete, open a PR from the working branch against the feature branch (`feat/prd-[n]-<short-name>`). Link the PRD path in the PR description. Do not open a PR against `main`.

---

## Output contract (Step 5)

Emit a build summary after all rows are complete:

```markdown
## Build summary — <Agent Name>

| Row | Files created | Files modified | Tests | Status |
|-----|--------------|---------------|-------|--------|
| F2: Track streak — Schema migration | `migrations/0043_add_streaks.sql` | `models/streak.py` | `tests/test_streak_model.py` | ✅ Done |
| F2: Track streak — API contract | — | `routes/streaks.py`, `openapi.yaml` | `tests/test_streaks_api.py` | ✅ Done |

**PR:** <link>
**Branch:** <branch name>
**Blocked rows:** <list any rows not completed and why>
```

**Constraints:**
- Use the PRD's `## Engineering — <Agent Name>` section as the sole specification.
- Do not modify the PRD file.
- Do not open a PR against `main` — always target the feature branch.
- Do not modify files outside the scope of the assigned exec-table rows.
