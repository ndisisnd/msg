# test — Load bucket

**When it runs:** fifth bucket — after QA (sequential), or concurrently with other buckets (`--fast`).

**What it checks:** performance under load — throughput, latency percentiles, and error rate against configured thresholds.

## Execution

Reads `load_runner` from the Step 1 fingerprint — does not re-detect.

### Step 1 — Guard

If `load_runner` is `null`: emit `pass_with_warnings` with note `"No load testing runner detected — Load bucket skipped."` and return immediately.

Recognised runners (detection order):

| Runner | Detection signal | Default command |
|--------|-----------------|-----------------|
| k6 | `k6` in PATH or `k6` script in `package.json` | `k6 run <script>` |
| Artillery | `artillery.yml` / `artillery.json` or `artillery` in devDeps | `npx artillery run <config>` |
| Locust | `locustfile.py` present | `locust --headless -u 10 -r 2 --run-time 30s` |
| autocannon | `autocannon` in devDeps or scripts | `npx autocannon <url>` |
| wrk / hey | binary in PATH | `wrk -t4 -c100 -d30s <url>` / `hey -n 1000 <url>` |

Use the first match found. `<script>` / `<config>` resolved by searching `load/`, `tests/load/`, `perf/`, project root (in order).

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

## Output

```json
{
  "verdict": "pass" | "pass_with_warnings" | "fail",
  "bucket": "load",
  "runner": "<load_runner.name>",
  "command": "<command executed>",
  "thresholds": { "p95_ms": 500, "p99_ms": 1000, "error_rate_pct": 1 },
  "totals": {
    "requests": 0,
    "passed_checks": 0,
    "failed_checks": 0,
    "p95_ms": null,
    "p99_ms": null,
    "error_rate_pct": null
  },
  "findings": [
    {
      "id": "load-<n>",
      "severity": "fail" | "warn",
      "file": "<load script path or null>",
      "line": null,
      "rule": "<threshold name>",
      "message": "<observed vs expected>",
      "repro": "<re-run command or null>",
      "suggestion": "<actionable fix or null>"
    }
  ]
}
```

`fail` if any threshold is breached. `pass_with_warnings` if runner not found or crashed. `pass` if all thresholds are met.