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

Run `/msg` to browse these interactively, or invoke any skill directly. `/msg --gui` opens a local, Notion-style PRD board (Kanban/table, light + dark) where you can edit PRDs, drag statuses, tick off todos, browse project docs, read run reports, and run Claude prompts — served on `127.0.0.1` only.

**Run reports.** `eng --build`, `/review`, and `/pre-merge` each end a run by writing `report-[n].md` into the PRD's `features/prd-[n]/reports/` folder (`features/reports/` when no PRD applies) — a plain-language record of the work done (features, code changes, lines added/deleted, tests passed/failed) plus what you can expect and the exact steps to verify the feature works. The board renders them under a dedicated **Reports** tab, grouped by PRD. Schema: `.claude/skills/shared/refs/report-schema.md`.

**Run modes.** Every skill runs in one of two modes: **comprehensive** (default — full fan-out, all gates) or **flash** (fewer subagents/buckets/gates/turns for a fast pass). Add `--flash`/`--comprehensive` per run, or set a durable default with `/msg --set-mode --flash|--comprehensive` (precedence: per-run flag > orchestrator-forwarded > local `pref.json` > global > comprehensive). The safety floor — DB/breaking-change pauses, branch isolation, never push/merge, secret scan, PRD §9 ledger — is **never relaxed in either mode**. See ARCHITECTURE.md § Run modes.

### 📐 Plan

| Skill | Description |
|-------|-------------|
| `/msg --init` | One-time project bootstrap — three-phase interview (project basics, architecture, design system) batched into ≤4 question prompts, then scaffolds `devkit/` (AHA.md, GLOSSARY.md, ARCHITECTURE.md, DESIGN-SYSTEM.md, OPEN-QUESTIONS.md) and root files. Idempotent. |
| `/plan-pm` | Principal PM — interviews via 5 questions, then writes a structured PRD to `features/prd-[n]/`. Splits large epics. `--roadmap` analyses the existing PRDs (flagging bloat/overlap, proposing approval-gated split/merge/fold/trim) and sequences them into phases in `roadmap/roadmap.md`, viewable on the `/msg --gui` Roadmap tab. |
| `/plan-tune` | Staff PM auditor — numbered, severity-tagged PRD audit (`--product`/`--eng`); applies all fixes inline. |
| `/plan-em` | Engineering Manager — spins up specialist agents to write engineering sections into the PRD, then synthesises the output. |

### 🔨 Build

| Skill | Description |
|-------|-------------|
| `/eng` | Platform-agnostic engineering agent — `--plan` proposes file changes for approval **and** writes the per-feature todo tickets in the same pass, `--build` writes code from the todos (falling back to exec-table rows). `--build --loop` adds a plan-tune review cycle after each build pass. `--build roadmap=roadmap/roadmap.md` runs an autonomous **product-operations orchestrator** that executes a whole roadmap phase-by-phase via `eng`/`review`/`test`/`pre-merge` subagents — fixing critical+major by default, guarding production (DB/data/config pauses, branch-isolated, never pushes/merges), and reporting on an interval. |
| `/test` | Runs unit, e2e, functional, visual, load, a11y, perf, API, mobile, and coverage buckets via detected runners. |
| `/review` | After `eng --build`, fans out `/cook` sub-agents across five review modes plus mechanical gates, aggregating findings into JSON. |
| `/pre-merge` | Pre-push gate — integration, e2e, build, deep-security, and bundle-size checks; emits a severity-graded JSON verdict. |

---

Credits to my dear JC who previously had her own harness with a bajillion agents. Great times.