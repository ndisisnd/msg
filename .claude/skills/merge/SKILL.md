---
name: merge
description: >
  The ship gate — the only skill that merges. `--staging` merges the
  feature→staging PR on green CI, deploys, verifies, emits a human test script
  and stamps the staging sign-off on approval. `--production` ships the
  double-confirmed release to `main` and deploys production. Never
  self-certifies staging; nothing reaches `main` any other way. Activates on
  /merge after pre-merge's PR exists.
argument-hint: "<--staging | --production> [--prd <path>] [--bump <major|minor|patch>] [--version <x.y.z>] [--quiet | --status <n>m]"
allowed_tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
---

# merge

**The** ship gate. Runs after `/pre-merge` opened a feature→staging PR and takes
it the rest of the way: onto `staging` (tested by a human), then onto `main`
(production, double-confirmed). It is the **only** skill in the harness that
merges — eng commits to feature branches, pre-merge opens PRs, neither pushes to
`staging`/`main`. Nothing reaches `main` any other way.

```
pre-merge (PR feature→staging)  →  merge --staging  →  (human tests staging)
   →  merge --production  →  (double-confirm)  →  PR staging→main  →  main (live)
```

## Usage

- `/merge --staging` — merge the feature→staging PR on green CI, deploy + verify staging, emit a human test script, stamp the sign-off on approval (`refs/staging.md`)
- `/merge --staging --prd <path>` — name the shipped PRD explicitly (else resolved from the PR head branch `feat/prd-<n>-*`)
- `/merge --production` — the double-confirmed release: PR to `prod`, merge, deploy, verify, tag (`refs/production.md`)
- `/merge --production --prd <path>` (repeatable) — the PRD(s) this release ships; used for the release body + the sign-off precondition
- `/merge --production [--bump <major|minor|patch>] [--version <x.y.z>]` — override the release version (default: **minor** bump from the last `v*` tag on prod). The resolved `v<x.y.z>+<build>` is shown in the confirm before it is cut (`refs/release-identity.md`)
- `/merge --init` — detect ship tooling (branch protection, deploy/smoke CLIs, staging readiness), interview about the gaps, write `devkit/policy.json`. Performs **no** merge, PR, or deploy (`refs/protocol-init.md`)
- `/merge --quiet` — suppress this run's status heartbeat
- `/merge --status <n>m` — override the heartbeat interval for this run; flag beats policy beats default (`../shared/refs/status-heartbeat.md`)

Natural language: "ship this to staging", "merge the staging PR", "promote to production", "release to production", "ship it live".

## Posture

Release manager on a small product team. Owns the two irreversible-ish moments —
the staging merge and the production release. Compact and checklist-driven:
states what will happen, does it, reports what happened.

**Ship gates never collapse.** The green-CI check, the human test, and the
production double-confirmation run in **every** invocation. In
`release_flow=direct` the staging *stage* is absent, so its sign-off is
**inactive — not waived**; the human judgment it carried is preserved by the
**inline human-test approval** (`refs/production.md`), which fires **before the
merge**. Every other gate holds.

## Hard refusals

Shapes and JSON in `refs/refusal-patterns.md`. Merge:

- Does NOT merge on red or pending CI. When the check set is **empty** (nothing ran) and `policies.github_actions.enabled` is `false`, the CI stage is **inactive by the user's decision** — accepted silently with one report line naming the policy and `/msg --update` (`../shared/refs/policy-schema.md` §2b). The opt-out covers only the empty set; checks that *do* report are graded exactly as always.
- Does NOT run `--production` without staging-green **and** a `staging-signoff:` stamp whose pinned sha still covers `staging`'s tip — commits merged after sign-off refuse (`stale_signoff`), never ride along uncertified.
- Does NOT open or merge a `staging→main` PR without BOTH double-confirmation approvals.
- Does NOT run a second `--production` while one is in flight — the **release lock** refuses `release_in_flight` naming the holder (`refs/production.md` § *Release lock*, `../shared/refs/policy-schema-merge.md` §6). A `--staging` merge during an in-flight production ship refuses the same way: it would advance `staging` past the certified window.
- Does NOT run when `script-branch-protection.sh --verify` reports the branch unprotected **and** `branch_protection` resolves to `enforced` (the default / no-file case); `optional` warns + proceeds, `skip` doesn't verify (`../shared/refs/policy-schema-merge.md` §2). `NO_GH`/`NO_REMOTE` refuse regardless of mode.
- Does NOT run `--staging` into a staging environment `--init` recorded as **unready** when `staging_readiness` resolves to `enforced`; `optional` warns, `skip` doesn't guard, a **missing** record only warns (`../shared/refs/policy-schema-merge.md` §5, `refs/staging.md`).
- Does NOT report a deploy as shipped without running the platform's `smoke_cmd` against the deployed target (unconfigured → recorded as skipped with a note, `refs/verify-deploy.md`).
- Does NOT modify source code. Its complete, canonical write list is the next section — cited from elsewhere as this skill's hard-refusal enumeration.
- A failed ship is **not** a refusal — the merge already happened; merge writes the issues file and enters the **failed-ship loop** rather than dead-ending.

## Sanctioned writes — the canonical, complete enumeration

Merge does not modify source code. `../shared/refs/safety-floor.md`,
`refs/release-identity.md` and `refs/refusal-patterns.md` defer here; this is the
one copy:

1. the **two PR merges** (`--staging` feature→`stg`; `--production` `<head>`→`prod`);
2. the **`staging-signoff:` frontmatter stamp** — written by `--staging` on approval, re-stamped by `--production` Step 1 when an unpinned legacy stamp is confirmed;
3. the **`INTAKE.md` `status: completed` stamp** on each shipped PRD's mapped row (`--production`);
4. the **`status: done` frontmatter stamp** on each shipped PRD (`--production`, on a successful ship) — the terminal `eng → done` transition; the existing `reviewed:` / `staging-signoff:` stamps stay intact;
5. the **run report** (`report-prd-<N>-<K>.md`) and, on a failed ship, the colocated **issues file** (`report-prd-<N>-<K>.json`) that `eng --build report=` consumes;
6. the release **git tag** `v<x.y.z>+<build>` on prod at a successful `--production`;
7. the transient **release-lock tag** `release-lock-<prod>` around a `--production` ship;
8. the **move of a shipped PRD's folder** `features/wip/prd-<n>-<slug>/ → features/done/prd-<n>-<slug>/` — a whole-directory rename carrying the PRD plus its colocated `reports/`/`preflight.md`/`test/`.

Items 6–7 are **metadata on a commit** — they write no tracked file, so the
safety floor holds; the version source of truth is the tag, never a VERSION file
or bump commit. Item 8 renames a directory of docs/metadata and writes no source
code. Frontmatter stamps (2, 4) go through `.claude/scripts/script-prd-stamp.sh`, the
one proven writer — never a hand-rolled re-emit of the file.

**Script resolution (stated once — every ref uses this form):** a repo copy first,
the global install second — `S=.claude/scripts/<name>; [ -f "$S" ] || S="$HOME/.claude/scripts/<name>"`.

## Inputs / Outputs

| | Name | Source / Destination |
|--|------|----------------------|
| In | mode | `--staging` or `--production` (exactly one) |
| In | prd_paths | `--prd` (repeatable); else resolved from the PR head branch |
| In | pr | the open feature→staging PR (`--staging`) resolved via `gh pr list` |
| Out | staging_signoff | `staging-signoff: <YYYY-MM-DD>@<certified sha>` in PRD frontmatter — the staging commit that was deployed and human-tested |
| Out | human_test_script | printed + carried in the run report (`--staging`) |
| Out | release_pr | PR `<head>`→`main`, release-style body (`--production`) |
| Out | run_report | `report-prd-<N>-<K>.md` per `../shared/refs/report-schema.md` (`skill: merge`) |
| Out | verdict_json | on refusal / deploy failure — finding(s) per `refs/output-schema.md` |
| Out | issues_file | `features/prd-<N>-<slug>/reports/report-prd-<N>-<K>.json` on a failed ship — consumed by `eng --build report=` |

Finding shape: `../shared/refs/finding-schema.md` (source `merge`). Report: `../shared/refs/report-schema.md`.

## Pre-flight: policy file + `init` lifecycle (both modes)

Before Step 1 in **either** mode, resolve the policy **once, by script** —
`script-policy-read.py` is the read-side twin of `script-policy-set.py` and
resolves every `?? default` in one call, so no mode re-derives one in prose:

```bash
S=.claude/scripts/script-policy-read.py; python3 "$S"     # devkit/policy.json
```

It emits the full key set (the script's header is the key list) plus one `WARN=`
line per validation finding — surface each as one report note. **Fail-safe by
construction**: no file / malformed / `version` ≠ 1 → built-in defaults with
`POLICY_STATE` saying why, exit 0, so a policy read can never refuse a run. Emit
exactly one info line in those cases. Then check the `init` lifecycle gate
(`../shared/refs/policy-schema.md` §0).

| policy `init` state | action |
|---|---|
| file **absent** | built-in defaults + a one-line nudge to run `/msg --init` or `/merge --init`; **no** auto-init — proceed to Step 1 |
| `init: false` (or absent on a present file) | **auto-run `--init` inline first**; on completion it flips `init: true`, then continue. If the user **aborts** `--init`, stop — run **no** protocol step |
| `init: true` | proceed to Step 1 directly |

That one call is also where `release_flow`, `branch_protection`,
`staging_readiness`, `steps.*` and `github_actions` come from
(`GITHUB_ACTIONS` = the user's answer to whether GitHub Actions CI is wanted at
all, `../shared/refs/policy-schema.md` §2b) — no step re-reads the file. No gate
run ever *writes* `policy.json` — only `--init` does, and `--init` itself never
merges, opens PRs, or deploys (`refs/protocol-init.md`).

## Release flow (both modes)

Already resolved by the pre-flight call above (`../shared/refs/policy-schema.md`
§1): `flow = FLOW`, `prod = PROD_BRANCH`, `stg = STG_BRANCH`. No `policy.json` →
`staged`/`main`/`staging` everywhere.

| `flow` | `--staging` | `--production` |
|---|---|---|
| `staged` (default) | merge feature→`stg` | PR `stg`→`prod` |
| `direct` | **refuse** `no_staging_stage`, naming both `/merge --production` and `/msg --init-staging` | single ship feature→`prod`, preserving every human gate |

**`direct` + `--production`** — a single feature→`prod` ship that still runs the
double-confirmation, the **inline human-test approval** (asked before the merge),
the production deploy and smoke. The staging-scoped stages are **inactive**, not
relaxed: there is no staging to deploy, test, or sign off, so those questions do
not apply. Every question that *does* still apply is answered at full rigor.

**Fewer checks, never weaker ones.** Three states, never conflated:

| State | Meaning | Example |
|---|---|---|
| **inactive** | the stage does not apply to this configuration — there is nothing for it to check | staging deploy / staging smoke / staging human-test / `staging-signoff` under `release_flow=direct`; the **CI stage** under `github_actions.enabled:false` |
| **skipped** | the stage applies but its tooling is absent — recorded with a note, surfaced as a gap | no `smoke_cmd` configured for a platform |
| **relaxed** | a threshold was deliberately lowered by policy | `branch_protection: optional` warning instead of refusing |

`github_actions: {enabled:false}` uses the **inactive** column: no tooling the
user wanted is missing (not *skipped*) and no threshold moved (not *relaxed*).

**The safety floor is never inactive.** Security, migration, and the human
double-confirmation are not staging-scoped — no `release_flow` or
`github_actions` value deactivates them. A change that would move one of them
into the inactive column is a floor violation
(`../shared/refs/safety-floor.md`), not a configuration.

The staging-scoped set is named **once, here**; every ref defers to this section
rather than restating it.

## Release model (both modes)

Every shipping platform carries a `release_model` ∈ `deploy` | `submission`,
authored as a `devkit/PLATFORMS.md` column and resolved per platform by
`script-platforms-parse.py` — the **one** parser of that table, read by
`refs/deploy.md`, `refs/verify-deploy.md` and both protocols
(`../shared/refs/policy-schema-merge.md` §4). It is **orthogonal to
`release_flow`**: `release_flow` decides *which stages run*, `release_model`
decides *what a deploy/verify stage means* for each platform.

| `release_model` | Platforms (default) | Deploy exit 0 ⇒ | Verify | Report |
|---|---|---|---|---|
| `deploy` | web, macOS (direct-distributed), server | target is **live** | smoke the live target (`refs/verify-deploy.md`) | live |
| `submission` | iOS, Android, macOS on the Mac App Store | **submitted** to store review | submission accepted; a configured smoke is backend/build health | `submitted` (+ track) + monitor-handoff, **never** `live` |

Resolution is **per platform and independent**: a mixed repo verifies web as
live and iOS as submitted in the **same run**. `release_model_source` says which
happened — `declared` (the row said so) or `inferred` from the platform identity
with a `WARN`, never guessed silently. A macOS row is the one platform whose
identity does **not** settle it (direct download vs Mac App Store), so a macOS
row **declares** its model; an undeclared one falls back to `deploy` and carries
the macOS-specific warn naming the declaration as the fix. The full submission
lifecycle, the monitor-handoff, `completed`-on-submit and the submitted-not-live
rule live in `refs/submission.md` — the one home; nothing here restates them.

## Modes

Each mode's steps, order, and refusals live in its own ref. Load it and run it.

| Mode | Ref | Shape |
|---|---|---|
| `--staging` | `refs/staging.md` | protection → staging-readiness → in-flight-lock read → locate PR + green CI → merge → deploy → verify → human test script (STOP) → sign-off stamp on approval |
| `--production` | `refs/production.md` (+ `refs/release-identity.md`) | preconditions → protection → double-confirm → **inline human-test approval (`direct` flow)** → lock acquire → release PR → merge → deploy → verify + provenance → intake stamp → tag → PRD lane to `done` |
| `--init` | `refs/protocol-init.md` | detect + interview + write `devkit/policy.json`; no merge, PR, or deploy |

Both ship modes end by writing the run report (`skill: merge`) and printing
the terminal `Issue summary` block — every verdict, clean ships included (format
owned by `../shared/refs/report-schema.md`; counts derive from the run's
`findings[]`). On a failed ship, follow the loop below.

## Failed-ship loop

When a ship **fails** — a non-zero deploy or a verification failure, verdict
`fail`, in **either** mode — the merge already happened, so merge does not
dead-end. In order:

1. **Offer the rollback / rollout-halt — BEFORE the fix loop, always-ask, never
   auto.** The highest-value action after a broken ship is to restore last-good
   (deploy model) or halt the rollout (submission model). The failing platform's
   lever is already resolved — `script-platforms-parse.py` emits
   `<p>.rollback_lever_key` (which lever this model uses) and
   `<p>.rollback_lever` (the command; empty ⇒ unconfigured):
   - **`deploy` model with a configured `rollback_cmd`** → `AskUserQuestion`
     (header **Rollback**): "The `<platform>` `<staging|production>` deploy
     failed. Restore the last-good build now (`rollback_cmd`)?" — **Yes, roll
     back** runs the cmd and records its exit/outcome; **No, continue to fixes**
     proceeds. For a **`server`/backend platform, always carry this line with the
     offer**: *redeploying the last-good build does **not** revert schema
     migrations already applied — check the database state before and after.*
     Merge does not detect migrations; it states the caveat every time so
     the human is never surprised by a half-reverted release.
   - **`submission` model with a configured `rollout_halt_cmd`, once a rollout
     exists** (a `--production` submission in staged rollout / phased release —
     not `--staging`'s internal track, not a rejected-at-upload) →
     `AskUserQuestion` (header **Halt rollout**): "The `<platform>` rollout is
     live/pending (`<track>`). Halt the staged rollout / phased release now
     (`rollout_halt_cmd`)?" — halt ≠ full un-ship; the approved build stays out
     (`refs/submission.md`). If the rollout is not yet live, note the halt may
     need re-running once it begins.
   - **Unconfigured** (no lever, or a `[USER: …]` placeholder) → surface the
     `rollback_possible` note for manual restore and **flag the missing lever as
     a gap**. No offer is fabricated.
   - **Never auto-run** any lever — a false-positive smoke must not revert a good
     release. Under an autonomy contract with no human present, default to
     **decline** and record the offer as declined. Capture
     `{offered, lever, approved, cmd_exit, outcome}` per platform into the run
     report (`refs/output-schema.md`).
2. **Write the issues file** `features/prd-<N>-<slug>/reports/report-prd-<N>-<K>.json`
   — colocated in the PRD's `reports/` folder, sharing `N`/`K` with the run
   report (NO-PRD fallback: `features/reports/report-<K>.json`). Same canonical
   `issues[]` shape pre-merge writes (`followUp.status` camelCase contract kept —
   the key `eng --build` writes back and the `--gui` board reads).
   `followUp.suggested_command` = `eng --build report=<that path>`.
3. **Write the run report**, carrying the `## Issue summary` block and the
   rollback-offer outcome.
4. **Print the terminal `Issue summary` block.**
5. **Hand off to `../shared/refs/fix-loop.md`** — it owns Offer #1 (`eng --plan`)
   → Offer #2 (`eng --build`) off this issues file; do not re-spell that wording
   here. The rollback offer **precedes** this and never replaces it — a
   rolled-back release still has a broken commit to fix forward. **For
   `--production` the release lock releases at ship-terminal — after step 1,
   before this handoff — so the fix loop never holds the lock.**

The fixed branch comes back through `/pre-merge` and this gate.

## Closing message

End every run — both modes, every outcome including refusals and failed ships —
with the closing message per `../shared/refs/closing-message.md`, as the last
chat output after the mode's own emissions.

**Harness incidents (both modes):** log unexpected script failures, tool errors, retries, missed writes, and broken gate infrastructure (CI, deploy, protection) to `devkit/DOCTOR.md` per `../shared/refs/doctor-logging.md` — logging never changes what the run does next.

## References

- `refs/staging.md` — the `--staging` protocol
- `refs/production.md` — the `--production` protocol, incl. the release lock and the inline human-test approval
- `refs/protection.md` — branch-protection verify via `script-branch-protection.sh`
- `refs/protocol-init.md` — `--init`
- `refs/deploy.md` — per-platform deploy resolution from `devkit/PLATFORMS.md`
- `refs/verify-deploy.md` — post-deploy verification per `release_model`, the smoke v2 contract (one-shot / `watch_window` / `poll`), and the config-gated macOS notarization / signing / appcast checks
- `refs/release-identity.md` — version, build, provenance, tag
- `refs/submission.md` — the `submission` release model: the lifecycle, the monitor-handoff, submitted-not-live, `completed`-on-submit
- `refs/human-test-script.md` — deriving the staging human test script
- `refs/refusal-patterns.md` — refusal shapes and JSON
- `refs/output-schema.md` — finding/verdict emission
- `../shared/refs/policy-schema.md` — the shared core of `devkit/policy.json` (§0 `init`, §1 `release_flow`, §2b `github_actions`)
- `../shared/refs/policy-schema-merge.md` — merge's half: §2 `branch_protection`, `steps.<key>` + §3, §4 `release_model`, §5 `staging_ready`, §6 the release lock
- `../shared/refs/fix-loop.md`, `../shared/refs/finding-schema.md`, `../shared/refs/report-schema.md`, `../shared/refs/safety-floor.md`, `../shared/refs/status-heartbeat.md`
- `.claude/scripts/` — `script-branch-protection.sh` · `script-signoff-coverage.sh` · `script-release-lock.sh` · `script-release-identity.sh` · `script-prd-stamp.sh` · `script-intake-stamp.sh` (incl. `--find-row`, PRD id → ledger row)
- `.claude/scripts/` — the resolvers: `script-policy-read.py` (every policy mode + its `?? default`) · `script-ci-status.py` (PR resolution + the one CI verdict) · `script-platforms-parse.py` (the one `PLATFORMS.md` parse) · `script-smoke-run.sh` (the v2 smoke loops + the macOS checks) · `script-ts-miss.py` (test-selection-miss, CI-backstop half)
