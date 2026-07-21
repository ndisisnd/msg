---
name: post-merge-production
description: post-merge --production — the double-confirmed staging→main release. Preconditions (green staging + signoff stamp), two separate approvals, release-style PR, merge only on green CI + human review, production deploy, and per-release_model verification (smoke the live target for deploy platforms; submission-accepted + backend-health for submission platforms).
---

# `--production` — the double-confirmed release to main

Ships everything currently on `staging` to `main` (production). This is the
harness's single path to `main` — it is **always human-initiated** (the roadmap
orchestrator never invokes it) and its gates never relax, in any mode.

## Step 1 — Preconditions (refuse without all three)

For each `--prd` (or every PRD with a merged feature→staging PR since the last release):

1. **Staging CI is green.** Check the latest CI on `staging` (`gh api repos/{owner}/{repo}/commits/staging/status` or `gh run list --branch staging --limit 1`). Not green → refuse (`staging_not_green`).
2. **`staging-signoff:` stamp present** in the PRD frontmatter (stamped by `--staging` Step 7, D11). Missing → refuse (`no_signoff`) — a human has not signed staging off; run `--staging` first.
3. **The sign-off covers what is about to ship** (§ *Sign-off coverage* below). Staging advanced past every stamped sha → refuse (`stale_signoff`).

All missing/failing conditions refuse before any question is asked.

### Sign-off coverage (the commit pin)

A stamp is `staging-signoff: <YYYY-MM-DD>@<sha>` — the sha is the staging commit
the human actually tested (`--staging` Step 3/7). A bare date proves only that
*someone signed off once*; it cannot prove that nothing landed on `staging`
afterwards. The pin closes that hole.

```bash
git fetch origin staging --quiet
STAGING_HEAD=$(git rev-parse origin/staging)
```

Collect each PRD's `staging-signoff` sha (resolve any **unpinned** stamps first —
see below — so the set is fully pinned before these checks run), then:

| Check | Rule | On failure |
|---|---|---|
| **Ancestry** | every stamped sha is an ancestor of (or equal to) `STAGING_HEAD` — `git merge-base --is-ancestor <sha> $STAGING_HEAD` (exit 0 = ok; a sha is its own ancestor, so equality passes) | refuse (`stale_signoff`) — the stamp certifies a commit that is not on `staging` (force-push / rewritten history); name the PRD and its sha |
| **Coverage** | `STAGING_HEAD` equals **at least one** stamped sha in the release set | refuse (`stale_signoff`) — list the uncertified commits (`git log --oneline $NEWEST..$STAGING_HEAD`) and name the PRD(s) owning them, each of which needs its own `/post-merge --staging` sign-off |

`$NEWEST` — the **topologically newest** stamped sha: the one every other stamped
sha is an ancestor of. It is defined independently of whether coverage passed
(that is the whole point — on failure no stamp equals the tip, so "newest" cannot
be defined by equality):

```bash
NEWEST=$(git rev-list --topo-order --no-walk $ALL_STAMPED_SHAS | head -1)
```

Ancestry having already passed, every stamp is on `staging`'s first-parent
history, so this total order is well defined. If it somehow is not (stamps on
divergent lines — only reachable via a rewrite that ancestry should have caught),
refuse `stale_signoff` rather than guessing which stamp is newest.

**Why coverage and not per-PRD equality.** A multi-PRD release stamps each PRD at
*its own* merge sha, so older stamps legitimately lag `STAGING_HEAD`. What must
hold is that the **newest** sign-off is the tip: every commit on `staging` is at
or below a sha a human certified. Requiring every stamp to equal the tip would
refuse almost every multi-PRD release; requiring none would let post-sign-off
commits ride to production — which is exactly the hole being closed.

**Unpinned (legacy) stamp.** A stamp with no `@<sha>` predates the pin. Do not
refuse — the PRD's feature→staging PR is already merged, so `--staging` cannot be
re-run to produce a pinned stamp, and refusing would dead-end the release. Ask
once instead:

> `AskUserQuestion` — header **Sign-off**, question "This PRD's sign-off is
> unpinned (no commit recorded). Staging is now at `<short STAGING_HEAD>`. Does
> staging still pass your testing at this commit?"
> - **Yes, staging works** — re-stamp `<today>@<STAGING_HEAD>` and continue
> - **Cancel** — stop (`skipped` / `signoff_declined`)

The human gate is preserved, not waived. Record a `low` `unpinned-signoff` note
in the run report either way.

**`direct` flow** (`release_flow.mode = direct`) — this whole step is **inactive**,
not waived: there is no staging, so there is no sign-off to check and nothing to
pin. Record it as `inactive (no staging)` in the run report, never as skipped or
relaxed (`SKILL.md` § *Release flow*; AC-RF3, AC-SO3, AC-NS1/NS4). The human
judgment the sign-off represents is **not** dropped — it moves to the inline
human-test approval before the production deploy, which is active in this flow.

A `submission`-model platform under `direct` flow (a mobile repo with no staging)
still runs the **full submission lifecycle** on the single feature→`prod` ship
(submit → accepted → monitor-handoff, `refs/submission.md` § *Submission in
`direct` flow*) — `release_model` is orthogonal to `release_flow`. The
staging-scoped stages are inactive, but the double-confirmation (Step 3) and the
inline human-test approval remain active (CV5).

## Step 2 — Branch protection

Per `refs/protection.md`: `post-merge-protection.sh --verify main`. Anything but
`PROTECTED main` refuses (`unprotected`). `main` protection additionally
requires ≥1 approving review (the machine-enforced half of D11).

## Step 3 — Double-confirmation (two separate asks)

Two **separately-asked** `AskUserQuestion` calls — never one combined question,
never a single multiSelect. The first gates the second.

**Ask A — intent:**

> header **Release**, question "Ship staging to production (main)?"
> - **Yes, proceed** — continue to the final confirmation
> - **Cancel** — stop; nothing ships

On Cancel → stop (verdict `skipped`, no findings).

**Ask B — final confirm (only after Ask A = Yes).** List *exactly what ships*,
computed from `staging..main`:

> header **Confirm release**, question "Confirm — this ships to production:"
> - **PRDs:** `<prd-ids + features>`
> - **Commits:** `<git rev-list --count main..staging>` commits (`<short shas / titles>`)
> - **Platforms:** `<from devkit/PLATFORMS.md>`
> - **Rollback:** per-platform (Step 4) — iOS `IRREVERSIBLE`
> Options: **Ship it** / **Cancel**

On Cancel → stop (`skipped`). Only **Ship it** proceeds. Never infer approval —
both asks must return an affirmative.

## Step 4 — Open the release PR (staging → main)

```bash
gh pr create --base main --head staging --title "Release: <prds / date>" --body "<release body>"
```

Release-style body (this is what the GUI production report + the `main` PR
render from):

- **PRDs shipped** — one line per PRD (id · feature · linked `reports/report-*.md`).
- **Reports** — link each shipped PRD's staging report(s).
- **Commits** — `git log --oneline main..staging`.
- **Rollback notes — per platform**, from `devkit/PLATFORMS.md` `rollback_possible`:
  | rollback_possible | note |
  |---|---|
  | `yes` | Rollback = redeploy the previous build. |
  | `limited` | Partial rollback — see the platform's notes. |
  | `no` | **IRREVERSIBLE** — shipped is permanent (app-store review). Flag iOS/Android here. |
  - Any platform with `rollback_possible: no` (iOS by default) is flagged **`IRREVERSIBLE`** in bold — the GUI surfaces this as a prominent badge/callout (H4).

## Step 5 — Merge on green CI + human review

Branch protection enforces both; post-merge checks them, then merges:

1. Verify the release PR's CI is green (same `statusCheckRollup` check as `--staging` Step 2). Red/pending → refuse (`red_ci`/`pending_ci`).
2. Verify the required human review is present: `gh pr view <n> --json reviewDecision` → must be `APPROVED`. Not approved → refuse (`no_review`) — branch protection would reject the merge anyway; refuse cleanly with that reason.
3. Merge:
   ```bash
   gh pr merge <number> --merge
   ```
   Merge failure → refuse (`merge_failed`).

## Step 6 — Production deploy

Per `refs/deploy.md` (`production_deploy_cmd` per platform). Run each platform's
command; capture logs. A deploy failure emits a `post-merge` finding
(`refs/output-schema.md`) and is reported — the merge already happened, so this
is surfaced, not silently swallowed.

## Step 7 — Verify the deploy

Per `refs/verify-deploy.md`: run each platform's `smoke_cmd` against the deployed
production target. Verified (or skipped-with-note) → continue to Step 8. **Smoke
failure** → emit the `smoke-failed` finding, set verdict `fail`, **skip Step 8**
(a release that isn't verifiably live doesn't close its PRD), and surface the
per-platform rollback notes (`rollback_possible`, iOS `IRREVERSIBLE`) prominently
in the report so the human can restore manually. The merge stands — never pretend
to un-ship.

## Step 8 — Stamp the intake ledger `completed` (D14/F4)

Only on a verified (or verify-skipped-with-note) deploy — Step 7's smoke failure
skips this stamp. Close the loop for each shipped PRD. Read `INTAKE.md`
(repo root); for every shipped PRD, find the row whose `prd` cell matches this
PRD's id (`prd-<n>-<slug>`, as stamped by `plan-pm` at F4) and set that row's
`status` cell to `completed` via `Bash` — edit only that row's status cell,
preserving every other row verbatim. This is the terminal lifecycle transition
(`backlog` → `in-progress` → `completed`), and it makes the `/msg --gui` Intake
tab render the idea as shipped. Missing `INTAKE.md`, or a PRD whose `prd` cell
matches no row → **skip that PRD with a one-line note** in the run report (an
unmapped or no-intake-ancestor PRD is not an error).

**`submission` platforms — `completed` stamps on submit (D2/AC-SB4).** For a
`submission`-model PRD, "verified deploy" means submission accepted (Step 7), so
this stamp fires **on submit** — the pipeline's last controllable moment. It is
**not** deferred until the app is live to users, which would require store-status
polling post-merge does not do. Whenever this stamp closes a `submission` PRD, the
run report must carry the note that **live-to-users is downstream and out-of-band**
(store review + rollout), pointing at the monitor-handoff (§ *What to expect*;
`refs/submission.md`). Stamp-on-submit + honest note — never a silent "shipped =
live".

## Run report

Write `report-prd-<N>-<K>.md` (`skill: post-merge`, production flavor) — release-style:

- `verdict: pass` on a clean release; `fail` if a production deploy errored **or its smoke check failed** (Step 7).
- `## Work done` — PRDs shipped, commit count, platforms deployed. **Under `release_flow=direct`, open with one `Stages` line** naming what did not run and why, so the reduced set is visible rather than invisible (AC-NS1):
  `Stages: staging deploy · staging smoke · staging human-test · staging sign-off — **inactive (no staging)**. All applicable stages ran at full rigor.`
  Never render these as *skipped* (that means tooling was missing) or *relaxed* (that means a threshold was lowered). In `staged` flow the line is omitted entirely.
- `## Test results` — one line per platform: verified / smoke-failed / skipped (no `smoke_cmd`), per `refs/verify-deploy.md`.
- `## What to expect` — **per `release_model`** (`../shared/refs/policy-schema.md` §4): `deploy` platforms — production is live; `submission` platforms — carry the **full monitor-handoff block** (AC-SB3, `refs/submission.md` § *Monitor-handoff*): submitted to `<track>` at `<submitted_at>`, **now in Apple App Store / Google Play review, not yet live to users**, monitor at **App Store Connect** / **Google Play Console**, halt via `rollout_halt_cmd`. Never report a `submission` platform as live (AC-RM3/AC-SB1), and never reduce it to a bare "submitted-not-live" — the human needs the monitor pointer + halt lever. **Rollback notes per platform, iOS `IRREVERSIBLE` surfaced prominently** (keep the literal token `IRREVERSIBLE` in the body — the GUI renders a callout when it's present).
- `## Links` — the release PR, the merge commit, per-platform deploy logs.
