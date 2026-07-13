---
name: post-merge-refusal-patterns
description: Canonical refusal shapes for post-merge. When each fires and the JSON to emit. Post-merge refuses rather than merges on red/pending CI, missing sign-off, unconfirmed release, or unprotected branches.
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
| `unprotected` | both | Step 1/2 — `post-merge-protection.sh --verify` returns `UNPROTECTED`/`NO_GH`/`NO_REMOTE` | list the missing protection; give the exact `--bootstrap` command |
| `no_pr` | staging | Step 2 — no open feature→staging PR to merge | run `/pre-merge` first, or the PR already merged |
| `red_ci` | both | CI has a failing check | list each failing check name; fix + re-gate via `/pre-merge` |
| `pending_ci` | both | CI still running | list pending checks; re-run post-merge when CI settles (post-merge does not poll) |
| `merge_failed` | both | `gh pr merge` rejected (protection/conflict) | quote gh's message |
| `staging_not_green` | production | Step 1 — latest staging CI not green | fix staging, re-verify |
| `no_signoff` | production | Step 1 — `staging-signoff:` absent from PRD frontmatter | run `/post-merge --staging` and get a human to sign off first |
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
- **Never modify source code** — the only writes are the merges, the sign-off frontmatter stamp, and the run report.
