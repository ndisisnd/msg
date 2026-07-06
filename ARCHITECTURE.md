# MSG Architecture

MSG is a Claude Code skill harness — a collection of slash-command skills for structured, agent-driven software development. Skills install globally into `~/.claude/skills/` and are invoked directly from Claude Code sessions.

## Layers

### 1. Install layer — `install.sh`

Shallow-clones this repo into a temp directory, then copies:
- `skills/` → `~/.claude/skills/` (each skill as its own subdirectory)
- `scripts/` → `~/.claude/scripts/` (all `.sh` files made executable)
- `improve/` is intentionally excluded — a repo-local meta skill (see `install.sh`'s `LOCAL_ONLY_SKILLS`), not part of the installed surface.

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

### 4. Devkit layer (scaffolded projects)

`/msg-init` generates a `devkit/` directory in the target project. These files are consumed by all other skills before doing any work — they are never created by any skill except `msg-init`.

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
Execution:  eng --plan → eng --todo → eng --build → review → test → fix (loop) → pre-merge
Roadmap:    plan-pm --roadmap → (approve reshaping) → roadmap/roadmap.md → eng --build roadmap= (orchestrated execution)
```

Every skill is invoked directly and standalone; a skill's end-of-run gate recommends a next step but never invokes it automatically. The `eng --todo` phase (task breakdown into per-feature tickets) runs between `--plan` and `--build` only when `plan-em`'s `prefs.json` `todos` toggle is on; with it off, execution is `eng --plan → eng --build` as before.

The **Roadmap** pipeline is the one deliberately-autonomous path. `plan-pm --roadmap` analyses the existing PRDs — flagging bloat/overlap and proposing `SPLIT`/`MERGE`/`FOLD`/`TRIM` ops, applied only on per-op approval — then sequences them into phases in `roadmap/roadmap.md` (viewable on the `/msg --gui` Roadmap tab). `eng --build roadmap=roadmap/roadmap.md` turns the current session into a **product-operations orchestrator** that executes the roadmap phase-by-phase, spawning `eng`/`review`/`test`/`pre-merge` subagents, fixing critical+major (`blocker`+`high`) by default, and looping until each phase is clean. It stays within the standing convention's spirit — it emits a plan and asks **once** before executing, then runs autonomously behind guardrails: all work on `feat/prd-<n>-*` branches, a pause for sign-off on any database/data/production-config touch (`eng-db-touch.sh`), and it never pushes or merges (branches are left merge-ready).

## Skill inventory

| Skill | Standalone |
|-------|------------|
| `plan-pm` | Yes |
| `plan-tune` | Yes (`--product` / `--eng`) |
| `plan-em` | Yes |
| `eng` | Yes (`--plan` / `--todo` / `--build` / `--build --loop`) |
| `review` | Yes |
| `test` | Yes |
| `pre-merge` | Yes |
| `msg-init` | Yes |
| `msg` | Yes (interactive skill browser; `--gui` serves the local interactive PRD board — Kanban/table, PRD editing, todo toggling, prompt console, project-doc viewer — via `refs/gui/server.py`, bound to 127.0.0.1) |
| `shared` | Internal only |

## Cook integration

`cook` is an optional but recommended dependency. MSG skills load project-specific coding standards from cook before generating code. Standalone skill runs call cook directly (`eng`/`plan-em` pass explicit `--<domain>` flags, e.g. `--flutter --dart`, for a cacheable, P0-guaranteed compile). On orchestrated paths, the orchestrator (`plan-em`, `review`, roadmap `eng --build`) compiles cook **once per stack** and injects the compiled standards payload into each subagent prompt, so leaf agents never re-invoke cook. Without cook, skills still work — they just skip the standards-loading step.
