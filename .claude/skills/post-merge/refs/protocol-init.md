---
name: post-merge-init
description: post-merge --init spec — detect ship capability + policy (release-flow topology, branch protection, deploy/smoke CLIs, PLATFORMS.md gaps), interview per gap, install OSS-first, and complete devkit/policy.json. Never merges, deploys, opens PRs, or writes PLATFORMS.md.
type: reference
---

# `/post-merge --init` — ship-capability + policy setup

`--init` is a **setup mode**, not a ship. Post-merge's tooling is less about test
runners and more about **ship capability + policy**: can this repo merge, protect its
branches, deploy, and smoke-verify — and what release flow does it follow. `--init`
**detects** each, **interviews** the user per gap, **offers OSS-first installs** (gated,
per-item), and **completes `devkit/policy.json`**. It runs no protocol step: no merge, no
PR, no deploy, no smoke, and it never writes `devkit/PLATFORMS.md`.

Follow the **Shared `--init` contract** (prereqs → load/seed policy → detect → interview
→ offer install → write → summary — the same seven-step contract both gates run,
spelled out in `../../pre-merge/refs/protocol-init.md` § *Shared `--init` contract*).
This ref covers the
**post-merge-specific detection**. The policy file's schema, status vocabulary, validation
rules, and gate read-contract are defined once in
[`../../shared/refs/policy-schema.md`](../../shared/refs/policy-schema.md) — **cite it, do
not restate it here**.

## Prerequisite: `gh` installed + authenticated

Steps 1–5 all lean on `gh`. If absent, offer `brew install jq gh` and prompt
`gh auth login`; without a git remote, note that protection/PR steps are inert. Record
`gh` presence so the coverage map below is honest (a `◐` step that has no `gh` is dead).

## The six detection items

### 1 · Release flow (branch topology) → `release_flow`

Detect whether a staging branch exists:

```bash
git show-ref --verify --quiet refs/heads/staging   # or gh api on the remote
```

| Topology | `--init` proposes | Offer |
|---|---|---|
| staging **present** | `release_flow.mode:"staged"` (`staging_branch:"staging"`, `prod_branch:<default branch>`) | — |
| staging **absent** | `release_flow.mode:"direct"` (`staging_branch:null`, `prod_branch:<default branch>`) | **`/msg --init-staging`** to add the staging stage |

`--init` **records the choice**; it **never creates the branch** — that is
`/msg --init-staging`'s job alone. See `policy-schema.md`
§`policies.release_flow`.

**Design-accepted:** `/msg --init-staging` that flips the flow to `staged`
**without a follow-up `/post-merge --init`** leaves **no `staging_ready` record** —
`--staging` then takes the **absent-record warn-and-proceed path** (`refs/staging.md`,
never a refusal). The mitigation is the handoff: `/msg --init-staging` hands off to
`/post-merge --init` to derive readiness, and the warn note names it.

**A branch is not a ready staging environment.** Detecting `staging` present is
only the *topology* half — it says the flow is `staged`, not that the environment
each platform deploys into actually exists. Under `staged`, item 6 below runs the
per-platform **staging-readiness** detection; branch-exists is never treated as
"staging ready".

### 2 · Branch protection → `branch_protection`

Run `post-merge-protection.sh --verify <branch>` per relevant branch and read the
environment (resolution form: `../SKILL.md` § *Sanctioned writes*):

```bash
S=.claude/scripts/post-merge-protection.sh; bash "$S" --verify <branch>
```

| `--verify` output | `--init` action |
|---|---|
| `NO_GH` (exit 2) | offer to install `gh` + prompt `gh auth login`; can't probe protection until then |
| `NO_REMOTE` (exit 2) | record `branch_protection.mode:"skip"` — nothing to protect |
| `UNPROTECTED <b> <missing>` (exit 1), protection **available** | offer `post-merge-protection.sh --bootstrap` (gated, per-item); decline → record `optional` or `skip` with a `reason` |
| `PROTECTED <b>` (exit 0) | record `enforced` for that branch |
| private repo + protection API `403` upgrade-required | **auto-detect Free-plan limitation** — see below |

**Free-plan 403 auto-detect.** A private repo on GitHub Free cannot set branch
protection; the API returns `403` upgrade-required. `--init` pre-fills
`branch_protection.mode:"optional"` (with a `reason` like *"private repo on GitHub Free —
branch-protection API unavailable"*) and records `repo.branch_protection_available:false`
+ `repo.detected_via`. It **requires an explicit confirm** via `AskUserQuestion` before
writing `optional` — the relaxation is never silent.

**Per-branch `overrides`.** Different branches may take different stances — e.g. `main`
`enforced` while `staging` stays `optional`. Record these under
`branch_protection.overrides` (`overrides[b] ?? mode`, per `policy-schema.md`
§`branch_protection`). The full read-contract that turns
these modes into refuse / warn-proceed / skip at merge time lives in `policy-schema-post-merge.md`
§2; `--init` only *records* the stance.

**Phantom-check guard — a workflow must exist first.** Requiring "green CI" via protection is
meaningless if no CI pipeline produces any status check. Before offering `--bootstrap`, resolve
whether a gate workflow exists — read `steps.ci` from `policy.json` (written by
`pre-merge --init`), or probe directly:

```bash
grep -lE 'pull_request' .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null
```

No workflow (`steps.ci` is `missing`/absent and the probe is empty) → **do not offer to enforce
required checks**; then branch on `ga = policies.github_actions.enabled ?? true`
(`../../shared/refs/policy-schema.md` §2b):

- `ga:false` — the absent workflow is the user's **decision**, not a gap. Say nothing about
  `/pre-merge --init`, record no gap, and **still offer `--bootstrap`**: protection is bootstrapped
  with `required_status_checks {strict:true, contexts:[]}`, which is meaningful without any CI
  (linear history, no force-push, review required). Note once in the run output that Actions is
  disabled by policy and `/msg --update` changes it.
- `ga:true`/absent — unchanged: note the gap and point the user at **`/pre-merge --init`**, which
  owns the `ci` step and scaffolds the pipeline.
 Post-merge `--init` **never writes `steps.ci`** and **never
scaffolds a workflow** — it only reads the record so it doesn't bootstrap protection around checks
nothing emits (the workflow is pre-merge's to create, as PLATFORMS.md is
`/msg --init`'s).

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
filled them in. `--init` **reports** these gaps and **delegates to `/msg --init`** — it
**does not write `devkit/PLATFORMS.md`**. PLATFORMS.md command
declarations stay owned by `/msg --init`; post-merge `--init` is read-only to that file.

### 6 · Staging readiness (per shipping platform) → `staging_ready`

**Only under `release_flow=staged`.** In `direct` flow the staging-scoped stages
are **inactive because they do not apply** (there is nothing to deploy, test, or
sign off) — this whole detection is inactive, not skipped and not relaxed
(`../SKILL.md` § *Release flow*, three-state vocabulary). Write **no**
`staging_ready` record in `direct`.

Today "staging ready" too often means "the branch exists" — a false promise
discovered at deploy time. `--init` moves that failure left: for each shipping
platform in `devkit/PLATFORMS.md`, verify the **declared** staging artifacts are
present and non-placeholder (**declared-artifact checks only**; no
stack-specific probing, no network pings, no store-CLI queries, no credentials).

Resolve each platform's `release_model` first (from the PLATFORMS.md column, else
inferred from platform identity with a warn — a macOS row must **declare** it,
since direct download and the Mac App Store are different models; `../SKILL.md`
§ *Release model*, `policy-schema-post-merge.md` §4). What "ready" means is
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
  `devkit/PLATFORMS.md`, then re-run `/post-merge --init`.*
- *ios* — `staging_deploy_cmd` is a `[USER: …]` placeholder — set it to your
  internal/TestFlight track deploy (e.g. `fastlane beta`), then re-run
  `/post-merge --init`.*

**Persist** the result to `policy.json` as the `staging_ready` record
(`../../shared/refs/policy-schema-post-merge.md` §5) — a resolved **fact**, re-derived on every
re-init, that `--staging` reads to guard the ship. `--init` performs no
merge/deploy here; it only reads what the row declares and records readiness.

## Step-coverage map

`--init` reaches three clusters (branch protection, deploy, smoke) plus the cross-cutting
`gh` prerequisite, and — under `staged` flow — records the per-platform
**staging-readiness** fact (item 6) that `--staging`'s guard reads. The rest are pure
logic / content / human gates with nothing to set up.

**Legend:** ✅ covered · ◐ indirect (via the `gh` prerequisite only) · ➖ not covered.

| Mode | Step | | `--init`'s role |
|---|---|---|---|
| `--staging` | 1 · Branch protection | ✅ | policy + `--bootstrap` offer (guarded on a `ci` workflow existing) + `gh` install |
| | 2 · Locate PR + green CI | ◐ | `gh` present + authed; reads `github_actions` then `steps.ci` to flag a vacuous (zero-check) pass — silent when Actions is opted out |
| | 3 · Merge into staging | ◐ | `gh` + protection |
| | 4 · Deploy staging | ✅ | deploy-CLI detect/install; PLATFORMS.md gaps → `/msg --init` |
| | 5 · Verify deploy (smoke) | ✅ | `smoke_cmd` binary present; flag declared-but-unverified |
| | 6 · Human test script | ➖ | derived from PRD report — no tooling |
| | 7 · Sign-off stamp | ➖ | writes PRD frontmatter — no tooling |
| `--production` | 1 · Preconditions | ◐ | CI status via `gh`; signoff is file state |
| | 2 · Branch protection (main) | ✅ | as staging #1, for `main` |
| | 3 · Double-confirmation | ➖ | pure human gate |
| | — · Inline human-test (`direct`) | ➖ | pure human gate |
| | — · Release lock | ➖ | git tag on the remote — no setup tooling (`gh`/remote covered above) |
| | 4 · Open release PR | ◐ | `gh` only |
| | 5 · Merge on green CI + review | ◐ | `gh` + protection |
| | 6 · Production deploy | ✅ | deploy-CLI detect/install |
| | 7 · Verify deploy (smoke) | ✅ | `smoke_cmd` binary present |
| | 8 · Intake stamp | ➖ | writes INTAKE.md — no tooling |
| | 9 · Tag the release | ➖ | `git tag` + push on prod — no setup tooling |
| | 10 · PRD lane → `done` | ➖ | frontmatter stamp + a folder move — no tooling |

## Direct-release mode reshapes the ship

When `release_flow.mode:"direct"`, there is no staging branch: `/post-merge --staging`
**refuses** with `no_staging_stage` (naming both `/post-merge --production` and
`/msg --init-staging`). The whole ship collapses into `--production` against `prod_branch`
— **every human gate is preserved** (double-confirmation, then the **inline
human-test approval** — defined in `refs/production.md` § *Inline human-test
approval*, asked before the merge — then deploy and smoke); only the staging
*stage* is gone. The **staging-scoped stages**
(enumerated once in `SKILL.md` § *Release flow*) are **inactive because they do
not apply** — not waived and not relaxed; every stage that still applies runs at
full rigor. This is the read-contract's behavior
(`policy-schema.md` §1); `--init`'s job is only to *record* `mode:"direct"`
so the gate collapses correctly. The **staging-readiness detection** (item 6) is
likewise inactive here — there is no staging environment to verify — so `--init`
writes no `staging_ready` record in `direct`.

## What `--init` writes

`--init` completes `devkit/policy.json` (never PLATFORMS.md):

- `steps.deploy_staging` / `steps.deploy_production` — deploy-CLI readiness (item 3).
- `steps.smoke` — smoke-binary readiness (item 4).
- `policies.branch_protection` — mode + `reason` + `overrides` (item 2).
- `policies.release_flow` — completes/confirms the topology (item 1).
- `staging_ready` — per-platform staging-readiness fact (item 6; **`staged` flow
  only** — omitted in `direct`). A resolved fact, re-derived each re-init, read by
  `--staging` (`../../shared/refs/policy-schema-post-merge.md` §5).
- flips **`init:true`** on completion, stamps `generated` + `generated_by:"post-merge --init"`.

The written file must pass its own validation and re-load with **zero** warnings. Schema, status vocabulary (`ready`/`opted_out`/`n/a`/`missing`/`deferred` — no
`installed`), and the full field spec are authoritative in `policy-schema-post-merge.md`; do not
duplicate them here.

## Never

- Never merge, open a PR, deploy, or run a smoke check — `--init` is setup only.
- Never write `devkit/PLATFORMS.md` — report gaps and delegate to `/msg --init`.
- Never write `steps.ci` or scaffold a `.github/workflows/` pipeline — that's `/pre-merge --init`'s; only *read* `steps.ci` to guard the protection offer.
- Never write `policies.github_actions` — that decision belongs to `/msg --init` / `/msg --update`; only *read* it. If the user asks to change it here, name `/msg --update` rather than writing the key.
- Never create a staging branch — offer `/msg --init-staging`, which owns branch creation.
- Never install a paid/SaaS tool or sign the user up for a host — record `deferred`/`opted_out` with the paid tool named.
- Never write `optional` on a Free-plan 403 without an explicit confirm.
