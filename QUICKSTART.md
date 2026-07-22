# Quickstart

Two setup phases — **machine**, then **repo** — followed by one guided run through the pipeline.

Every step below carries a **verify** line. If a verify fails, stop and fix it before continuing; the gates are ordered and a skipped step surfaces later as a refusal, not a warning.

> **The one thing people miss:** `/pre-merge` and `/post-merge` each need their own one-time `--init` (steps 5 and 6). Until then `/pre-merge` refuses with `no_manifest` and runs zero components. Bootstrapping the repo with `/msg --init` alone is not enough.

---

## 0 · Prerequisites

| Need | Why | Check |
|------|-----|-------|
| `git` | Everything | `git --version` |
| `curl` | Installer | `curl --version` |
| Claude Code | Runs the skills | — |
| `gh` CLI, authenticated | pre-merge opens PRs, post-merge merges them | `gh auth status` |
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
ls ~/.claude/skills     # msg intake plan-pm plan-tune plan-em eng pre-merge post-merge shared
ls ~/.claude/scripts    # non-empty: preflight-check-*.sh, post-merge-protection.sh, ...
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

Creates `devkit/AHA.md`, `GLOSSARY.md`, `ARCHITECTURE.md`, `DESIGN-SYSTEM.md`, `OPEN-QUESTIONS.md`, `PLATFORMS.md`, seeds `devkit/policy.json` (`init:false` + release flow), and writes the root `INTAKE.md` backlog ledger.

**Verify:** `devkit/policy.json` exists and contains `release_flow`.

Idempotent and strictly additive — re-running only fills gaps. Accumulated `AHA.md` and `GLOSSARY.md` content is never rewritten.

### 4. `/msg --init-staging` *(only if you chose direct flow and now want staging)*

The only path that creates a `staging` branch: branches off prod, pushes, offers branch protection, flips policy to `staged`.

**Verify:** `git branch -r | grep staging`, and `policy.json` shows `"release_flow": "staged"`.

Skip this if you deliberately ship direct-to-prod — every human gate is preserved either way.

### 5. `/pre-merge --init`

Detects your pipeline (tests, lint, coverage, security, preview, and whether `.github/workflows/` runs the gate on PRs), offers to install or scaffold the missing free/OSS pieces, and writes the `components[]` manifest into `devkit/policy.json`.

**Verify:** `policy.json` has a non-empty `components[]`.

Without it `/pre-merge` refuses `no_manifest` and runs nothing. Use `/pre-merge --update` later to reconcile the manifest as the code drifts.

### 6. `/post-merge --init`

Sets up branch protection and deploy tooling, records the release flow, verifies staging is actually ready per platform, and flips `policy.json` to `init:true`.

**Verify:**

```bash
~/.claude/scripts/post-merge-protection.sh --verify
```

Expect `PROTECTED main` / `PROTECTED staging`. `NO_GH` means `gh` is missing; `UNPROTECTED` names what's missing. On a private Free-plan repo that cannot set protection, policy records the stance as `optional` and the gate is not blocked — that's expected, not a failure.

### 7. `/kermit --init` *(optional)*

Conventional-commit formatter and changelog manager. Installed separately from msg; initializes `CHANGELOG.md`.

---

## Part 3 · Your first feature

```
/intake → /plan-pm → /plan-em → /eng --plan → /eng --build
                                                    ↓
                                /pre-merge   (opens PR feature→staging)
                                                    ↓
                        /post-merge --staging   (merge, deploy, human test)
                                                    ↓
                     /post-merge --production   (double-confirmed release)
```

| # | Command | What happens | Your move |
|---|---------|--------------|-----------|
| 8 | `/intake` | Interviews you, fleshes out the idea, grades it, writes a row to `INTAKE.md` | Describe the feature or bug |
| 9 | `/plan-pm` | Drafts the full PRD solo into `features/prd-[n]-[slug]/` | Answer the batched open questions |
| 10 | `/plan-em` | Certifies the PRD, proposes a specialist roster, writes the engineering sections | **Approve the roster** — the single gate here |
| 11 | `/eng --plan` | Proposes file changes and writes the per-feature todo tickets | Approve the file changes |
| 12 | `/eng --build` | Writes the code on a `feat/prd-<n>-*` branch | — |
| 13 | `/pre-merge` | Runs the pipeline, stands up a pokeable preview, opens the PR to staging | **Approve or reject the preview** |
| 14 | `/post-merge --staging` | Merges on green CI, deploys, hands you a human test script | Run the script, then sign off |
| 15 | `/post-merge --production` | Opens the staging→main release PR, merges on green CI + review, deploys, tags `v<x.y.z>+<build>` | **Double-confirm** |

`/plan-tune` runs automatically inside `/plan-em` before each wave — you don't invoke it yourself.

Each of `eng --build`, `pre-merge`, and `post-merge` ends by writing `report-[n].md` into the PRD's `reports/` folder: what was done, what to expect, and how to verify it.

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

3. /pre-merge --init
   Verify: devkit/policy.json has a non-empty components[] array.

4. /post-merge --init
   Verify: ~/.claude/scripts/post-merge-protection.sh --verify prints PROTECTED
   for each branch. NO_GH or a Free-plan `optional` stance is an acceptable result
   — report it rather than treating it as a failure.

When all four are done, summarise the resolved release flow, the components[] the
pre-merge pipeline will run, and the branch-protection stance.
```

Then start the feature loop with `/intake`.

---

## Appendix B · Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Slash commands don't exist | Claude Code hasn't reloaded `~/.claude/skills` | Fully quit and reopen |
| `/pre-merge` refuses `no_manifest` | No `components[]` in `policy.json` — step 5 not run, or the file predates v3 | `/pre-merge --init` |
| Pipeline runs the wrong checks | Manifest drifted from the code | `/pre-merge --update` |
| `/post-merge --production` refuses `stale_signoff` | Commits landed on staging after the sign-off sha | Re-run `/post-merge --staging` and re-test |
| `/post-merge --production` refuses `release_in_flight` | Another release holds the lock | Wait, or follow the printed manual unlock if the lock is over 2h stale |
| `/post-merge --production` refuses `no_signoff` | Staging was never signed off | Run `/post-merge --staging` first |
| `post-merge-protection.sh` prints `NO_GH` | `gh` missing or unauthenticated | Install `gh`, then `gh auth login` |
| `post-merge-protection.sh` prints `NO_REMOTE` | No git remote configured | `git remote add origin <url>` |
| `/msg --init-staging` stops immediately | No `devkit/policy.json` — repo was never bootstrapped | `/msg --init` first |
| Coding standards never load | cook isn't installed | `curl -fsSL https://raw.githubusercontent.com/ndisisnd/cook/main/install.sh \| bash` |

---

**Next:** [README.md](README.md) for the full skill surface · [ARCHITECTURE.md](ARCHITECTURE.md) for how the layers fit together.
