---
name: msg
description: >
  Root menu for msg skills, plus harness modes. `--init` is the one-time
  project bootstrap — use it when the user says "initialise project",
  "bootstrap repo", "set up the framework", "start a new project", or asks
  to set up project structure in an empty repo (scaffolds devkit/ and root
  files via a three-phase interview; idempotent, never overwrites). Other
  modes: `--gui` (local PRD board), `--help` (guided skill picker).
allowed_tools:
  - AskUserQuestion
  - Read
  - Write
  - Bash
---

# msg

## Usage

**Invoke**: `/msg` — two-step category → skill picker.
**Invoke**: `/msg --init` — one-time project bootstrap (devkit/ + root files). Protocol: [`refs/protocol-init.md`](refs/protocol-init.md).
**Invoke**: `/msg --help` — three-question interview to find the right skill.
**Invoke**: `/msg --gui` (or `/msg gui`) — launch the local interactive PRD board (Kanban/List, editing, todos, prompt console, project docs).

## Skills

| Category | Skill | Description |
|----------|-------|-------------|
| Planning | msg --init | One-time project bootstrap |
| Planning | intake | Capture + grade ideas/bugs into the INTAKE.md backlog (the front door) |
| Planning | plan-pm | Autonomous PRD writer — drafts from a graded intake row |
| Planning | plan-tune | PRD contract certifier — seven consumer-bound checks, product/eng |
| Planning | plan-em | Engineering plan generator — certifies each wave, roster is the one gate |
| Build & Ship | eng | Plan or build engineering work from exec-table rows |
| Build & Ship | pre-merge | The CI gate — sync, mechanical, tests, regression, security/migration, PRD-consistency, preview, opens PR feature→staging |
| Build & Ship | post-merge | The ship gate — `--staging` (merge on green CI, deploy, human test, sign-off) and `--production` (double-confirmed staging→main release) |
| Delivery | kermit | Conventional-commit formatter and changelog manager |

> **Footnote:** This table is the canonical menu — it MUST list every user-facing skill in the msg workflow and any external skill the pipeline depends on (`kermit`). When a skill is added, removed, or renamed, update this table and the routing table below in the same change. A skill absent from this table is unreachable through `/msg`.

---

## End-to-end happy path

```
/msg --init  →  /intake  →  /plan-pm  →  /plan-tune --product  →  /plan-em  →  /plan-tune --eng
                                                                         ↓
                                                             /eng --build
                                                                         ↓
                                             /pre-merge  (CI gate: opens PR feature→staging)
                                                                         ↓
                              /post-merge --staging  (merge on green CI, deploy, human test)
                                                                         ↓
                                             (human)  /post-merge --production  (release to main)
```

---

## Dispatch

Before running any picker, check the invocation:

1. `--init`, or a natural-language bootstrap request — "initialise project", "bootstrap repo",
   "set up the framework", "start a new project" — → **Protocol: --init**. Skip the picker.
2. `--gui`, the bare word `gui`, or a natural-language board request — "open gui for PRDs",
   "show me the PRD board", "visualize my PRDs", "open kanban" — → **Protocol: --gui**. Skip
   the picker; do not call `AskUserQuestion`; go straight to rendering.
3. `--help` → **Protocol: --help**.
4. Otherwise → **Protocol: default**.

---

## Protocol: --init

Dispatch to [`refs/protocol-init.md`](refs/protocol-init.md) and follow it end to end: scan the
working directory (`refs/init/init-setup.sh`), run the batched three-phase interview (≤4
`AskUserQuestion` calls), then generate the missing devkit/ and
root files deterministically via `refs/init/init.sh`. Idempotent — existing files are never
overwritten. Do not run a picker.

---

## Protocol: --gui

Dispatch to [`refs/protocol-gui.md`](refs/protocol-gui.md) and follow it end to end. Default
is **interactive mode**: launch `refs/gui/server.py` bound to `127.0.0.1` and open the browser —
the server parses `features/prd-*/` (frontmatter + F-IDs + `## Todos`), infers completion, and
serves a Linear/Jira-style board where the user can edit PRD bodies, change status (dropdown or
drag-and-drop), toggle todos, browse project docs (README, CLAUDE.md, `devkit/`), and run
Claude prompts from a console. Writes are confined to `features/prd-*/` markdown. When a
read-only snapshot is wanted (or `python3` is unavailable), fall back to the static
template + data-fill path — same board, editing hidden, nothing ever written.

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

**Paging (Planning has 5 rows).** When a category has more than 4 rows (Planning: msg --init · intake · plan-pm · plan-tune · plan-em), present the first 4 in table order plus a final `More…` option; if the user picks `More…`, re-ask with the remaining rows. Every other category has ≤4 rows and is asked in one call.

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
  - `label`: `A roadmap`, `description`: `Sequence existing PRDs into phases, or execute one`

**Step 2 — Route**

Match the first row in the table below where all conditions hold. Use "any" as a wildcard. If no row matches exactly, pick the closest fit.

| Stage | Artifact | Output | Skill |
|-------|----------|--------|-------|
| Starting fresh | any | any | msg --init |
| Planning | A rough idea or notes | any | intake |
| Planning | Nothing yet / rough idea | A project spec | plan-pm |
| Planning | Nothing yet / rough idea | An engineering plan | plan-pm |
| Planning | A PRD or spec | A project spec | plan-tune |
| Planning | A PRD or spec | An engineering plan | plan-em |
| Planning | any | A roadmap | plan-pm --roadmap |
| Building | Nothing yet / rough idea | Working code or test results | plan-pm |
| Building | A PRD or spec | Working code or test results | eng |
| Building | any | A roadmap | eng --build roadmap=roadmap/roadmap.md |
| Building | Code or a diff | Working code or test results | pre-merge |
| Building | Code or a diff | A review or audit report | pre-merge |
| Reviewing | Code or a diff | A review or audit report | pre-merge |
| Reviewing | A PRD or spec | A project spec | plan-tune |
| Reviewing | Code or a diff | An engineering plan | eng |
| Wrapping up | Code or a diff | Working code or test results | post-merge --staging |
| Wrapping up | Code or a diff | A commit or task list | kermit |

**Step 3 — Emit**

Emit exactly:

```
/<skill> — <description>
```

Stop. Do not emit anything else.