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

New here? [QUICKSTART.md](./QUICKSTART.md) walks from install to your first shipped feature, with a verify check at every step.

## 🗂️ Skills

Run `/msg` to browse these interactively, or invoke any skill directly. `/msg --gui` opens a local, Notion-style PRD board (Kanban/table, light + dark) where you can edit PRDs, drag statuses, tick off todos, work the `INTAKE.md` backlog on an Intake tab (grade chips, lane drag), browse project docs, read run reports, and run Claude prompts — served on `127.0.0.1` only.

**Run reports.** `eng --build`, `/pre-merge`, and `/merge` each end a run by writing `report-[n].md` into the PRD's `features/prd-[n]/reports/` folder (`features/reports/` when no PRD applies) — a plain-language record of the work done (features, code changes, lines added/deleted, tests passed/failed) plus what you can expect and the exact steps to verify the feature works. Merge's staging report carries the human test script; its production report renders release-style — the version it tagged, each platform's outcome per its release model (`live`, or `submitted` + where to monitor), any rollback offered, and any no-rollback platform flagged `IRREVERSIBLE`. The board renders them under a dedicated **Reports** tab, grouped by PRD. Schema: `.claude/skills/shared/refs/report-schema.md`.

**Closing message.** Every pipeline skill run ends with a closing message telling you exactly where you stand and what to do next: a 🟢 Success! / 🟡 Warning! / 🔴 Fail! headline, a one-line plain-language summary, a short table of what happened, and a **Next steps** list of concrete actions (e.g. "Run `/pre-merge` now") drawn from a fixed registry — same shape whether the run passed, needs your call, or stopped on a blocker. Contract: `.claude/skills/shared/refs/closing-message.md`.

**Safety floor.** The safety floor is **never relaxed**: write powers are scoped per skill (eng commits to feature branches only; pre-merge opens exactly one feature→staging PR and never merges; merge is the only merger, and nothing reaches `main` except via its double-confirmed staging→main release), and the human gates (staging sign-off — pinned to the commit you tested, the inline human-test when shipping without staging, the always-ask rollback offer, production double-confirm) never disappear. `/merge --production` guards `main` behind branch protection (green CI + human review). See ARCHITECTURE.md § Safety floor.

### 📐 Plan

| Skill | Description |
|-------|-------------|
| `/msg --init` | One-time project bootstrap — batched interview (project basics, architecture, design system, **release flow**), then scaffolds `devkit/` (AHA.md, ARCHITECTURE.md, DESIGN-SYSTEM.md, DOCTOR.md, ENV.md, GLOSSARY.md, OPEN-QUESTIONS.md, PLATFORMS.md), seeds `devkit/policy.json` (`init:false` + release flow), the root `INTAKE.md` backlog ledger, `roadmap/TEMPLATE-roadmap.md`, and root files. Idempotent. |
| `/msg --update` | Re-scans an already-bootstrapped repo for components added since it was set up — missing `devkit/` files, template rows added later (e.g. the `devkit/DOCTOR.md` ignore line), and PRD folders not yet sorted into a lane. Additive and preview-gated; never rewrites an existing line. |
| `/msg --init-staging` | Adds a `staging` branch to a direct-flow repo (branches off prod, offers branch protection) and flips `devkit/policy.json` release flow to `staged`. The only mode that creates a staging branch. |
| `/msg --doctor` | Reads `devkit/DOCTOR.md` — the local ledger where every skill records a **harness incident** (a script that failed, a write that did not land, a validator that misfired). It reports which problems have recurred often enough to be worth fixing and never fixes anything itself, so a broken harness is visible instead of quietly absorbed. The ledger is gitignored: it is about your machine, not your product. |
| `/intake` | The planning front door — captures feature ideas and bugs as graded rows in the root `INTAKE.md` ledger. Owns the requirements interview: fleshes out thin ideas, suggests adjacent ones, splits compound/hybrid asks and XL ideas into discrete rows, and grades each in a single-turn banded judgment (complexity `C:` / token-cost `T:` / sequencing `S:` — bands only, never fake-precise numbers). Feeds `plan-pm`. |
| `/intake --delete` | Removes a row from the backlog — the only destructive intake mode. Runs a warning pass first (a PRD it would orphan, other rows graded `S:blocked-by-#n` against it, a `completed` ship record, log history), then requires an explicit confirm. **Never renumbers** — the `#` gap stays, because renumbering would silently repoint every `blocked-by` reference. Deletes ledger rows only, never a PRD folder or file. |
| `/intake --update` | Edits a row already in the backlog. Lists every un-shipped row in full, then changes the one you pick — `idea` / `goal` / `type` on `backlog` rows only (`in-progress` rows belong to their PRD; use `/plan-review`). A **material** change re-runs the grading rubric and the same hybrid/`≥8` split gates as capture; a cosmetic one keeps the grade. Every edit lands in `INTAKE-UPDATE.md`, a sibling file to `INTAKE.md`. Never writes `status` or `prd`. |
| `/plan-pm` | Principal PM — the **autonomous PRD writer**. Consumes a graded intake row and drafts the full PRD solo (edge cases, feature/acceptance table, user flows, error handling) to `features/prd-[n]/`, pausing only for batched open questions and breaking/critical touches. Stamps the intake row `in-progress` + its `prd` mapping. |
| `/plan-review` | Staff PM **contract certifier** — runs a fixed seven-check certification (`--product`: checks 1/2/3/6; `--eng`: 2/4/5/6/7), each tied to a named downstream consumer ("no check without a consumer"). Auto-selects the tune type, auto-fixes every Critical + Major with a terminal `# \| Sev \| Found \| Fixed` table, asks once about Minors, pauses only on a product-decision finding. Each auto-fix writes a category-tagged learning to `devkit/AHA.md` so the next `plan-pm` draft self-heals. |
| `/plan-em` | Engineering Manager — auto-runs `plan-review` certification before each wave (product before plan, eng before build; roster approval is the single human gate), spins up specialist agents to write engineering sections into the PRD, then synthesises the output. Runs `--team` by default (an Opus orchestrator engineer decomposes each wave into file-disjoint, model-tiered packets — Opus for load-bearing work, Sonnet for mechanical — fanned out to leaf `eng` subagents to maximise parallelism) or `--solo` (one leaf subagent per roster stack). |

### 🔨 Build

| Skill | Description |
|-------|-------------|
| `/eng` | Platform-agnostic engineering agent — `--plan` proposes file changes for approval **and** writes the per-feature todo tickets in the same pass, `--build` writes code from the todos (falling back to exec-table rows) and spawns the reviewer before the commit confirm, `--review` runs one adversarial whole-change review of the working diff as a separate subagent (also available standalone on any branch). Every build pauses for sign-off before it commits, and again on any database, data, or production-config touch. |
| `/pre-merge` | The CI gate — takes a feature branch from "eng says done" to "PR open against staging". Runs a **preflight-driven pipeline executor** over the `components[]` manifest in `devkit/policy.json`: it prunes to the components this project actually has, topo-sorts them on their dependencies, and runs independent components as parallel waves — sync → parallel correctness + security waves (with **`smoke`** first inside the ephemeral test sandbox) → coverage → regression tail → opens PR feature→staging. Pre-merge holds **no human gate**: the human look at a running build belongs to `/merge` (the staging sign-off, or the direct-flow attestation when there is no staging branch), so a feature is never human-tested twice for the same content. `smoke` is the machine stand-in — a default-liveness check plus the project's critical-path golden flows, run first so a dead build short-circuits the expensive checks; it emits a significance-rated manual-test-plan checklist that merge's staging walk-through renders. With **no manifest** it refuses `no_manifest` and points you at `/pre-merge --init`. Opt in to **minified test selection** (`policies.test_selection`) and `unit`/`integration`/`regression` narrow to *affected(diff) ∪ critical-floor* instead of the whole suite, sized by an S/M/L tier rubric measured from the diff's actual blast radius (never the PRD's prose) — any resolution failure fails open to the full suite, and the full suite still runs somewhere (a declared CI and/or merge backstop). Per-run `--minified`/`--full` override the policy for one run; `--update-criticality` keeps the critical-tag floor current as your test suite drifts. Absorbs the old `/review` and `/test`; emits a severity-graded JSON verdict. `--init` detects the pipeline — including whether a `.github/workflows/` pipeline runs the gate on PRs — offers to install/scaffold the missing (free/OSS) pieces, and writes the manifest; `--update` reconciles it as the code drifts. |
| `/merge` | The ship gate — the only skill that merges. Every shipping platform carries a `release_model` (`deploy` vs `submission`, inferred with a warn if undeclared): `deploy` platforms (web, macOS) verify live via smoke; `submission` platforms (iOS, Android) never report `live` — a deploy is `submitted` + track, verified as submission-accepted + backend/build-health smoke, with an explicit monitor-handoff. `--staging` verifies green CI, merges the feature→staging PR, deploys + verifies staging per that model, emits a human test script, and stamps `staging-signoff: <date>@<sha>` on approval — **pinned to the commit the human actually tested**, so `--production` refuses (`stale_signoff`) if anything landed on staging afterwards. `--production` resolves **release identity** first (the next version + build off the last `v*` tag on prod — read-only, threaded through the confirm and release PR), double-confirms, opens the release PR staging→main (rollback notes per platform; iOS `IRREVERSIBLE`), acquires a **release lock** so a second concurrent `--production` refuses `release_in_flight`, merges on green CI + human review, deploys + verifies per `release_model` (checking provenance against the signed-off sha), and on success tags `v<x.y.z>+<build>`. Any deploy/smoke failure **offers an executable rollback or rollout-halt** (always-ask, never auto) before the fix loop. Branch protection (`script-branch-protection.sh`) is the machine enforcement — **policy-conditional** (`enforced`/`optional`/`skip` per `devkit/policy.json`, so private Free repos that can't set protection aren't blocked). `--init` sets up protection/deploy tooling + the release flow and verifies staging is actually ready per platform. Ship gates never collapse. |

---

Credits to my dear JC who previously had her own harness with a bajillion agents. Great times.