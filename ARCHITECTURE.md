# MSG Architecture

MSG is a Claude Code skill harness — a collection of slash-command skills for structured, agent-driven software development. Skills install globally into `~/.claude/skills/` and are invoked directly from Claude Code sessions.

## Layers

### 1. Install layer — `install.sh`

Shallow-clones this repo into a temp directory, then copies:
- `skills/` → `~/.claude/skills/` (each skill as its own subdirectory; `improve/` is excluded — it's a repo-internal plan tracker, never an installed skill)
- `scripts/` → `~/.claude/scripts/` (all `.sh` files made executable)

Retired artifacts are scrubbed on every install via a **removal manifest** (`remove-manifest.txt` at the repo root): one exact `skills/<name>` or `scripts/<file>` path per line, `rm -rf`'d under `~/.claude/` after the copy step. Retiring a skill is therefore a one-line data change, not a script edit. The parser rejects globs, `..`, absolute paths, and anything outside `skills/`+`scripts/`, and skips any entry this run also installs; an absent target is a silent (idempotent) skip.

Pass `--with-cook` to also bootstrap the [cook](https://github.com/ndisisnd/cook) dependency, which provides the `/cook` skill MSG skills call for domain-specific coding standards.

### 2. Skill layer — `~/.claude/skills/<name>/SKILL.md`

Each skill is a directory containing a `SKILL.md` — a structured prompt consumed by Claude Code's skill system when the user invokes `/name`. Skills are self-contained: they declare their `allowed_tools`, `model`, and protocol inline.

Skills compose in two ways:
- **In-session chaining** via the `Skill` tool (e.g. `plan-pm`'s end-of-run gate can invoke `plan-tune` or `plan-em` directly)
- **Subagent delegation** via the `Agent` tool (e.g. `/review` fans out `/cook` sub-agents in parallel)

The `shared/` skill holds common prompt fragments imported by multiple skills.

### 3. Script layer — `~/.claude/scripts/`

Bash helpers invoked by skills at runtime. Skills resolve scripts locally first (`./claude/scripts/`), then fall back to the global install.

| Script | Purpose |
|--------|---------|
| `test-tooling-detect.sh` | Emits project tooling as JSON — test runners, mechanical runners (lint/format/typecheck), secret scanners, build tool, and bundle analyzer. Consumed at runtime by `test`, `review`, and `pre-merge` (replacing manual reads of `shared/refs/tooling-detection.md`, now maintainer docs only) |
| `test-aggregate-verdict.sh` | Merges per-bucket test results into a single verdict |
| `test-init-profile.sh` | Writes the test profile for a project |
| `scan-n.prd` | Assigns the next available PRD number |
| `plan-tune-preflight.sh` | Validates PRD structure before a tune pass |
| `changelog-gate.py` | Validates CHANGELOG.md format |
| `eng-comment-scan.sh` | Deterministic A4 comment scan — flags added symbol declarations with no plain-English comment above them; run at the `eng --build` commit gate |
| `eng-commit-cap.sh` | A5 small-commit cap — blocks a staged diff over 500 changed LOC (300 with `--breaking`); `--oversize-reason` escape hatch |

### 4. Devkit layer (scaffolded projects)

`/msg --init` generates a `devkit/` directory in the target project. These files are consumed by all other skills before doing any work — they are never created by anything except `/msg --init`.

| File | Role |
|------|------|
| `devkit/AHA.md` | Institutional knowledge log — past learnings agents must not repeat |
| `devkit/GLOSSARY.md` | Canonical domain terms — consistent naming across all agents |
| `devkit/ARCHITECTURE.md` | System constraints, layers, integration points — scopes what agents may touch |
| `devkit/DESIGN-SYSTEM.md` | Component registry — which UI components exist and what needs data ingestion |
| `devkit/OPEN-QUESTIONS.md` | Unresolved decisions — build agents write here when they hit ambiguity |

## Skill pipelines

```
Planning:   plan-pm → plan-tune --product → plan-em → plan-tune --eng
Execution:  eng --plan → eng --build → review → test → fix (loop) → pre-merge
Roadmap:    plan-pm --roadmap → (approve reshaping) → roadmap/roadmap.md → eng --build roadmap= (orchestrated execution)
```

Every skill is invoked directly and standalone; a skill's end-of-run gate recommends a next step but never invokes it automatically. `eng --plan` writes the per-feature todo tickets in the same pass as the engineering section, so execution is `eng --plan → eng --build` with no separate todo phase.

The **Roadmap** pipeline is the one deliberately-autonomous path. `plan-pm --roadmap` analyses the existing PRDs — flagging bloat/overlap and proposing `SPLIT`/`MERGE`/`FOLD`/`TRIM` ops, applied only on per-op approval — then sequences them into phases in `roadmap/roadmap.md` (viewable on the `/msg --gui` Roadmap tab). `eng --build roadmap=roadmap/roadmap.md` turns the current session into a **product-operations orchestrator** that executes the roadmap phase-by-phase, spawning `eng`/`review`/`test`/`pre-merge` subagents, fixing critical+major (`blocker`+`high`) by default, and looping until each phase is clean. It stays within the standing convention's spirit — it emits a plan and asks **once** before executing, then runs autonomously behind guardrails: all work on `feat/prd-<n>-*` branches, a pause for sign-off on any database/data/production-config touch (`eng-db-touch.sh`), and it never pushes or merges (branches are left merge-ready).

## Skill inventory

| Skill | Standalone |
|-------|------------|
| `plan-pm` | Yes |
| `plan-tune` | Yes (`--product` / `--eng`) |
| `plan-em` | Yes |
| `eng` | Yes (`--plan` / `--build` / `--build --loop`) |
| `review` | Yes |
| `test` | Yes |
| `pre-merge` | Yes |
| `msg` | Yes (interactive skill browser; `--init` runs the one-time project bootstrap; `--gui` serves the local interactive PRD board — Kanban/table, PRD editing, todo toggling, prompt console, project-doc viewer, run-report reader — via `refs/gui/server.py`, bound to 127.0.0.1) |
| `shared` | Internal only |

## Run reports

`eng --build`, `review`, and `pre-merge` end every completed run by writing a `report-[n].md` (schema: `shared/refs/report-schema.md`) to the PRD's `features/prd-<n>-<slug>/reports/` folder, or `features/reports/` when no PRD is resolvable — `[n]` is the standard `max+1` counter per directory. The report carries GUI-parseable frontmatter (skill, PRD, branch, verdict, features, diff/test stats) and fixed sections covering work done, code changes, test results, **what the user can expect**, and **how to verify** the work — written for a human, derived from the PRD's acceptance criteria and the tests that ran. Writes are best-effort (a failed write never fails, blocks, or re-verdicts a run) and supplement — never replace — each skill's existing output contract (eng's build summary, review's findings JSON, pre-merge's final JSON emission). The `/msg --gui` **Reports** tab groups them by PRD and renders them read-only.

## Run modes

Every user-facing skill resolves a run mode at Step 0: **comprehensive** (default) or **flash**.

- **Precedence** (`shared/refs/mode-resolution.md`): per-run flag (`--flash`/`--comprehensive`, not persisted) > orchestrator-forwarded mode > local `.claude/msg/pref.json` > global `~/.claude/msg/pref.json` > `comprehensive`. A missing/corrupt/unknown pref silently resolves `comprehensive` — never a hard failure.
- **Pref file** — `.claude/msg/pref.json` (`{"mode": "flash"|"comprehensive"}`), written by `/msg --set-mode` at a chosen scope. It sits beside `cache/` and is **not** gitignored (only `.claude/msg/cache/` is); `install.sh` never creates or writes it (pref is user-created).
- **What flash changes** — execution count and interactivity, **not** correctness: one combined review agent instead of ≤4, two test buckets in-process instead of the parallel fan-out, build+security-only pre-merge, one generalist eng agent (≤2 platforms), collapsed interviews/gates. Each skill loads a small `refs/flash/mode-flash.md` (plan-pm: `refs/flash/mode-flash.md`) **instead of** its comprehensive refs.
- **Reuses the v2 substrate, never a leaner copy** — flash consumes the PRD-digest slices (`scan-prd-digest.py`), the shared verify prelude (`shared/refs/verify-prelude.md`), flag-based injected cook, and the session cache (`shared/refs/session-cache.md`).
- **Propagation** — in-repo orchestrators (`plan-em`, roadmap `eng --build`, `review`) forward the resolved mode into every `Skill(...)`/`Agent(...)` handoff as an explicit flag; a leaf skill never re-reads the pref mid-pipeline, so a run can't drift between local and global. (`plan`/`ship` are global-only — their propagation is a tracked follow-up in the global-skills repo.)
- **Safety floor** — DB/data/prod-config pauses, breaking-change pauses, branch isolation, never push/merge, secret scan, frontmatter stamps, F-ID stability, PRD §9 ledger, test-fail ticket, pre-merge refusals are **never relaxed in either mode** (`shared/refs/flash-floor.md`).

## Cook integration

`cook` is an optional but recommended dependency. MSG skills load project-specific coding standards from cook before generating code. Standalone skill runs call cook directly (`eng`/`plan-em` pass explicit `--<domain>` flags, e.g. `--flutter --dart`, for a cacheable, P0-guaranteed compile). On orchestrated paths, the orchestrator (`plan-em`, `review`, roadmap `eng --build`) compiles cook **once per stack** and injects the compiled standards payload into each subagent prompt, so leaf agents never re-invoke cook. Without cook, skills still work — they just skip the standards-loading step.
