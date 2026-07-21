# MSG Architecture

MSG is a Claude Code skill harness — a collection of slash-command skills for structured, agent-driven software development. Skills install globally into `~/.claude/skills/` and are invoked directly from Claude Code sessions.

## Layers

### 1. Install layer — `install.sh`

Shallow-clones this repo into a temp directory, then copies:
- `skills/` → `~/.claude/skills/` (each skill as its own subdirectory; `improve/` is excluded — it's a repo-internal plan tracker, never an installed skill)
- `scripts/` → `~/.claude/scripts/` (all `.sh` files made executable)

Pass `--with-cook` to also bootstrap the [cook](https://github.com/ndisisnd/cook) dependency, which provides the `/cook` skill MSG skills call for domain-specific coding standards.

### 2. Skill layer — `~/.claude/skills/<name>/SKILL.md`

Each skill is a directory containing a `SKILL.md` — a structured prompt consumed by Claude Code's skill system when the user invokes `/name`. Skills are self-contained: they declare their `allowed_tools`, `model`, and protocol inline.

Skills compose in two ways:
- **In-session chaining** via the `Skill` tool (e.g. `plan-pm`'s end-of-run gate can invoke `plan-tune` or `plan-em` directly)
- **Subagent delegation** via the `Agent` tool (e.g. `/pre-merge` fans out `/cook` sub-agents in parallel for its security stage)

The `shared/` skill holds common prompt fragments imported by multiple skills, including
`shared/refs/component-catalog.md` — the single source of pre-merge/post-merge component
metadata (schema, defaults, grouping) that gate sequencing, folder placement, and
check-script naming all key off.

### 3. Script layer — `~/.claude/scripts/`

Bash helpers invoked by skills at runtime. Skills resolve scripts locally first (`./claude/scripts/`), then fall back to the global install.

| Script | Purpose |
|--------|---------|
| `preflight-check-*.sh` (+ `preflight-common.sh`) | The per-check detect+normalize family — one script per component, sharing the probe primitives in `preflight-common.sh`. Each emits a normalized check-report `detect` section; `/pre-merge --init` / `--update` run them to assemble the `components[]` manifest. **Replaced the retired monolithic `pre-merge-tooling-detect.sh`** at v3 P3 |
| `pre-merge-aggregate-verdict.sh` | Merges per-component pre-merge results into a single verdict |
| `scan-n.prd` | Assigns the next available PRD number |
| `plan-tune-preflight.sh` | Validates PRD structure before a tune pass |
| `changelog-gate.py` | Validates CHANGELOG.md format |
| `eng-comment-scan.sh` | Deterministic A4 comment scan — flags added symbol declarations with no plain-English comment above them; run at the `eng --build` commit gate |
| `eng-commit-cap.sh` | A5 small-commit cap — blocks a staged diff over 500 changed LOC (300 with `--breaking`); `--oversize-reason` escape hatch |
| `post-merge-protection.sh` | Branch-protection `--bootstrap` (sets required status checks + no-force-push on `staging`/`main`, plus ≥1 required review on `main`) and `--verify` (machine `PROTECTED`/`UNPROTECTED` lines; `NO_GH`/`NO_REMOTE` when degraded). Run by `/post-merge` Step 1; offered by `/msg --init-staging` and `--init` |
| `doctor-detect-repo.sh` | Read-only probe of repo visibility, branch-protection availability (Free-plan 403 sniff), and staging/prod branch topology → JSON. Consumed by `/pre-merge --init` and `/post-merge --init` to seed `devkit/policy.json`'s `repo` block + `release_flow` |

### 4. Devkit layer (scaffolded projects)

`/msg --init` generates a `devkit/` directory in the target project. The read-only docs are consumed by all other skills before doing any work and are never created by anything except `/msg --init`; the one writable exception, `devkit/policy.json`, is noted below the table.

| File | Role |
|------|------|
| `devkit/AHA.md` | Institutional knowledge log — past learnings agents must not repeat |
| `devkit/GLOSSARY.md` | Canonical domain terms — consistent naming across all agents |
| `devkit/ARCHITECTURE.md` | System constraints, layers, integration points — scopes what agents may touch |
| `devkit/DESIGN-SYSTEM.md` | Component registry — which UI components exist and what needs data ingestion |
| `devkit/OPEN-QUESTIONS.md` | Unresolved decisions — build agents write here when they hit ambiguity |
| `devkit/PLATFORMS.md` | Per-platform tolerance profiles + deploy pipeline — read by `/pre-merge` and `/post-merge` |
| `devkit/policy.json` | Committed, shared gate policy — release-flow shape (`staged`/`direct`), branch-protection stance, and per-step tooling decisions. Read by both gates at run time; **decisions only** (never per-machine tool presence). Schema: `shared/refs/policy-schema.md` |

`devkit/policy.json` is the one **co-written** devkit file: `/msg --init` seeds it (`version`, `init:false`, `release_flow`), `--init` completes it (tooling + branch-protection, flips `init:true`), and `/msg --init-staging` flips the flow to `staged`. It gates the pipeline: a gate run with `init:false` auto-runs `--init` first; with `init:true` it runs the protocol; with no file at all it falls back to today's behavior (unmanaged repo). See the `--init` protocol refs (`{pre,post}-merge/refs/protocol-init.md`). `--doctor` is a deprecated one-release alias for `--init` on both gates.

The root `INTAKE.md` backlog ledger is **not** a devkit file — it is scaffolded by `/msg --init` at the repo root (D13) but, unlike the read-only devkit docs, it is a living ledger written by `intake` (rows), `plan-pm` (status/prd mapping), and `post-merge --production` (completed status).

## Skill pipelines

```
Planning:   intake → plan-pm → plan-tune --product → plan-em → plan-tune --eng
Execution:  eng --plan → eng --build → pre-merge → post-merge --staging → (human) → post-merge --production
Roadmap:    plan-pm --roadmap → (approve reshaping) → roadmap/roadmap.md → eng --build roadmap= (orchestrated execution)
```

The planning pipeline starts at `intake`, the graded backlog front door: it captures every feature idea and bug as a row in the root `INTAKE.md` ledger (chronological table `# | date | type | idea | goal | grade | status | prd`), owning the requirements interview (flesh-out, adjacent-idea suggestion, hybrid/XL splitting) and grading each idea in a single-turn banded judgment (complexity / token-cost / sequencing — bands only). `plan-pm` then consumes a graded row and drafts the PRD autonomously; the row's `status` walks `backlog` (intake) → `in-progress` (plan-pm, which also fills the `prd` mapping) → `completed` (`post-merge --production`), giving the harness a living ledger connecting "things we want" to "PRDs that shipped."

Every skill is invoked directly and standalone; a skill's end-of-run gate recommends a next step but never invokes it automatically. The two deliberate exceptions are the roadmap orchestrator (below) and `plan-em`'s **certification preconditions**: `plan-em` auto-runs `plan-tune --product` before the plan wave and `plan-tune --eng` before the build wave (D18), so the build wave can never start on an uncertified plan. `plan-tune` itself is a **contract certifier** — it runs a fixed seven-check certification, each check bound to a named downstream consumer that executes a PRD field blindly (regression authoring, pre-merge's PRD-consistency gate, the safety pauses, `eng --build`'s row/ticket reads); "no check without a consumer" is its governing rule. It auto-fixes every Critical + Major and writes a category-tagged learning to `devkit/AHA.md`, which `plan-pm` reads on its next draft — a self-healing loop that trends fresh-PRD defect counts toward zero. `eng --plan` writes the per-feature todo tickets in the same pass as the engineering section, so execution is `eng --plan → eng --build` with no separate todo phase.

The **Roadmap** pipeline is the one deliberately-autonomous path. `plan-pm --roadmap` analyses the existing PRDs — flagging bloat/overlap and proposing `SPLIT`/`MERGE`/`FOLD`/`TRIM` ops, applied only on per-op approval — then sequences them into phases in `roadmap/roadmap.md` (viewable on the `/msg --gui` Roadmap tab). `eng --build roadmap=roadmap/roadmap.md` turns the current session into a **product-operations orchestrator** that executes the roadmap phase-by-phase, spawning `eng`, `pre-merge`, and `post-merge --staging` subagents (pre-merge is the single CI gate; post-merge is the single merger), fixing critical+major (`blocker`+`high`) by default, and looping until each phase is clean. Its per-PRD chain is `eng --build → pre-merge → (clean PR) → post-merge --staging → STOP` — the chain ends at staging. It stays within the standing convention's spirit — it emits a plan and asks **once** before executing, then runs autonomously behind guardrails: all work on `feat/prd-<n>-*` branches, a pause for sign-off on any database/data/production-config touch (`eng-db-touch.sh`), and it never merges with its own hands (staging merges go through the `post-merge --staging` subagent) and **never** ships to production — `post-merge --production` is always a human release.

## Skill inventory

| Skill | Standalone |
|-------|------------|
| `intake` | Yes (idea/bug capture + interview + grading into the root `INTAKE.md` backlog — the planning front door) |
| `plan-pm` | Yes (autonomous PRD writer — consumes a graded intake row; interview lives in `intake`) |
| `plan-tune` | Yes (contract certifier — seven consumer-bound checks; `--product` runs 1/2/3/6, `--eng` runs 2/4/5/6/7; auto-run by `plan-em` before each wave) |
| `plan-em` | Yes |
| `eng` | Yes (`--plan` / `--build` / `--build --loop`) |
| `pre-merge` | Yes (the CI gate — absorbs the retired `/review` + `/test`; runs a **preflight-driven pipeline executor** over the `components[]` manifest in `devkit/policy.json` — no manifest → refuses `no_manifest` naming `--init`; `--init`/`--update` detect the pipeline and write the manifest; `--doctor` is a deprecated one-release alias. The **merged `preview` gate** (absorbs the retired `qa`, id 15) is the **sole human gate**: it captures visual states **and** stands up an ephemeral pokeable env for one unified Approve/Reject; **`smoke` is its health precondition** — default-liveness floor + critical-path golden flows, runs first and short-circuits so a dead preview never reaches the human) |
| `post-merge` | Yes (the ship gate — `--staging` / `--production`; the only skill that merges; verifies each deploy per platform `release_model` — `deploy` platforms (web, macOS) smoke the live target under the v2 contract (one-shot / watch-window / poll), plus config-gated macOS notarization/signing/appcast checks; `submission` platforms (iOS, Android) never report live — a deploy is `submitted` + track, verified as submission-accepted + backend/build-health smoke, with an explicit monitor-handoff; any deploy/smoke failure offers an executable rollback or rollout-halt before the fix loop; `--production` additionally resolves read-only release identity (version/build off the last `v*` tag, provenance checked against the signed-off sha) and holds a release lock against a concurrent release; `--init` sets up protection/deploy tooling + release-flow policy and verifies per-platform staging readiness; `--doctor` is a deprecated one-release alias) |
| `msg` | Yes (interactive skill browser; `--init` runs the one-time project bootstrap + seeds `devkit/policy.json`; `--init-staging` adds a staging branch and flips the release flow to `staged`; `--gui` serves the local interactive PRD board — Kanban/table, PRD editing, todo toggling, prompt console, project-doc viewer, run-report reader — via `refs/gui/server.py`, bound to 127.0.0.1) |
| `shared` | Internal only |

## Run reports

`eng --build`, `pre-merge`, and `post-merge` end every completed run by writing a `report-[n].md` (schema: `shared/refs/report-schema.md`) to the PRD's `features/prd-<n>-<slug>/reports/` folder, or `features/reports/` when no PRD is resolvable — `[n]` is the standard `max+1` counter per directory. The report carries GUI-parseable frontmatter (skill, PRD, branch, verdict, features, diff/test stats) and fixed sections covering work done, code changes, test results, **what the user can expect**, and **how to verify** the work — written for a human, derived from the PRD's acceptance criteria and the tests that ran. Post-merge's staging report carries the human test script in `## How to verify`; its production report renders release-style, flagging any no-rollback platform (iOS) `IRREVERSIBLE`. Writes are best-effort (a failed write never fails, blocks, or re-verdicts a run) and supplement — never replace — each skill's existing output contract (eng's build summary, pre-merge's final JSON emission, post-merge's merge/deploy summary). The `/msg --gui` **Reports** tab groups them by PRD and renders them read-only.

## Safety floor

Write powers are scoped per skill rather than blanket-forbidden: eng commits to `feat/prd-<n>-*` feature branches only; pre-merge opens exactly one feature→staging PR (+ the D7 sync-merge commit) and never merges; **post-merge is the only merger** — staging via a green-CI PR merge, production via the double-confirmed staging→main release — and nothing reaches `main` any other way. DB/data/prod-config pauses, breaking-change pauses, branch isolation, secret scan, frontmatter stamps, F-ID stability, PRD §9 ledger, gate-fail ticket, pre-merge refusals, and the human gates (preview approval, staging sign-off, production double-confirm) are **never relaxed** (`shared/refs/safety-floor.md`).

## Cook integration

`cook` is an optional but recommended dependency. MSG skills load project-specific coding standards from cook before generating code. Standalone skill runs call cook directly (`eng`/`plan-em` pass explicit `--<domain>` flags, e.g. `--flutter --dart`, for a cacheable, P0-guaranteed compile). On orchestrated paths, the orchestrator (`plan-em`, `review`, roadmap `eng --build`) compiles cook **once per stack** and injects the compiled standards payload into each subagent prompt, so leaf agents never re-invoke cook. Without cook, skills still work — they just skip the standards-loading step.
