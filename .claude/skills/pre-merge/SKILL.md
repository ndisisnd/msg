---
name: pre-merge
description: >
  The CI gate. Takes a feature branch from "eng says done" to "PR open against
  staging with green checks". Runs the project's
  preflight-resolved pipeline from devkit/policy.json components[]: sync →
  parallel correctness + security waves → coverage → regression tail →
  security/migration → PRD-consistency → open PR.
  Emits a severity-graded verdict JSON. Absorbs the old /review and /test.
  Activates on /pre-merge after eng --build.
argument-hint: "[--init | --update | --update-criticality] [--prd <path>] [--flaky <n>] [--minified | --full] [--quiet | --status <n>m]"
allowed_tools:
  - AskUserQuestion
  - Read
  - Edit
  - Write
  - Bash
  - Agent
---

# pre-merge

**The** CI gate. Runs after `eng --build` says a feature branch is done and takes it to
a PR open against `staging` with green checks. Pre-merge holds **no human gate** — the
human look at the running feature belongs to merge (`../shared/refs/safety-floor.md`
§ *Human gates*). Absorbs the retired `/review` and `/test`. Each run is independent.
Posture: release engineer — owns the gate; repeatable evidence over assertion, severity matched to reachability, tables over prose, JSON-first.

```
eng --build  →  /pre-merge  →  (fail → eng --build report=…, repeat)  →  PR feature→staging  →  merge --staging
```

## Usage

- `/pre-merge` — gate the current feature branch against `staging`
- `/pre-merge --init` — the one-time setup: detect tooling → interview → gated install/scaffold → write `devkit/policy.json`; no gate run (`refs/protocol-init.md`). The `.github/workflows/` CI pipeline is part of the detect unless `policies.github_actions.enabled` is `false` — a settled opt-out, not a gap
- `/pre-merge --update` — reconcile the manifest with codebase reality: re-run preflight → diff `components[]` → approve the delta → apply `present`/`active_when`/new-component changes only, never re-grading user-set criticality or re-prompting settled opt-outs (`refs/protocol-init.md`)
- `/pre-merge --update-criticality` — the criticality reconcile: inventory untagged tests → evidence-cited proposals → one human gate → markers committed + `criticality_review` restamped (`refs/protocol-update-criticality.md`)
- `/pre-merge --prd <path>` (repeatable) — name the PRD explicitly. The `prd` group (`prd-consistency`, `manual-test-plan`) runs by default whenever a `features/prd-<N>-*/` PRD matches the branch; this flag overrides an ambiguous or missing match
- `/pre-merge --prior-issues <path>` / `--full-secret-scan` — load a prior verdict JSON to mark regressions / make the `security` component scan the full tree (default: diff-only)
- `/pre-merge --flaky <N>` / `--changed-only` — retry failing e2e / unit-int tests up to `N` times; skip platform components whose surface the diff doesn't touch (`refs/_common.md`). `--minified` / `--full` — force test selection on for this run (a trial; nothing written) / force the full suites, the kill switch. Flag beats policy: `--full` > `--minified` > `policies.test_selection` (`refs/executor.md` §3c)
- `/pre-merge --quiet` / `--status <n>m` — suppress or retune this run's status heartbeat; flag beats policy beats default, floor 2 minutes (`../shared/refs/status-heartbeat.md`)

Natural language: "run pre-merge", "gate this before merge", "open the PR against staging", "run the CI gate".

## Hard refusals

Shapes and JSON in `refs/refusal-patterns.md`. Pre-merge:
- Does NOT run without a manifest. No `components[]` in `devkit/policy.json` ⇒ **REFUSE `no_manifest`**, zero components run, naming `/pre-merge --init`. No built-in-defaults path, no inline auto-`--init` (state table: `refs/refusal-patterns.md` § `no_manifest`, its one home).
- Does NOT modify source code. Its ONLY direct write is the SYNC (D7)-bounded sync-merge commit; regression tests are written by a spawned eng subagent, never by pre-merge.
- Does NOT `git push`, `gh pr merge`, `git merge` into `main`, or deploy production. It opens exactly one PR (feature→staging, or feature→`main` when no `staging` branch exists) and never merges it.
- Does NOT run without a non-empty diff against base (`no_diff`). A missing `staging` branch is NOT a blocker — the sync + PR target falls back to `main`, no warning, no refusal.
- Does NOT grade a finding as blocker without quoted tool evidence. Does NOT write `policy.json` or mutate `components[]` — only `--init` / `--update` do. Staleness nudges (manifest, `refs/executor.md` §0; untagged tests, `refs/protocol-update-criticality.md`) are read-only.

## Inputs / Outputs

| | Name | Source / Destination |
|--|------|----------------------|
| In | base | `release_flow` per `../shared/refs/policy-schema.md` §1 — `staging`, falling back to `main` when that branch is absent; the diff comes from `scripts/script-resolve-diff.sh` or a fresh `../shared/refs/verify-prelude.md` |
| In | prd_paths · prior_issues | auto-discovered from `features/prd-<N>-*/` (branch match), or `--prd` — feeds `regression` + the `prd` group · optional `--prior-issues` JSON |
| Out | verdict_json | single JSON per `refs/output-schema.md` — final stdout emission; also written to `.pre-merge/<ts>/verdict.json`, the dispatcher's transport (`../shared/refs/gate-dispatch.md`) |
| Out | run_report + issues_file | `report-prd-<N>-<K>.md` per `../shared/refs/report-schema.md`, paired `.json` on a non-clean verdict — consumed by `eng --build report=`; raw stage logs → `.pre-merge/<timestamp>/<stage>.log` |
| Out | pr | PR feature→staging — the OPEN-PR terminal (`refs/executor.md` §7) |

## Dispatch

**The gate run executes in a subagent.** The main thread is a thin dispatcher: cheap
refusal probes inline (`no_manifest`, `no_diff`), then one backgrounded subagent runs the
whole pipeline, watched under `gate-<epoch>`, result relayed byte-identically
(`../shared/refs/gate-dispatch.md`). The dispatcher runs no check, writes no artifact,
never touches git. The **interview modes stay inline**; every gate run goes to the subagent.

The gate is a **preflight-driven executor** — it runs the resolved `components[]` pipeline
from `devkit/policy.json`, not a fixed step list. Policy load/validate once per run
(`../shared/refs/policy-schema.md` §0/§1 + `policy-schema-pre-merge.md` §2c — merge's half
never loaded); the manifest carries **deltas only**, joined with the catalog by
`script-pipeline-resolve.py`, whose plan the executor quotes verbatim. **SYNC** always
first, the **terminal** always last — OPEN-PR on clean, the issues-file loop otherwise;
the gate never dead-ends.

| Invocation / stage | Ref that owns it |
|---|---|
| the gate run — prune → topo-sort → parallel waves → fail-fast → per-check result reports → aggregate; §3c test selection (opt-IN, off by default); §7 terminals + emission order | `refs/executor.md` |
| SYNC (D7), the un-prunable DAG root | `refs/sync.md` |
| each component's protocol, loaded on demand; `--flaky` / `--changed-only` + the platform components | `refs/universal/*.md`, `refs/platform/*.md`, `refs/prd/*.md`, `refs/_common.md` |
| `--init`, `--update` / `--update-criticality` | `refs/protocol-init.md` / `refs/protocol-update-criticality.md` |
| grading + criticality fail-fast · refusals | `refs/severity-rubric.md` · `refs/refusal-patterns.md` |

Every run ends with the emission order of `refs/executor.md` §7 — run report, terminal
`Issue summary`, verdict JSON (the final machine emission), closing message last.
**Harness incidents:** log per `../shared/refs/doctor-logging.md` — a check that
legitimately fails is not an incident.

## References

- `refs/executor.md` — **the pipeline executor** (C1/C5/C6/C7): §0 staleness nudge, §3b the C23 test sandbox, §3c test selection, §5b emissions, §7 terminals
- `refs/sync.md` · `refs/protocol-init.md` · `refs/protocol-update-criticality.md` · `refs/platform-profiles.md` · `refs/_common.md` · `refs/universal/protocol-{mechanical,unit,integration,coverage,regression,security}.md` · `refs/platform/protocol-{migration,smoke}.md` · `refs/prd/protocol-prd-consistency.md` (**advisory** — grades route to the human test checklist at `merge --staging`, never block)
- `refs/output-schema.md` · `refs/finding-schema.md` · `refs/severity-rubric.md` · `refs/refusal-patterns.md`
- `../shared/refs/` — `policy-schema.md` (§0/§1/§2b) · `policy-schema-pre-merge.md` (`components[]`, `source_signature`, §2c `test_selection`, `criticality_review`) · `component-catalog.md` · `check-report-schema.md` · `env-contract.md` (read at §3b, never written) · `gate-dispatch.md` · `fix-loop.md` · `closing-message.md` · `doctor-logging.md` · `safety-floor.md` · `finding-schema.md` · `report-schema.md` · `verify-prelude.md` · `status-heartbeat.md`
- `.claude/scripts/script-preflight-*.sh` (C4, the detector) · `script-pipeline-resolve.py` (join → prune → C12 → waves → plan JSON; `--check-complete`) · `script-aggregate-verdict.sh` · `scripts/script-resolve-diff.sh`
