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
  - Bash
  - Read
  - Write
  - Agent
  - AskUserQuestion
---

Running under OpenAI Codex? Read `shared/refs/harness-map.md` first and apply its bindings; under Claude Code, skip it.

# pre-merge

**The** CI gate. Runs after `eng --build` says a feature branch is done and takes it
to a PR open against `staging` with green checks. Pre-merge holds **no human gate**
— the human look at the running feature belongs to merge (the staging sign-off, or
the direct-flow attestation when there is no staging branch);
`../shared/refs/safety-floor.md` § *Human gates*. Absorbs the retired `/review` and
`/test`. Each run is independent.

```
eng --build  →  /pre-merge  →  (fail → eng --build report=…, repeat)  →  PR feature→staging  →  merge --staging
```

## Usage

- `/pre-merge` — gate the current feature branch against `staging`
- `/pre-merge --init` — the one-time setup: detect tooling → interview → gated install/scaffold → write `devkit/policy.json`; no gate run (`refs/protocol-init.md`). The `.github/workflows/` CI pipeline is part of the detect unless `policies.github_actions.enabled` is `false` — a settled opt-out, not a gap
- `/pre-merge --update` — reconcile the manifest with codebase reality: re-run preflight → diff `components[]` → approve the delta → apply `present`/`active_when`/new-component changes only, never re-grading user-set criticality or re-prompting settled opt-outs (`refs/protocol-init.md`)
- `/pre-merge --update-criticality` — the criticality reconcile: inventory untagged tests → evidence-cited proposals → one human gate → markers committed + `criticality_review` restamped (`refs/protocol-update-criticality.md`)
- `/pre-merge --prd <path>` (repeatable) — name the PRD explicitly. The `prd` group (`prd-consistency`, `manual-test-plan`) runs by default whenever a `features/prd-<N>-*/` PRD matches the branch; this flag overrides an ambiguous or missing match
- `/pre-merge --prior-issues <path>` — load a prior verdict JSON to mark regressions
- `/pre-merge --full-secret-scan` — the `security` component scans the full tree (default: diff-only)
- `/pre-merge --flaky <N>` — retry failing e2e / unit-int tests up to `N` times before a hard failure (`refs/_common.md`)
- `/pre-merge --changed-only` — skip platform components whose surface the diff doesn't touch (`refs/_common.md`)
- `/pre-merge --minified` — force **test selection** on for this run even when `policies.test_selection` is off (a trial); nothing is written (`refs/executor.md` §3c)
- `/pre-merge --full` — force the **full** suites — the kill switch. Flag beats policy: `--full` > `--minified` > `policies.test_selection`
- `/pre-merge --quiet` — suppress this run's status heartbeat
- `/pre-merge --status <n>m` — override the heartbeat interval for this run; flag beats policy beats default, floor 2 minutes (`../shared/refs/status-heartbeat.md`)

Natural language: "run pre-merge", "gate this before merge", "open the PR against staging", "run the CI gate".

## Posture

Release engineer on a small product team. Owns the gate: what ships, what blocks,
what gets logged as accepted risk — repeatable evidence over assertion, severity
matched to reachability. Compact and structured: tables over prose, JSON-first.

## Hard refusals

Shapes and JSON in `refs/refusal-patterns.md`. Pre-merge:

- Does NOT run without a manifest. No `components[]` in `devkit/policy.json` ⇒ **REFUSE `no_manifest`**, zero components run, naming `/pre-merge --init`. No built-in-defaults path, no inline auto-`--init` (state table: `refs/refusal-patterns.md` § `no_manifest`, its one home).
- Does NOT modify source code. Its ONLY direct write is the SYNC (D7)-bounded sync-merge commit; regression tests are written by a spawned eng subagent, never by pre-merge.
- Does NOT `git push`, `gh pr merge`, `git merge` into `main`, or deploy production. It opens exactly one PR (feature→staging, or feature→`main` when no `staging` branch exists) and never merges it.
- Does NOT run without a non-empty diff against base (`no_diff`). A missing `staging` branch is NOT a blocker — the sync + PR target falls back to `main`, no warning, no refusal.
- Does NOT grade a finding as blocker without quoted tool evidence.
- Does NOT write `policy.json` or mutate `components[]` — only `--init` / `--update` do. Staleness nudges (manifest, `refs/executor.md` §0; untagged tests, `refs/protocol-update-criticality.md`) are read-only.

## Inputs / Outputs

| | Name | Source / Destination |
|--|------|----------------------|
| In | base | `release_flow` per `../shared/refs/policy-schema.md` §1 — `staging`, falling back to `main` when that branch is absent; the diff comes from `scripts/script-resolve-diff.sh` or a fresh `../shared/refs/verify-prelude.md` |
| In | prd_paths | auto-discovered from `features/prd-<N>-*/` (branch match), or `--prd` — feeds `regression` + the `prd` group |
| In | prior_issues | `--prior-issues` JSON, optional |
| Out | verdict_json | single JSON per `refs/output-schema.md` — final stdout emission |
| Out | run_report | `report-prd-<N>-<K>.md` per `../shared/refs/report-schema.md` (first `--prd`'s `reports/`, else `features/reports/report-<K>.md`) |
| Out | issues_file | the run report's paired `.json`, on a non-clean verdict — consumed by `eng --build report=` |
| Out | run_artifacts | raw stage logs → `.pre-merge/<timestamp>/<stage>.log` |
| Out | verdict_file | `.pre-merge/<timestamp>/verdict.json` — the verdict JSON written to disk, byte-identical to the stdout emission; the dispatcher's transport (`../shared/refs/gate-dispatch.md`) |
| Out | pr | PR feature→staging (the OPEN-PR terminal) |

Schema: `refs/output-schema.md` · finding shape: `refs/finding-schema.md` (canonical
`../shared/refs/finding-schema.md`) · severity: `refs/severity-rubric.md`.

## Dispatch

**The gate run executes in a subagent.** The main thread is a thin dispatcher:
it runs the cheap refusal probes inline (`no_manifest`, `no_diff` — so a refusal
costs no spawn), then spawns one backgrounded subagent that runs the whole pipeline,
watches it under a gate-scoped run-id `gate-<epoch>`, and relays the result. The
contract — probe, spawn, register + watch, relay, close — is
`../shared/refs/gate-dispatch.md`; nothing about it is restated here. The dispatcher
runs no check, writes no artifact, and never touches git.

The **interview modes stay inline**, unchanged: `--init`, `--update`,
`--update-criticality` are cheap and conversational, and dispatching them would buy
nothing. Everything else — the bare gate run with any combination of run flags
(`--flaky`, `--minified`, `--full`, `--prd`, `--changed-only`, `--quiet`,
`--status`) — goes to the subagent. Output is unaffected either way: the verdict
JSON and every report file are byte-identical to an inline run.

The gate is a **preflight-driven executor** — it runs the resolved `components[]`
pipeline from `devkit/policy.json`, not a fixed step list. Load and validate the
policy once per run (`../shared/refs/policy-schema.md` §0/§1 plus
`../shared/refs/policy-schema-pre-merge.md` §2c — merge's half is never loaded),
gate on the manifest per the `no_manifest` refusal above, then run the pipeline. The
manifest carries **deltas only**: catalog constants resolve from
`../shared/refs/component-catalog.md` by `id` at run time, and
`.claude/scripts/script-pipeline-resolve.py` joins the two and prints the run's plan,
which the executor quotes verbatim instead of re-deriving it.

| Invocation / stage | Ref that owns it |
|---|---|
| the gate run — prune → topo-sort → parallel waves → fail-fast → per-check result reports → aggregate | `refs/executor.md` (the spine points there) |
| SYNC (D7), the un-prunable DAG root | `refs/sync.md` |
| each component's protocol, loaded on demand | `refs/universal/*.md`, `refs/platform/*.md`, `refs/prd/*.md` |
| `--flaky`, `--changed-only`, the platform components | `refs/_common.md` |
| `--minified` / `--full` test selection | `refs/executor.md` §3c |
| `--init`, `--update` | `refs/protocol-init.md` |
| `--update-criticality` | `refs/protocol-update-criticality.md` |
| grading + criticality fail-fast | `refs/severity-rubric.md` |
| refusals (incl. `no_manifest`, `no_diff`) | `refs/refusal-patterns.md` |

Two anchors are un-prunable and bound every run: **SYNC** first (everything
implicitly depends on it, so the tree is synced before anything runs) and the
**terminal** last — OPEN-PR on a clean verdict, the issues-file loop otherwise. The
gate never dead-ends.

**Test selection (opt-IN, off by default).** When it resolves enabled (`--full` >
`--minified` > `policies.test_selection`), the selection-capable components —
`unit`, `integration`, `regression` — run `run_minified` (*affected(diff) ∪ the
critical floor*) instead of their full suites. Rule, tier rubric and recording
contract: `refs/executor.md` §3c; key schema:
`../shared/refs/policy-schema-pre-merge.md` § `policies.test_selection`. Disabled ⇒
byte-identical to today: nothing read, nothing emitted.

## Emission

The per-check result reports are the executor's **single aggregation input** — the
verdict and the run report are *derived*, never authored separately
(`refs/executor.md`). Every run ends with, in order:

1. **Run report** — `report-prd-<N>-<K>.md` per `../shared/refs/report-schema.md` (`skill: pre-merge`). Best-effort; skipped on `refused` / `skipped`.
2. **Terminal `Issue summary` block** — every verdict; format owned by `../shared/refs/report-schema.md`, counts from the canonical `findings[]`. A clean run prints exactly `Issue summary — 0 issues`.
3. **The verdict JSON** per `refs/output-schema.md`, shape **unchanged**: `fail` (any blocker/high) · `pass_with_warnings` (only medium/low) · `pass` (zero) · `refused` / `skipped`. Additive: `pipeline` (the resolved order) and, only when selection ran, `test_selection`. The same JSON is **also written to `.pre-merge/<ts>/verdict.json`** — that file is the dispatcher's transport, `cat`-ed and re-emitted byte-identically, never paraphrased from the subagent's return text (`../shared/refs/gate-dispatch.md` § *Relay, don't rewrite*).
4. **Closing message** — end the run (every verdict, including `refused` / `skipped`) with the closing message per `../shared/refs/closing-message.md` as the last **chat** output; the step-3 JSON stays the final **machine** emission, byte-identical.

**Harness incidents (every run):** log unexpected script failures, tool errors,
retries, missed writes, and broken gate infrastructure (CI, sandbox, checkout) to
`devkit/DOCTOR.md` per `../shared/refs/doctor-logging.md`. A **check that
legitimately fails is not an incident** — only the harness breaking is. Logging
never changes the verdict or what the run does next.

## Terminals

**OPEN-PR — clean verdict only.** On `pass` / `pass_with_warnings`:
`gh pr create --base <target> --head <feature-branch>` (`<target>` = the SYNC target,
`staging` else `main`), verdict JSON + report path linked in the body, `pr_url`
recorded. **Never** `gh pr merge` — `merge --staging` merges it on green CI.

**Issues-file loop — non-clean verdict.** No PR opens. Write the **issues file** —
the run report's paired `.json` (same stem, folder, N and K), the **universal
report** (C7): canonical `issues[]` + `context` + `summary` + `followUp`, **plus**
an additive `checks[]` block from the result reports.
`followUp.status` keeps its **camelCase** contract — the key `eng --build` writes
back and the `--gui` board reads — and `followUp.suggested_command` = `eng --build
report=<that .json path>`. With both files written, hand off to
`../shared/refs/fix-loop.md`, which owns Offer #1 (`eng --plan`) → Offer #2 (`eng
--build`) off this same file; do **not** re-spell that wording here. The fixed
branch comes back through the gate.

## References

- `refs/executor.md` — **the pipeline executor** (C1/C5/C6/C7), the whole algorithm; §0 staleness nudge, §3b the C23 test sandbox, §3c test selection
- `refs/sync.md` — SYNC (D7, the DAG root): sync-merge + conflicts
- `refs/protocol-init.md` — `--init` / `--update`; also the test-selection enabling interview
- `refs/protocol-update-criticality.md` — `--update-criticality`; also the read-only staleness nudge
- `refs/platform-profiles.md` — profile → `criticality` overrides from `devkit/PLATFORMS.md`
- `refs/_common.md` + `refs/platform/*.md` — platform components + `--flaky` / `--changed-only`
- `refs/universal/protocol-mechanical.md` (critical, short-circuits) · `refs/universal/protocol-unit.md` · `refs/universal/protocol-integration.md` · `refs/universal/protocol-coverage.md` · `refs/universal/protocol-regression.md` (spawned-eng authoring, tail-pinned)
- `refs/universal/protocol-security.md`, `refs/platform/protocol-migration.md` — the mandatory safety-floor pair
- `refs/platform/protocol-smoke.md` — liveness + golden path, first inside the env sandbox
- `refs/prd/protocol-prd-consistency.md` — `prd`-group spec match (**advisory** — its grades route to the human test checklist walked at `merge --staging`, they never block)
- `refs/output-schema.md` · `refs/finding-schema.md` · `refs/severity-rubric.md` · `refs/refusal-patterns.md` — emission shape, finding shape, grading + fail-fast, refusal shapes (incl. `no_manifest`)
- `../shared/refs/policy-schema.md` — the shared core of `devkit/policy.json` (§0 `init`, §1 `release_flow`, §2b `github_actions`)
- `../shared/refs/policy-schema-pre-merge.md` — pre-merge's half: the `components[]` delta manifest, `source_signature`, `policies.test_selection` §2c, the `criticality_review` stamp
- `../shared/refs/component-catalog.md` — the component metadata the manifest + executor key off
- `../shared/refs/check-report-schema.md` — the `detect` + `result` sections the executor writes per check and aggregates
- `../shared/refs/env-contract.md` — the `devkit/ENV.md` `provision`/`seed`/`reset`/`teardown` block read at executor §3b (gate runs never write it)
- `../shared/refs/gate-dispatch.md` — the dispatcher contract: gate runs execute in a subagent behind a thin main-thread dispatcher (probe → backgrounded spawn → `gate-<epoch>` watch → byte-identical verdict relay → close)
- `../shared/refs/fix-loop.md` · `../shared/refs/closing-message.md` · `../shared/refs/doctor-logging.md` · `../shared/refs/safety-floor.md` · `../shared/refs/finding-schema.md` · `../shared/refs/report-schema.md` · `../shared/refs/verify-prelude.md` · `../shared/refs/status-heartbeat.md`
- `.claude/scripts/script-preflight-*.sh` — the per-check detect+normalize family (C4), ingested into `components[]` by `--init`/`--update`. **These + the manifest are the detector now (v3 P3)**
- `.claude/scripts/script-pipeline-resolve.py` — **the pipeline resolver**: join → prune → C12 coverage-gap correlation → topo-sorted waves → plan JSON; `--check-complete` verifies every planned component reported
- `.claude/scripts/script-aggregate-verdict.sh` — the aggregation half: collect → dedup → downgrades → verdict + summary + `checks[]` + critical-abort signal
- `scripts/script-resolve-diff.sh` — diff-vs-base structured summary
