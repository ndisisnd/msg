# Quickstart

Two setup phases — **machine**, then **repo** — followed by one guided run through the pipeline.

Every step below carries a **verify** line. If a verify fails, stop and fix it before continuing; the gates are ordered and a skipped step surfaces later as a refusal, not a warning.

> **The one thing people miss:** `/msg --init` sets up the repo, but each gate has its own settings. `/pre-merge` (step 5) and `/merge` (step 6) each set themselves up on their first run — they ask a few setup questions, then carry on.

---

## 0 · Prerequisites

| Need | Why | Check |
|------|-----|-------|
| `git` | Everything | `git --version` |
| `curl` | Installer | `curl --version` |
| Claude Code | Runs the skills | — |
| `gh` CLI, authenticated | merge opens and merges PRs | `gh auth status` |
| A git repo with a remote | Branch protection, PRs, release tags | `git rev-parse --is-inside-work-tree` → `true` |

Working without a remote or without `gh` is possible, but branch protection degrades to `NO_GH` / `NO_REMOTE` and the ship gate runs in a reduced mode.

---

## Part 1 · Install msg (once per machine)

### 1. Install

```bash
curl -fsSL https://raw.githubusercontent.com/ndisisnd/msg/main/install.sh | bash -s -- --with-cook
```

Drop `-s -- --with-cook` for msg only. [cook](https://github.com/ndisisnd/cook) supplies the coding standards msg loads before generating code — msg works without it, it just skips that step.

**Verify:**

```bash
ls ~/.claude/skills     # msg intake plan-pm plan-review plan-em eng pre-merge merge emulate shared
ls ~/.claude/scripts    # non-empty: script-preflight-*.sh, script-branch-protection.sh, ...
```

### 2. Confirm the skills load

Restart Claude Code, then run `/msg`.

**Verify:** the skill menu renders. If nothing happens, the restart didn't pick up `~/.claude/skills` — quit fully and reopen.

---

## Part 2 · Bootstrap the repo (once per project)

### 3. `/msg --init`

A batched interview — project basics, architecture, design system, release flow — then deterministic scaffolding.

| Mode | Behaviour |
|------|-----------|
| `/msg --init --cto` | Advisory — msg recommends architecture, language, conventions, release flow, design system |
| `/msg --init --eng` | Direct — msg asks, you decide |
| `/msg --init` | Asks which mode first |

Creates `devkit/AHA.md`, `ARCHITECTURE.md`, `DESIGN-SYSTEM.md`, `DOCTOR.md`, `ENV.md`, `GLOSSARY.md`, `OPEN-QUESTIONS.md`, `PLATFORMS.md`, seeds `devkit/policy.json` (`init:false` + release flow), writes the root `INTAKE.md` backlog ledger, and drops `roadmap/TEMPLATE-roadmap.md` for when you want to sequence PRDs by hand.

**Verify:** `devkit/policy.json` exists and contains `release_flow`.

Idempotent and strictly additive — re-running only fills gaps. Accumulated `AHA.md` and `GLOSSARY.md` content is never rewritten.

On a GitHub repo it also asks whether you want **GitHub Actions CI** at all. Answer no (no Actions minutes on a private Free repo, or CI hosted elsewhere) and the gates stop expecting PR status checks: pre-merge setup won't offer to scaffold a workflow, and `/merge` accepts a PR reporting zero checks instead of flagging it. Red or pending checks from any CI still block the merge, and every human gate stands. Change the answer any time with `/msg --update`.

### 4. `/msg --init-staging` *(only if you chose direct flow and now want staging)*

The only path that creates a `staging` branch: branches off prod, pushes, offers branch protection, flips policy to `staged`.

**Verify:** `git branch -r | grep staging`, and `policy.json` shows `"release_flow": "staged"`.

Skip this if you deliberately ship direct-to-prod — every human gate is preserved either way.

### 5. pre-merge setup — automatic on the first `/pre-merge`

There is no separate setup command. The first `/pre-merge` run detects your pipeline (tests, lint, coverage, security, smoke, and whether `.github/workflows/` runs the gate on PRs), asks about the real gaps a few questions at a time, offers to install or scaffold the missing free/OSS pieces, writes the `components[]` manifest into `devkit/policy.json`, and then runs the gate.

**Verify (after your first `/pre-merge`):** `policy.json` has a non-empty `components[]`.

Use `/pre-merge --update` later to redo setup or reconcile the manifest as the code drifts.

### 6. merge setup — automatic on the first `/merge`

There is no separate setup command. The first `/merge` run sets up branch protection and deploy tooling, checks the release flow `/msg --init` recorded, verifies staging is actually ready per platform, records the risky paths (database, dependency, auth, payment and CI files) and the CI wait limit, then carries on with the merge step.

**Verify (after your first `/merge`):**

```bash
~/.claude/scripts/script-branch-protection.sh --verify
```

Expect `PROTECTED main` / `PROTECTED staging`. `NO_GH` means `gh` is missing; `UNPROTECTED` names what's missing. On a private Free-plan repo that cannot set protection, policy records the stance as `optional` and the gate is not blocked — that's expected, not a failure.

Use `/merge --update` later when the repo changes — a new platform, a new deploy tool, a staging branch added.

### 7. `/kermit --init` *(optional)*

Conventional-commit formatter and changelog manager. Installed separately from msg; initializes `CHANGELOG.md`.

---

## Part 3 · Your first feature

```
/intake → /plan-pm → /plan-em → /eng --plan → /eng --build
                                                    ↓
                                /pre-merge   (checks + fixes; then /merge)
                                                    ↓
                                    /merge   (push, PR, CI, merge to staging, deploy, human test)
                                                    ↓
                                    /merge   (confirmed release to main)
```

| # | Command | What happens | Your move |
|---|---------|--------------|-----------|
| 8 | `/intake` | Asks what you are trying to build, fills in the rest from your project docs, grades it, writes a row to `INTAKE.md` | Describe the feature or bug |
| 9 | `/plan-pm` | Drafts the full PRD solo into `features/prd-[n]-[slug]/` | Answer the batched open questions |
| 10 | `/plan-em` | Certifies the PRD, picks the specialists, writes the engineering sections | Approve the roster only when it is unusual for the project |
| 11 | `/eng --plan` | Proposes file changes and writes the per-feature todo tickets | Approve the file changes |
| 12 | `/eng --build` | Writes the code on a `feat/prd-<n>-*` branch | — |
| 13 | `/pre-merge` | Runs the pipeline in an ephemeral test sandbox and fixes failures by itself (up to 2 rounds); the first run asks a few setup questions first. Stays local — ends with "Next: /merge" | Answer the setup questions on the first run |
| 14 | `/merge` (staging step) | Checks pre-merge passed, pushes the branch, opens the PR, waits for CI, merges to staging, deploys, hands you a human test script. The first run asks a few setup questions first | Run the script, then sign off |
| 15 | `/merge` (production step) | Opens the staging→main release PR, merges on green CI + review, deploys, tags `v<x.y.z>+<build>` | **Double-confirm** |

`/merge` with no flag picks the next step by itself; `--staging` and `--production` force one. With no staging branch, `/merge` gives you the test script, asks one "Tested and ready to ship?" question, then ships the feature branch straight to main.

`/plan-review` is suggested after `/plan-pm` and `/plan-em`; run it when you choose, or turn on `--review on` to have it run every time. `/plan-em` still runs it by itself on a PRD that was never checked.

Each of `eng --build`, `pre-merge`, and `merge` ends by writing `report-[n].md` into the PRD's `reports/` folder: what was done, what to expect, and how to verify it.

### 16. See it on a board

```
/msg --gui
```

A local Notion-style board on `127.0.0.1` only — Kanban and table views, PRD editing, todo toggling, the `INTAKE.md` backlog with grade chips, project docs, run reports, and roadmap.

---

## Appendix A · Ask your LLM to do it

Paste this into Claude Code, in your project directory, after the msg install (step 1) has run:

```
Set up msg in this repository. Run these steps in order. After each step, run its
verify check and report the result. If a verify fails, STOP and tell me what failed
— do not skip ahead, and do not substitute a different command.

1. /msg --init
   Verify: devkit/policy.json exists and contains a release_flow key.

2. If I chose a direct release flow but want staging, run /msg --init-staging.
   Verify: a remote `staging` branch exists and policy.json shows release_flow=staged.
   Skip this step entirely if the flow is already `staged` or I want direct-to-prod.

When both are done, summarise the resolved release flow. (pre-merge and merge each
set themselves up on their first run; after the first /merge,
~/.claude/scripts/script-branch-protection.sh --verify prints PROTECTED for each
branch — NO_GH or a Free-plan `optional` stance is an acceptable result.)
```

Then start the feature loop with `/intake`.

---

## Appendix B · Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Slash commands don't exist | Claude Code hasn't reloaded `~/.claude/skills` | Fully quit and reopen |
| Pipeline runs the wrong checks | Manifest drifted from the code | `/pre-merge --update` |
| `/merge --production` refuses `stale_signoff` | Commits landed on staging after the sign-off sha | Re-run `/merge --staging` and re-test |
| `/merge --production` refuses `release_in_flight` | Another release holds the lock | Wait, or follow the printed manual unlock if the lock is over 2h stale |
| `/merge --production` refuses `no_signoff` | Staging was never signed off | Run `/merge --staging` first |
| `/merge` says "Run /pre-merge first." | No pre-merge pass on the branch tip, or the commits since it are not small (over 20 lines, or a risky file) | Run `/pre-merge`, then `/merge` |
| `/merge` refuses `push_rejected` | The remote branch has commits yours lacks | Pull them, run `/pre-merge`, then `/merge` |
| `script-branch-protection.sh` prints `NO_GH` | `gh` missing or unauthenticated | Install `gh`, then `gh auth login` |
| `script-branch-protection.sh` prints `NO_REMOTE` | No git remote configured | `git remote add origin <url>` |
| `/msg --init-staging` stops immediately | No `devkit/policy.json` — repo was never bootstrapped | `/msg --init` first |
| Coding standards never load | cook isn't installed | `curl -fsSL https://raw.githubusercontent.com/ndisisnd/cook/main/install.sh \| bash` |
| The same harness glitch keeps happening | Skills log harness incidents to `devkit/DOCTOR.md` | `/msg --doctor` — it reports which problems have recurred enough to be worth fixing (it never fixes them itself) |
| `devkit/AHA.md` has grown long and noisy | Agents append a learning every time one surfaces | `/msg --aha` — sweeps the ledger, merges repeats, prunes noise, and flags recurring lessons to fix at the source (its only write is the ledger itself) |
| A repo set up before v5 is missing a devkit file | Components added after it was bootstrapped | `/msg --update` — additive, preview-gated, and it also adds the `devkit/DOCTOR.md` line to `.gitignore` |

---

**Next:** [README.md](README.md) for the full skill surface · [ARCHITECTURE.md](ARCHITECTURE.md) for how the layers fit together · [RELEASES.md](RELEASES.md) for what each release changed for you.
