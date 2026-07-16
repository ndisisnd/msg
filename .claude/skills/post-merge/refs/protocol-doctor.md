---
name: post-merge-doctor
description: post-merge --doctor spec — detect ship capability + policy (release-flow topology, branch protection, deploy/smoke CLIs, PLATFORMS.md gaps), interview per gap, install OSS-first, and complete devkit/policy.json. Never merges, deploys, opens PRs, or writes PLATFORMS.md.
type: reference
---

# `/post-merge --doctor` — ship-capability + policy setup

`--doctor` is a **setup mode**, not a ship. Post-merge's tooling is less about test
runners and more about **ship capability + policy**: can this repo merge, protect its
branches, deploy, and smoke-verify — and what release flow does it follow. `--doctor`
**detects** each, **interviews** the user per gap, **offers OSS-first installs** (gated,
per-item), and **completes `devkit/policy.json`**. It runs no protocol step: no merge, no
PR, no deploy, no smoke, and it never writes `devkit/PLATFORMS.md` (AC-DR1).

Follow the **Shared `--doctor` contract** (prereqs → load/seed policy → detect → interview
→ offer install → write → summary; see `improve-doctor.md`). This ref covers the
**post-merge-specific detection**. The policy file's schema, status vocabulary, validation
rules, and gate read-contract are defined once in
[`../../shared/refs/policy-schema.md`](../../shared/refs/policy-schema.md) — **cite it, do
not restate it here**.

## Prerequisite: `gh` installed + authenticated

Steps 1–5 all lean on `gh`. If absent, offer `brew install jq gh` and prompt
`gh auth login`; without a git remote, note that protection/PR steps are inert. Record
`gh` presence so the coverage map below is honest (a `◐` step that has no `gh` is dead).

## The five detection items

### 1 · Release flow (branch topology) → `release_flow`

Detect whether a staging branch exists:

```bash
git show-ref --verify --quiet refs/heads/staging   # or gh api on the remote
```

| Topology | Doctor proposes | Offer |
|---|---|---|
| staging **present** | `release_flow.mode:"staged"` (`staging_branch:"staging"`, `prod_branch:<default branch>`) | — |
| staging **absent** | `release_flow.mode:"direct"` (`staging_branch:null`, `prod_branch:<default branch>`) | **`/msg --init-staging`** to add the staging stage |

Doctor **records the choice**; it **never creates the branch** — that is
`/msg --init-staging`'s job alone (AC-DR6, AC-RF5, AC-OW3). See `policy-schema.md`
§`policies.release_flow`.

### 2 · Branch protection → `branch_protection`

Run `post-merge-protection.sh --verify <branch>` per relevant branch and read the
environment. Resolve the script locally-first, then the global install (as
`refs/protection.md`):

```bash
S=.claude/scripts/post-merge-protection.sh
[ -f "$S" ] || S="$HOME/.claude/scripts/post-merge-protection.sh"
bash "$S" --verify <branch>
```

| `--verify` output | Doctor action |
|---|---|
| `NO_GH` (exit 2) | offer to install `gh` + prompt `gh auth login`; can't probe protection until then |
| `NO_REMOTE` (exit 2) | record `branch_protection.mode:"skip"` — nothing to protect |
| `UNPROTECTED <b> <missing>` (exit 1), protection **available** | offer `post-merge-protection.sh --bootstrap` (gated, per-item, AC-BP1 setup); decline → record `optional` or `skip` with a `reason` |
| `PROTECTED <b>` (exit 0) | record `enforced` for that branch |
| private repo + protection API `403` upgrade-required | **auto-detect Free-plan limitation** — see below |

**Free-plan 403 auto-detect (AC-DR5).** A private repo on GitHub Free cannot set branch
protection; the API returns `403` upgrade-required. Doctor pre-fills
`branch_protection.mode:"optional"` (with a `reason` like *"private repo on GitHub Free —
branch-protection API unavailable"*) and records `repo.branch_protection_available:false`
+ `repo.detected_via`. It **requires an explicit confirm** via `AskUserQuestion` before
writing `optional` — the relaxation is never silent.

**Per-branch `overrides`.** Different branches may take different stances — e.g. `main`
`enforced` while `staging` stays `optional`. Record these under
`branch_protection.overrides` (`overrides[b] ?? mode`, per `policy-schema.md`
§`branch_protection` — this is the AC-BP4 setup side). The full read-contract that turns
these modes into refuse / warn-proceed / skip at merge time lives in `policy-schema.md`
§2 (AC-BP1–BP6 are enforced there; doctor only *records* the stance).

### 3 · Deploy CLIs

Parse `devkit/PLATFORMS.md` deploy commands (the `staging_deploy_cmd` /
`production_deploy_cmd` columns, per `refs/deploy.md`), extract the **leading binary** of
each command, and probe it:

```bash
command -v <bin>        # flyctl, vercel, netlify, wrangler, eas, gh, fastlane, …
```

Offer install for the ones missing. The deploy **target** may be a paid host, but the
**CLIs are free** — install those; **never sign the user up for anything** (AC-DR3). A
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

Empty or `[USER: …]` placeholder deploy / preview / smoke cells mean `/msg --init` never
filled them in. Doctor **reports** these gaps and **delegates to `/msg --init`** — it
**does not write `devkit/PLATFORMS.md`** (AC-DR1, AC-OW2). PLATFORMS.md command
declarations stay owned by `/msg --init`; doctor is read-only to that file.

## Step-coverage map

`--doctor` reaches three clusters (branch protection, deploy, smoke) plus the cross-cutting
`gh` prerequisite. The rest are pure logic / content / human gates with nothing to set up.

**Legend:** ✅ covered · ◐ indirect (via the `gh` prerequisite only) · ➖ not covered.

| Mode | Step | | Doctor's role |
|---|---|---|---|
| `--staging` | 1 · Branch protection | ✅ | policy + `--bootstrap` offer + `gh` install |
| | 2 · Locate PR + green CI | ◐ | `gh` present + authed |
| | 3 · Merge into staging | ◐ | `gh` + protection |
| | 4 · Deploy staging | ✅ | deploy-CLI detect/install; PLATFORMS.md gaps → `/msg --init` |
| | 5 · Verify deploy (smoke) | ✅ | `smoke_cmd` binary present; flag declared-but-unverified |
| | 6 · Human test script | ➖ | derived from PRD report — no tooling |
| | 7 · Sign-off stamp | ➖ | writes PRD frontmatter — no tooling |
| `--production` | 1 · Preconditions | ◐ | CI status via `gh`; signoff is file state |
| | 2 · Branch protection (main) | ✅ | as staging #1, for `main` |
| | 3 · Double-confirmation | ➖ | pure human gate |
| | 4 · Open release PR | ◐ | `gh` only |
| | 5 · Merge on green CI + review | ◐ | `gh` + protection |
| | 6 · Production deploy | ✅ | deploy-CLI detect/install |
| | 7 · Verify deploy (smoke) | ✅ | `smoke_cmd` binary present |
| | 8 · Intake stamp | ➖ | writes INTAKE.md — no tooling |

## Direct-release mode reshapes the ship

When `release_flow.mode:"direct"`, there is no staging branch: `/post-merge --staging`
**refuses** with `no_staging_stage` (naming both `/post-merge --production` and
`/msg --init-staging`). The whole ship collapses into `--production` against `prod_branch`
— **every human gate is preserved** (double-confirmation, inline human-test approval,
deploy, smoke); only the staging *stage* is gone. The `staging-signoff:` precondition is
**waived** and no staging deploy runs. This is the read-contract's behavior
(`policy-schema.md` §1, AC-RF3/AC-RF4); doctor's job is only to *record* `mode:"direct"`
so the gate collapses correctly.

## What doctor writes

Doctor completes `devkit/policy.json` (never PLATFORMS.md):

- `steps.deploy_staging` / `steps.deploy_production` — deploy-CLI readiness (item 3).
- `steps.smoke` — smoke-binary readiness (item 4).
- `policies.branch_protection` — mode + `reason` + `overrides` (item 2).
- `policies.release_flow` — completes/confirms the topology (item 1).
- flips **`init:true`** on completion, stamps `generated` + `generated_by:"post-merge --doctor"`.

The written file must pass its own validation and re-load with **zero** warnings (AC-DR5,
AC-S6). Schema, status vocabulary (`ready`/`opted_out`/`n/a`/`missing`/`deferred` — no
`installed`), and the full field spec are authoritative in `policy-schema.md`; do not
duplicate them here.

## Never

- Never merge, open a PR, deploy, or run a smoke check — `--doctor` is setup only (AC-DR1).
- Never write `devkit/PLATFORMS.md` — report gaps and delegate to `/msg --init` (AC-OW2).
- Never create a staging branch — offer `/msg --init-staging`, which owns branch creation (AC-OW3).
- Never install a paid/SaaS tool or sign the user up for a host — record `deferred`/`opted_out` with the paid tool named (AC-DR3).
- Never write `optional` on a Free-plan 403 without an explicit confirm (AC-DR5).
