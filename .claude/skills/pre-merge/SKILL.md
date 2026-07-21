---
name: pre-merge
description: >
  The CI gate. Takes a feature branch from "eng says done" to "PR open against
  staging with green checks and a human-approved preview". Runs the project's
  preflight-resolved pipeline from devkit/policy.json components[]: sync →
  parallel correctness + security waves → coverage → regression tail →
  security/migration → PRD-consistency → preview deploy (human gate) → open PR.
  Emits a severity-graded verdict JSON. Absorbs the old /review and /test.
  Activates on /pre-merge after eng --build.
argument-hint: "[--init | --update] [--prd <path>] [--flaky <n>]"
allowed_tools:
  - Bash
  - Read
  - Write
  - Agent
  - AskUserQuestion
---

# pre-merge

**The** CI gate. Runs after `eng --build` says a feature branch is done, and takes
it to a PR open against `staging` with green checks and a human-approved preview.
Absorbs the retired `/review` and `/test`. Each run is independent.

```
eng --build  →  /pre-merge  →  (fail → eng --build report=…, repeat)  →  PR feature→staging  →  post-merge --staging
```

## Usage

- `/pre-merge` — gate the current feature branch against `staging`
- `/pre-merge --init` — run the one-time setup: detect tooling (incl. the `.github/workflows/` CI pipeline that runs the gate on PRs) → interview → gated install/scaffold → write `devkit/policy.json` (no gate run); see `refs/protocol-init.md`
  - `/pre-merge --doctor` — **deprecated alias for one release**: runs `--init` and prints a deprecation note naming `--init`/`--update`
- `/pre-merge --update` — reconcile the manifest with codebase reality (re-run preflight checks → diff `components[]` → approve the delta → apply `present`/`active_when`/new-component changes only; never re-grades user-set criticality or re-prompts settled opt-outs); see `refs/protocol-init.md`
- `/pre-merge --prd <path>` — load a PRD; enables the `prd`-group components (`prd-consistency`, `manual-test-plan`) and feeds the `regression` component (repeatable)
- `/pre-merge --prior-issues <path>` — load a prior verdict JSON to mark regressions
- `/pre-merge --full-secret-scan` — the `security` component scans the full tree (default: diff-only)
- `/pre-merge --flaky <N>` — retry failing e2e / unit-int tests up to `N` times before counting a hard failure (`refs/_common.md`)
- `/pre-merge --changed-only` — skip platform components whose surface the diff doesn't touch (`refs/_common.md`)

Natural language: "run pre-merge", "gate this before merge", "open the PR against staging", "run the CI gate".

**Hard refusals** (`refs/refusal-patterns.md`):
- Does NOT modify source code. Its ONLY direct write is the SYNC (D7)-bounded sync-merge commit; regression tests are written by a spawned eng subagent (the `regression` component), never by pre-merge.
- Does NOT `git push`, `gh pr merge`, `git merge` into `main`, or deploy production. It opens exactly one PR (feature→staging, or feature→`main` when no `staging` branch exists) and never merges it.
- Does NOT run without a non-empty diff against base. A missing `staging` branch is NOT a blocker — pre-merge falls back to `main` as the sync + PR target, no warning, no refusal.
- Does NOT grade a finding as blocker without quoted tool evidence.

## Inputs / Outputs

| | Name | Source / Destination |
|--|------|----------------------|
| In | base | resolved via `release_flow` per `../shared/refs/policy-schema.md` §1 — `staged` → `staging_branch` (falls back to `main` when the branch is absent), `direct` → `prod_branch`; no policy → default `staging`, else `main`; diff resolved by `scripts/resolve-diff.sh` / a fresh verify-prelude |
| In | prd_paths | `--prd` (repeatable) — feeds Steps 4 + 7 |
| In | prior_issues | `--prior-issues` JSON, optional |
| Out | verdict_json | single JSON per `refs/output-schema.md` — final stdout emission |
| Out | run_report | `report-prd-<N>-<K>.md` per `../shared/refs/report-schema.md` (first `--prd`'s `reports/`, else `features/reports/` as `report-<K>.md`) |
| Out | issues_file | the run report's paired `.json` (same stem + `reports/` folder as `run_report`) on a non-clean verdict — consumed by `eng --build report=` |
| Out | run_artifacts | raw stage logs → `.pre-merge/<timestamp>/<stage>.log` |
| Out | pr | PR feature→staging (Step 9), verdict JSON + report linked in the body |

Schema: `refs/output-schema.md` · finding shape: `refs/finding-schema.md` (canonical
`../shared/refs/finding-schema.md`) · severity: `refs/severity-rubric.md`.

## Persona

Release engineer on a small product team. Owns the gate: what ships, what blocks,
what gets logged as accepted risk. Repeatable evidence over assertion; severity
matched to reachability. Never modifies source (bar the sync-merge), never merges,
never grades a blocker without quoted evidence. Compact and structured — tables over
prose, severity counts before the issue list, JSON-first.

## Pre-flight — manifest gate (Fork C, BREAKING)

The gate is a **preflight-driven executor** (`refs/executor.md`) — it runs the resolved
`components[]` pipeline from `devkit/policy.json`, not a fixed step list. Load + validate
the policy once per run (`../shared/refs/policy-schema.md` read-contract), then gate on
the **manifest**:

| state | behavior |
|---|---|
| `components[]` present, non-empty | **run** the executor (`refs/executor.md`) |
| file **absent** / malformed / `version` ≠ 1 | **REFUSE `no_manifest`** — name `/pre-merge --init`, run **zero** components (`refs/refusal-patterns.md`) |
| **pre-v3** `policy.json` (`init`/`release_flow`, **no** `components[]`) | **REFUSE `no_manifest`** + upgrade nudge — name `/pre-merge --init` |

This is the **breaking cutover** (Fork C, AC-PF13/PF14): the old "file absent → run on
built-in defaults" fallback is **retired** (`AC-LC6`/`AC-ST5` retired). There is no
defaults path and no inline auto-`--init` — a run without a `components[]` manifest does
nothing but tell the user to run `/pre-merge --init`, which detects the pipeline and
writes the manifest. The old per-step policy self-consult (the retired `steps` entries)
is superseded by component **presence** (an absent component simply isn't in the
pipeline). The loaded policy still drives base resolution (below).

**Manifest staleness nudge (Fork E, read-only).** With a valid manifest, the executor
**recomputes** `source_signature` cheaply (the sha256 over the sorted
`id:present:run:tooling.chosen` lines, per `../shared/refs/policy-schema.md`) and, on
mismatch, prints one line — *"pipeline may be stale — run `/pre-merge --update`"* — then
**proceeds on the current manifest**. The gate **never** writes `policy.json` or mutates
`components[]`; only `--init`/`--update` do (AC-UP5/UP6).

## The pipeline executor (replaces the old fixed gate sequence)

The full algorithm — manifest read → prune → runtime topo-sort → parallel waves →
fail-fast → per-check result reports → aggregate — lives in **`refs/executor.md`**;
this file stays the spine. In outline:

1. **Prelude — diff + base.** Resolve base (`staging`, else `main`) and the diff:
   consume a fresh `../shared/refs/verify-prelude.md` if present, else run
   `scripts/resolve-diff.sh <base>`; empty diff → refuse `no_diff`
   (`refs/refusal-patterns.md`). Best-effort write the prelude. **Tooling is
   already resolved** into each component's `run` command in the manifest (by
   `--init`/`--update` via the `preflight-check-*.sh` family) — the gate does not
   re-detect tooling.
2. **SYNC (D7) — the un-prunable DAG root.** Fetch + merge the sync target
   (`staging`, else `main`); trivial conflicts auto-resolve, semantic same-hunk
   pause; the sync-merge commit is the sole direct write; no `staging` → fall back
   to `main` (no refusal). Every component implicitly depends on SYNC — the tree
   is synced before anything runs (`refs/sync.md`).
3. **Resolve the pipeline** from `components[]` — include `present`/`mandatory`
   components whose `active_when` gate is met; apply `--changed-only`/`--prd`/
   `--flaky` pruning. An absent component produces **no** step and **no** note
   (AC-PF6). `security` + `migration` are always in (Fork D).
4. **Topo-sort + run in waves.** Order = topological sort on `depends_on`, ties
   broken by `criticality` then `cost` (AC-PF7). Independent components in a wave
   run as **parallel subagents**; dependents never run concurrently (AC-PF8/9).
   For universal+prd this is `{mechanical·security·unit·prd-consistency}` ‖ →
   the **env wave** `{integration·e2e·a11y·perf·load·mobile}` inside the **C23
   test-sandbox** (one ephemeral isolated env, provisioned only-on-green after the
   static waves, promoted to serve as the preview, torn down after — `refs/executor.md`
   §3b) → `{coverage}` → `{regression}` (C5, AC-SEQ1). Static (`needs_env:false`)
   components never enter the sandbox; `preview`/`smoke` are the only-on-green tail.
   Each protocol loads its ref on demand (`refs/universal/*`, `refs/platform/*`,
   `refs/prd/*`).
5. **Fail-fast by `criticality`** (`refs/severity-rubric.md`): `critical` aborts the
   remaining pipeline (mechanical/security/migration short-circuit); `blocking`
   fails the verdict, marks downstream dependents `blocked`, lets independent
   branches finish; `advisory`/`config-driven` never aborts (AC-PF11).
6. **Every component writes a result report** to `.pre-merge/<ts>/<check>.json` —
   pass, fail, or skip, on **every** run (C6, AC-RR1) — the `result` section of
   `../shared/refs/check-report-schema.md`. `unit` emits the same shape as every
   check.
7. **OPEN-PR / issues-loop — the un-prunable terminal.** On clean → open the PR;
   on non-clean → the Issues-file loop (below). The gate never dead-ends.

## Aggregate + emit (from the per-check result reports)

The per-check result reports (§6) are the executor's **single uniform aggregation
input** (AC-RR6/UR6) — the verdict and universal report are *derived*, never
authored separately. Full detail in `refs/executor.md`; in outline:

1. **Collect** every result report's `findings[]`; filter nulls.
2. **Dedup** by `(category, file, line, rule)` — keep highest severity, concatenate `source` (`refs/finding-schema.md`).
3. **Triage** with `refs/severity-rubric.md` (in-diff weighting, dev-only / unreachable downgrades, profile coverage floor).
4. **Mark regressions** from `--prior-issues` on `(category, file, rule)`.
5. **Verdict:** `fail` (any blocker/high) · `pass_with_warnings` (only medium/low) · `pass` (zero) · `refused`/`skipped` (early-termination paths).
6. **Run report** — write `report-prd-<N>-<K>.md` per `../shared/refs/report-schema.md` (`skill: pre-merge`; `## Test results` = one line per check for pass AND fail, sourced from the result reports' `checks[]`; `tests_passed`/`tests_failed` summed from their `totals`; `## How to verify` lists the resolved, ordered pipeline + what flags pruned — AC-RR3/PF15). Best-effort; skip on `refused`/`skipped`.
7. **Terminal issue summary** — on **every** report write, all verdicts, print the `Issue summary` block to the terminal (exact format owned by `../shared/refs/report-schema.md`); counts derive from the run's canonical `findings[]` (`category` / `severity`). A clean run prints exactly `Issue summary — 0 issues`.
8. Print the JSON per `refs/output-schema.md` as the **final emission** — shape **unchanged** (AC-PF16); the optional additive `pipeline` field carries the resolved ordered pipeline for observability.

## Issues-file loop (non-clean verdict)

On `fail`, write the **issues file** — the run report's paired `.json` (same stem,
same `reports/` folder, sharing its N and K) — the **universal report** (C7). It
carries the same canonical-finding `issues[]` + `context` + `summary` + `followUp`
the prior verdict artifact carried, now **plus** an additive `checks[]` block (the
per-check run picture, sourced from the result reports — AC-UR2). The
`followUp.status` contract is kept — **camelCase**, the key `eng --build` writes
back and the `--gui` board reads (AC-UR4). `checks[]` is additive to the existing
shape, not a rename (AC-PF16). It is consumed by
`eng --build report=<that .json path>`, which fixes `issues[]` using `checks[]` for
context and the branch comes back through the gate. `followUp.suggested_command` =
`eng --build report=<that .json path>` — kept as the deep-link fallback
`fix-loop.md` resumes from if the user declines.

Once the issues file **and** the run report are written, hand off to
`../shared/refs/fix-loop.md` — it runs Offer #1 (plan the fixes with `eng --plan`)
→ Offer #2 (orchestrated `eng --build`) off this same issues file. Do **not**
re-spell the offer wording here; fix-loop.md owns it. The gate does not dead-end on
the issues file — the loop walks the user from "issues found" to "fixes planned + built".

## OPEN-PR — the terminal (clean verdict only)

On `pass` / `pass_with_warnings` **and** an approved preview (when the gate fired):
`gh pr create --base <target> --head <feature-branch>` (where `<target>` is the
SYNC target — `staging`, else `main`) with the verdict JSON + report
path linked in the body. Record `pr_url`. **Never** `gh pr merge` — post-merge
`--staging` merges it on green CI (Part C). On a non-clean verdict, skip OPEN-PR —
no PR opens; the **Issues-file loop** above runs instead (issues file → fix-loop),
so the gate never dead-ends.

## References

- `refs/executor.md` — **the pipeline executor** (C1/C5/C6/C7): manifest read → prune → topo-sort → parallel waves → fail-fast → per-check result reports → aggregate. The spine points here for the full algorithm
- `refs/platform-profiles.md` — profile → per-component `criticality` override layer from `devkit/PLATFORMS.md`
- `refs/sync.md` — SYNC (D7, the DAG root) sync-merge + conflict handling
- `refs/universal/protocol-mechanical.md` — `mechanical` lint/format/typecheck/comment/commit-cap (scripts, no LLM; critical, short-circuits)
- `refs/universal/protocol-unit.md`, `refs/universal/protocol-integration.md` — `unit` + `integration` suites (Wave 1)
- `refs/universal/protocol-regression.md` — `regression` accumulated suite + spawned eng-subagent authoring (D9/D5; tail-pinned)
- `refs/universal/protocol-coverage.md` — `coverage` (`depends_on unit,integration`; Wave 2)
- `refs/_common.md` + `refs/platform/*.md` — platform components + `--flaky`/`--changed-only`
- `refs/universal/protocol-security.md`, `refs/platform/protocol-migration.md` — the mandatory safety-floor components
- `refs/prd/protocol-prd-consistency.md` — `prd`-group spec-match pass (Wave 1, `active_when --prd`)
- `refs/platform/protocol-preview.md` — `preview` deploy + human gate (D6/D10; only-on-green tail)
- `refs/protocol-init.md` — `--init`/`--update` mode: detect → interview → gated install → assemble `components[]` → write `devkit/policy.json`; `--doctor` is a deprecated one-release alias for `--init` (see Usage)
- `../shared/refs/policy-schema.md` — `devkit/policy.json` schema + read-contract (`components[]` manifest, base `release_flow`, `source_signature`)
- `../shared/refs/component-catalog.md` — component metadata (schema, defaults, `depends_on` edges, grouping) the manifest + executor key off
- `refs/output-schema.md` — final emission schema (shape unchanged, AC-PF16) · `refs/finding-schema.md` — per-finding shape
- `refs/severity-rubric.md` — grading + criticality fail-fast rules · `refs/refusal-patterns.md` — refusal shapes (incl. `no_manifest`)
- `../shared/refs/finding-schema.md`, `../shared/refs/report-schema.md`, `../shared/refs/verify-prelude.md`
- `../shared/refs/fix-loop.md` — post-failure Offer #1 → Offer #2 sequence the issues-file loop hands off to
- `../shared/refs/check-report-schema.md` — the normalized check-report schema (`detect` + `result` sections); the executor writes the `result` section per check and aggregates them
- `.claude/scripts/preflight-check-*.sh` — the per-check detect+normalize family (C4); `--init`/`--update` run + ingest them into `components[]` (`refs/protocol-init.md`). **These + the manifest are the detector now — the monolithic pre-merge tooling detector is retired (v3 P3)**
- `.claude/scripts/pre-merge-aggregate-verdict.sh` — per-component verdict aggregation/merge helper
- `scripts/resolve-diff.sh` — diff-vs-base structured summary
