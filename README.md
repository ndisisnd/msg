<div align="center">
<img src="./asset/intro.jpg">

# 🧂 MSG

_Sh*t tastes so good, it's probably loaded with MSG._

The counterpart that relies on `/cook`, it's a heavily opinionated coding agent workflow and harness that depends on human approvals more than autonomy.

</div>

## 💻 Install

### **msg + cook (recommended)**

```bash
curl -fsSL https://raw.githubusercontent.com/ndisisnd/msg/main/install.sh | bash -s -- --with-cook
```

### **msg only**

```bash
curl -fsSL https://raw.githubusercontent.com/ndisisnd/msg/main/install.sh | bash
```

## 🗂️ Skills

Run `/msg` to browse these interactively, or invoke any skill directly. `/msg --gui` opens a local, Notion-style PRD board (Kanban/table, light + dark) where you can edit PRDs, drag statuses, tick off todos, work the `INTAKE.md` backlog on an Intake tab (grade chips, lane drag), browse project docs, read run reports, and run Claude prompts — served on `127.0.0.1` only.

**Run reports.** `eng --build`, `/pre-merge`, and `/post-merge` each end a run by writing `report-[n].md` into the PRD's `features/prd-[n]/reports/` folder (`features/reports/` when no PRD applies) — a plain-language record of the work done (features, code changes, lines added/deleted, tests passed/failed) plus what you can expect and the exact steps to verify the feature works. Post-merge's staging report carries the human test script; its production report renders release-style with any no-rollback platform flagged `IRREVERSIBLE`. The board renders them under a dedicated **Reports** tab, grouped by PRD. Schema: `.claude/skills/shared/refs/report-schema.md`.

**Safety floor.** The safety floor is **never relaxed**: write powers are scoped per skill (eng commits to feature branches only; pre-merge opens exactly one feature→staging PR and never merges; post-merge is the only merger, and nothing reaches `main` except via its double-confirmed staging→main release), and the human gates (preview approval, staging sign-off, production double-confirm) never disappear. `/post-merge --production` guards `main` behind branch protection (green CI + human review). See ARCHITECTURE.md § Safety floor.

### 📐 Plan

| Skill | Description |
|-------|-------------|
| `/msg --init` | One-time project bootstrap — batched interview (project basics, architecture, design system, **release flow**), then scaffolds `devkit/` (AHA.md, GLOSSARY.md, ARCHITECTURE.md, DESIGN-SYSTEM.md, OPEN-QUESTIONS.md), seeds `devkit/policy.json` (`init:false` + release flow), the root `INTAKE.md` backlog ledger, and root files. Idempotent. |
| `/msg --init-staging` | Adds a `staging` branch to a direct-flow repo (branches off prod, offers branch protection) and flips `devkit/policy.json` release flow to `staged`. The only mode that creates a staging branch. |
| `/intake` | The planning front door — captures feature ideas and bugs as graded rows in the root `INTAKE.md` ledger. Owns the requirements interview: fleshes out thin ideas, suggests adjacent ones, splits compound/hybrid asks and XL ideas into discrete rows, and grades each in a single-turn banded judgment (complexity `C:` / token-cost `T:` / sequencing `S:` — bands only, never fake-precise numbers). Feeds `plan-pm`. |
| `/intake --delete` | Removes a row from the backlog — the only destructive intake mode. Runs a warning pass first (a PRD it would orphan, other rows graded `S:blocked-by-#n` against it, a `completed` ship record, log history), then requires an explicit confirm. **Never renumbers** — the `#` gap stays, because renumbering would silently repoint every `blocked-by` reference. Deletes ledger rows only, never a PRD folder or file. |
| `/intake --update` | Edits a row already in the backlog. Lists every un-shipped row in full, then changes the one you pick — `idea` / `goal` / `type` on `backlog` rows only (`in-progress` rows belong to their PRD; use `/plan-tune`). A **material** change re-runs the grading rubric and the same hybrid/`≥8` split gates as capture; a cosmetic one keeps the grade. Every edit lands in `INTAKE-UPDATE.md`, a sibling file to `INTAKE.md`. Never writes `status` or `prd`. |
| `/plan-pm` | Principal PM — the **autonomous PRD writer**. Consumes a graded intake row and drafts the full PRD solo (edge cases, feature/acceptance table, user flows, error handling) to `features/prd-[n]/`, pausing only for batched open questions and breaking/critical touches. Stamps the intake row `in-progress` + its `prd` mapping. `--roadmap` analyses the existing PRDs (flagging bloat/overlap, proposing approval-gated split/merge/fold/trim, reading the intake `S:` grades) and sequences them into phases in `roadmap/roadmap.md`, viewable on the `/msg --gui` Roadmap tab. |
| `/plan-tune` | Staff PM **contract certifier** — runs a fixed seven-check certification (`--product`: checks 1/2/3/6; `--eng`: 2/4/5/6/7), each tied to a named downstream consumer ("no check without a consumer"). Auto-selects the tune type, auto-fixes every Critical + Major with a terminal `# \| Sev \| Found \| Fixed` table, asks once about Minors, pauses only on a product-decision finding. Each auto-fix writes a category-tagged learning to `devkit/AHA.md` so the next `plan-pm` draft self-heals. |
| `/plan-em` | Engineering Manager — auto-runs `plan-tune` certification before each wave (product before plan, eng before build; roster approval is the single human gate), spins up specialist agents to write engineering sections into the PRD, then synthesises the output. |

### 🔨 Build

| Skill | Description |
|-------|-------------|
| `/eng` | Platform-agnostic engineering agent — `--plan` proposes file changes for approval **and** writes the per-feature todo tickets in the same pass, `--build` writes code from the todos (falling back to exec-table rows). `--build --loop` adds a plan-tune review cycle after each build pass. `--build roadmap=roadmap/roadmap.md` runs an autonomous **product-operations orchestrator** that executes a whole roadmap phase-by-phase via `eng`/`pre-merge` subagents — fixing critical+major by default, guarding production (DB/data/config pauses, branch-isolated, never pushes/merges), and reporting on an interval. |
| `/pre-merge` | The CI gate — takes a feature branch from "eng says done" to "PR open against staging". Runs a **preflight-driven pipeline executor** over the `components[]` manifest in `devkit/policy.json`: it prunes to the components this project actually has, topo-sorts them on their dependencies, and runs independent components as parallel waves — sync → parallel correctness + security waves → coverage → regression tail → **smoke health-check → the merged `preview` human-review gate** → opens PR feature→staging. `preview` is the **sole human gate** in pre-merge: it absorbs the retired `qa` (visual capture folded in), stands up an ephemeral, isolated, pokeable env, and serves **one** unified Approve/Reject artifact carrying the machine evidence + the significance-rated manual-test-plan checklist. `smoke` is its **health precondition** — a fired preview always gets at least a default-liveness check plus the critical-path golden flows, runs first, and short-circuits so no one is ever asked to approve a dead preview. With **no manifest** it refuses `no_manifest` and points you at `/pre-merge --init`. Absorbs the old `/review` and `/test`; emits a severity-graded JSON verdict. `--init` detects the pipeline — including whether a `.github/workflows/` pipeline runs the gate on PRs — offers to install/scaffold the missing (free/OSS) pieces, and writes the manifest; `--update` reconciles it as the code drifts. (`--doctor` is a deprecated one-release alias for `--init`.) |
| `/post-merge` | The ship gate — the only skill that merges. `--staging` verifies green CI, merges the feature→staging PR, deploys staging, smoke-verifies the deploy (`smoke_cmd` from `PLATFORMS.md`), emits a human test script, and stamps `staging-signoff: <date>@<sha>` on approval — **pinned to the commit the human actually tested**, so `--production` refuses (`stale_signoff`) if anything landed on staging afterwards. `--production` double-confirms, opens the release PR staging→main (rollback notes per platform; iOS `IRREVERSIBLE`), merges on green CI + human review, then deploys and smoke-verifies the live target. Branch protection (`post-merge-protection.sh`) is the machine enforcement — now **policy-conditional** (`enforced`/`optional`/`skip` per `devkit/policy.json`, so private Free repos that can't set protection aren't blocked). `--init` sets up protection/deploy tooling + the release flow, and guards the protection offer on a CI workflow existing (so it never requires status checks nothing produces). (`--doctor` is a deprecated one-release alias for `--init`.) Ship gates never collapse. |

---

Credits to my dear JC who previously had her own harness with a bajillion agents. Great times.