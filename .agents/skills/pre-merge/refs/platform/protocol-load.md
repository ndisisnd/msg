---
name: load
description: Pre-merge load component — diff-scoped throughput/latency/error-rate against configured thresholds, using the project's own runner profile. Runs only when the PR touches an endpoint/data path. Parse to canonical findings.
---

# load component

Guard, error rule, envelope: `../_common.md`. **Runs isolated** (no overlap with other
components or `perf`). Runner (`load_runner`: k6 / Artillery / Locust / autocannon / wrk /
hey) from the component's resolved tooling. Full-suite-per-PR is too slow to gate — so `load` is made
**structurally gate-able** by scoping it to the diff (below), which is *why* it can gate
instead of staying advisory-and-never-run.

## Diff-scoped gating (C16/rec 1 — when it runs)

`load` **runs and gates only when the PR touches an endpoint handler or a shared
data-access path**, scoped to the **affected endpoints**; a PR that touches neither
**skips `load` entirely**. Reuse the **executor's `resolve-diff` surface** (shared with coverage C10 / migration C17 / api C15) to map changed files → touched
endpoints/handlers/data-access paths:

- diff touches an endpoint handler or shared data-access path → run load **against those
  endpoints** (e.g. a PR adding an unindexed `GET /todos?sort=priority` runs load on the
  todos endpoints).
- diff touches neither (README-only, config-only) → **skip** load, note
  `"no endpoint/data-path change — load not scoped"`.

Diff-scoping governs **when** load runs, **not whether configured thresholds block**
 — same judge-the-diff shape as C10, but the motive is **affordability**, not
fairness.

## Traffic profile — declared mix, or the runner's own

The load profile comes from the project's **own runner config** (k6 `scenarios`,
Artillery `phases`, Locust user classes) — that is where a realistic read/write mix,
concurrency, and think-time belong, and it is the only place they can be maintained.
When the `load` component carries a declared `traffic_mix` hint, use it; when it does
not, **run the runner's configured profile as written** and note
`traffic_mix: "runner-default"`. Pre-merge never synthesizes a mix it cannot source.

## Thresholds (the hard bar — config-driven criticality unchanged)

Priority: runner config (k6 `thresholds`, Artillery `config.ensure`) → `load-thresholds.json` (root or `load/`) → defaults (p95 ≤ 500 ms, p99 ≤ 1000 ms, error rate ≤ 1%, throughput ≥ 1 req/s).
Emit the resolved thresholds. **Configured absolute thresholds remain the hard blocking bar** (the catalog `†` config-driven criticality is unchanged); diff-scoping only
changes *when* the component runs.

## Parse — bottleneck-named findings (C16/rec 3)

- Skipped (no endpoint/data-path change) → not run, note as above.
- All thresholds pass → `pass`.
- Any breach → one finding per breached threshold, `severity: high` (`medium` if marginal
  or a default threshold).
- Runner crash / connection refused → `pass_with_warnings`, note `"Load runner failed to start."`

A threshold breach **names the bottleneck** when the run produced a per-operation
trace — slowest endpoint, the query/span, the error cluster — plus a suggestion, per
`../../../shared/refs/attribute-the-cause.md`: *"p99 8.2s on `GET /todos` — N+1 on
`todo.tags`, 340 queries/request under load — add an index / batch the tag load."*
**No trace available → report the breached metric + the scoped endpoint and stop** —
never a fabricated cause.

Finding fields: `rule` = threshold name (`p95 latency`/`error_rate`); `file` = script/config
path; `line` = `null`; `message` = the bottleneck + observed-vs-expected; `evidence.endpoint`
+ `evidence.slowest_op` = the attributed bottleneck; `suggestion` = actionable fix.

Component fields: `runner`, `command`, `scoped_endpoints[]`, `thresholds`,
`traffic_mix` (declared, or `runner-default`), `totals` (requests, passed/failed_checks, p95_ms, p99_ms, error_rate_pct).
