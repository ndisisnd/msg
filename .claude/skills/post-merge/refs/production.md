---
name: post-merge-production
description: post-merge --production — the double-confirmed staging→main release. Preconditions (green staging + signoff stamp), two separate approvals, release-style PR, merge only on green CI + human review, production deploy, and per-release_model verification (smoke the live target for deploy platforms; submission-accepted + backend-health for submission platforms).
---

# `--production` — the double-confirmed release to main

Ships everything currently on `staging` to `main` (production). This is the
harness's single path to `main` — it is **always human-initiated** (the roadmap
orchestrator never invokes it) and its gates never relax, in any mode.

## Release identity (resolved early — `refs/release-identity.md`)

Before the double-confirm (so the human sees exactly what will be tagged), resolve
the release identity from the **last `v*` tag on prod** (the read-only source of
truth, D8):

- `CURRENT_TAG` = newest `v*` tag reachable on prod; `NEXT_VERSION` = default
  **minor** bump (overridable via `--bump` / `--version`); `BUILD` = commit count
  on prod (`git rev-list --count origin/$PROD`), monotonic by construction.
- These flow into: the Step 3 final-confirm (shows `v<x.y.z>+<build>`), the Step 6
  **build-number monotonicity** gate for `submission` platforms, the Step 7
  **provenance** check, and the post-success **tag** (Step 9).
- post-merge **never writes a VERSION file or a bump commit** — the only new write
  is the git tag at Step 9, which changes no tracked file (safety floor holds).

Full contract — bump rule, build derivation, provenance read, tag command, release
notes — in `refs/release-identity.md`.

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
> - **Version:** `v<NEXT_VERSION>+<BUILD>` (from `<CURRENT_TAG>`, `<bump-level>` bump — `refs/release-identity.md`) — this tag is cut on prod only on success
> - **PRDs:** `<prd-ids + features>`
> - **Commits:** `<git rev-list --count main..staging>` commits (`<short shas / titles>`)
> - **Platforms:** `<from devkit/PLATFORMS.md>`
> - **Rollback:** per-platform (Step 4) — iOS `IRREVERSIBLE`; the halt/redeploy lever is **offered on failure** (Step 7)
> Options: **Ship it** / **Cancel**

On Cancel → stop (`skipped`). Only **Ship it** proceeds. Never infer approval —
both asks must return an affirmative.

## Release lock (acquire after Step 3, release on every exit) — C8

A production ship is the one path that mutates `prod`. Two `--production` runs in
flight at once — two terminals, two teammates, or a retry over a still-running ship
— race on that branch: both open a `staging→main` PR, both merge, both deploy. The
lock serializes them. It applies to **`--production` in both flows** (`staged` *and*
`direct` — a `direct` feature→`prod` ship races on `prod` exactly the same way),
and it is **silent when uncontended**: an uncontended acquire + release adds no
prompt and no gate, so a solo dev shipping one release at a time never sees it
(AC-LK3). Friction appears **only** on a real collision.

### Mechanism — a remote git tag (`refs/release-identity.md` machinery, `../shared/refs/policy-schema.md` §6)

The lock is an **annotated git tag** `release-lock-<prod>` (e.g. `release-lock-main`)
pushed to the remote — the **same pushed-tag primitive P3's release tag already
uses** (D8): a tag is metadata on a commit, writes **no tracked file**, so the safety
floor holds. Storage is the **remote**, so the lock survives across machines
(the open question) — a teammate on another laptop sees the same lock. No committed
file (which would violate the source-write floor), no GitHub deployment/issue (no
atomic single-holder guarantee), no new credentials (it reuses the push post-merge
already does at Step 9).

**Atomic acquire.** A tag ref is never fast-forwarded — pushing a tag name the
remote already holds is **rejected** without `--force`. That rejection *is* the
compare-and-swap-to-absent: the push either creates the tag (you hold the lock) or
fails because someone else holds it. Acquire, then re-read to confirm you own it:

```bash
PROD=${prod_branch:-main}
LOCK="release-lock-$PROD"
# holder metadata rides in the annotated message → names the in-flight run (AC-LK1)
git tag -a "$LOCK" "origin/$PROD" -m "held-by: $(git config user.name) <$(git config user.email)>
mode: production
at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
sha: $(git rev-parse origin/$PROD)
prds: <prd ids this ship carries>"
if git push origin "$LOCK" 2>/tmp/lock.err; then
  :   # acquired — proceed to Step 4
elif grep -qiE 'already exists|non-fast-forward|rejected|stale info' /tmp/lock.err; then
  git tag -d "$LOCK"                      # drop the local tag; we did NOT acquire
  # read the holder off the existing remote tag → refuse release_in_flight (below)
else
  git tag -d "$LOCK"                      # infra/network error, not a contention
  # fail-open: one `low` note "lock not acquired (push error) — proceeding without
  # concurrency guard", then proceed. The lock is a safety ASSIST, not a floor; a
  # flaky network must not dead-end a legit solo ship (CV1).
fi
```

**Acquire happens here — after Step 3, before Step 4 — deliberately (AC-LK2, AC-LK3):**

- **Late enough** that no *pre-flight refusal* ever touches the lock: Step 1
  (`staging_not_green` / `no_signoff` / `stale_signoff`), Step 2 (`unprotected`),
  and a Step 3 double-confirm **Cancel** all exit *before* acquisition — those runs
  never acquire, so there is nothing to release and no friction on the common
  refusal paths (AC-LK3).
- **Early enough** to cover the whole mutating window: Step 4 (open release PR),
  Step 5 (the irreversible merge to `prod`), and Steps 6–9 (deploy/verify/stamp/tag)
  all run **inside** the lock. Two runs can both clear Step 3 concurrently (two humans
  each confirm); the acquire at the top of this window is what serializes them —
  first to push the tag proceeds, the second's push is rejected and it refuses
  `release_in_flight` naming the first (AC-LK1).

### If acquire is rejected → `release_in_flight` (`refs/refusal-patterns.md`)

Read the holder off the existing remote tag and refuse, naming who/when/sha:

```bash
git fetch origin "refs/tags/$LOCK:refs/tags/$LOCK" --force --quiet
git for-each-ref --format='%(contents)' "refs/tags/$LOCK"   # held-by / at / sha / prds
```

Emit `release_in_flight` (verdict `refused`, exits non-zero) with the holder in
`detail` + the additive `lock` block (`refs/output-schema.md`). This is a refusal,
not a failed ship — it fires **before** Step 4's sanctioned mutating action, so it
un-does nothing (`refs/refusal-patterns.md`).

### Staleness — bounded TTL, never a permanent dead-end

A lock older than **120 minutes (2h)** is **stale**. TTL rationale: the in-lock
window is merge + deploy + verify — the longest bounded async waits are macOS
notarization (~10m ceiling, C6) and the smoke `poll`/`watch_window` (C7), summed
with a slow local deploy; 2h clears that with wide margin, yet a lock alive past 2h
is almost certainly a **crashed or abandoned** run, not one still working. Read the
tagger date and compare:

```bash
LOCK_AGE=$(( $(date +%s) - $(git log -1 --format=%ct "refs/tags/$LOCK") ))
# LOCK_AGE > 7200  ⇒ stale
```

On a **stale** lock, do **not** blindly refuse forever and do **not** auto-steal
(auto-stealing re-opens the race). Report it as stale with the one-line manual
unlock and let the human decide (the CV1 escape hatch — a wedged lock must never
dead-end a solo dev):

> **Release lock is stale** — held by `<holder>` since `<at>` (> 2h ago), likely an
> aborted run. If no release is actually in flight, clear it and re-run:
> `git push origin :refs/tags/release-lock-<prod>`  (then `git tag -d release-lock-<prod>` locally)

### Release — unconditional, on every exit of a run that acquired it (AC-LK2)

**Invariant: any `--production` run that acquired the lock releases it as the last
action before its terminal output — on success, on a failed ship, and on a
refusal-after-acquire — with no exception path.** Release deletes the remote tag:

```bash
git push origin ":refs/tags/$LOCK" && git tag -d "$LOCK"   # release; failure → low note, tag TTL-expires anyway
```

Every exit path of `--production` **after acquisition**, and where the lock releases:

| # | Exit path (post-acquire) | Outcome | Lock release |
|---|---|---|---|
| 1 | Step 4 `gh pr create` errors | reported failure | **release**, then surface the error |
| 2 | Step 5 `red_ci` / `pending_ci` | refused | **release** before emitting the refusal |
| 3 | Step 5 `no_review` | refused | **release** before the refusal |
| 4 | Step 5 `merge_failed` | refused | **release** before the refusal |
| 5 | Step 6 `nonmonotonic_build` (before submit) | refused | **release** before the refusal |
| 6 | Step 6 deploy failure | failed ship (terminal) | **release** at ship termination (after the failed-ship loop) |
| 7 | Step 7 smoke / poll-timeout / watch-degrade / macOS-check / provenance failure | failed ship (terminal) | **release** at ship termination |
| 8 | Human declines the Step 7 rollback offer | still a terminal ship outcome | **release** at ship termination |
| 9 | Steps 6–9 all pass | success (tagged) | **release** after Step 9 |
| 10 | **Hard process kill** (SIGKILL / crash) between acquire and any release | dangling lock | **not** releasable by code — the **TTL (2h) + manual unlock** cover it (the one path graceful release cannot, by physics) |

Rows 2–5 are refusals that fire *after* acquisition — each releases the lock first,
so a refused release never leaves the lock dangling. Row 10 is the only path a
`finally`-style release cannot reach; it is exactly why the TTL + manual-unlock
escape hatch exists, and it is documented honestly rather than pretended away.
Record `{ref, acquired, acquired_at, released, released_at, stale_detected}` into
the run report's `release_lock` block (`refs/output-schema.md`).

## Step 4 — Open the release PR (staging → main)

```bash
gh pr create --base main --head staging --title "Release: <prds / date>" --body "<release body>"
```

Release-style body (this is what the GUI production report + the `main` PR
render from):

- **PRDs shipped** — one line per PRD (id · feature · linked `reports/report-*.md`).
- **Reports** — link each shipped PRD's staging report(s).
- **Commits** — `git log --oneline main..staging`.
- **Rollback notes — per platform**, from `devkit/PLATFORMS.md` `rollback_possible`.
  These notes are **documentation** in the release body (the *executable* lever is
  **offered on a failed ship** — Step 7 → the failed-ship loop's rollback offer,
  `SKILL.md`):
  | rollback_possible | note |
  |---|---|
  | `yes` | Rollback = redeploy the previous build (`rollback_cmd`). |
  | `limited` | Partial rollback — a lever exists but does not fully un-ship: `deploy` (macOS) → re-publish the prior build; `submission` (Android) → **halt the staged rollout** (`rollout_halt_cmd`) — stops further exposure, the approved build stays out. |
  | `no` | **IRREVERSIBLE** — an approved app-store release is permanent. The *phased release* can still be halted (`rollout_halt_cmd`) but the build is not recallable. Flag iOS here (default). |
  - Any platform with `rollback_possible: no` (iOS by default) is flagged **`IRREVERSIBLE`** in bold — the GUI surfaces this as a prominent badge/callout (H4). Android is `limited` (I6), not `no` — its staged-rollout halt is a real lever.

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

**Build-number monotonicity — `submission` platforms, checked BEFORE submit
(AC-RI3).** For each `submission`-model platform, compare the resolved `BUILD`
(release identity, above) against the build integer in `CURRENT_TAG`: `BUILD ≤
last_tag_build` → **refuse `nonmonotonic_build`** (`refs/refusal-patterns.md`)
before running its `production_deploy_cmd` — a store rejects a non-increasing build
number, so post-merge stops rather than pushing a doomed submission. `deploy`
platforms are not build-gated (`refs/release-identity.md`).

Then, per `refs/deploy.md` (`production_deploy_cmd` per platform). Run each
platform's command; capture logs. A deploy failure emits a `post-merge` finding
(`refs/output-schema.md`) and is reported — the merge already happened, so this
is surfaced, not silently swallowed. On a **deploy failure**, the failed-ship loop
runs — including the **rollback/rollout-halt offer** (`SKILL.md` § *Failed-ship
loop*) before the fix loop.

## Step 7 — Verify the deploy + provenance

Per `refs/verify-deploy.md`: run each platform's smoke against the deployed
production target — the **v2 smoke contract** (`smoke: {cmd, watch_window?, poll?}`):
a bare `smoke_cmd` is one-shot (unchanged); a declared `poll` waits for a late-live
target (CDN/DNS propagation, notarization, store processing) before the first
verdict, a declared `watch_window` re-checks health over a bounded window after it
passes and **fails the verdict if health degrades** (routing to the same
rollback offer below). Verified (or skipped-with-note) → continue. For a macOS
platform, the config-gated notarization / signing / appcast checks
(`refs/verify-deploy.md` § *macOS release checks*) run here too — each a distinct
finding (`notarization-stall` / `notarization-invalid` / `signing-fail` /
`appcast-stale`), silent when undeclared.

**Provenance (AC-RI2, `refs/release-identity.md`).** For each platform with a
declared `version_probe`, read the deployed/submitted artifact's source commit and
assert it is within the signed-off release (equals the certified sha, or is an
ancestor of prod). A probe commit **outside** the signed-off release → emit a
**provenance finding**, verdict `fail` (the artifact shipped was built from a
commit no human certified). No `version_probe` → provenance is `asserted
(unverified)` with a note, never a fail. A provenance `fail` skips Step 8 and the
tag, exactly like a smoke failure.

**Any verification failure** — a plain `smoke-failed`, a poll timeout
(`smoke-never-live`), a watch-window degrade, **or** a macOS release-check finding
(`notarization-stall` / `notarization-invalid` / `signing-fail` / `appcast-stale`) —
sets verdict `fail`, **skips Step 8** (a release that isn't verifiably live doesn't
close its PRD). The failed-ship loop then runs, and its **first action is the
rollback/rollout-halt offer** (`SKILL.md` § *Failed-ship loop*): with a configured `rollback_cmd`
(`deploy`) / `rollout_halt_cmd` (`submission`, once a rollout exists) post-merge
**offers to execute it** via `AskUserQuestion` *before* the fix loop, never auto
(D12, AC-RB1/RB3); unconfigured → the per-platform rollback notes
(`rollback_possible`, iOS `IRREVERSIBLE`) are surfaced for **manual** restore and
flagged as a gap (AC-RB2). The merge stands — never pretend to un-ship.

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

## Step 9 — Tag the release (AC-RI1, `refs/release-identity.md`)

Only on a **successful** release — the same success condition as Step 8 (merged +
deployed-or-skipped-with-note + verified-or-skipped-with-note, and provenance not
`fail`). Cut the annotated tag on the prod release commit with the generated
release notes, then push it:

```bash
git tag -a "v${NEXT_VERSION}+${BUILD}" "origin/$PROD" -m "<release notes from the shipping PRDs>"
git push origin "v${NEXT_VERSION}+${BUILD}"
```

- **This is the only new write C4 adds, and it touches no tracked file** — the tag
  is metadata on a commit, so the safety floor holds (D8). post-merge never writes a
  VERSION file, never makes a bump commit.
- A **failed** release (deploy/smoke/provenance `fail`) does **not** tag — an
  unverified release gets no version identity, mirroring the skipped Step 8 stamp.
- No remote / push rejected → **skip the tag with a note** (the release shipped;
  the tag is metadata), never a hard failure.
- Record `version` / `tag` / `build` / per-platform `provenance` in the clean-run
  summary (`refs/output-schema.md`).

## Run report

Write `report-prd-<N>-<K>.md` (`skill: post-merge`, production flavor) — release-style:

- `verdict: pass` on a clean release; `fail` if a production deploy errored, its smoke check failed, **or provenance mismatched** (Step 7).
- `## Release` — the resolved identity: `v<NEXT_VERSION>+<BUILD>` (tagged on success — Step 9; skipped-with-note or absent on a failed release), the bump level, and per-platform provenance (`verified` / `asserted (unverified)` / `fail`) (`refs/release-identity.md`). On a failed ship, also carry the **rollback offer outcome** (offered/executed/declined + cmd exit) surfaced by the failed-ship loop (`refs/output-schema.md`). If a **stale lock** was reported and cleared this run, carry the `low` note; a clean uncontended acquire/release adds nothing here (silent — AC-LK3).
- `## Work done` — PRDs shipped, commit count, platforms deployed. **Under `release_flow=direct`, open with one `Stages` line** naming what did not run and why, so the reduced set is visible rather than invisible (AC-NS1):
  `Stages: staging deploy · staging smoke · staging human-test · staging sign-off — **inactive (no staging)**. All applicable stages ran at full rigor.`
  Never render these as *skipped* (that means tooling was missing) or *relaxed* (that means a threshold was lowered). In `staged` flow the line is omitted entirely.
- `## Test results` — one line per platform: verified / smoke-failed / skipped (no `smoke_cmd`), per `refs/verify-deploy.md`.
- `## What to expect` — **per `release_model`** (`../shared/refs/policy-schema.md` §4): `deploy` platforms — production is live; `submission` platforms — carry the **full monitor-handoff block** (AC-SB3, `refs/submission.md` § *Monitor-handoff*): submitted to `<track>` at `<submitted_at>`, **now in Apple App Store / Google Play review, not yet live to users**, monitor at **App Store Connect** / **Google Play Console**, halt via `rollout_halt_cmd`. Never report a `submission` platform as live (AC-RM3/AC-SB1), and never reduce it to a bare "submitted-not-live" — the human needs the monitor pointer + halt lever. **Rollback notes per platform, iOS `IRREVERSIBLE` surfaced prominently** (keep the literal token `IRREVERSIBLE` in the body — the GUI renders a callout when it's present).
- `## Links` — the release PR, the merge commit, per-platform deploy logs.
