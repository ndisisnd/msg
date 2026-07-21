---
name: post-merge-refusal-patterns
description: Canonical refusal shapes for post-merge. When each fires and the JSON to emit. Post-merge refuses rather than merges on red/pending CI, a missing sign-off, a sign-off that no longer covers staging's tip (stale_signoff), an unconfirmed release, a direct-flow --staging with no staging stage (no_staging_stage), a staging environment that was never set up (staging_unready, enforced mode), or unprotected branches (only when branch_protection resolves to enforced, or on NO_GH/NO_REMOTE).
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
| `no_prd` | production | no `--prd` and none resolvable for the release body | pass `--prd <path>` |
| `out_of_scope_modify` | both | asked to edit source code | post-merge only merges, stamps sign-off, and deploys — it never edits source |

## `skipped` (not a refusal)

Emitted when a human cancels at a gate — exits **0**, carries no findings:

```json
{
  "verdict": "skipped",
  "reason": "release_cancelled" | "signoff_declined" | "deploy_skipped",
  "mode": "staging" | "production",
  "detail": "<what the human declined and where>"
}
```

- `release_cancelled` — the `--production` double-confirmation was cancelled at Ask A or Ask B.
- `signoff_declined` — the `--staging` sign-off ask returned "Not yet"; the merge/deploy still stand, only the stamp was withheld.
- `deploy_skipped` — no deploy command configured and the human chose to skip (not a failure).

## Never

- **Never merge on red or pending CI.** Branch protection would reject it; post-merge refuses first with the clearer reason.
- **Never open or merge a staging→main PR without both double-confirmation approvals.**
- **Never stamp `staging-signoff:` without the explicit approval question returning "Staging works".**
- **Never stamp a sign-off without its certified sha**, and never pin it to a commit other than the one that was deployed and human-tested. An unpinned stamp is unverifiable — it is exactly the hole `stale_signoff` exists to close.
- **Never modify source code** — the only writes are the merges, the sign-off frontmatter stamp, and the run report.
