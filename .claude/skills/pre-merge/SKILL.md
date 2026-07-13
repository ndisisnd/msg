---
name: pre-merge
description: >
  The CI gate. Takes a feature branch from "eng says done" to "PR open against
  staging with green checks and a human-approved preview": sync → mechanical →
  unit/int → regression → platform buckets → security/migration → PRD-consistency
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
eng --build  →  /pre-merge  →  (fail → eng --build gate-json=…, repeat)  →  PR feature→staging  →  post-merge --staging
```

## Usage

- `/pre-merge` — gate the current feature branch against `staging`
- `/pre-merge --prd <path>` — load a PRD for the regression (Step 4) + PRD-consistency (Step 7) stages (repeatable)
- `/pre-merge --prior-issues <path>` — load a prior verdict JSON to mark regressions
- `/pre-merge --full-secret-scan` — Step 6 scans the full tree (default: diff-only)
- `/pre-merge --flaky <N>` — retry failing e2e / unit-int tests up to `N` times before counting a hard failure (`refs/buckets/_common.md`)
- `/pre-merge --changed-only` — skip platform buckets whose surface the diff doesn't touch (`refs/buckets/_common.md`)
- `/pre-merge --flash` — flash mode: load `refs/flash/mode-flash.md`. **Step 0 — Mode:** resolve per `../shared/refs/mode-resolution.md` (flag > forwarded > pref > comprehensive).

Natural language: "run pre-merge", "gate this before merge", "open the PR against staging", "run the CI gate".

**Hard refusals** (`refs/refusal-patterns.md`):
- Does NOT modify source code. Its ONLY direct write is the Step 1 D7-bounded sync-merge commit; regression tests are written by a spawned eng subagent (Step 4), never by pre-merge.
- Does NOT `git push`, `gh pr merge`, `git merge` into `main`, or deploy production. It opens exactly one PR (feature→staging) and never merges it.
- Does NOT run without a non-empty diff against base, or without a `staging` branch.
- Does NOT grade a finding as blocker without quoted tool evidence.

## Inputs / Outputs

| | Name | Source / Destination |
|--|------|----------------------|
| In | base | default `staging`; diff resolved by `scripts/resolve-diff.sh` / a fresh verify-prelude |
| In | prd_paths | `--prd` (repeatable) — feeds Steps 4 + 7 |
| In | prior_issues | `--prior-issues` JSON, optional |
| Out | verdict_json | single JSON per `refs/output-schema.md` — final stdout emission |
| Out | run_report | `report-[n].md` per `../shared/refs/report-schema.md` (first `--prd`'s `reports/`, else `features/reports/`) |
| Out | fail_ticket | `msg-gate/gate-<n>.json` on a non-clean verdict — consumed by `eng --build gate-json=` |
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

## The gate sequence (Steps 0–9)

Run in order. Any **red** step short-circuits per `refs/severity-rubric.md`; on a
non-clean run write the fail-ticket (see below) and stop before Step 9's PR. Each
step loads its ref on demand — this file stays the spine.

| # | Step | Ref | Notes |
|---|------|-----|-------|
| 0 | **Platform mode** — resolve the strictness profile + bucket set from `devkit/PLATFORMS.md`; missing → `standard` + warn to run `/msg --init` | `refs/platform-profiles.md` | sets `profile`, `required_buckets`, `coverage_mode`, `preview_map`, `preview_always` |
| — | **Diff + tooling** — consume a fresh `../shared/refs/verify-prelude.md` if present, else run `scripts/resolve-diff.sh <base>` + `.claude/scripts/pre-merge-tooling-detect.sh`; empty diff → refuse `no_diff`. Best-effort write the prelude (producer + consumer). | `refs/refusal-patterns.md` | base defaults to `staging` |
| 1 | **SYNC (D7)** — fetch + merge `staging`; trivial conflicts auto-resolve, semantic same-hunk pause; the sync-merge commit is the sole direct write; no `staging` → refuse `no_staging` | `refs/sync.md` | Steps 3–4 always re-run post-sync |
| 2 | **MECHANICAL** — lint / format / typecheck / comment-coverage / per-commit commit-cap audit; scripts, no LLM | `refs/mechanical.md` | a `blocker` here short-circuits |
| 3 | **UNIT + INTEGRATION** — run the unit+integration suite (re-run post-sync) | `refs/buckets/_common.md` (`--flaky`) | non-zero exit → `blocker`; `test_runner` null → try the stack's conventional invocation (e.g. `python3 -m pytest`, `npm test`), else record `skipped`/`no_tooling` — a missing runner is never a blocker |
| 4 | **REGRESSION (D9+D5)** — run `tests/regression/prd-*/`; spawn an eng subagent to author this PRD's regression tests to `tests/regression/prd-<n>/`; pre-merge runs + grades them (never authors what it grades); prior-test edits need a PRD-clause citation | `refs/regression.md` | |
| 5 | **PLATFORM BUCKETS** — e2e / qa / mobile / perf / a11y / coverage / api / load, only the profile's `required_buckets`, each a parallel subagent | `refs/buckets/*.md` | never hardcoded |
| 6 | **SECURITY + MIGRATION (safety floor)** — secret + SAST + dependency scan then a /cook semantic pass; static SQL-safety scan + /cook pass when the diff touches migrations | `refs/security.md`, `refs/migration.md` | run in every profile |
| 7 | **PRD-CONSISTENCY** — one spec-match pass: every F-ID's acceptance criteria met by the diff, nothing out-of-scope shipped | `refs/prd-consistency.md` | skipped (noted) with no `--prd` |
| 8 | **PREVIEW DEPLOY (human gate)** — fires on the D6 path heuristic (UI / API / schema / migration paths), always in `strict`; produces the profile's `preview_kind` (url/artifact/screenshots); **BLOCKS on human approval** | `refs/preview.md` | no trigger → skipped + noted |
| 9 | **OPEN PR feature→staging** — with the verdict JSON + report linked in the body | below | never merges, never touches `main` |

## Aggregate + emit (after Step 8)

1. **Collect** all stage/bucket return values; filter nulls.
2. **Dedup** by `(category, file, line, rule)` — keep highest severity, concatenate `source` (`refs/finding-schema.md`).
3. **Triage** with `refs/severity-rubric.md` (in-diff weighting, dev-only / unreachable downgrades, profile coverage floor).
4. **Mark regressions** from `--prior-issues` on `(category, file, rule)`.
5. **Verdict:** `fail` (any blocker/high) · `pass_with_warnings` (only medium/low) · `pass` (zero) · `refused`/`skipped` (early-termination paths).
6. **Run report** — write `report-[n].md` per `../shared/refs/report-schema.md` (`skill: pre-merge`; one line per gate stage in `## Test results`; plain-language `## How to verify`). Best-effort; skip on `refused`/`skipped`.
7. Print the JSON per `refs/output-schema.md` as the **final emission**.

## Fail-ticket loop (non-clean verdict)

On `fail`, write `msg-gate/gate-<n>.json` — the same canonical-finding `issues[]`
shape the old `msg-test/test-<n>.json` used (`followUp.status` contract kept —
camelCase, the key `eng --build` writes back and the `--gui` board reads),
numbered `max(suffix)+1` under `msg-gate/`. It is consumed by
`eng --build gate-json=msg-gate/gate-<n>.json`, which fixes the findings and the
branch comes back through the gate. `followUp.suggested_command` =
`eng --build gate-json=msg-gate/gate-<n>.json`.

## Step 9 — Open the PR (clean verdict only)

On `pass` / `pass_with_warnings` **and** an approved preview (when the gate fired):
`gh pr create --base staging --head <feature-branch>` with the verdict JSON + report
path linked in the body. Record `pr_url`. **Never** `gh pr merge` — post-merge
`--staging` merges it on green CI (Part C). On a non-clean verdict, skip Step 9 —
the fail-ticket is the output.

## References

- `refs/platform-profiles.md` — Step 0 profile + bucket-set resolution from `devkit/PLATFORMS.md`
- `refs/sync.md` — Step 1 sync-merge + conflict handling (D7)
- `refs/mechanical.md` — Step 2 lint/format/typecheck/comment/commit-cap (scripts, no LLM)
- `refs/regression.md` — Step 4 accumulated suite + spawned eng-subagent authoring (D9/D5)
- `refs/buckets/_common.md` + `refs/buckets/*.md` — Step 5 platform buckets + `--flaky`/`--changed-only`
- `refs/security.md`, `refs/migration.md` — Step 6 safety-floor stages
- `refs/prd-consistency.md` — Step 7 spec-match pass
- `refs/preview.md` — Step 8 preview deploy + human gate (D6/D10)
- `refs/output-schema.md` — final emission schema · `refs/finding-schema.md` — per-finding shape
- `refs/severity-rubric.md` — grading + short-circuit rules · `refs/refusal-patterns.md` — refusal shapes
- `../shared/refs/finding-schema.md`, `../shared/refs/report-schema.md`, `../shared/refs/verify-prelude.md`
- `.claude/scripts/pre-merge-tooling-detect.sh` — tooling fingerprint (Step 0/1)
- `.claude/scripts/pre-merge-aggregate-verdict.sh` — Step 5 per-bucket verdict aggregation/merge
- `scripts/resolve-diff.sh` — diff-vs-base structured summary
