---
name: post-merge-staging
description: post-merge --staging — locate the feature→staging PR, verify green CI, merge into staging, verify the deploy with the platform smoke check, and stamp the harness-readable staging sign-off (D11). Deploy, verification, and the human test script have their own refs.
---

# `--staging` — merge to staging, hand off to a human

Runs after `/pre-merge` opened a `feature → staging` PR. Post-merge merges it on
green CI, deploys, verifies the deploy with the platform's smoke check, hands a
human a test script, and — only on the human's explicit approval — stamps the
sign-off that `--production` requires. Post-merge **never self-certifies
staging**: Step 6 STOPS and waits for a human.

## Step 1 — Branch protection

Per `refs/protection.md`: `post-merge-protection.sh --verify staging`. Anything
but `PROTECTED staging` refuses (`refs/refusal-patterns.md` → `unprotected`).

## Staging-readiness guard (pre-flight, after Step 1)

Before locating the PR, read the `staging_ready` record `--init` wrote
(`../shared/refs/policy-schema.md` §5) — verify staging is a **real environment**,
not just a branch. Resolve `mode = policies.staging_readiness.mode ?? "enforced"`
(mirrors `branch_protection`'s stance + default). Then:

- **Record absent** (pre-C9 init, or the repo was never `/post-merge --init`ed) →
  add **one `low` note** to the run report — *"staging readiness was never
  recorded; run `/post-merge --init` to verify the staging environment"* — and
  **proceed**. Never refuse solely because the record predates C9.
- **Present, every shipping platform `ready:true`** → proceed silently.
- **Present, any platform with `gaps[]`:**
  - `enforced` → **refuse** (`refs/refusal-patterns.md` → `staging_unready`),
    listing each unready platform's gaps and its exact fix verbatim from the
    record. The merge has not happened yet — refusing here is the whole point:
    surface the gap before deploying into an environment that was never set up.
  - `optional` → **warn + proceed**, one `low` note per unready platform.
  - `skip` → don't guard (record "staging-readiness check skipped by policy").

This guard only bites under `release_flow=staged`; in `direct` flow `--staging`
has already refused `no_staging_stage` (there is no staging to check).

## In-flight-production check (pre-flight, before Step 2) — C8

A `--staging` merge lands new commits on `staging` **while** a `--production` run
may be mid-flight — the exact race the release lock names. If a production ship has
already opened its `staging→main` PR (Step 4) and is between merge and verify,
merging into `staging` now advances the branch the release is shipping: the PR
silently grows past what the human double-confirmed, and past the commit the
sign-off certified — **reopening C2's uncertified-commit hole at the concurrency
level**. So `--staging` **reads** the production release lock and refuses if one is
held (`../shared/refs/policy-schema.md` §6):

```bash
PROD=${prod_branch:-main}; LOCK="release-lock-$PROD"
git fetch origin "refs/tags/$LOCK:refs/tags/$LOCK" --force --quiet 2>/dev/null
git rev-parse -q --verify "refs/tags/$LOCK" >/dev/null   # exists ⇒ a production release holds the lock
```

- **Lock held, not stale** (age ≤ 2h) → **refuse** `release_in_flight`
  (`refs/refusal-patterns.md`), naming the in-flight production run (holder/when/sha
  from the tag message). The merge has not happened — refusing here keeps the
  running release's certified window intact. Wait for it to finish, then re-run.
- **Lock held, stale** (age > 2h) → same stale handling as `--production`: report it
  as stale with the one-line manual unlock, never a blind permanent refusal.
- **No lock** → proceed to Step 2.

**Asymmetric by design:** `--staging` **reads** the lock but never **acquires** one.
A staging merge (a single `gh pr merge`) is near-atomic — the reverse window (a
production ship starting mid-staging-merge) is sub-second and not worth the machinery
or the friction (AC-LK3). The production ship is the long-lived hold; it is the only
acquirer.

## Step 2 — Locate the PR + verify green CI

1. Resolve the feature branch: from `--prd`'s `feat/prd-<n>-<slug>`, else the current branch, else the single open `--base staging` PR.
2. Find the PR:
   ```bash
   gh pr list --base staging --head "<feature-branch>" --state open \
     --json number,headRefName,url,statusCheckRollup --limit 1
   ```
   No open PR → refuse (`no_pr`) — pre-merge hasn't opened one, or it already merged.
3. **Verify CI is green.** Branch protection is the machine enforcement; this is
   post-merge's own check so it can refuse with a clear reason rather than a raw
   merge rejection. Inspect `statusCheckRollup` (or
   `gh pr checks <number> --json name,state`):
   - Any check `state` in `FAILURE`/`ERROR`/`CANCELLED` → refuse (`red_ci`), listing each failing check name.
   - Any check still `PENDING`/`IN_PROGRESS`/`QUEUED` → refuse (`pending_ci`), listing the pending checks. Do not wait/poll — the human re-runs post-merge when CI settles.
   - **Empty check set** (the PR reports *zero* checks — no CI pipeline ran) → don't treat "no red" as green. Resolve `steps.ci` from `devkit/policy.json` per `policy-schema.md` §3: `ready` → emit one `low` `vacuous-ci` note (a workflow was expected but nothing ran — likely a broken or missing `.github/workflows/` pipeline; run `/pre-merge --init`) and proceed; `opted_out`/`n/a` → the empty set is intentional, proceed silently; `missing`/`deferred`/absent → proceed as today. Never blocks the merge — branch protection is the enforcement.
   - All `SUCCESS`/`NEUTRAL`/`SKIPPED` → proceed.

## Step 3 — Merge into staging

This is post-merge's sanctioned merge power (the pre-merge floor forbids it for
every other skill):

```bash
gh pr merge <number> --merge --delete-branch=false
```

Use `--merge` (a real merge commit — preserves the feature history on staging);
never `--squash`/`--rebase` unless the user asks. On merge failure (protection
rejected it, conflict) → refuse (`merge_failed`) with gh's message. Record the
merge commit sha.

**This sha is the certified sha.** It is what Step 4 deploys, what the human
tests in Step 6, and what Step 7 pins the sign-off to. Resolve it once, in full
40-char form, and carry it through the run:

```bash
git fetch origin staging --quiet
CERTIFIED_SHA=$(git rev-parse origin/staging)   # == the merge commit just created
```

## Step 4 — Deploy staging

Per `refs/deploy.md` (`staging_deploy_cmd` from `devkit/PLATFORMS.md`).

## Step 5 — Verify the deploy

Per `refs/verify-deploy.md`: run each platform's smoke against the deployed staging
target — the **v2 smoke contract** (`smoke: {cmd, watch_window?, poll?}`): a bare
`smoke_cmd` is one-shot (unchanged); a declared `poll` waits for a late-live target
first, a declared `watch_window` re-checks health after it passes. Verified (or
skipped-with-note) → continue. **Any smoke failure** — a plain non-zero, a poll
timeout (`smoke-never-live`), or a watch-window degrade — emits the finding, sets
verdict `fail`, and **stops here** — skip Steps 6–7. Never hand a human a test
script for an environment that is already failing its own health check; the report
points at fixing forward via `/pre-merge` (the merge stands). For a macOS platform,
the config-gated notarization / signing / appcast checks (`refs/verify-deploy.md`
§ *macOS release checks*) run here too — each a distinct finding, silent when
undeclared.

## Step 6 — Human test script + STOP

Per `refs/human-test-script.md`. Emit the script and **stop the autonomous
flow** — a human must exercise staging. Post-merge does not proceed to Step 7 on
its own.

## Step 7 — Stamp the sign-off (on explicit approval)

Only after the human returns. Ask once:

> `AskUserQuestion` — header **Staging**, question "Did staging pass your testing?"
> - **Staging works** — stamp the sign-off and finish
> - **Not yet** — leave unstamped; re-run `--staging` (or fix + re-gate) later

On **Staging works**, stamp the PRD frontmatter (the harness-readable half of
D11 — `--production` Step 1 reads it, the GUI ladder reads it):

- Key: `staging-signoff`, value: `<YYYY-MM-DD>@<sha>` — today's date **and the
  certified sha** (Step 3's `CERTIFIED_SHA`, full 40 chars). The sha is what
  makes the stamp verifiable: `--production` Step 1 refuses if `staging` has
  advanced past every stamped sha, so commits merged after sign-off cannot ride
  to production uncertified (AC-SO1).
- Idempotent: if the key exists, overwrite its value; else append it inside the `---` frontmatter block.
- Write only the frontmatter line — never touch the PRD body.

```bash
# resolve both halves once
SIGNOFF_DATE=$(date -u +%Y-%m-%d)
SIGNOFF="${SIGNOFF_DATE}@${CERTIFIED_SHA}"       # CERTIFIED_SHA from Step 3
```

Frontmatter edit shape (preserve every other line verbatim):

```yaml
staging-signoff: 2026-07-13@4f2c9a1e8b7d6c5a4938271605f4e3d2c1b0a9f8
```

**Never stamp a sha other than the one that was deployed and tested.** If
`git rev-parse origin/staging` no longer equals `CERTIFIED_SHA` at stamp time,
something landed on `staging` during the human's test window: still stamp
`CERTIFIED_SHA` (that is what the human actually tested) and add a `low` note to
the run report naming the commits that arrived after it — they are uncertified
and `--production` will say so.

On **Not yet**, do not stamp; note it in the run report and stop.

## Run report

Write `report-prd-<N>-<K>.md` (`../shared/refs/report-schema.md`, `skill: post-merge`)
to the PRD's `reports/` dir. Staging flavor:

- `verdict: pass` when merged + (deployed or deploy-skipped-with-note) + (smoke verified or verify-skipped-with-note); `fail` on a smoke failure (Step 5); `n/a` if it refused before merging.
- Body `## Test results` — one line per platform: verified / smoke-failed / skipped (no `smoke_cmd`), per `refs/verify-deploy.md`.
- Body `## What to expect` — per `release_model`: `deploy` platforms — staging is live at the deploy target; `submission` platforms — **submitted to the internal/TestFlight track, not "live"** (`refs/submission.md`). Production still gated on sign-off + double-confirm.
- Body `## How to verify` — **the human test script verbatim** (Step 6) so the GUI Reports tab surfaces it.
- `## Links` — the merged PR, the merge commit, the deploy log/target, the smoke log.
