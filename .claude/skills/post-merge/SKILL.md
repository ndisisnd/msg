---
name: post-merge
description: >
  The ship gate. Takes a pre-merge PR from "open against staging" to "live in
  production". Two modes: `--staging` (verify green CI → merge into staging →
  deploy → smoke-verify the deploy → emit a human test script → stamp staging
  sign-off on approval) and `--production` (double-confirmed staging→main release
  PR → merge on green CI + human review → production deploy → verify per release
  model: smoke the live target, or submission-accepted + monitor-handoff for
  store apps). The ONLY skill that merges. Never
  self-certifies staging; nothing reaches `main` any other way. Activates on
  /post-merge after pre-merge's PR exists.
argument-hint: "<--staging | --production> [--prd <path>]"
allowed_tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
---

# post-merge

**The** ship gate. Runs after `/pre-merge` has opened a feature→staging PR, and
takes it the rest of the way: onto `staging` (tested by a human), then onto
`main` (production, double-confirmed). It is the **only** skill in the harness
that merges — pre-merge opens PRs but never merges; eng commits to feature
branches but never pushes to `staging`/`main`. Nothing reaches `main` any other
way. Each run is independent.

```
pre-merge (PR feature→staging)  →  post-merge --staging  →  (human tests staging)
   →  post-merge --production  →  (double-confirm)  →  PR staging→main  →  main (live)
```

## Usage

- `/post-merge --staging` — merge the current feature→staging PR on green CI, deploy staging, smoke-verify the deploy, emit a human test script, and stamp sign-off on approval
- `/post-merge --staging --prd <path>` — name the shipped PRD explicitly (else resolved from the PR head branch `feat/prd-<n>-*`)
- `/post-merge --production` — open + merge the double-confirmed staging→main release PR and run the production deploy
- `/post-merge --production --prd <path>` (repeatable) — the PRD(s) this release ships; used for the release body + sign-off precondition
- `/post-merge --init` — detect ship tooling (branch-protection, deploy/smoke CLIs), interview about the policy gaps, and write `devkit/policy.json`; performs **no** merge, PR, or deploy. Guards the branch-protection offer on a CI workflow existing (reads `steps.ci`; scaffolding the workflow is `/pre-merge --init`'s job) (`refs/protocol-init.md`)
  - `/post-merge --doctor` — **deprecated alias for one release**: runs `--init` and prints a deprecation note naming `--init`/`--update`

Natural language: "ship this to staging", "merge the staging PR", "promote to production", "release to production", "ship it live".

**Ship gates never collapse.** The green-CI check, the human staging test, the
staging sign-off, and the production double-confirmation run in **every**
invocation. (In `release_flow=direct` the staging *stage* is absent — its
sign-off is waived and an inline human-test approval stands in its place; every
other gate holds. See **Release flow** below.)

**Hard refusals** (`refs/refusal-patterns.md`):
- Does NOT merge on red or pending CI — branch protection is the enforcement; this skill's checks refuse and list the failing checks.
- Does NOT run `--production` without staging-green **and** a `staging-signoff:` stamp in the PRD frontmatter **whose pinned sha still covers `staging`'s tip** — commits merged after sign-off refuse (`stale_signoff`), never ride along uncertified.
- Does NOT open or merge a `staging→main` PR without BOTH double-confirmation approvals.
- Does NOT run when `post-merge-protection.sh --verify` reports the branch unprotected **and** the `branch_protection` policy resolves to `enforced` (the default / no-file case) — refuses with the bootstrap instruction; `optional` warns + proceeds, `skip` doesn't verify (`../shared/refs/policy-schema.md` §2). `NO_GH`/`NO_REMOTE` refuse regardless of mode.
- Does NOT run `--staging` into a staging environment `--init` recorded as **unready** (a platform with `gaps[]` in `staging_ready`) **when `staging_readiness` resolves to `enforced`** (the default) — refuses `staging_unready`, naming the exact missing artifact + fix; `optional` warns + proceeds, `skip` doesn't guard, and a **missing** record (pre-C9 init) only warns, never refuses (`../shared/refs/policy-schema.md` §5, `refs/staging.md`).
- Does NOT modify source code. Its sanctioned writes are: the two PR merges, the `staging-signoff:` frontmatter stamp, the `INTAKE.md` `status: completed` stamp on each shipped PRD's mapped row (`--production`, D14), and its run report.
- Does NOT report a deploy as shipped without running the platform's `smoke_cmd` against the deployed target (unconfigured → recorded as skipped with a note, per `refs/verify-deploy.md`).
- A failed ship is **not** a refusal — the merge already happened; on a deploy/smoke failure post-merge writes the colocated issues file `features/prd-<N>-<slug>/reports/report-prd-<N>-<K>.json` and enters the fix loop (`../shared/refs/fix-loop.md`) rather than dead-ending.

## Inputs / Outputs

| | Name | Source / Destination |
|--|------|----------------------|
| In | mode | `--staging` or `--production` (exactly one) |
| In | prd_paths | `--prd` (repeatable); else resolved from the PR head branch |
| In | pr | the open feature→staging PR (`--staging`) resolved via `gh pr list` |
| Out | staging_signoff | `staging-signoff: <YYYY-MM-DD>@<certified sha>` stamped into PRD frontmatter (`--staging`, on approval) — the sha is the staging commit that was deployed and human-tested |
| Out | human_test_script | printed + carried in the run report (`--staging`) |
| Out | release_pr | PR staging→main, release-style body (`--production`) |
| Out | run_report | `report-prd-<N>-<K>.md` per `../shared/refs/report-schema.md` (`skill: post-merge`) |
| Out | verdict_json | on refusal / deploy failure — finding(s) per `refs/output-schema.md` |
| Out | issues_file | `features/prd-<N>-<slug>/reports/report-prd-<N>-<K>.json` on a failed ship (deploy/smoke failure) — consumed by `eng --build report=` |

Finding shape: `../shared/refs/finding-schema.md` (source `post-merge`). Report: `../shared/refs/report-schema.md`.

## Persona

Release manager on a small product team. Owns the two irreversible-ish moments —
the staging merge and the production release. Trusts machines for what machines
verify (green CI, branch protection) and humans for what only humans can judge
(does staging actually work; do we really ship). Never self-certifies staging;
never ships to production on its own say-so. Compact and checklist-driven —
states what will happen, does it, reports what happened. When a ship fails at
deploy or smoke — the merge already stands — it doesn't just stop: it writes the
issues file and walks the user into the fix loop.

## Pre-flight: policy file + `init` lifecycle (both modes)

Before Step 1 in **either** mode, load + validate `devkit/policy.json` **once**
and check the `init` lifecycle gate (`../shared/refs/policy-schema.md` §0). No
file / malformed / `version` ≠ 1 → built-in defaults (today's behavior) + exactly
one info line; never abort on a parse error.

| policy `init` state | action |
|---|---|
| file **absent** (repo never `/msg --init`ed) | built-in defaults + a one-line nudge to run `/msg --init` or `/post-merge --init`; **no** auto-init (back-compat, AC-LC6) — proceed to Step 1 |
| `init: false` (or `init` absent on a present file) | **auto-run `--init` inline first** (AC-LC2); on completion it flips `init: true` (AC-LC3), then continue to Step 1. If the user **aborts** `--init`, stop — run **no** protocol step (no PR, no merge, no verdict) (AC-LC4) |
| `init: true` | proceed to Step 1 directly — no init run (AC-LC5) |

The same load resolves `release_flow` (below) and `branch_protection` (Step 1
`--staging` / Step 2 `--production`) for the run. No gate run ever *writes*
`policy.json` — only `--init` does (AC-OW1). `--init` itself never merges,
opens PRs, or deploys (`refs/protocol-init.md`). (`--doctor` is a deprecated
one-release alias for `--init`.)

## Release flow (both modes)

Resolve `release_flow` from the policy file (`../shared/refs/policy-schema.md`
§1): `flow = policies.release_flow.mode ?? "staged"`, `prod = prod_branch ?? "main"`,
`stg = staging_branch ?? "staging"`. No `policy.json` → `staged` everywhere
(= today).

| `flow` | `--staging` | `--production` |
|---|---|---|
| `staged` (default / no file) | merge feature→`stg` (Steps 1–7 below, unchanged) | PR `stg`→`prod` (Steps 1–8 below, unchanged) |
| `direct` | **refuse** `no_staging_stage` (`refs/refusal-patterns.md`), naming both `/post-merge --production` and `/msg --init-staging` | single ship feature→`prod`, preserving every human gate |

**`direct` + `--production`** — a single feature→`prod` ship that still runs the
double-confirmation (Step 3), an inline human-test approval, the production deploy
(Step 6), and smoke (Step 7). The staging-scoped stages are **inactive**, not
relaxed: there is no staging to deploy, test, or sign off, so those questions do
not apply. Every question that *does* still apply is answered at full rigor
(AC-RF3, AC-RF4, AC-NS2).

**Fewer checks, never weaker ones.** In `direct` flow post-merge is answering a
narrower question — *is this allowed to merge to `prod`, and does it pass?* — with
undiminished strictness on everything still in scope. Three states, never
conflated (AC-NS1):

| State | Meaning | Example |
|---|---|---|
| **inactive** | the stage does not apply to this configuration — there is nothing for it to check | staging deploy / staging smoke / staging human-test / `staging-signoff` under `release_flow=direct` |
| **skipped** | the stage applies but its tooling is absent — recorded with a note, surfaced as a gap | no `smoke_cmd` configured for a platform |
| **relaxed** | a threshold was deliberately lowered by policy | `branch_protection: optional` warning instead of refusing |

**The safety floor is never inactive** (AC-NS3). Security, migration, and the
human double-confirmation are not staging-scoped — no `release_flow` value
deactivates them. A change that would move one of them into the inactive column
is a floor violation (`../shared/refs/safety-floor.md`), not a configuration.

The sign-off is inactive **because its stage is** — which is also why C2's
commit-pin has nothing to pin, consistently rather than as a special case
(AC-NS4). Deferred to the post-merge executor phase: declaring this activation
set as catalog data (AC-NS5) — post-merge is not component-driven yet
(`../shared/refs/policy-schema.md` § `components[]`), so today the staging-scoped
set is named **once**, here, and every ref defers to this section rather than
restating it.

## Release model (both modes)

Every shipping platform carries a `release_model` ∈ `deploy` | `submission`,
authored as a `devkit/PLATFORMS.md` column and resolved per platform
(`../shared/refs/policy-schema.md` §4). It is **orthogonal to `release_flow`**:
`release_flow` decides *which stages run* (staged vs direct), `release_model`
decides *what a deploy/verify stage means* for each platform. The deploy and
verification steps below (`--staging` 4–5, `--production` 6–7) branch on it:

| `release_model` | Platforms (default) | Deploy exit 0 ⇒ | Verify | Report |
|---|---|---|---|---|
| `deploy` | web, macOS, server | target is **live** | smoke the live target (`refs/verify-deploy.md`) | live — today's path, unchanged (AC-RM2) |
| `submission` | iOS, Android | **submitted** to store review | submission accepted; a configured smoke is backend/build health (`refs/submission.md`) | `submitted` (+ track) + monitor-handoff, **never** `live` (AC-RM3/SB1/SB3) |

Resolution is **per platform and independent** (AC-RM4): a mixed repo verifies web
as live and iOS as submitted in the **same run**. Missing `release_model` → inferred
from the platform identity with a warn, never guessed silently (AC-RM1). The full
submission lifecycle (submit → processing → review → phased rollout), the
monitor-handoff the run report emits, `completed`-on-submit, and the `live_status`
polling seam are specified in `refs/submission.md`: C1 established the primitive
(submitted-not-live + the backend-health smoke label); the submission-lifecycle
phase (C5) built the lifecycle, the handoff, and the seam on top.

## Mode: `--staging` (Steps 1–7)

Loads `refs/staging.md`. Run in order; any refusal emits `refs/refusal-patterns.md` and stops.

**Release-flow guard:** if `release_flow.mode = direct`, `--staging` **refuses**
`no_staging_stage` before Step 1 (there is no staging branch) — name both
`/post-merge --production` and `/msg --init-staging` (AC-RF2).

| # | Step | Ref |
|---|------|-----|
| 1 | **Branch protection (policy-conditional)** — resolve `mode_staging = overrides[staging] ?? branch_protection.mode ?? "enforced"` (`../shared/refs/policy-schema.md` §2), then `post-merge-protection.sh --verify staging`: `enforced` → `UNPROTECTED` **refuses** (`unprotected`, bootstrap instruction); `optional` → `UNPROTECTED` **warns + proceeds** (one `low` note in the report); `skip` → don't verify (record "protection check skipped by policy"). `NO_GH`/`NO_REMOTE` **refuse regardless of mode**. No file → `enforced` (= today) | `refs/protection.md` |
| 2 | **Locate PR + verify green CI** — `gh pr list --base staging --head <feat/prd-<n>-*>`; check its checks are all green; red/pending → refuse listing the failing checks | `refs/staging.md` |
| 3 | **Merge into staging** — `gh pr merge --merge` (post-merge's sanctioned merge power) | `refs/staging.md` |
| 4 | **Deploy staging** — run the per-platform `staging_deploy_cmd` from `devkit/PLATFORMS.md`; empty ⇒ ask or skip with a note. Exit 0 means **live** (`deploy` model) or **submitted to the internal/TestFlight track** (`submission` model — report `submitted` + track + the (lighter, internal-track) monitor-handoff, never `live`; non-zero = rejected-at-upload, a deploy failure) | `refs/deploy.md`, `refs/submission.md` |
| 5 | **Verify the deploy** — **`deploy` model:** run each platform's `smoke_cmd` against the deployed staging target (unchanged, AC-RM2). **`submission` model:** verification = submission accepted; a configured `smoke_cmd` runs but is reported as backend/build health, never app liveness (AC-RM3). Failure → `smoke-failed` finding, verdict `fail`, skip Steps 6–7; unconfigured → skipped with a note | `refs/verify-deploy.md`, `refs/submission.md` |
| 6 | **Emit human test script + STOP** — derive from the shipped PRD report's `## How to verify` sections + acceptance criteria; post-merge never self-certifies staging | `refs/human-test-script.md` |
| 7 | **Stamp sign-off (on approval)** — explicit `AskUserQuestion` ("staging works"); on yes stamp `staging-signoff: <YYYY-MM-DD>@<certified sha>` into the PRD frontmatter (D11), pinned to Step 3's merge sha — the commit that was actually deployed and tested | `refs/staging.md` |

Then write the run report (`skill: post-merge`, staging flavor — carries the human test script, and the `## Issue summary` block per `../shared/refs/report-schema.md`), and on the write print the terminal `Issue summary` block — every verdict, clean ships included (format owned by `../shared/refs/report-schema.md`; counts derive from the run's `findings[]`). On a failed ship, follow the **Failed-ship loop** below.

## Mode: `--production` (Steps 1–8)

Loads `refs/production.md`. The gates here never relax.

| # | Step | Ref |
|---|------|-----|
| 1 | **Preconditions** — `staging` CI green AND `staging-signoff:` present in the PRD frontmatter AND the sign-off still **covers** `staging`'s tip (every stamped sha an ancestor of `origin/staging`, and `origin/staging` == the newest stamped sha); refuse without any (`staging_not_green` / `no_signoff` / `stale_signoff`). An unpinned legacy stamp re-asks the human rather than dead-ending. **Under `release_flow=direct` this whole step is *inactive*, not waived** — there is no staging to sign off (see **Release flow** above); the ship goes feature→`prod` with every human gate preserved (AC-RF3, AC-NS4) | `refs/production.md` |
| 2 | **Branch protection (policy-conditional)** — resolve `mode_main = overrides[main] ?? branch_protection.mode ?? "enforced"` (`../shared/refs/policy-schema.md` §2), then `post-merge-protection.sh --verify main`: `enforced` → `UNPROTECTED` **refuses** (`unprotected`); `optional` → `UNPROTECTED` **warns + proceeds** (one `low` note); `skip` → don't verify. `NO_GH`/`NO_REMOTE` **refuse regardless of mode**. No file → `enforced` (= today) | `refs/protection.md` |
| 3 | **Double-confirmation** — two separately-asked `AskUserQuestion`s: (a) intent — "ship staging to production?"; (b) final confirm listing exactly what ships (PRDs, commits, platforms, rollback notes) | `refs/production.md` |
| 4 | **Open release PR** — `gh pr create --base main --head staging`, release-style body: PRDs, linked reports, per-platform rollback notes from `PLATFORMS.md` `rollback_possible` (iOS flagged `IRREVERSIBLE`) | `refs/production.md` |
| 5 | **Merge on green CI + human review** — branch protection enforces both; post-merge checks then `gh pr merge --merge`; red/pending/unreviewed → refuse | `refs/production.md` |
| 6 | **Production deploy** — run each platform's `production_deploy_cmd` from `devkit/PLATFORMS.md`. Exit 0 means **live** (`deploy` model) or **submitted to store review** (`submission` model — report `submitted` + track, never `live`; the app goes live downstream, out-of-band; **emit the monitor-handoff** — now in Apple/Google review, monitor at App Store Connect / Play Console, halt via `rollout_halt_cmd`; non-zero = rejected-at-upload, a deploy failure) | `refs/deploy.md`, `refs/submission.md` |
| 7 | **Verify the deploy** — **`deploy` model:** run each platform's `smoke_cmd` against the live target (unchanged, AC-RM2). **`submission` model:** verification = submission accepted; a configured `smoke_cmd` is reported as backend/build health, never app liveness (AC-RM3). Failure → `smoke-failed` finding, verdict `fail`, skip Step 8, surface rollback notes; unconfigured → skipped with a note | `refs/verify-deploy.md`, `refs/submission.md` |
| 8 | **Stamp intake `completed`** — only on a verified (or verify-skipped) deploy; for each shipped PRD, set its mapped `INTAKE.md` row's `status` to `completed` (D14); unmapped / no `INTAKE.md` → skip with a note | `refs/production.md` |

Then write the run report (`skill: post-merge`, production flavor — release-style, iOS `IRREVERSIBLE` surfaced, carrying the `## Issue summary` block per `../shared/refs/report-schema.md`), and on the write print the terminal `Issue summary` block — every verdict, clean ships included (format owned by `../shared/refs/report-schema.md`; counts derive from the run's `findings[]`). On a failed ship, follow the **Failed-ship loop** below.

## Failed-ship loop (failed ship)

When a ship **fails** — a non-zero deploy (`deploy` finding) or a smoke-check
failure (`smoke-failed` finding), verdict `fail`, in **either** mode — the merge
already happened, so post-merge does not dead-end on the failure. In order:

1. **Write the issues file `features/prd-<N>-<slug>/reports/report-prd-<N>-<K>.json`**
   — colocated in the PRD's `reports/` folder, sharing `N`/`K` with the run
   report `.md` (NO-PRD fallback: `features/reports/report-<K>.json`). Same
   canonical-finding `issues[]` shape pre-merge writes (`followUp.status`
   contract kept — camelCase, the key `eng --build` writes back and the `--gui`
   board reads). `followUp.suggested_command` =
   `eng --build report=features/prd-<N>-<slug>/reports/report-prd-<N>-<K>.json` —
   the deep-link fallback `fix-loop.md` resumes from if the user declines.
2. **Write the run report** (above) — it carries the `## Issue summary` block.
3. **Print the terminal `Issue summary` block** (above).
4. **Hand off to `../shared/refs/fix-loop.md`** — it runs Offer #1 (plan the
   fixes with `eng --plan`) → Offer #2 (orchestrated `eng --build`) off this same
   issues file. Do **not** re-spell the offer wording here; fix-loop.md owns it.

Applies identically to `--staging` (Step 5 smoke failure / Step 4 deploy failure)
and `--production` (Step 7 smoke failure / Step 6 deploy failure) — the mode's
own skip rules (`refs/verify-deploy.md`) still apply. The fixed branch comes back
through `/pre-merge` and this gate; the gate does not dead-end on the issues file.

## References

- `refs/staging.md` — `--staging` steps 2/3/7 (PR locate, green-CI check, merge, sign-off stamp)
- `refs/production.md` — `--production` preconditions, double-confirmation, release PR, merge
- `refs/protection.md` — Step 1/2 branch-protection verify via `post-merge-protection.sh` (policy-conditional: `enforced` refuses, `optional` warns + proceeds, `skip` doesn't verify)
- `refs/protocol-init.md` — `--init` mode (protection policy, deploy/smoke CLIs, PLATFORMS.md gap delegation; no merge/PR/deploy); `--doctor` is a deprecated one-release alias
- `refs/deploy.md` — per-platform staging/production deploy resolution from `devkit/PLATFORMS.md`; what deploy-cmd exit 0 means per `release_model` (live vs submitted)
- `refs/verify-deploy.md` — post-deploy verification per `release_model` (`deploy`: smoke the live target; `submission`: submission accepted + backend-health-labeled smoke)
- `refs/submission.md` — the `submission` release model (iOS/Android): exit 0 = submitted (+ track), never live; verification = submission accepted; smoke = backend/build health. Carries the full lifecycle (submit → processing → review → phased rollout), the monitor-handoff, `completed`-on-submit, the `live_status` polling seam, and submission-in-`direct`-flow (CV5)
- `refs/human-test-script.md` — deriving the staging human test script (D11 human gate)
- `refs/refusal-patterns.md` — refusal shapes (red CI, missing sign-off, unconfirmed, conditional `unprotected`, direct-mode `no_staging_stage`)
- `../shared/refs/policy-schema.md` — `devkit/policy.json` schema + read-contract (§0 `init` lifecycle, §1 `release_flow`, §2 `branch_protection`)
- `refs/output-schema.md` — finding/verdict emission on refusal or deploy failure
- `../shared/refs/fix-loop.md` — the post-failure Offer #1 → Offer #2 sequence run on a failed ship
- `features/prd-<N>-<slug>/reports/report-prd-<N>-<K>.json` — the issues file written on a failed ship (canonical `issues[]`, `followUp` contract)
- `.claude/scripts/post-merge-protection.sh` — `--verify` / `--bootstrap` (C3 / D11)
- `../shared/refs/finding-schema.md`, `../shared/refs/report-schema.md`, `../shared/refs/safety-floor.md`
