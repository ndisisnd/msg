---
name: msg
description: Root menu for msg skills
model: claude-sonnet-4-6
allowed_tools:
  - AskUserQuestion
---

# msg

## Usage

**Invoke**: `/msg` — two-step category → skill picker.
**Invoke**: `/msg --help` — three-question interview to find the right skill.

## Skills

| Category | Skill | Description |
|----------|-------|-------------|
| Planning | msg-init | One-time project bootstrap |
| Planning | plan | Autonomous planning loop — pm → tune → em → tune until eng-tuned |
| Planning | plan-pm | PM interview — PRD writer |
| Planning | plan-tune | PRD auditor — product/eng |
| Planning | plan-em | Engineering plan generator |
| Build & Ship | ship | Autonomous build-and-ship loop — eng build → review loop → pre-merge |
| Build & Ship | eng | Plan, build, or review engineering work from exec-table rows |
| Build & Ship | test | Run unit, e2e, functional, visual, perf, mobile, or coverage buckets |
| Build & Ship | pre-merge | Pre-push gate — integration, e2e, build, security, bundle-size |
| Review | review | Five-mode code review — Quality, Coverage, Functional, Security, Perf |
| Review | docu | Stale doc checker and fixer |
| Delivery | handoff | Structured mid-flight handoff artifact |
| Delivery | todo | Parse PRD tables → TODOs.json |
| Meta | improve | Improvement planner for any skill or workflow |

---

## End-to-end happy path

```
/msg-init  →  /plan-pm  →  /plan-tune --product  →  /plan-em  →  /plan-tune --eng
                                                                         ↓
                                                             /eng --build
                                                                         ↓
                                             /test  →  /review  →  /test --eval-set
                                                                         ↓
                                                                     /docu
                                                                         ↓
                                                                 /pre-merge
                                                                         ↓
                                                         gh pr create  /  /handoff
                                                                         ↓
                                                                   /todo (optional)
```

**Autonomous loop shortcuts** collapse the stages above into one hands-off command each:

- `/plan <idea>` — runs `plan-pm → plan-tune → plan-em → plan-tune` to a finished eng-tuned PRD. Pauses only for the interview and breaking-change reconciliation.
- `/ship <PRD path | prose>` — runs `eng --build → review loop → pre-merge` on an eng-tuned PRD. Pauses only for database-file touches or breaking changes.

---

## Protocol: default (no args)

**Step 1 — Category**

Call `AskUserQuestion` with one question:

- **Question**: `Which area do you need help with?`
- **Header**: `Category`
- **multiSelect**: `false`
- **Options**:
  - `label`: `Planning`, `description`: `Bootstrap, spec writing, PRD audit, engineering planning`
  - `label`: `Build & Ship`, `description`: `Implement, test, and run the pre-push gate`
  - `label`: `Review`, `description`: `Code review and doc checking`
  - `label`: `Delivery`, `description`: `Handoff artifacts, task lists`
  - `label`: `Meta`, `description`: `Improvement planning, agent design, and skill-level tooling`

**Step 2 — Skill**

Call `AskUserQuestion` with one question, sourcing options from the Skills table filtered to the selected category:

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
  - `label`: `Wrapping up`, `description`: `Feature is done, need handoff or tasks`

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
  - `label`: `A handoff or task list`, `description`: `Handoff artifact or TODOs.json`

**Step 2 — Route**

Match the first row in the table below where all conditions hold. Use "any" as a wildcard. If no row matches exactly, pick the closest fit.

| Stage | Artifact | Output | Skill |
|-------|----------|--------|-------|
| Starting fresh | any | any | msg-init |
| Planning | Nothing yet / rough idea | A project spec | plan-pm |
| Planning | A PRD or spec | A project spec | plan-tune |
| Planning | A PRD or spec | An engineering plan | plan-em |
| Building | A PRD or spec | Working code or test results | eng |
| Building | Code or a diff | Working code or test results | test |
| Building | Code or a diff | A review or audit report | pre-merge |
| Reviewing | Code or a diff | A review or audit report | review |
| Reviewing | A PRD or spec | A project spec | plan-tune |
| Reviewing | Code or a diff | An engineering plan | improve |
| Reviewing | any | A review or audit report | docu |
| Wrapping up | A PRD or spec | A handoff or task list | todo |
| Wrapping up | any | A handoff or task list | handoff |

**Step 3 — Emit**

Emit exactly:

```
/<skill> — <description>
```

Stop. Do not emit anything else.