# test — Performance budget bucket

**When it runs:** seventh bucket in `--sequential` order — after Accessibility. Under the default parallel dispatch it is carved out of the concurrent batch and runs **isolated** as its own subagent — not overlapping other buckets or `load` — so CPU/network contention can't skew its Web Vitals / timing numbers.

**What it checks:** two orthogonal performance concerns:
1. **Runtime perf** — Core Web Vitals and Lighthouse scores against configured thresholds.
2. **Bundle size** — JS/CSS bundle weights against configured size budgets.

Both sub-checks run if their respective runner is detected. Either sub-check alone is sufficient for the bucket to run.

## Execution

Reads `perf_runner` from the Step 1 fingerprint — does not re-detect.

### Step 1 — Guard

If `perf_runner` is `null`: emit `pass_with_warnings` with note `"No performance budget runner detected — perf bucket skipped."` and return immediately.

Recognised runners (detection order):

| Sub-check | Runner | Detection signal | Default command |
|-----------|--------|-----------------|-----------------|
| Runtime | Lighthouse CI | `.lighthouserc.*` / `lighthouserc.js` / `lhci` in scripts or devDeps | `npx lhci autorun` |
| Runtime | Playwright + web-vitals | `web-vitals` in deps + Playwright config | run via existing Playwright config with vitals collection |
| Bundle | size-limit | `size-limit` in `package.json` (field or devDep) | `npx size-limit --json` |
| Bundle | bundlesize | `bundlesize` in `package.json` (field or devDep) | `npx bundlesize` |

Multiple runners may be active simultaneously (e.g. `lhci` for runtime + `size-limit` for bundle). Run all detected.

### Step 2 — Resolve budgets / thresholds

**Runtime thresholds** — resolve in priority order:
1. `lhci` config (`assert.assertions` block or `budgets` array in `.lighthouserc.*`).
2. **Defaults:**

| Metric | Budget |
|--------|--------|
| Performance score | ≥ 80 |
| LCP (Largest Contentful Paint) | ≤ 2500 ms |
| CLS (Cumulative Layout Shift) | ≤ 0.1 |
| FID / INP (Interaction to Next Paint) | ≤ 200 ms |
| FCP (First Contentful Paint) | ≤ 1800 ms |
| TTI (Time to Interactive) | ≤ 3800 ms |

**Bundle thresholds** — always read from the runner's own config (`size-limit` field in `package.json` or `bundlesize.files`). If no config is present and a bundle runner is detected, emit `pass_with_warnings` with note `"Bundle runner detected but no size budgets configured."` for that sub-check; do not invent thresholds.

Emit: `Perf budgets: <N> runtime thresholds, <M> bundle entries.`

### Step 3 — Run

Execute each detected runner's command. Capture stdout, stderr, exit code, and report artifacts (HTML report, JSON summary).

For Lighthouse CI:
- **All assertions pass** → `pass`.
- **One or more assertions fail** → `fail`; parse each failed assertion into a finding.
- **Runner crash / auth / start failure** → `pass_with_warnings`.

For size-limit / bundlesize:
- **All entries within budget** → `pass`.
- **One or more entries exceed budget** → `fail`; parse each over-budget entry into a finding.
- **Runner crash / build artifact missing** → `pass_with_warnings` with note `"Bundle runner could not locate build output — run a production build first."`.

### Step 4 — Parse failures

**Runtime finding fields:**

- `file` — page URL audited
- `line` — `null`
- `rule` — metric name (e.g. `"LCP"`, `"CLS"`, `"performance-score"`)
- `message` — observed vs budget (e.g. `"LCP=3200ms exceeds budget of 2500ms"`)
- `repro` — `npx lhci autorun` or equivalent command
- `suggestion` — actionable recommendation keyed to the metric (see table below)
- `evidence` — path to Lighthouse HTML report, or `null`

Metric-specific suggestions:

| Metric | Default suggestion |
|--------|--------------------|
| LCP | Check largest image/text render; add preload hints; verify CDN cache headers |
| CLS | Set explicit width/height on images and embeds; avoid inserting DOM above the fold |
| FID / INP | Reduce long tasks; defer non-critical JS; use web workers for heavy computation |
| FCP | Eliminate render-blocking resources; inline critical CSS |
| TTI | Reduce JS parse time; code-split routes |
| Performance score | Run Lighthouse locally for full opportunity list |

**Bundle finding fields:**

- `file` — bundle entry name (e.g. `"dist/main.js"`)
- `line` — `null`
- `rule` — `"bundle-size"`
- `message` — observed vs budget (e.g. `"dist/main.js=312kB exceeds budget of 250kB (gzip)"`)
- `repro` — `npx size-limit` or `npx bundlesize`
- `suggestion` — `"Analyse with source-map-explorer or webpack-bundle-analyzer to find oversized dependencies"`

Findings conform to the canonical finding object (`../../../shared/refs/finding-schema.md`). `severity` is `high` for a budget breach (runtime metric or bundle entry); `medium` if the breach is marginal or thresholds fell back to defaults rather than project config. `evidence.tool` is the runtime or bundle runner name; `evidence.file` carries the Lighthouse HTML report path (runtime) or is `null` (bundle, which has no per-entry artifact); `evidence.snippet` carries the observed-vs-budget line.

## Error handling

A bucket-level error never stops other buckets. All errors produce `pass_with_warnings` (not `fail`) so a broken runner does not falsely block a merge.

| Error condition | Verdict | Note in output |
|----------------|---------|----------------|
| Runner binary not found / not installed | `pass_with_warnings` | `"<runner> not found — install it or add it to devDependencies."` |
| Runner crashes on startup (no report produced) | `pass_with_warnings` | `"Perf runner failed to start — results unreliable."` Include stderr excerpt (max 5 lines). |
| Build artifact missing (bundle check) | `pass_with_warnings` | `"Bundle runner could not locate build output — run a production build first."` |
| LHCI / Lighthouse token / auth failure | `pass_with_warnings` | `"Lighthouse CI authentication failed — check LHCI_BUILD_CONTEXT__GITHUB_TOKEN or server URL."` |
| Target URL unreachable (runtime check) | Skip that URL; continue; `pass_with_warnings` if ALL targets fail | `"Could not reach <url> — skipped."` |
| Network timeout (runner hangs > 180 s per URL) | Kill runner for that URL; continue | `"Timed out auditing <url> after 180 s — skipped."` |
| Config parse error | `pass_with_warnings` | `"Could not parse perf config at <path>: <error>."` Fall back to default thresholds for runtime; skip bundle check if bundle config unreadable. |
| No bundle budgets configured (bundle runner present) | `pass_with_warnings` | `"Bundle runner detected but no size budgets configured."` Do not invent thresholds. |
| Runtime runner and bundle runner both error | `pass_with_warnings` | `"All perf sub-checks failed — no findings."` |

**Partial results rule:** if either sub-check (runtime or bundle) completes successfully, emit its findings and base the verdict on those. The other sub-check's failure is recorded in `"errors"` but does not override a clean sub-check's `pass`. If one sub-check passes and the other errors, overall verdict = `pass_with_warnings`.

## Output

```json
{
  "verdict": "pass" | "pass_with_warnings" | "fail",
  "bucket": "perf",
  "runners": ["<runtime_runner>", "<bundle_runner>"],
  "errors": [
    { "sub_check": "runtime" | "bundle", "target": "<url or entry>", "reason": "<error description>" }
  ],
  "thresholds": {
    "runtime": { "lcp_ms": 2500, "cls": 0.1, "fid_ms": 200, "fcp_ms": 1800, "tti_ms": 3800, "score": 80 },
    "bundle": "<from runner config>"
  },
  "totals": {
    "runtime_checks": { "passed": 0, "failed": 0 },
    "bundle_checks":  { "passed": 0, "failed": 0 }
  },
  "findings": [
    {
      "id": "perf-<n>",
      "source": "perf",
      "severity": "high" | "medium",
      "category": "perf",
      "file": "<page URL or bundle entry>",
      "line": null,
      "rule": "<metric or bundle-size>",
      "message": "<observed vs budget>",
      "evidence": {
        "tool": "<runtime or bundle runner name>",
        "file": "<Lighthouse HTML report path or null>",
        "line": null,
        "snippet": "<observed vs budget line>"
      },
      "suggestion": "<actionable fix or null>",
      "repro": "<runner command>",
      "regression_of": null
    }
  ]
}
```

`fail` if any runtime metric or bundle entry breaches its budget. `pass_with_warnings` if runner not found, build artifact missing, or no bundle budgets configured. `pass` if all checks are within budget.
