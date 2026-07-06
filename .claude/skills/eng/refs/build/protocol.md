# eng — Mode: --build

Reads the assigned exec-table rows and the PRD's engineering section (produced in `--plan` mode), then writes implementation code to the working branch.

This file defines the build-mode specifics only. The shared protocol — input validation, PRD + devkit read, summary + approval gate mechanics, codebase scan, platform + coding standards, scope enforcement, user interview — lives in `SKILL.md`. Read SKILL.md's numbered steps as the spine; the sections below slot into the points it marks as mode-specific.

---

## Input contract (build-specific)

Build mode has two input sources (resolved at `SKILL.md` Step 1):

- **PRD/exec-table** (default): the shared four (`--build`, `prd-path`, `rows`, `agent`).
- **`test-json`** (alternate, `--build`-only): if a `test-json=<path to msg-test/test-N.json>` arg is present, **load `protocol-build-testjson.md` and follow it** — it defines that source's required fields, rejections, path derivation, `branch` defaulting, work-step deltas, `Issue`-keyed summary, and loop-closing. A plain PRD/exec-table build never loads it. (Supplying both `prd-path` and `test-json` is a hard failure — ambiguous source; see that ref.)

Either way, build mode requires one additional field, plus one optional commit-mode field:

| Field | Value |
|-------|-------|
| `branch` | The **feature branch** that already exists (created by the orchestrator/`plan-em`/`ship`). This is the branch your work must land on. On the `test-json` source, if `branch` is not passed it defaults to the file's own `context.branch` (see `protocol-build-testjson.md`). |
| `commit_mode` | *(optional)* `direct` or `sub-branch`. Default `direct`. See **Branch contract** below. |

### Branch contract (what `branch` means)

`branch` is the **feature branch the orchestrator created and will review** — it is the destination for this build's commits, **not** merely a PR target.

**Sub-PRD parent-aware derivation.** Before hard-refusing on a missing `branch`, read the PRD's frontmatter for a `parent:` field (present only on sub-PRDs — see `plan-pm`'s § Sub-PRD mode). If `parent: prd-<parent-n>-<parent-slug>` is present and `branch` was not explicitly passed, default `branch` to `feat/prd-<parent-n>-<parent-slug>` — the parent's feature branch, which already exists. A sub-PRD never gets its own branch. (Under `plan-em` orchestration `branch` is always passed explicitly and already resolves this way; this fallback covers a human running `eng --build` directly against a sub-PRD.) The `branch`-already-exists rule in Work-step 1 then applies unchanged: the parent branch is checked out, not created.

There are two commit modes:

- **`direct` (default — used by `ship`):** Commit your work **directly onto `branch`**. Do **not** cut a sub-branch and do **not** open a PR. The orchestrator reviews/tests `branch` itself, so your commits must be on it. When several build agents run in parallel against one `branch`, each agent owns a **disjoint set of files** (the exec-table groups rows by agent), so committing to the shared branch is safe as long as you touch only the files your assigned rows specify (Step 6 scope enforcement guarantees this).
- **`sub-branch` (direct human invocation):** Cut a working sub-branch `{branch}/{row-slug}` from `branch`, do all work there, commit, and open a PR from the sub-branch into `branch`. Use this only when a human runs `eng --build` standalone and wants a reviewable PR per agent.

If `commit_mode` is absent, default to `direct`.

**Example invocation (ship/default — direct):**
```
/eng --build prd-path=features/prd-4-habit-tracking/prd-4-habit-tracking.md rows="F2: Track streak — Schema migration; F2: Track streak — API contract" branch=feat/prd-4-habit-tracking
```

**Hard-refuse if `branch` is missing and cannot be derived.** If `branch` is not passed, first apply the derivation for the active source (PRD: sub-PRD `parent:` frontmatter above; `test-json`: the file's `context.branch`). Only if `branch` is still unresolved — no explicit value, no `parent:` frontmatter, and no `context.branch` in the `test-json` file — emit `Hard failure: missing required field 'branch' for --build mode` and stop. Do not proceed to pre-flight without a resolved `branch`.

---

## PRD read (Step 2 — standalone build, PRD/exec-table source)

This refines the **standalone path** of `SKILL.md` Step 2 for build mode. On a standalone build (no orchestrator injected scoped context) driven by the PRD/exec-table source, do **not** read the full PRD to locate the execution table and engineering section. Instead, run the PRD-digest generator for the **build** slice, once per assigned F-ID, and consume the JSON it prints:

```bash
G=.claude/scripts/scan-prd-digest.py; [ -f "$G" ] || G="$HOME/.claude/scripts/scan-prd-digest.py"; python3 "$G" "<prd-path>" --slice build --feature <F-ID>
```

The `build --feature <F-ID>` slice returns that feature's row (F-ID + acceptance criterion verbatim), its execution-table rows, and the `engineering` block (integration contracts, migration/breaking-change, scope mapping, findings, open questions) — the spec the Work steps below consume (Item 0 cross-check + exec-table fallback). Run it per assigned F-ID (or omit `--feature` to get all features and filter to your `rows` locally). The generator re-parses the current PRD on every call, so the slice is never stale and the PRD prose stays canonical — see `.claude/skills/shared/refs/session-cache.md`.

**Escape hatch:** if a row needs a detail the slice omits — Design-decisions / Phases prose or exact identifiers buried in narrative beyond the captured contracts/migration/scope blocks, or a heading under the digest's `unparsed_sections` — read only that engineering section's `prose_lines` range. Do **not** default to reading the whole PRD. (The `## Engineering — <Agent Name>` section remains the authority on design decisions and exact identifiers, per Work steps below.) The `### F<n>` **todo** blocks are not part of the slice; when the todo layer drives the build, read them from the PRD's `## Todos — <Agent Name>` section as the Work steps specify.

The **orchestrated** build path is unchanged (work from the injected scoped excerpts, PRD path as escape hatch only), and the **`test-json`** source reads no exec-table at all — neither invokes this slice read.

## Summary content (Step 3 — Pre-run 1 of 2)

The 3–4 line summary covers:

- Line 1: What is being implemented — one sentence naming the feature and platform.
- Lines 2–3: Which exec-table rows are owned and what code will be written (files created or modified, test coverage expected).
- Line 4 (optional): Any rows blocked by another agent's output; name the blocking agent and row.

---

## Coding-standards flags (Step 4)

Standards are resolved at `SKILL.md` Step 4. **On orchestrated build runs the orchestrator injects a compiled `standards payload` and this agent does not call `/cook` at all** — use the injected payload. Only on a **standalone** build (a human runs `eng --build` directly, no payload injected) does this agent call `/cook` itself, via **explicit flags** (never a prose summary) so the call is cacheable and always loads the P0 floor.

Derive the flags from the stack and the assigned rows' concerns:

| Source | Flags |
|--------|-------|
| P0 floor — **always** | `--global` |
| Flutter/Dart mobile | `--flutter --dart` |
| React web | `--react` |
| Next.js web | `--nextjs` |
| Node backend | `--nodejs` |
| TypeScript | `--typescript` |
| Supabase / Postgres | `--supabase --database` |
| GraphQL | `--graphql` |
| A **Tests** row is owned | add the stack's testing sub-ref: `--flutter:testing` / `--dart:testing` / `--react:testing` / `--nextjs:testing` / `--nodejs:testing` / `--typescript:testing` / `--graphql:testing` |

`--global` is mandatory on every call — it loads the **P0 universal floor** plus all 8 concern refs (architecture, api-design, auth, security, performance, error-handling, debug, cicd). Those concern refs already cover the row concerns `migration`, `schema`, `auth`, `api`, `endpoint`, `webhook`, `hook`, `component`, so no separate concern flags are added — only stack (domain) and tests (sub-ref) flags. Invoke `/cook` **once** with all applicable flags (e.g. `/cook --global --flutter --dart --flutter:testing`); if rows span multiple stacks, add each stack's domain flags to the **same** call. A repeated identical flag set is a cook **cache hit** (script-only run, no index scan). Read the result fully. If `/cook` returns no coverage for a stack, do not substitute another stack's standards — surface the uncovered stack as a named gap in the build summary and proceed using only `CLAUDE.md` and `devkit/ARCHITECTURE.md` conventions for that stack.

---

## Work steps (Step 5)

**Spec source — prefer todos, fall back to the exec-table.** For each assigned F-ID, first look for a matching `### F<n>` todo block under this agent's `## Todos — <Agent Name>` section (written by `--todo` mode, when the todo layer is enabled):

- **Todos present** for the F-ID → work the `### F<n>` block's **tickets** directly (JIRA/Linear-style; see the schema in `refs/todo/template-todo.md`). Each ticket carries `id`, `title`, `objective`, `type`, `priority`, `files` (each path + its `add|edit|remove` action), `depends-on`, and `done-when`. To execute a ticket: make the `files` changes to deliver the `objective`, then satisfy the `done-when` check. This is a mechanical checklist — no re-derivation of tasks from engineering-plan prose needed. (An explicitly empty `### F<n>` block — `_No discrete work for this feature._` — means nothing to build for that feature.)
  - **Ordering (`depends-on` + `priority`).** Build tickets in dependency order: a ticket runs only after every id in its `depends-on` is complete (this replaces the old TDD `blocked by:` row annotation as the ordering signal when todos drive the build). Among tickets with no outstanding dependency, take higher `priority` first (`P0` → `P1` → `P2`). A ticket whose `depends-on` names an id that doesn't exist in this PRD's `## Todos`, or a dependency cycle, is a blocking gap → surface via `AskUserQuestion`, do not guess an order.
  - **Objective keeps scope honest.** Use each ticket's `objective` as the intent check — implement exactly what serves it; anything beyond is out of scope (Step 6).
- **No todos for the F-ID** (todo layer disabled, or no `### F<n>` block exists for it) → fall back to deriving tasks from the PRD's `## Engineering — <Agent Name>` section and the F-ID's execution-table rows, exactly as before.
- **Neither todos nor a resolvable execution-table row** for an assigned F-ID → hard stop (no scope to build), consistent with the existing missing-input hard-refusals: emit `Hard failure: no todos and no execution-table row for '<F-ID>' — nothing to build` and stop.

In all cases the PRD's `## Engineering — <Agent Name>` section remains the authority on design decisions and exact identifiers; the todos are the executable breakdown of that section. Do not re-interpret the PRD features section directly.

**`test-json` source.** When build is driven by `test-json` instead of an exec-table, the numbered work steps below still run but with source-specific deltas (Item 0 skipped, Item 2 reads each issue, Item 4 collapses to reproduce→fix→verify, flaky handling, `Issue`-keyed summary, loop-closing) — **see `protocol-build-testjson.md`**.

0. **Cross-check plan section vs exec-table.** Before reading any file, confirm the §Engineering section is consistent with the current exec-table:
   - Every assigned row must appear in the exec-table with a non-blank Execution steps cell.
   - The `## Engineering — <Agent Name>` section must reference each assigned row (by row label or feature ID).
   If any row is missing from the exec-table, has a blank Execution steps cell, or is absent from the §Engineering section, surface it as a blocking gap via `AskUserQuestion` — do not proceed until resolved. Do not guess or infer intent; `plan-tune --eng` may have edited the table after the section was written.

1. **Check out the work branch (per `commit_mode`).** `branch` already exists — it is created once by the orchestrator (`plan-em`/`ship`) before any build agent starts; do **not** create it yourself (parallel build agents racing to create the same branch from `main` corrupts the tree). If `branch` does not exist, this is a hard failure: emit `Hard failure: target branch '<branch>' does not exist — the orchestrator must create it before build agents run` and stop. Then:
   - **`commit_mode: direct` (default):** check out `branch` itself and do all work on it. Your commits land directly on the feature branch the orchestrator reviews. Touch only the files your assigned rows specify (Step 6) so parallel agents on the same branch stay file-disjoint.
   - **`commit_mode: sub-branch`:** derive a sub-branch name `{branch}/{row-slug}` (where `row-slug` is a lowercase hyphenated slug of the first assigned row, e.g. `feat/prd-4-habit-tracking/streaks-schema`), cut it from `branch`, check it out, and do all work there.
   Do not push until the commit step.
2. **Read the tasks.** For each assigned F-ID, read its `### F<n>` todo block if present (preferred), else the assigned exec-table rows' Execution steps column (fallback), per **Spec source** above. If falling back and an Execution steps cell is blank, surface it as a blocking gap via `AskUserQuestion` — do not proceed on that row until resolved.
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

   **c. Write implementation.** For each implementation row in this group, in order: Schema migration → API contract → Authentication → Webhook → Client implementation. Create or modify the files named in the Execution steps. Apply the Step 4 coding standards (the injected `standards payload`, or `/cook` on a standalone run). Reuse existing components from `DESIGN-SYSTEM.md` before creating new ones.

   **d. Verify green.** Re-run the test files for this group. If all pass, continue to the next feature group. If any fail, enter Debug mode (`protocol-build-debug.md`). Do not move to the next feature group until this group's tests are green.

5. **Full-suite gate.** After all feature groups are green, run the project's **full** test suite and lint/typecheck once (discover the commands from `CLAUDE.md`, `devkit/ARCHITECTURE.md`, or the package manifest — e.g. `npm test`/`npm run lint`, `pytest`, `flutter test`). The per-group runs only covered the files this agent wrote; this catches breakage in sibling code. Any new failure introduced by this agent's changes goes to Debug mode (`protocol-build-debug.md`, max 3 cycles) before committing. A pre-existing failure unrelated to the assigned rows is noted in the build summary, not fixed (out of scope). If the project has no test or lint command, state that in the build summary and continue.
   *Caller override: orchestrators (e.g. `ship`) may suppress this gate and run a dedicated test stage instead. When suppressed, skip to step 6.*
6. **Confirm before commit.** Emit a one-line change summary (files touched, tests added, full-suite result) and ask via `AskUserQuestion` whether to commit and open the PR. Proceed only on an explicit "Yes". This is the single human gate between writing code and publishing it.
   *Caller override: when invoked with an autonomy contract (e.g. by `ship`), this gate is treated as pre-approved; proceed without prompting.*
7. **Commit (to the work branch).** On approval, commit with a conventional commit message referencing the feature and rows (e.g., `feat(streaks): add schema migration and API contract`). In `direct` mode this commit lands on `branch`; in `sub-branch` mode it lands on the sub-branch. Either way, the feature branch ends with your commits on it (directly in `direct` mode, or via the PR you open in `sub-branch` mode).
8. **Open PR (`sub-branch` mode only).** In `sub-branch` mode, when all assigned rows are complete and tests pass, open a PR from the working sub-branch to `{branch}`; link the PRD path in the PR description; never open a PR against `main`. **In `direct` mode, skip this step** — there is no sub-branch and no PR; the orchestrator reviews `branch` directly.

---

## Debug mode

Activates on a test failure at verify-green (step 4d) or a compile/runtime error during implementation (step 4c): a bounded per-issue cycle (identify → isolate → hypothesize → fix → verify → log), max 3 cycles, then a structured escalation. **See `protocol-build-debug.md`** — load it only when a failure actually occurs.

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
- A debug escalation (3 failed cycles, see `protocol-build-debug.md`) leaves a row unresolved — log here in addition to AHA, since it blocks a decision rather than just recording a learning.

**Format:** use the entry template in `.claude/skills/msg-init/refs/template-OPEN-QUESTIONS.md`, with these eng-specific values — `Status: open` (build agents never write `in-progress`/`resolved`) and `Raised by: eng-<agent name>`.

Append under the `## Open Questions` heading only — never write to `## Resolved` (that section is curated by humans or `plan-em`/`plan-tune`, not by build agents). `devkit/OPEN-QUESTIONS.md` is append-only, same as AHA.md. Reference any entries written during the run in the build summary.

---

## Output contract (Step 5)

Emit a build summary after all rows are complete:

```markdown
## Build summary — <Agent Name>

| Row | Files created | Files modified | Tests | Status |
|-----|--------------|---------------|-------|--------|
| <Feature — Concern> | `<path/created>` | `<path/modified>` | ✅ <n>/<n> pass | ✅ Done |

**PR:** <link, or "none — direct commit mode">
**Branch:** <branch the commits landed on — the feature branch in `direct` mode, or the sub-branch name in `sub-branch` mode>
**Target:** <feature branch (branch field value)>
**Full-suite gate:** <pass / fail summary, or "no test/lint command">
**Warnings:** <e.g. groups shipped without a Tests row, uncovered stacks from /cook, or "None">
**Blocked rows:** <list any rows not completed and why>
**AHA entries:** <list any entries written to devkit/AHA.md, or "None">
**Open questions:** <list any entries written to devkit/OPEN-QUESTIONS.md, or "None">
```

**`test-json` source.** When the build was driven by `test-json`, the summary table is keyed by `Issue` (not `Row`) and the loop is closed in the source file's `follow_up.status` — see `protocol-build-testjson.md`.

**Constraints:**
- Use the PRD's `## Engineering — <Agent Name>` section as the sole specification.
- Do not modify the PRD file.
- Your commits must land on the feature branch (`branch`): directly in `direct` mode, or via a PR into it in `sub-branch` mode. Never commit to or open a PR against `main`.
- Do not modify files outside the scope of the assigned exec-table rows — this also keeps parallel `direct`-mode agents file-disjoint on the shared branch.
