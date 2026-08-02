---
name: msg
description: >
  Root menu for msg skills, plus harness modes. `--init` is the one-time
  project bootstrap — use it when the user says "initialise project",
  "bootstrap repo", "set up the framework", "start a new project", or asks
  to set up project structure in an empty repo. Other modes: `--init-staging`
  (add a staging branch), `--update` (re-scan a bootstrapped repo), `--gui`
  (local PRD board), `--doctor` (tally and triage the harness-incident ledger),
  `--aha` (sweep, triage, and compact the devkit/AHA.md learnings ledger),
  `--help` (guided skill picker).
argument-hint: "[--init | --init-staging | --update | --gui | --doctor | --aha | --help]"
allowed_tools:
  - AskUserQuestion
  - Read
  - Edit
  - Write
  - Bash
---

# msg

**This file is a router.** Every mode's protocol lives in a ref; the only protocols written
here are the two pickers, which exist to route and nothing else. The Dispatch table below is
the single statement of msg's mode surface — do not restate it elsewhere in this file.

## Dispatch

Check the invocation before running any picker. First match wins.

| Invocation | Also triggers on (natural language) | Route |
|---|---|---|
| `/msg --init` (+ `--cto` / `--eng`) | "initialise project", "bootstrap repo", "set up the framework", "start a new project" | [`refs/protocol-init.md`](refs/protocol-init.md) |
| `/msg --init-staging` | "add a staging branch", "set up staging", "switch to a staged release flow" | [`refs/protocol-init-staging.md`](refs/protocol-init-staging.md) |
| `/msg --update` | "check for msg updates", "reinitialise this project", "resync my init setup", "are there new init components" | [`refs/protocol-update.md`](refs/protocol-update.md) |
| `/msg --gui`, or the bare word `gui` | "open gui for PRDs", "show me the PRD board", "visualize my PRDs", "open kanban" | [`refs/protocol-gui.md`](refs/protocol-gui.md) — render directly, never call `AskUserQuestion` first |
| `/msg --doctor` | "check the harness", "what keeps failing", "run the doctor", "triage the incident log" | [`refs/protocol-doctor.md`](refs/protocol-doctor.md) — tallies and triages `devkit/DOCTOR.md`; **never fixes** |
| `/msg --aha` | "prune the learnings", "sweep AHA", "trim the aha log", "triage the learnings ledger" | [`refs/protocol-aha.md`](refs/protocol-aha.md) — triages and compacts `devkit/AHA.md`; only write is the ledger itself, promotions stay recommendations |
| `/msg --help` | — | **Protocol: --help** below |
| `/msg` (no args) | — | **Protocol: default** below |

**`--init` sub-flags.** `--init` takes the only sub-flags in msg's surface — every other mode is
a bare flag off `/msg`. They select the Step 2 interview mode: `--init --cto` (advisory — msg
recommends the technical decisions) and `--init --eng` (direct — msg asks, the user decides).
Pass the mode through to the protocol. **Bare `--init` carries no mode, and neither does any
natural-language phrasing — all of them land on the protocol's mode gate**, which is the right
default: NL phrasing correlates with the less-technical user, who is exactly who cto mode is for.
An **unrecognised sub-flag** (`--init --foo`) is never silently ignored — it also falls to the gate.

**Closing message.** `--init`, `--update`, `--init-staging`, `--doctor`, and `--aha` runs end with the closing message
per [`../shared/refs/closing-message.md`](../shared/refs/closing-message.md) — the last chat
output, after the protocol's own output. The pure-emission modes (default picker, `--gui`,
`--help`) are exempt: their "Stop. Do not emit anything else." / render contracts stand unchanged.

**Harness incidents.** The same five modes log unexpected script failures, tool errors, retries,
and missed writes to `devkit/DOCTOR.md` per
[`../shared/refs/doctor-logging.md`](../shared/refs/doctor-logging.md) — logging never changes what
the run does next. `--doctor` is the reader, never a writer of incident rows.

## Skills

| Category | Skill | Description |
|----------|-------|-------------|
| Planning | msg --init | One-time project bootstrap |
| Planning | intake | Capture + grade ideas/bugs into the INTAKE.md backlog (the front door); `--update` edits a captured row, `--delete` removes one |
| Planning | plan-pm | Autonomous PRD writer — drafts from a graded intake row |
| Planning | plan-review | PRD contract certifier — seven consumer-bound checks, product/eng |
| Planning | plan-em | Engineering plan generator — certifies each wave, roster is the one gate |
| Build & Ship | eng | Plan or build engineering work from exec-table rows |
| Build & Ship | pre-merge | The CI gate — sync, mechanical, tests, regression, security/migration, PRD-consistency, opens PR feature→staging |
| Build & Ship | merge | The ship gate — `--staging` (merge on green CI, deploy, human test, sign-off) and `--production` (double-confirmed staging→main release) |
| Delivery | kermit | Conventional-commit formatter and changelog manager |

> **Footnote:** This table is the canonical menu — it MUST list every user-facing skill in the msg workflow and any external skill the pipeline depends on (`kermit`). When a skill is added, removed, or renamed, update this table and the `--help` routing table below in the same change. A skill absent from this table is unreachable through `/msg`.

## End-to-end happy path

```
/msg --init  →  /intake  →  /plan-pm  →  /plan-review --product  →  /plan-em  →  /plan-review --eng
                                                                         ↓
                                                             /eng --build
                                                                         ↓
                                             /pre-merge  (CI gate: opens PR feature→staging)
                                                                         ↓
                              /merge --staging  (merge on green CI, deploy, human test)
                                                                         ↓
                                             (human)  /merge --production  (release to main)
```

---

## Protocol: default (no args)

**Step 1 — Category**

Call `AskUserQuestion` with one question:

- **Question**: `Which area do you need help with?`
- **Header**: `Category`
- **multiSelect**: `false`
- **Options**:
  - `label`: `Planning`, `description`: `Bootstrap, idea capture, spec writing, PRD audit, engineering planning`
  - `label`: `Build & Ship`, `description`: `Implement code and run the CI gate`
  - `label`: `Delivery`, `description`: `Task lists, commits`

**Step 2 — Skill**

`AskUserQuestion` allows 2–4 options per question.

- **Question**: `Which skill?`
- **Header**: `Skill`
- **multiSelect**: `false`
- **Options**: the rows in the selected category, in table order (`label` = Skill, `description` = Description).

**Paging (Planning has 5 rows).** When a category has more than 4 rows (Planning: msg --init · intake · plan-pm · plan-review · plan-em), present the first 4 in table order plus a final `More…` option; if the user picks `More…`, re-ask with the remaining rows. Every other category has ≤4 rows and is asked in one call.

**Step 3 — Emit**

Emit exactly:

```
/<skill> — <description>
```

Stop. Do not emit anything else.

---

## Protocol: --help

**Step 1 — Interview**

Call `AskUserQuestion` with three questions in a single call:

**Q1**
- **Question**: `What stage of the project are you in?`
- **Header**: `Stage`
- **multiSelect**: `false`
- **Options**:
  - `label`: `Starting fresh`, `description`: `New project, no files yet`
  - `label`: `Planning`, `description`: `Speccing a feature or writing a PRD`
  - `label`: `Building`, `description`: `PRD is ready, need to write or test code`
  - `label`: `Reviewing`, `description`: `Code exists, need review or audit`
  - `label`: `Wrapping up`, `description`: `Feature is done, need to commit or track tasks`

**Q2**
- **Question**: `What do you have to work with?`
- **Header**: `Artifact`
- **multiSelect**: `false`
- **Options**:
  - `label`: `Nothing yet`, `description`: `Starting from scratch`
  - `label`: `A rough idea or notes`, `description`: `Some context but no structured doc`
  - `label`: `A PRD or spec`, `description`: `Structured product or engineering doc`
  - `label`: `Code or a diff`, `description`: `Existing codebase or a changeset`

**Q3**
- **Question**: `What do you want to walk away with?`
- **Header**: `Output`
- **multiSelect**: `false`
- **Options**:
  - `label`: `A project spec (PRD)`, `description`: `Structured product requirements doc`
  - `label`: `An engineering plan`, `description`: `Tasks, milestones, technical design`
  - `label`: `Working code or test results`, `description`: `Implementation, test run, or pre-push gate`
  - `label`: `A review or audit report`, `description`: `Findings on code, docs, or a skill`
  - `label`: `A commit or task list`, `description`: `Conventional commit or TODOs.json`

**Step 2 — Route**

Match the first row in the table below where all conditions hold. Use "any" as a wildcard. If no row matches exactly, pick the closest fit.

**Every Artifact and Output cell must name an option Step 1 actually offers.** A row conditioned
on anything else can never match — that is how two dead `intake --update` / `intake --delete` rows
and a roadmap route survived unnoticed in this table. Check reachability whenever a row is added.

| Stage | Artifact | Output | Skill |
|-------|----------|--------|-------|
| Starting fresh | any | any | msg --init |
| Planning | A rough idea or notes | any | intake |
| Planning | Nothing yet | A project spec (PRD) | plan-pm |
| Planning | Nothing yet | An engineering plan | plan-pm |
| Planning | A PRD or spec | A project spec (PRD) | plan-review |
| Planning | A PRD or spec | An engineering plan | plan-em |
| Building | Nothing yet / A rough idea or notes | Working code or test results | plan-pm |
| Building | A PRD or spec | Working code or test results | eng |
| Building | Code or a diff | Working code or test results | pre-merge |
| Building | Code or a diff | A review or audit report | pre-merge |
| Reviewing | Code or a diff | A review or audit report | pre-merge |
| Reviewing | A PRD or spec | A project spec (PRD) | plan-review |
| Reviewing | Code or a diff | An engineering plan | eng |
| Wrapping up | Code or a diff | Working code or test results | merge --staging |
| Wrapping up | Code or a diff | A commit or task list | kermit |

**Step 3 — Emit**

Emit exactly:

```
/<skill> — <description>
```

Stop. Do not emit anything else.
