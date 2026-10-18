---
name: Build loop — tickets to commits
description: The one build loop — tickets, TDD, full-suite gate, review and re-test, db-touch pause, one commit per ticket, output. An orchestrated packet reads only this file; a manual build reads it through protocol.md, which adds the solo-only steps.
type: reference
---

# Build loop

This file is the build loop, written once. Two readers:

- **An orchestrated packet** (spawned by `plan-em` or another orchestrator) reads **only this file**. Do not read `eng/SKILL.md` or `refs/build/protocol.md`.
- **A manual build** reads `refs/build/protocol.md` first. That file adds the solo-only steps (branch, standards, progress messages, the "Commit?" question, the sub-branch PR) and then runs Steps 0–7 below.

## What the orchestrator guarantees a packet (do not re-derive)

The feature **branch exists and is checked out**. The stack's **`standards payload` is injected**. **Scoped context** is injected (your rows, the mapped PRD feature sections, a devkit digest); the PRD path is the escape hatch for anything an excerpt cannot resolve. Every **approval gate is pre-approved**. The **review regime is decided for you** (`review=self` or `review=batched` — Step 5). The **progress messages are sent for you** from your returned `status:` line.

A packet **never**: creates or switches a branch · calls `/cook` · opens a PR · calls the status-tick script · touches a file outside its packet · reads a `report=` issues file · spawns anything except its Step 5 reviewer.

Two things are **never** pre-approved: the **db-touch pause** (Step 6) and a genuine blocker you cannot derive — return the blocker rather than guess.

---

## Step 0 — Record the run base

Before your first change, record the commit you start from. The db-touch pause (Step 6) checks only the changes made after it:

```bash
RUN_BASE=$(git rev-parse HEAD)
```

## Step 1 — Read your tickets (the only spec)

Your `rows` are exec-table `Feature — concern` cells. Take their **F-IDs**. For each, read the `### F<n>` block under `## Todos — <agent>` in the PRD.

- **The tickets are the only spec.** `## Engineering — <agent>` is design context (surrounding decisions, cross-agent contracts), never a second spec. Do not re-interpret the PRD's features section, and never rebuild a spec from prose.
- Each ticket carries `id`, `title`, `objective`, `type` (`code | test | config | migration | doc`), `files` (path + `add|edit|remove`), `depends-on`, `done-when`. To execute one: make the `files` changes that deliver the `objective`, then satisfy `done-when`. The `objective` keeps scope honest — build exactly what serves it.
- **Order.** A ticket runs only after every id in its `depends-on` is complete. Among unblocked tickets, take ticket-id order (`F1-T1` → `F1-T2` → `F2-T1`).
- **Sentinel.** A block reading `_No discrete work for this feature._` means nothing to build for that feature. It is not an error.
- **A plan defect stops the run — never a question.** A missing `### F<n>` block, a `depends-on` naming an absent id, or a dependency cycle means the plan is incomplete. Emit one line and stop: `<F-ID> has no tickets. Run /plan-em again.` (for example `F3 has no tickets. Run /plan-em again.`), or `<F-ID> tickets have a broken depends-on. Run /plan-em again.`

## Unclear requirements

A ticket whose intent you cannot settle from the ticket, `## Engineering —`, `CLAUDE.md` or `devkit/ARCHITECTURE.md`:

- **A user is present** (a manual build): ask via `AskUserQuestion` — 3–4 concrete options, naming the ticket.
- **An automatic run** (a packet, or any run under an autonomy contract): take the most conservative reading, state the assumption in the summary's **Open questions** line, and log it to `devkit/OPEN-QUESTIONS.md` (§ Learnings and open questions).

## Step 2 — Discover the testing tools

Before writing any test: scan existing test files in the feature area for the runner and framework, assertion style, file naming and layout, factory/fixture/mock patterns, and shared setup helpers. Apply them to every test you write. With no existing tests, take the declared stack from `CLAUDE.md` / `devkit/ARCHITECTURE.md`.

## Step 3 — Execute tickets in TDD order

Group by F-ID; complete all phases for a group before the next. A `test` ticket is phase (a); `code`, `migration`, `config`, `doc` tickets are phase (b). **Unit and integration tests only** — e2e, visual, perf, a11y and coverage belong to pre-merge.

**a. Red.** For each `test` ticket, write runnable assertions derived from its `objective` and `done-when` — no `TODO` placeholders. Run only those files and confirm they fail on a **real assertion**, not a compile or import error. A test that errors is not red; fix the setup first.
Do not invent tests for a group with no `test` ticket — that is a planner gap. Do not ship it silently either: emit `⚠ No test ticket for group '<F-ID>' — shipping implementation without coverage`, record it in the summary's **Warnings** and in `devkit/AHA.md`, then proceed.

**b. Green.** Create or modify **exactly** the files named in each implementation ticket's `files`, applying the coding standards (the injected `standards payload`, or the standards a manual build resolved). Reuse `devkit/DESIGN-SYSTEM.md` components before creating new ones. **Write the minimum** — the least code that satisfies `done-when`; no speculative abstraction, no single-caller indirection, no unrequested generality; prefer a stdlib or framework call over hand-rolled code. **Plain-English comments (A4):** every new or modified function, module, class and exported symbol gets a comment on the line above saying **what** it does, not how. The commit gate greps for presence; the reviewer judges what-versus-how.

**c. Verify.** Re-run the group's tests and check each ticket's `done-when`. All pass → next group. A failure, or a compile/runtime error in (b) → debug mode (`protocol-build-debug.md`). Do not move on until the group is green.

## Step 4 — Full-suite gate

After all groups are green, run the project's **unit + integration** suite and lint/typecheck once (discover the commands from `CLAUDE.md`, `devkit/ARCHITECTURE.md`, or the package manifest). This catches breakage in sibling code the group runs never touched. A new failure your changes introduced goes to debug mode before committing. A pre-existing unrelated failure is noted, not fixed. No test or lint command → say so and continue.

**The caller may suppress this gate** and run a dedicated test stage instead. When suppressed, go straight to Step 5.

## Step 5 — Whole-change review, then re-test

**Who reviews is decided by the injected `review=` field.** A manual build is always `self`.

| `review=` | What you do |
|-----------|-------------|
| `self` (default, and the value assumed if the field is absent) | Spawn your own reviewer, as below. |
| `batched` | **Do not spawn a reviewer.** The orchestrator reviews the whole wave's diff after your packet lands; its artifact records your packet key. Go to Step 6, and write `batched — covered by the wave review` on your **Review** line. |

`batched` is not permission to go unreviewed. The orchestrator's coverage check verifies every packet key in the wave from the filesystem, yours included.

**When `review=self`:** once the suite has passed (or been suppressed) and **before** any commit, spawn **one** reviewer subagent over your whole change. It runs on **every** build that produced a diff — no size threshold, no skip. `refs/review/protocol.md` owns its protocol, severity discipline, return contract and spawn rules.

- Inject the change set, the worked tickets' `done-when`, the digest's acceptance criteria, and **the identity fields**: `built_by` (your agent name) and `<K>`. A packet passes through the key the orchestrator gave it, unchanged. A manual build uses the `<K>` of its own run report, so the build and its review sit side by side.
- **The artifact is required.** The reviewer writes `<prd-dir>/reports/review-prd-<N>-<K>.json` before returning. That file, not the returned prose, is what a coverage check reads.
- On return, resolve every `blocker` and `high`: apply the reviewer's fix, or carry its question to the user (a manual build asks it with "Commit?"; a packet returns it as a blocker). Record `medium`/`low` findings, the verdict and the artifact path on the **Review** line. A re-review after fixes is a judgment call, not a required round.

**Re-test after any code change in review.** When the reviewer's `fixed[]` is non-empty, or you changed code to resolve a finding, run the tests again before Step 6 — the full suite (Step 4), or the touched groups' tests when the caller suppressed the full suite. A failure goes to debug mode, as for any other test failure. When review changed nothing, nothing extra runs. This keeps "tests pass" in the summary true.

## Step 6 — The db-touch pause (never skipped)

Before committing, run the production guardrail over **this run's own changes** — never skipped under any autonomy contract (`shared/refs/safety-floor.md`):

```bash
D=.claude/scripts/script-eng-db-touch.sh; [ -f "$D" ] || D="$HOME/.claude/scripts/script-eng-db-touch.sh"
bash "$D" "$RUN_BASE"                                   # manual build
```

**An orchestrated packet checks only its own ticket `files`.** Sibling packets share the branch and the working tree, so their changes must not trip your pause. Collect the changed paths, keep only the paths named in your tickets' `files`, and pipe the list to the script:

```bash
{ git diff --name-only "$RUN_BASE" HEAD; git diff --name-only; git diff --name-only --cached; git ls-files --others --exclude-standard; } \
  | sort -u | grep -Fx -f <(printf '%s\n' <each path in your tickets' files>) | bash "$D" -   # orchestrated packet
```

Exit 1 prints `category<TAB>path` lines (migration, SQL, ORM schema/entity, seed/fixture, `.env`/secrets, production config). On exit 1 — or when your change removes/renames a public API or alters a contract or schema — **pause via `AskUserQuestion` and require explicit sign-off before committing.** No pre-approval reaches this pause, and it is never merged into another question.

## Step 7 — One commit per ticket

Commit onto the checked-out branch. **Every todo ticket gets its own commit** — no grouping, in a manual build and in a packet alike. When one file serves several tickets, stage each ticket's part separately (`git add -p`), or order the tickets so each commit stays whole. No per-commit approval prompt.

**Both gates run on every commit**, on the **staged** diff:

```bash
C=.claude/scripts/script-eng-comment-scan.sh; [ -f "$C" ] || C="$HOME/.claude/scripts/script-eng-comment-scan.sh"; "$C" --staged
P=.claude/scripts/script-eng-commit-cap.sh;   [ -f "$P" ] || P="$HOME/.claude/scripts/script-eng-commit-cap.sh";   "$P" --message "<the prepared commit message>"   # add --breaking on a breaking change
```

- **Comment scan (A4).** Any `UNCOMMENTED <file>:<line>` → add the comment and re-stage. A genuine false positive is left and noted.
- **Commit cap (A5).** The size measurement is advisory: `CAP_OK` / `CAP_EXCEEDED <loc>/<cap>`; an under-cap commit never blocks. `--breaking` drops the cap from 500 to 300 changed lines. On `CAP_EXCEEDED`, prefer splitting.
- **The `Oversize-reason:` trailer is not advisory.** Always pass the prepared message. Over cap with no `Oversize-reason: <text>` trailer prints `TRAILER_MISSING` and **exits 3** — add the trailer or split, never commit through it. A recurring oversize pattern is a ticket-sizing signal: note it in the summary and `devkit/AHA.md`.

Conventional messages naming feature and ticket: `feat(streaks): add streaks table [F1-T1]`.

## Scope (continuous)

Act only on what your assigned rows specify — no extra refactors, no unrelated file touches. This also keeps parallel builds file-disjoint on a shared branch. Exempt: `devkit/AHA.md`, `devkit/OPEN-QUESTIONS.md`, and the run report and review artifact under `features/…/reports/`.

## Learnings and open questions

You judge *when* to write and *what* it says; the shared writers own the entry shape. Each field is one terse clause (≤140 chars, single line — the writer rejects longer; compress and retry). **Exit 3 = no such file in this project → skip silently.** Exit 2 → note it in **Warnings** and continue.

**AHA** — write one entry when: the codebase shows a pattern the standards lack; a ticket cannot be built as written; an unmarked cross-agent dependency surfaces; a non-obvious decision is made. **One entry per bug**, written once the bug is fixed or escalated — never one per debug round (`protocol-build-debug.md`). Use the same `--tag` for the same class (`eng:standards-gap`, `eng:ticket-unbuildable`, `eng:debug`), so recurrences count.

```bash
A=.claude/scripts/script-aha.sh; [ -f "$A" ] || A="$HOME/.claude/scripts/script-aha.sh"
bash "$A" devkit/AHA.md --tag "eng:<class>" --summary "<what happened>" --why "<why a future run cares>" --note "<what was done>"
```

**OPEN-QUESTIONS** — when an automatic run proceeds on an assumption (§ Unclear requirements), an unanticipated product decision surfaces, or a bug is escalated:

```bash
Q=.claude/scripts/script-openq.sh; [ -f "$Q" ] || Q="$HOME/.claude/scripts/script-openq.sh"
bash "$Q" devkit/OPEN-QUESTIONS.md --title "<one-line title>" --question "<what could not be decided>" \
  --raised-by "eng-<agent>" --severity <critical|high|medium|low> --context "<the assumption taken>"
```

## Output — the build summary

The first line states the result. Every line after the table shows **only when it has content** — never write a "None" line. A packet keeps three elements always: the result line, the **Review** line and the `status:` line.

```markdown
## Build summary — <agent>

**Result:** <✅ done | ⛔ blocked> · tests <pass <n>/<n> | fail | not run: no test command | suppressed by caller> · review <pass | warn | block | batched>

| Row | Files created | Files modified | Tests | Status |
|-----|--------------|---------------|-------|--------|
| <Feature — concern> | `<path>` | `<path>` | ✅ <n>/<n> pass | ✅ Done |

**Branch:** <the branch the commits landed on>
**Review:** <reviewer one-liner> · `<verdict>` · evidence: `<reports/review-prd-<N>-<K>.json>` — or `batched — covered by the wave review`
**Warnings:** <groups shipped without a test ticket, uncovered stacks, skipped report write>
**Blocked rows:** <row — why>
**AHA entries:** <entries written>
**Open questions:** <assumptions taken, entries written>

status: <packet key> <done|blocked> — <≤8-word summary>      ← packets only
```

A packet emits no other free-form prose. A manual build adds its own lines (`refs/build/protocol.md` § Summary and run report).

Log unexpected script failures, tool errors and missed writes to `devkit/DOCTOR.md` per `../../../shared/refs/doctor-logging.md` — logging never changes what you do next.
