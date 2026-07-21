---
name: eng
description: >
  Platform-agnostic engineering agent with two modes: --plan (propose file changes for human approval AND write the per-feature todo tickets in the same pass), --build (write code from the todos, falling back to exec-table rows). Invoked by plan-em or directly by the user.
argument-hint: "<--plan | --build> [report=<path> | roadmap=<path>]"
allowed_tools:
  - Bash
  - Read
  - Write
  - Edit
  - Skill
  - AskUserQuestion
  - Agent
---

# eng

Platform-agnostic engineering agent with two modes — `--plan`, `--build` — each a distinct protocol in its own ref file, selected by the invocation flag. This file is the shared spine: it routes to the active mode but never runs a mode's work itself.

---

## Step 0 — Route to the active mode

Read the invocation flag and load exactly one mode protocol:

| Flag | Read |
|------|------|
| `--plan` | `refs/plan/protocol.md` |
| `--plan report=<path>` | `refs/plan/report-fix.md` (instead of `protocol.md`) |
| `--build` | `refs/build/protocol.md` |
| `--build report=<path>` | `refs/build/report-fix.md` (instead of `protocol.md`) |
| `--build roadmap=<path>` | `refs/build/protocol-roadmap.md` (instead of `protocol.md`) |

Exactly one mode flag must be present (`--plan` | `--build`). If zero or more than one is given, emit:

```
Hard failure: exactly one mode flag required (--plan | --build). Got: <list>.
```

Stop.

**`--todo` is no longer a mode.** Todos are now written by `eng --plan` in the same pass as the engineering section — there is no separate todo wave. An invocation carrying `--todo` hard-fails:

```
Hard failure: --todo is no longer a mode — todos are written by `eng --plan` in the same pass. Re-run with --plan.
```

Stop. `roadmap=<path>` (a `--build`-only field) loads `refs/build/protocol-roadmap.md` **instead of** `refs/build/protocol.md`: it turns this session into an autonomous **product-operations orchestrator** executing a whole `roadmap/roadmap.md` phase-by-phase, spawning `eng`/`pre-merge` subagents (pre-merge is the single CI gate — it absorbed `/review` + `/test`).

Otherwise read the active mode file **fully** first — it defines the mode-specific input rules, summary content, work steps, and output contract. The numbered steps below are the shared spine; they run for every mode and point to the active mode file where the path diverges.

---

## Step 1 — Input validation

Three input sources. The **PRD/exec-table source** is the default for every mode; **`report`** is an alternate available on both modes, and **`roadmap`** is a `--build`-only alternate.

### PRD/exec-table source (all modes)

Requires four fields. Hard-refuse if any is missing:

| Field | Value |
|-------|-------|
| mode flag | `--plan` or `--build` |
| `prd-path` | Path to the PRD `.md` file containing the execution table |
| `rows` | Semicolon-separated exec-table Feature identifiers for this invocation — each the exact `<ID>: <name> — <concern>` text of a Feature cell (e.g. `F2: Track streak — Schema migration`) |
| `agent` | This invocation's agent identity (e.g. `eng-backend`) — the exec-table **Agent** column value for the assigned rows; names the `## Engineering — <agent>` heading and confirms row ownership. |

If any field is missing, emit:

```
Hard failure: missing required field(s): <list>. Provide the mode flag, prd-path, rows, and agent to continue.
```

Stop. The active mode file may add mode-specific input rules — apply those too.

### Alternate sources

- **`report=<path>`** — build or plan from a failed run's issues file (`report-prd-<N>-<K>.json`) instead of an exec-table. On `--build`, required fields, rejections, path-validity failures, and the finding→issue-ticket projection live in `refs/build/report-fix.md`. On `--plan`, the same source plans the fix tickets for the issues file's findings — required fields, rejections, and the fix-plan output contract live in `refs/plan/report-fix.md`.
- **`roadmap=<path>`** — `--build` only: hand the whole roadmap to the orchestrator (`refs/build/protocol-roadmap.md`), which derives per-PRD fields for each leaf subagent. Required fields and rejections live in that file.

`--plan` accepts `report` but rejects `roadmap`; passing more than one input source is a hard failure (ambiguous source) — exact messages in the mode refs.

---

## Step 2 — Pre-flight: read everything in one pass

Before any output, read the spec, devkit, and relevant codebase files in one consolidated scan.

**Orchestrated fast path (scoped context injected).** When an orchestrator (`plan-em` or the roadmap orchestrator) has injected **scoped excerpts** — the assigned rows, the relevant PRD feature sections, and a devkit **digest** — work from those directly; do **not** re-read the full PRD or every devkit file. The PRD path is always supplied as an **escape hatch**: read the full PRD (or a specific devkit file) on demand only when an excerpt is insufficient to resolve a row.

**Standalone path (default when nothing is injected).** Read the full PRD at `prd-path`, locate the Execution Table, and select rows whose **Feature** column text exactly matches one of the assigned `rows`. A `rows` identifier matching no Feature cell, or a matched row whose **Agent** column differs from the `agent` field, is a hard failure — emit it and stop. On the `report` source there is no exec-table, no `rows`, and no ownership to confirm — read the file and project its `issues[]` per `refs/build/report-fix.md`.

**Devkit files** (read in parallel with the PRD, unless a digest was injected): `devkit/AHA.md` (past learnings relevant to the rows), `devkit/GLOSSARY.md` (canonical terms; flag PRD deviations), `CLAUDE.md` at project root (tech-stack constraints on every file-path/approach decision), `devkit/ARCHITECTURE.md` (validate scope against system layers; flag conflicts as gaps), `devkit/DESIGN-SYSTEM.md` (reusable components). If `devkit/` does not exist, emit a single warning and continue; a missing individual file is a per-file warning, then continue.

**Codebase scan** (in parallel): read files relevant to the assigned rows, matched by concern type (schema migration → migrations/schema; API contract → handlers, routes, OpenAPI; client mobile/web → screens/pages, components, services/clients; tests → existing test files; webhook → event emitters, queue handlers). For each, determine **Modify** (exists) or **Create** (does not), and note naming conventions, patterns, and constraints — they constrain the output. Eng derives all implementation paths from this scan and the spec; `report`'s `issues[].file` marks where a *symptom* was observed, not a path to blindly edit.

Complete pre-flight before Step 3; emit no output during it.

---

## Step 3 — Pre-run (1 of 2): Summary + approval gate

Emit a **short summary** (3–4 lines max) — content per the active mode file's "Summary content" section — then ask:

```
AskUserQuestion:
  "Does this summary look right?"
  Options:
    - Yes, proceed
    - No, needs correction
    - I have a follow-up question
```

- **Yes, proceed:** continue to Step 4.
- **No, needs correction:** rewrite the summary once with the correction and re-ask; if still rejected, stop and ask the user to clarify scope.
- **I have a follow-up question:** enter the interview (Step 3a), then re-present the summary.

Never proceed to Step 4 without an explicit "Yes, proceed." *(Under an autonomy contract — e.g. an orchestrator running hands-off — treat this gate as pre-approved and proceed.)*

### Step 3a — User interview (on demand)

Ask up to 3 focused questions, one at a time — each naming the specific row or PRD section it concerns, with 3–4 concrete `AskUserQuestion` options (never open-ended). If more than 3 ambiguities exist, list them and ask which to prioritise. Then resume where the protocol paused — do not restart.

---

## Step 4 — Pre-run (2 of 2): Coding standards

Coding standards come from `/cook`, pulled via **explicit flags** (never a prose summary) so the call is cacheable and the P0 floor always loads. **Runs on `--build` only:** `--plan` does not call `/cook` — its design doc + todo tickets are grounded in the `CLAUDE.md` + `devkit/ARCHITECTURE.md` stack constraints read in Step 2; standards are pulled later, at build time. On `--build`, resolve standards one of two ways:

- **Orchestrated (payload injected):** when the prompt carries a **`standards payload`** section (an orchestrator compiled it once for this stack and injected it), use it and **do not call `/cook`**. Default on orchestrated runs.
- **Standalone (call cook yourself):** when no payload is injected, call `/cook` once with explicit flags — stack→flag table in `refs/build/protocol.md`. Always include `--global` (guarantees the P0 floor + 8 concern refs); an identical flag set repeats as a cook cache hit. Read fully; surface any uncovered stack as a named gap in the build summary.

---

## Step 5 — Run the active mode's work and emit output

Follow the work steps and output contract in the active mode file, where the modes diverge:

- `--plan` → in one pass, append the `## Engineering — <Agent>` section, fill the Execution steps + Files columns, and write the `## Todos — <Agent>` tickets that decompose each owned F-ID (no implementation code written; inline snippets/pseudocode encouraged).
- `--build` → write code to derived paths; emit a build summary.

---

## Step 6 — Scope enforcement (continuous)

Throughout Steps 2–5, enforce strict scope: act only on what the assigned exec-table rows specify; make no additional refactors, unrelated file touches, or out-of-scope changes. A row that cannot be resolved from the PRD, exec-table, or codebase scan → surface it as a named gap (plan / review) or block and ask (build). Never resolve ambiguity by assumption.

---

## References

- `refs/plan/protocol.md` — `--plan`: summary content, output contract, exact-identifier rule, **and the `## Todos — <Agent>` ticket-writing spec** run in the same pass. `refs/plan/template-todo.md` — the ticket schema (`F<n>-T<k>` ids, the seven fields, rendering, rules, empty-block sentinel, the ticket-sizing rule) that `--build` reads mechanically. `refs/plan/template-eng-plan.md` — §1–13 output format.
- `refs/plan/report-fix.md` — `--plan`'s `report` source: required fields, rejections, and the fix-plan output contract for planning the fixes to a failed run's issues file.
- `refs/build/protocol.md` — `--build`: branch contract, `report` source, coding-standards flag table, work steps, per-ticket pair review, commit/PR contract. `refs/build/protocol-exec.md` — Execution-steps column format. `refs/build/report-fix.md` — `report` source + the finding→issue-ticket projection and `kind` discriminator.
- `refs/build/pair-review.md` — per-ticket pair-review subagent: platform-parameterised principal-engineer persona, unnecessary-code-only mandate, one-revision-round blocking contract (loaded on the build hot path).
- `refs/build/protocol-roadmap.md` — `--build roadmap=<path>` orchestrator: executes `roadmap/roadmap.md` phase-by-phase, spawning subagents and injecting per-stack standards.
- `.claude/scripts/eng-db-touch.sh` — production/data guardrail; the orchestrator pauses for sign-off when it trips.
- `.claude/scripts/eng-comment-scan.sh` — deterministic A4 comment scan; flags added symbol declarations with no plain-English comment above them (`--staged` or a diff range).
- `.claude/scripts/eng-commit-cap.sh` — A5 commit-size measurement on the staged diff (>500 changed LOC, >300 with `--breaking`) — advisory: always exits 0, prints `CAP_OK`/`CAP_EXCEEDED` for the agent to judge split-or-commit; `--oversize-reason` records the justification when committing over-cap anyway.
- **Contract:** the `## Engineering — <Agent>` and `## Todos — <Agent>` headings written by `--plan` (same pass) are how `plan-em` detects the section is ready and how `--build` locates its spec. Do not rename them.
