---
name: test
description: >
  Execution-focused test skill. Runs unit/integration tests via the detected
  test runner, e2e tests via the detected e2e runner, and verifies executable
  functional assertions from an eval_set. Accepts --eval-set to consume
  eval_set.json written by /review, avoiding re-bootstrapping from the PRD.
  Emits structured JSON findings compatible with the pre-merge finding schema.
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

Flags are composable: `/test --base main --eval-set features/prd-3/review/eval_set.json`

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

Show execution plan:

```
Unit/Integration  → <test_runner.command> (<N> changed files)
E2E               → <e2e_runner.command>
Functional        → <N> executable assertions via /tmp scripts
```

Omit any bucket where the runner is `null` or `eval_set` is empty.

Options: **Proceed** / **Skip bucket(s)** (user names which to skip; continue without re-asking) / **Cancel** (exit, no findings).

No further `AskUserQuestion` calls.

### Step 4/5 — Run buckets in order

Run each bucket that was not skipped or absent. Proceed to the next bucket even if a prior one fails — collect all findings before aggregating.

| Order | Bucket | Mode ref | Skip condition |
|-------|--------|----------|----------------|
| 1 | Unit / Integration | `refs/modes/unit.md` | `test_runner` is `null` |
| 2 | E2E | `refs/modes/e2e.md` | `e2e_runner` is `null` |
| 3 | Functional | `refs/modes/functional.md` | `eval_set` is empty |

### Step 5/5 — Aggregate and emit

Merge bucket outputs into output schema (`refs/schema.md`). Overall verdict = worst across completed buckets (`fail` > `pass_with_warnings` > `pass`). Emit JSON to stdout. If PRD known, also write `features/prd-<n>/test/test-<YYYYMMDD-HHmmss>.json`. Omit skipped buckets from output.

## References

- `refs/schema.md` — output JSON schema and verdict semantics
- `refs/modes/unit.md` — unit/integration runner invocation and output parsing
- `refs/modes/e2e.md` — e2e runner invocation and output parsing
- `refs/modes/functional.md` — executable assertion verification via ephemeral scripts
- `refs/../../shared/refs/tooling-detection.md` — tooling fingerprint protocol
