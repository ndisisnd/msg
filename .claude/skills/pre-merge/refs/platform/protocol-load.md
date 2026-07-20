---
name: load
description: Pre-merge load component — diff-scoped throughput/latency/error-rate against configured thresholds, under a realistic declared read/write traffic mix. Runs only when the PR touches an endpoint/data path. Breaches name the bottleneck. Parse to canonical findings.
---

# load component

Guard, error rule, envelope: `../_common.md`. **Runs isolated** (no overlap with other
components or `perf`). Runner (`load_runner`: k6 / Artillery / Locust / autocannon / wrk /
hey) from the fingerprint. Full-suite-per-PR is too slow to gate — so `load` is made
**structurally gate-able** by scoping it to the diff (below), which is *why* it can gate
instead of staying advisory-and-never-run.

## Diff-scoped gating (C16/rec 1 — when it runs)

`load` **runs and gates only when the PR touches an endpoint handler or a shared
data-access path**, scoped to the **affected endpoints**; a PR that touches neither
**skips `load` entirely** (AC-LOAD1). Reuse the **executor's `resolve-diff` surface**
(shared with coverage C10 / migration C17 / api C15) to map changed files → touched
endpoints/handlers/data-access paths:

- diff touches an endpoint handler or shared data-access path → run load **against those
  endpoints** (e.g. a PR adding an unindexed `GET /todos?sort=priority` runs load on the
  todos endpoints).
- diff touches neither (README-only, config-only) → **skip** load, note
  `"no endpoint/data-path change — load not scoped"`.

Diff-scoping governs **when** load runs, **not whether configured thresholds block**
(AC-LOAD4) — same judge-the-diff shape as C10, but the motive is **affordability**, not
fairness.

## Realistic traffic mix (C16/rec 2 — how it runs)

The load profile reflects a **declared traffic mix** — **read/write ratio, concurrency,
think-time** — and **exercises the write path**, so read/write contention (lock waits,
full-table scans under concurrent writes) surfaces, not single-endpoint flat-RPS
hammering (AC-LOAD2). The mix needs project input, so it is an **`--init` question**
("read/write mix?") recorded in the manifest with a **sane default** (e.g. 80/20 read/write,
moderate concurrency, short think-time) — **not** a synthesized requirement
(`../protocol-init.md`).

## Thresholds (the hard bar — config-driven criticality unchanged)

Priority: runner config (k6 `thresholds`, Artillery `config.ensure`) → `load-thresholds.json`
(root or `load/`) → defaults (p95 ≤ 500 ms, p99 ≤ 1000 ms, error rate ≤ 1%, throughput ≥ 1 req/s).
Emit the resolved thresholds. **Configured absolute thresholds remain the hard blocking bar**
(the catalog `†` config-driven criticality is unchanged — AC-LOAD4); diff-scoping only
changes *when* the component runs.

## Parse — bottleneck-named findings (C16/rec 3)

- Skipped (no endpoint/data-path change) → not run, note as above.
- All thresholds pass → `pass`.
- Any breach → one finding per breached threshold, `severity: high` (`medium` if marginal
  or a default threshold).
- Runner crash / connection refused → `pass_with_warnings`, note `"Load runner failed to start."`

A threshold breach **names the bottleneck** — slowest endpoint, the query/span, the error
cluster — **+ a suggestion**, not just `"p95 1200ms > 500ms"`, per
`../../../shared/refs/attribute-the-cause.md` (AC-LOAD3): *"p99 8.2s on `GET /todos` — N+1
on `todo.tags`, 340 queries/request under load — add an index / batch the tag load."* When
no per-operation trace is available, degrade to the breached metric + the scoped endpoint,
never a fabricated cause.

Finding fields: `rule` = threshold name (`p95 latency`/`error_rate`); `file` = script/config
path; `line` = `null`; `message` = the bottleneck + observed-vs-expected; `evidence.endpoint`
+ `evidence.slowest_op` = the attributed bottleneck; `suggestion` = actionable fix.

Component fields: `runner`, `command`, `scoped_endpoints[]`, `traffic_mix`, `thresholds`,
`totals` (requests, passed/failed_checks, p95_ms, p99_ms, error_rate_pct).
