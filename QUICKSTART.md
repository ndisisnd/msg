# Quickstart

Two setup phases — **machine**, then **repo** — followed by one guided run through the pipeline.

Every step below carries a **verify** line. If a verify fails, stop and fix it before continuing; the gates are ordered and a skipped step surfaces later as a refusal, not a warning.

> **The one thing people miss:** `/pre-merge` and `/merge` each need their own one-time `--init` (steps 5 and 6). Until then `/pre-merge` refuses with `no_manifest` and runs zero components. Bootstrapping the repo with `/msg --init` alone is not enough.

---

## 0 · Prerequisites

| Need | Why | Check |
|------|-----|-------|
| `git` | Everything | `git --version` |
| `curl` | Installer | `curl --version` |
| Claude Code, or OpenAI Codex CLI | Runs the skills — either harness, same skills ([Appendix C](#appendix-c--running-under-codex-cli)) | — |
| `gh` CLI, authenticated | pre-merge opens PRs, merge merges them | `gh auth status` |
| A git repo with a remote | Branch protection, PRs, release tags | `git rev-parse --is-inside-work-tree` → `true` |

Working without a remote or without `gh` is possible, but branch protection degrades to `NO_GH` / `NO_REMOTE` and the ship gate runs in a reduced mode.

---

## Part 1 · Install msg (once per machine)

### 1. Install

```bash
curl -fsSL https://raw.githubusercontent.com/ndisisnd/msg/main/install.sh | bash -s -- --with-cook
```

Drop `-s -- --with-cook` for msg only. [cook](https://github.com/ndisisnd/cook) supplies the coding standards msg loads before generating code — msg works without it, it just skips that step.

Add `--codex` if you also use OpenAI Codex CLI. It links the same install into the place Codex looks, so there is never a second copy to keep in sync — see [Appendix C](#appendix-c--running-under-codex-cli).

**Verify:**

```bash
ls ~/.claude/skills     # msg intake plan-pm plan-review plan-em eng pre-merge merge emulate shared
ls ~/.claude/scripts    # non-empty: script-preflight-*.sh, script-branch-protection.sh, ...
ls -l ~/.agents/skills  # only with --codex: nine links into ~/.claude/skills/<name>
```

### 2. Confirm the skills load

Restart Claude Code, then run `/msg`.

**Verify:** the skill menu renders. If nothing happens, the restart didn't pick up `~/.claude/skills` — quit fully and reopen.

Under Codex the same check is a new session and `$msg` — Codex invokes skills with a `$` sigil, not a `/` one, and it will not start a skill for you from a plain description.

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

It also sets the repo up for both harnesses in the same pass, whichever one you happen to be running it from: `CLAUDE.md` gets an `AGENTS.md` beside it (a pointer, so the two can't drift), and a `.codex/` layer carries the commit-gate wiring, the orchestration roles, and the one config key msg needs. If you use Codex, read [Appendix C](#appendix-c--running-under-codex-cli) next — the commit gate there needs your explicit trust before it does anything.

**Verify:** `devkit/policy.json` exists and contains `release_flow`.

Idempotent and strictly additive — re-running only fills gaps. Accumulated `AHA.md` and `GLOSSARY.md` content is never rewritten.

On a GitHub repo it also asks whether you want **GitHub Actions CI** at all. Answer no (no Actions minutes on a private Free repo, or CI hosted elsewhere) and the gates stop expecting PR status checks: `/pre-merge --init` won't offer to scaffold a workflow, and `/merge` accepts a PR reporting zero checks instead of flagging it. Red or pending checks from any CI still block the merge, and every human gate stands. Change the answer any time with `/msg --update`.

### 4. `/msg --init-staging` *(only if you chose direct flow and now want staging)*

The only path that creates a `staging` branch: branches off prod, pushes, offers branch protection, flips policy to `staged`.

**Verify:** `git branch -r | grep staging`, and `policy.json` shows `"release_flow": "staged"`.

Skip this if you deliberately ship direct-to-prod — every human gate is preserved either way.

### 5. `/pre-merge --init`

Detects your pipeline (tests, lint, coverage, security, smoke, and whether `.github/workflows/` runs the gate on PRs), offers to install or scaffold the missing free/OSS pieces, and writes the `components[]` manifest into `devkit/policy.json`.

**Verify:** `policy.json` has a non-empty `components[]`.

Without it `/pre-merge` refuses `no_manifest` and runs nothing. Use `/pre-merge --update` later to reconcile the manifest as the code drifts.

### 6. `/merge --init`

Sets up branch protection and deploy tooling, records the release flow, verifies staging is actually ready per platform, and flips `policy.json` to `init:true`.

**Verify:**

```bash
~/.claude/scripts/script-branch-protection.sh --verify
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
                        /merge --staging   (merge, deploy, human test)
                                                    ↓
                     /merge --production   (double-confirmed release)
```

| # | Command | What happens | Your move |
|---|---------|--------------|-----------|
| 8 | `/intake` | Interviews you, fleshes out the idea, grades it, writes a row to `INTAKE.md` | Describe the feature or bug |
| 9 | `/plan-pm` | Drafts the full PRD solo into `features/prd-[n]-[slug]/` | Answer the batched open questions |
| 10 | `/plan-em` | Certifies the PRD, proposes a specialist roster, writes the engineering sections | **Approve the roster** — the single gate here |
| 11 | `/eng --plan` | Proposes file changes and writes the per-feature todo tickets | Approve the file changes |
| 12 | `/eng --build` | Writes the code on a `feat/prd-<n>-*` branch | — |
| 13 | `/pre-merge` | Runs the pipeline in an ephemeral test sandbox, opens the PR to staging | — (the human test happens at `/merge --staging`) |
| 14 | `/merge --staging` | Merges on green CI, deploys, hands you a human test script | Run the script, then sign off |
| 15 | `/merge --production` | Opens the staging→main release PR, merges on green CI + review, deploys, tags `v<x.y.z>+<build>` | **Double-confirm** |

`/plan-review` runs automatically inside `/plan-em` before each wave — you don't invoke it yourself.

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

3. /pre-merge --init
   Verify: devkit/policy.json has a non-empty components[] array.

4. /merge --init
   Verify: ~/.claude/scripts/script-branch-protection.sh --verify prints PROTECTED
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
| In Codex, describing the task starts nothing | Working as intended — msg skills never self-activate there | Type `$name` (or use `/skills`) — see [Appendix C](#appendix-c--running-under-codex-cli) |
| In Codex, `$msg` isn't recognised at all | msg was installed for Claude Code only | Re-run the installer with `--codex`, then start a new session |
| Commits go through with no `CHANGELOG.md` entry under Codex | The hook isn't trusted — trust is per content hash and drops after any edit to `.codex/hooks.json` | Re-approve the project's `.codex/` layer, then re-run the liveness probe in [Appendix C](#appendix-c--running-under-codex-cli) |
| `/pre-merge` refuses `no_manifest` | No `components[]` in `policy.json` — step 5 not run, or the file predates v3 | `/pre-merge --init` |
| Pipeline runs the wrong checks | Manifest drifted from the code | `/pre-merge --update` |
| `/merge --production` refuses `stale_signoff` | Commits landed on staging after the sign-off sha | Re-run `/merge --staging` and re-test |
| `/merge --production` refuses `release_in_flight` | Another release holds the lock | Wait, or follow the printed manual unlock if the lock is over 2h stale |
| `/merge --production` refuses `no_signoff` | Staging was never signed off | Run `/merge --staging` first |
| `script-branch-protection.sh` prints `NO_GH` | `gh` missing or unauthenticated | Install `gh`, then `gh auth login` |
| `script-branch-protection.sh` prints `NO_REMOTE` | No git remote configured | `git remote add origin <url>` |
| `/msg --init-staging` stops immediately | No `devkit/policy.json` — repo was never bootstrapped | `/msg --init` first |
| Coding standards never load | cook isn't installed | `curl -fsSL https://raw.githubusercontent.com/ndisisnd/cook/main/install.sh \| bash` |
| The same harness glitch keeps happening | Skills log harness incidents to `devkit/DOCTOR.md` | `/msg --doctor` — it reports which problems have recurred enough to be worth fixing (it never fixes them itself) |
| `devkit/AHA.md` has grown long and noisy | Agents append a learning every time one surfaces | `/msg --aha` — sweeps the ledger, merges repeats, prunes noise, and flags recurring lessons to fix at the source (its only write is the ledger itself) |
| A repo set up before v5 is missing a devkit file | Components added after it was bootstrapped | `/msg --update` — additive, preview-gated, and it also adds the `devkit/DOCTOR.md` line to `.gitignore` |

---

## Appendix C · Running under Codex CLI

Everything above works the same under OpenAI Codex CLI, with three differences worth knowing before you start.

### C1 · Invoke skills with `$`, not `/`

`$msg`, `$intake`, `$eng` — or pick one from the `/skills` list. Codex can normally start a skill on its own when your wording matches its description; msg switches that off for every skill, because these are commands with consequences. Nothing happens until you type the name. That is the intended behaviour, not a failed install.

If `$msg` isn't found at all, msg was installed for Claude Code only. Re-run the installer with `--codex` and check `ls -l ~/.agents/skills`.

### C2 · The commit gate needs your trust, and silence means it is off

This is the one thing that can quietly cost you something.

msg wires a hook that blocks a commit until the staged change is written up in `CHANGELOG.md`. Codex trust-gates hooks: until you approve this project's `.codex/` layer, the hook **does not run and does not warn you that it didn't**. An untrusted gate and a live gate look identical from the outside — right up to the release that ships with no changelog entry.

**Granting trust.** Codex asks when it first meets the project's `.codex/` layer; approve it there. The `/hooks` view inside a Codex session is where the hooks it knows about and their trust state can be reviewed.

**Trust is per content hash, so it expires on edit.** Any change to `.codex/hooks.json` — yours, a teammate's, or a future `/msg --update` — produces a new hash and drops the old approval. Re-approve after every edit. This is also why `/msg --init` never overwrites an existing `hooks.json`: silently rewriting it would revoke your trust and stop the gate.

**Verify the gate rather than assuming it.** Run a command that *looks* like a commit but does nothing:

```bash
git status --short          # confirm CHANGELOG.md is NOT staged first
true  # git commit probe
```

A live gate blocks the second command and tells you to update `CHANGELOG.md`. A dead gate lets it through silently.

The first line matters. The gate's whole job is to allow a commit once the changelog is staged, so if `CHANGELOG.md` happens to be staged already, a live gate allows the probe too and you learn nothing. Unstage it first, or treat the result as inconclusive and say so — never read a pass in that state as "gate live".

One more reason to check: if no gate script is installed anywhere, the wiring exits quietly rather than blocking every command you run. Failing open is deliberate, but it means "not installed" and "not trusted" also look alike.

### C3 · Reloading after msg changes

Skills are read when a session starts. Edit a skill, update msg, or install a new one, and the session you're in carries on with what it already loaded — start a new Codex session, the same way you'd fully restart Claude Code.

Updating msg itself needs no Codex-side step: `~/.agents/skills` holds links, not copies, so a re-run of the installer updates both harnesses at once. The exception is a skill that is genuinely new — a link for it only appears when you re-run the installer with `--codex`.

### What doesn't change

Every path msg uses is identical on both harnesses: skills stay under `~/.claude/skills`, scripts under `~/.claude/scripts`, per-project state under `.claude/msg/`. Under Codex, `.claude/` is simply a directory msg owns — the name is history, not a dependency. And the human gates are untouched: staging sign-off, the production double-confirm, the rollback offer and the pause before touching a database all still stop and wait for you. The one consequence is that non-interactive `codex exec` runs cannot drive the human-gated skills — with no way to ask, they refuse rather than assume. Run them in an interactive session.

---

**Next:** [README.md](README.md) for the full skill surface · [ARCHITECTURE.md](ARCHITECTURE.md) for how the layers fit together · [RELEASES.md](RELEASES.md) for what each release changed for you.
