---
name: report-schema
description: Canonical run-report artifact (report-[n].md) written by eng --build, review, and pre-merge; parsed by the /msg --gui Reports tab
type: reference
---

# Run report — `report-[n].md`

The canonical post-run report artifact. Written by exactly three skills — `eng --build`, `review`, and `pre-merge` — as the last action of a completed run. It records what the run did (features worked on, code changed, tests passed/failed) and, most importantly, **what the user can expect and how they can verify the work** — in plain language, for a human. The `/msg --gui` Reports tab parses it mechanically, so the frontmatter keys and `##` headings below are a contract: keep them verbatim.

The report **supplements** each skill's existing output contract (build summary, findings JSON, final emission) — it never replaces or reorders it.

## Path resolution + numbering

| Condition | Directory |
|---|---|
| PRD known | `features/prd-<n>-<slug>/reports/` (the PRD's own folder — sub-PRDs use their nested folder) |
| No PRD resolvable | `features/reports/` |

Create the directory if absent. `[n]` is the standard incrementing counter — `max(numeric suffix) + 1` over existing `report-*.md` in the **target directory**, `1` when empty/absent:

```bash
n=$(ls <dir>/report-*.md 2>/dev/null | sed -E 's#.*/report-([0-9]+)\.md#\1#' | sort -n | tail -1); n=$(( ${n:-0} + 1 ))
```

Reports are append-only: always write a new `report-[n].md`, never edit an existing one.

## Frontmatter

Flat `key: value` pairs (plus `[a, b]` lists) — the GUI's frontmatter parser reads nothing nested. All keys present, `none` / `0` where not applicable; **never invent a value that wasn't measured**.

```markdown
---
skill: eng | review | pre-merge
prd: features/prd-101-task-crud/prd-101-task-crud.md   # or none
branch: feat/prd-101-task-crud                          # or none
verdict: pass | pass_with_warnings | warn | fail | block | n/a
features: [F1, F2]            # exec-table feature ids touched, or []
files_changed: 12             # from git diff --stat / resolve-diff
lines_added: 340
lines_removed: 58
tests_passed: 24              # 0 when none ran
tests_failed: 0
generated: 2026-07-08T14:03:00Z    # date -u +%Y-%m-%dT%H:%M:%SZ
---
```

Per-skill field sources:

| Field | eng --build | review | pre-merge |
|---|---|---|---|
| `prd` | the required `prd-path` input | Step 3 discovery (or `none`) | first `--prd` path (or `none`) |
| `branch` | branch commits landed on | current branch (Step 1) | current branch |
| `verdict` | full-suite gate → `pass`/`fail`; `n/a` if no test command | overall verdict (`pass`/`warn`/`block`) | Step 7 verdict |
| `features` | assigned exec-table row ids | feature ids referenced by findings / eval-set | feature ids from `--prd` context, or `[]` |
| diff stats | `git diff --numstat` over this agent's commits | Step 1 resolved diff | Step 1 resolved diff (`resolve-diff.sh` / prelude) |
| test counts | per-group + full-suite results | Functional-mode assertions confirmed vs failed (`0`/`0` if Functional didn't run) | bucket outcomes (integration/e2e totals when parsed; else `0`) |

## Body — fixed section contract

One `# ` H1 title, then these `##` headings, in this order, all present (write `None.` under a section rather than omitting it):

```markdown
# Report <n> — <skill> — <one-line title>

## Summary
2–4 sentences, plain language: what this run did and its outcome.

## Work done
Features worked on — one bullet per feature/exec-row (or per review mode / check bucket), stating what was done to it.

## Code changes
Table of files created/modified with per-file `+/-` lines where available, plus the diff totals.
review/pre-merge don't change code — they report the diff they examined and any artifacts they wrote.

## Test results
Passed/failed counts and notable failures. review: findings by severity per mode. pre-merge: one line per bucket (ran/skipped + outcome).

## What to expect
User-visible behaviour now available (eng), or the current state of the diff/gate (review/pre-merge): what is safe to rely on, what is still open.

## How to verify
Numbered steps in simple, everyday language — written so someone non-technical can follow them and see for themselves that the work is done. Each step says exactly what to do and what they should see, derived from the PRD acceptance criteria and the tests that exist. Prefer actions over jargon ("open the app, add a task, refresh the page — the task is still there", not "exercise the CRUD flow"). When a command is unavoidable, give it verbatim to copy-paste and describe the expected outcome in plain words ("run `npx vitest run tests/auth.test.ts` — all 6 checks come back green"). Never generic ("run the tests"); always specific.

## Links
Related artifacts: findings JSON path, eval_set.json, PR / branch, `.pre-merge/<timestamp>/` logs, prior report-[n].md files, the PRD.
```

## Rules

- **Best-effort write** — a failed report write never fails, blocks, or changes the verdict of the run; note the failure in the skill's own output instead.
- **Anti-fabrication** — record only what actually happened this run; anything unmeasured is `0`, `none`, or "not measured".
- **No output-contract changes** — pre-merge's printed JSON stays its final stdout emission (the report file write is not prose); review's summary line/JSON ordering is unchanged; eng's build summary gains only a `**Report:**` path line.
- **GUI contract** — the Reports tab groups by the containing `prd-*` folder, badges `verdict`, and renders the body sections; renaming a heading or frontmatter key silently drops that data from the board.
