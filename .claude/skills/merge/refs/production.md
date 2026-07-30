---
name: merge-production
description: merge --production — the double-confirmed release to prod. Preconditions (green staging + a sign-off that still covers the tip), two separate approvals, the direct-flow human-test attestation before the merge, the release lock, a release-style PR, merge only on green CI + human review, production deploy, and per-release_model verification.
---

# `--production` — the double-confirmed release to prod

Ships everything currently on the release head to `prod`. This is the harness's
single path to `prod` — **always human-initiated** (no orchestrator invokes it)
and its gates never relax, in any mode.

Every deterministic check here is **scripted, not reasoned**. Each emits
`key=value` lines the protocol below reads; none of them is re-derived by hand:

```bash
S=.claude/scripts/script-signoff-coverage.sh   # coverage verdict + uncertified commits
S=.claude/scripts/script-release-lock.sh       # acquire | release | status
S=.claude/scripts/script-release-identity.sh   # tag, version, build, monotonicity, provenance
S=.claude/scripts/script-ci-status.py          # the CI verdict (Steps 1 + 5)
S=.claude/scripts/script-policy-read.py        # every policy mode + its `?? default`
S=.claude/scripts/script-platforms-parse.py    # PLATFORMS.md → per-platform key=value
S=.claude/scripts/script-smoke-run.sh          # the v2 smoke loops + macOS checks
S=.claude/scripts/script-intake-stamp.sh --find-row   # PRD id → ledger row # (Step 8)
```

(Resolution form — repo copy first, global install second — is stated once in
`SKILL.md` § *Sanctioned writes*.)

## Release identity (resolved early)

Before the double-confirm, so the human sees exactly what will be tagged:

```bash
bash "$S" --prod "$PROD" [--bump <level>] [--version <x.y.z>]
```

Read `CURRENT_TAG`, `NEXT_VERSION`, `BUILD`, `NEXT_TAG`. `VERDICT=version_regression`
(exit 3) → refuse `version_regression` (`refs/refusal-patterns.md`) — resolved
here, **before** the lock is acquired, so a bad `--version` never touches it.

This early read is a **preview**: the merge commit does not exist yet. The
**authoritative** `BUILD` comes from re-running the same script after the Step-5
merge + fetch (Step 5), because the tag must encode tag-time truth. The preview
feeds the Step-3 confirm; the recompute feeds the Step-6 monotonicity gate, the
Step-7 provenance read, and the Step-9 tag.

merge **never writes a VERSION file or a bump commit** — the only new write
is the git tag at Step 9, which changes no tracked file. Full contract:
`refs/release-identity.md`.

## Step 1 — Preconditions (refuse without all three)

For each `--prd` (or every PRD with a merged feature→staging PR since the last release):

1. **Staging CI is green** — the same scripted verdict `--staging` Step 2 runs, in branch mode:
   ```bash
   S=.claude/scripts/script-ci-status.py; python3 "$S" --branch "$STG"
   ```
   `green` (0) → proceed. `red`/`pending` (3/4) → refuse (`staging_not_green`), quoting `FAILING_CHECKS`/`PENDING_CHECKS`. `empty-inactive` (5) → the precondition is **inactive**: proceed, recording `NOTE` when it is non-empty. `empty-vacuous` (6) → proceed + the `low` `vacuous-ci` note. The script owns the empty-set branch (`github_actions` outranking `steps.ci`), so a real failing or in-flight status still refuses whatever `ga` says.
2. **`staging-signoff:` stamp present** in the PRD frontmatter. Missing → refuse (`no_signoff`) — a human has not signed staging off; run `--staging` first.
3. **The sign-off still covers what is about to ship** (below). Staging advanced past every stamped sha → refuse (`stale_signoff`).

All missing/failing conditions refuse before any question is asked.

### Sign-off coverage (the commit pin)

A stamp is `staging-signoff: <YYYY-MM-DD>@<sha>` — the sha is the staging commit
the human actually tested. A bare date proves only that *someone signed off
once*; it cannot prove nothing landed afterwards. The pin closes that hole, and
the script decides it:

```bash
bash "$S" --fetch --head "origin/$STG" --stamp <prd-id>=<sha> [--stamp …]
```

| `VERDICT` (exit) | Meaning | Do |
|---|---|---|
| `covered` (0) | the newest stamp **is** the tip | proceed |
| `stale_signoff` (3) | `REASON=not_ancestor` (a stamp is not on `staging` — rewritten history) · `head_ahead` (commits landed after the newest sign-off) · `no_newest` (stamps on divergent lines) | refuse `stale_signoff` |
| `unpinned` (4) | a legacy stamp carries no sha | the human re-ask below |
| `no_stamps` (5) | nothing pinned | refuse `no_signoff` |

On `head_ahead` the script emits `UNCERTIFIED_COUNT`, `UNCERTIFIED_SHAS` and the
oneline commit list as comment lines. The refusal quotes them and gives **both**
exits, so it never dead-ends: (a) if the owning PRD is already signed off and its
stamp merely lags the tip, **add `--prd <owning PRD>`** to fold it into this
release; (b) if the commits are genuinely un-signed-off, run **`/merge
--staging`** for only that work. Never order a bare `--staging` re-run for a PRD
whose feature→staging PR already merged — it would refuse `no_pr`.

**Why coverage and not per-PRD equality.** A multi-PRD release stamps each PRD at
*its own* merge sha, so older stamps legitimately lag the tip. What must hold is
that the **newest** sign-off is the tip: every commit on `staging` is at or below
a sha a human certified. Requiring every stamp to equal the tip would refuse
almost every multi-PRD release; requiring none would let post-sign-off commits
ride to production.

**Unpinned (legacy) stamp — the one judgment half.** A stamp with no `@<sha>`
predates the pin. Do not refuse: the PRD's feature→staging PR is already merged,
so `--staging` cannot be re-run to produce a pinned stamp, and refusing would
dead-end the release. Ask once instead:

> `AskUserQuestion` — header **Sign-off**, question "This PRD's sign-off is
> unpinned (no commit recorded). Staging is now at `<short STAGING_HEAD>`. Does
> staging still pass your testing at this commit?"
> - **Yes, staging works** — re-stamp and continue
> - **Cancel** — stop (`skipped` / `signoff_declined`)

On **Yes**, re-stamp via the shared writer, then re-run the coverage script with
the now-pinned set:

```bash
S=.claude/scripts/script-prd-stamp.sh; bash "$S" <prd-path> staging-signoff "<today>@<STAGING_HEAD>"
```

Record a `low` `unpinned-signoff` note in the run report either way.

**`direct` flow** — this whole step is **inactive**, not waived: there is no
staging, so there is no sign-off to check and nothing to pin. Record it as
`inactive (no staging)` in the run report, never as skipped or relaxed
(`SKILL.md` § *Release flow*). The human judgment the sign-off represents is not
dropped — it moves to the **inline human-test approval** below, which fires
before the merge.

A `submission`-model platform under `direct` flow still runs the full submission
lifecycle on the single feature→`prod` ship (`refs/submission.md`) —
`release_model` is orthogonal to `release_flow`.

## Step 2 — Branch protection (policy-conditional)

Per `refs/protection.md` + `../shared/refs/policy-schema-merge.md` §2:
resolve `mode_main`, run `script-branch-protection.sh --verify main`, and read the
outcome against that mode (`enforced` refuses `unprotected`; `optional` warns +
proceeds; `skip` doesn't verify; `NO_GH`/`NO_REMOTE` refuse regardless). Under
`enforced`, `main` protection additionally requires ≥1 approving review.

## Step 3 — Double-confirmation (two separate asks)

Two **separately-asked** `AskUserQuestion` calls — never one combined question,
never a single multiSelect. The first gates the second.

**Ask A — intent:**

> header **Release**, question "Ship staging to production (main)?"
> - **Yes, proceed** — continue to the final confirmation
> - **Cancel** — stop; nothing ships

On Cancel → stop (verdict `skipped`, no findings).

**Ask B — final confirm (only after Ask A = Yes).** List *exactly what ships*.
The release head is **flow-dependent** (`SKILL.md` § *Release flow*): `$STG` in
`staged` flow, the resolved **feature branch** in `direct` flow (resolved exactly
as `--staging` does: the shipping `--prd`'s `feat/prd-<n>-<slug>`, else the
current branch). Compute the shipping commits as `$PROD..<release-head>` either way:

> header **Confirm release**, question "Confirm — this ships to production:"
> - **Version:** `v<NEXT_VERSION>+<BUILD>` (from `<CURRENT_TAG>`, `<bump-level>` bump — the **preview** build; the tag is cut on prod only on success with the recomputed build)
> - **PRDs:** `<prd-ids + features>`
> - **Commits:** `<count>` commits (`<short shas / titles>`)
> - **Platforms:** `<from devkit/PLATFORMS.md>`
> - **Rollback:** per-platform (Step 4) — iOS `IRREVERSIBLE`; the halt/redeploy lever is **offered on failure** (Step 7)
> Options: **Ship it** / **Cancel**

On Cancel → stop (`skipped`). Only **Ship it** proceeds. Never infer approval —
both asks must return an affirmative.

## Inline human-test approval (`direct` flow only — after Step 3, before the lock)

**This is the single definition of the direct-flow human-test gate; every other
reference cites it here.** Under `release_flow=direct` there is no staging stage,
so the staging sign-off is **inactive** (not waived). The human judgment that
sign-off would have carried is not dropped: it moves to an explicit attestation
that fires **before the merge** — the direct flow's equivalent of the staging
sign-off (`../shared/refs/safety-floor.md` § *Human gates*), asked immediately
after the Step-3 double-confirm and **before the lock is acquired**. In `staged`
flow this gate does **not** run; the staging sign-off already carried that
judgment.

**Why before the merge.** The merge to `prod` is the irreversible action; the
deploy is not. Asked after the merge, a Cancel would leave `main` permanently
carrying untested commits that the next release ships silently. Asked here, a
Cancel means nothing was opened, nothing merged, nothing held. The release PR's
CI still validates the merged result afterwards, and there is no deployed target
the human could have tested between merge and deploy anyway.

Ask exactly once:

> `AskUserQuestion` — header **Human test**, question: "There is no staging stage
> in this repo (`release_flow=direct`), so nothing was staged for testing. About
> to merge and deploy **`<prds>`** on **`<platforms>`** (`v<NEXT_VERSION>+<BUILD>`)
> straight to production. Have you tested this build?"
> - **I have tested this build** — proceed to the lock + Step 4
> - **Cancel** — stop; nothing merges and nothing deploys

- **I have tested this build** → continue. Record a `low` `direct-human-test`
  note in the run report (the gate fired and passed).
- **Cancel** → **skipped**, reason **`human_test_declined`**
  (`refs/refusal-patterns.md`; exits 0). Nothing was merged, nothing deployed,
  and **no lock was acquired** — the gate sits before acquisition, so there is
  nothing to release. Under an autonomy contract with no human present, default
  to **Cancel** (do not ship an untested build unattended).

The gate is never a formality: declining it stops the ship exactly as a withheld
sign-off blocks a `staged` release.

## Release lock (acquire before Step 4, release on every exit)

Two `--production` runs in flight at once — two terminals, two teammates, or a
retry over a still-running ship — race on `prod`: both open a release PR, both
merge, both deploy. The lock serializes them. It applies to **both flows** (a
`direct` feature→`prod` ship races the same way) and is **silent when
uncontended**: a solo dev shipping one release at a time never sees it. Friction
appears only on a real collision.

`script-release-lock.sh` owns the whole mechanism — the atomic push-reject
acquire, the holder metadata, the 2h staleness read, the remote holder read, and
the manual-unlock line:

```bash
bash "$S" acquire --prod "$PROD" --prds "<prd ids>"
```

| Exit | `LOCK_STATUS` | Do |
|---|---|---|
| 0 | `acquired` | proceed to Step 4. Record the `release_lock` block (`refs/output-schema.md`) |
| 3 | `held` (fresh) | refuse `release_in_flight`, naming `HELD_BY` / `ACQUIRED_AT` / `SHA` / `PRDS` from the script's output. Fires **before** any mutating action, so it un-does nothing |
| 5 | `held` + `STALE=true` | refuse `release_in_flight` (stale variant) and print the script's `UNLOCK_CMD` verbatim — the human decides; merge never auto-steals a lock |
| 4 | `error` | **fail-open**: one `low` note ("lock not acquired — proceeding without the concurrency guard") and proceed. The lock is a safety assist, not a floor; a flaky network must not dead-end a legit ship |

**Where acquisition sits — after the human gates, before the first mutating
step.** Late enough that no pre-flight refusal ever touches the lock (Step 1,
Step 2, a Step-3 Cancel and a declined inline human-test all exit before it, so
there is nothing to release). Early enough to cover the whole mutating window:
Step 4 onward runs inside it. Two runs can both clear Step 3 concurrently; the
acquire is what serializes them.

### Re-verify sign-off coverage immediately after acquire (`staged` flow)

Step 1 checked coverage **before the lock existed**. Between then and here a
`--staging` merge could have advanced `staging` past the newest stamped sha. The
**first action after a successful acquire** is to re-run the same coverage script
against a fresh fetch:

```bash
S=.claude/scripts/script-signoff-coverage.sh; bash "$S" --fetch --head "origin/$STG" --stamp <prd-id>=<sha> …
```

Anything but `VERDICT=covered` → **release the lock**, then refuse
`stale_signoff` — the certified window shifted under the release. `staged`-flow
only: under `direct` the sign-off stage is inactive, so there is nothing to
re-verify. This is the production-side half of the race `refs/staging.md`
§ *In-flight-production check* closes from the staging side.

### Release — unconditional, at ship-terminal

**Invariant: any run that acquired the lock releases it once the prod-mutating
window closes — no exception path.**

```bash
bash "$S" release --prod "$PROD"
```

`release` is idempotent (`LOCK_STATUS=absent` when there is nothing to delete)
and a failed delete is a `low` note, never a hard stop — the TTL reclaims it.

- **Every refusal, skip, or error after acquisition** — release **before**
  emitting the refusal/skip. That covers Step 4 (`no_prd`, `gh` errors), Step 5
  (`red_ci`/`pending_ci`/`no_review`/`merge_failed`), post-acquire coverage drift,
  and Step 6's `nonmonotonic_build`.
- **A failed ship** (deploy / smoke / provenance `fail`) — release **at
  ship-terminal**: after the failed-ship loop's rollback / rollout-halt offer (the
  last action that can touch `prod`) and **before** the issues-file write and the
  fix-loop handoff, so the potentially long fix loop never holds the lock. That
  ordering is what keeps the 2h TTL bounding only the genuine in-lock window
  (merge → deploy → verify → rollback offer).
- **Success** — release after Step 10.
- **A hard process kill** between acquire and release is the one path code cannot
  cover; the TTL + the script's `UNLOCK_CMD` handle it, documented honestly
  rather than pretended away.

Record `{ref, acquired, acquired_at, released, released_at}` — straight off the
script's keys — into the run report's `release_lock` block.

## Step 4 — Open the release PR (`<head>` → prod)

The PR head is **flow-dependent**, never hardcoded to `staging`: `$STG` in
`staged` flow; in `direct` flow the resolved **feature branch**.

If no `--prd` is given **and** none is resolvable for the release body, refuse
`no_prd` — release the lock first.

```bash
gh pr create --base "$PROD" --head "$HEAD" --title "Release: <prds / date>" --body "<release body>"
```

Release-style body (what the GUI production report and the PR render from):

- **PRDs shipped** — one line per PRD (id · feature · linked `reports/report-*.md`).
- **Reports** — link each shipped PRD's staging report(s).
- **Commits** — `git log --oneline $PROD..$HEAD`.
- **Rollback notes — per platform**, from `devkit/PLATFORMS.md` `rollback_possible`.
  These are **documentation** in the release body; the *executable* lever is
  **offered on a failed ship** (`SKILL.md` § *Failed-ship loop*):
  | rollback_possible | note |
  |---|---|
  | `yes` | Rollback = redeploy the previous build (`rollback_cmd`). For a `server` platform, add the standing caveat: a redeploy does **not** revert schema migrations. |
  | `limited` | Partial rollback — a lever exists but does not fully un-ship: `deploy` (macOS direct download) → re-publish the prior build; `submission` (Android, Mac App Store) → **halt the staged/phased rollout** (`rollout_halt_cmd`); the approved build stays out. |
  | `no` | **IRREVERSIBLE** — an approved app-store release is permanent. The *phased release* can still be halted (`rollout_halt_cmd`) but the build is not recallable. Flag iOS here (default). |
  - Any platform with `rollback_possible: no` (iOS by default) is flagged **`IRREVERSIBLE`** in bold — the GUI surfaces it as a prominent badge. Android is `limited`, not `no` — its staged-rollout halt is a real lever.

## Step 5 — Merge on green CI + human review

Branch protection enforces both; merge checks them, then merges:

1. Verify the release PR's CI is green — the same scripted verdict, in PR mode:
   ```bash
   S=.claude/scripts/script-ci-status.py; python3 "$S" --pr <number>
   ```
   `red`/`pending` (3/4) → refuse (`red_ci`/`pending_ci`), releasing the lock first. `empty-inactive`/`empty-vacuous` (5/6) → proceed, recording `NOTE`. The empty-check-set branch is the script's, identical to `--staging`'s — one implementation, three call sites.
2. Verify the required human review: `gh pr view <n> --json reviewDecision` → must be `APPROVED`. Not approved → refuse (`no_review`).
3. Merge:
   ```bash
   gh pr merge <number> --merge
   ```
   Merge failure → refuse (`merge_failed`).

4. **Refresh prod after the merge — every later step depends on it.** The merge
   moved `$PROD`'s tip, but `origin/$PROD` locally is still the *previous*
   release's head until fetched:
   ```bash
   git fetch origin "$PROD" --tags --quiet
   ```
   Without this, the build recompute, the provenance read and the tag all read a
   stale prod. This fetch is the single refresh Steps 6–10 read from.

5. **Recompute the authoritative release identity.** Re-run
   `script-release-identity.sh` (same flags) against the freshly-fetched prod:
   its `BUILD` now includes the release merge commit, and that value is what the
   Step-6 gate compares and Step 9 tags. Because the merge commit always advances
   `$PROD`, `BUILD` strictly increases release-over-release — and a re-release
   that did **not** advance prod recomputes the same build, which Step 6
   correctly refuses.

## Step 6 — Production deploy

**Build-number monotonicity — `submission` platforms, checked BEFORE submit.**
The Step-5 recompute already answered it: `NONMONOTONIC_BUILD=true` (exit 4) →
**refuse `nonmonotonic_build`** before running any `submission` platform's
`production_deploy_cmd`, naming `BUILD` and `CURRENT_BUILD` — a store rejects a
non-increasing build number, so merge stops rather than pushing a doomed
submission. Release the lock first. `deploy` platforms are not build-gated.

Then, per `refs/deploy.md`, run each platform's `production_deploy_cmd` and
capture logs. A deploy failure emits a `merge` finding
(`refs/output-schema.md`) and runs the **failed-ship loop** — the merge already
happened, so this is surfaced, not swallowed.

## Step 7 — Verify the deploy + provenance

Per `refs/verify-deploy.md`: verification is per `release_model` — smoke the live
target for `deploy` platforms (the v2 contract: one-shot / `watch_window` /
`poll`, plus the config-gated macOS notarization / signing / appcast checks), and
submission-accepted + backend-health for `submission` platforms.

**Provenance.** For each platform with a declared `version_probe`, read the
deployed artifact's source commit and pass it to the identity script:

```bash
S=.claude/scripts/script-release-identity.sh; bash "$S" --prod "$PROD" --probe-sha "$PROBE_SHA"
```

`PROVENANCE=verified` → the artifact was built inside **this release's window**.
`PROVENANCE=fail` (exit 5) → emit a provenance finding, verdict `fail`: the
artifact shipped was built from a commit no human certified for this release —
a stale CI cache, the wrong branch, a hand-built artifact from an old checkout.
The window deliberately **excludes commits already shipped in a prior tag**; a
bare ancestor-of-prod test would wrongly pass last year's release commit. No
probe → `asserted_unverified` with a note, never a fail.

**Any verification failure** — `smoke-failed`, a poll timeout
(`smoke-never-live`), a watch-window degrade, a macOS release-check finding, or
provenance — sets verdict `fail` and **skips Steps 8–10**: a release that isn't
verifiably live doesn't close its PRD's intake row, earn a tag, or move to
`done/`. The failed-ship loop then runs, and its **first action is the
rollback/rollout-halt offer** (`SKILL.md` § *Failed-ship loop*), always-ask,
never auto. The merge stands — never pretend to un-ship.

## Step 8 — Stamp the intake ledger `completed`

Close the loop for each shipped PRD. Both halves go through the ledger's one
parser — the lookup as much as the write, so no second table parser exists:

```bash
S=.claude/scripts/script-intake-stamp.sh
bash "$S" INTAKE.md - --find-row --prd prd-<n>-<slug>   # read: ROW=<#> STATUS=…
bash "$S" INTAKE.md <ROW> --status completed            # write: that cell only
```

`--find-row` is read-only and matches on the `prd-<n>-<slug>` token, so a bare
id, a backticked id and a markdown link all resolve identically. `FOUND=false`
(exit 1) → skip that PRD with a one-line note (below). The write rewrites only
that row's status cell, leaving every other row byte-identical.

This is the terminal ledger transition (`backlog` → `in-progress` →
`completed`), and it makes the `/msg --gui` Intake tab render the idea as
shipped. Missing `INTAKE.md`, or `FOUND=false` → **skip that PRD with a
one-line note**; an unmapped PRD is not an error.

**When it fires, per `release_model`:**

- **`deploy`** — only on a verified (or verify-skipped-with-note) deploy; a smoke failure skips the stamp, because the live target is genuinely unverified.
- **`submission`** — on **submit-accepted**, regardless of the backend-smoke verdict. Once the submit is accepted the artifact is out and cannot be un-submitted by a backend blip, so a *backend* smoke failure must not withhold the stamp. The backend failure still stands as a finding (verdict `fail`, still driving the rollback/halt offer) and Step 9 still withholds the tag. Only a failure of *submission acceptance itself* — rejected-at-upload, or a provenance `fail` — skips the stamp. The report carries the note that live-to-users is downstream and out-of-band, pointing at the monitor-handoff (`refs/submission.md`).

## Step 9 — Tag the release

Only on a **successful** release — merged + deployed-or-skipped-with-note +
verified-or-skipped-with-note, provenance not `fail`. Cut the annotated tag on
the prod release commit with the generated release notes, then push it:

```bash
git tag -a "$NEXT_TAG" "origin/$PROD" -m "<release notes from the shipping PRDs>"
git push origin "$NEXT_TAG"
```

- The tag is **metadata on a commit** — no tracked file changes, so the safety floor holds. No VERSION file, no bump commit.
- A **failed** release does **not** tag — an unverified release gets no version identity, mirroring the skipped Step 8 stamp.
- No remote / push rejected → **skip the tag with a note** (the release shipped; the tag is metadata), never a hard failure.
- Record `version` / `tag` / `build` / per-platform `provenance` in the clean-run summary (`refs/output-schema.md`).

## Step 10 — PRD lifecycle transition to `done`

Only on a **successful** release (the same condition as Steps 8–9). This is the
terminal PRD transition: the folder lane and the `status:` frontmatter both move
to `done` so the physical location and the logical state agree. For **each
shipped PRD**:

1. **Stamp `status: done`** via the shared scalar writer — the `eng → done`
   transition owned here (plan-em set it to `eng` at the branch cut):
   ```bash
   S=.claude/scripts/script-prd-stamp.sh; bash "$S" <prd-path> status done
   ```
   Distinct from the Step-8 write: `status:` lives in the PRD frontmatter, the
   intake row is a separate file. The **`reviewed:` and `staging-signoff:` stamps
   are left intact** — `reviewed` records that a gate ran, `staging-signoff`
   records the human staging test, `status: done` records that the feature
   shipped; the three are orthogonal.
2. **Move the folder to `done/`** — a whole-directory rename that carries the
   PRD and its colocated `reports/`, `preflight.md` and `test/` with no path
   rewriting. **Resolve the source lane first — never assume `wip/`:**
   ```bash
   SRC=""
   for L in planned wip done; do
     for D in features/$L/prd-<n>-*/; do [ -d "$D" ] && SRC="$D" && break 2; done
   done
   [ -n "$SRC" ] || for D in features/prd-<n>-*/; do [ -d "$D" ] && SRC="$D" && break; done
   ```
   The glob is **lane-agnostic and slug-agnostic** (`prd-<n>-*`, not a
   hand-written slug) and falls back to the legacy flat layout; the **first hit
   wins** — a PRD lives in exactly one place. Then:
   ```bash
   case "$SRC" in features/done/*) : ;;    # already filed — no-op
     *) mkdir -p features/done && mv "$SRC" "features/done/$(basename "$SRC")" ;;
   esac
   ```
   `features/` is gitignored, so the directory is normally untracked and plain
   `mv` is the correct mover. Use `git mv` **only** when the directory is
   actually tracked (a legacy repo that committed its PRDs before the ignore).

**Lane-agnostic + idempotent.** No hit anywhere → skip with a one-line note (the
stamp in step 1 still stands). Already under `features/done/` → **no-op**, also
noted — re-running `--production` after a partial run must never fail on it.

**Only on a successful production ship.** A failed ship skips this step entirely
— exactly as it skips Step 8's stamp and Step 9's tag — so a broken release
neither stamps `status: done` nor files the PRD into `done/`. And **`--staging`
never runs this step**: a PRD is not `done` until it is live in production.

**Safety floor.** The stamp is a PRD-frontmatter edit (docs/metadata, the same
category as the intake stamp); the move renames the PRD's own directory. Neither
touches `src/` or writes source code, and both are named in `SKILL.md`'s
sanctioned-writes enumeration (items 4 and 8).

## Run report

Write `report-prd-<N>-<K>.md` (`skill: merge`, production flavor) — release-style:

- `verdict: pass` on a clean release; `fail` if a production deploy errored, its smoke check failed, or provenance mismatched.
- `## Release` — the resolved identity: `v<NEXT_VERSION>+<BUILD>` (tagged on success; skipped-with-note or absent on a failed release), the bump level, per-platform provenance (`verified` / `asserted (unverified)` / `fail`). On a failed ship, also the **rollback offer outcome** (offered/executed/declined + cmd exit). A clean uncontended acquire/release adds nothing here — the lock is silent when it does its job. A **stale lock** never appears here at all: it terminates *that* run as a `release_in_flight` refusal.
- `## Work done` — PRDs shipped, commit count, platforms deployed; on success, note that each shipped PRD was stamped `status: done` and filed into `features/done/`. **Under `release_flow=direct`, open with one `Stages` line** so the reduced set is visible rather than invisible:
  `Stages: staging deploy · staging smoke · staging human-test · staging sign-off — **inactive (no staging)**. All applicable stages ran at full rigor.`
  Never render these as *skipped* (tooling missing) or *relaxed* (threshold lowered). In `staged` flow the line is omitted entirely.
- `## Test results` — one line per platform per `refs/verify-deploy.md`'s vocabulary: `deploy` platforms — verified / smoke-failed / **smoke-never-live** / **degraded-in-window** / skipped; `submission` platforms — submitted (+ track) / backend-health-ok / backend-health-failed / skipped, never "live".
- `## What to expect` — per `release_model`: `deploy` platforms — production is live; `submission` platforms — the **full monitor-handoff block** (`refs/submission.md` § *Monitor-handoff*), never a bare "submitted-not-live" and never "live". **Rollback notes per platform, iOS `IRREVERSIBLE` surfaced prominently** (keep the literal token `IRREVERSIBLE` — the GUI renders a callout when it is present).
- `## Links` — the release PR, the merge commit, per-platform deploy logs.
