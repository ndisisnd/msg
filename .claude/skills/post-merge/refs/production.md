---
name: post-merge-production
description: post-merge --production — the double-confirmed staging→main release. Preconditions (green staging + signoff stamp), two separate approvals, release-style PR, merge only on green CI + human review, production deploy, smoke verification of the live target.
---

# `--production` — the double-confirmed release to main

Ships everything currently on `staging` to `main` (production). This is the
harness's single path to `main` — it is **always human-initiated** (the roadmap
orchestrator never invokes it) and its gates never relax, in any mode.

## Step 1 — Preconditions (refuse without both)

For each `--prd` (or every PRD with a merged feature→staging PR since the last release):

1. **Staging CI is green.** Check the latest CI on `staging` (`gh api repos/{owner}/{repo}/commits/staging/status` or `gh run list --branch staging --limit 1`). Not green → refuse (`staging_not_green`).
2. **`staging-signoff:` stamp present** in the PRD frontmatter (stamped by `--staging` Step 6, D11). Missing → refuse (`no_signoff`) — a human has not signed staging off; run `--staging` first.

Both missing/failing conditions refuse before any question is asked.

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

## Run report

Write `report-[n].md` (`skill: post-merge`, production flavor) — release-style:

- `verdict: pass` on a clean release; `fail` if a production deploy errored **or its smoke check failed** (Step 7).
- `## Work done` — PRDs shipped, commit count, platforms deployed.
- `## Test results` — one line per platform: verified / smoke-failed / skipped (no `smoke_cmd`), per `refs/verify-deploy.md`.
- `## What to expect` — production is live; **rollback notes per platform, iOS `IRREVERSIBLE` surfaced prominently** (keep the literal token `IRREVERSIBLE` in the body — the GUI renders a callout when it's present).
- `## Links` — the release PR, the merge commit, per-platform deploy logs.
