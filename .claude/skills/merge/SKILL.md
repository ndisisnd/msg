---
name: merge
description: >
  The ship gate — the only skill that pushes a feature branch, opens its PR and
  merges. `--staging` checks that pre-merge passed on the branch tip, pushes,
  opens the feature→staging PR, waits for green CI, merges, deploys, verifies,
  emits a human test script and stamps the staging sign-off on approval.
  `--production` ships the confirmed release to `main` and deploys production.
  `--update` refreshes merge's settings. Never self-certifies staging; nothing
  reaches `main` any other way. Activates on /merge after pre-merge passes.
argument-hint: "<--staging | --production> [--prd <path>] [--bump <major|minor|patch>] [--version <x.y.z>]"
allowed_tools:
  - Bash
  - Read
  - Write
  - Agent
  - AskUserQuestion
---

# merge

**The** ship gate. Runs after `/pre-merge` passed on the feature branch and takes it the
rest of the way: it pushes the branch and opens the PR, then onto `staging` (tested by a
human), then onto `main` (production, double-confirmed). It is the **only** skill in the
harness that pushes a feature branch, opens a PR or merges — eng commits to feature
branches, pre-merge checks and fixes them on the machine. Nothing reaches `main` any
other way.

```
pre-merge (local pass) → merge --staging (push, PR feature→staging, CI, merge) → (human tests staging) → merge --production → (double-confirm) → PR staging→main → main (live)
```

## Usage

- `/merge --staging [--prd <path>]` — merge the feature→staging PR on green CI, deploy + verify staging, emit a human test script, stamp the sign-off on approval (`refs/staging.md`); `--prd` names the shipped PRD explicitly (else resolved from the PR head branch `feat/prd-<n>-*`)
- `/merge --production [--prd <path>]...` — the double-confirmed release: PR to `prod`, merge, deploy, verify, tag (`refs/production.md`); `--prd` (repeatable) names the PRD(s) this release ships — the release body + the sign-off precondition
- `/merge --production [--bump <major|minor|patch>] [--version <x.y.z>]` — override the release version (default: **minor** bump from the last `v*` tag on prod); the resolved `v<x.y.z>+<build>` is shown in the confirm (`refs/release-identity.md`)
- `/merge --update` — re-check what changed since setup (protection, deploy and smoke tools, platforms and staging readiness, risky paths, CI wait limit; release flow is read and reported only), show the changes, ask one approval, save `devkit/policy.json`; performs **no** merge, PR, or deploy (`refs/protocol-init.md`)
- First run sets merge up by itself, then continues (§ *Pre-flight*)
- Progress messages are always on, every 5 minutes (`../shared/refs/status-heartbeat.md`)

Natural language: "ship this to staging", "merge the staging PR", "promote to production", "release to production", "ship it live".

## Posture

Release manager on a small product team. Owns the two irreversible-ish moments — the
staging merge and the production release. Compact and checklist-driven. **Ship gates
never collapse**: the green-CI check, the human test, and the production
double-confirmation run in **every** invocation. Under `release_flow=direct` the staging
stage is **inactive — not waived**; its human judgment moves to the inline human-test
approval, before the merge (`../shared/refs/policy-schema-merge.md` §1b).

## Hard refusals

Shapes and JSON in `refs/refusal-patterns.md`. Merge:
- Does NOT modify source code — the canonical, complete write list is `refs/sanctioned-writes.md`.
- Does NOT push or open a feature PR without pre-merge's pass on the branch tip; new commits since the pass ride only when small (≤20 lines, no risky file) and the quick check passes — else `no_premerge_pass`, "Run /pre-merge first." (`refs/open-pr.md`).
- Does NOT force-push — a rejected push stops the run (`push_rejected`).

- Does NOT merge on red or pending CI. An **empty** check set under `github_actions.enabled:false` is inactive by the user's decision — accepted with one report line (`../shared/refs/policy-schema.md` §2b); checks that *do* report are graded as always.
- Does NOT run `--production` without staging-green **and** a `staging-signoff:` stamp whose pinned sha still covers `staging`'s tip — later commits refuse (`stale_signoff`), never ride along uncertified.
- Does NOT open or merge a `staging→main` PR without BOTH double-confirmation approvals.
- Does NOT run a second `--production` while one is in flight — the release lock refuses `release_in_flight` naming the holder; a `--staging` merge during an in-flight production ship refuses the same way (`refs/production.md`, `../shared/refs/policy-schema-merge.md` §6).
- Does NOT run when the branch is unprotected and `branch_protection` resolves `enforced`; `optional` warns + proceeds, `skip` doesn't verify; `NO_GH`/`NO_REMOTE` refuse regardless (`../shared/refs/policy-schema-merge.md` §2).
- Does NOT run `--staging` into a staging environment recorded **unready** when `staging_readiness` resolves `enforced`; `optional` warns, `skip` doesn't guard, a missing record only warns (`../shared/refs/policy-schema-merge.md` §5).
- Does NOT report a deploy as shipped without running the platform's `smoke_cmd` against the deployed target (unconfigured → recorded as skipped with a note, `refs/verify-deploy.md`).
- A failed ship is **not** a refusal — the merge already happened; merge writes the issues file and enters `refs/failed-ship.md` rather than dead-ending.

## Pre-flight: policy file + first-run setup (every mode)

Before Step 1 in **any** mode, resolve the policy **once, by script** — it emits the
full key set (`release_flow`, `branch_protection`, `staging_readiness`, `steps.*`,
`github_actions`, `policies.merge`) plus `WARN=` lines; no step re-reads the file. A
malformed file → built-in defaults with `POLICY_STATE`, exit 0 — a policy read never
refuses a run. Then check whether merge was set up (`../shared/refs/policy-schema.md` §0):

```bash
S=.claude/scripts/script-policy-read.py; python3 "$S"     # devkit/policy.json
```

| policy state | action |
|---|---|
| file **absent** | run `/msg --init` first (it seeds the file), then merge setup inline, then continue |
| no `policies.merge` record (`MERGE_RISKY_PATHS_STATE=absent`), or `init: false` | **run merge setup inline first** (`refs/protocol-init.md`), save, then continue into the mode in the same run; user aborts setup → stop, run no protocol step |
| set up | proceed to Step 1 directly |

## Modes

Each mode's steps, order, refusals and phase seams live in its own ref. Load it and run
it. Mechanical phases run in **subagents**; every human gate stays **main-thread**, wording
unchanged (`../shared/refs/gate-dispatch.md`; seams: each ref's *Phase markers*); setup and
`--update` stay inline. Both ship modes end with the run report (`skill: merge`), the terminal
`Issue summary` block, the closing message (`../shared/refs/closing-message.md`), and
doctor-log any harness incidents (`../shared/refs/doctor-logging.md`).

| Mode | Ref |
|---|---|
| `--staging` | `refs/staging.md` |
| `--production` | `refs/production.md` (+ `refs/release-identity.md`) |
| `--update` (and first-run setup) | `refs/protocol-init.md` |

## References

- `refs/open-pr.md` — pass check, push, PR, CI wait · `refs/sanctioned-writes.md` — the canonical write enumeration + the script-resolution form · `refs/failed-ship.md` — rollback/rollout-halt offer, issues file, fix-loop handoff · `refs/deploy.md` · `refs/verify-deploy.md` · `refs/submission.md` · `refs/human-test-script.md` · `refs/protection.md` · `refs/refusal-patterns.md` · `refs/output-schema.md`
- `../shared/refs/` — `policy-schema.md` (§0 `init`, §1 `release_flow`, §2b `github_actions`) · `policy-schema-merge.md` (§1b flow behavior, §2 protection, §3 steps, §4 `release_model`, §5 `staging_ready`, §6 release lock) · `gate-dispatch.md` · `fix-loop.md` · `finding-schema.md` · `report-schema.md` · `safety-floor.md` · `status-heartbeat.md` · `prd-lifecycle.md`
- `.claude/scripts/` — `script-branch-protection.sh` · `script-signoff-coverage.sh` · `script-release-lock.sh` · `script-release-identity.sh` · `script-prd-stamp.sh` · `script-intake-stamp.sh` · `script-policy-read.py` · `script-policy-set.py` · `script-merge-checks.py` · `script-premerge-last-check.sh` · `script-ci-status.py` · `script-platforms-parse.py` · `script-smoke-run.sh` · `script-ts-miss.py`
