---
name: report-schema
description: Canonical run-report artifact (report-prd-<N>-<K>.md, no-PRD fallback report-<K>.md) written by eng --build and pre-merge; parsed by the /msg --gui Reports tab
type: reference
---

# Run report — `report-prd-<N>-<K>.md`

The canonical post-run report artifact. Written by `eng --build`, `pre-merge`, and `post-merge` as the last action of a completed run. It records what the run did (features worked on, code changed, tests passed/failed) and, most importantly, **what the user can expect and how they can verify the work** — in plain language, for a human. The `/msg --gui` Reports tab parses it mechanically, so the frontmatter keys and `##` headings below are a contract: keep them verbatim.

The report **supplements** each skill's existing output contract (build summary, findings JSON, final emission) — it never replaces or reorders it.

## Path resolution + numbering

All three forms of a run's report share ONE stem and live together in the PRD's `reports/` folder:

| Condition | Directory | Stem |
|---|---|---|
| PRD known | `features/prd-<N>-<slug>/reports/` (the PRD's own folder — sub-PRDs use their nested `.../prd-<parent>/prd-<child>-<slug>/reports/`) | `report-prd-<N>-<K>` |
| No PRD resolvable | `features/reports/` | `report-<K>` |

- `N` = the PRD number, taken from the `prd-<N>-<slug>` folder.
- `K` = per-PRD report counter — `max(existing K) + 1` over `report-prd-<N>-*.md` in the **target directory**, `1` when empty/absent. The `.md`, its paired `.json`, and the `-fix-plan.md` produced for the SAME run all share this one `N`/`K` stem.

Create the directory if absent. Compute `K` (PRD case) by extracting the trailing number from `report-prd-<N>-*.md`:

```bash
K=$(ls <dir>/report-prd-<N>-*.md 2>/dev/null | sed -E 's#.*/report-prd-'"<N>"'-([0-9]+)\.md#\1#' | sort -n | tail -1); K=$(( ${K:-0} + 1 ))
```

No-PRD fallback — same idea over `report-*.md` in `features/reports/`:

```bash
K=$(ls <dir>/report-*.md 2>/dev/null | sed -E 's#.*/report-([0-9]+)\.md#\1#' | sort -n | tail -1); K=$(( ${K:-0} + 1 ))
```

Reports are append-only: always write a new `report-prd-<N>-<K>.md` (or `report-<K>.md`), never edit an existing one.

### Paired files (colocated, same stem)

On a **failed** run two more files join the `.md`, written into the same `reports/` folder under the same stem:

- **Issues file** `report-prd-<N>-<K>.json` — the report's machine/issues form: canonical `issues[]` + `context` + `summary` + `followUp`, consumed by `eng --build report=<path>` and `eng --plan report=<path>` (the `report=` flag points at this `.json`). This is the single machine artifact for the run — it **replaces** the retired `msg-gate/gate-<n>.json` fail-ticket (identical canonical contents, just renamed and colocated).
- **Fix plan** `report-prd-<N>-<K>-fix-plan.md` — written by `eng --plan`, same stem.

All three files (`.md`, `.json`, `-fix-plan.md`) share the SAME `N` and `K`. The no-PRD fallback uses the `report-<K>.*` stem for all three.

## Frontmatter

Flat `key: value` pairs (plus `[a, b]` lists) — the GUI's frontmatter parser reads nothing nested. All keys present, `none` / `0` where not applicable; **never invent a value that wasn't measured**.

```markdown
---
skill: eng | pre-merge | post-merge
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

| Field | eng --build | pre-merge |
|---|---|---|
| `prd` | the required `prd-path` input | first `--prd` path (or `none`) |
| `branch` | branch commits landed on | current feature branch |
| `verdict` | full-suite gate → `pass`/`fail`; `n/a` if no test command | final gate verdict |
| `features` | assigned exec-table row ids | feature ids from `--prd` context, or `[]` |
| diff stats | `git diff --numstat` over this agent's commits | resolved diff (`resolve-diff.sh` / prelude) |
| test counts | per-group + full-suite results | unit-int / bucket outcomes when parsed; else `0` |

**post-merge fields (H4).** `prd` = the shipped PRD; `branch` = the merged feature branch (`--staging`) or `staging` (`--production`); `verdict` = `pass` on a clean merge/deploy, `fail` if a production deploy errored, `n/a` on an early refusal; diff/test stats are `0`/`none` (post-merge changes no source and runs no test buckets — it merges and deploys). Two flavors:

- **Staging report** — its `## How to verify` section carries the **human test script verbatim** (`post-merge/refs/human-test-script.md`), so the GUI surfaces exactly what the human should poke at on the deployed staging environment.
- **Production report** — release-style: `## Work done` lists the PRDs shipped + platforms deployed; `## What to expect` carries the per-platform rollback notes and keeps the literal token **`IRREVERSIBLE`** for any no-rollback platform (iOS), which the GUI renders as a prominent callout.

## Body — fixed section contract

One `# ` H1 title (`# Report <N>-<K> — …` for the PRD case; the no-PRD fallback drops `<N>` and uses just `<K>`), then these `##` headings, all required and in this exact order (write `None.` under a section rather than omitting it):

```markdown
# Report <N>-<K> — <skill> — <one-line title>

## Summary
2–4 sentences, plain language: what this run did and its outcome.

## Issue summary
**Total:** <n> issue(s)

| Category | Count |
|----------|-------|
| <category> | <n> |

**By severity:** blocker <n> · high <n> · medium <n> · low <n>

## Work done
Features worked on — one bullet per feature/exec-row (or per gate stage / check bucket), stating what was done to it.

## Code changes
Table of files created/modified with per-file `+/-` lines where available, plus the diff totals.
pre-merge doesn't change source (its only write is the D7 sync-merge commit) — it reports the diff it examined and any artifacts it wrote.

## Test results
Passed/failed counts and notable failures. pre-merge: one line per gate stage / bucket (ran/skipped + outcome).

## What to expect
User-visible behaviour now available (eng), or the current state of the diff/gate (pre-merge): what is safe to rely on, what is still open.

## How to verify
Numbered steps in simple, everyday language — written so someone non-technical can follow them and see for themselves that the work is done. Each step says exactly what to do and what they should see, derived from the PRD acceptance criteria and the tests that exist. Prefer actions over jargon ("open the app, add a task, refresh the page — the task is still there", not "exercise the CRUD flow"). When a command is unavoidable, give it verbatim to copy-paste and describe the expected outcome in plain words ("run `npx vitest run tests/auth.test.ts` — all 6 checks come back green"). Never generic ("run the tests"); always specific.

## Links
Related artifacts: the paired issues file (`report-prd-<N>-<K>.json`), eval_set.json, PR / branch, `.pre-merge/<timestamp>/` logs, prior `report-prd-<N>-*.md` files, the PRD.
```

**`## Issue summary` derivation.** Counts come straight from the run's canonical `findings[]` (`category` + `severity` fields, both already required by `.claude/skills/shared/refs/finding-schema.md` — no schema change needed there). On a clean run (zero findings) write `No issues.` under the heading in place of the table.

## Rules

- **Best-effort write** — a failed report write never fails, blocks, or changes the verdict of the run; note the failure in the skill's own output instead.
- **Anti-fabrication** — record only what actually happened this run; anything unmeasured is `0`, `none`, or "not measured".
- **No output-contract changes** — pre-merge's printed JSON stays its final stdout emission (the report file write is not prose); eng's build summary gains only a `**Report:**` path line.
- **GUI contract** — the Reports tab groups by the containing `prd-*` folder, badges `verdict`, and renders the body sections; renaming a heading or frontmatter key silently drops that data from the board. Body sections render raw (markdown passthrough) — adding `## Issue summary` needs no GUI parser change.
- **Terminal emission** — every report write, on every verdict (pass and fail alike), also prints the same counts to the terminal:
  ```
  Issue summary — <total> issue(s)
  By category:  <cat>: <n> · <cat>: <n> …
  By severity:  blocker <n> · high <n> · medium <n> · low <n>
  ```
  A clean run prints exactly `Issue summary — 0 issues`. This is a standing producer obligation independent of the fail-only follow-up offers in `.claude/skills/shared/refs/fix-loop.md` (which only trigger after a FAILED run, once the issues file + report are written).
