# eng — Mode: --build

Reads the todo tickets for the assigned exec-table rows (written in the same `--plan` pass) and writes implementation code to the working branch. The tickets are the spec.

This file defines the build-mode specifics only. The shared protocol — input validation, PRD + devkit read, summary + approval gate mechanics, codebase scan, platform + coding standards, scope enforcement, user interview — lives in `SKILL.md`. Read SKILL.md's numbered steps as the spine; the sections below slot into the points it marks as mode-specific.

---

## Input contract (build-specific)

Build mode has two input sources (resolved at `SKILL.md` Step 1):

- **PRD/exec-table** (default): the shared four (`--build`, `prd-path`, `rows`, `agent`).
- **`report`** (alternate, `--build`-only): if a `report=<path to features/prd-<N>-<slug>/reports/report-prd-<N>-<K>.json>` arg is present, **load `fix-build.md` and follow it** — it defines that source's required fields, rejections, path derivation, `branch` defaulting, work-step deltas, `Issue`-keyed summary, and loop-closing. A plain PRD/exec-table build never loads it. (Supplying both `prd-path` and `report` is a hard failure — ambiguous source; see that ref.)

Either way, build mode requires one additional field, plus one optional commit-mode field:

| Field | Value |
|-------|-------|
| `branch` | The **feature branch** that already exists (created by the orchestrator/`plan-em`/`ship`). This is the branch your work must land on. On the `report` source, if `branch` is not passed it defaults to the file's own `context.branch` (see `fix-build.md`). |
| `commit_mode` | *(optional)* `direct` or `sub-branch`. Default `direct`. See **Branch contract** below. |

### Branch contract (what `branch` means)

`branch` is the **feature branch the orchestrator created and will review** — it is the destination for this build's commits, **not** merely a PR target.

**Sub-PRD parent-aware derivation.** A sub-PRD (frontmatter `parent: prd-<parent-n>-<parent-slug>`) never gets its own branch — it rides the parent's `feat/prd-<parent-n>-<parent-slug>`. The resolver below applies that rule, so `branch` is derived the same way whether `plan-em` passes it explicitly or a human runs `eng --build` directly against a sub-PRD. The `branch`-already-exists rule in Work-step 1 applies unchanged: the parent branch is checked out, not created.

There are two commit modes:

- **`direct` (default — used by `ship`):** Commit your work **directly onto `branch`**. Do **not** cut a sub-branch and do **not** open a PR. The orchestrator reviews/tests `branch` itself, so your commits must be on it. When several build agents run in parallel against one `branch`, each agent owns a **disjoint set of files** (the exec-table groups rows by agent), so committing to the shared branch is safe as long as you touch only the files your assigned rows specify (Step 6 scope enforcement guarantees this).
- **`sub-branch` (direct human invocation):** Cut a working sub-branch `{branch}/{row-slug}` from `branch`, do all work there, commit, and open a PR from the sub-branch into `branch`. Use this only when a human runs `eng --build` standalone and wants a reviewable PR per agent.

If `commit_mode` is absent, default to `direct`.

**Example invocation (ship/default — direct):**
```
/eng --build prd-path=features/prd-4-habit-tracking/prd-4-habit-tracking.md rows="F2: Track streak — Schema migration; F2: Track streak — API contract" branch=feat/prd-4-habit-tracking
```

**Resolve and check the branch mechanically (PRD source).** Do not hand-derive the name or eyeball `git branch`. Run the shared resolver — it reads the PRD frontmatter (`parent:` included) and the local branch state and prints `BRANCH=`/`ACTION=`:

```bash
B=.claude/scripts/plan-em-branch-resolve.sh; [ -f "$B" ] || B="$HOME/.claude/scripts/plan-em-branch-resolve.sh"; bash "$B" "<prd-path>"
```

- `ACTION=checkout` — the branch exists. Use `BRANCH` when `branch` was not passed; if `branch` **was** passed and differs from `BRANCH`, the caller wins (an orchestrator may target a shared branch) — note the difference in the build summary.
- `ACTION=create` or `ACTION=fresh-cut` — the target branch does not exist. Build agents never create branches: emit `Hard failure: target branch '<BRANCH>' does not exist — the orchestrator must create it before build agents run` and stop.
- Exit 2 (no PRD / not a git repo) — fall back to the passed `branch`; if there is none, hard-refuse as below.

**Hard-refuse if `branch` is missing and cannot be derived.** If `branch` is not passed, first apply the derivation for the active source (PRD: the resolver above; `report`: the file's `context.branch`). Only if `branch` is still unresolved — no explicit value, no resolver result, and no `context.branch` in the `report` file — emit `Hard failure: missing required field 'branch' for --build mode` and stop. Do not proceed to pre-flight without a resolved `branch`.

---

## PRD read (Step 2 — standalone build, PRD/exec-table source)

This refines the **standalone path** of `SKILL.md` Step 2 for build mode. On a standalone build (no orchestrator injected scoped context) driven by the PRD/exec-table source, do **not** read the full PRD to locate the execution table and engineering section. Instead, run the PRD-digest generator for the **build** slice, once per assigned F-ID, and consume the JSON it prints:

```bash
G=.claude/scripts/scan-prd-digest.py; [ -f "$G" ] || G="$HOME/.claude/scripts/scan-prd-digest.py"; python3 "$G" "<prd-path>" --slice build --feature <F-ID>
```

The `build --feature <F-ID>` slice returns that feature's row (F-ID + acceptance criterion verbatim), its execution-table rows (whose Execution steps cell is the ticket-id pointer), the `todos` block (each agent's ticket ids + the `prose_lines` range to read the tickets from), and the `engineering` block (integration contracts, migration/breaking-change, scope mapping, findings, open questions) — the context the Work steps below consume around the tickets. Run it per assigned F-ID (or omit `--feature` to get all features and filter to your `rows` locally). The generator re-parses the current PRD on every call, so the slice is never stale and the PRD prose stays canonical — see `.claude/skills/shared/refs/session-cache.md`.

**Escape hatch:** if a row needs a detail the slice omits — Design-decisions / Phases prose or exact identifiers buried in narrative beyond the captured contracts/migration/scope blocks, or a heading under the digest's `unparsed_sections` — read only that engineering section's `prose_lines` range. Do **not** default to reading the whole PRD. (The `## Engineering — <Agent Name>` section remains the authority on design decisions and exact identifiers, per Work steps below.)

The **orchestrated** build path is unchanged (work from the injected scoped excerpts, PRD path as escape hatch only), and the **`report`** source reads no exec-table at all — neither invokes this slice read.

The slice points at the `### F<n>` **todo** blocks (ids + `prose_lines`) rather than inlining them; read the ticket bodies from that line range in the PRD's `## Todos — <Agent Name>` section — they are the spec the Work steps execute.

**Row ownership is verified mechanically** (`SKILL.md` Step 2): the digest script grades the `rows`/`agent` pair rather than the model reading the table.

## Summary content (Step 3 — Pre-run 1 of 2)

The 3–4 line summary covers:

- Line 1: What is being implemented — one sentence naming the feature and platform.
- Lines 2–3: Which exec-table rows are owned and what code will be written (files created or modified, test coverage expected).
- Line 4 (optional): Any rows blocked by another agent's output; name the blocking agent and row.

---

## Coding-standards flags (Step 4)

Standards are resolved at `SKILL.md` Step 4. **On orchestrated build runs the orchestrator injects a compiled `standards payload` and this agent does not call `/cook` at all** — use the injected payload. Only on a **standalone** build (a human runs `eng --build` directly, no payload injected) does this agent call `/cook` itself, via **explicit flags** (never a prose summary) so the call is cacheable and always loads the P0 floor.

Identify the applicable **domains** from the stack, then scope each domain's refs to the assigned rows' work (their **Files** column + **concerns**):

| Source | Domain flag |
|--------|-------------|
| P0 floor — **always** | `--global` |
| Flutter/Dart mobile | `--flutter --dart` |
| React web | `--react` |
| Next.js web | `--nextjs` |
| Node backend | `--nodejs` |
| TypeScript | `--typescript` |
| Supabase / Postgres | `--supabase --database` |
| GraphQL | `--graphql` |
| Swift native | `--swift` |
| macOS desktop | `--macos` |
| CSS / styling | `--css` |

**`--global` is mandatory and unscoped.** It loads the **P0 universal floor** plus all 8 concern refs (architecture, api-design, auth, security, performance, error-handling, debug, cicd). Those concern refs already cover the row concerns `migration`, `schema`, `auth`, `api`, `endpoint`, `webhook`, `hook`, `component`, so no separate concern flags are added. Emit `--global` **whole** on every call — do **not** scope its concern refs (concern-ref scoping is out of this scope).

**Scope every DOMAIN flag to the refs the work needs — do NOT emit the bare domain flag by default.** A **bare** domain flag (`--macos`, `--react`) loads the domain's `SKILL.md` **plus every** `refs/*.md` — the full shelf, most of which a given diff never touches. Cook already supports **sub-ref flags** (`--macos:windows-and-scenes` → just `standards/macos/refs/windows-and-scenes.md`); use them to compile only the refs in scope. Derive the scoped set per in-scope domain:

1. **Enumerate the domain's refs.** List `<cook>/standards/<domain>/refs/` (or read the domain's `_INDEX.md` ref table). This is the full candidate set — **never hardcode a ref list**; shelves change.
2. **Keep by default; drop only on a PROVABLE exclusion.** Start from *every* ref. **Never under-load: missing a relevant standard is worse than loading an extra one.** Drop a ref **only** when the PRD/devkit **provably excludes its subject** — e.g. `distribution.md` when `CLAUDE.md` defers distribution; `localization.md` when there is no i18n in scope; `sandbox-and-tcc.md` when the app declares no entitlements/sandbox. Weigh each ref against the assigned rows' **Files** column, the row **concerns**, and the devkit's provable exclusions. On **any** uncertainty, **keep** the ref.
3. **Always keep the domain `SKILL.md` floor.** The domain `SKILL.md` is the platform-correctness P0/P1 baseline (not a ref) and is never "provably excluded." Emit the bare `--<domain>` flag to anchor it so the platform floor never under-loads; the sub-ref flags below narrow only the *refs*.
4. **Emit `--<domain>:<ref>` for each KEPT ref.** The sub-ref flags name exactly the refs in scope; the provably-excluded refs are simply not requested. (Testing stays on the same mechanism — see below.)
5. **Whole-domain fallback.** If you cannot confidently scope a domain — the diff's ref footprint is unclear, or the `SKILL.md`'s in-scope P0 isn't confidently covered by the kept refs — **fall back to the bare `--<domain>` flag alone** (full shelf). A safe over-load beats an unsafe under-load.

**Tests sub-ref (unchanged).** If a **Tests** row is owned, add the stack's testing sub-ref alongside the scoped refs: `--flutter:testing` / `--dart:testing` / `--react:testing` / `--nextjs:testing` / `--nodejs:testing` / `--typescript:testing` / `--graphql:testing` / `--swift:testing`.

Invoke `/cook` **once** with `--global` + every applicable domain's scoped flag set. Example (macOS build whose PRD defers distribution, declares no entitlements, and has no i18n — so `distribution` / `sandbox-and-tcc` / `localization` are provably excluded):

```
/cook --global --macos --macos:architecture-and-state --macos:windows-and-scenes --macos:performance-accessibility --macos:hig-conventions --macos:testing
```

If rows span multiple stacks, add each stack's scoped flags to the **same** call. A repeated identical flag set is a cook **cache hit** (script-only run, no index scan). Read the result fully. If `/cook` returns no coverage for a stack, do not substitute another stack's standards — surface the uncovered stack as a named gap in the build summary and proceed using only `CLAUDE.md` and `devkit/ARCHITECTURE.md` conventions for that stack.

---

## Work steps (Step 5)

**Spec source — the todo tickets, and nothing else.** Tickets are written by `eng --plan` in the same pass as the engineering section, so every owned F-ID has a `### F<n>` block under this agent's `## Todos — <Agent Name>` section. There is no second spec: the exec-table row's Execution steps cell is a **pointer** to the ticket ids that deliver it (`→ F2-T1, F2-T2`), not a work description.

- Work the `### F<n>` block's **tickets** directly (JIRA/Linear-style; see the schema in `refs/plan/template-todo.md`). Each ticket carries `id`, `title`, `objective`, `type`, `files` (each path + its `add|edit|remove` action), `depends-on`, and `done-when`. To execute a ticket: make the `files` changes to deliver the `objective`, then satisfy the `done-when` check. This is a mechanical checklist — no re-derivation of tasks from engineering-plan prose. (An explicitly empty `### F<n>` block — `_No discrete work for this feature._` — means nothing to build for that feature.)
- **Ordering (`depends-on`, then ticket-id order).** A ticket runs only after every id in its `depends-on` is complete. Among tickets with no outstanding dependency, take **ticket-id order** (`F1-T1` → `F1-T2` → `F2-T1`) — ids are stable, feature-scoped and 1-based, so authoring order doubles as build order. A `depends-on` naming an id that doesn't exist in this PRD's `## Todos`, or a dependency cycle, is a blocking gap → surface via `AskUserQuestion`, do not guess an order.
- **Objective keeps scope honest.** Use each ticket's `objective` as the intent check — implement exactly what serves it; anything beyond is out of scope (Step 6).
- **Missing tickets are a plan failure, not a fallback.** No `### F<n>` block for an assigned F-ID, or a pointer id that resolves to no ticket, means the plan pass was incomplete. Emit `Hard failure: no todos for '<F-ID>' — plan pass incomplete, re-run eng --plan` and stop. Never reconstruct a spec from exec-table prose or engineering-section narrative.

The PRD's `## Engineering — <Agent Name>` section remains the authority on the surrounding design decisions and cross-agent contracts; the tickets are the work. Do not re-interpret the PRD features section directly.

**`report` source.** When build is driven by `report=` instead of an exec-table, the numbered work steps below still run but with source-specific deltas (Item 0 skipped, Item 2 reads each issue, Item 4 collapses to reproduce→fix→verify, flaky handling, `Issue`-keyed summary, loop-closing) — **see `fix-build.md`**.

0. **Cross-check the pointers resolve.** Before reading any file, confirm the row → ticket chain is intact:
   - Every assigned row's Execution steps cell names at least one ticket id, and **every named id resolves** to a real ticket under `## Todos — <Agent Name>`.
   - The `## Engineering — <Agent Name>` section references each assigned row (by row label or feature ID).
   A missing row, an empty or unresolvable pointer cell, or a row absent from the §Engineering section is a blocking gap — surface it via `AskUserQuestion` and do not proceed until resolved. Do not guess or infer intent; `plan-tune --eng` may have edited the table after the section was written.

1. **Check out the work branch (per `commit_mode`).** `branch` already exists — it is created once by the orchestrator (`plan-em`/`ship`) before any build agent starts; do **not** create it yourself (parallel build agents racing to create the same branch from `main` corrupts the tree). If `branch` does not exist, this is a hard failure: emit `Hard failure: target branch '<branch>' does not exist — the orchestrator must create it before build agents run` and stop. Then:
   - **`commit_mode: direct` (default):** check out `branch` itself and do all work on it. Your commits land directly on the feature branch the orchestrator reviews. Touch only the files your assigned rows specify (Step 6) so parallel agents on the same branch stay file-disjoint.
   - **`commit_mode: sub-branch`:** derive the sub-branch name `{branch}/{row-slug}` mechanically from the first assigned row, then cut it from `branch`, check it out, and do all work there:
     ```bash
     ROW_SLUG=$(printf '%s' "<first assigned row>" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\+/-/g; s/^-//; s/-$//')
     ```
   Do not push until the commit step.
2. **Read the tickets.** For each assigned F-ID, read its `### F<n>` todo block — the whole spec for the build, per **Spec source** above. Follow each assigned row's Execution steps pointer to the ticket ids it owns; an unresolvable pointer or a missing block is the hard failure named there, not a prompt to improvise.
3. **Discover testing tools.** Before writing any test file, scan existing test files in the relevant feature area for:
   - Test runner and framework (e.g., `pytest`, `jest`, `go test`, `flutter_test`)
   - Assertion libraries and matchers in use
   - Test file naming convention and directory layout
   - Factory, fixture, or mock patterns used in existing tests
   - Shared setup helpers (e.g., `beforeEach`, `setUp`, conftest fixtures)

   Record findings and apply them to every test file written in step 4. If no existing test files exist, check `CLAUDE.md` and `devkit/ARCHITECTURE.md` for the declared test stack.

4. **Execute tickets in TDD order.** Take tickets in the order set by **Spec source** (`depends-on` first, then ticket-id order), grouped by F-ID. For each F-ID group, complete all four phases (a–d) before moving to the next group. Which phases a ticket touches follows its `type` (`code | test | config | migration | doc`): a `test` ticket is the group's phase (a); `code`, `migration`, `config` and `doc` tickets are phase (c); and every ticket ends at its own `done-when` in phase (d).

   **Test surface — unit + integration only.** The TDD loop writes and runs **unit and integration tests only**. Do **not** run e2e, visual, perf, a11y, or coverage buckets inside the build loop — everything heavier is pre-merge's job (the CI gate), run once there instead of per-fix-iteration. This keeps the inner loop fast and cheap.

   **a. Write tests.** For each `test` ticket in this group, create the test file using the conventions and tooling discovered in step 3. Write syntactically valid, runnable assertions derived from the ticket's `objective` and `done-when`. No `TODO` placeholders. Tests must compile or parse without errors. Do not invent tests for a group with no `test` ticket — a missing test ticket is a planner gap, not eng's to fill. **If a group owns implementation tickets but no `test` ticket, do not silently ship it untested:** emit a visible warning (`⚠ No test ticket for group '<F-ID>' — shipping implementation without coverage`), record it in the build summary's Blocked/Notes and in `devkit/AHA.md`, then proceed.

   **b. Verify red.** Run only the test files just written. Confirm they fail with assertion failures — not compile errors or import errors. If a test errors instead of fails, fix the setup until it fails cleanly on a real assertion. A test that errors is not a red test; do not proceed to implementation until this is resolved.

   **c. Write implementation.** For each implementation ticket in this group, in the order set above, create or modify exactly the files named in the ticket's `files`. Apply the Step 4 coding standards (the injected `standards payload`, or `/cook` on a standalone run). Reuse existing components from `DESIGN-SYSTEM.md` before creating new ones.

   **Write the minimum (brevity mandate).** Write the least code that satisfies the ticket's `done-when` — no speculative abstraction, no indirection with a single caller, no unrequested generality, no options nobody asked for. Prefer a stdlib or framework call over hand-rolled code. Anything beyond the `done-when` is out of scope (Step 6), the same posture the ticket's `objective` already sets for scope.

   **Plain-English comments (A4).** Every new or modified function, module, class, and exported symbol gets a comment on the line above stating in plain English **what** it does (not how). Enforced twice: the pair reviewer checks it per ticket (4e), and `eng-comment-scan.sh` greps the staged diff mechanically at the commit gate (Step 7).

   **d. Verify green.** Re-run the test files for this group and check each ticket's `done-when`. If all pass, continue to the next feature group. If any fail, enter Debug mode (`protocol-build-debug.md`). Do not move to the next feature group until this group's tests are green.

   **e. Pair review (per ticket, before its commit gate).** After a ticket's implementation passes green, spawn one **pair-review subagent** — the platform-parameterised principal-engineer persona, the unnecessary-code-only mandate, the injected contract (diff + `done-when` + the parent's standards payload; no `/cook` call), and the blocking **one-revision-round** rule all live in `pair-review.md`; its input cost is bounded by the ticket's diff size — typically ≤500 changed LOC, the same figure `eng-commit-cap.sh` measures at the ticket's commit gate (an observed number, not a guaranteed one). Resolve or justify each finding; after the single round any unresolved finding is logged to the §11 Findings ledger with the justification, then the ticket is eligible to commit.

5. **Full-suite gate (unit + integration).** After all feature groups are green, run the project's **unit + integration** test suite and lint/typecheck once (discover the commands from `CLAUDE.md`, `devkit/ARCHITECTURE.md`, or the package manifest — e.g. `npm test`/`npm run lint`, `pytest`, `flutter test`). This gate scopes to unit + integration only — e2e / visual / perf / a11y / coverage are **not** run here; they belong to pre-merge (the CI gate). The per-group runs only covered the files this agent wrote; this catches breakage in sibling code. Any new failure introduced by this agent's changes goes to Debug mode (`protocol-build-debug.md`, max 3 cycles) before committing. A pre-existing failure unrelated to the assigned rows is noted in the build summary, not fixed (out of scope). If the project has no test or lint command, state that in the build summary and continue.
   *Caller override: orchestrators (e.g. `ship`) may suppress this gate and run a dedicated test stage instead. When suppressed, skip to step 6.*
6. **Confirm before commit.** First, the **production guardrail (never skipped under any autonomy contract — `shared/refs/safety-floor.md`):** run `.claude/scripts/eng-db-touch.sh` (fall back to `$HOME/.claude/scripts/eng-db-touch.sh`) against the working diff. If it flags database/data/production-config files, or the change introduces a breaking change (removed/renamed public API, changed contract or schema), pause via `AskUserQuestion` and require explicit sign-off before committing — the caller-override pre-approval below does **not** cover this pause. Then emit a one-line change summary (files touched, tests added, full-suite result) and ask via `AskUserQuestion` whether to commit and open the PR. Proceed only on an explicit "Yes". This is the single human gate between writing code and publishing it.
   *Caller override: when invoked with an autonomy contract (e.g. by `ship`), this gate is treated as pre-approved; proceed without prompting — except the production guardrail above, which always pauses when tripped.*
7. **Commit per ticket (to the work branch).** On the single approval from Step 6, commit — **one commit per todo ticket** (or per coherent group of tickets that reads as one reviewable unit). Each ticket's diff is a natural commit unit because a ticket is scoped to one coherent objective (`refs/plan/template-todo.md`, rule 2) — the commit-cap script below measures the actual size at commit time, when it's a fact instead of a guess. Do **not** add a per-ticket `AskUserQuestion` — Step 6's single confirmation (and the production guardrail) cover the whole run; per-ticket commits happen after that one "Yes". For **each** commit, run the two mechanical gates on the **staged** diff before committing (resolve each script locally, then the `$HOME` fallback):
   ```bash
   C=.claude/scripts/eng-comment-scan.sh; [ -f "$C" ] || C="$HOME/.claude/scripts/eng-comment-scan.sh"; "$C" --staged
   P=.claude/scripts/eng-commit-cap.sh;   [ -f "$P" ] || P="$HOME/.claude/scripts/eng-commit-cap.sh";   "$P" --message "<the prepared commit message>"   # add --breaking on a breaking-change commit
   ```
   - **Comment scan (A4):** any `UNCOMMENTED <file>:<line>` flag → add the plain-English comment and re-stage before committing. A genuine false positive is left as-is and noted in the build summary.
   - **Commit cap (A5):** pass `--breaking` when the commit contains a breaking change (removed/renamed public API, changed contract/schema) — the cap drops from 500 to 300 changed LOC. **The size measurement never blocks:** the script prints `CAP_OK`/`CAP_EXCEEDED <loc>/<cap>` and an under-cap commit always exits 0, because commit-time LOC is a measured fact the agent judges, not a gate. On `CAP_EXCEEDED`, judge split-or-commit: prefer **splitting the commit** into smaller ticket-sized commits.
   - **The `Oversize-reason:` trailer is enforced mechanically, not by memory.** Always pass the prepared commit message (`--message "<text>"` or `--message-file <path>`; `-` reads stdin). Over cap, the script greps the message for an `Oversize-reason: <text>` trailer: present → `TRAILER_OK`, exit 0; absent → `TRAILER_MISSING`, **exit 3** — add the trailer (or split the commit) and re-run, never commit through it. Omitting the message prints `TRAILER_UNCHECKED` and leaves the gap open, so don't. Also pass `--oversize-reason "<text>"` to print the `OVERSIZE <loc> reason: <text>` line, and log that same justification to the §11 Findings ledger. A **recurring** oversize pattern is a ticket-sizing signal — note it in the build summary and `devkit/AHA.md` (plan-time LOC sizing no longer exists to feed back to; the loop closes at `AHA.md` only).

   Use a conventional commit message referencing the feature and ticket ids (e.g. `feat(streaks): add streaks table [F1-T1]`). In `direct` mode commits land on `branch`; in `sub-branch` mode on the sub-branch. Either way, the feature branch ends with your commits on it (directly, or via the PR you open in `sub-branch` mode).
8. **Open PR (`sub-branch` mode only).** In `sub-branch` mode, when all assigned rows are complete and tests pass, open a PR from the working sub-branch to `{branch}`; link the PRD path in the PR description; never open a PR against `main`. **In `direct` mode, skip this step** — there is no sub-branch and no PR; the orchestrator reviews `branch` directly.

---

## Debug mode

Activates on a test failure at verify-green (step 4d) or a compile/runtime error during implementation (step 4c): a bounded per-issue cycle (identify → isolate → hypothesize → fix → verify → log), max 3 cycles, then a structured escalation. **See `protocol-build-debug.md`** — load it only when a failure actually occurs.

---

## AHA.md

Throughout the build, record a learning in `devkit/AHA.md` (the same file pre-flight reads, so learnings resurface in future plan runs) when any of the following occur:

- Codebase scan reveals a pattern not in the pulled coding standards.
- A ticket cannot be implemented as written.
- A cross-agent dependency is discovered mid-build that no ticket's `depends-on` marks.
- A non-obvious implementation decision is made.
- A debug cycle runs (regardless of outcome).

**Eng judges *when* to log and *what* it says; the writer is shared.** Do not hand-format or hand-append the entry — call the file's one writer, which owns the entry shape, the most-recent-first ordering and the recurrence count:

```bash
A=.claude/scripts/script-aha.sh; [ -f "$A" ] || A="$HOME/.claude/scripts/script-aha.sh"
bash "$A" devkit/AHA.md --tag "eng:<class>" --summary "<what happened>" \
  --why "<why it matters to a future run>" --note "<what was done, or 'unresolved — see debug escalation'>"
```

- `--tag` names the class of learning (e.g. `eng:standards-gap`, `eng:ticket-unbuildable`, `eng:debug-escalation`) — same tag for the same class every time, so recurrences count.
- **Exit 3** = no `devkit/AHA.md` in this project → skip the write silently and continue; it is not a build failure.
- Exit 2 = usage error or a malformed target file → note it in the build summary's **Warnings** and continue.

Reference any AHA entries written during the run in the build summary.

---

## OPEN-QUESTIONS.md

Throughout the build, append to `devkit/OPEN-QUESTIONS.md` (read by `plan-pm` and `plan-em` pre-flight, and by `handoff`) when eng cannot resolve an ambiguity itself and must proceed on an assumption. This is distinct from `devkit/AHA.md`: AHA logs what eng *learned or decided*; OPEN-QUESTIONS logs what eng *could not decide* and is flagging for a human or a future planning run.

Append when any of the following occur:
- An execution step's intent is genuinely ambiguous (not just under-specified enough to infer from the PRD/CLAUDE.md/ARCHITECTURE.md) and eng proceeds on a stated assumption.
- A product or design decision surfaces mid-build that the PRD didn't anticipate and that would affect scope beyond the current row.
- A debug escalation (3 failed cycles, see `protocol-build-debug.md`) leaves a row unresolved — log here in addition to AHA, since it blocks a decision rather than just recording a learning.

**Eng judges *when* to log and *what* it says; the writer is shared.** Do not hand-format or hand-append — call the file's one writer, which owns the entry shape and enforces structurally that the append lands in `## Open Questions` and never touches `## Resolved`:

```bash
Q=.claude/scripts/script-openq.sh; [ -f "$Q" ] || Q="$HOME/.claude/scripts/script-openq.sh"
bash "$Q" devkit/OPEN-QUESTIONS.md --title "<one-line question title>" \
  --question "<the decision that could not be made>" --raised-by "eng-<agent name>" \
  --severity <critical|high|medium|low> --context "<the assumption the build proceeded on>"
```

- `--status` defaults to `open` and build agents never pass anything else (`in-progress`/`resolved` are a human's or a planner's call).
- **Exit 3** = no `devkit/OPEN-QUESTIONS.md` in this project → skip the log silently and continue.
- Exit 2 = usage error or a malformed target file → note it in the build summary's **Warnings** and continue.

Reference any entries written during the run in the build summary.

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
**Warnings:** <e.g. groups shipped without a test ticket, uncovered stacks from /cook, or "None">
**Blocked rows:** <list any rows not completed and why>
**AHA entries:** <list any entries written to devkit/AHA.md, or "None">
**Open questions:** <list any entries written to devkit/OPEN-QUESTIONS.md, or "None">
**Report:** <path to the report-prd-<N>-<K>.md if the file was written, else "inline — the build summary above is the report of record">
```

**`report` source.** When the build was driven by `report=`, the summary table is keyed by `Issue` (not `Row`) and the loop is closed in the source file's `followUp.status` — see `fix-build.md`.

### Run report — `report-prd-<N>-<K>.md`

The inline build summary above is always emitted and is the **report of record** for the orchestrator — a `report-prd-<N>-<K>.md` file only *supplements* it (per `../../../shared/refs/report-schema.md`, which never lets the file replace the summary). After emitting the build summary, **best-effort** write that supplementary run report per the schema — path resolution, `<N>`/`<K>` numbering, frontmatter keys, and the fixed section contract all live there; do not improvise fields. The write is optional, not required: if the file cannot be written — sandbox / subagent write policy, or an IO failure — the inline build summary stands as the sanctioned fallback; note the skipped report under the build summary's **Warnings** and continue. Never fail or block the build over the report file. Build-mode specifics:

- Directory: `features/prd-<N>-<slug>/reports/` derived from the `prd-path` input (create if absent).
- Frontmatter: `skill: eng`; `prd` = `prd-path`; `branch` = the branch the commits landed on; `verdict` mapped from the full-suite gate (`pass` / `fail`, `n/a` when no test command); `features` = the assigned exec-table rows' feature ids; diff stats from `rtk git diff --numstat` over this agent's commits; test counts from the per-group and full-suite runs.
- `## What to expect` / `## How to verify` are written for the human who will use the feature, in simple, non-technical language: derive the verification steps from the PRD acceptance criteria of the rows built and the tests written — say what to do and what they should see (exact command to copy-paste where unavoidable, user-visible behaviour to click through, expected result in plain words).
- Best-effort: a failed report write never fails the build — record it under the build summary's **Warnings** instead.

**Constraints:**
- Use the PRD's `## Engineering — <Agent Name>` section as the sole specification.
- Do not modify the PRD file.
- Your commits must land on the feature branch (`branch`): directly in `direct` mode, or via a PR into it in `sub-branch` mode. Never commit to or open a PR against `main`.
- Do not modify files outside the scope of the assigned exec-table rows — this also keeps parallel `direct`-mode agents file-disjoint on the shared branch. (Run artifacts are exempt: `devkit/AHA.md`, `devkit/OPEN-QUESTIONS.md`, and the run report under `features/…/reports/` — the report's max+1 numbering keeps parallel agents from colliding on a filename; on a collision, re-derive `K` and retry once.)
