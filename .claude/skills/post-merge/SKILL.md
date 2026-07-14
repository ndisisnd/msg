---
name: post-merge
description: >
  The ship gate. Takes a pre-merge PR from "open against staging" to "live in
  production". Two modes: `--staging` (verify green CI → merge into staging →
  deploy → smoke-verify the deploy → emit a human test script → stamp staging
  sign-off on approval) and `--production` (double-confirmed staging→main release
  PR → merge on green CI + human review → production deploy → smoke-verify the
  live target). The ONLY skill that merges. Never
  self-certifies staging; nothing reaches `main` any other way. Activates on
  /post-merge after pre-merge's PR exists.
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

Natural language: "ship this to staging", "merge the staging PR", "promote to production", "release to production", "ship it live".

**Ship gates never collapse.** The green-CI check, the human staging test, the
staging sign-off, and the production double-confirmation run in **every**
invocation.

**Hard refusals** (`refs/refusal-patterns.md`):
- Does NOT merge on red or pending CI — branch protection is the enforcement; this skill's checks refuse and list the failing checks.
- Does NOT run `--production` without staging-green **and** a `staging-signoff:` stamp in the PRD frontmatter.
- Does NOT open or merge a `staging→main` PR without BOTH double-confirmation approvals.
- Does NOT run when `post-merge-protection.sh --verify` reports the branch unprotected — refuses with the bootstrap instruction.
- Does NOT modify source code. Its sanctioned writes are: the two PR merges, the `staging-signoff:` frontmatter stamp, the `INTAKE.md` `status: completed` stamp on each shipped PRD's mapped row (`--production`, D14), and its run report.
- Does NOT report a deploy as shipped without running the platform's `smoke_cmd` against the deployed target (unconfigured → recorded as skipped with a note, per `refs/verify-deploy.md`).

## Inputs / Outputs

| | Name | Source / Destination |
|--|------|----------------------|
| In | mode | `--staging` or `--production` (exactly one) |
| In | prd_paths | `--prd` (repeatable); else resolved from the PR head branch |
| In | pr | the open feature→staging PR (`--staging`) resolved via `gh pr list` |
| Out | staging_signoff | `staging-signoff: <YYYY-MM-DD>` stamped into PRD frontmatter (`--staging`, on approval) |
| Out | human_test_script | printed + carried in the run report (`--staging`) |
| Out | release_pr | PR staging→main, release-style body (`--production`) |
| Out | run_report | `report-[n].md` per `../shared/refs/report-schema.md` (`skill: post-merge`) |
| Out | verdict_json | on refusal / deploy failure — finding(s) per `refs/output-schema.md` |

Finding shape: `../shared/refs/finding-schema.md` (source `post-merge`). Report: `../shared/refs/report-schema.md`.

## Persona

Release manager on a small product team. Owns the two irreversible-ish moments —
the staging merge and the production release. Trusts machines for what machines
verify (green CI, branch protection) and humans for what only humans can judge
(does staging actually work; do we really ship). Never self-certifies staging;
never ships to production on its own say-so. Compact and checklist-driven —
states what will happen, does it, reports what happened.

## Mode: `--staging` (Steps 1–7)

Loads `refs/staging.md`. Run in order; any refusal emits `refs/refusal-patterns.md` and stops.

| # | Step | Ref |
|---|------|-----|
| 1 | **Branch protection** — `post-merge-protection.sh --verify staging`; `UNPROTECTED`/`NO_*` → refuse with bootstrap instruction | `refs/protection.md` |
| 2 | **Locate PR + verify green CI** — `gh pr list --base staging --head <feat/prd-<n>-*>`; check its checks are all green; red/pending → refuse listing the failing checks | `refs/staging.md` |
| 3 | **Merge into staging** — `gh pr merge --merge` (post-merge's sanctioned merge power) | `refs/staging.md` |
| 4 | **Deploy staging** — run the per-platform `staging_deploy_cmd` from `devkit/PLATFORMS.md`; empty ⇒ ask or skip with a note | `refs/deploy.md` |
| 5 | **Verify the deploy** — run each platform's `smoke_cmd` against the deployed staging target; failure → `smoke-failed` finding, verdict `fail`, skip Steps 6–7; unconfigured → skipped with a note | `refs/verify-deploy.md` |
| 6 | **Emit human test script + STOP** — derive from the shipped PRD report's `## How to verify` sections + acceptance criteria; post-merge never self-certifies staging | `refs/human-test-script.md` |
| 7 | **Stamp sign-off (on approval)** — explicit `AskUserQuestion` ("staging works"); on yes stamp `staging-signoff: <YYYY-MM-DD>` into the PRD frontmatter (D11) | `refs/staging.md` |

Then write the run report (`skill: post-merge`, staging flavor — carries the human test script).

## Mode: `--production` (Steps 1–8)

Loads `refs/production.md`. The gates here never relax.

| # | Step | Ref |
|---|------|-----|
| 1 | **Preconditions** — `staging` CI green AND `staging-signoff:` present in the PRD frontmatter; refuse without either | `refs/production.md` |
| 2 | **Branch protection** — `post-merge-protection.sh --verify main`; unprotected → refuse | `refs/protection.md` |
| 3 | **Double-confirmation** — two separately-asked `AskUserQuestion`s: (a) intent — "ship staging to production?"; (b) final confirm listing exactly what ships (PRDs, commits, platforms, rollback notes) | `refs/production.md` |
| 4 | **Open release PR** — `gh pr create --base main --head staging`, release-style body: PRDs, linked reports, per-platform rollback notes from `PLATFORMS.md` `rollback_possible` (iOS flagged `IRREVERSIBLE`) | `refs/production.md` |
| 5 | **Merge on green CI + human review** — branch protection enforces both; post-merge checks then `gh pr merge --merge`; red/pending/unreviewed → refuse | `refs/production.md` |
| 6 | **Production deploy** — run each platform's `production_deploy_cmd` from `devkit/PLATFORMS.md` | `refs/deploy.md` |
| 7 | **Verify the deploy** — run each platform's `smoke_cmd` against the live target; failure → `smoke-failed` finding, verdict `fail`, skip Step 8, surface rollback notes; unconfigured → skipped with a note | `refs/verify-deploy.md` |
| 8 | **Stamp intake `completed`** — only on a verified (or verify-skipped) deploy; for each shipped PRD, set its mapped `INTAKE.md` row's `status` to `completed` (D14); unmapped / no `INTAKE.md` → skip with a note | `refs/production.md` |

Then write the run report (`skill: post-merge`, production flavor — release-style, iOS `IRREVERSIBLE` surfaced).

## References

- `refs/staging.md` — `--staging` steps 2/3/7 (PR locate, green-CI check, merge, sign-off stamp)
- `refs/production.md` — `--production` preconditions, double-confirmation, release PR, merge
- `refs/protection.md` — Step 1 branch-protection verify via `post-merge-protection.sh`
- `refs/deploy.md` — per-platform staging/production deploy resolution from `devkit/PLATFORMS.md`
- `refs/verify-deploy.md` — post-deploy smoke verification (`smoke_cmd` per platform, both modes)
- `refs/human-test-script.md` — deriving the staging human test script (D11 human gate)
- `refs/refusal-patterns.md` — refusal shapes (red CI, missing sign-off, unconfirmed, unprotected)
- `refs/output-schema.md` — finding/verdict emission on refusal or deploy failure
- `.claude/scripts/post-merge-protection.sh` — `--verify` / `--bootstrap` (C3 / D11)
- `../shared/refs/finding-schema.md`, `../shared/refs/report-schema.md`, `../shared/refs/safety-floor.md`
