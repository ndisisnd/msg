---
name: test
description: >
  Execution-focused test skill. Runs unit/integration, e2e, functional,
  visual (QA), and load test buckets via detected runners. Per-mode flags
  (--unit, --e2e, --functional, --qa, --load) target individual buckets;
  --fast runs all selected buckets in parallel. Accepts --eval-set to
  consume eval_set.json written by /review. Emits structured JSON findings
  compatible with the pre-merge finding schema.
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

Run tooling detection using `refs/../../shared/refs/tooling-detection.md`. Produce:

- **`test_runner`** — unit/integration runner object, or `null` if none detected.
- **`e2e_runner`** — e2e runner object, or `null` if none detected.
- **`qa_runner`** — visual testing runner object, or `null` if none detected. Recognised tools: Playwright (visual snapshot mode), Chromatic, Percy, BackstopJS, Loki.
- **`load_runner`** — load testing runner object, or `null` if none detected. Recognised tools: k6, Artillery, Locust, autocannon, wrk, hey.
- **`a11y_runner`** — accessibility audit runner object, or `null` if none detected. Recognised tools: axe-core (via `@axe-core/cli`, `axe-playwright`, `jest-axe`), Lighthouse (accessibility mode), pa11y.
- **`perf_runner`** — performance budget runner object, or `null` if none detected. Recognised tools: Lighthouse CI (`lhci`), size-limit, bundlesize.
- **`eval_set`** — resolved assertion list (see Step 2).

Detection runs once; never re-derive mid-run.

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
```

Options: **Proceed** / **Skip bucket(s)** (user names which to skip; continue without re-asking) / **Cancel** (exit, no findings).

No further `AskUserQuestion` calls.

### Step 4/5 — Run buckets in order (or in parallel with `--fast`)

**Skip a bucket if any of these are true:**
- A mode flag (`--unit`, `--e2e`, `--functional`, `--qa`, `--load`) was supplied and this bucket's flag was NOT included.
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

**Sequential (default):** run in order 1→7; proceed to the next bucket even if a prior one fails or errors.

**Parallel (`--fast`):** start all selected, non-skipped buckets concurrently; collect all findings before aggregating. Do not wait for one to finish before starting the next.

**Bucket-level error rule:** a runner crash, missing binary, unreachable target, or auth failure within a bucket produces `pass_with_warnings` for that bucket — never `fail`. This prevents a broken CI environment from falsely blocking a merge. Each bucket's mode ref defines its specific error table; the top-level verdict aggregates across all completed buckets as normal.

### Step 5/5 — Aggregate and emit

Merge bucket outputs into output schema (`refs/schema.md`). Overall verdict = worst across completed buckets (`fail` > `pass_with_warnings` > `pass`). Emit JSON to stdout. If PRD known, also write `features/prd-<n>/test/test-<YYYYMMDD-HHmmss>.json`. Omit skipped buckets from output.

When `--fast` was used, include `"parallel": true` at the top level of the output JSON.

## References

- `refs/schema.md` — output JSON schema and verdict semantics
- `refs/modes/unit.md` — unit/integration runner invocation and output parsing
- `refs/modes/e2e.md` — e2e runner invocation and output parsing
- `refs/modes/functional.md` — executable assertion verification via ephemeral scripts
- `refs/modes/qa.md` — visual/QA runner invocation and diff reporting
- `refs/modes/load.md` — load test runner invocation and threshold reporting
- `refs/modes/a11y.md` — accessibility audit runner invocation and WCAG violation reporting
- `refs/modes/perf.md` — performance budget runner invocation and Web Vitals / bundle-size reporting
- `refs/../../shared/refs/tooling-detection.md` — tooling fingerprint protocol
