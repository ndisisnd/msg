---
name: msg --help
description: The /msg --help protocol — three-question interview, routing table, one-line emission
type: reference
---

# Protocol: --help

Dispatched from `msg/SKILL.md` on `/msg --help`. When a skill is added, removed, or
renamed, the SKILL.md **Skills** table and this routing table change in the same commit.

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
| Reviewing | Code or a diff | Working code or test results | emulate |
| Reviewing | Code or a diff | An engineering plan | eng |
| Wrapping up | Code or a diff | Working code or test results | merge --staging |
| Wrapping up | Code or a diff | A commit or task list | kermit |

**Step 3 — Emit**

Emit exactly:

```
/<skill> — <description>
```

Stop. Do not emit anything else.
