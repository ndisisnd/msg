---
name: tooling-detection
description: Shared tooling fingerprint protocol. Produces package manager, test runner, e2e runner, build tool, mechanical runner, security scanner, and bundle analyzer objects from project signals. Used by /review (Step 2 fingerprint) and /pre-merge (Step 2 detect tooling).
---

# Tooling Detection

Shared fingerprint protocol. Run all checks in parallel. Populate outputs once per skill invocation; never re-derive mid-run.

---

## Output shapes

All outputs are in-memory objects populated during the fingerprint step and referenced by downstream buckets/modes.

**`package_manager`**
```json
{
  "name": "bun | pnpm | npm | yarn | pub | pip | poetry",
  "run_prefix": "bun | pnpm | npm | yarn | flutter pub | pip | poetry run"
}
```

**`test_runner`**
```json
{
  "name": "<runner name>",
  "command": "<full scoped command — <files> replaced at runtime with space-separated changed file paths>",
  "coverage_output": "<relative path to coverage JSON, or null>",
  "ci_override": true | false
}
```

**`e2e_runner`**
```json
{
  "name": "<runner name>",
  "command": "<base command — appended with spec path or tag at runtime>",
  "config_path": "<detected config file path, or null>"
}
```

**`build_tool`**
```json
{
  "name": "<tool name>",
  "command": "<build command>",
  "output_dir": "<expected output directory, or null>"
}
```

**`mechanical_runners[]`** — one entry per detected runner
```json
{
  "name": "<runner name>",
  "command": "<command with <files> placeholder>",
  "expects_zero_exit": true,
  "severity_on_fail": "warn" | "block"
}
```

`<files>` is replaced at runtime with the space-separated diff file list filtered to files the runner can process (e.g. `.ts`/`.tsx` for `eslint`).

**`security_scanners[]`** — ordered list; `secret_scanner` alias = first entry with `type: "secret"`
```json
{
  "name": "<scanner name>",
  "type": "secret" | "sast" | "dependency" | "container",
  "command_diff": "<command for diff-scoped scan, <files> placeholder>",
  "command_full": "<command for full-tree scan>",
  "severity_on_hit": "block"
}
```

**`bundle_analyzer`**
```json
{
  "name": "<analyzer name>",
  "command": "<command to produce bundle report>",
  "baseline_path": "<path to baseline artifact, or null>"
}
```

---

## Package manager detection

Use the **first match** (priority order):

| Priority | Signal | Package manager | Run prefix |
|----------|--------|----------------|------------|
| 1 | `bun.lockb` found (maxdepth 2) | bun | `bun` |
| 2 | `pnpm-lock.yaml` found (maxdepth 2) | pnpm | `pnpm` |
| 3 | `yarn.lock` found (maxdepth 2) | yarn | `yarn` |
| 4 | `package-lock.json` found (maxdepth 2) | npm | `npm` |
| 5 | `pubspec.yaml` found (maxdepth 2) | pub | `flutter pub` |
| 6 | `pyproject.toml` with `[tool.poetry]`, or `poetry.lock` found | poetry | `poetry run` |
| 7 | `requirements*.txt` found | pip | `pip` |

If no signal matches, `package_manager` is `null`.

---

## Test runner detection

Run checks in the order listed; use the **first match**. Populate `test_runner`.

| Priority | Signal | Runner | Scoped command | Coverage output path |
|----------|--------|--------|---------------|----------------------|
| 1 | `vitest` in `devDependencies` or `vitest.config.*` found (maxdepth 3) | Vitest | `npx vitest run --coverage <files>` | `coverage/coverage-summary.json` |
| 2 | `jest` in `devDependencies` or `jest.config.*` found (maxdepth 3) | Jest | `npx jest --coverage --testPathPattern=<files>` | `coverage/coverage-summary.json` |
| 3 | `mocha` in `devDependencies` or `.mocharc.*` found (maxdepth 3) | Mocha | `npx nyc npx mocha <files>` | `.nyc_output/coverage-summary.json` |
| 4 | `pytest` in `requirements*.txt` or `pyproject.toml` has `[tool.pytest]` | pytest | `pytest --cov=<files> --cov-report=json` | `coverage.json` |
| 5 | `pubspec.yaml` found (maxdepth 2) | Dart/Flutter | `flutter test <file>` | stdout parse |
| 6 | `bun.lockb` found (maxdepth 2) | Bun test | `bun test <files>` | `null` |
| 7 | `deno.json` or `deno.jsonc` found (maxdepth 2) | Deno test | `deno test <files>` | `null` |
| 8 | `package.json` `scripts.test` contains `node --test` | Node built-in | `node --test <files>` | `null` |

**CI workflow override** — after the table match, check `.github/workflows/*.yml` (and `.gitlab-ci.yml` if present) for lines containing `npm run test` or `npm run test:*`. If found, extract the script name (e.g. `test:unit`) and substitute it as the command: `npm run test:unit -- --coverage`. CI commands take precedence over the table command for the matched runner.

If no signal matches, `test_runner` is `null`.

---

## E2E runner detection

Run checks in priority order; use the **first match**. Populate `e2e_runner`.

| Priority | Signal | Runner | Base command | Config path |
|----------|--------|--------|-------------|-------------|
| 1 | `playwright.config.*` found (maxdepth 3) or `@playwright/test` in `devDependencies` | Playwright | `npx playwright test` | detected config path |
| 2 | `cypress.config.*` found (maxdepth 3) or `cypress` in `devDependencies` | Cypress | `npx cypress run` | detected config path |
| 3 | `pubspec.yaml` found (maxdepth 2) and `integration_test/` dir exists | Flutter integration test | `flutter test integration_test/` | `null` |

**CI workflow override** — check `.github/workflows/*.yml` for lines containing `npm run e2e` or `npm run test:e2e`; if found, extract the script and use it as the command.

If no signal matches, `e2e_runner` is `null`.

---

## Build tool detection

Run checks in priority order; use the **first match**. Populate `build_tool`.

| Priority | Signal | Tool | Command | Output dir |
|----------|--------|------|---------|------------|
| 1 | `next` in `dependencies` | Next.js | `next build` | `.next/` |
| 2 | `astro.config.*` found (maxdepth 3) or `astro` in `dependencies` | Astro | `astro build` | `dist/` |
| 3 | `svelte.config.*` found (maxdepth 3) or `@sveltejs/kit` in `dependencies` | SvelteKit | `vite build` | `build/` |
| 4 | `vite.config.*` found (maxdepth 3) or `vite` in `devDependencies` | Vite | `vite build` | `dist/` |
| 5 | `tsup.config.*` found (maxdepth 3) or `tsup` in `devDependencies` | tsup | `tsup` | `dist/` |
| 6 | `esbuild` in `devDependencies` | esbuild | `<run_prefix> run build` | `dist/` |
| 7 | `rollup.config.*` found (maxdepth 3) or `rollup` in `devDependencies` | Rollup | `rollup -c` | `dist/` |
| 8 | `webpack.config.*` found (maxdepth 3) or `webpack` in `devDependencies` | Webpack | `npx webpack` | `dist/` |
| 9 | `pubspec.yaml` found (maxdepth 2) | Flutter | `flutter build apk --debug` | `build/` |
| 10 | `tsconfig.json` found with no framework match | TypeScript | `tsc --noEmit` | `null` |

**`build` script override** — check `package.json` `scripts.build`; if present, use `<run_prefix> run build` as the command regardless of detected tool (CI parity).

If no signal matches, `build_tool` is `null`.

---

## Mechanical runner detection

Run checks in parallel across all sub-tables. Populate `mechanical_runners[]` with one entry per detected runner.

A runner is **configured** if its config signal is present but **not executable** if the command would fail with `command not found` or `cannot find module`. Callers (e.g. Quality mode Stage 0) treat configured-but-not-executable as a `block` with source prefix `env:`.

### JS/TS runners

Biome subsumes both lint and format — if Biome is detected alongside eslint or prettier, all entries appear in `mechanical_runners[]` but downstream consumers should treat Biome as the authoritative runner for files it covers.

| Signal | Runner | Command | Severity on fail |
|--------|--------|---------|------------------|
| `biome.json` found (maxdepth 3) or `@biomejs/biome` in `devDependencies` | biome | `npx @biomejs/biome check <files>` | `warn` |
| `eslint.config.*` or `.eslintrc.*` found (maxdepth 3) | eslint | `npx eslint <files>` | `warn` |
| `.prettierrc*` or `prettier.config.*` found (maxdepth 3), or `prettier` in `devDependencies` | prettier | `npx prettier --check <files>` | `warn` |
| `oxlint` in `devDependencies` or `.oxlintrc.json` found (maxdepth 3) | oxlint | `npx oxlint <files>` | `warn` |
| `.stylelintrc*` or `stylelint.config.*` found (maxdepth 3) or `stylelint` in `devDependencies` | stylelint | `npx stylelint <files>` | `warn` |
| `tsconfig.json` found (maxdepth 3) | tsc | `npx tsc --noEmit` | `block` |

### Python runners

| Signal | Runner | Command | Severity on fail |
|--------|--------|---------|------------------|
| `pyproject.toml` has `[tool.ruff]`, or `ruff.toml` found, or `.ruff.toml` found | ruff | `ruff check <files>` | `warn` |
| `pyproject.toml` has `[tool.black]`, or `black` in `requirements*.txt` | black | `black --check <files>` | `warn` |
| `.flake8` found (maxdepth 2), or `setup.cfg` with `[flake8]`, or `flake8` in `requirements*.txt` | flake8 | `flake8 <files>` | `warn` |
| `.pylintrc` or `pylintrc` found (maxdepth 2), or `pylint` in `requirements*.txt` | pylint | `pylint <files>` | `warn` |
| `pyproject.toml` has `[tool.mypy]`, or `mypy.ini` found, or `mypy` in `requirements*.txt` | mypy | `mypy <files>` | `block` |

### Dart/Flutter runners

| Signal | Runner | Command | Severity on fail |
|--------|--------|---------|------------------|
| `pubspec.yaml` found (maxdepth 2) and `analysis_options.yaml` present | dart analyze | `dart analyze <files>` | `block` |
| `pubspec.yaml` found (maxdepth 2) | dart format | `dart format --output=none --set-exit-if-changed <files>` | `warn` |

`dart analyze` is treated as a typecheck-equivalent (`block`) — Dart's static analyzer subsumes the type-checking that `tsc`/`mypy` cover in other ecosystems.

---

## Security scanner detection

Populate `security_scanners[]` in the priority order below. Each detected scanner appends one entry. The `secret_scanner` alias used by `/review` Security mode Stage 0 = first entry with `type: "secret"`, or `null` if none found.

Any finding from a security scanner has `severity_on_hit: "block"`.

### Secret scanners (type: "secret")

Probe in priority order:

| Priority | Signal | Scanner | Command (diff) | Command (full tree) |
|----------|--------|---------|----------------|---------------------|
| 1 | `gitleaks` on `$PATH` (`command -v gitleaks`) | gitleaks | `gitleaks detect --no-git --source=<files>` | `gitleaks detect` |
| 2 | `trufflehog` on `$PATH` (`command -v trufflehog`) | trufflehog | `trufflehog filesystem --no-update --json <files>` | `trufflehog filesystem --no-update --json .` |

### SAST scanners (type: "sast")

| Signal | Scanner | Command (diff) | Command (full tree) |
|--------|---------|----------------|---------------------|
| `semgrep` on `$PATH` | semgrep | `semgrep scan --config auto <files>` | `semgrep scan --config auto .` |
| `.semgrep.yml` found (maxdepth 2) | semgrep (project config) | `semgrep scan --config .semgrep.yml <files>` | `semgrep scan --config .semgrep.yml .` |

`.semgrep.yml` takes precedence over `--config auto` if both signals are present — merge into one entry using the project config command.

### Dependency scanners (type: "dependency")

| Signal | Scanner | Command |
|--------|---------|---------|
| `package_manager.name` is `pnpm` | pnpm audit | `pnpm audit --json` |
| `package_manager.name` is `npm` | npm audit | `npm audit --json` |
| `package_manager.name` is `yarn` | yarn audit | `yarn audit --json` |
| `pip-audit` on `$PATH` and `requirements*.txt` or `pyproject.toml` found | pip-audit | `pip-audit --format=json` |
| `osv-scanner` on `$PATH` | osv-scanner | `osv-scanner --recursive --format json .` |
| `trivy` on `$PATH` | trivy fs | `trivy fs --format json .` |
| `snyk` on `$PATH` | snyk | `snyk test --json` |

### Container scanners (type: "container")

| Signal | Scanner | Command |
|--------|---------|---------|
| `Dockerfile` or `docker-compose*.yml` found (maxdepth 2), and `trivy` on `$PATH` | trivy image | `trivy image --format json <image>` |

If no secret scanner signal is found, callers that require one (e.g. `/review` Security mode Stage 0) emit a `warn` finding rather than blocking.

---

## Bundle analyzer detection

Use the **first match**. Populate `bundle_analyzer`.

| Priority | Signal | Analyzer | Command | Baseline path |
|----------|--------|----------|---------|---------------|
| 1 | `@next/bundle-analyzer` in `devDependencies` or `ANALYZE=true` accepted by `next.config.*` | @next/bundle-analyzer | `ANALYZE=true next build` | `.next/analyze/` |
| 2 | `webpack-bundle-analyzer` in `devDependencies` | webpack-bundle-analyzer | `webpack --json stats.json && webpack-bundle-analyzer stats.json --mode static --no-open` | `null` |
| 3 | `rollup-plugin-visualizer` in `devDependencies` | rollup-plugin-visualizer | `<build_tool.command>` (produces `stats.html` via plugin) | `stats.html` |
| 4 | `source-map-explorer` in `devDependencies` | source-map-explorer | `source-map-explorer 'build/static/js/*.js'` | `null` |
| 5 | `size-limit` in `devDependencies` or `.size-limit.json` found (maxdepth 2) or `size-limit` key in `package.json` | size-limit | `npx size-limit` | `.size-limit.json` |
| 6 | `bundlesize` in `devDependencies` or `.bundlesizerc` found (maxdepth 2) | bundlesize | `bundlesize` | `.bundlesizerc` |
| 7 | `vite-bundle-visualizer` in `devDependencies` | vite-bundle-visualizer | `vite-bundle-visualizer` | `null` |

**Baseline** — check `.pre-merge/` for prior run artifacts; if a matching report exists, set `baseline_path` to the most recent one. If no baseline exists, `baseline_path` is `null` and size-delta comparisons are skipped on the first run.

If no signal matches, `bundle_analyzer` is `null`.
