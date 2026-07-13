---
name: sync
description: Gate Step 1 — fetch + merge latest staging into the feature branch. Trivial conflicts auto-resolve; semantic same-hunk conflicts pause for a human. This sync-merge commit is pre-merge's ONLY direct write.
---

# Step 1 — SYNC (D7)

Bring the feature branch up to date with `staging` before gating, so the gate
grades what will actually merge. The resulting sync-merge commit is pre-merge's
**only** direct write to the repo (B4) — mechanical, one correct answer or a pause.

## Preconditions

1. `rtk git fetch origin`.
2. **`staging` must exist.** If `origin/staging` (and local `staging`) do not resolve → **refuse** with `reason: "no_staging"` (`refs/refusal-patterns.md#no_staging`) and terminate. The v2 topology (D3) is `feature → staging → main`; without `staging` there is nothing to gate against and nothing for Step 9 to PR into. The refusal names the setup: create `staging` off `main` and re-run, or run `/msg --init`'s branch-protection bootstrap.

## Merge + conflict handling

Run `rtk git merge origin/staging` into the current feature branch. When `origin/staging` does not resolve but a local `staging` does (the precondition-2 fallback — e.g. no remote yet), merge the local branch instead: `rtk git merge staging`.

- **Clean merge** → commit the merge (message: `sync: merge staging into <branch> before gate`). Proceed.
- **Conflicts** → classify each conflicted hunk:

| Conflict class | Test | Action |
|---|---|---|
| Non-overlapping | changes touch different regions the merge driver could not auto-place | auto-resolve (take both) |
| Whitespace-only | the only delta is whitespace/EOL | auto-resolve |
| Lockfile | path is a known lockfile (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `Cargo.lock`, `poetry.lock`, `Podfile.lock`, `pubspec.lock`) | auto-resolve by regenerating (`<pm> install`) or taking staging's, then re-lock |
| **Semantic (same-hunk)** | both sides edited the same lines with differing intent | **PAUSE** |

- Auto-resolved everything → stage the resolutions and commit the sync-merge. Record which files were auto-resolved (surfaced in the report's `## Work done`).
- **Any semantic same-hunk conflict** → `AskUserQuestion`: present the conflicting hunks and ask the human to resolve (Resolve now / Abort gate). On **Abort**, `git merge --abort` and terminate with `verdict: "skipped"`, `reason: "sync_conflict_declined"`. Never guess a semantic merge.

## Re-run gate after sync

Steps 3 (unit + integration) and 4 (regression) **always re-run post-sync** — the
merge may have changed behavior, so a bad auto-merge cannot pass silently. This is
non-negotiable regardless of profile or flash.

## Write scope

The sync-merge commit is the sole carve-out to pre-merge's no-write rule. Pre-merge
still never edits source, never `git push`, never `gh pr merge`/`git merge` into
`main`. Regression-test writes happen via the spawned eng subagent (Step 4), never
by pre-merge's own hand.
