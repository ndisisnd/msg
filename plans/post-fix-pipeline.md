---
name: post-fix-pipeline
description: Phase 3b — entered after canary passes clean; runs CI/CD review, writes commit messages, runs git actions (commit/push/PR), updates documentation if needed, then em-agent synthesizes for a go/no-go before production deployment.
type: plan
phase: 3b
---

# Post-Fix Pipeline

## 1. Skill Identity

```yaml
name: post-fix-pipeline
description: >
  Phase 3b of the product ship workflow. Entered when pre-ship canary passes
  clean. Runs CI/CD review, generates commit messages for all changes, runs
  git actions (commit, push, PR), updates any affected documentation, then
  em-agent synthesizes a go/no-go report. Human confirms before production
  deployment is triggered.
type: plan
phase: 3b
```

### Component Skills

| Skill | Role |
|-------|------|
| `eng-review-cicd` | CI/CD specialist — reviews pipeline config, build scripts, deployment manifests |
| `commit-writer` | Writes structured commit messages for all staged changes |
| `git-agent` | Runs git actions: stage, commit, push, open PR |
| `doc-updater` | Updates documentation if code changes affect public interfaces, APIs, or user-facing behavior |
| `em-agent` | Engineering Manager — synthesizes CI/CD + canary reports into a go/no-go decision document |

---

## 2. Trigger Conditions

- Entered after pre-ship-pipeline canary passes clean
- All pre-ship fix cycles complete; no outstanding canary issues

**Hard refusals:**
- CI/CD review must complete before em-agent synthesizes
- Commit message must be written and presented to the user before git-agent commits
- Git actions (commit/push) do not run without user review of the commit message
- Production deployment does not proceed without explicit human confirmation at the final gate

---

## 3. Flow

### CI/CD Review

`eng-review-cicd` reviews the CI/CD pipeline config, build scripts, deployment manifests, and environment variable handling. Produces a structured findings report.

### Commit message

`commit-writer` inspects all staged changes (from fix cycles and any other modifications) and writes structured commit messages — one per logical change group. Messages are presented to the user for review before being applied.

### Git actions

`git-agent` runs in sequence: `git add` (staged files), `git commit` (with written messages), `git push`, then opens a PR if a remote is configured. Each action is confirmed with the user before executing. No force pushes, no `--no-verify`.

### Documentation update

`doc-updater` checks whether any changes affect public interfaces, exported APIs, configuration options, or user-facing behavior. If so, it updates the relevant documentation files. If no documentation changes are needed, this step is skipped.

### EM synthesis

`em-agent` reads the CI/CD review report and the clean canary reports carried over from pre-ship. Produces a structured go/no-go decision document covering:
- Overall ship readiness
- CI/CD findings (critical or advisory)
- Advisory findings with required actions
- Go / no-go recommendation with rationale

Present the EM synthesis report to the human. Human approves to deploy or terminates.

### Deployment

**Mandatory confirmation gate:** Before any deployment action, present the human with an explicit confirmation prompt naming the target environment (production), target platform(s), and artifact(s) to be deployed. This gate fires every time — it cannot be bypassed by the EM report approval.

On confirmation: trigger deployment to production per platform:
- Vercel for web
- Fly.io for backend
- App Store Connect for iOS
- Google Play for Android

On rejection: pipeline ends; no deployment is triggered.

---

## 4. Workflow

### Diagram

```
◆ entered from pre-ship-pipeline (canary clean) ◆
                       │
                       ▼
        ┌──────────────────────────┐
        │ eng-review-cicd          │
        │ (CI/CD review)           │
        └──────────────┬───────────┘
                       │
                       ▼
        ┌──────────────────────────┐
        │ commit-writer            │
        │ writes commit message(s) │
        └──────────────┬───────────┘
                       │
                       ▼
        ╔══════════════════════════╗
        ║ <HUMAN: review commit    ║
        ║ message(s)>              ║
        ╚══════════════┬═══════════╝
                       │
                       ▼
        ┌──────────────────────────┐
        │ git-agent:               │
        │ add → commit → push      │
        │ → open PR                │
        └──────────────┬───────────┘
                       │
                       ▼
        ┌──────────────────────────┐
        │ doc-updater              │
        │ (skip if no doc changes) │
        └──────────────┬───────────┘
                       │
                       ▼
        ┌──────────────────────────┐
        │ em-agent synthesizes     │
        │ CI/CD + canary reports;  │
        │ go/no-go recommendation  │
        └──────────────┬───────────┘
                       │
                       ▼
        ╔══════════════════════════╗
        ║ <HUMAN: approve EM       ║
        ║ report & deploy?>        ║
        ╚══════════════┬═══════════╝
                       │
               ┌── no ─┴─ yes ──┐
               │                 │
           ◆ END ◆               ▼
                   ╔══════════════════════════╗
                   ║ <HUMAN: confirm          ║
                   ║ production deploy?>      ║
                   ╚══════════════┬═══════════╝
                                  │
                          ┌── no ─┴─ yes ──┐
                          │                 │
                      ◆ END ◆    ┌──────────▼──────────┐
                                 │ deploy to production │
                                 │ (per platform)       │
                                 └──────────┬───────────┘
                                            │
                                            ▼
                                        ◆ SHIPPED ◆
```

### Protocol

**Step 1 — eng-review-cicd: CI/CD review**
Runs immediately on entry. Reviews CI/CD pipeline config, build scripts, deployment manifests, environment variable handling. Produces a findings report.

**Step 2 — commit-writer: commit messages**
Inspects all staged changes. Groups changes logically. Writes a structured commit message per group. Presents messages to the user for review before applying.

**Step 3 — git-agent: git actions**
Executes in sequence after user reviews commit messages: `git add` (staged files) → `git commit` (with written messages) → `git push` → open PR (if remote configured). Presents each action to the user before executing. No force pushes, no `--no-verify`.

**Step 4 — doc-updater: documentation**
Checks whether changes affect public interfaces, exported APIs, config options, or user-facing behavior. Updates relevant documentation files if so. Skips if no documentation changes are needed.

**Step 5 — em-agent: synthesis report**
Reads CI/CD report and the clean canary reports from pre-ship. Produces a structured go/no-go document. Presents to human. Human approves to continue or terminates.

**Step 6 — Deployment confirmation gate**
Present explicit confirmation naming: target environment (production), target platform(s), and artifact(s) to deploy. Fires every time without exception — cannot be bypassed by the EM report approval.

**Step 7 — Deploy**
On confirmation: deploy to production per platform (Vercel / Fly.io / App Store Connect / Google Play). Each platform is a separate invocation. On rejection: pipeline ends.

---

## 5. Inputs and Outputs

### Inputs

| Artifact | Format | Source |
|----------|--------|--------|
| Clean canary reports ×3 | Structured markdown | pre-ship-pipeline |
| Staged code changes | Code files / diffs | Working directory |

### Outputs

| Artifact | Format | Destination |
|----------|--------|-------------|
| CI/CD review report | Structured markdown | em-agent |
| Commit message(s) | Git commit messages | Repository |
| PR | Pull request | Remote (if configured) |
| Documentation updates | Markdown files | Repository |
| EM synthesis report | Structured decision document | Human gate before deploy |
| Deploy artifact | Production deployment | Target platform |

---

## 6. Reference Files

- `refs/reviewer-report-template.md` — structured findings format for eng-review-cicd
- `refs/em-synthesis-template.md` — structured synthesis report format for em-agent
