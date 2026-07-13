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

**Run modes.** Every skill runs in one of two modes: **comprehensive** (default — full fan-out, all gates) or **flash** (fewer subagents/buckets/gates/turns for a fast pass). Add `--flash`/`--comprehensive` per run, or set a durable default with `/msg --set-mode --flash|--comprehensive` (precedence: per-run flag > orchestrator-forwarded > local `pref.json` > global > comprehensive). The safety floor is **never relaxed in either mode**: write powers are scoped per skill (eng commits to feature branches only; pre-merge opens exactly one feature→staging PR and never merges; post-merge is the only merger, and nothing reaches `main` except via its double-confirmed staging→main release), the human gates (preview approval, staging sign-off, production double-confirm) never disappear, and `/post-merge` has no flash mode at all. `/post-merge --production` guards `main` behind branch protection (green CI + human review). See ARCHITECTURE.md § Run modes.

### 📐 Plan

| Skill | Description |
|-------|-------------|
| `/msg --init` | One-time project bootstrap — three-phase interview (project basics, architecture, design system) batched into ≤4 question prompts, then scaffolds `devkit/` (AHA.md, GLOSSARY.md, ARCHITECTURE.md, DESIGN-SYSTEM.md, OPEN-QUESTIONS.md), the root `INTAKE.md` backlog ledger, and root files. Idempotent. |
| `/intake` | The planning front door — captures feature ideas and bugs as graded rows in the root `INTAKE.md` ledger. Owns the requirements interview: fleshes out thin ideas, suggests adjacent ones, splits compound/hybrid asks and XL ideas into discrete rows, and grades each in a single-turn banded judgment (complexity `C:` / token-cost `T:` / sequencing `S:` — bands only, never fake-precise numbers). Feeds `plan-pm`. |
| `/plan-pm` | Principal PM — the **autonomous PRD writer**. Consumes a graded intake row and drafts the full PRD solo (edge cases, feature/acceptance table, user flows, error handling) to `features/prd-[n]/`, pausing only for batched open questions and breaking/critical touches. Stamps the intake row `in-progress` + its `prd` mapping. `--roadmap` analyses the existing PRDs (flagging bloat/overlap, proposing approval-gated split/merge/fold/trim, reading the intake `S:` grades) and sequences them into phases in `roadmap/roadmap.md`, viewable on the `/msg --gui` Roadmap tab. |
| `/plan-tune` | Staff PM auditor — numbered, severity-tagged PRD audit (`--product`/`--eng`); applies all fixes inline. |
| `/plan-em` | Engineering Manager — spins up specialist agents to write engineering sections into the PRD, then synthesises the output. |

### 🔨 Build

| Skill | Description |
|-------|-------------|
| `/eng` | Platform-agnostic engineering agent — `--plan` proposes file changes for approval **and** writes the per-feature todo tickets in the same pass, `--build` writes code from the todos (falling back to exec-table rows). `--build --loop` adds a plan-tune review cycle after each build pass. `--build roadmap=roadmap/roadmap.md` runs an autonomous **product-operations orchestrator** that executes a whole roadmap phase-by-phase via `eng`/`pre-merge` subagents — fixing critical+major by default, guarding production (DB/data/config pauses, branch-isolated, never pushes/merges), and reporting on an interval. |
| `/pre-merge` | The CI gate — takes a feature branch from "eng says done" to "PR open against staging": sync → mechanical → unit/int → regression → platform buckets → security/migration → PRD-consistency → preview deploy (human gate) → opens PR feature→staging. Absorbs the old `/review` and `/test`; emits a severity-graded JSON verdict. |
| `/post-merge` | The ship gate — the only skill that merges. `--staging` verifies green CI, merges the feature→staging PR, deploys staging, emits a human test script, and stamps `staging-signoff:` on approval. `--production` double-confirms, opens the release PR staging→main (rollback notes per platform; iOS `IRREVERSIBLE`), and merges on green CI + human review. Branch protection (`post-merge-protection.sh`) is the machine enforcement. No flash mode — ship gates never collapse. |

---

Credits to my dear JC who previously had her own harness with a bajillion agents. Great times.