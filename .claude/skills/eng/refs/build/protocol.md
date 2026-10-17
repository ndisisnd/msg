# eng — Mode: --build (manual build)

A manual `/eng --build` runs the **build loop** in `protocol-packet.md` (Steps 0–7), plus the solo-only steps below. Read this file, then read `protocol-packet.md` fully. The loop is written once, there; this file never restates it.

A `report=<path>` source loads `fix-build.md` instead — the bug-list deltas on the same loop.

**One question.** A manual build asks one question, at the end: "Commit?". There is no opening approval question. The db-touch pause (loop Step 6) stays separate and is never merged into "Commit?". A build started by `plan-em` or another orchestrator is pre-approved: it asks nothing except the db-touch pause.

---

## Input contract

| Field | Value |
|-------|-------|
| `prd-path`, `rows`, `agent` | The shared PRD/exec-table source (`../protocol-core.md` Step 1). |
| `branch` | The feature branch the commits land on. It must already exist. Resolved below when not passed. |
| `commit_mode` | *(optional)* `direct` (default) or `sub-branch`. |
| `report` | *(alternate source)* `report=<features/prd-<N>-<slug>/reports/report-prd-<N>-<K>.json>` → load `fix-build.md` and follow it. Passing both `prd-path` and `report` is a hard failure (`fix-build.md`). |

**Commit modes.** `direct`: commit straight onto `branch`; no sub-branch, no PR. Parallel builds share it safely because each owns a disjoint set of files. `sub-branch`: cut `{branch}/{row-slug}` from `branch`, work and commit there, then open a PR into `branch` — for a human who wants one reviewable PR per agent.

**Resolve the branch mechanically** — never hand-derive it. The resolver reads the PRD frontmatter (a sub-PRD rides its parent's `feat/prd-<parent-n>-<parent-slug>`) and the local branch state:

```bash
B=.claude/scripts/script-em-branch-resolve.sh; [ -f "$B" ] || B="$HOME/.claude/scripts/script-em-branch-resolve.sh"; bash "$B" "<prd-path>"
```

- `ACTION=checkout` — use `BRANCH` when `branch` was not passed. A passed `branch` that differs wins (an orchestrator may target a shared branch); note it in the summary.
- `ACTION=create` or `ACTION=fresh-cut` — the branch does not exist. A build never creates branches: emit `Hard failure: target branch '<BRANCH>' does not exist — the orchestrator must create it before build agents run` and stop.
- Exit 2 (no PRD / not a git repo) — fall back to the passed `branch`. Still unresolved → `Hard failure: missing required field 'branch' for --build mode` and stop.

---

## Solo-only steps, in order

### 1. Check out the branch

`direct`: check out `branch`. `sub-branch`: derive the slug from the first assigned row, cut it from `branch`, and check it out:

```bash
ROW_SLUG=$(printf '%s' "<first assigned row>" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]\+/-/g; s/^-//; s/-$//')
```

### 2. Check every ticket exists — before any question

Read the PRD through the digest, once per assigned F-ID — never the whole PRD:

```bash
G=.claude/scripts/script-prd-digest.py; [ -f "$G" ] || G="$HOME/.claude/scripts/script-prd-digest.py"; python3 "$G" "<prd-path>" --slice build --feature <F-ID>
```

The slice returns the feature row, its exec-table rows, the `todos` block (ticket ids + `prose_lines`) and the `engineering` block. Read the ticket bodies from the `todos` `prose_lines` range. A non-zero exit (`FEATURE_NOT_RESOLVED=<F-ID>`, `FEATURE_ID_EMPTY=<row>`) means the PRD and the assignment disagree: stop and show it. Row ownership is checked by `script-prd-digest.py --verify-rows` (`../protocol-core.md` Step 2).

Every assigned F-ID must have its `### F<n>` block. A missing block stops the run with one line, never a question: `F3 has no tickets. Run /plan-em again.` (loop Step 1). Then show one start line — `Building <F-IDs> — <n> tickets on <branch>` — and begin. No approval question.

### 3. Resolve the coding standards

An injected `standards payload` wins; use it and do not call `/cook`. Otherwise build the explicit flag set with the script. Pass the stack tokens, and exclude a ref only when the PRD or devkit **provably** excludes its subject (for example `macos:distribution` when `CLAUDE.md` defers distribution). On any doubt, keep the ref; never exclude `testing` when a test ticket exists.

```bash
F=.claude/scripts/script-eng-cook-flags.py; [ -f "$F" ] || F="$HOME/.claude/scripts/script-eng-cook-flags.py"
python3 "$F" --stack "<tokens, e.g. nextjs,typescript,supabase>" [--exclude "<domain:ref,…>"]
C=.claude/scripts/script-standards-cache.py; [ -f "$C" ] || C="$HOME/.claude/scripts/script-standards-cache.py"
python3 "$C" --check --flags "<FLAGS value>"
```

`HIT <payload-path>` → read that file as the standards; skip `/cook`. `MISS` → call `/cook` once with the flags, write the result to a temp file, then `python3 "$C" --store --flags "<same flags>" --payload <temp-file> || true` (best effort). Each `GAP=<stack>` line is an uncovered stack: name it in the summary's **Warnings** and follow `CLAUDE.md` + `devkit/ARCHITECTURE.md` for it. Cache contract: `../../../shared/refs/session-cache.md` § Consumers.

### 4. Progress messages

A manual build sends its own progress messages (`../../../shared/refs/status-heartbeat.md`). An orchestrated build never does — the orchestrator sends them from the returned `status:` line. All five calls, in one place:

```bash
S=.claude/scripts/script-status-tick.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-status-tick.sh"
RUN_ID=build-$(date +%s)
"$S" --start --phase eng-build --run-id "$RUN_ID" --total <ticket count>      # before loop Step 1
"$S" --tick --run-id "$RUN_ID" --done <n> --note "<F-ID>-T<k> done"           # each ticket whose done-when passed
"$S" --tick --run-id "$RUN_ID" --next "full-suite gate, ~<Xm>"                 # before loop Step 4; after it: --note "full-suite gate: <pass|fail>"
"$S" --tick --run-id "$RUN_ID" --next "whole-change review, ~<Xm>"             # before loop Step 5; after it: --note "review: <one-liner>"
"$S" --end --run-id "$RUN_ID" --outcome "<the summary's result line>"          # before the summary
```

One agent builds here, so there is no wave to register or poll (`../../../shared/refs/agent-watch.md` does not apply).

### 5. Run the build loop

Run `protocol-packet.md` Steps 0–6 with `review=self`. A user is present, so an unclear requirement is a question (loop § Unclear requirements).

### 6. "Commit?" — the one question

After the db-touch pause (loop Step 6), emit a one-line change summary (files touched, tests added, test result), then ask via `AskUserQuestion`: **"Commit?"** (Yes / No). Any open reviewer question (loop Step 5) goes in the same `AskUserQuestion` call. Yes → loop Step 7. No → leave the changes uncommitted, say so, and go to the summary.

Under an autonomy contract (`plan-em`, an orchestrator) this question is pre-approved: go straight to loop Step 7.

### 7. Open the PR (`sub-branch` only)

When every assigned row is done and tests pass, push the sub-branch and open a PR into `branch`, linking the PRD path. Never open a PR against `main`. `direct` mode skips this step.

### 8. Summary and run report

Emit the loop's build summary (`protocol-packet.md` § Output), with these extra lines, each shown only when it has content:

```markdown
**PR:** <link — sub-branch mode only>
**Target:** <the feature branch — only when commits landed on a sub-branch>
**Report:** <path to report-prd-<N>-<K>.md>
```

Then **best effort** write the run report `report-prd-<N>-<K>.md` per `../../../shared/refs/report-schema.md` (path, numbering, frontmatter keys and section contract live there). The inline summary is the report of record; a failed write is noted under **Warnings** and never blocks the build.

- Directory: `features/prd-<N>-<slug>/reports/`, derived from `prd-path` (create if absent).
- Frontmatter: `skill: eng`; `prd` = `prd-path`; `branch` = where the commits landed; `verdict` from the test result (`pass` / `fail`, `n/a` with no test command); `features` = the assigned F-IDs; diff stats from `git diff --numstat` over this run's commits; test counts from the group and full-suite runs.
- `## What to expect` / `## How to verify`: plain, non-technical steps for the person who will use the feature, derived from the acceptance criteria and the tests written.

---

## Constraints

- Do not modify the PRD file.
- Commits land on the feature branch only (directly, or through the sub-branch PR). Never commit to or open a PR against `main`.
- Touch only the assigned rows' files (loop § Scope). On a run-report numbering collision with a parallel build, re-derive `K` and retry once.
