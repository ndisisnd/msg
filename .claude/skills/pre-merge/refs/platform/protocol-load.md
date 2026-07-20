---
name: load
description: Pre-merge load component — throughput, latency percentiles, and error rate against configured thresholds. Runs isolated. Parse breaches to canonical findings.
---

# load component

Guard, error rule, envelope: `../_common.md`. **Runs isolated** (no overlap with other
components or `perf`). Runner (`load_runner`: k6 / Artillery / Locust / autocannon / wrk /
hey) from the fingerprint. Resolve `<script>`/`<config>` by searching `load/`,
`tests/load/`, `perf/`, root (in order).

## Thresholds

Priority: runner config (k6 `thresholds`, Artillery `config.ensure`) → `load-thresholds.json`
(root or `load/`) → defaults (p95 ≤ 500 ms, p99 ≤ 1000 ms, error rate ≤ 1%, throughput ≥ 1 req/s).
Emit the resolved thresholds.

## Parse

- All thresholds pass → `pass`.
- Any breach → one finding per breached threshold, `severity: high` (`medium` if marginal or a default threshold).
- Runner crash / connection refused → `pass_with_warnings`, note `"Load runner failed to start."`

Finding fields: `rule` = threshold name (`p95 latency`/`error_rate`); `file` = script/config
path; `line` = `null`; `message` = observed-vs-expected; `suggestion` = actionable.

Component fields: `runner`, `command`, `thresholds`, `totals` (requests, passed/failed_checks, p95_ms, p99_ms, error_rate_pct).
