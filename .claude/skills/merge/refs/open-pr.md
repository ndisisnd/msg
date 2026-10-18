---
name: merge-open-pr
description: merge's PR step — check that pre-merge passed on the branch tip (with the small-change allowance), push the feature branch, open the feature PR or reuse an open one, and wait for CI up to the limit. Used by --staging Step 2 and direct-flow --production Step 4. pre-merge never pushes and never opens a PR; merge is where the PR is made.
type: reference
---

# Open the PR — pass check, push, PR, CI wait

pre-merge checks quality and fixes bugs on the machine; it never pushes and never opens
a PR. merge makes the PR. This ref runs, in order, inside the mode's **subagent phase 1**
(no question is asked here):

| Caller | PR | Base |
|---|---|---|
| `--staging` Step 2 | feature → `staging` | `$STG` |
| `--production` Step 4, `direct` flow | feature → prod | `$PROD` |

Staged `--production` does not use this ref: its `staging` → prod release PR has no
pre-merge pass to check (`refs/production.md` Step 4).

**The feature branch** is the current branch (`git branch --show-current`). On `$STG`,
`$PROD`, or a detached head ⇒ refuse `not_feature_branch` ("check out the feature
branch, then run `/merge`").

## 0 · Already merged into staging (`--staging` only)

A re-run after a **Not yet** sign-off answer (`refs/staging.md` Step 7) finds the
feature PR already merged. Check this first, before the pass check, the push and the PR:

```bash
gh pr list --head "$BRANCH" --base "$STG" --state merged --json number,url,mergeCommit --limit 1
git fetch origin "$STG" --quiet
git merge-base --is-ancestor HEAD "origin/$STG"   # exit 0 ⇒ the tip is already in staging
```

A merged feature → `$STG` PR exists **and** the tip is in `origin/$STG` ⇒ skip §1–§4 (no
pass check, no push, no PR, no CI wait) and skip `refs/staging.md` Steps 3–5. Set
`CERTIFIED_SHA` to that PR's merge commit (`mergeCommit.oid`, full 40 chars), and resume
at `refs/staging.md` Step 6 (test script), then Step 7 (sign-off). Report one line:
"Already merged into staging as `<PR_URL>` — asking for the sign-off again."

Otherwise (no merged PR, or new commits since it) ⇒ continue at §1; §3 opens a new PR
for the new commits.

## 1 · Pass check — pre-merge passed on this commit

pre-merge stores its last check per branch — the commit it checked **and** the verdict,
together (`.pre-merge/last-check.json`, written by `script-premerge-last-check.sh`).
Grade the branch tip against it by script:

```bash
S=.claude/scripts/script-merge-checks.py; python3 "$S" pass --branch "$BRANCH"
```

| `PASS_STATE` (exit) | Meaning | Do |
|---|---|---|
| `current` (0) | pre-merge passed (`pass` / `pass_with_warnings`) on the tip | continue |
| `small` (4) | new commits since the pass: **20 changed lines or fewer** and **no risky file** | run the **quick check** below |
| `not_small` (3) | more than 20 lines, or a risky file | refuse `no_premerge_pass` — "Run `/pre-merge` first." quoting `REASON` and `RISKY_FILES` |
| `none` (3) | no record, or the last verdict is not a pass (either the commit or the verdict missing ⇒ no pass) | refuse `no_premerge_pass` — "Run `/pre-merge` first." |
| `history_changed` (3) | the checked commit is gone or not under the tip (rewritten history) | refuse `no_premerge_pass` — "Run `/pre-merge` first." |

How the script counts (merge-2 build decisions, owned by the script, never re-derived):

- **Lines** — only this branch's own commits since the pass (first parent, no merge
  commits), added plus removed lines. Lock files and generated files are not counted.
- **Risky** — a path in `policies.merge.risky_paths` (`MERGE_RISKY_PATHS`; absent ⇒ the
  catalog seed), or any lock file (never counted, always risky).
- **Library search** — the changed files only are searched for auth and payment
  libraries (`../../shared/refs/component-catalog.md` § *Risky libraries*). A hit outside
  the list is risky, and its folder is in `NEW_RISKY_PATHS`.

**`NEW_RISKY_PATHS` non-empty (any state)** ⇒ save the grown list and report one line
("Added `<path>` to the risky paths: it uses an auth or payment library"). merge never
removes a path:

```bash
S=.claude/scripts/script-policy-set.py
python3 "$S" --file devkit/policy.json --set policies.merge.risky_paths='<RISKY_PATHS_JSON>'
```

### Quick check (`small` only)

Lint plus the tests for the changed files — never the full pipeline:

1. **Lint** — the `mechanical` component's lint command from `devkit/policy.json`
   `components[]`.
2. **Tests** — when `policies.test_selection` is on, the `unit` component's
   `run_minified` over the changed files (the runner's own affected-test map). Otherwise
   the name-matched tests in `TEST_FILES` (`home.ts` → `home.test.ts`), run with the
   `unit` component's runner. No match ⇒ lint only, plus the report note "no matching
   tests for the new commits".

Quick check fails ⇒ refuse `no_premerge_pass` — "Run `/pre-merge` first." naming the
failing command. Quick check passes ⇒ continue; the PR body lists the new commits
(`COMMIT` lines) under **Commits since the pre-merge pass**.

## 2 · Push the feature branch

```bash
git push -u origin "$BRANCH"
```

A normal push — **never** `--force` or `--force-with-lease`. A rejected push stops the
run: refuse `push_rejected`, quoting git's message ("the remote has commits this branch
lacks — pull them, run `/pre-merge`, then `/merge`"). Nothing is opened.

## 3 · Open the PR, or reuse an open one

```bash
gh pr list --head "$BRANCH" --base "$BASE" --state open --json number,url --limit 1
```

- **An open PR exists** ⇒ reuse it. When the pass check was `small`, add the new-commit
  list as one PR comment (`gh pr comment <n> --body …`).
- **None** ⇒ open it. (An already-merged staging PR whose merge holds the tip never
  reaches here: §0 skipped to the sign-off.)
  ```bash
  gh pr create --base "$BASE" --head "$BRANCH" --title "<PRD title, else branch>" --body "<body>"
  ```

The body links **pre-merge's report** (the `REPORT` key of the pass check, else the newest
`reports/report-prd-<N>-<K>.md` of the PRD), the PRD, and — after a `small` pass check —
the commits since the pass. Record `PR_NUMBER` and `PR_URL`. A `gh` error ⇒ stop and
surface it; never merge blind.

## 4 · Wait for CI

Wait for CI on the PR, with progress messages, up to `MERGE_CI_WAIT_MINUTES`
(`policies.merge.ci_wait_minutes`, default 30; setup sets it above recent run times —
`refs/protocol-init.md` item 8). No flag changes it.

```bash
DEADLINE=$(( $(date +%s) + MERGE_CI_WAIT_MINUTES * 60 ))
S=.claude/scripts/script-ci-status.py
python3 "$S" --pr "$PR_NUMBER" --wait-seconds 270 --deadline "$DEADLINE"
```

Each call polls for at most 270 seconds. Exit 4 (still pending, deadline not reached) ⇒
tick the heartbeat (`--note "waiting for CI — <PENDING_CHECKS> pending"`) and call again.

| `VERDICT` (exit) | Do |
|---|---|
| `green` (0) | continue to the mode's merge step |
| `red` (3) | **refuse** `red_ci`, listing `FAILING_CHECKS` verbatim — "fix it with `/eng`, then run `/pre-merge` and `/merge`" |
| `pending` (9) `REASON=wait_limit` | **refuse** `pending_ci` — "CI is still running after `<n>` minutes; re-run `/merge` when it finishes" (the re-run reuses this PR) |
| `empty-inactive` (5) | proceed. `REASON=policy_disabled` → record `NOTE` as the one report line; `step_opted_out`/`step_na`/`no_ci_record` → proceed silently |
| `empty-vacuous` (6) | proceed **+ one `low` `vacuous-ci` note** (`NOTE` carries it verbatim). While waiting, an empty set first gets a 2-minute grace for workflows to register |
| — (8) `REASON=gh_error` | the CI state could not be read — **never a green**; surface `ERROR` and stop |

Branch protection is the machine enforcement; this check exists so merge stops with a
clear reason instead of a raw merge rejection. The script owns the whole empty-set branch
(`github_actions` outranking `steps.ci`, `../../shared/refs/policy-schema.md` §2b), so
"no red" is never read as green.
