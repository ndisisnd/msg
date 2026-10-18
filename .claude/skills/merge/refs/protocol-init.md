---
name: merge-setup
description: merge setup (runs inline on the first /merge run, then the merge step continues) and /merge --update — detect ship capability + policy (release-flow topology, branch protection, deploy/smoke CLIs, PLATFORMS.md gaps, staging readiness, risky paths, CI wait limit), ask the real gaps in batches, install OSS-first, and complete devkit/policy.json. Never merges, deploys, opens PRs, or writes PLATFORMS.md.
type: reference
---

# merge setup (first run) and `/merge --update`

Setup is **not a ship**. Merge's tooling is less about test runners and more about
**ship capability + policy**: can this repo merge, protect its branches, deploy, and
smoke-verify — and what release flow does it follow. Setup **detects** each,
**asks** the user about the real gaps, **offers OSS-first installs** (gated, per-item),
and **completes `devkit/policy.json`**. Setup itself merges nothing, opens no PR,
deploys nothing, runs no smoke, and never writes `devkit/PLATFORMS.md`.

## When it runs

| Trigger | What happens |
|---|---|
| **First run** — `devkit/policy.json` has no `policies.merge` record (`MERGE_RISKY_PATHS_STATE=absent`), or `init: false` | setup runs **inline**, saves `devkit/policy.json`, then the run **continues** into the merge step the user asked for (`--staging` / `--production` / bare `/merge`) in the same run. The user aborts setup ⇒ stop; no merge step runs on a half-configured repo |
| `devkit/policy.json` **absent** | run `/msg --init` first (it seeds the file and owns `release_flow`), then setup, then the merge step |
| `/merge --update` | re-run every detection item, show the changes, ask **one** approval, save, and **end** — no merge step follows |

The trigger is `policies.merge`, not `init`: pre-merge setup also flips `init:true`, so
`init` alone cannot say whether *merge's* half was ever set up.

Follow the **Shared setup contract** (prereqs → load/seed policy → detect → interview
→ offer install → write → summary — the same seven-step contract both gates run,
spelled out in `../../pre-merge/refs/protocol-init.md` § *Shared setup contract*).
This ref covers the **merge-specific detection**. The policy file's schema, status
vocabulary, validation rules, and gate read-contract are defined once in
[`../../shared/refs/policy-schema.md`](../../shared/refs/policy-schema.md) — **cite it, do
not restate it here**.

**Questions — in batches, gaps only.** Up to **4** related questions per
`AskUserQuestion` prompt, each with the recommended default as its first option. A
question detection already answered is **not asked**. Every answer is recorded, so the
next run does not re-ask.

## Prerequisite: `gh` installed + authenticated

Items 2, 7 and the PR step all lean on `gh`. If absent, offer `brew install jq gh` and
prompt `gh auth login`; without a git remote, note that protection/PR steps are inert.
Record `gh` presence so the coverage map below is honest (a `◐` step that has no `gh` is
dead).

## The eight detection items

### 1 · Release flow (branch topology) — read and report only

`release_flow` has **one writer: `/msg --init`** (`/msg --init-staging` flips it to
`staged`). Setup and `--update` **read** it and **report** a mismatch; they never write
it.

```bash
git show-ref --verify --quiet refs/heads/staging   # or gh api on the remote
```

| Recorded flow | Topology | Report |
|---|---|---|
| `staged` | staging **present** | — (matches) |
| `direct` | staging **absent** | — (matches) |
| `direct` | staging **present** | "A staging branch exists but the flow is `direct`. Run **`/msg --init-staging`** to switch to the staged flow." |
| `staged` (recorded or default) | staging **absent** | "The flow is `staged` but no staging branch exists. Run **`/msg --init-staging`** to create it, or re-run **`/msg --init`** to record the direct flow." |

Setup **never creates the branch** — that is `/msg --init-staging`'s job alone.

**A branch is not a ready staging environment.** Detecting `staging` present is only the
*topology* half. Under `staged`, item 6 runs the per-platform **staging-readiness**
detection; branch-exists is never treated as "staging ready".

### 2 · Branch protection → `branch_protection`

Run `script-branch-protection.sh --verify <branch>` per relevant branch and read the
environment (resolution form: `sanctioned-writes.md`):

```bash
S=.claude/scripts/script-branch-protection.sh; bash "$S" --verify <branch>
```

| `--verify` output | setup action |
|---|---|
| `NO_GH` (exit 2) | offer to install `gh` + prompt `gh auth login`; can't probe protection until then |
| `NO_REMOTE` (exit 2) | record `branch_protection.mode:"skip"` — nothing to protect |
| `UNPROTECTED <b> <missing>` (exit 1), protection **available** | offer `script-branch-protection.sh --bootstrap` (gated, per-item); decline → record `optional` or `skip` with a `reason` |
| `PROTECTED <b>` (exit 0) | record `enforced` for that branch |
| private repo + protection API `403` upgrade-required | **auto-detect Free-plan limitation** — see below |

**Free-plan 403 auto-detect.** A private repo on GitHub Free cannot set branch
protection; the API returns `403` upgrade-required. Setup pre-fills
`branch_protection.mode:"optional"` (with a `reason` like *"private repo on GitHub Free —
branch-protection API unavailable"*) and records `repo.branch_protection_available:false`
+ `repo.detected_via`. It **requires an explicit confirm** via `AskUserQuestion` before
writing `optional` — the relaxation is never silent.

**Per-branch `overrides`.** Different branches may take different stances — e.g. `main`
`enforced` while `staging` stays `optional`. Record these under
`branch_protection.overrides` (`overrides[b] ?? mode`, per `policy-schema.md`
§`branch_protection`). The full read-contract that turns these modes into refuse /
warn-proceed / skip at merge time lives in `policy-schema-merge.md` §2; setup only
*records* the stance.

**Phantom-check guard — a workflow must exist first.** Requiring "green CI" via protection is
meaningless if no CI pipeline produces any status check. Before offering `--bootstrap`, resolve
whether a gate workflow exists — read `steps.ci` from `policy.json` (written by
pre-merge setup), or probe directly:

```bash
grep -lE 'pull_request' .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null
```

No workflow (`steps.ci` is `missing`/absent and the probe is empty) → **do not offer to enforce
required checks**; then branch on `ga = policies.github_actions.enabled ?? true`
(`../../shared/refs/policy-schema.md` §2b):

- `ga:false` — the absent workflow is the user's **decision**, not a gap. Say nothing about
  `/pre-merge --update`, record no gap, and **still offer `--bootstrap`**: protection is bootstrapped
  with `required_status_checks {strict:true, contexts:[]}`, which is meaningful without any CI
  (linear history, no force-push, review required). Note once in the run output that Actions is
  disabled by policy and `/msg --update` changes it.
- `ga:true`/absent — unchanged: note the gap and point the user at **`/pre-merge --update`**, which
  owns the `ci` step and scaffolds the pipeline.

Merge setup **never writes `steps.ci`** and **never scaffolds a workflow** — it only reads the
record so it doesn't bootstrap protection around checks nothing emits (the workflow is
pre-merge's to create, as PLATFORMS.md is `/msg --init`'s).

### 3 · Deploy CLIs

Parse `devkit/PLATFORMS.md` deploy commands (the `staging_deploy_cmd` /
`production_deploy_cmd` columns, per `refs/deploy.md`), extract the **leading binary** of
each command, and probe it:

```bash
command -v <bin>        # flyctl, vercel, netlify, wrangler, eas, gh, fastlane, …
```

Offer install for the ones missing. The deploy **target** may be a paid host, but the
**CLIs are free** — install those; **never sign the user up for anything**. A
step whose only real option is paid is recorded `deferred`/`opted_out` with the paid tool
named in `reason` — never installed. Records land under `steps.deploy_staging` /
`steps.deploy_production`.

### 4 · Smoke command binary

For each shipping platform's `smoke_cmd` (per `refs/verify-deploy.md`), check the binary
it invokes (`curl`, `playwright`, …) is present via `command -v`. Flag a
declared-but-unverified smoke command as `steps.smoke.status:"missing"` (with a `reason`
like *"declared in PLATFORMS.md, never verified"*). Missing binary → offer the OSS-first
install; installed → persist as `ready`.

### 5 · PLATFORMS.md declaration gaps → delegate, never write

Empty or `[USER: …]` placeholder deploy / smoke cells mean `/msg --init` never
filled them in. Setup **reports** these gaps and **delegates to `/msg --init`** — it
**does not write `devkit/PLATFORMS.md`**. PLATFORMS.md command declarations stay owned by
`/msg --init`; merge setup is read-only to that file. Platforms added or removed since the
last setup are reported here too, and item 6 re-derives their staging readiness.

### 6 · Staging readiness (per shipping platform) → `staging_ready`

**Only under `release_flow=staged`.** In `direct` flow the staging-scoped stages
are **inactive because they do not apply** (there is nothing to deploy, test, or
sign off) — this whole detection is inactive, not skipped and not relaxed
(`../../shared/refs/policy-schema-merge.md` §1b, three-state vocabulary). Write **no**
`staging_ready` record in `direct`.

"Staging ready" too often means "the branch exists" — a false promise discovered at
deploy time. Setup moves that failure left: for each shipping platform in
`devkit/PLATFORMS.md`, verify the **declared** staging artifacts are present and
non-placeholder (**declared-artifact checks only**; no stack-specific probing, no
network pings, no store-CLI queries, no credentials).

Resolve each platform's `release_model` first (from the PLATFORMS.md column, else
inferred from platform identity with a warn — a macOS row must **declare** it,
since direct download and the Mac App Store are different models; `../../shared/refs/policy-schema-merge.md` §4). What "ready" means is
model-shaped:

| `release_model` | Ready when the row declares… | Checked (declared-artifact only) |
|---|---|---|
| `deploy` (web, server, directly-distributed macOS) | a non-placeholder `staging_deploy_cmd` **and** target; **and** if `staging_config` names a file, that file exists on disk; macOS additionally names a **staging channel/target** in the cmd | `staging_deploy_cmd` ≠ blank/`[USER: …]`; declared `staging_config` path present via `[ -f <path> ]` |
| `submission` (iOS, Android, Mac App Store macOS) | a non-placeholder `staging_deploy_cmd` that **names an internal / TestFlight track** (e.g. `fastlane beta` (TestFlight, iOS or macOS), `./gradlew publishStaging` (internal track)) | `staging_deploy_cmd` ≠ blank/`[USER: …]` and the track is named in the cell |

A cell is a **placeholder** (⇒ not declared / not ready) when it is empty or a
`[USER: …]` stub. A `staging_config` cell that is blank/`[USER: …]` means *no
config file is declared* — that platform simply has no config-file check (many
need none); only a **real path** that is **missing on disk** is a gap.

**Report per platform** — `ready` or a `gaps[]` list; each gap names the **exact
missing artifact and the exact fix**, e.g.:

- *web* — `no `.env.staging` on disk (declared in `staging_config`) and
  `staging_deploy_cmd` is a `[USER: …]` placeholder — fill both in
  `devkit/PLATFORMS.md`, then run `/merge --update`.*
- *ios* — `staging_deploy_cmd` is a `[USER: …]` placeholder — set it to your
  internal/TestFlight track deploy (e.g. `fastlane beta`), then run
  `/merge --update`.*

**Persist** the result to `policy.json` as the `staging_ready` record
(`../../shared/refs/policy-schema-merge.md` §5) — a resolved **fact**, re-derived on every
setup and `--update`, that `--staging` reads to guard the ship.

### 7 · Risky paths → `policies.merge.risky_paths`

The list of paths that make a change **risky** — merge's PR step reads it to decide
whether new commits since pre-merge's pass are a small change (`refs/open-pr.md` § *Pass
check*). **Always present** after setup. Scripted:

```bash
S=.claude/scripts/script-merge-checks.py
python3 "$S" seed --scope <scope> [<scope>…]   # RISKY_PATHS_JSON (catalog seed); e.g. --scope web python
python3 "$S" libs --all                                     # FOUND_PATHS / NEW_RISKY_PATHS
```

- **Seed** (first run only) — the catalog's `force_full_paths` rows (universal + each
  detected scope) plus `**/auth/**`, `**/payments/**`, `.github/workflows/**`
  (`../../shared/refs/component-catalog.md` § *Risky libraries*).
- **Library search** — finds the real auth and payment folders **by library use, not by
  folder name** (next-auth, @clerk, passport, supabase.auth, jsonwebtoken, bcrypt;
  stripe, @paddle, braintree, StoreKit, Play Billing — the list lives in the catalog).
  Each hit folder is added.
- **No question.** The summary shows the list, marking the folders the search added.
- **Never remove a path.** A path the user added by hand stays, on every run and in
  `--update`.

### 8 · CI wait limit → `policies.merge.ci_wait_minutes`

How long merge waits for CI on the PR before it stops (`refs/open-pr.md` § *CI wait*).
Default **30 minutes**; setup measures recent GitHub Actions run times and sets the
limit above them. No flag and no question:

```bash
S=.claude/scripts/script-merge-checks.py; python3 "$S" ci-limit   # CI_LIMIT_MINUTES
```

`CI_LIMIT_MINUTES` = max(30, slowest of the last 20 completed runs × 1.5, rounded up
to 5). No runs, no `gh`, or `github_actions.enabled:false` ⇒ 30.

## `/merge --update` — reconcile settings with the repo

Same detection, run against a repo that already has `policies.merge`. Asks only about
real gaps (the same batches as setup). It **never merges, opens a PR, or deploys**.

| Item | `--update` does |
|---|---|
| (a) release flow (item 1) | **read and report only** — a staging branch added or removed is reported with the owning command; never written |
| (b) branch protection (item 2) | re-verify each branch; a changed state is a proposed change; user-set modes and `reason`s are kept |
| (c) deploy tools + smoke command (items 3–4) | re-probe; a newly missing or newly present binary is a proposed change |
| (d) platforms + staging readiness (items 5–6) | report platforms added or removed; re-derive `staging_ready` |
| (e) risky paths (item 7) | re-run `libs --all` on the whole codebase; add new folders; **never** remove a user-added path |
| (f) CI wait limit (item 8) | re-measure; propose the new limit |

**One approval.** Show every proposed change as one list (`<key>: <old> → <new>`, one line
each), then ask once — `AskUserQuestion`, header **Update**, "Save these changes to
devkit/policy.json?" — **Save** / **Cancel**. Nothing changed ⇒ say so and save nothing.
Cancel ⇒ nothing is written.

## Step-coverage map

Setup reaches three clusters (branch protection, deploy, smoke) plus the cross-cutting
`gh` prerequisite, and — under `staged` flow — records the per-platform
**staging-readiness** fact (item 6) that `--staging`'s guard reads. Items 7–8 feed the
PR step. The rest are pure logic / content / human gates with nothing to set up.

**Legend:** ✅ covered · ◐ indirect (via the `gh` prerequisite only) · ➖ not covered.

| Mode | Step | | setup's role |
|---|---|---|---|
| `--staging` | 1 · Branch protection | ✅ | policy + `--bootstrap` offer (guarded on a `ci` workflow existing) + `gh` install |
| | 2 · Open the PR + wait for CI | ✅ | `risky_paths` + `ci_wait_minutes` (items 7–8); `gh` present + authed; reads `github_actions` then `steps.ci` to flag a vacuous (zero-check) pass |
| | 3 · Merge into staging | ◐ | `gh` + protection |
| | 4 · Deploy staging | ✅ | deploy-CLI detect/install; PLATFORMS.md gaps → `/msg --init` |
| | 5 · Verify deploy (smoke) | ✅ | `smoke_cmd` binary present; flag declared-but-unverified |
| | 6 · Human test script | ➖ | derived from PRD report — no tooling |
| | 7 · Sign-off stamp | ➖ | writes PRD frontmatter — no tooling |
| `--production` | 1 · Preconditions | ◐ | CI status via `gh`; signoff is file state |
| | 2 · Branch protection (main) | ✅ | as staging #1, for `main` |
| | 3 · Confirmation | ➖ | pure human gate |
| | — · Release lock | ➖ | git tag on the remote — no setup tooling (`gh`/remote covered above) |
| | 4 · Open release PR | ✅ | `gh`; direct flow also uses items 7–8 |
| | 5 · Merge on green CI + review | ◐ | `gh` + protection |
| | 6 · Production deploy | ✅ | deploy-CLI detect/install |
| | 7 · Verify deploy (smoke) | ✅ | `smoke_cmd` binary present |
| | 8 · Intake stamp | ➖ | writes INTAKE.md — no tooling |
| | 9 · Tag the release | ➖ | `git tag` + push on prod — no setup tooling |
| | 10 · PRD lane → `done` | ➖ | frontmatter stamp + a folder move — no tooling |

## What setup writes

Setup completes `devkit/policy.json` (never PLATFORMS.md) through
`.claude/scripts/script-policy-set.py`, as its **last** write:

- `steps.deploy_staging` / `steps.deploy_production` — deploy-CLI readiness (item 3).
- `steps.smoke` — smoke-binary readiness (item 4).
- `policies.branch_protection` — mode + `reason` + `overrides` (item 2).
- `staging_ready` — per-platform staging-readiness fact (item 6; **`staged` flow
  only** — omitted in `direct`).
- `policies.merge.risky_paths` + `policies.merge.ci_wait_minutes` (items 7–8).
- `--set init=true`, `--stamp-by "merge setup"` on the first run (`"merge --update"` on
  an update) — stamps `generated` + `generated_by`.

The written file must pass its own validation and re-load with **zero** warnings. Schema,
status vocabulary (`ready`/`opted_out`/`n/a`/`missing`/`deferred` — no `installed`), and
the full field spec are authoritative in `policy-schema-merge.md`; do not duplicate them
here.

## Never

- Never merge, open a PR, deploy, or run a smoke check during setup or `--update`.
- Never write `policies.release_flow` — `/msg --init` owns it; report a mismatch with the owning command.
- Never write `devkit/PLATFORMS.md` — report gaps and delegate to `/msg --init`.
- Never write `steps.ci` or scaffold a `.github/workflows/` pipeline — that's pre-merge setup's; only *read* `steps.ci` to guard the protection offer.
- Never write `policies.github_actions` — that decision belongs to `/msg --init` / `/msg --update`; only *read* it. If the user asks to change it here, name `/msg --update` rather than writing the key.
- Never create a staging branch — offer `/msg --init-staging`, which owns branch creation.
- Never remove a path from `policies.merge.risky_paths`.
- Never install a paid/SaaS tool or sign the user up for a host — record `deferred`/`opted_out` with the paid tool named.
- Never write `optional` on a Free-plan 403 without an explicit confirm.
