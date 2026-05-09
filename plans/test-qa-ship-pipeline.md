---
name: test-qa-ship-pipeline
description: Phase 3 of the product ship workflow — user runs ship, which spins up canary (security, standards, testing); issues written to feature-[n]/issue-[n].md; user pauses to fix manually or approves auto-fix; then CI/CD review, EM synthesis, and production deployment.
type: plan
phase: 3
---

# Test → QA → Ship Pipeline

## 1. Skill Identity

```yaml
name: test-qa-ship-pipeline
description: >
  Phase 3 of the product ship workflow. User runs ship with code ready to
  commit. Ship spins up canary; canary runs security, standards, and testing
  subagents in parallel. Issues are written to feature-[n]/issue-[n].md and
  flagged to the user. User either pauses and runs fix manually, or approves
  the ship workflow to auto-fix. Once issues are clear, CI/CD review runs,
  em-agent synthesizes all reports, and human confirms production deployment.
type: plan
phase: 3
```

### Component Skills

| Skill | Role | Sub-phase |
|-------|------|-----------|
| `ship` | Entry point — user runs ship; spins up canary; collects all review reports; forwards to em-agent | All |
| `canary` | Spun up by ship — runs security, standards, and testing subagents in parallel; writes issues to `feature-[n]/issue-[n].md`; flags issues to user | Pre-ship |
| `eng-review-security` | Security reviewer — reviews auth, secrets handling, attack surface | Pre-ship (via canary) |
| `eng-review-standards` | Coding standards reviewer — reviews naming, structure, lint, style | Pre-ship (via canary) |
| `eng-review-testing` | Code testing reviewer — reviews test coverage, test quality, gaps | Pre-ship (via canary) |
| `fix` | Fix agent — applies fixes for canary issues; invoked manually by user (fix flow) or automatically when user approves auto-fix | Pre-ship |
| `eng-review-cicd` | CI/CD specialist — reviews pipeline config, build scripts, deployment manifests; triggered independently by user during pre-ship | Pre-ship (user-triggered) |
| `em-agent` | Engineering Manager — synthesizes all review reports into a go/no-go decision document | Ship |

---

## 2. Trigger Conditions

- User has code ready to commit and invokes the `/ship` slash command
- Ship immediately spins up canary; canary runs security, standards, and testing subagents in parallel
- User invoking a **pre-ship** flow independently triggers `eng-review-cicd` (not part of canary)

**Hard refusals:**
- Canary must complete before ship advances to EM synthesis
- CI/CD review result must be present before em-agent synthesizes — ship waits for it
- Auto-fix cannot run without explicit user approval — ship must present issues and wait for a decision
- Production deployment does not proceed without explicit human confirmation at the final gate — this gate cannot be bypassed by any prior approval in the same session

---

## 3. Sub-phases

### Pre-ship

**Entry condition:** User runs `/ship` with code ready to commit.

**`ship` spins up `canary`**, which runs three eng-review subagents in parallel:

| Reviewer | Scope |
|----------|-------|
| `eng-review-security` | Auth flows, secrets handling, input validation, attack surface, dependency vulnerabilities |
| `eng-review-standards` | Naming conventions, code structure, lint compliance, style guide adherence |
| `eng-review-testing` | Test coverage, test quality, missing edge case tests, test reliability |

**Issue output:** When canary subagents find issues, canary combines their outputs using the `issue-[n].md` template and writes each issue as a separate file under the `feature-[n]/` folder. All issues are flagged to the user.

**User decision — two paths:**

1. **Pause and fix manually** — User reviews the issues in `feature-[n]/`, then runs the `fix` flow independently. Fix applies changes, canary re-runs to verify. Pipeline resumes once canary passes clean.

2. **Approve auto-fix** — User approves the ship workflow to apply fixes on its own. `fix` agent runs automatically, canary re-runs to verify. Pipeline resumes once canary passes clean.

If canary passes clean (no issues), the pipeline advances immediately — no user decision required.

**`eng-review-cicd`** is triggered independently when the user runs the pre-ship flow — it is not spun up by canary. Its report is collected by `ship` alongside the canary output.

**Checklist before advancing to Ship:**
- [ ] Canary passed clean (or all issues fixed and canary re-run passed)
- [ ] CI/CD review result present (`eng-review-cicd` triggered by user pre-ship flow)

### Ship

**Entry condition:** Pre-ship checklist cleared — canary passed clean, CI/CD review result present.

**`ship` orchestrator** collects the canary reports (testing, standards, security) and the CI/CD review report, then hands all four to `em-agent`. No additional subagents are spun up at this stage.

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
| canary reports ×3 | Structured markdown (security, standards, testing) | Collected by ship orchestrator |
| CI/CD review report ×1 | Structured markdown (user-triggered pre-ship) | Collected by ship orchestrator |
| EM synthesis report | Structured decision document | Human gate before deploy |
| Deploy artifact | Deployment to staging or production | Target platform (Vercel, Fly.io, App Store Connect, Google Play) |

---

## 6. Workflow

### Diagram

```
╔══════════════════════╗
║ user: /ship          ║
║ (code ready to       ║
║  commit)             ║
╚══════════┬═══════════╝
           │
           ▼
┌──────────────────────┐
│ [8] ship spins up    │
│     canary           │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐    ┌──────────────────────────┐
│ [8a] canary runs:    │    │ [8b] eng-review-cicd      │
│      security,       │    │      triggered by user    │
│      standards,      │    │      (pre-ship flow,      │
│      testing         │    │      independent)         │
│      in parallel     │    │                           │
└──────────┬───────────┘    └─────────────┬─────────────┘
           │
           ▼
   ◇ issues found? ◇
           │
       ┌── no ──────────────────────────────────────────┐
       │                                                 │
      yes                                                │
       │                                                 │
       ▼                                                 │
┌──────────────────────┐                                 │
│ canary writes        │                                 │
│ feature-[n]/         │                                 │
│ issue-[n].md         │                                 │
│ flags issues to user │                                 │
└──────────┬───────────┘                                 │
           │                                             │
           ▼                                             │
╔══════════════════════╗                                 │
║ <HUMAN: pause+fix    ║                                 │
║ manually, or approve ║                                 │
║ auto-fix?>           ║                                 │
╚══════════┬═══════════╝                                 │
           │                                             │
    ┌──────┴──────┐                                      │
    │             │                                      │
  pause         auto                                     │
    │             │                                      │
    ▼             ▼                                      │
[user runs    [fix agent                                 │
 fix flow]     runs auto]                                │
    │             │                                      │
    └──────┬──────┘                                      │
           │                                             │
           ▼                                             │
   canary re-runs ──── issues remain? ──yes──▶ (repeat) │
           │                                             │
          clean                                          │
           │                                             │
           └─────────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────┐
│ [9] ship collects canary reports +       │
│     CI/CD report; passes all to em-agent │
└──────────────────────┬───────────────────┘
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

**Step 8 — ship spins up canary (Pre-ship)**
User runs `/ship`. Ship immediately spins up canary. Canary runs three eng-review subagents in parallel: security, standards, testing. Each produces a findings report.

**Step 8a — canary: issue output (Pre-ship)**
If any subagent finds issues, canary combines findings using the `issue-[n].md` template and writes one file per issue under `feature-[n]/`. All issues are flagged to the user. If no issues are found, the pipeline advances to Step 9 without a user decision.

**Step 8a (issues found) — user decision: fix path**
Present the user with two options:
- **Pause and fix manually**: User reviews `feature-[n]/issue-[n].md` files, runs the `fix` flow themselves. Fix applies changes; canary re-runs. If canary passes clean, continue to Step 9. If issues remain, repeat.
- **Approve auto-fix**: Ship workflow invokes the `fix` agent automatically. Fix applies changes; canary re-runs. If canary passes clean, continue to Step 9. If issues remain, present user with another decision.

Ship must not advance to Step 9 until canary passes clean.

**Step 8b — eng-review-cicd: CI/CD review (Pre-ship, user-triggered)**
When the user runs the pre-ship flow, `eng-review-cicd` is triggered independently of canary. It reviews CI/CD pipeline config, build scripts, deployment manifests, and environment variable handling. Its report is collected by `ship` alongside the canary reports.

**Step 9 — ship: collect and forward (Ship)**
ship collects the three canary reports and the CI/CD report. Verifies all four are present. Passes all reports to `em-agent` for synthesis. No additional subagents are spun up at this stage.

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
- `refs/issue-template.md` — `issue-[n].md` template used by canary to write per-issue files under `feature-[n]/`
- `refs/em-synthesis-template.md` — structured synthesis report format for the em-agent
