---
name: msg
description: >
  Root menu for msg skills, plus harness modes. `--init` is the one-time
  project bootstrap — use it when the user says "initialise project",
  "bootstrap repo", "set up the framework", "start a new project", or asks
  to set up project structure in an empty repo (scaffolds devkit/ and root
  files via a three-phase interview; idempotent, never overwrites). Other
  modes: `--gui` (local PRD board), `--set-mode` (harness-wide run mode),
  `--help` (guided skill picker).
allowed_tools:
  - AskUserQuestion
  - Read
  - Write
  - Bash
---

# msg

## Usage

**Invoke**: `/msg` — two-step category → skill picker.
**Invoke**: `/msg --init` — one-time project bootstrap (devkit/ + root files). Protocol: [`refs/protocol-init.md`](refs/protocol-init.md). `--init --flash` runs the zero-interview variant defined there.
**Invoke**: `/msg --help` — three-question interview to find the right skill.
**Invoke**: `/msg --gui` (or `/msg gui`) — launch the local interactive PRD board (Kanban/List, editing, todos, prompt console, project docs).
**Invoke**: `/msg --flash` — resolve to a skill in **≤1** grouped `AskUserQuestion` (or route directly from prose args, no question). `--gui --flash` is **interactive-only** — it never runs the static build; with `python3` missing it prints a one-line instruction instead. Safety floor (`../shared/refs/flash-floor.md`) never relaxed.
**Invoke**: `/msg --set-mode --flash|--comprehensive` — persist the harness-wide run mode to `pref.json` (asks local vs global scope), then confirm and stop. Precedence + file format: `../shared/refs/mode-resolution.md`.

## Skills

| Category | Skill | Description |
|----------|-------|-------------|
| Planning | msg --init | One-time project bootstrap |
| Planning | plan-pm | PM interview — PRD writer |
| Planning | plan-tune | PRD auditor — product/eng |
| Planning | plan-em | Engineering plan generator |
| Build & Ship | eng | Plan or build engineering work from exec-table rows |
| Build & Ship | test | Run unit, e2e, functional, visual, perf, mobile, or coverage buckets |
| Build & Ship | pre-merge | Pre-push gate — integration, e2e, build, security, bundle-size |
| Review | review | Five-mode code review — Quality, Coverage, Functional, Security, Perf |
| Delivery | kermit | Conventional-commit formatter and changelog manager |

> **Footnote:** This table is the canonical menu — it MUST list every user-facing skill in the msg workflow and any external skill the pipeline depends on (`kermit`). When a skill is added, removed, or renamed, update this table and the routing table below in the same change. A skill absent from this table is unreachable through `/msg`.

---

## End-to-end happy path

```
/msg --init  →  /plan-pm  →  /plan-tune --product  →  /plan-em  →  /plan-tune --eng
                                                                         ↓
                                                             /eng --build
                                                                         ↓
                                             /test  →  /review  →  /test --eval-set
                                                                         ↓
                                                                 /pre-merge
                                                                         ↓
                                                                 gh pr create
```

---

## Dispatch

Before running any picker, check the invocation:

1. `--set-mode` → **Protocol: --set-mode**. Skip the picker.
2. `--init`, or a natural-language bootstrap request — "initialise project", "bootstrap repo",
   "set up the framework", "start a new project" — → **Protocol: --init**. Skip the picker.
3. `--gui`, the bare word `gui`, or a natural-language board request — "open gui for PRDs",
   "show me the PRD board", "visualize my PRDs", "open kanban" — → **Protocol: --gui**. Skip
   the picker; do not call `AskUserQuestion`; go straight to rendering.
4. `--help` → **Protocol: --help**.
5. Otherwise → **Protocol: default**.

---

## Protocol: --init

Dispatch to [`refs/protocol-init.md`](refs/protocol-init.md) and follow it end to end: scan the
working directory (`refs/init/init-setup.sh`), run the batched three-phase interview (≤4
`AskUserQuestion` calls; skipped entirely under `--flash`), then generate the missing devkit/ and
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

## Protocol: --set-mode

**Step 1 — Scope.** Call `AskUserQuestion` (header `Scope`): `Local` (`.claude/msg/pref.json`, this project) or `Global` (`~/.claude/msg/pref.json`, all projects).

**Step 2 — Write.** Read the target `pref.json` if it exists, set `"mode"` to the requested value (`flash`/`comprehensive`), and write it back **merging** — never clobber unrelated keys, never create a duplicate. `mkdir -p` the parent if absent. If neither `--flash` nor `--comprehensive` was passed, ask which via one `AskUserQuestion` first.

**Step 3 — Confirm and stop.** Emit `Mode set to <mode> (<scope>: <path>).` and terminate. Do not run a picker.

---

## Protocol: default (no args)

**Step 0 — Show active mode.** Resolve the current mode per `../shared/refs/mode-resolution.md` and print one line before the picker: `Mode: <flash|comprehensive> (source: <local pref | global pref | default>).`

**Step 1 — Category**

Call `AskUserQuestion` with one question:

- **Question**: `Which area do you need help with?`
- **Header**: `Category`
- **multiSelect**: `false`
- **Options**:
  - `label`: `Planning`, `description`: `Bootstrap, spec writing, PRD audit, engineering planning`
  - `label`: `Build & Ship`, `description`: `Implement, test, and run the pre-push gate`
  - `label`: `Review`, `description`: `Code review and doc checking`
  - `label`: `Delivery`, `description`: `Task lists, commits`

**Step 2 — Skill**

`AskUserQuestion` allows 2-4 options per question. Every category has 4 or fewer rows, so call it directly:

- **Question**: `Which skill?`
- **Header**: `Skill`
- **multiSelect**: `false`
- **Options**: all rows in the selected category, in table order (`label` = Skill, `description` = Description)

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
| Planning | Nothing yet / rough idea | A project spec | plan-pm |
| Planning | Nothing yet / rough idea | An engineering plan | plan-pm |
| Planning | A PRD or spec | A project spec | plan-tune |
| Planning | A PRD or spec | An engineering plan | plan-em |
| Planning | any | A roadmap | plan-pm --roadmap |
| Building | Nothing yet / rough idea | Working code or test results | plan-pm |
| Building | A PRD or spec | Working code or test results | eng |
| Building | any | A roadmap | eng --build roadmap=roadmap/roadmap.md |
| Building | Code or a diff | Working code or test results | test |
| Building | Code or a diff | A review or audit report | pre-merge |
| Reviewing | Code or a diff | A review or audit report | review |
| Reviewing | A PRD or spec | A project spec | plan-tune |
| Reviewing | Code or a diff | An engineering plan | eng |
| Wrapping up | Code or a diff | A commit or task list | kermit |

**Step 3 — Emit**

Emit exactly:

```
/<skill> — <description>
```

Stop. Do not emit anything else.