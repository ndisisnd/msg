# MSG Architecture

MSG is a Claude Code skill harness — a collection of slash-command skills for structured, agent-driven software development. Skills install globally into `~/.claude/skills/` and are invoked directly from Claude Code sessions.

## Layers

### 1. Install layer — `install.sh`

Shallow-clones this repo into a temp directory, then copies:
- `skills/` → `~/.claude/skills/` (each skill as its own subdirectory)
- `scripts/` → `~/.claude/scripts/` (all `.sh` files made executable)

Pass `--with-cook` to also bootstrap the [cook](https://github.com/ndisisnd/cook) dependency, which provides the `/cook` skill MSG skills call for domain-specific coding standards.

### 2. Skill layer — `~/.claude/skills/<name>/SKILL.md`

Each skill is a directory containing a `SKILL.md` — a structured prompt consumed by Claude Code's skill system when the user invokes `/name`. Skills are self-contained: they declare their `allowed_tools`, `model`, and protocol inline.

Skills compose in two ways:
- **In-session chaining** via the `Skill` tool (e.g. `/plan` calls plan-pm, plan-tune, plan-em in sequence)
- **Subagent delegation** via the `Agent` tool (e.g. `/ship` fans out `eng --build` agents in parallel)

The `shared/` skill holds common prompt fragments imported by multiple skills.

### 3. Script layer — `~/.claude/scripts/`

Bash helpers invoked by skills at runtime. Skills resolve scripts locally first (`./claude/scripts/`), then fall back to the global install.

| Script | Purpose |
|--------|---------|
| `ship-find-prd.sh` | Ranks existing PRDs against a prose query (used by `/ship` Step 1) |
| `ship-db-touch.sh` | Reports database files touched in a branch diff (used by `/ship` guardrail) |
| `test-tooling-detect.sh` | Discovers test runners and configs for the project |
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
Planning:   /plan → plan-pm → plan-tune --product → plan-em → plan-tune --eng
Execution:  /ship → eng --build (parallel) ──┐
                                              ├─ review → test → fix (loop) → pre-merge
                                              └──────────────────────────────────────────
```

`/plan` and `/ship` are the two orchestrators. Everything else can be invoked standalone.

## Skill inventory

| Skill | Orchestrator | Standalone |
|-------|-------------|------------|
| `plan` | Chains plan-pm → plan-tune → plan-em → plan-tune | — |
| `ship` | Fans out eng → review → test → fix → pre-merge | — |
| `plan-pm` | — | Yes |
| `plan-tune` | — | Yes (`--product` / `--eng`) |
| `plan-em` | — | Yes |
| `eng` | — | Yes (`--plan` / `--build` / `--build --loop`) |
| `review` | — | Yes |
| `test` | — | Yes |
| `pre-merge` | — | Yes |
| `handoff` | — | Yes |
| `improve` | — | Yes |
| `msg-init` | — | Yes |
| `msg` | — | Yes (interactive skill browser) |
| `shared` | — | Internal only |

## Cook integration

`cook` is an optional but recommended dependency. MSG skills call `Skill("cook", "<task summary>")` to load project-specific coding standards before generating code. Without cook, skills still work — they just skip the standards-loading step.
