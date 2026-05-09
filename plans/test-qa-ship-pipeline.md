---
name: test-qa-ship-pipeline
description: Phase 3 of the product ship workflow — structured as pre-ship (adversarial findings cleared), ship (four parallel eng-review specialists + EM synthesis), and post-ship (confirmed production deployment). Takes reviewed code from the eng-agent-pipeline as input.
type: plan
phase: 3
---

# Test → QA → Ship Pipeline

## 1. Skill Identity

```yaml
name: test-qa-ship-pipeline
description: >
  Phase 3 of the product ship workflow. Structured as three sub-phases:
  pre-ship (adversarial gate cleared, code ready for final review),
  ship (four eng-review specialists run in parallel; EM synthesizes
  findings into a go/no-go report; human approves), and post-ship
  (explicit production deployment with a mandatory human confirmation gate).
type: plan
phase: 3
```

### Component Skills

| Skill | Role | Sub-phase |
|-------|------|-----------|
| `ship` | Ship orchestrator — spins up eng-review subagents; hard-blocks on critical findings | Ship |
| `eng-review-cicd` | CI/CD specialist — reviews pipeline config, build scripts, deployment manifests | Ship |
| `eng-review-security` | Security reviewer — reviews auth, secrets handling, attack surface | Ship |
| `eng-review-standards` | Coding standards reviewer — reviews naming, structure, lint, style | Ship |
| `eng-review-testing` | Code testing reviewer — reviews test coverage, test quality, gaps | Ship |
| `em-agent` | Engineering Manager — synthesizes all eng-review reports into a go/no-go decision document | Ship |

---

## 2. Trigger Conditions

- Invoked after human dismisses or resolves adversarial review findings from `eng-agent-pipeline`
- User invokes `/ship` slash command standalone with reviewed code in context
- Reviewed, adversarially-tested code artifacts are present in the repository

**Hard refusals:**
- Ship pipeline does not start without code that has passed through `eng-adversarial-review`
- Production deployment does not proceed without explicit human confirmation at the final gate — this gate cannot be bypassed by any prior approval in the same session

---

## 3. Sub-phases

### Pre-ship

**Entry condition:** Human has cleared the adversarial review gate in `eng-agent-pipeline` — either by approving that findings are fixed, or by dismissing them as false positives/accepted risk (saved to `adversarial-review-[n].md`).

**State at entry:**
- All code committed to repository
- Tuned engineer plans present at `docs/plans/<domain>-plan-tuned.md`
- Adversarial review record present (dismissed findings) or confirmed resolved (approved findings)
- No outstanding critical or high findings pending engineer remediation

**Checklist before advancing to Ship:**
- [ ] All eng-* agents have committed their final builds
- [ ] adversarial-review-[n].md exists in project root, or all findings confirmed fixed and re-review passed
- [ ] No outstanding blocking findings from the plan review cycle

### Ship

**Entry condition:** Pre-ship checklist cleared.

**`ship` orchestrator** spins up four `eng-review` subagents in parallel:

| Reviewer | Scope |
|----------|-------|
| `eng-review-cicd` | CI/CD pipeline config, build scripts, deployment manifests, environment variable handling |
| `eng-review-security` | Auth flows, secrets handling, input validation, attack surface, dependency vulnerabilities |
| `eng-review-standards` | Naming conventions, code structure, lint compliance, style guide adherence |
| `eng-review-testing` | Test coverage, test quality, missing edge case tests, test reliability |

Each reviewer produces a structured report with findings classified as:
- **Critical** — hard-blocks the pipeline; engineers must fix before re-running from Step 7 of `eng-agent-pipeline`
- **Advisory** — surfaces in the EM synthesis report; does not block

If any reviewer flags a critical finding, the pipeline stops immediately. No EM synthesis is produced until all critical findings are resolved and the ship reviewers re-run.

**`em-agent` synthesis** reads all four eng-review reports and produces a structured go/no-go decision document covering:
- Overall ship readiness
- Critical findings (if any remain after remediation)
- Advisory findings with required actions
- Go / no-go recommendation with rationale

Present the EM synthesis report to the human. Human approves to advance to post-ship, or terminates (pipeline ends, no deployment triggered).

### Post-ship

**Entry condition:** Human approves the EM synthesis report.

**Mandatory deployment confirmation gate:**
Before any deployment action is taken, present the human with an explicit confirmation prompt naming:
- Target environment: production
- Target platform(s): as determined by the PRD (Vercel for web, Fly.io for backend, App Store Connect for iOS, Google Play for Android)
- Artifact(s) to be deployed

This gate fires every time, without exception. It cannot be bypassed by a prior approval in the same session, including the EM report approval.

On confirmation: trigger deployment to production. Deployment is a separate skill invocation per platform.

On rejection: pipeline ends; no deployment is triggered.

---

## 4. Personas

### 4.1 Engineering Manager (`em-agent`) — Synthesis role

In this phase the EM reads four structured reviewer reports rather than the PRD. The synthesis output is a decision document, not a status update. Each finding carries a severity and a required action. The go/no-go recommendation is stated as a binary with rationale — not hedged.

### 4.2 Eng-Review Specialists

All four eng-review specialists share the same output contract:
- Findings classified as **critical** or **advisory**
- Each finding: affected file and line range, one-sentence description, severity label
- No vague praise — the output is a findings list
- Critical findings trigger an immediate pipeline stop; advisory findings aggregate into the EM report

---

## 5. Inputs and Outputs

### Inputs

| Artifact | Format | Source |
|----------|--------|--------|
| Built code artifacts | Code files, PRs, or diffs | Repository (from eng-agent-pipeline) |
| Tuned engineer plans | Structured markdown per engineer | `docs/plans/<domain>-plan-tuned.md` |
| Approved PRD | Structured markdown | `docs/prd-<feature>.md` |
| Adversarial review record | `adversarial-review-[n].md` | Project root (from eng-agent-pipeline) |

### Outputs

| Artifact | Format | Destination |
|----------|--------|-------------|
| eng-review reports ×4 | Structured markdown per reviewer | Aggregated by EM agent |
| EM synthesis report | Structured decision document | Human gate before deploy |
| Deploy artifact | Deployment to staging or production | Target platform (Vercel, Fly.io, App Store Connect, Google Play) |

---

## 6. Workflow

### Diagram

```
┌──────────────────────┐
│ PRE-SHIP             │
│ Adversarial gate     │
│ cleared; code ready  │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ SHIP                 │
│ [9] ship spins up    │
│     eng-review       │
│     subagents        │
│     (cicd, security, │
│     standards, tests)│
│     in parallel      │
└──────────┬───────────┘
           │
           ▼
  ◇ critical findings? ◇
           │
       ┌── yes ──▶ ◆ BLOCKED ◆
       │   (fix and re-run
       │    from eng-agent-pipeline
       │    Step 7)
       no
       │
       ▼
┌──────────────────────┐
│ [10] em-agent        │
│      synthesizes all │
│      eng-review      │
│      reports;        │
│      go/no-go rec.   │
└──────────┬───────────┘
           │
           ▼
╔══════════════════════╗
║ <HUMAN: approve EM   ║
║ report & deploy?>    ║
╚══════════┬═══════════╝
           │
       ┌── no ──▶ ◆ END ◆
       yes
       │
       ▼
┌──────────────────────┐
│ POST-SHIP            │
│ [11] Confirm deploy  │
│      (env, platform, │
│      artifact named) │
└──────────┬───────────┘
           │
           ▼
╔══════════════════════╗
║ <HUMAN: confirm      ║
║ production deploy?>  ║
╚══════════┬═══════════╝
           │
       ┌── no ──▶ ◆ END ◆
       yes
       │
       ▼
┌──────────────────────┐
│ [12] Deploy to       │
│      production      │
│      (per platform)  │
└──────────┬───────────┘
           │
           ▼
        ◆ SHIPPED ◆
```

### Protocol

**Pre-ship — Entry gate**
Verify the adversarial review gate is cleared: either all findings resolved and re-review passed, or findings dismissed and saved to `adversarial-review-[n].md`. All code committed. Blocking plan review findings resolved. If any pre-ship condition is unmet, surface it to the human before activating `ship`.

**Step 9 — ship: eng-review subagents (Ship)**
ship spins up four eng-review subagents in parallel:
- `eng-review-cicd`: reviews CI/CD pipeline config, build scripts, deployment manifests, environment variable handling
- `eng-review-security`: reviews auth flows, secrets handling, input validation, attack surface, dependency vulnerabilities
- `eng-review-standards`: reviews naming conventions, code structure, lint compliance, style guide adherence
- `eng-review-testing`: reviews test coverage, test quality, missing edge case tests, test reliability

Each reviewer produces a structured report with findings classified as critical (hard-blocks the pipeline) or advisory (surfaces in EM report). If any reviewer flags a critical finding, the pipeline stops. Engineers fix the finding and re-run from Step 7 of `eng-agent-pipeline`.

**Step 10 — em-agent: synthesis report (Ship)**
em-agent reads all four eng-review reports. Produces a structured synthesis document covering: overall ship readiness, critical findings (if any remain), advisory findings with required actions, and a go/no-go recommendation. Presents the report to the human. Human approves to deploy or terminates.

**Step 11 — Deployment confirmation gate (Post-ship)**
Before any deployment action is taken, present the human with an explicit confirmation prompt naming the target environment (production), the target platform(s), and the artifact(s) to be deployed. The pipeline does not proceed until the human confirms. This gate fires every time, without exception — it cannot be bypassed by a prior approval in the same session.

**Step 12 — Deploy (Post-ship)**
On confirmation: trigger deployment to production. Target platform determined by PRD:
- Vercel for web
- Fly.io for backend
- App Store Connect for iOS
- Google Play for Android

Deployment is a separate skill invocation per platform. On rejection at the confirmation gate: pipeline ends; no deployment is triggered.

---

## 7. Reference Files

- `refs/reviewer-report-template.md` — structured report format for each eng-review subagent
- `refs/em-synthesis-template.md` — structured synthesis report format for the em-agent
