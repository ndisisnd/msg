# test — Load bucket

**When it runs:** fifth bucket in `--sequential` order — after QA. Under the default parallel dispatch it is carved out of the concurrent batch and runs **isolated** as its own subagent — not overlapping other buckets or `perf` — so CPU/network contention can't skew its throughput/timing numbers.

**What it checks:** performance under load — throughput, latency percentiles, and error rate against configured thresholds.

## Execution

Guard, bucket-error rule, and output envelope: see `_common.md`. `load_runner` (name, command, e.g. k6 / Artillery / Locust / autocannon / wrk / hey) comes from the Step 1 fingerprint — this bucket does not re-detect.

### Step 1 — Guard

Per `_common.md`: if `load_runner` is `null`, emit `pass_with_warnings` with note `"No load testing runner detected — Load bucket skipped."` and return immediately.

`<script>` / `<config>` in the runner command is resolved by searching `load/`, `tests/load/`, `perf/`, project root (in order).

### Step 2 — Threshold resolution

Thresholds gate the verdict. Resolve in priority order:

1. Runner's own config (k6 `thresholds`, Artillery `config.ensure`, Locust `--stop-on-error`).
2. A `load-thresholds.json` file in project root or `load/` directory.
3. **Defaults** (used when neither of the above exists):
   - p95 latency ≤ 500 ms
   - p99 latency ≤ 1000 ms
   - error rate ≤ 1%
   - throughput ≥ 1 req/s

Emit the resolved thresholds in the output so the user can see what was applied.

### Step 3 — Run

Execute `load_runner.command`. Capture stdout, stderr, exit code, and any output artifacts (HTML reports, JSON summaries).

- **Exit 0, all thresholds passed** → verdict `pass`.
- **Exit 0 / non-zero, one or more thresholds breached** → verdict `fail`; create one finding per breached threshold.
- **Non-zero exit, runner crash / connection refused** → verdict `pass_with_warnings` with note `"Load runner failed to start — results unreliable."`.

### Step 4 — Parse results

For each threshold breach, extract:

- `file` — load script / config path
- `line` — `null` (load results are not line-addressable)
- `rule` — threshold name (e.g. `"p95 latency"`, `"error_rate"`)
- `message` — observed vs expected value (e.g. `"p95=812ms exceeds threshold of 500ms"`)
- `repro` — command to re-run the load test
- `suggestion` — actionable recommendation (e.g. `"Profile the slowest endpoint; check DB query plans"`)

Also record aggregate totals for the summary:

- `totals.requests` — total requests sent
- `totals.passed_checks` — number of threshold checks that passed
- `totals.failed_checks` — number of threshold checks that failed
- `totals.p95_ms` — measured p95 latency in ms
- `totals.p99_ms` — measured p99 latency in ms
- `totals.error_rate_pct` — error rate as a percentage

Findings conform to the canonical finding object (`../../../shared/refs/finding-schema.md`). `severity` is `high` for a breached threshold; `medium` if the breach is marginal or the threshold source is a default rather than project-configured. `evidence.tool` is the load runner name; `evidence.snippet` carries the observed-vs-expected line.

## Output

Envelope + finding shape per `_common.md`. Bucket fields:

```json
"runner": "<load_runner.name>", "command": "<command executed>",
"thresholds": { "p95_ms": 500, "p99_ms": 1000, "error_rate_pct": 1 },
"totals": { "requests": 0, "passed_checks": 0, "failed_checks": 0, "p95_ms": null, "p99_ms": null, "error_rate_pct": null }
```

Findings: category/source `load`; `rule` = threshold name, `evidence.snippet` = observed-vs-expected line.

`fail` if any threshold is breached. `pass_with_warnings` if runner not found or crashed. `pass` if all thresholds are met.