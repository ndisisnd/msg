# eng — Mode: --build

Reads the todo tickets for the assigned exec-table rows (written in the same `--plan` pass) and writes implementation code to the working branch. **The tickets are the spec.**

Build-mode specifics only. `SKILL.md` is the spine — input validation, PRD + devkit read, summary + approval gate, codebase scan, standards, scope enforcement, user interview; the sections below slot into the points it marks mode-specific.

---

## Input contract (build-specific)

Two input sources, resolved at `SKILL.md` Step 1:

- **PRD/exec-table** (default): the shared four (`--build`, `prd-path`, `rows`, `agent`).
- **`report`** (`--build`-only): a `report=<path to features/prd-<N>-<slug>/reports/report-prd-<N>-<K>.json>` arg → **load `fix-build.md` and follow it** — it owns that source's required fields, rejections, path derivation, `branch` defaulting, work-step deltas, `Issue`-keyed summary, loop-closing, and the fix-complexity routing to `fix-build-orchestrated.md`. A plain PRD/exec-table build never loads it. Passing both `prd-path` and `report` is a hard failure (ambiguous source; see that ref).

Both also require:

| Field | Value |
|-------|-------|
| `branch` | The **feature branch that already exists** (created by the orchestrator/`plan-em`/`ship`). On the `report` source, an unpassed `branch` defaults to the file's own `context.branch` (see `fix-build.md`). |
| `commit_mode` | *(optional)* `direct` or `sub-branch`. Default `direct`. See **Branch contract** below. |

### Branch contract (what `branch` means)

`branch` is the **feature branch the orchestrator created and will review** — the destination for this build's commits, **not** merely a PR target.

**Sub-PRD parent-aware derivation.** A sub-PRD (frontmatter `parent: prd-<parent-n>-<parent-slug>`) never gets its own branch — it rides the parent's `feat/prd-<parent-n>-<parent-slug>`. The resolver applies that rule, so derivation is identical whether `plan-em` passes `branch` or a human runs `eng --build` against the sub-PRD; Work-step 1's already-exists rule is unchanged (the parent branch is checked out, not created).

Two commit modes:

- **`direct` (default — used by `ship`):** commit **directly onto `branch`**; no sub-branch, no PR — the orchestrator reviews `branch` itself. Parallel agents share it safely because each owns a **disjoint set of files** (Step 6 scope enforcement).
- **`sub-branch` (direct human invocation):** cut `{branch}/{row-slug}` from `branch`, do all work there, commit, and open a PR into `branch`. Only for a standalone human run that wants a reviewable PR per agent.

**Example (direct):**
```
/eng --build prd-path=features/prd-4-habit-tracking/prd-4-habit-tracking.md rows="F2: Track streak — Schema migration; F2: Track streak — API contract" branch=feat/prd-4-habit-tracking
```

**Resolve the branch mechanically (PRD source)** — never hand-derive it or eyeball `git branch`. The resolver reads the PRD frontmatter (`parent:` included) and local branch state and prints `BRANCH=`/`ACTION=`:

```bash
B=.claude/scripts/script-em-branch-resolve.sh; [ -f "$B" ] || B="$HOME/.claude/scripts/script-em-branch-resolve.sh"; bash "$B" "<prd-path>"
```

- `ACTION=checkout` — use `BRANCH` when `branch` wasn't passed; if a passed `branch` differs, the caller wins (an orchestrator may target a shared branch) — note it in the build summary.
- `ACTION=create` or `ACTION=fresh-cut` — the target branch does not exist. Build agents never create branches: emit `Hard failure: target branch '<BRANCH>' does not exist — the orchestrator must create it before build agents run` and stop.
- Exit 2 (no PRD / not a git repo) — fall back to the passed `branch`, else hard-refuse as below.

**Hard-refuse if `branch` cannot be derived.** Apply the active source's derivation first (PRD: the resolver; `report`: `context.branch`). Still unresolved — no explicit value, no resolver result, no `context.branch` — emit `Hard failure: missing required field 'branch' for --build mode` and stop. Never enter pre-flight without a resolved `branch`.

---

## PRD read (Step 2 — standalone build, PRD/exec-table source)

Refines `SKILL.md` Step 2's **standalone** path for the PRD/exec-table source. Do **not** read the full PRD to locate the execution table and engineering section — run the PRD-digest generator for the **build** slice, once per assigned F-ID, and consume its JSON:

```bash
G=.claude/scripts/script-prd-digest.py; [ -f "$G" ] || G="$HOME/.claude/scripts/script-prd-digest.py"; python3 "$G" "<prd-path>" --slice build --feature <F-ID>
```

The slice returns the feature's row, its exec-table rows, the `todos` block (ticket ids + `prose_lines`) and the `engineering` block; the generator owns the field list. Omit `--feature` to get all features and filter to your `rows` locally. Every call re-parses the current PRD, so the slice is never stale (`.claude/skills/shared/refs/session-cache.md`). **A non-zero exit (`FEATURE_NOT_RESOLVED=<F-ID>` — the filter matched nothing; `FEATURE_ID_EMPTY=<row>` — the §3 id column didn't parse) means the PRD and the assignment disagree: stop and surface it, don't guess a feature from prose.**

**Escape hatch:** if a row needs a detail the slice omits — Design-decisions/Phases prose, identifiers buried in narrative, a heading under `unparsed_sections` — read only that engineering section's `prose_lines` range. Never default to the whole PRD.

The **orchestrated** path (injected scoped excerpts, PRD path as escape hatch) and the **`report`** source (no exec-table at all) do not invoke this slice.

The slice points at the `### F<n>` **todo** blocks rather than inlining them: read the ticket bodies from that `prose_lines` range in `## Todos — <Agent Name>`.

**Row ownership is verified mechanically** by the digest script grading the `rows`/`agent` pair, not by the model reading the table (`SKILL.md` Step 2).

## Summary content (Step 3 — Pre-run 1 of 2)

The 3–4 line summary covers:

- Line 1: what is being implemented — the feature and platform.
- Lines 2–3: which exec-table rows are owned and what code will be written (files created or modified, tests expected).
- Line 4 (optional): rows blocked by another agent — name the agent and row.

---

## Coding-standards flags (Step 4)

Standards resolve at `SKILL.md` Step 4. **Orchestrated runs use the injected `standards payload` and never call `/cook`.** Only a **standalone** build calls `/cook` itself, via **explicit flags** (never prose) so the call is cacheable and always loads the P0 floor.

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

**`--global` is mandatory, unscoped, and emitted whole on every call.** It loads the **P0 universal floor** plus all 8 concern refs (architecture, api-design, auth, security, performance, error-handling, debug, cicd), covering the row concerns (`migration`, `schema`, `auth`, `api`, `endpoint`, `webhook`, `hook`, `component`) — so no separate concern flags, and never scope its concern refs.

**Scope every DOMAIN flag to the refs the work needs — never emit the bare domain flag by default.** A bare `--macos` loads the domain's `SKILL.md` **plus every** `refs/*.md` — the full shelf. Sub-ref flags (`--macos:windows-and-scenes`) compile only the refs in scope. Per in-scope domain:

1. **Enumerate the domain's refs.** List `<cook>/standards/<domain>/refs/` or read its `_INDEX.md` ref table — **never hardcode a ref list**; shelves change.
2. **Keep by default; drop only on a PROVABLE exclusion.** Start from *every* ref. **Never under-load: missing a relevant standard is worse than loading an extra one.** Drop a ref only when the PRD/devkit **provably excludes its subject** (e.g. `distribution.md` when `CLAUDE.md` defers distribution). On **any** uncertainty, **keep**.
3. **Always keep the domain `SKILL.md` floor.** The platform-correctness P0/P1 baseline, never "provably excluded" — emit the bare `--<domain>` to anchor it; sub-ref flags narrow only the *refs*.
4. **Emit `--<domain>:<ref>` for each KEPT ref.** Provably-excluded refs are simply not requested.
5. **Whole-domain fallback.** If you cannot confidently scope a domain — unclear ref footprint, or the `SKILL.md`'s in-scope P0 not confidently covered by the kept refs — fall back to the bare `--<domain>` flag alone.

**Tests sub-ref (unchanged).** If a **Tests** row is owned, add the stack's testing sub-ref alongside the scoped refs: `--flutter:testing` / `--dart:testing` / `--react:testing` / `--nextjs:testing` / `--nodejs:testing` / `--typescript:testing` / `--graphql:testing` / `--swift:testing`.

Invoke `/cook` **once** with `--global` + every applicable domain's scoped flag set; multi-stack rows add each stack's flags to the **same** call. Example (macOS; distribution, entitlements and i18n provably excluded):

```
/cook --global --macos --macos:architecture-and-state --macos:windows-and-scenes --macos:performance-accessibility --macos:hig-conventions --macos:testing
```

A repeated identical flag set is a cook **cache hit**. Read the result fully. If `/cook` returns no coverage for a stack, do not substitute another stack's standards — surface the uncovered stack as a named gap in the build summary and proceed on `CLAUDE.md` + `devkit/ARCHITECTURE.md` conventions for it.

---

## Work steps (Step 5)

**Spec source — the todo tickets, and nothing else.** `eng --plan` writes them in the same pass as the engineering section, so every owned F-ID has a `### F<n>` block under this agent's `## Todos — <Agent Name>` section. There is no second spec: the exec-table row's Execution steps cell is a **pointer** to the ticket ids that deliver it (`→ F2-T1, F2-T2`), not a work description.

- Work the `### F<n>` block's **tickets** directly (schema: `refs/plan/template-todo.md`). Each carries `id`, `title`, `objective`, `type`, `files` (path + `add|edit|remove`), `depends-on`, `done-when`. To execute: make the `files` changes to deliver the `objective`, then satisfy `done-when`. A mechanical checklist — never re-derive tasks from engineering prose. **Sentinel:** an explicitly empty block (`_No discrete work for this feature._`) means nothing to build for that feature.
- **Ordering (`depends-on`, then ticket-id order).** A ticket runs only after every id in its `depends-on` is complete; among unblocked tickets take ticket-id order (`F1-T1` → `F1-T2` → `F2-T1`). A `depends-on` naming an id absent from this PRD's `## Todos`, or a dependency cycle, is a blocking gap → surface via `AskUserQuestion`, never guess an order.
- **`objective` keeps scope honest.** Implement exactly what serves it; anything beyond is out of scope (Step 6).
- **Missing tickets are a plan failure, not a fallback.** No `### F<n>` block for an assigned F-ID, or a pointer id resolving to no ticket, means the plan pass was incomplete: emit `Hard failure: no todos for '<F-ID>' — plan pass incomplete, re-run eng --plan` and stop. Never reconstruct a spec from exec-table prose or engineering-section narrative.

`## Engineering — <Agent Name>` remains the authority on the surrounding design decisions and cross-agent contracts; the tickets are the work. Do not re-interpret the PRD features section directly.

**`report=` source.** The numbered steps below still run, with source-specific deltas (Item 0 skipped, Item 2 reads each issue, Item 4 collapses to reproduce→fix→verify, plus flaky handling, `Issue`-keyed summary and loop-closing) — **see `fix-build.md`**.

0. **Cross-check the pointers resolve.** Before reading any file: every assigned row's Execution steps cell names at least one ticket id, **every named id resolves** to a real ticket under `## Todos — <Agent Name>`, and the `## Engineering — <Agent Name>` section references each assigned row (row label or feature ID). A missing row, an empty or unresolvable pointer cell, or a row absent from §Engineering is a blocking gap — surface via `AskUserQuestion` and do not proceed until resolved. Do not guess intent; `plan-review --eng` may have edited the table after the section was written.

1. **Check out the work branch (per `commit_mode`).** `branch` already exists — the orchestrator (`plan-em`/`ship`) creates it once before build agents start; never create it yourself. If it does not exist: emit `Hard failure: target branch '<branch>' does not exist — the orchestrator must create it before build agents run` and stop. Then:
   - **`commit_mode: direct` (default):** check out `branch` and work on it. Touch only the files your assigned rows specify (Step 6) so parallel agents stay file-disjoint.
   - **`commit_mode: sub-branch`:** derive `{branch}/{row-slug}` mechanically from the first assigned row, cut it from `branch`, check it out, work there:
     ```bash
     ROW_SLUG=$(printf '%s' "<first assigned row>" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\+/-/g; s/^-//; s/-$//')
     ```
   Do not push until the commit step.
2. **Read the tickets.** For each assigned F-ID, read its `### F<n>` todo block per **Spec source** above, following each row's Execution steps pointer to the ticket ids it owns. An unresolvable pointer or a missing block is the hard failure named there.
3. **Discover testing tools.** Before writing any test file, scan existing test files in the feature area for:
   - Test runner and framework (e.g. `pytest`, `jest`, `go test`, `flutter_test`)
   - Assertion libraries and matchers in use
   - Test file naming convention and directory layout
   - Factory, fixture, or mock patterns
   - Shared setup helpers (e.g. `beforeEach`, `setUp`, conftest fixtures)

   Apply the findings to every test file written in step 4. With no existing test files, check `CLAUDE.md` and `devkit/ARCHITECTURE.md` for the declared test stack.

4. **Execute tickets in TDD order.** Take tickets in **Spec source** order (`depends-on`, then ticket id), grouped by F-ID; complete all four phases (a–d) for a group before the next. Phase follows ticket `type` (`code | test | config | migration | doc`): a `test` ticket is phase (a); `code`, `migration`, `config`, `doc` are phase (c); every ticket ends at its own `done-when` in phase (d).

   **Test surface — unit + integration only.** The TDD loop runs unit and integration tests only; e2e, visual, perf, a11y and coverage belong to pre-merge, not the inner loop.

   **a. Write tests.** For each `test` ticket, create the file using step 3's conventions and tooling. Write syntactically valid, runnable assertions derived from the ticket's `objective` and `done-when` — no `TODO` placeholders, must compile or parse. Do not invent tests for a group with no `test` ticket; a missing test ticket is a planner gap, not eng's to fill. **If a group owns implementation tickets but no `test` ticket, do not silently ship it untested:** emit `⚠ No test ticket for group '<F-ID>' — shipping implementation without coverage`, record it in the build summary's Blocked/Notes and in `devkit/AHA.md`, then proceed.

   **b. Verify red.** Run only the test files just written; confirm they fail with assertion failures, not compile or import errors. A test that errors is not a red test — fix the setup until it fails cleanly on a real assertion before implementing.

   **c. Write implementation.** For each implementation ticket, in the order above, create or modify exactly the files named in its `files`. Apply the Step 4 coding standards (injected `standards payload`, or `/cook` on a standalone run). Reuse existing `DESIGN-SYSTEM.md` components before creating new ones.

   **Write the minimum (brevity mandate).** Write the least code that satisfies the ticket's `done-when` — no speculative abstraction, no single-caller indirection, no unrequested generality or options. Prefer a stdlib or framework call over hand-rolled code.

   **Plain-English comments (A4).** Every new or modified function, module, class and exported symbol gets a comment on the line above stating in plain English **what** it does (not how). Enforced mechanically once: `script-eng-comment-scan.sh` greps the staged diff at the commit gate (Step 7) for *presence*. It cannot read a comment, so what-versus-how is judged by the reviewer at Step 5a (`refs/review/protocol.md`).

   **d. Verify green.** Re-run this group's test files and check each ticket's `done-when`. All pass → next group. Any failure → Debug mode (`protocol-build-debug.md`). Do not move on until the group is green.

5. **Full-suite gate (unit + integration).** After all feature groups are green, run the project's **unit + integration** suite and lint/typecheck once (discover the commands from `CLAUDE.md`, `devkit/ARCHITECTURE.md`, or the package manifest — e.g. `npm test`/`npm run lint`, `pytest`, `flutter test`). Unit + integration only — e2e / visual / perf / a11y / coverage belong to pre-merge. This catches breakage in sibling code the per-group runs never touched. Any new failure introduced by this agent's changes goes to Debug mode (`protocol-build-debug.md`, max 3 cycles) before committing. A pre-existing failure unrelated to the assigned rows is noted in the build summary, not fixed. No test or lint command → state that in the summary and continue.
   *Caller override: orchestrators (e.g. `ship`) may suppress this gate and run a dedicated test stage instead. When suppressed, skip to step 5a.*

   **5a. Whole-change review (spawned by default).** Once the full-suite gate has passed and **before** the human confirmation at Step 6, spawn **one** reviewer subagent over the whole change — `refs/review/protocol.md` owns the protocol, inputs, severity discipline, return contract and spawn rules; do not restate them here. It runs on **every** build that produced a diff — no size threshold, no skip condition, no fast path — so nothing reaches the human unreviewed. Inject the change set, the worked tickets' `done-when`, and the PRD digest's acceptance criteria. On return: resolve every `blocker` and `high` (apply the reviewer's fix, or put its question to the human at Step 6) before proceeding; record `medium`/`low` findings and the one-line verdict in the build summary's **Review** line, ungating. A re-review after fixes is a judgment call, not a required round.

6. **Confirm before commit.** First, the **production guardrail (never skipped under any autonomy contract — `shared/refs/safety-floor.md`):** run `.claude/scripts/script-eng-db-touch.sh` (fall back to `$HOME/.claude/scripts/script-eng-db-touch.sh`) against the working diff. If it flags database/data/production-config files, or the change introduces a breaking change (removed/renamed public API, changed contract or schema), pause via `AskUserQuestion` and require explicit sign-off before committing — the caller-override pre-approval below does **not** cover this pause. Then emit a one-line change summary (files touched, tests added, full-suite result) and ask via `AskUserQuestion` whether to commit and open the PR. Proceed only on an explicit "Yes". This is the single human gate between writing code and publishing it.
   *Caller override: under an autonomy contract (e.g. `ship`) this gate is pre-approved; proceed without prompting — except the production guardrail, which always pauses when tripped.*

7. **Commit per ticket (to the work branch).** On Step 6's single approval, commit — **one commit per todo ticket** (or per coherent group that reads as one reviewable unit — `refs/plan/template-todo.md`, rule 2). Do **not** add a per-ticket `AskUserQuestion` — Step 6's confirmation (and the production guardrail) cover the whole run. For **each** commit, run the two mechanical gates on the **staged** diff before committing (local script, then the `$HOME` fallback):
   ```bash
   C=.claude/scripts/script-eng-comment-scan.sh; [ -f "$C" ] || C="$HOME/.claude/scripts/script-eng-comment-scan.sh"; "$C" --staged
   P=.claude/scripts/script-eng-commit-cap.sh;   [ -f "$P" ] || P="$HOME/.claude/scripts/script-eng-commit-cap.sh";   "$P" --message "<the prepared commit message>"   # add --breaking on a breaking-change commit
   ```
   - **Comment scan (A4):** any `UNCOMMENTED <file>:<line>` flag → add the plain-English comment and re-stage before committing. A genuine false positive is left as-is and noted in the summary.
   - **Commit cap (A5):** pass `--breaking` when the commit contains a breaking change (removed/renamed public API, changed contract/schema) — the cap drops from 500 to 300 changed LOC. **The size measurement never blocks:** the script prints `CAP_OK`/`CAP_EXCEEDED <loc>/<cap>` and an under-cap commit always exits 0 — commit-time LOC is a measured fact the agent judges. On `CAP_EXCEEDED`, judge split-or-commit: prefer **splitting** into smaller ticket-sized commits.
   - **The `Oversize-reason:` trailer is enforced mechanically, not by memory.** Always pass the prepared commit message (`--message "<text>"` or `--message-file <path>`; `-` reads stdin). Over cap the script greps it for an `Oversize-reason: <text>` trailer: present → `TRAILER_OK`, exit 0; absent → `TRAILER_MISSING`, **exit 3** — add the trailer or split the commit and re-run, never commit through it. Omitting the message prints `TRAILER_UNCHECKED` and leaves the gap open. Also pass `--oversize-reason "<text>"` to print `OVERSIZE <loc> reason: <text>`, and log that justification to the §11 Findings ledger. A **recurring** oversize pattern is a ticket-sizing signal — note it in the build summary and `devkit/AHA.md`.

   Use a conventional commit message referencing the feature and ticket ids (e.g. `feat(streaks): add streaks table [F1-T1]`). Commits land on `branch` in `direct` mode, on the sub-branch in `sub-branch` mode.
8. **Open PR (`sub-branch` mode only).** When all assigned rows are complete and tests pass, open a PR from the sub-branch to `{branch}` and link the PRD path in the description; never open a PR against `main`. **In `direct` mode, skip this step** — no sub-branch, no PR; the orchestrator reviews `branch` directly.

---

## Debug mode

Activates on a test failure at verify-green (step 4d) or a compile/runtime error during implementation (step 4c): a bounded per-issue cycle (identify → isolate → hypothesize → fix → verify → log), max 3 cycles, then a structured escalation. **See `protocol-build-debug.md`** — load it only when a failure actually occurs.

---

## AHA.md

Throughout the build, record a learning in `devkit/AHA.md` — the file pre-flight reads, so learnings resurface in future plan runs — when:

- The codebase scan reveals a pattern not in the pulled coding standards.
- A ticket cannot be implemented as written.
- A cross-agent dependency surfaces mid-build that no ticket's `depends-on` marks.
- A non-obvious implementation decision is made.
- A debug cycle runs (regardless of outcome).

**Eng judges *when* to log and *what* it says; the writer is shared** — call the file's one writer, which owns entry shape, most-recent-first ordering and the recurrence count:

```bash
A=.claude/scripts/script-aha.sh; [ -f "$A" ] || A="$HOME/.claude/scripts/script-aha.sh"
bash "$A" devkit/AHA.md --tag "eng:<class>" --summary "<what happened>" \
  --why "<why it matters to a future run>" --note "<what was done, or 'unresolved — see debug escalation'>"
```

- `--tag` names the class (e.g. `eng:standards-gap`, `eng:ticket-unbuildable`, `eng:debug-escalation`) — same tag for the same class every time, so recurrences count.
- **Exit 3** = no `devkit/AHA.md` in this project → skip the write silently and continue; not a build failure.
- Exit 2 = usage error or malformed target file → note it in the build summary's **Warnings** and continue.

Reference any AHA entries written during the run in the build summary.

---

## OPEN-QUESTIONS.md

Throughout the build, append to `devkit/OPEN-QUESTIONS.md` (read by `plan-pm` and `plan-em` pre-flight, and by `handoff`) when eng cannot resolve an ambiguity itself and must proceed on an assumption. Distinct from `devkit/AHA.md`: AHA logs what eng *learned or decided*; OPEN-QUESTIONS logs what eng *could not decide*. Append when:

- An execution step's intent is genuinely ambiguous (not merely inferable from the PRD/CLAUDE.md/ARCHITECTURE.md) and eng proceeds on a stated assumption.
- A product or design decision surfaces mid-build that the PRD didn't anticipate and that affects scope beyond the current row.
- A debug escalation (3 failed cycles, `protocol-build-debug.md`) leaves a row unresolved — log here *in addition to* AHA.

**Eng judges *when* to log and *what* it says; the writer is shared** — call the file's one writer, which owns entry shape and guarantees the append lands in `## Open Questions`, never `## Resolved`:

```bash
Q=.claude/scripts/script-openq.sh; [ -f "$Q" ] || Q="$HOME/.claude/scripts/script-openq.sh"
bash "$Q" devkit/OPEN-QUESTIONS.md --title "<one-line question title>" \
  --question "<the decision that could not be made>" --raised-by "eng-<agent name>" \
  --severity <critical|high|medium|low> --context "<the assumption the build proceeded on>"
```

- `--status` defaults to `open`; build agents never pass anything else (`in-progress`/`resolved` are a human's or planner's call).
- **Exit 3** = no `devkit/OPEN-QUESTIONS.md` in this project → skip the log silently and continue.
- Exit 2 = usage error or malformed target file → note it in the build summary's **Warnings** and continue.

Reference any entries written during the run in the build summary.

---

## Output contract (Step 5)

Emit after all rows are complete:

```markdown
## Build summary — <Agent Name>

| Row | Files created | Files modified | Tests | Status |
|-----|--------------|---------------|-------|--------|
| <Feature — Concern> | `<path/created>` | `<path/modified>` | ✅ <n>/<n> pass | ✅ Done |

**PR:** <link, or "none — direct commit mode">
**Branch:** <branch the commits landed on — the feature branch in `direct` mode, or the sub-branch name in `sub-branch` mode>
**Target:** <feature branch (branch field value)>
**Full-suite gate:** <pass / fail summary, or "no test/lint command">
**Review:** <the reviewer's one-liner from Step 5a — `reviewed <n> files — <k> fixed, <q> questions, <c> comments added`, or "— clean"; list any recorded medium/low findings>
**Warnings:** <e.g. groups shipped without a test ticket, uncovered stacks from /cook, or "None">
**Blocked rows:** <list any rows not completed and why>
**AHA entries:** <list any entries written to devkit/AHA.md, or "None">
**Open questions:** <list any entries written to devkit/OPEN-QUESTIONS.md, or "None">
**Report:** <path to the report-prd-<N>-<K>.md if the file was written, else "inline — the build summary above is the report of record">
```

**`report=` source.** The summary table is keyed by `Issue` (not `Row`) and the loop is closed in the source file's `followUp.status` — see `fix-build.md`.

### Run report — `report-prd-<N>-<K>.md`

The inline build summary is always emitted and is the **report of record**; a `report-prd-<N>-<K>.md` file only *supplements* it (`../../../shared/refs/report-schema.md`). After emitting the summary, **best-effort** write that run report per the schema — path resolution, `<N>`/`<K>` numbering, frontmatter keys and the section contract all live there; do not improvise fields. If it cannot be written, the inline summary is the sanctioned fallback: note the skipped report under **Warnings** and continue — never fail or block the build over it. Build-mode specifics:

- Directory: `features/prd-<N>-<slug>/reports/` derived from `prd-path` (create if absent).
- Frontmatter: `skill: eng`; `prd` = `prd-path`; `branch` = the branch the commits landed on; `verdict` mapped from the full-suite gate (`pass` / `fail`, `n/a` when no test command); `features` = the assigned rows' feature ids; diff stats from `rtk git diff --numstat` over this agent's commits; test counts from the per-group and full-suite runs.
- `## What to expect` / `## How to verify` are written for the human who will use the feature, in plain non-technical language: derive the steps from the PRD acceptance criteria of the rows built and the tests written — what to do and what they should see.

**Constraints:**
- Use the PRD's `## Engineering — <Agent Name>` section as the sole specification.
- Do not modify the PRD file.
- Commits must land on the feature branch (`branch`): directly in `direct` mode, or via a PR into it in `sub-branch` mode. Never commit to or open a PR against `main`.
- Do not modify files outside the assigned exec-table rows' scope — this also keeps parallel `direct`-mode agents file-disjoint on the shared branch. (Run artifacts are exempt: `devkit/AHA.md`, `devkit/OPEN-QUESTIONS.md`, and the run report under `features/…/reports/` — the report's max+1 numbering keeps parallel agents from colliding; on a collision, re-derive `K` and retry once.)
