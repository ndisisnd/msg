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
Planning:   plan-pm → plan-tune --product → plan-em → plan-tune --eng
Execution:  eng --plan → eng --todo → eng --build → review → test → fix (loop) → pre-merge
```

Every skill is invoked directly and standalone; a skill's end-of-run gate recommends a next step but never invokes it automatically. The `eng --todo` phase (task breakdown into per-feature tickets) runs between `--plan` and `--build` only when `plan-em`'s `prefs.json` `todos` toggle is on; with it off, execution is `eng --plan → eng --build` as before.

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
| `msg` | Yes (interactive skill browser) |
| `shared` | Internal only |

## Cook integration

`cook` is an optional but recommended dependency. MSG skills call `Skill("cook", "<task summary>")` to load project-specific coding standards before generating code. Without cook, skills still work — they just skip the standards-loading step.
