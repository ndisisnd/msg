---
name: pre-merge
description: >
  The CI gate. Takes a feature branch from "eng says done" to "PR open against
  staging with green checks and a human-approved preview": sync → mechanical →
  unit/int → regression → platform components → security/migration → PRD-consistency
  → preview deploy (human gate) → open PR. Platform-tolerance profiles from
  devkit/PLATFORMS.md. Emits a severity-graded verdict JSON. Absorbs the old
  /review and /test. Activates on /pre-merge after eng --build.
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
- `/pre-merge --prd <path>` — load a PRD for the regression (Step 4) + PRD-consistency (Step 7) stages (repeatable)
- `/pre-merge --prior-issues <path>` — load a prior verdict JSON to mark regressions
- `/pre-merge --full-secret-scan` — Step 6 scans the full tree (default: diff-only)
- `/pre-merge --flaky <N>` — retry failing e2e / unit-int tests up to `N` times before counting a hard failure (`refs/_common.md`)
- `/pre-merge --changed-only` — skip platform components whose surface the diff doesn't touch (`refs/_common.md`)

Natural language: "run pre-merge", "gate this before merge", "open the PR against staging", "run the CI gate".

**Hard refusals** (`refs/refusal-patterns.md`):
- Does NOT modify source code. Its ONLY direct write is the Step 1 D7-bounded sync-merge commit; regression tests are written by a spawned eng subagent (Step 4), never by pre-merge.
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

## Pre-flight — `init` lifecycle (before Step 0)

Before the diff prelude, load + validate `devkit/policy.json` once per run and check
`init` per `../shared/refs/policy-schema.md` §0 (that ref owns the exact rules):

| state | behavior |
|---|---|
| file **absent** | proceed on built-in defaults + one nudge line to run `/pre-merge --init` or `/msg --init`; **no** auto-init (back-compat, AC-LC6) |
| `init: false` | **run `--init` inline first** (`refs/protocol-init.md`) — it flips `init: true`, then the gate continues; if the user **aborts** `--init`, stop and run **no** protocol step (AC-LC2, AC-LC4) |
| `init: true` | proceed normally — no init run (AC-LC5) |

Malformed / `version` ≠ 1 → whole file treated as absent (defaults + one info line). The
loaded policy also drives base resolution (below) and the Steps 2/3/5/6 consult.

**Manifest staleness nudge (v3, Fork E).** When the loaded policy carries a v3
`components[]` + `source_signature`, the gate **recomputes** the signature cheaply (the
sha256 over the sorted `id:present:run:tooling.chosen` lines, per
`../shared/refs/policy-schema.md`) and, on mismatch, prints one line — *"pipeline may be
stale — run `/pre-merge --update`"* — then **proceeds on the current manifest**. The gate
**never** writes `policy.json` or mutates `components[]`; only `--init`/`--update` do
(AC-UP5/UP6). This is a read-only nudge — the gate sequence below is unchanged, and the
executor cutover that actually *runs* from `components[]` lands at P3.

## The gate sequence (Steps 0–9)

Run in order. Any **red** step short-circuits per `refs/severity-rubric.md`; on a
non-clean run Step 9's PR is skipped and the run enters the **Issues-file loop**
(below) instead of opening it — the gate does not dead-end. Each step loads its
ref on demand — this file stays the spine.

| # | Step | Ref | Notes |
|---|------|-----|-------|
| 0 | **Platform mode** — resolve the strictness profile + component set from `devkit/PLATFORMS.md`; missing → `standard` + warn to run `/msg --init` | `refs/platform-profiles.md` | sets `profile`, `required_buckets`, `coverage_mode`, `preview_map`, `preview_always` |
| — | **Diff + tooling** — consume a fresh `../shared/refs/verify-prelude.md` if present, else run `scripts/resolve-diff.sh <base>` + `.claude/scripts/pre-merge-tooling-detect.sh`; empty diff → refuse `no_diff`. Best-effort write the prelude (producer + consumer). | `refs/refusal-patterns.md` | base defaults to `staging`, else `main` |
| 1 | **SYNC (D7)** — fetch + merge the sync target (`staging`, else `main`); trivial conflicts auto-resolve, semantic same-hunk pause; the sync-merge commit is the sole direct write; no `staging` → fall back to `main` (no refusal) | `refs/sync.md` | Steps 3–4 always re-run post-sync |
| 2 | **MECHANICAL** — lint / format / typecheck / comment-coverage / per-commit commit-cap audit; scripts, no LLM | `refs/universal/protocol-mechanical.md` | a `blocker` here short-circuits |
| 3 | **UNIT + INTEGRATION** — run the unit+integration suite (re-run post-sync) | `refs/universal/protocol-unit.md`, `refs/universal/protocol-integration.md`, `refs/_common.md` (`--flaky`) | non-zero exit → `blocker`; `test_runner` null → try the stack's conventional invocation (e.g. `python3 -m pytest`, `npm test`), else record `skipped`/`no_tooling` — a missing runner is never a blocker |
| 4 | **REGRESSION (D9+D5)** — run `tests/regression/prd-*/`; spawn an eng subagent to author this PRD's regression tests to `tests/regression/prd-<n>/`; pre-merge runs + grades them (never authors what it grades); prior-test edits need a PRD-clause citation | `refs/universal/protocol-regression.md` | |
| 5 | **PLATFORM COMPONENTS** — e2e / qa / mobile / perf / a11y / coverage / api / load, only the profile's `required_buckets`, each a parallel subagent | `refs/platform/*.md` | never hardcoded |
| 6 | **SECURITY + MIGRATION (safety floor)** — secret + SAST + dependency scan then a /cook semantic pass; static SQL-safety scan + /cook pass when the diff touches migrations | `refs/universal/protocol-security.md`, `refs/platform/protocol-migration.md` | run in every profile |
| 7 | **PRD-CONSISTENCY** — one spec-match pass: every F-ID's acceptance criteria met by the diff, nothing out-of-scope shipped | `refs/prd/protocol-prd-consistency.md` | skipped (noted) with no `--prd` |
| 8 | **PREVIEW DEPLOY (human gate)** — fires on the D6 path heuristic (UI / API / schema / migration paths), always in `strict`; produces the profile's `preview_kind` (url/artifact/screenshots); **BLOCKS on human approval** | `refs/platform/protocol-preview.md` | no trigger → skipped + noted |
| 9 | **OPEN PR feature→staging** — with the verdict JSON + report linked in the body | below | never merges, never touches `main` |

**Policy consult (Steps 2, 3, 5, 6).** Before running, each of these steps consults its
`steps.<key>` entry in the loaded `devkit/policy.json` per `../shared/refs/policy-schema.md`
§3: `opted_out` / `n/a` → **skip silently** (zero findings/warnings); `ready` + live tool
absent → one `medium` `policy-mismatch` finding, **then** the step's existing no-tooling
path; `missing` / `deferred` → the existing `no_tooling` note; **key absent / no `policy.json`
→ today's behavior unchanged** (back-compat invariant, AC-ST5). Except for the
`policy-mismatch` finding, a `steps` entry never changes the pass/fail verdict.

## Aggregate + emit (after Step 8)

1. **Collect** all stage/component return values; filter nulls.
2. **Dedup** by `(category, file, line, rule)` — keep highest severity, concatenate `source` (`refs/finding-schema.md`).
3. **Triage** with `refs/severity-rubric.md` (in-diff weighting, dev-only / unreachable downgrades, profile coverage floor).
4. **Mark regressions** from `--prior-issues` on `(category, file, rule)`.
5. **Verdict:** `fail` (any blocker/high) · `pass_with_warnings` (only medium/low) · `pass` (zero) · `refused`/`skipped` (early-termination paths).
6. **Run report** — write `report-prd-<N>-<K>.md` per `../shared/refs/report-schema.md` (`skill: pre-merge`; one line per gate stage in `## Test results`; plain-language `## How to verify`). Best-effort; skip on `refused`/`skipped`.
7. **Terminal issue summary** — on **every** report write, all verdicts, print the `Issue summary` block to the terminal (exact format owned by `../shared/refs/report-schema.md`); counts derive from the run's canonical `findings[]` (`category` / `severity`). A clean run prints exactly `Issue summary — 0 issues`.
8. Print the JSON per `refs/output-schema.md` as the **final emission**.

## Issues-file loop (non-clean verdict)

On `fail`, write the **issues file** — the run report's paired `.json` (same stem,
same `reports/` folder, sharing its N and K) — carrying the same canonical-finding
`issues[]` shape the prior verdict artifact carried (`followUp.status` contract kept —
camelCase, the key `eng --build` writes back and the `--gui` board reads). It is
consumed by `eng --build report=<that .json path>`, which fixes the findings and the
branch comes back through the gate. `followUp.suggested_command` =
`eng --build report=<that .json path>` — kept as the deep-link fallback
`fix-loop.md` resumes from if the user declines.

Once the issues file **and** the run report are written, hand off to
`../shared/refs/fix-loop.md` — it runs Offer #1 (plan the fixes with `eng --plan`)
→ Offer #2 (orchestrated `eng --build`) off this same issues file. Do **not**
re-spell the offer wording here; fix-loop.md owns it. The gate does not dead-end on
the issues file — the loop walks the user from "issues found" to "fixes planned + built".

## Step 9 — Open the PR (clean verdict only)

On `pass` / `pass_with_warnings` **and** an approved preview (when the gate fired):
`gh pr create --base <target> --head <feature-branch>` (where `<target>` is the
Step 1 sync target — `staging`, else `main`) with the verdict JSON + report
path linked in the body. Record `pr_url`. **Never** `gh pr merge` — post-merge
`--staging` merges it on green CI (Part C). On a non-clean verdict, skip Step 9 —
no PR opens; the **Issues-file loop** above runs instead (issues file → fix-loop),
so the gate never dead-ends.

## References

- `refs/platform-profiles.md` — Step 0 profile + component-set resolution from `devkit/PLATFORMS.md`
- `refs/sync.md` — Step 1 sync-merge + conflict handling (D7)
- `refs/universal/protocol-mechanical.md` — Step 2 lint/format/typecheck/comment/commit-cap (scripts, no LLM)
- `refs/universal/protocol-unit.md`, `refs/universal/protocol-integration.md` — Step 3 unit + integration suites
- `refs/universal/protocol-regression.md` — Step 4 accumulated suite + spawned eng-subagent authoring (D9/D5)
- `refs/_common.md` + `refs/platform/*.md` — Step 5 platform components + `--flaky`/`--changed-only`
- `refs/universal/protocol-security.md`, `refs/platform/protocol-migration.md` — Step 6 safety-floor stages
- `refs/prd/protocol-prd-consistency.md` — Step 7 spec-match pass
- `refs/platform/protocol-preview.md` — Step 8 preview deploy + human gate (D6/D10)
- `refs/protocol-init.md` — `--init` mode: detect → interview → gated install → write `devkit/policy.json`; `--doctor` is a deprecated one-release alias for `--init` (see Usage)
- `../shared/refs/policy-schema.md` — `devkit/policy.json` schema + read-contract (pre-flight `init`, base `release_flow`, Steps 2/3/5/6 `steps.<key>`)
- `../shared/refs/component-catalog.md` — component metadata (schema, defaults, grouping) every step above keys off
- `refs/output-schema.md` — final emission schema · `refs/finding-schema.md` — per-finding shape
- `refs/severity-rubric.md` — grading + short-circuit rules · `refs/refusal-patterns.md` — refusal shapes
- `../shared/refs/finding-schema.md`, `../shared/refs/report-schema.md`, `../shared/refs/verify-prelude.md`
- `../shared/refs/fix-loop.md` — post-failure Offer #1 → Offer #2 sequence the issues-file loop hands off to
- `../shared/refs/check-report-schema.md` — the normalized check-report schema (`detect` + `result` sections) the preflight scripts emit and the executor aggregates
- `.claude/scripts/preflight-check-*.sh` — the per-check detect+normalize family (C4); `--init`/`--update` run + ingest them into `components[]` (`refs/protocol-init.md`)
- `.claude/scripts/pre-merge-tooling-detect.sh` — tooling fingerprint (Step 0/1); **deprecated** — superseded by `preflight-check-*.sh`, still consumed by the pre-P3 gate prelude, removed at P3
- `.claude/scripts/pre-merge-aggregate-verdict.sh` — Step 5 per-component verdict aggregation/merge
- `scripts/resolve-diff.sh` — diff-vs-base structured summary
