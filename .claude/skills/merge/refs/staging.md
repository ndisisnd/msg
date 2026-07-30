---
name: merge-staging
description: merge --staging — locate the feature→staging PR, verify green CI, merge into staging, verify the deploy with the platform smoke check, and stamp the harness-readable staging sign-off. Deploy, verification, and the human test script have their own refs.
---

# `--staging` — merge to staging, hand off to a human

Runs after `/pre-merge` opened a `feature → staging` PR. `/merge` merges it on
green CI, deploys, verifies the deploy with the platform's smoke check, hands a
human a test script, and — only on the human's explicit approval — stamps the
sign-off that `--production` requires. Merge **never self-certifies
staging**: Step 6 STOPS and waits for a human.

## Step 1 — Branch protection (policy-conditional)

Per `refs/protection.md` + `../shared/refs/policy-schema-merge.md` §2. Resolve
`mode_staging = overrides[staging] ?? branch_protection.mode ?? "enforced"` (no file
→ `enforced` = today), then `script-branch-protection.sh --verify staging`: `enforced` →
`UNPROTECTED` **refuses** (`refs/refusal-patterns.md` → `unprotected`); `optional` →
`UNPROTECTED` **warns + proceeds** (one `low` note); `skip` → don't verify. `NO_GH` /
`NO_REMOTE` **refuse regardless of mode**.

## Staging-readiness guard (pre-flight, after Step 1)

Before locating the PR, read the `staging_ready` record `--init` wrote
(`../shared/refs/policy-schema-merge.md` §5) — verify staging is a **real environment**,
not just a branch. Resolve `mode = policies.staging_readiness.mode ?? "enforced"`
(mirrors `branch_protection`'s stance + default). Then:

- **Record absent** (the repo was never `/merge --init`ed) →
  add **one `low` note** to the run report — *"staging readiness was never
  recorded; run `/merge --init` to verify the staging environment"* — and
  **proceed**. Never refuse solely because the record predates the readiness check.
- **Present, every shipping platform `ready:true`** → proceed silently.
- **Present, any platform with `gaps[]`:**
  - `enforced` → **refuse** (`refs/refusal-patterns.md` → `staging_unready`),
    listing each unready platform's gaps and its exact fix verbatim from the
    record. The merge has not happened yet — surface the gap before deploying
    into an environment that was never set up.
  - `optional` → **warn + proceed**, one `low` note per unready platform.
  - `skip` → don't guard (record "staging-readiness check skipped by policy").

This guard only bites under `release_flow=staged`; in `direct` flow `--staging`
has already refused `no_staging_stage` (there is no staging to check).

`staging_ready` is a **resolved fact** re-derived at each `--init`, so it can go
**stale** between init and this run (a platform's declared artifacts changed since
readiness was last derived) — accepted (the record reflects the last
`--init`, not live state; re-run `/merge --init` to refresh it).

## In-flight-production check (pre-flight, before Step 2)

A `--staging` merge lands new commits on `staging` **while** a `--production` run
may be mid-flight. If a production ship is between merge and verify, merging into
`staging` now advances the branch the release is shipping: the PR silently grows
past what the human double-confirmed and past the commit the sign-off certified —
reopening the uncertified-commit hole at the concurrency level. So `--staging`
**reads** the production release lock (`../shared/refs/policy-schema-merge.md` §6):

```bash
S=.claude/scripts/script-release-lock.sh; bash "$S" status --prod "$PROD"
```

| Exit | Meaning | Do |
|---|---|---|
| 0 (`free`) | no production ship in flight | proceed to Step 2 |
| 3 (`held`) | a release holds the lock | **refuse** `release_in_flight`, naming `HELD_BY` / `ACQUIRED_AT` / `SHA`. The merge has not happened — refusing keeps the running release's certified window intact. Wait for it to finish, then re-run |
| 5 (`held` + stale) | held > 2h, likely an aborted run | terminal `release_in_flight` (stale variant) that prints the script's `UNLOCK_CMD` verbatim, so a wedged lock never dead-ends a solo dev. Never auto-steal |
| 4 (`error`) | infra/network | one `low` note, proceed — the lock is a safety assist, not a floor |

This closes the race from the **staging side**. The **reverse** window — a
`--staging` merge that landed *before* the production run acquired the lock — is
closed from the **production side** (`refs/production.md` § *Re-verify sign-off
coverage immediately after acquire*).

**Asymmetric by design:** `--staging` **reads** the lock but never **acquires** one;
the long-lived production ship is the only acquirer. A staging merge (a single
`gh pr merge`) is near-atomic — the reverse window (a production ship starting
mid-staging-merge) is sub-second and not worth the machinery or the friction.

## Step 2 — Locate the PR + verify green CI

**Scripted.** PR resolution and the five-way CI verdict are one deterministic
call — the identical logic `--production` Steps 1 and 5 run, so it lives in one
place (`script-ci-status.py`), not three:

```bash
S=.claude/scripts/script-ci-status.py
python3 "$S" --base "$STG" --prd <prd-path>          # or --head <feature-branch>
```

The branch resolves from `--prd`'s `feat/prd-<n>-<slug>`, else pass `--head`
with the current branch:

| `VERDICT` (exit) | Do |
|---|---|
| — (7) `REASON=no_pr` | **refuse** `no_pr` — pre-merge hasn't opened one, or it already merged |
| `green` (0) | proceed to Step 3 |
| `red` (3) | **refuse** `red_ci`, listing `FAILING_CHECKS` verbatim |
| `pending` (4) | **refuse** `pending_ci`, listing `PENDING_CHECKS`. Do not wait/poll — the human re-runs merge when CI settles |
| `empty-inactive` (5) | proceed. `REASON=policy_disabled` → record `NOTE` as the one report line; `step_opted_out`/`step_na`/`no_ci_record` → proceed silently |
| `empty-vacuous` (6) | proceed **+ one `low` `vacuous-ci` note** (`NOTE` carries it verbatim) |
| — (8) `REASON=gh_error` | the CI state could not be read — **never a green**; surface `ERROR` and stop rather than merging blind |

Branch protection is the machine enforcement; this check exists so merge
refuses with a clear reason instead of a raw merge rejection. The script owns
the whole empty-set branch — `github_actions` outranking `steps.ci`
(`../shared/refs/policy-schema.md` §2b,
`../shared/refs/policy-schema-merge.md` §3) — here and at both `--production`
call sites, so "no red" is never read as green. The opt-out governs **only**
the empty set: checks that *do* report are graded exactly as always.

## Test-selection-miss detection (`policies.test_selection` backstop attribution)

Read-only, additive, and only relevant when `policies.test_selection.enabled`
resolves `true` (`../shared/refs/policy-schema-pre-merge.md` §2c) — otherwise nothing in
this section is read, per the same dead-config rule every other selection
artifact follows. When it's on, pre-merge's minified runs traded
full-suite coverage for speed on the promise that the full suite still runs
somewhere — the declared `full_run_backstop` (`ci` \| `merge` \| `both`).
This is where that promise is checked: a test the minified run **selected away**
breaking at the backstop is the false-green risk the plan calls out.

**`ci` backstop — SCRIPTED, off the Step 2 `red_ci` check just above.** The
attribution is a deterministic read: block → component → did the selected set
run full or minified → the 30-day count. `script-ts-miss.py` is the one
implementation; the model never re-derives it.

```bash
S=.claude/scripts/script-ts-miss.py
python3 "$S" --report features/**/prd-<n>-<slug>/reports/report-prd-<N>-<K>.json \
             --failing-check "<name>" [--failing-check "<name>" …]
```

`--report` is the **committed universal report** for the pre-merge run that
produced this PR's head commit — the durable source
(`../shared/refs/report-schema.md` § *`test_selection` in the paired `.json`*;
the verdict JSON itself is stdout and doesn't survive the run).
`--failing-check` takes `FAILING_CHECKS` straight off Step 2.

| Key / exit | Meaning | Do |
|---|---|---|
| `SELECTION_RAN=false` (4) | the block is absent — a full or selection-off run | nothing in this section applies |
| `MISS_COUNT=0` (0) | every failing check's component ran full, or names no selection-capable component (`NONMISS` says which) | an ordinary regression — **no finding** |
| each `MISS=<check>\|<component>\|<selected>/<total>\|<exclusion>` (3) | the minified run never exercised the test that just broke | record a `high` finding per line |
| `ESCALATE=true` | `WINDOW_MISS_COUNT ≥ 2` in `WINDOW_DAYS` | add `RECOMMENDATION` verbatim to the run report |

Category each finding by the owning component when the closed category
vocabulary has a slot for it (`unit`/`integration`; a `regression` miss uses
`other` by the deliberate convention in `refs/output-schema.md` §
*Test-selection-miss finding*), `rule: "test-selection-miss"`, naming the
failing test, its file, and the exclusion reason. The script's `<exclusion>` is
the block's deterministic read (`tier` when the resolved tier's contract
excluded the component, else `not-affected`); telling `not-tagged` (no critical
marker) from `not-affected` (excluded by the affected-diff rule) is the
**model's** read of the finding context, not a schema field. These findings are
**additive** to the `red_ci` refusal already in play — they explain it, they
never manufacture a new one or turn a green run red.

**`merge`/`both` backstop — Step 7's human test outcome. This half is the
MODEL's, deliberately.** `script-ts-miss.py` does not attempt it: mapping a
"Not yet" answer's named behaviour to a known test is judgment about English,
not a lookup (the fixed-results ruling). The script's `HUMAN_HALF=model` key is
the standing marker. The full suite
here is the human exercising staging, so attribution is necessarily coarser: on
**Not yet** at Step 7, if the human's answer names a specific broken behaviour
that maps to a known test (by name, or by the acceptance criterion it covers),
attribute it the same way — read the same PR's `test_selection` block and record
the `high` finding if that test was selected away. An unattributable **Not
yet** (no specific test named) changes nothing about today's behaviour — still
just an unstamped sign-off — plus one `low` note: "staging failed testing while
test_selection is enabled; consider whether a selected-away test caused it."

**Rolling-window escalation — the script counts it.** `WINDOW_MISS_COUNT` is
`test-selection-miss` findings across this PRD's committed reports plus the rest
of the repo's `features/**/reports/report-*.json`, restricted to the most recent
30 days, **plus this run's misses**. `RECOMMENDATION` names
`/pre-merge --update-criticality` (tag the escapee critical so it stops being
selected away) or `/msg --update` to disable `policies.test_selection` outright,
and points at `force_full_paths`
(`../shared/refs/policy-schema-pre-merge.md` §`policies.test_selection.force_full_paths`)
— a cross-cutting-enough surface that selection should stop trying to prune
around it; `FORCE_FULL_CANDIDATES` names the escapees' components and the model
names the specific test **file**.

## Step 3 — Merge into staging

This is merge's sanctioned merge power (the pre-merge floor forbids it for
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
target under the **v2 smoke contract** (`smoke: {cmd, watch_window?, poll?}`).
Verified (or skipped-with-note) → continue. **Any smoke failure** — a plain
non-zero, a poll timeout (`smoke-never-live`), or a watch-window degrade —
emits the finding, sets verdict `fail`, and **stops here** — skip Steps 6–7.
Never hand a human a test
script for an environment that is already failing its own health check; the report
points at fixing forward via `/pre-merge` (the merge stands). For a macOS platform,
the config-gated notarization / signing / appcast checks (`refs/verify-deploy.md`
§ *macOS release checks*) run here too — each a distinct finding, silent when
undeclared.

## Step 6 — Human test script + STOP

Per `refs/human-test-script.md`. Emit the script and **stop the autonomous
flow** — a human must exercise staging. Merge does not proceed to Step 7 on
its own.

## Step 7 — Stamp the sign-off (on explicit approval)

Only after the human returns. Ask once:

> `AskUserQuestion` — header **Staging**, question "Did staging pass your testing?"
> - **Staging works** — stamp the sign-off and finish
> - **Not yet** — leave unstamped; re-run `--staging` (or fix + re-gate) later

On **Staging works**, stamp the PRD frontmatter through the shared scalar writer
— the one sanctioned writer for this field, never a hand-rolled edit or a
whole-file re-emit (`SKILL.md` § *Sanctioned writes*, item 2):

```bash
S=.claude/scripts/script-prd-stamp.sh
bash "$S" <prd-path> staging-signoff "$(date -u +%Y-%m-%d)@${CERTIFIED_SHA}"   # CERTIFIED_SHA from Step 3
```

- Value shape `<YYYY-MM-DD>@<sha>` — today's date **and the certified sha**, full
  40 chars. The sha is what makes the stamp verifiable: `--production` Step 1
  refuses if `staging` has advanced past every stamped sha, so commits merged
  after sign-off cannot ride to production uncertified.
- The writer is idempotent, inserts the key when absent, rewrites it when
  present, and preserves every other byte — including the PRD body.

**Never stamp a sha other than the one that was deployed and tested.** If
`git rev-parse origin/staging` no longer equals `CERTIFIED_SHA` at stamp time,
something landed on `staging` during the human's test window: still stamp
`CERTIFIED_SHA` (that is what the human actually tested) and add a `low` note to
the run report naming the commits that arrived after it — they are uncertified
and `--production` will say so.

On **Not yet**, do not stamp; note it in the run report and stop.

## Run report

Write `report-prd-<N>-<K>.md` (`../shared/refs/report-schema.md`, `skill: merge`)
to the PRD's `reports/` dir. Staging flavor:

- `verdict: pass` when merged + (deployed or deploy-skipped-with-note) + (smoke verified or verify-skipped-with-note); `fail` on a smoke failure (Step 5); `n/a` if it refused before merging.
- Body `## Test results` — one line per platform per `refs/verify-deploy.md`'s full vocabulary: for `deploy` platforms — verified / smoke-failed / smoke-never-live (poll timeout) / degraded-in-window (watch-window) / skipped (no `smoke_cmd`); for `submission` platforms — submitted (+ track) / backend-health-ok / backend-health-failed / skipped, never "live".
- Body `## What to expect` — per `release_model`: `deploy` platforms — staging is live at the deploy target; `submission` platforms — **submitted to the internal/TestFlight track, not "live"** (`refs/submission.md`). Production still gated on sign-off + double-confirm.
- Body `## How to verify` — **the human test script verbatim** (Step 6) so the GUI Reports tab surfaces it.
- `## Links` — the merged PR, the merge commit, the deploy log/target, the smoke log.
