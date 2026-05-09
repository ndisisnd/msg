---
name: pre-ship-pipeline
description: Phase 3a — user runs /ship; ship spins up canary (security, standards, testing); issues written to feature-[n]/issue-[n].md; user pauses to fix manually or approves auto-fix; iterates until canary passes clean.
type: plan
phase: 3a
---

# Pre-Ship Pipeline

## 1. Skill Identity

```yaml
name: pre-ship-pipeline
description: >
  Phase 3a of the product ship workflow. Entry point is /ship. Ship spins up
  canary, which runs security, standards, and testing reviewers in parallel.
  Issues are written to feature-[n]/issue-[n].md and flagged to the user.
  User either pauses and runs fix manually, or approves auto-fix. Canary
  re-runs after each fix cycle. Loop continues until canary passes clean.
  Hands off to post-fix-pipeline when complete.
type: plan
phase: 3a
```

### Component Skills

| Skill | Role |
|-------|------|
| `ship` | Entry point — user runs /ship; spins up canary; hands off to post-fix when canary passes clean |
| `canary` | Spun up by ship — runs security, standards, testing in parallel; writes issues to `feature-[n]/issue-[n].md`; flags to user |
| `eng-review-security` | Security reviewer — auth, secrets, attack surface (via canary) |
| `eng-review-standards` | Standards reviewer — naming, structure, lint, style (via canary) |
| `eng-review-testing` | Testing reviewer — coverage, quality, gaps (via canary) |
| `fix` | Applies fixes for canary issues — invoked manually (user fix flow) or automatically (user approves auto-fix) |

---

## 2. Trigger Conditions

- User has code ready to commit and invokes `/ship`
- Ship immediately spins up canary

**Hard refusals:**
- Canary must complete (all three subagents) before ship can advance
- Auto-fix cannot run without explicit user approval — ship must present issues and wait for a decision
- Ship does not hand off to post-fix until canary passes clean

---

## 3. Flow

### Entry

User runs `/ship` with code ready to commit. Ship spins up canary.

### Canary

Canary runs three eng-review subagents in parallel:

| Reviewer | Scope |
|----------|-------|
| `eng-review-security` | Auth flows, secrets handling, input validation, attack surface, dependency vulnerabilities |
| `eng-review-standards` | Naming conventions, code structure, lint compliance, style guide adherence |
| `eng-review-testing` | Test coverage, test quality, missing edge case tests, test reliability |

### Issue output

When subagents find issues, canary combines their outputs using the `issue-[n].md` template and writes each issue as a separate file under `feature-[n]/`. All issues are flagged to the user.

If canary finds no issues, the pipeline hands off to post-fix-pipeline immediately — no user decision required.

### User decision — fix path

Present the user with two options:

1. **Pause and fix manually** — User reviews `feature-[n]/issue-[n].md` files, then runs the `fix` flow. Fix applies changes; canary re-runs.
2. **Approve auto-fix** — Ship invokes the `fix` agent automatically. Fix applies changes; canary re-runs.

After each fix cycle, canary re-runs. If issues remain, the decision is presented again. Loop continues until canary passes clean.

### Exit

Canary passes clean → hand off to post-fix-pipeline.

---

## 4. Workflow

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
│ ship spins up canary │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────────────────────────┐
│ canary runs in parallel:                 │
│   eng-review-security                    │
│   eng-review-standards                   │
│   eng-review-testing                     │
└──────────────────────┬───────────────────┘
                       │
                       ▼
             ◇ issues found? ◇
                       │
         no ───────────┴─────────── yes
          │                          │
          │           ┌──────────────▼──────────────┐
          │           │ canary writes                │
          │           │ feature-[n]/issue-[n].md;    │
          │           │ flags to user                │
          │           └──────────────┬───────────────┘
          │                          │
          │           ╔══════════════▼══════════════╗
          │           ║ <HUMAN: pause+fix manually, ║
          │           ║ or approve auto-fix?>        ║
          │           ╚══════════════┬══════════════╝
          │                          │
          │              ┌───────────┴───────────┐
          │           pause                     auto
          │              │                        │
          │       [user runs fix]       [fix agent auto]
          │              │                        │
          │              └───────────┬────────────┘
          │                          │
          │                   canary re-runs
          │                          │
          │                ◇ issues remain? ◇
          │                          │
          │              yes ────────┘ (repeat)
          │                          │
          └──────────────────── clean┘
                       │
                       ▼
           ◆ hand off to post-fix-pipeline ◆
```

### Protocol

**Step 1 — ship: spin up canary**
User runs `/ship`. Ship immediately spins up canary.

**Step 2 — canary: run subagents**
Canary runs security, standards, and testing subagents in parallel. Each produces a structured findings report.

**Step 3 — canary: issue output**
If any subagent finds issues, canary combines findings using the `issue-[n].md` template and writes one file per issue under `feature-[n]/`. All issues are flagged to the user. If no issues, skip to Step 6.

**Step 4 — user decision**
Present two options:
- **Pause and fix manually**: User reviews issues, runs `fix` flow. Fix applies changes. Go to Step 5.
- **Approve auto-fix**: Ship invokes `fix` agent. Fix applies changes. Go to Step 5.

**Step 5 — canary re-run**
Canary re-runs all three subagents. If issues remain, return to Step 3. If clean, continue.

**Step 6 — hand off**
Canary passed clean. Hand off to post-fix-pipeline.

---

## 5. Inputs and Outputs

### Inputs

| Artifact | Format | Source |
|----------|--------|--------|
| Code ready to commit | Code files / diffs | Working directory |

### Outputs

| Artifact | Format | Destination |
|----------|--------|-------------|
| `feature-[n]/issue-[n].md` | Issue files per finding | `feature-[n]/` folder |
| Clean canary reports ×3 | Structured markdown | Passed to post-fix-pipeline |

---

## 6. Reference Files

- `refs/issue-template.md` — `issue-[n].md` template used by canary to write per-issue files under `feature-[n]/`
- `refs/reviewer-report-template.md` — structured findings format for each eng-review subagent
