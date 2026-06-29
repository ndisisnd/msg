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

Run `/msg` to browse these interactively, or invoke any skill directly.

### 📐 Plan

| Skill | Description |
|-------|-------------|
| `/msg-init` | One-time project bootstrap — 7-step, three-phase interview (project basics, architecture, design system), then scaffolds `devkit/` (AHA.md, GLOSSARY.md, ARCHITECTURE.md, DESIGN-SYSTEM.md, OPEN-QUESTIONS.md) and root files. Idempotent. |
| `/plan` | One-shot planning orchestrator — runs the full PRD pipeline once: plan-pm → plan-tune --product → plan-em → plan-tune --eng. No loop. The planning counterpart to `/ship`. |
| `/plan-pm` | Principal PM — interviews via 5 questions, then writes a structured PRD to `features/prd-[n]/`. Splits large epics. |
| `/plan-tune` | Staff PM auditor — numbered, severity-tagged PRD audit (`--product`/`--eng`); applies all fixes inline. |
| `/plan-em` | Engineering Manager — spins up specialist agents to write engineering sections into the PRD, then synthesises the output. |

### 🔨 Build

| Skill | Description |
|-------|-------------|
| `/eng` | Platform-agnostic engineering agent — `--plan` proposes file changes for approval, `--build` writes code from exec-table rows. `--build --loop` adds a plan-tune review cycle after each build pass. |
| `/test` | Runs unit, e2e, functional, visual, load, a11y, perf, API, mobile, and coverage buckets via detected runners. |
| `/review` | After `eng --build`, fans out `/cook` sub-agents across five review modes plus mechanical gates, aggregating findings into JSON. |
| `/docu` | After a code change, checks README, ARCHITECTURE.md, PRD, and AHA.md for stale references and offers inline fixes. |

### 🚢 Ship

| Skill | Description |
|-------|-------------|
| `/ship` | Autonomous build-and-ship loop — resolves a PRD, spins up `eng --build` agents in parallel, then loops /review → /test → fix until both are clean, then runs /pre-merge. Never pushes or merges. The engineering counterpart to `/plan`. |
| `/pre-merge` | Pre-push gate — integration, e2e, build, deep-security, and bundle-size checks; emits a severity-graded JSON verdict. |
| `/handoff` | Produces a numbered, agent-readable handoff artifact at `handoff/<n>.md`. Zero input required. |
| `/todo` | Parses PRD tables, open-questions files, or prose into `TODOs.json`. Gates on approval before every write. |
| `/improve` | Lightweight improvement planner — writes a plan + acceptance criteria to `improve/[n]-[feature-type]/`. `--review <n>` runs an adversarial Opus review against an existing plan: checks assertion realism, plan quality, and feasibility; findings ranked critical → major → minor. |
