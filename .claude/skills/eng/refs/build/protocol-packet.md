---
name: Build Packet Protocol — orchestrated leaf fast path
description: The complete contract for one orchestrated build leaf — tickets, TDD loop, review artifact, commit gates, output. Read INSTEAD of SKILL.md + protocol.md when an orchestrator spawned you.
type: reference
---

# Build packet — the orchestrated leaf's whole protocol

You are **one packet** of a parallel build coordinated by an orchestrator. This file is everything you need and nothing you do not. Do **not** read `eng/SKILL.md` or `refs/build/protocol.md` — they carry the standalone-run paths (branch creation, the `report=` fix source, `/cook` resolution, sub-branch PRs, the status heartbeat) that are **forbidden or already handled** here.

## What is already true (do not re-derive)

The orchestrator guarantees all of this before you start: the feature **branch exists and is checked out**; the stack's **`standards payload` is injected**; **scoped context** (your rows, the mapped PRD feature sections, a devkit digest) is injected, with the PRD path as an escape hatch for anything an excerpt cannot resolve; every **approval gate is pre-approved**; the **review regime is decided for you** (`review=self` or `review=batched` — Step 5); and the **status heartbeat is ticked for you** from your returned `status:` line.

Two things are **not** pre-approved and never can be: the **db-touch pause** (Step 6) and a genuine blocker — if you are blocked by information you cannot derive, return the blocker rather than guessing.

**You never:** create or switch a branch · call `/cook` · open a PR · call the status-tick script · touch a file outside your packet · read a `report=` issues file · spawn anything except your Step 5 reviewer.

---

## Step 1 — Read your tickets

Your `rows` are exec-table `Feature — concern` cells. Take their **F-IDs**, and for each read the `### F<n>` block under `## Todos — <agent>` in the PRD. **Those tickets are the entire spec.** There is no pointer to follow and no second index (v5.4 removed both).

Each ticket carries `id`, `title`, `objective`, `type` (`code | test | config | migration | doc`), `files` (path + `add|edit|remove`), `depends-on`, `done-when`. To execute one: make the `files` changes that deliver the `objective`, then satisfy `done-when`.

- **Order.** A ticket runs only after every id in its `depends-on` is complete; among unblocked tickets, ticket-id order (`F1-T1` → `F1-T2` → `F2-T1`). A `depends-on` naming an absent id, or a cycle, is a blocker — return it, never guess an order.
- **Sentinel.** A block reading `_No discrete work for this feature._` means nothing to build for that feature — not an error.
- **Missing block.** No `### F<n>` for an assigned F-ID → emit `Hard failure: no todos for '<F-ID>' — plan pass incomplete, re-run eng --plan` and stop. Never reconstruct a spec from prose.
- `## Engineering — <agent>` is the authority on surrounding design and cross-agent contracts; the tickets are the work. Do not re-interpret the PRD's features section directly.

## Step 2 — Discover the testing tools

Before writing any test: scan existing test files in the feature area for the runner and framework, assertion style, file naming and layout, factory/fixture/mock patterns, and shared setup helpers. Apply them to every test you write. With no existing tests, take the declared stack from `CLAUDE.md` / `devkit/ARCHITECTURE.md`.

## Step 3 — Execute tickets in TDD order

Group by F-ID; complete all four phases for a group before the next. **Unit and integration tests only** — e2e, visual, perf, a11y and coverage belong to pre-merge.

**a. Red.** For each `test` ticket, write runnable assertions derived from its `objective` and `done-when` — no `TODO` placeholders. Run only those files and confirm they fail on a **real assertion**, not a compile or import error. A test that errors is not red; fix the setup first.
Do not invent tests for a group with no `test` ticket — that is a planner gap. But do not silently ship it either: emit `⚠ No test ticket for group '<F-ID>' — shipping implementation without coverage`, record it in the summary's Warnings and in `devkit/AHA.md`, then proceed.

**b. Green.** Create or modify **exactly** the files named in each implementation ticket's `files`, applying the injected `standards payload`; reuse `devkit/DESIGN-SYSTEM.md` components before creating new ones. **Write the minimum** — the least code that satisfies `done-when`, no speculative abstraction, no single-caller indirection, no unrequested generality; prefer a stdlib or framework call over hand-rolled code. **Plain-English comments (A4):** every new or modified function, module, class and exported symbol gets a comment on the line above saying **what** it does, not how (a gate greps for presence at commit; the reviewer judges what-versus-how).

**c. Verify.** Re-run the group's tests and check each ticket's `done-when`. All pass → next group. Any failure → the bounded debug cycle in `protocol-build-debug.md` (identify → isolate → hypothesise → fix → verify → log, max 3 cycles, then escalate). Do not move on until the group is green.

## Step 4 — Full-suite gate

After all groups are green, run the project's **unit + integration** suite and lint/typecheck once (discover the commands from `CLAUDE.md`, `devkit/ARCHITECTURE.md`, or the package manifest). This catches breakage in sibling code the per-group runs never touched. Any new failure your changes introduced goes to debug mode before committing; a pre-existing unrelated failure is noted, not fixed. No test or lint command → say so and continue.

**The caller may suppress this gate** and run a dedicated test stage instead. When suppressed, skip straight to Step 5.

## Step 5 — Whole-change review, and its artifact

**The orchestrator decides who reviews you, via the injected `review=` field. You never decide it.**

| `review=` | What you do |
|-----------|-------------|
| `self` (default, and the value assumed if the field is absent) | Spawn your own reviewer, as below. |
| `batched` | **Do not spawn a reviewer.** The orchestrator reviews the whole wave's diff after your packet lands, and its artifact records your packet key. Skip to Step 6, and say `batched — covered by the wave review` on your Review line. |

`batched` is not permission to go unreviewed: your code is reviewed either way, and the orchestrator's coverage check verifies it from the filesystem for every packet key in the wave, yours included. What changes is only that one reviewer reads the whole wave instead of one reading your slice.

**When `review=self`:** once the suite has passed (or been suppressed) and **before** any commit, spawn **one** reviewer subagent over your whole change. It runs on **every** build that produced a diff — no size threshold, no skip, no fast path. `refs/review/protocol.md` owns its protocol, severity discipline, return contract and spawn rules.

Inject the change set, the worked tickets' `done-when`, the digest's acceptance criteria, and **the identity fields: `built_by` (your agent name) and `<K>` (the packet key the orchestrator gave you — pass it through unchanged, never derive your own)**.

**The artifact is required.** The reviewer writes `<prd-dir>/reports/review-prd-<N>-<K>.json` before returning. That file, not the returned prose, is what the orchestrator's coverage check reads to prove the review happened — and it checks the filesystem whether or not you claim one ran.

On return, resolve every `blocker` and `high` before proceeding, then record `medium`/`low` findings, the verdict and the artifact path in your summary's **Review** line.

## Step 6 — The db-touch pause (the one gate autonomy does not cover)

Before committing, run the production guardrail — **never skipped under any autonomy contract** (`shared/refs/safety-floor.md`):

```bash
D=.claude/scripts/script-eng-db-touch.sh; [ -f "$D" ] || D="$HOME/.claude/scripts/script-eng-db-touch.sh"; bash "$D"
```

If it flags database, data or production-config files — or your change removes/renames a public API or alters a contract or schema — **pause via `AskUserQuestion` and require explicit sign-off before committing.** Your pre-approval does not reach this.

## Step 7 — Commit to the branch

Commit directly onto the checked-out branch. **One commit per ticket, or per coherent group that reads as one reviewable unit.** With `review=batched` — a mechanical packet, well-scoped and fully specified — **commit the packet as one commit** whenever it reads as one unit; per-ticket commits buy granularity that nothing downstream consumes on work of that shape. With `review=self`, prefer per-ticket commits: a load-bearing change is where a reviewable commit history earns its cost.

Whatever the granularity, **both gates run on every commit** — batching commits never batches the gates. No per-commit approval prompt. For **each** commit, run both gates on the **staged** diff:

```bash
C=.claude/scripts/script-eng-comment-scan.sh; [ -f "$C" ] || C="$HOME/.claude/scripts/script-eng-comment-scan.sh"; "$C" --staged
P=.claude/scripts/script-eng-commit-cap.sh;   [ -f "$P" ] || P="$HOME/.claude/scripts/script-eng-commit-cap.sh";   "$P" --message "<the prepared commit message>"   # add --breaking on a breaking change
```

- **Comment scan.** Any `UNCOMMENTED <file>:<line>` → add the comment and re-stage. A genuine false positive is left and noted.
- **Commit cap.** The size measurement is advisory: `CAP_OK` / `CAP_EXCEEDED <loc>/<cap>` — an under-cap commit never blocks. On `CAP_EXCEEDED`, prefer splitting.
- **The `Oversize-reason:` trailer is not advisory.** Always pass the prepared message. Over cap with no `Oversize-reason: <text>` trailer prints `TRAILER_MISSING` and **exits 3** — add the trailer or split, never commit through it. Omitting the message prints `TRAILER_UNCHECKED` and leaves the gap open.

Conventional messages referencing feature and ticket ids: `feat(streaks): add streaks table [F1-T1]`.

## Scope enforcement (continuous)

Act only on what your assigned rows specify — no additional refactors, no unrelated file touches. This is also what keeps parallel leaves file-disjoint on the shared branch. Exempt: `devkit/AHA.md`, `devkit/OPEN-QUESTIONS.md`, and your run report under `features/…/reports/`.

## AHA.md and OPEN-QUESTIONS.md

You judge *when* to write and *what* it says; the shared writers own the entry shape. AHA fields are one terse clause each (≤140 chars, single line — the writer rejects longer). **Exit 3 = no such file in this project → skip silently, not a failure.** Exit 2 → note it in Warnings and continue.

**AHA** — when the codebase reveals a pattern the standards payload lacks, a ticket cannot be implemented as written, an unmarked cross-agent dependency surfaces, a non-obvious decision is made, or a debug cycle runs (whatever its outcome):

```bash
A=.claude/scripts/script-aha.sh; [ -f "$A" ] || A="$HOME/.claude/scripts/script-aha.sh"
bash "$A" devkit/AHA.md --tag "eng:<class>" --summary "<what happened>" --why "<why a future run cares>" --note "<what was done>"
```

**OPEN-QUESTIONS** — when you could not decide and proceeded on a stated assumption (ambiguous intent, an unanticipated product decision, or a debug escalation — log those in both files):

```bash
Q=.claude/scripts/script-openq.sh; [ -f "$Q" ] || Q="$HOME/.claude/scripts/script-openq.sh"
bash "$Q" devkit/OPEN-QUESTIONS.md --title "<one-line title>" --question "<what could not be decided>" \
  --raised-by "eng-<agent>" --severity <critical|high|medium|low> --context "<the assumption taken>"
```

## Output contract — what you return

```markdown
## Build summary — <Agent Name>

| Row | Files created | Files modified | Tests | Status |
|-----|--------------|---------------|-------|--------|
| <Feature — concern> | `<path>` | `<path>` | ✅ <n>/<n> pass | ✅ Done |

**Branch:** <the branch the commits landed on>
**Full-suite gate:** <pass / fail summary, "suppressed by caller", or "no test/lint command">
**Review:** <reviewer one-liner> · `<verdict>` · evidence: `<reports/review-prd-<N>-<K>.json>`   ← or, with `review=batched`: `batched — covered by the wave review`
**Warnings:** <groups shipped without a test ticket, or "None">
**Blocked rows:** <any row not completed, and why>
**AHA entries:** <entries written, or "None">
**Open questions:** <entries written, or "None">

status: <packet key> <done|blocked> — <≤8-word summary>
```

Three elements are **required**, not optional: the **Review** line (with its artifact path), the **`status:`** line, and the build summary table. A return missing any of them is incomplete. Emit no other free-form prose.

Log unexpected script failures, tool errors and missed writes to `devkit/DOCTOR.md` per `../../../shared/refs/doctor-logging.md` — logging never changes what you do next.
