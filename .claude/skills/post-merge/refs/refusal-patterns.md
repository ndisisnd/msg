---
name: post-merge-refusal-patterns
description: Canonical refusal shapes for post-merge. When each fires and the JSON to emit. Post-merge refuses rather than merges on red/pending CI, a missing sign-off, a sign-off that no longer covers staging's tip (stale_signoff), an unconfirmed release, a direct-flow --staging with no staging stage (no_staging_stage), a staging environment that was never set up (staging_unready, enforced mode), a non-increasing store build number before submit (nonmonotonic_build), a --version that is not strictly greater than the current tag (version_regression), a production release already in flight (release_in_flight, the concurrency lock), or unprotected branches (only when branch_protection resolves to enforced, or on NO_GH/NO_REMOTE).
---

# Refusal Patterns

Post-merge emits a structured refusal JSON and terminates on the conditions
below. Ship gates never soft-pass: on any doubt post-merge refuses rather than
merges. Refusals exit non-zero, except `skipped` (a human cancelled) which
exits zero. The refusal JSON is the sole output — no other text follows.

Common shape:

```json
{
  "verdict": "refused",
  "reason": "<reason>",
  "mode": "staging" | "production",
  "detail": "<human-readable explanation + how to proceed>",
  "issues": []
}
```

| `reason` | Mode | When it fires | `detail` guidance |
|---|---|---|---|
| `unprotected` | both | Step 1/2 — **only when the resolved `branch_protection` mode is `enforced`** and `--verify` returns `UNPROTECTED`; **or** `NO_GH`/`NO_REMOTE` in any mode. Under `optional` an `UNPROTECTED` **warns + proceeds** (not a refusal); `skip` doesn't verify (`../shared/refs/policy-schema.md` §2) | list the missing protection; give the exact `--bootstrap` command. For `NO_GH`/`NO_REMOTE` cite the missing prerequisite, not protection |
| `no_staging_stage` | staging | `release_flow.mode = direct` — there is no staging branch to merge into, so `--staging` cannot run (`../shared/refs/policy-schema.md` §1) | name both `/post-merge --production` (single ship straight to `prod_branch`, all human gates preserved) and `/msg --init-staging` (add a staging stage first) |
| `staging_unready` | staging | Staging-readiness guard (after Step 1) — the `staging_ready` record shows one or more platforms with `gaps[]` **and** `policies.staging_readiness` resolves to `enforced` (the default). `optional` warns + proceeds; `skip` doesn't guard; an **absent** record warns + proceeds, never refuses (`../shared/refs/policy-schema.md` §5) | list each unready platform's gaps and its exact fix from the record; fill the missing artifact(s) in `devkit/PLATFORMS.md`, then re-run `/post-merge --init` |
| `no_pr` | staging | Step 2 — no open feature→staging PR to merge | run `/pre-merge` first, or the PR already merged |
| `red_ci` | both | CI has a failing check | list each failing check name; fix + re-gate via `/pre-merge` |
| `pending_ci` | both | CI still running | list pending checks; re-run post-merge when CI settles (post-merge does not poll) |
| `merge_failed` | both | `gh pr merge` rejected (protection/conflict) | quote gh's message |
| `staging_not_green` | production | Step 1 — latest staging CI not green | fix staging, re-verify |
| `no_signoff` | production | Step 1 — `staging-signoff:` absent from PRD frontmatter | run `/post-merge --staging` and get a human to sign off first |
| `stale_signoff` | production | Step 1 — the sign-off no longer covers `staging`: **either** a stamped sha is not an ancestor of `origin/staging` (rewritten history), **or** `origin/staging` has advanced past every stamped sha (commits merged after sign-off) | list the uncertified commits (`git log --oneline <newest-stamped-sha>..origin/staging`) and name the PRD(s) owning them — each needs its own `/post-merge --staging` sign-off before the release can go |
| `no_review` | production | Step 5 — release PR lacks the required approving review | a human must review-approve the staging→main PR on GitHub |
| `no_prd` | production | **Step 4** — no `--prd` and none resolvable for the release body. Fires **post-acquire**, so the lock releases before this refusal is emitted (`refs/production.md` § *Release lock* exit-table row 1) | pass `--prd <path>` |
| `version_regression` | production | `--version <x.y.z>` is **not strictly greater** than `CURRENT_TAG`'s version. Resolved with the release identity **early — before the lock is acquired** (`refs/release-identity.md`) | name the given version and the current tag; a release never goes backward — pick a higher version or drop `--version` for the default minor bump |
| `nonmonotonic_build` | production | Step 6 — a `submission` platform's resolved `BUILD` (commit count on prod) is ≤ the build in the last `v*` tag, checked **before** submit (`refs/release-identity.md`, AC-RI3) | name the resolved build + the last tagged build; a store rejects a non-increasing build. On an append-only prod this means the release commit is not ahead of the last tag (re-releasing the same commit, or rewound/divergent history) — resolve the branch state, don't force a lower build |
| `release_in_flight` | both | The **release lock** is held by another production ship (`refs/production.md` § *Release lock*, `../shared/refs/policy-schema.md` §6). `--production`: its acquire-tag push (after Step 3, before Step 4) was rejected because the lock tag already exists. `--staging`: its pre-flight lock read (before Step 2) found a held lock — a staging merge mid-production-ship would advance `staging` past the certified/confirmed window (C2). Fires only when the lock is **not stale** (age ≤ 2h) | name the in-flight run — **holder / when / sha** read off the lock tag message (the additive `lock` block below) — and say to wait for it to complete. If it is actually a wedged run, the **stale** path (below) prints the manual unlock; never suggest `--force`-stealing a live lock |
| `out_of_scope_modify` | both | asked to edit source code | post-merge only merges, stamps sign-off, deploys, and tags the release + the release-lock tag (metadata only, no tracked file) — it never edits source |

## `release_in_flight` — the held lock + the stale variant (C8)

`release_in_flight` carries an additive `lock` block naming the holder (never a
bare "someone is shipping"):

```json
{
  "verdict": "refused",
  "reason": "release_in_flight",
  "mode": "production" | "staging",
  "detail": "A production release is in flight, held by Ada <ada@x.io> since 2026-07-21T11:07:18Z on sha 4f2c9a1. Wait for it to finish, then re-run.",
  "lock": {
    "ref": "release-lock-main",
    "held_by": "Ada <ada@x.io>",
    "acquired_at": "2026-07-21T11:07:18Z",
    "sha": "4f2c9a1e8b7d6c5a4938271605f4e3d2c1b0a9f8",
    "prds": ["prd-101-task-crud"],
    "age_seconds": 214,
    "stale": false
  },
  "issues": []
}
```

**Stale variant (`stale: true`, age > 2h TTL).** A lock older than the TTL is
almost certainly an aborted/crashed run, not one still working. It is **not** a
permanent dead-end and it is **never auto-stolen** (that reopens the race). Refuse
*with the manual unlock*, so a solo dev is never wedged (CV1):

> **Release lock is stale** — held by `<held_by>` since `<acquired_at>` (> 2h ago),
> likely an aborted run. If no release is actually in flight, clear it and re-run:
> `git push origin :refs/tags/release-lock-<prod>` (then `git tag -d release-lock-<prod>`).

The same stale text is emitted by both `--production` (acquire rejected) and
`--staging` (pre-flight read). A **non**-stale held lock refuses cleanly with "wait
for it to finish" and no unlock command — a live lock must not be `--force`-stolen.

## `skipped` (not a refusal)

Emitted when a human cancels at a gate — exits **0**, carries no findings:

```json
{
  "verdict": "skipped",
  "reason": "release_cancelled" | "signoff_declined" | "human_test_declined" | "deploy_skipped",
  "mode": "staging" | "production",
  "detail": "<what the human declined and where>"
}
```

- `release_cancelled` — the `--production` double-confirmation was cancelled at Ask A or Ask B.
- `signoff_declined` — a **sign-off/human-test gate was declined**, covering both modes: the `--staging` sign-off ask returned "Not yet", **or** the `--production` unpinned-legacy sign-off re-ask (Step 1) was **Cancel**led. The merge/deploy still stand; only the stamp was withheld.
- `human_test_declined` — the **`direct`-flow inline human-test approval** (`refs/production.md` § *Inline human-test approval*) returned **Cancel**. Fires after the Step 5 merge (which stands) and **before the Step 6 deploy**, so nothing deployed. It is **post-acquire** — the release lock releases before this skip is emitted (`refs/production.md` § *Release lock* exit-table row 7).
- `deploy_skipped` — **terminal only when *every* platform's deploy is skipped** (no command configured anywhere, and the human chose to skip). When only *some* platforms skip, the deploy is **not** terminal: `refs/deploy.md`'s per-platform proceed-with-note is authoritative — the run continues, records a note for the skipped platform, and skips only that platform's verification.

## macOS release-check findings (NOT refusals — C6)

The macOS notarization / signing / appcast checks (`refs/verify-deploy.md`
§ *macOS release checks*) and the smoke-v2 verdicts (`smoke-never-live` on a poll
timeout, a watch-window degrade) run **after the merge and deploy** — the
irreversible action has already happened. So a `notarization-stall` /
`notarization-invalid` / `signing-fail` / `appcast-stale` / `smoke-never-live` is a
**deploy-step failure** (a `category: deploy` finding, verdict `fail`,
`refs/output-schema.md`), routed through the failed-ship loop — **never a
refusal**. Refusals only fire **before** a sanctioned action; these fire after, so
they cannot un-do anything and must not masquerade as a pre-flight stop. (The one
release-check-adjacent *refusal* is `nonmonotonic_build` — the build-number gate,
which correctly fires **before** a submission's submit; the macOS checks have no
such pre-flight case.)

## Never

- **Never merge on red or pending CI.** Branch protection would reject it; post-merge refuses first with the clearer reason.
- **Never open or merge a staging→main PR without both double-confirmation approvals.**
- **Never stamp `staging-signoff:` without the explicit approval question returning "Staging works".**
- **Never stamp a sign-off without its certified sha**, and never pin it to a commit other than the one that was deployed and human-tested. An unpinned stamp is unverifiable — it is exactly the hole `stale_signoff` exists to close.
- **Never `--force`-steal a live (non-stale) release lock.** A held lock < 2h old is a running ship; only its own run releases it, or the human clears a stale one manually. Auto-stealing reopens the exact race the lock closes.
- **Never modify source code** — post-merge's sanctioned writes are enumerated canonically and completely in `../SKILL.md` (Hard refusals). The release **git tag** and the transient **release-lock tag** are metadata on a commit (no tracked-file change, so the safety floor holds; the version source of truth is the tag, never a VERSION file or bump commit — D8).
