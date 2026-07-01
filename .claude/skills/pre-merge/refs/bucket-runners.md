---
name: bucket-runners
description: One section per pre-merge bucket (integration, e2e, build, security, bundle) with detected-tool → command mapping. Used by Step 3 to build the check matrix and by Step 5 subagents to run checks.
---

# Bucket Runners

Five buckets. Each section defines: which detected tools activate the bucket, the command each subagent runs, how to parse output, and what constitutes a finding.

Subagents use `rtk` for all commands. File list placeholder `<files>` is replaced at runtime with the space-separated `files_changed` list filtered to files the tool can process.

**Package manager note:** Commands below use `npx` as a universal package manager prefix. When constructing the `repro` field for findings, subagents should substitute the detected package manager (from `detected.package_manager.run_prefix`) to ensure copy-paste-runnable commands. Example: if the project uses pnpm, emit `rtk pnpm vitest ...` rather than `rtk npx vitest ...`.

---

## integration

**Activates when**: `detected.test_runner` is non-null.

**Scope**: changed files and their co-located test files.

| Detected runner | Command |
|---|---|
| Vitest | `rtk npx vitest run --coverage <files>` |
| Jest | `rtk npx jest --coverage --testPathPattern=<files>` |
| Mocha | `rtk npx nyc npx mocha <files>` |
| pytest | `rtk pytest --cov=<files> --cov-report=json <files>` |
| Flutter | `rtk flutter test <files>` |
| CI override | `rtk <package_manager> run <ci_script>` |

**Artifact**: stdout/stderr → `.pre-merge/<timestamp>/integration.log`

**Parsing**:
- Exit zero with all tests passing → `verdict: "pass"`
- Exit non-zero → collect each failing test name, file, and line from the tool's output. Each failing test is one finding with `severity: "blocker"`.
- Exit zero with failing assertions reported inline (e.g. Jest `--passWithNoTests`) → `verdict: "pass"` (no finding).

**Coverage floor**: if `coverage_output` path exists after the run, check the overall coverage percentage. If below a threshold configured in `package.json` (look for `"coverageThreshold"` key under vitest/jest config), emit a `severity: "medium"` finding: `"Coverage dropped below configured threshold"`.

---

## e2e

**Activates when**: `detected.e2e_runner` is non-null.

**Scope**: full suite (e2e tests are not scoped to changed files — they test integration paths end to end).

| Detected runner | Command |
|---|---|
| Playwright | `rtk npx playwright test` |
| Cypress | `rtk npx cypress run` |
| Flutter integration | `rtk flutter test integration_test/` |
| CI override | `rtk <package_manager> run <ci_script>` |

**Artifact**: stdout/stderr → `.pre-merge/<timestamp>/e2e.log`

**Parsing**:
- Exit zero → `verdict: "pass"`
- Exit non-zero → collect each failing spec name, file path, and line from the runner's output. Each failing spec is one finding with `severity: "high"`.
- Flaky-test retries: if the runner reports a retry (Playwright `--retries` output), emit a `severity: "medium"` finding: `"Spec required retries — possible flake"`.

---

## build

**Activates when**: `detected.build_tool` is non-null.

**Scope**: full tree (builds are not incrementally scoped to changed files).

| Detected tool | Command |
|---|---|
| Next.js | `rtk npx next build` |
| Vite | `rtk npx vite build` |
| tsup | `rtk npx tsup` |
| Rollup | `rtk npx rollup -c` |
| Flutter | `rtk flutter build apk --debug` |
| TypeScript (no framework) | `rtk npx tsc --noEmit` |
| `package.json scripts.build` override | `rtk <package_manager> run build` |

**Artifact**: stdout/stderr → `.pre-merge/<timestamp>/build.log`

**Parsing**:
- Exit zero → `verdict: "pass"`
- Exit non-zero → find the first error line in output. Emit one finding per distinct `file:line` error reference, `severity: "blocker"`.
- Warnings (exit zero but warnings emitted): emit `severity: "low"` per warning type group; do not emit one finding per warning line.

**Mechanical checks first**: before running the build tool, run each entry in `detected.mechanical_runners[]` (lint, format, typecheck) in parallel:

```
for runner in detected.mechanical_runners:
  rtk <runner.command with <files>>
```

- If any mechanical runner exits non-zero and `severity_on_fail == "block"`: emit `severity: "blocker"` finding with tool name and first error line. Skip the build tool step — a type error or lint block already indicates a broken build.
- If `severity_on_fail == "warn"`: emit `severity: "medium"` finding, continue to build tool.

---

## security

**Activates when**: `detected.security_scanners[]` is non-empty.

**Scope**: diff-scoped for secret and SAST scans; full-tree for dependency and container scans.

Run all detected security scanners in parallel:

### Secret scanners (`type: "secret"`)

| Scanner | Command |
|---|---|
| gitleaks | `rtk gitleaks detect --no-git --source=<files> --no-banner --redact` |
| trufflehog | `rtk trufflehog filesystem --no-update --json <files>` |

Each hit → `severity: "blocker"`. Snippet must be redacted — show rule name only: `"gitleaks rule 'stripe-access-token' matched src/lib/stripe.ts:42 — value redacted"`.

### SAST scanners (`type: "sast"`)

| Scanner | Command |
|---|---|
| semgrep (auto config) | `rtk semgrep scan --config auto <files>` |
| semgrep (project config) | `rtk semgrep scan --config .semgrep.yml <files>` |

SAST findings: map `semgrep` severity levels — `ERROR` → `high`, `WARNING` → `medium`, `INFO` → `low`.

### Dependency scanners (`type: "dependency"`)

| Scanner | Command |
|---|---|
| pnpm audit | `rtk pnpm audit --json` |
| npm audit | `rtk npm audit --json` |
| yarn audit | `rtk yarn audit --json` |
| trivy fs | `rtk trivy fs --format json .` |
| snyk | `rtk snyk test --json` |

Map CVE CVSS: ≥ 9.0 → `high`, 7.0–8.9 → `medium`, < 7.0 → `low`. Apply dev-only downgrade rule from `refs/severity-rubric.md` for findings in `devDependencies`.

### Container scanners (`type: "container"`)

| Scanner | Command |
|---|---|
| trivy image | `rtk trivy image --format json <image>` |

Container findings: map trivy `CRITICAL` → `high`, `HIGH` → `high`, `MEDIUM` → `medium`, `LOW` → `low`.

**Artifact**: stdout/stderr per scanner → `.pre-merge/<timestamp>/security-<scanner>.log`

---

## bundle

**Activates when**: `detected.bundle_analyzer` is non-null.

**Scope**: full tree (bundle analysis requires a complete build).

| Detected analyzer | Command |
|---|---|
| @next/bundle-analyzer | `ANALYZE=true rtk npx next build` |
| source-map-explorer | `rtk npx source-map-explorer 'build/static/js/*.js'` |
| bundlesize | `rtk npx bundlesize` |
| vite-bundle-visualizer | `rtk npx vite-bundle-visualizer` |

**Baseline**: if `detected.bundle_analyzer.baseline_path` is non-null, compare current report against it. If null, emit a `severity: "low"` informational finding: `"No baseline available — first run; establishing baseline"` and write current report as the new baseline.

**Parsing**:
- Per-route size increase > 15% vs baseline → `severity: "high"`. Include culprit module if detectable.
- Per-route size increase 5–15% → `severity: "medium"`.
- Per-route size increase < 5% → `severity: "low"`.
- Total bundle decrease → no finding (improvement).
- `bundlesize` exit non-zero (size limit exceeded) → `severity: "high"`.

**Artifact**: stdout/stderr → `.pre-merge/<timestamp>/bundle.log`; current bundle report → `.pre-merge/<timestamp>/bundle-report.json`.

---

## Bucket omission log

When a bucket is omitted (no tooling detected), add an entry to `skipped[]`:

```json
{
  "bucket": "bundle",
  "reason": "no_tooling"
}
```

Do not attempt to run the bucket. Log the omission in the check matrix (Step 3) as a grayed row. See `refs/output-schema.md` for the `skipped[]` field definition.
