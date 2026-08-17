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
  `--version` (print the installed release in one line), `--help` (guided skill picker).
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
| `/msg --init` (+ `--cto` / `--eng`) | "initialise project", "bootstrap repo", "set up the framework", "start a new project" | [`refs/protocol-init.md`](refs/protocol-init.md) |
| `/msg --init-staging` | "add a staging branch", "set up staging", "switch to a staged release flow" | [`refs/protocol-init-staging.md`](refs/protocol-init-staging.md) |
| `/msg --update` | "check for msg updates", "reinitialise this project", "resync my init setup", "are there new init components" | [`refs/protocol-update.md`](refs/protocol-update.md) |
| `/msg --gui`, or the bare word `gui` | "open gui for PRDs", "show me the PRD board", "visualize my PRDs", "open kanban" | [`refs/protocol-gui.md`](refs/protocol-gui.md) — render directly, never call `AskUserQuestion` first |
| `/msg --doctor` | "check the harness", "what keeps failing", "run the doctor", "triage the incident log" | [`refs/protocol-doctor.md`](refs/protocol-doctor.md) — tallies and triages `devkit/DOCTOR.md`; **never fixes** |
| `/msg --aha` | "prune the learnings", "sweep AHA", "trim the aha log", "triage the learnings ledger" | [`refs/protocol-aha.md`](refs/protocol-aha.md) — triages and compacts `devkit/AHA.md`; only write is the ledger itself, promotions stay recommendations |
| `/msg --version`, or the bare word `version` | "which msg is this", "what version of msg do I have", "did the reinstall land", "is msg up to date" | [`refs/protocol-version.md`](refs/protocol-version.md) |
| `/msg --help` | — | [`refs/protocol-help.md`](refs/protocol-help.md) |
| `/msg` (no args) | — | [`refs/protocol-default.md`](refs/protocol-default.md) — the category/skill picker over the Skills table below |

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
`--version`, `--help`) are exempt: their "Stop. Do not emit anything else." / render contracts stand unchanged.

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
| Build & Ship | emulate | The local run lane — boots a simulator/emulator on the current branch and opens the window; a leaf, never part of the pipeline |
| Delivery | kermit | Conventional-commit formatter and changelog manager |

> **Footnote:** This table is the canonical menu — it MUST list every user-facing skill in the msg workflow and any external skill the pipeline depends on (`kermit`). When a skill is added, removed, or renamed, update this table and the `--help` routing table (`refs/protocol-help.md`) in the same change. A skill absent from this table is unreachable through `/msg`.

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
