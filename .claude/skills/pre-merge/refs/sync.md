---
name: sync
description: SYNC — the un-prunable DAG root: fetch + merge the run's resolved base into the feature branch. Trivial conflicts auto-resolve; a same-lines conflict aborts the merge and is asked in the main conversation, never inside the gate. This sync-merge commit is one of pre-merge's three bounded direct writes (beside the first-run setup commit and the critical-test tag commit).
---

# SYNC (D7) — the un-prunable DAG root

Bring the feature branch up to date with the base (`staging`, else `main`) before gating, so the gate
grades what will actually merge. The resulting sync-merge commit is a bounded direct
write to the repo (B4), beside the first-run setup commit (`protocol-init.md` step 7)
and the critical-test tag commit (`executor.md` §3c.4) — mechanical, one correct answer or a pause.

## Preconditions

1. `git fetch origin`.
2. **Use the run's resolved base.** The base is resolved **once** at the start of the run (`executor.md` §0a) by this rule: `staging` when `origin/staging` or a local `staging` resolves, else `main` (`origin/main`, else local `main`) — never a refusal or a warning. SYNC merges that base; every later step and script uses the same one.

## Merge + conflict handling

Run `git merge origin/<base>` into the current feature branch, where `<base>` is the run's resolved base (`staging`, else `main`). When the remote branch does not resolve but a local one does (e.g. no remote yet), merge the local branch instead: `git merge <base>`.

- **Clean merge** → commit the merge (message: `sync: merge <base> into <branch> before gate`). Proceed.
- **Conflicts** → classify each conflicted hunk:

| Conflict class | Test | Action |
|---|---|---|
| Non-overlapping | changes touch different regions the merge driver could not auto-place | auto-resolve (take both) |
| Whitespace-only | the only delta is whitespace/EOL | auto-resolve |
| Lockfile | path is a known lockfile (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `Cargo.lock`, `poetry.lock`, `Podfile.lock`, `pubspec.lock`) | auto-resolve by regenerating (`<pm> install`) or taking the base's, then re-lock |
| **Semantic (same-hunk)** | both sides edited the same lines with differing intent | **STOP** — asked in the main conversation |

- Auto-resolved everything → stage the resolutions and commit the sync-merge. Record which files were auto-resolved (surfaced in the report's `## Work done`).
- **Any semantic same-hunk conflict** → the gate never asks and never guesses:
  1. run `git merge --abort`, so the branch is unchanged;
  2. stop with `verdict: "skipped"`, `reason: "sync_conflict"`, and a **gate request**
     listing each conflicting file and its hunks;
  3. the main conversation asks the user **"Resolve now / Abort"**
     (`../../shared/refs/gate-dispatch.md` § *Phase-split*);
  4. on **Resolve**, the conflict is resolved in the main conversation and `/pre-merge`
     runs again from the start. On **Abort**, the run ends with that `skipped` verdict.

  The question is never pre-approved, even inside the automatic fix loop.

## Re-run gate after sync

The test components (`unit`, `integration`, `regression`) **always re-run post-sync** — the
merge may have changed behavior, so a bad auto-merge cannot pass silently. This is
non-negotiable regardless of profile.

## Write scope

The sync-merge commit is one of three carve-outs to pre-merge's no-write rule, beside the
first-run setup commit (`protocol-init.md` step 7) and the critical-test tags
(`executor.md` §3c.4). Pre-merge still never edits source, never
`git push`, never opens a PR, never `gh pr merge`/`git merge` into `main`. Regression-test writes happen via the `regression` component's spawned eng subagent, never
by pre-merge's own hand.
