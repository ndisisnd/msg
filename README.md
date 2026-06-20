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
| `/msg-init` | One-time project bootstrap — scans the directory, asks 3–4 questions, scaffolds `devkit/` and root files. Idempotent. |
| `/plan-pm` | Principal PM — interviews via 5 questions, then writes a structured PRD to `features/prd-[n]/`. Splits large epics. `--loop` runs the full pm→tune→em→tune pipeline automatically until all critical/major issues clear. |
| `/plan-tune` | Staff PM auditor — numbered, severity-tagged PRD audit (`--product`/`--eng`); applies all fixes inline. `--from-loop` suppresses the Human gate and emits `[LOOP: PASS/FAIL]` for loop orchestrators. |
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
| `/pre-merge` | Pre-push gate — integration, e2e, build, deep-security, and bundle-size checks; emits a severity-graded JSON verdict. |
| `/handoff` | Produces a numbered, agent-readable handoff artifact at `handoff/<n>.md`. Zero input required. |
| `/todo` | Parses PRD tables, open-questions files, or prose into `TODOs.json`. Gates on approval before every write. |
| `/improve` | Lightweight improvement planner — writes a plan + acceptance criteria to `improve/[n]-[feature-type]/`. `--review <n>` runs an adversarial Opus review against an existing plan: checks assertion realism, plan quality, and feasibility; findings ranked critical → major → minor. |
