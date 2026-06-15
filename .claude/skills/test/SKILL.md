---
name: test
description: >
  Execution-focused test skill. Runs unit/integration, e2e, functional,
  visual (QA), load, accessibility, performance budget, API/contract,
  mobile (Flutter/Dart, Android + iOS), and coverage gate buckets via
  detected runners. Per-mode flags (--unit, --e2e, --functional, --qa,
  --load, --a11y, --perf, --api, --mobile, --coverage) target individual
  buckets; --fast runs all selected buckets in parallel. Accepts --eval-set
  to consume eval_set.json written by /review. Emits structured JSON
  findings compatible with the pre-merge finding schema.
model: claude-sonnet-4-6
allowed_tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
  - Agent
---

# test

Execution-focused test skill. Owns all test execution in the workflow — unit/integration runners, e2e runners, and functional assertion verification via live scripts.

```
/review  →  eval_set.json  →  /test --eval-set <path>   (targeted re-run of deferred assertions)
eng --build               →  /test                      (full test suite against a built change)
```

## Usage

- `/test` — detect and run all applicable test buckets against the current working tree
- `/test --base <branch>` — scope diff to changed files since `<branch>` (passed to test runners as file filters)
- `/test --prd <path>` — read PRD to bootstrap an eval_set for the functional bucket (if no `--eval-set` supplied)
- `/test --eval-set <path>` — consume `eval_set.json` written by `/review`; skip PRD re-bootstrap; run only the `executable` assertions from that file

**Mode flags** (mutually-inclusive; combine freely):

- `--unit` — run only the unit/integration bucket
- `--e2e` — run only the e2e bucket
- `--functional` — run only the functional bucket
- `--qa` — run only the visual/QA bucket
- `--load` — run only the load testing bucket
- `--a11y` — run only the accessibility audit bucket
- `--perf` — run only the performance budget bucket
- `--api` — run only the API / contract testing bucket
- `--mobile` — run only the mobile testing bucket (Flutter/Dart; Android + iOS)
- `--coverage` — run only the coverage gate bucket

When **no** mode flag is supplied, all applicable buckets run (existing default). When one or more mode flags are supplied, only the named buckets run; all others are skipped regardless of runner detection.

**Execution flags:**

- `--fast` — run all selected, non-skipped buckets **in parallel** rather than sequentially

Flags are composable: `/test --base main --eval-set features/prd-3/review/eval_set.json --unit --e2e --fast`

**Hard refusals:** does NOT modify source code; does NOT write outside `features/` and `/tmp/`; makes exactly ONE `AskUserQuestion` call (Step 3 gate).

## Inputs / Outputs

| | Name | Source / Destination |
|--|------|----------------------|
| In | Diff scope | `--base <branch>` or full working tree |
| In | eval_set | `--eval-set <path>` (JSON) or bootstrapped from `--prd <path>` |
| Out | Findings JSON | stdout always; `features/prd-[n]/test/test-<YYYYMMDD-HHmmss>.json` when PRD known |

Schema and verdict semantics: `refs/schema.md`.

## Protocol

### Step 1/5 — Detect tooling

Invoke the deterministic detector — do NOT walk priority tables by hand:

```bash
S=.claude/scripts/test-tooling-detect.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/test-tooling-detect.sh"; "$S"
```

The script emits a single JSON object to stdout with these keys, each either an object or `null`:

- **`package_manager`** — pnpm / yarn / npm / pub / poetry / pip.
- **`test_runner`** — unit/integration runner. Recognised: Vitest, Jest, Mocha, pytest, Dart/Flutter.
- **`e2e_runner`** — Playwright, Cypress, Flutter integration test.
- **`qa_runner`** — visual testing. Recognised: Playwright (visual snapshot mode), Chromatic, Percy, BackstopJS, Loki.
- **`load_runner`** — k6, Artillery, Locust, autocannon, wrk, hey.
- **`a11y_runner`** — axe-core (via `@axe-core/cli`, `axe-playwright`, `jest-axe`), Lighthouse (accessibility mode), pa11y.
- **`perf_runner`** — `{runtime, bundle}` sub-runners. Recognised: Lighthouse CI (`lhci`), Playwright + web-vitals, size-limit, bundlesize.
- **`api_runner`** — array of runners (Pact, Newman, Dredd, Hurl, Spectral, openapi-validator); multiple co-existing runners is normal (see `refs/modes/api.md`).
- **`mobile_runner`** — `flutter` or `fvm flutter` plus `patrol` / `maestro` / test-dir flags (see `refs/modes/mobile.md` for device matrix detection).
- **`coverage_runner`** — Flutter, Jest, NYC/Istanbul, pytest-cov, Go.

Then derive in this same step:

- **`eval_set`** — resolved assertion list (see Step 2).
- **CI workflow override** — after reading the fingerprint, scan `.github/workflows/*.yml` (and `.gitlab-ci.yml`) for `npm run test` / `npm run test:*` / `npm run e2e` / `npm run test:e2e`. If found, replace the matched runner's `command` and set `ci_override: true`. The script intentionally leaves this to you because CI script extraction is intent-matching, not file-existence.

Detection runs once; never re-derive mid-run. Treat the script's output as authoritative for file/$PATH/package.json signals — adding LLM second-guesses on top of it is what this script exists to prevent.

### Step 2/5 — Resolve eval_set

| Condition | Action |
|-----------|--------|
| `--eval-set <path>` supplied | Read `eval_set.json`; extract only `executable`-classed assertions. Skip PRD bootstrap. |
| `--prd <path>` supplied | Bootstrap eval_set from the named PRD using the same discovery protocol as `/review` Step 3. Classify all assertions; keep only `executable` for this step. |
| Neither flag | Attempt PRD auto-discovery (`features/prd-*/prd-*.md`, most recent first); if found, bootstrap as above. If no PRD, set `eval_set = []`. |

Emit: `Eval-set: <N> executable assertions.`

### Step 3/5 — Confirm and gate ← sole AskUserQuestion call

Show execution plan. Omit any bucket that is mode-flag-excluded, has a `null` runner, or has an empty `eval_set`. If `--fast` is set, append `[parallel]` to the header line.

```
Test execution plan  [parallel]        ← only shown with --fast
Unit/Integration  → <test_runner.command> (<N> changed files)
E2E               → <e2e_runner.command>
Functional        → <N> executable assertions via /tmp scripts
QA / Visual       → <qa_runner.command>
Load              → <load_runner.command>
Accessibility     → <a11y_runner.command>
Performance       → <perf_runner.command>
API / Contract    → <api_runner.commands>
Mobile            → <mobile_runner.command> [iOS: <n> device(s), Android: <n> device(s)]
Coverage          → <coverage_runner.command> (thresholds: lines ≥ <n>%, branches ≥ <n>%)
```

Options: **Proceed** / **Skip bucket(s)** (user names which to skip; continue without re-asking) / **Cancel** (exit, no findings).

No further `AskUserQuestion` calls.

### Step 4/5 — Run buckets in order (or in parallel with `--fast`)

**Skip a bucket if any of these are true:**
- A mode flag (`--unit`, `--e2e`, `--functional`, `--qa`, `--load`, `--a11y`, `--perf`, `--api`, `--mobile`, `--coverage`) was supplied and this bucket's flag was NOT included.
- The required runner / eval_set is absent (see table below).
- The user skipped it at the Step 3 gate.

| Order | Bucket | Mode flag | Mode ref | Additional skip condition |
|-------|--------|-----------|----------|---------------------------|
| 1 | Unit / Integration | `--unit` | `refs/modes/unit.md` | `test_runner` is `null` |
| 2 | E2E | `--e2e` | `refs/modes/e2e.md` | `e2e_runner` is `null` |
| 3 | Functional | `--functional` | `refs/modes/functional.md` | `eval_set` is empty |
| 4 | QA / Visual | `--qa` | `refs/modes/qa.md` | `qa_runner` is `null` |
| 5 | Load | `--load` | `refs/modes/load.md` | `load_runner` is `null` |
| 6 | Accessibility | `--a11y` | `refs/modes/a11y.md` | `a11y_runner` is `null` |
| 7 | Performance | `--perf` | `refs/modes/perf.md` | `perf_runner` is `null` |
| 8 | API / Contract | `--api` | `refs/modes/api.md` | `api_runner` is `null` |
| 9 | Mobile | `--mobile` | `refs/modes/mobile.md` | `mobile_runner` is `null` |
| 10 | Coverage | `--coverage` | `refs/modes/coverage.md` | `coverage_runner` is `null` |

**Sequential (default):** run in order 1→10; proceed to the next bucket even if a prior one fails or errors.

**Parallel (`--fast`):** start all selected, non-skipped buckets concurrently; collect all findings before aggregating. Do not wait for one to finish before starting the next.

**Bucket-level error rule:** a runner crash, missing binary, unreachable target, or auth failure within a bucket produces `pass_with_warnings` for that bucket — never `fail`. This prevents a broken CI environment from falsely blocking a merge. Each bucket's mode ref defines its specific error table; the top-level verdict aggregates across all completed buckets as normal.

### Step 5/5 — Aggregate and emit

Do NOT compute the overall verdict or hand-merge the bucket JSON. Throughout Step 4, each bucket's final JSON is written to `/tmp/test-<runid>/<bucket>.json` (recognised buckets: `unit`, `e2e`, `functional`, `qa`, `load`, `a11y`, `perf`, `api`, `mobile`, `coverage`). Skipped buckets are simply not written.

Then invoke the aggregator:

```bash
S=.claude/scripts/test-aggregate-verdict.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/test-aggregate-verdict.sh"
"$S" \
  --run-dir /tmp/test-<runid> \
  [--prd <path>] \
  [--eval-set <path>] \
  [--parallel]                # only when --fast was used
```

The script:
- validates each bucket file has a recognised `verdict` (`pass` | `pass_with_warnings` | `fail`) — refuses with exit 1 if any is missing or malformed
- computes the overall verdict as `fail > pass_with_warnings > pass` across present buckets
- merges every bucket payload under `.buckets` keyed by bucket name (skipped buckets omitted)
- emits the final JSON to stdout per `refs/schema.md`

Pipe stdout to `features/prd-<n>/test/test-<YYYYMMDD-HHmmss>.json` when a PRD is known (use `date +%Y%m%d-%H%M%S` for the timestamp — don't construct it by hand). Always print to stdout regardless.

If the script exits 1, the offending bucket wrote invalid JSON — fix that bucket's emission and re-run; do NOT fall back to hand-aggregation.

## References

- `.claude/scripts/test-tooling-detect.sh` — Step 1 fingerprint detector
- `.claude/scripts/test-aggregate-verdict.sh` — Step 5 verdict aggregator + JSON merger
- `refs/schema.md` — output JSON schema and verdict semantics
- `refs/modes/unit.md` — unit/integration runner invocation and output parsing
- `refs/modes/e2e.md` — e2e runner invocation and output parsing
- `refs/modes/functional.md` — executable assertion verification via ephemeral scripts
- `refs/modes/qa.md` — visual/QA runner invocation and diff reporting
- `refs/modes/load.md` — load test runner invocation and threshold reporting
- `refs/modes/a11y.md` — accessibility audit runner invocation and WCAG violation reporting
- `refs/modes/perf.md` — performance budget runner invocation and Web Vitals / bundle-size reporting
- `refs/modes/api.md` — API / contract testing runner invocation and contract/schema violation reporting
- `refs/modes/mobile.md` — Flutter/Dart mobile testing, Android + iOS device matrix, Patrol/Maestro
- `refs/modes/coverage.md` — coverage gate runner invocation, lcov parsing, threshold enforcement
- `refs/../../shared/refs/tooling-detection.md` — tooling fingerprint protocol
