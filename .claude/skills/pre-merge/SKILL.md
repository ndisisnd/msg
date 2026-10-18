---
name: pre-merge
description: >
  The quality gate. Takes a feature branch from "eng says done" to "checked,
  fixed and ready for /merge". Runs the project's preflight-resolved pipeline
  from devkit/policy.json components[]: sync → parallel correctness + security
  waves → coverage → regression tail → security/migration → PRD-consistency →
  verdict. A failed gate fixes itself automatically (up to 2 rounds). Stays
  local: never pushes, never opens a PR — its last line says "Next: /merge".
  The first run sets the project up, then gates. Emits a severity-graded
  verdict JSON. Absorbs the old /review and /test. Activates on /pre-merge
  after eng --build.
argument-hint: "[--update] [--flaky <n>] [--minified | --full]"
allowed_tools:
  - AskUserQuestion
  - Read
  - Edit
  - Write
  - Bash
  - Agent
---

# pre-merge

**The** quality gate. Runs after `eng --build` says a feature branch is done: it checks
quality, fixes the bugs it finds, and writes its report. It **stays local** — it never
pushes and never opens a PR; `/merge` does both. Pre-merge holds **no human gate** — the
human look at the running feature belongs to merge (`../shared/refs/safety-floor.md`
§ *Human gates*). Absorbs the retired `/review` and `/test`. Each run is independent.
Posture: release engineer — owns the gate; repeatable evidence over assertion, severity matched to reachability, tables over prose, JSON-first.

```
eng --build  →  /pre-merge  →  (fail → automatic fix: eng --plan + eng --build, gate again, ≤2 rounds)  →  pass → "Next: /merge"
```

## Usage

- `/pre-merge` — gate the current feature branch against the base (`staging`, else `main`). **First run:** no `components[]` in `devkit/policy.json` ⇒ setup runs inline (detect tooling → batched questions, gaps only → gated install/scaffold → save `devkit/policy.json`), then the gate continues in the same run (`refs/protocol-init.md`). The PRD is found from the branch name (`feat/prd-<N>-<slug>`); no match or several matches ⇒ one question, with a "No PRD" choice (`refs/executor.md` §0b). When test selection is on, critical-test tagging runs automatically before selection (`refs/protocol-criticality.md`)
- `/pre-merge --update` — redo or refresh setup: re-run preflight → diff `components[]` → approve the delta → apply `present`/`active_when`/new-component changes only, never re-grading user-set criticality or re-prompting settled opt-outs (`refs/protocol-init.md`). The `.github/workflows/` CI pipeline is part of the detect unless `policies.github_actions.enabled` is `false` — a settled opt-out, not a gap
- `/pre-merge --prior-issues <path>` / `--full-secret-scan` — load a prior verdict JSON to mark regressions / make the `security` component scan the full tree (default: diff-only)
- `/pre-merge --flaky <N>` / `--changed-only` — retry failing e2e / unit-int tests up to `N` times; skip platform components whose surface the diff doesn't touch (`refs/_common.md`). `--minified` / `--full` — force test selection on for this run (a trial; nothing written) / force the full suites, the kill switch. Flag beats policy: `--full` > `--minified` > `policies.test_selection` (`refs/executor.md` §3c)

Progress messages are always on, every 5 minutes (`../shared/refs/status-heartbeat.md`).

Natural language: "run pre-merge", "gate this before merge", "check this branch", "run the CI gate".

## Hard refusals

Shapes and JSON in `refs/refusal-patterns.md`. Pre-merge:
- Does NOT run on built-in defaults. No `components[]` in `devkit/policy.json` ⇒ setup runs first, saves the manifest, then the gate runs (`refs/executor.md` §0).
- Does NOT modify source code itself. Its only direct writes are the first-run setup commit (`refs/protocol-init.md` step 7), the SYNC (D7)-bounded sync-merge commit and, when test selection is on, the critical-test tag commit (`refs/protocol-criticality.md`); regression tests and fixes are written by eng, never by pre-merge.
- Does NOT `git push`, open a PR, `gh pr merge`, `git merge` into `main`, or deploy. The branch stays local; `/merge` pushes it and opens the PR.
- Does NOT run without a non-empty diff against base (`no_diff`). A missing `staging` branch is NOT a blocker — the base falls back to `main`, no warning, no refusal.
- Does NOT grade a finding as blocker without quoted tool evidence. Does NOT compute a verdict by hand — `script-aggregate-verdict.sh` does (`refs/executor.md` §5b). Does NOT mutate `components[]` in a gate run — only setup and `--update` do. The manifest staleness nudge (`refs/executor.md` §0) is read-only.

## Inputs / Outputs

| | Name | Source / Destination |
|--|------|----------------------|
| In | base | resolved once per run (`refs/executor.md` §0a) — `staging`, falling back to `main` when that branch is absent; the diff comes from `scripts/script-resolve-diff.sh <base>` or a fresh `../shared/refs/verify-prelude.md` |
| In | prd · prior_issues | the one PRD found from the branch name, or the user's one answer (`refs/executor.md` §0b) — feeds `regression`, the `prd` group and the review-coverage check · optional `--prior-issues` JSON |
| Out | verdict_json | single JSON per `refs/output-schema.md` — final stdout emission; also written to `.pre-merge/<ts>/verdict.json`, the dispatcher's transport (`../shared/refs/gate-dispatch.md`) |
| Out | run_report + issues_file | `report-prd-<N>-<K>.md` per `../shared/refs/report-schema.md`, paired `.json` on a non-clean verdict — consumed by `eng --build report=`; raw stage logs → `.pre-merge/<timestamp>/<stage>.log` |
| Out | last check | `.pre-merge/last-check.json` — the checked commit and the verdict, stored together per branch (`scripts/script-premerge-last-check.sh`); `/merge` reads it to confirm a pass on the branch tip |

## Dispatch

**The gate run executes in a subagent.** The main thread is a thin dispatcher: first-run
setup and the PRD question inline (both may ask the user), the cheap `no_diff` probe, then
one backgrounded subagent runs the whole pipeline, watched under `gate-<epoch>`, result
relayed byte-identically (`../shared/refs/gate-dispatch.md`). The dispatcher runs no check
and writes no artifact. **Every question stays in the main thread**:

- **Merge conflict** — the subagent aborts the merge and stops with `sync_conflict`; the
  main thread asks "Resolve now / Abort", and on Resolve runs `/pre-merge` again
  (`refs/sync.md`).
- **Fail** — the main thread runs the automatic fix loop: `eng --plan report=…` →
  `eng --build report=…` → gate again, no question, up to **2 rounds**; it stops early
  on no progress, a safety pause, a merge conflict, or a bug at eng's 3-attempt limit,
  and the hand-off says why and the next command (`../shared/refs/fix-loop.md`).

The gate is a **preflight-driven executor** — it runs the resolved `components[]` pipeline
from `devkit/policy.json`, not a fixed step list. Policy load/validate once per run
(`../shared/refs/policy-schema.md` §0/§1 + `policy-schema-pre-merge.md` §2c — merge's half
never loaded); the manifest carries **deltas only**, joined with the catalog by
`script-pipeline-resolve.py`, whose plan the executor quotes verbatim. **SYNC** always
first, the **terminal** always last — "Next: /merge" on a pass, the fix loop on a fail;
the gate never dead-ends.

| Invocation / stage | Ref that owns it |
|---|---|
| the gate run — prune → topo-sort → parallel waves → fail-fast → per-check result reports → aggregate; §3c test selection (opt-IN, off by default); §7 terminals + emission order | `refs/executor.md` |
| SYNC (D7), the un-prunable DAG root | `refs/sync.md` |
| each component's protocol, loaded on demand; `--flaky` / `--changed-only` + the platform components | `refs/universal/*.md`, `refs/platform/*.md`, `refs/prd/*.md`, `refs/_common.md` |
| first-run setup, `--update` · critical-test tagging (gate step §3c.4) | `refs/protocol-init.md` · `refs/protocol-criticality.md` |
| grading + criticality fail-fast · refusals | `refs/severity-rubric.md` · `refs/refusal-patterns.md` |

Every run ends with the emission order of `refs/executor.md` §7 — run report, terminal
`Issue summary`, verdict JSON (the final machine emission), closing message last; on a
pass its last line is **"Next: /merge"**.
**Harness incidents:** log per `../shared/refs/doctor-logging.md` — a check that
legitimately fails is not an incident.

## References

- `refs/executor.md` — **the pipeline executor** (C1/C5/C6/C7): §0 first-run setup + staleness nudge, §0a base, §0b PRD, §3b the C23 test sandbox, §3c test selection + §3c.4 critical tagging, §5b emissions, §6 last check, §7 terminals
- `refs/sync.md` · `refs/protocol-init.md` · `refs/protocol-criticality.md` · `refs/platform-profiles.md` · `refs/_common.md` · `refs/universal/protocol-{mechanical,tests,coverage,regression,security}.md` · `refs/platform/protocol-{migration,smoke}.md` · `refs/prd/protocol-prd-consistency.md` (**blocks on unmet criteria only** — every other grade routes to the human test checklist at `merge --staging`)
- `refs/output-schema.md` · `refs/finding-schema.md` · `refs/severity-rubric.md` · `refs/refusal-patterns.md`
- `../shared/refs/` — `policy-schema.md` (§0/§1/§2b) · `policy-schema-pre-merge.md` (`components[]`, `source_signature`, §2c `test_selection`, `criticality_review`) · `component-catalog.md` · `check-report-schema.md` · `env-contract.md` (read at §3b, never written) · `gate-dispatch.md` · `fix-loop.md` · `closing-message.md` · `doctor-logging.md` · `safety-floor.md` · `finding-schema.md` · `report-schema.md` · `verify-prelude.md` · `status-heartbeat.md`
- `.claude/scripts/script-preflight-*.sh` (C4, the detector) · `script-pipeline-resolve.py` (join → prune → C12 → waves → plan JSON; `--check-complete`) · `script-aggregate-verdict.sh` · `script-premerge-last-check.sh` · `scripts/script-resolve-diff.sh`
