---
name: msg
description: >
  Root menu for msg skills, plus harness modes. Bare `/msg` says the next step
  for each PRD in progress and offers to run it — use it when the user says
  "what's next", "where am I", "what should I run now". `--init` is the
  project setup — use it when the user says "initialise project", "bootstrap
  repo", "set up the framework", "start a new project", or asks to set up
  project structure in an empty repo; every msg skill also runs it by itself
  when `devkit/` is missing. Other modes: `--init-staging` (add a staging
  branch), `--update` (one pass that updates msg, pre-merge and merge
  settings, with one approval), `--gui` (local PRD board), `--doctor` (tally
  and triage the harness-incident ledger), `--aha` (sweep, triage, and compact
  the devkit/AHA.md learnings ledger), `--version` (print the installed
  release in one line), `--help` (guided skill picker).
argument-hint: "[--init | --init-staging | --update | --gui | --doctor | --aha | --version | --help]"
allowed_tools:
  - AskUserQuestion
  - Read
  - Edit
  - Write
  - Bash
---

# msg

**This file is a router.** Every mode's protocol lives in a ref — none is written here.
The Dispatch table below is the single statement of msg's mode surface — do not restate
it elsewhere in this file.

## Dispatch

Check the invocation before running any picker. First match wins.

| Invocation | Also triggers on (natural language) | Route |
|---|---|---|
| `/msg --init` | "initialise project", "bootstrap repo", "set up the framework", "start a new project" | [`refs/protocol-init.md`](refs/protocol-init.md) |
| `/msg --init-staging` | "add a staging branch", "set up staging", "switch to a staged release flow" | [`refs/protocol-init-staging.md`](refs/protocol-init-staging.md) |
| `/msg --update` | "check for msg updates", "reinitialise this project", "resync my init setup", "are there new init components", "update everything" | [`refs/protocol-update.md`](refs/protocol-update.md) — msg's update, then pre-merge's and merge's `--update`, one change list, one approval |
| `/msg --gui`, or the bare word `gui` | "open gui for PRDs", "show me the PRD board", "visualize my PRDs", "open kanban" | [`refs/protocol-gui.md`](refs/protocol-gui.md) — render directly, never call `AskUserQuestion` first |
| `/msg --doctor` | "check the harness", "what keeps failing", "run the doctor", "triage the incident log" | [`refs/protocol-doctor.md`](refs/protocol-doctor.md) — tallies and triages `devkit/DOCTOR.md`; **never fixes** |
| `/msg --aha` | "prune the learnings", "sweep AHA", "trim the aha log", "triage the learnings ledger" | [`refs/protocol-aha.md`](refs/protocol-aha.md) — triages and compacts `devkit/AHA.md`; only write is the ledger itself, promotions stay recommendations |
| `/msg --version`, or the bare word `version` | "which msg is this", "what version of msg do I have", "did the reinstall land", "is msg up to date" | [`refs/protocol-version.md`](refs/protocol-version.md) |
| `/msg --help` | — | [`refs/protocol-help.md`](refs/protocol-help.md) |
| `/msg` (no args) | "what's next", "where am I", "what should I run now" | [`refs/protocol-default.md`](refs/protocol-default.md) — the next step per PRD in progress (`script-msg-next.py`), then run one or show the category/skill picker over the Skills table below |

**Setup runs by itself.** Every msg skill that finds no `devkit/` runs `/msg --init` first
(its one interview), then continues the command the user asked for. `/msg --init` stays for
a manual run. `--init` takes no sub-flags; an unknown one is ignored with a one-line note.

**Closing message.** `--init`, `--update`, `--init-staging`, `--doctor`, and `--aha` runs end with the closing message
per [`../shared/refs/closing-message.md`](../shared/refs/closing-message.md) — the last chat
output, after the protocol's own output. The pure-emission modes (bare `/msg`, `--gui`,
`--version`, `--help`) are exempt: their "Stop. Do not emit anything else." / render contracts stand unchanged.

**Harness incidents.** The same five modes log unexpected script failures, tool errors, retries,
and missed writes to `devkit/DOCTOR.md` per
[`../shared/refs/doctor-logging.md`](../shared/refs/doctor-logging.md) — logging never changes what
the run does next. `--doctor` is the reader, never a writer of incident rows.

## Skills

| Category | Skill | Description |
|----------|-------|-------------|
| Planning | msg --init | Project setup — runs by itself on the first msg command when `devkit/` is missing |
| Planning | intake | Capture + grade ideas/bugs into the INTAKE.md backlog (the front door); `--update` edits a captured row, `--delete` removes one, `--health` finds stale or wrong rows |
| Planning | plan-pm | Autonomous PRD writer — drafts from a graded intake row |
| Planning | plan-review | PRD contract certifier — seven consumer-bound checks; suggested after plan-pm and plan-em |
| Planning | plan-em | Engineering plan generator — certifies each wave, asks about the roster only when it is unusual |
| Build & Ship | eng | Plan or build engineering work from exec-table rows |
| Build & Ship | pre-merge | The quality gate — sync, mechanical, tests, regression, security/migration, PRD-consistency; fixes failures by itself (≤2 rounds); first run sets it up; stays local, ends "Next: /merge" |
| Build & Ship | merge | The ship gate — bare `/merge` does the next step; `--staging` (pre-merge pass check, push, PR, CI wait, merge, deploy, human test, sign-off), `--production` (confirmed release to main), `--update` (refresh settings); first run sets it up |
| Build & Ship | emulate | The local run lane — boots a simulator/emulator on the current branch and opens the window; a leaf, never part of the pipeline |
| Delivery | kermit | Conventional-commit formatter and changelog manager |

> **Footnote:** This table is the canonical menu — it MUST list every user-facing skill in the msg workflow and any external skill the pipeline depends on (`kermit`). When a skill is added, removed, or renamed, update this table and the `--help` routing table (`refs/protocol-help.md`) in the same change. A skill absent from this table is unreachable through `/msg`.

## End-to-end happy path

```
/msg --init  →  /intake  →  /plan-pm  →  (/plan-review)  →  /plan-em  →  (/plan-review)
                                                                         ↓
                                                             /eng --build
                                                                         ↓
                                             /pre-merge  (quality gate; then /merge)
                                                                         ↓
                      /merge  (staging step: push, PR, CI, merge, deploy, human test)
                                                                         ↓
                                     (human)  /merge  (production step: release to main)
```

`(/plan-review)` is a step the user chooses: plan-pm and plan-em suggest it, `--review on` makes them run it, and plan-em still certifies an unchecked PRD before engineering.
