---
name: msg
description: >
  Root menu for msg skills, plus harness modes. `--init` is the one-time
  project bootstrap — use it when the user says "initialise project",
  "bootstrap repo", "set up the framework", "start a new project", or asks
  to set up project structure in an empty repo (scaffolds devkit/ and root
  files via a batched interview; idempotent, never overwrites). Other
  modes: `--init-staging` (add a staging branch + flip release flow to staged),
  `--gui` (local PRD board), `--help` (guided skill picker).
allowed_tools:
  - AskUserQuestion
  - Read
  - Write
  - Bash
---

# msg

## Usage

**Invoke**: `/msg` — two-step category → skill picker.
**Invoke**: `/msg --init` — one-time project bootstrap (devkit/ + root files, incl. the `policy.json` release-flow seed). Protocol: [`refs/protocol-init.md`](refs/protocol-init.md).
**Invoke**: `/msg --init-staging` — add a `staging` branch to a direct-flow repo and flip `policy.json` release flow to `staged` (the only mode that creates a staging branch). Protocol: [Protocol: --init-staging](#protocol---init-staging).
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
   `--init` takes two optional **sub-flags** (the only sub-flags in msg's surface — every other
   mode is a bare flag off `/msg`) selecting the Step 2 interview mode: `--init --cto` (advisory —
   msg recommends the technical decisions) and `--init --eng` (direct — msg asks, the user
   decides). Pass the mode through to the protocol. **Bare `--init` carries no mode, and neither
   does any natural-language phrasing — all of them land on the protocol's mode gate**, which is
   the right default: NL phrasing correlates with the less-technical user, who is exactly who cto
   mode is for. An **unrecognised sub-flag** (`--init --foo`) is never silently ignored — it also
   falls to the gate.
1b. `--init-staging`, or a natural-language request to add a staging stage — "add a staging
   branch", "set up staging", "switch to a staged release flow" — → **Protocol: --init-staging**.
   Skip the picker.
2. `--gui`, the bare word `gui`, or a natural-language board request — "open gui for PRDs",
   "show me the PRD board", "visualize my PRDs", "open kanban" — → **Protocol: --gui**. Skip
   the picker; do not call `AskUserQuestion`; go straight to rendering.
3. `--help` → **Protocol: --help**.
4. Otherwise → **Protocol: default**.

---

## Protocol: --init

Dispatch to [`refs/protocol-init.md`](refs/protocol-init.md) and follow it end to end: scan the
working directory (`refs/init/init-setup.sh`), resolve the **interview mode** — `--cto` (advisory:
msg recommends architecture, language, conventions, release flow and design system) or `--eng`
(direct: msg asks, the user decides), else one mode-gate `AskUserQuestion` — and run the mode's
Step 2 protocol (`refs/protocol-cto.md` / `refs/protocol-eng.md`), then generate the missing
devkit/ and root files deterministically via `refs/init/init.sh`. Both modes converge on the
identical env-var set, so the mode is invisible from Step 3 on. Idempotent — existing files are
never overwritten. Do not run a picker. Step 2 also resolves the **release flow** and seeds
`devkit/policy.json` (`version:1`, `init:false`, `policies.release_flow`) — see the protocol.

---

## Protocol: --init-staging

The **only** path that creates a `staging` branch. It takes a direct-flow repo (ships straight to
prod) and adds the staging stage: branch `staging` off the prod branch, push it, offer branch
protection, then flip `devkit/policy.json` release flow to `staged`. Offered by
`/post-merge --doctor` when it detects a direct-flow repo, and directly invocable. Skip the picker.

**Preconditions.**
- A git repo with `devkit/policy.json` present. If it is **absent**, the repo was never bootstrapped —
  stop and direct the user to run `/msg --init` first (that seeds the policy this mode flips). Do not
  create the file here.
- Read `policies.release_flow.prod_branch` from `devkit/policy.json` (default `main`). This is the
  branch `staging` is cut from.

**Step 1 — Create + push the `staging` branch (the only branch creation in msg).**
Idempotency first — if `staging` already exists locally or on the remote, skip creation and go
straight to Step 3 (the branch is already there):

```bash
git show-ref --verify --quiet refs/heads/staging && echo LOCAL_STAGING
git ls-remote --exit-code --heads origin staging >/dev/null 2>&1 && echo REMOTE_STAGING
```

If neither prints, create it off the prod branch and publish it:

```bash
git branch staging "<prod_branch>"     # cut staging from the recorded prod branch
git push -u origin staging             # publish (skip if there is no remote — note it)
```

**Step 2 — Offer branch protection (gated).** Adding a staging stage means `/post-merge` will gate
on it, so offer to protect `staging` (and `main`) now. One `AskUserQuestion`:

> header **Branch protection**, question "Apply branch protection to `staging` + prod now? (required for `/post-merge`)"
> - **Yes, bootstrap it** — run `bash .claude/scripts/post-merge-protection.sh --bootstrap` (resolve locally-first, else `$HOME/.claude/scripts/…`); it's idempotent. Print each `BOOTSTRAPPED`/`BOOTSTRAP_FAILED` line.
> - **Skip** — note `/post-merge` will refuse until protection is set; the user can re-run the script later.

Skip this offer silently when there is no GitHub remote or no `gh` (nothing to protect yet). Never a
hard failure.

**Step 3 — Flip the release flow in `devkit/policy.json`.** Surgically edit the existing file
(preserve `version`, `init`, and `prod_branch`), setting four fields:

```
policies.release_flow.mode           = "staged"
policies.release_flow.staging_branch = "staging"
generated                            = "<today, YYYY-MM-DD>"   # the skill stamps it — this mode wrote the file
generated_by                         = "msg --init-staging"
```

Leave `init` untouched — this mode does not complete setup (that's `--doctor`'s job) — but **do**
refresh the provenance fields (`generated`/`generated_by`) since this mode is a policy-file writer.
Do **not** rewrite the file from scratch; edit only these fields. After this, `policy.json` reads
`release_flow.mode:"staged"`, `staging_branch:"staging"` (AC-RF5). Schema authority:
[`shared/refs/policy-schema.md`](../shared/refs/policy-schema.md) (writers table — `/msg --init-staging`
performs the "flow flip").

**Step 4 — Summary.** Print what happened: branch created (or already present), protection applied
(or skipped), and the new `staged` flow. Suggest next: `/pre-merge` now opens PRs against `staging`.
This mode never merges, deploys, or opens PRs.

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