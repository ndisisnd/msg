---
name: test
description: >
  Execution-focused test skill. Runs unit/integration, e2e, functional,
  visual (QA), load, accessibility, performance budget, API/contract,
  mobile (Flutter/Dart, Android + iOS), and coverage gate buckets via
  detected runners. Per-mode flags (--unit, --e2e, --functional, --qa,
  --load, --a11y, --perf, --api, --mobile, --coverage) target individual
  buckets; selected buckets run in parallel as subagents by default
  (--sequential forces the old in-order 1→10 run). --init profiles
  the codebase to recommend which test buckets, tools, and packages it
  needs, then writes a test.json cache the execution path reads. Accepts
  --eval-set to consume eval_set.json written by /review. --flaky <N>
  retries failing unit/e2e tests before counting them as real failures;
  --changed-only (with --base) skips buckets whose surface the diff
  doesn't touch. Emits structured JSON findings conforming to the shared
  canonical finding schema (.claude/skills/shared/refs/finding-schema.md),
  the same shape /review and /pre-merge emit.
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

- `/test --init` — **setup mode** (does not run tests). Profile the codebase, recommend which test buckets, third-party tools, and packages it needs, optionally install them, and write `.claude/test/test.json`. See **Init mode** below and `refs/modes/init.md`.
- `/test` — detect and run all applicable test buckets against the current working tree
- `/test --base <branch>` — scope diff to changed files since `<branch>` (passed to test runners as file filters)
- `/test --base <branch> --changed-only` — additionally skip whole buckets whose surface the diff doesn't touch (e.g. no UI files changed → skip `qa`/`a11y`/`perf`/`e2e`/`mobile`). Requires `--base`; ignored (with a printed note) if `--base` is absent. See Step 1b.
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

- `--sequential` — opt out of the default parallel dispatch and run selected, non-skipped buckets **in order 1→10** in-process, continuing past a failing bucket (the pre-parallel behavior, useful for debugging one bucket at a time). Parallel subagent dispatch is the default; this flag is the only way back to sequential.
- `--flaky <N>` — retry each failing unit/e2e test up to `N` times before counting it as a real failure; a test that passes on any retry is reclassified as flaky rather than a hard failure. No effect on other buckets. See `refs/modes/unit.md` Step 3b / `refs/modes/e2e.md` Step 3b.

> **Removed:** `--fast` no longer exists — parallel execution is now the unconditional default, so there is nothing for it to toggle. If passed, it is ignored with a printed note (`--fast is removed — parallel is the default; use --sequential for in-order runs`); it is not a hard error.

Flags are composable: `/test --base main --eval-set features/prd-3/review/eval_set.json --unit --e2e --sequential --flaky 2`

**Hard refusals (execution path):** does NOT modify source code; does NOT write outside `features/` and `/tmp/`; makes exactly ONE `AskUserQuestion` call (Step 3 gate).

**Init mode (`--init`) carve-out:** may install dev dependencies and write `.claude/test/test.json` after the user approves at its gate. It still does NOT write application or test source code (config scaffolds and example smoke tests are out of scope — it only recommends and records). When `--init` is present, run the **Init mode** protocol below and skip the execution protocol (Steps 1–5) entirely.

## Inputs / Outputs

| | Name | Source / Destination |
|--|------|----------------------|
| In | Diff scope | `--base <branch>` or full working tree |
| In | eval_set | `--eval-set <path>` (JSON) or bootstrapped from `--prd <path>` |
| Out | Findings JSON | stdout always; `features/prd-[n]/test/test-<YYYYMMDD-HHmmss>.json` when PRD known |

Schema and verdict semantics: `refs/schema.md` (conforms to the shared canonical finding object in `../shared/refs/finding-schema.md`).

## Init protocol (`--init` only)

Runs instead of the execution protocol. Sets up the testing suite the codebase needs and
writes `.claude/test/test.json`. Full decision tables and the `test.json` schema live in
`refs/modes/init.md` — load it before Step I-2.

### Step I-0 — Check for an existing cache ← gate before any work

Check whether `.claude/test/test.json` already exists:

```bash
[ -f .claude/test/test.json ] && echo EXISTS || echo ABSENT
```

- **ABSENT** → no cache yet. Proceed straight to Step I-1 to init it (no question asked).
- **EXISTS** → a cache is already present. Make ONE `AskUserQuestion` call before doing
  anything else, offering:
  - **Analyse + update** — read the existing `test.json`, re-run the profile + detect scripts,
    and reconcile: add buckets/tools/packages now needed but missing from the cache, and remove
    entries no longer warranted by the current profile. Preserve unaffected fields. Show the
    diff of added/removed properties before writing.
  - **Replace (fresh run)** — discard the existing cache and run the full init from scratch
    (Steps I-1 → I-5), overwriting `test.json` wholesale.
  - **Cancel** — exit, change nothing.

  This is an extra `AskUserQuestion` permitted only in `--init` mode (it precedes, and is
  separate from, the Step I-3 gate). On **Analyse + update**, still run Step I-1's scripts to
  get current truth, compute the reconciliation against the loaded cache rather than a blank
  slate, then present and write at Steps I-3/I-4. On **Replace**, ignore the loaded cache entirely.

### Step I-1 — Profile + detect

Run both deterministic scripts and keep their JSON:

```bash
P=.claude/scripts/test-init-profile.sh;  [ -f "$P" ] || P="$HOME/.claude/scripts/test-init-profile.sh";  "$P"
D=.claude/scripts/test-tooling-detect.sh; [ -f "$D" ] || D="$HOME/.claude/scripts/test-tooling-detect.sh"; "$D"
```

The profiler answers *what kind of project this is* (shape, languages, frameworks); the
detector answers *what runners are already installed*. Treat both as authoritative — do not
second-guess their file/dep signals. Also note whether `features/prd-*` exists (enables the
`functional` bucket).

### Step I-2 — Compute needed buckets + gaps

Using the **Shape → needed buckets** table in `refs/modes/init.md`, mark every bucket the
profile makes needed, each with a one-line `rationale`. Then set each bucket's `status`:
`configured` (detector found a runner), `partial` (runner present but key packages/config
missing), or `missing` (needed, no runner). For each `missing`/`partial` bucket pick ONE
recommended tool + packages via the **Bucket → recommended tool** table, preferring a tool
already installed and respecting CLI-vs-npm placement.

### Step I-3 — Present plan and gate ← plan-approval AskUserQuestion call

Show needed buckets grouped by status, the recommended tool per gap, and the exact install
command. Then ask once:

```
Test setup plan for <project.type>  (<languages>)
  configured : unit (Vitest), coverage
  missing    : e2e → Playwright (@playwright/test)
               a11y → axe (@axe-core/cli, axe-playwright)
  Install:  npm i -D @playwright/test @axe-core/cli
```

Options: **Install + write cache** (run the install command, then write `test.json`) /
**Write cache only** (record recommendations, install nothing) / **Cancel** (exit, write nothing).

### Step I-4 — Apply

- If **Install + write cache**: run the `install_command` via the detected package manager.
  If it fails, record the affected packages under `recommended_to_install` anyway and note the
  failure — never leave the cache unwritten because an install broke.
- Write `.claude/test/test.json` per the schema in `refs/modes/init.md` (create the
  `.claude/test/` directory if absent). Stamp `generated_at` with `date -u +%Y-%m-%dT%H:%M:%SZ`.

### Step I-5 — Summarize

Print a short human summary: project type, buckets now `configured` vs still `missing`, what
was installed, and the next command to run (`/test` to execute, or per-bucket flags). END.

---

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

**Read the init cache (if present):** read `.claude/test/test.json` if it exists. It does NOT override detection commands — detection stays authoritative for *how* to run. Use only its `needed_buckets` to flag gaps: for any entry with `needed: true` whose runner came back `null` from detection, annotate that bucket in the Step 3 plan with `⚠ needed but not configured — run /test --init`. Absent cache → no annotations; proceed normally.

### Step 1b — Diff-surface classification (`--changed-only` only)

Only runs when both `--changed-only` and `--base <branch>` are supplied. If `--changed-only` is given without `--base`, ignore it and print `"--changed-only requires --base <branch> — ignored."`; skip the rest of this step.

Take the changed file list already resolved for `--base` scoping (`git diff --name-only <base>...HEAD`) and classify each path into a surface:

| Surface | Path counts as this surface if it matches | Buckets gated by this surface |
|---------|---------------------------------------------|--------------------------------|
| UI | `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.css`, `*.scss`, any path containing `/components/`, `/pages/`, `/views/`, `/screens/`; for Flutter projects (project type `mobile` or Dart files present) also `lib/**/*.dart` | `qa`, `a11y`, `perf`, `e2e`, `mobile` |
| API/backend | any path containing `/routes/`, `/controllers/`, `/handlers/`, `/api/`, `/server/`, `/services/`; `*.proto`; OpenAPI/Swagger spec files | `load`, `api` |

A gated bucket becomes **surface-skip-eligible** if zero changed files match its surface. `unit`, `functional`, and `coverage` are never surface-gated — they always run regardless of which surfaces the diff touches.

**Fail open:** if the changed-file list can't be resolved, or classification is ambiguous, do not mark anything skip-eligible — an unnecessary run is cheaper than a missed regression. Note in the Step 3 plan which buckets were skipped this way and why (e.g. `skipped — no UI files changed`).

### Step 2/5 — Resolve eval_set

| Condition | Action |
|-----------|--------|
| `--eval-set <path>` supplied | Read `eval_set.json`; extract only `executable`-classed assertions. Skip PRD bootstrap. |
| `--prd <path>` supplied | Bootstrap eval_set from the named PRD using the same discovery protocol as `/review` Step 3. Classify all assertions; keep only `executable` for this step. |
| Neither flag | Attempt PRD auto-discovery (`features/prd-*/prd-*.md`, most recent first); if found, bootstrap as above. If no PRD, set `eval_set = []`. |

Emit: `Eval-set: <N> executable assertions.`

### Step 3/5 — Confirm and gate ← sole AskUserQuestion call

Show execution plan. Omit any bucket that is mode-flag-excluded, has a `null` runner, or has an empty `eval_set`. Append `[parallel]` to the header line by default; append `[sequential]` instead when `--sequential` is set. If `--flaky <N>` is set, append `[flaky ×N]`. For any bucket marked surface-skip-eligible at Step 1b, show it with a `skipped — <reason>` line instead of its command.

```
Test execution plan  [parallel] [flaky ×2]        ← [parallel] by default, [sequential] with --sequential; [flaky ×N] only with --flaky <N>
Unit/Integration  → <test_runner.command> (<N> changed files)
E2E               → <e2e_runner.command>
Functional        → <N> executable assertions via /tmp scripts
QA / Visual       → skipped — no UI files changed (--changed-only)
Load              → <load_runner.command>
Accessibility     → <a11y_runner.command>
Performance       → <perf_runner.command>
API / Contract    → <api_runner.commands>
Mobile            → <mobile_runner.command> [iOS: <n> device(s), Android: <n> device(s)]
Coverage          → <coverage_runner.command> (thresholds: lines ≥ <n>%, branches ≥ <n>%)
```

Options: **Proceed** / **Skip bucket(s)** (user names which to skip; continue without re-asking) / **Cancel** (exit, no findings).

No further `AskUserQuestion` calls.

### Step 4/5 — Dispatch buckets as parallel subagents (default) or in order (`--sequential`)

**Skip a bucket if any of these are true:**
- A mode flag (`--unit`, `--e2e`, `--functional`, `--qa`, `--load`, `--a11y`, `--perf`, `--api`, `--mobile`, `--coverage`) was supplied and this bucket's flag was NOT included.
- The required runner / eval_set is absent (see table below).
- The user skipped it at the Step 3 gate.
- (`--changed-only` + `--base` only) the bucket was marked surface-skip-eligible at Step 1b (`qa`, `a11y`, `perf`, `e2e`, `mobile`, `load`, `api`) and none of the changed files matched its surface.

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

**Parallel subagent dispatch (default):** activate each selected, non-skipped bucket as its own parallel subagent via the `Agent` tool — mirroring the dispatch language `plan-em` uses for `eng` agents ("Activate each approved agent as a parallel subagent via the `Agent` tool"). Each subagent runs exactly one bucket per its mode ref and writes that bucket's JSON to `/tmp/test-<runid>/<bucket>.json`. Do not wait for one to finish before starting the next.

- **Resource isolation for `load` and `perf`:** these two buckets are carved out of the concurrent batch. Dispatch the remaining selected buckets (unit, e2e, functional, qa, a11y, api, mobile, coverage) fully parallel; run `load` and `perf` **on their own** — not competing with other buckets, and not with each other — so CPU/network contention can't skew their timing/throughput numbers. (Concretely: run the non-load/perf batch to completion, then run load and perf isolated, or otherwise guarantee neither overlaps another bucket.)
- **Concurrency cap:** if more buckets are selected than the subagent dispatch limit, the excess queue and run as slots free — never a dispatch failure.
- **Degenerate selections (fall out of the rules above, no special-casing needed):** a single selected bucket dispatches as a batch of one (the load/perf isolation rule still applies to it); if only `load`/`perf` are selected there is no concurrent batch at all, just the isolated run(s); if neither `load` nor `perf` is selected the isolation carve-out is a no-op and the concurrent batch runs alone; a skipped/surface-pruned bucket is never dispatched; if no buckets are selected nothing is dispatched and Step 5 aggregates an empty set.

**Sequential (`--sequential`):** run in order 1→10 in-process (no subagents); proceed to the next bucket even if a prior one fails or errors. This is the pre-parallel behavior, retained for debugging one bucket at a time.

**Bucket-level error rule:** a runner crash, missing binary, unreachable target, or auth failure within a bucket produces `pass_with_warnings` for that bucket — never `fail`. This prevents a broken CI environment from falsely blocking a merge. Each bucket's mode ref defines its specific error table; the top-level verdict aggregates across all completed buckets as normal.

### Step 5/5 — Aggregate and emit

Do NOT compute the overall verdict or hand-merge the bucket JSON. Throughout Step 4, each bucket's final JSON is written to `/tmp/test-<runid>/<bucket>.json` (recognised buckets: `unit`, `e2e`, `functional`, `qa`, `load`, `a11y`, `perf`, `api`, `mobile`, `coverage`). Skipped buckets are simply not written.

**Stream verdicts as subagents return:** under the default parallel dispatch, report each bucket's verdict to the user the moment its subagent returns (a one-line `<bucket> → <verdict>` as each completes), rather than withholding all output until the run ends. Once **every** dispatched subagent — including the isolated `load`/`perf` pair — has returned, run the final aggregation pass exactly **once** over all bucket JSON outputs (below). Under `--sequential` there is nothing to stream — buckets already complete in order — so just aggregate at the end.

**Missing/failed subagent output (does not abort aggregation):** if a *dispatched* bucket's subagent returns without writing a valid `/tmp/test-<runid>/<bucket>.json` (crash, killed, wrote nothing), record that bucket as `pass_with_warnings` with a finding noting the missing output, and proceed — the final aggregation still runs over the remaining buckets. A dispatched bucket is never silently dropped; only *skipped* buckets (mode-flag-excluded, `null` runner, surface-pruned, user-skipped) are legitimately absent.

**Write isolation:** the bucket name is baked into every path a bucket writes to — the final JSON (`/tmp/test-<runid>/<bucket>.json`) and any bucket-owned scratch dir (e.g. Functional's `/tmp/test-functional-<runid>/`, Mobile's per-device artifact paths). No two buckets ever share a filename or directory, so the concurrent subagents cannot clobber each other's output or scratch files even though they run at the same time. If a future bucket needs scratch space, it must namespace it under its own bucket name the same way — never write to a shared, bucket-agnostic path.

Then invoke the aggregator:

```bash
S=.claude/scripts/test-aggregate-verdict.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/test-aggregate-verdict.sh"
"$S" \
  --run-dir /tmp/test-<runid> \
  [--prd <path>] \
  [--eval-set <path>] \
  [--parallel]                # default dispatch is parallel — pass this unless --sequential was used
```

The script:
- validates each bucket file has a recognised `verdict` (`pass` | `pass_with_warnings` | `fail`) — refuses with exit 1 if any is missing or malformed
- computes the overall verdict as `fail > pass_with_warnings > pass` across present buckets
- merges every bucket payload under `.buckets` keyed by bucket name (skipped buckets omitted)
- emits the final JSON to stdout per `refs/schema.md`

Pipe stdout to `features/prd-<n>/test/test-<YYYYMMDD-HHmmss>.json` when a PRD is known (use `date +%Y%m%d-%H%M%S` for the timestamp — don't construct it by hand). Always print to stdout regardless.

If the script exits 1, the offending bucket wrote invalid JSON — fix that bucket's emission and re-run; do NOT fall back to hand-aggregation.

## References

- `.claude/scripts/test-tooling-detect.sh` — Step 1 fingerprint detector (installed runners)
- `.claude/scripts/test-init-profile.sh` — Init Step I-1 codebase shape profiler
- `.claude/scripts/test-aggregate-verdict.sh` — Step 5 verdict aggregator + JSON merger
- `refs/modes/init.md` — `--init` decision tables (shape→buckets, bucket→tools) and `test.json` schema
- `refs/schema.md` — output JSON schema and verdict semantics (conforms to the shared canonical finding object)
- `../shared/refs/finding-schema.md` — canonical finding object shared with /review and /pre-merge (severity enum, dedup/regression keys, verdict normalization)
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
