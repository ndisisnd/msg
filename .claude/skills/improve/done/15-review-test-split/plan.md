# Improvement Plan — 15-review-test-split

**Skill:** `review` (refactor) + new `test` skill
**Change type:** Refactor + new capability

## Problem

`/review` conflates two fundamentally different kinds of work: static semantic analysis ("is the code correct?") and test execution ("does it work?"). Coverage mode runs the live test runner and parses a coverage file. Functional mode generates ephemeral scripts under `/tmp/` and executes them. Both are slow, have side effects, and belong in an execution-focused skill — not a code review.

The result: review is unpredictable in speed, requires a running project environment, and mixes static findings with execution failures in the same output. Execution concerns should live in a dedicated `/test` skill that pre-merge can delegate to, and review should be pure static analysis.

---

## Proposed changes

| # | What | How | Why necessary | Why ignorable | Rank |
|---|------|-----|---------------|---------------|------|
| 1 | Strip test execution from Coverage mode | Rewrite `refs/modes/coverage.md`: remove `test_runner.command` execution and coverage file parsing; replace with static sibling-file detection (does a `.test.*`/`.spec.*`/`__tests__/` counterpart exist for each changed file?) and assertion-presence check (are eval_set entries referenced in nearby test files?) | Review runs live tests today, making it slow and environment-dependent | Not ignorable — this is the core scope change | P0 |
| 2 | Remove `test_runner` from review Step 2 fingerprint | Edit `SKILL.md` Step 2 and `refs/schema.md` Fingerprint object to drop `test_runner`; Coverage mode no longer needs it | Coverage no longer executes tests; keeping it adds unnecessary detection work and a misleading output field | Not ignorable — stale fingerprint output is confusing | P0 |
| 3 | Reclassify `executable` assertions in Functional mode as `n/a` | In `refs/modes/functional.md` Step 3: remove ephemeral script generation and Bash execution; `executable` class assertions emit `n/a` with `note: "executable — run /test for verification"` instead of a run verdict; `intent` and `negative` paths are unchanged. Also define mode-level verdict for the all-deferred case: when every applicable assertion is `n/a`, verdict is `warn` (never `pass`) with note `"all assertions deferred to /test"` | Removes script execution from review while preserving signal that these assertions exist and need verification; prevents false-green when the applicable tally is empty | Could silently drop executable assertions, but n/a referral maintains traceability | P0 |
| 4 | Emit eval_set handoff artifact from review | In `SKILL.md`: after Step 3 / before Functional emits findings, write the resolved `eval_set[]` (with `eval_set_source` and per-assertion `class`) to `<run_dir>/eval_set.json`; expose the path as `eval_set_path` in the top-level run output. Functional mode embeds that path into the n/a note (`"run /test --eval-set <path> for verification"`) so the handoff is discoverable from the report | Without this, `/test` has no way to verify the specific assertions review deferred — re-bootstrapping from PRD would produce a different eval_set (paraphrase drift, source mismatch) and the deferral chain leaks | Not ignorable — this is the contract that makes the split coherent | P0 |
| 5 | Create `/test` skill `SKILL.md` | New file at `.claude/skills/test/SKILL.md`; three execution buckets in order: (1) unit/integration via `test_runner`, (2) e2e via `e2e_runner`, (3) functional assertions via eval_set executable path; trigger flags `--base`, `--prd`, `--eval-set <path>` (when supplied, consume eval_set verbatim and skip re-bootstrap); shares tooling detection from `shared/refs/tooling-detection.md`; human gate before fan-out; emits JSON findings compatible with pre-merge's finding schema | Core new capability: a standalone, execution-focused skill that owns all test execution in the workflow | N/A — this is the stated deliverable | P0 |
| 6 | Create `/test` mode refs | New files at `.claude/skills/test/refs/modes/unit.md`, `e2e.md`, `functional.md`; `functional.md` extracts the full executable execution path from review's current `refs/modes/functional.md` Step 3 (script generation, execution, evidence); unit.md and e2e.md cover runner invocation, output parsing, verdict | Each bucket needs its own scoped protocol for runner invocation and output parsing | e2e.md could be deferred to P1 | P0 |
| 7 | Create `/test` output schema | New `refs/schema.md` under the test skill; finding shape mirrors pre-merge's `finding-schema.md` (`id`, `severity`, `category`, `evidence`, `repro`); verdict: `fail` / `pass_with_warnings` / `pass` / `refused` | Needed for pre-merge to consume `/test` output cleanly | Could use pre-merge schema directly — but test skill shouldn't depend on pre-merge | P0 |
| 8 | Update pre-merge to delegate integration+e2e buckets to `/test` | Edit `pre-merge-plan.md` Step 5 fan-out: replace integration and e2e bucket subagents with a single `/test` invocation (passing `--base`, `--prd`, `--eval-set <path>` sourced from review's `eval_set_path` when review ran upstream, and diff context); pre-merge keeps build, security, bundle buckets directly | Avoids duplicated test runner logic and keeps pre-merge's scope clean | Deferrable until pre-merge ref files are built (they don't exist yet) | P1 |

---

## Scope boundaries

**In scope:**
- review `refs/modes/coverage.md` — full rewrite to static check
- review `refs/modes/functional.md` — strip executable path, add n/a reclassification, define all-deferred verdict
- review `SKILL.md` Step 2 — remove `test_runner` from fingerprint
- review `SKILL.md` — emit `eval_set.json` to run_dir and expose `eval_set_path` in top-level output
- review `refs/schema.md` — remove `test_runner` from Fingerprint object; add `eval_set_path` to top-level output; update Coverage and Functional mode output shapes
- New `.claude/skills/test/` skill tree (SKILL.md + refs/modes/ + refs/schema.md) with `--eval-set` flag support
- pre-merge plan update to delegate test buckets and forward `--eval-set` (P1)

**Out of scope:**
- pre-merge ref files (`output-schema.md`, `finding-schema.md`, etc.) — not built yet; build is tracked separately
- Changes to `/cook` flags or `/review` Quality/Security/Performance modes
- eval_set bootstrapping logic — stays in review and is reused by `/test` via shared protocol reference

---

## Dependency order

```
Change 1 (strip Coverage execution)
Change 2 (remove test_runner from fingerprint)   ← both depend on nothing external
Change 3 (reclassify executable in Functional, define all-deferred verdict)
Change 4 (emit eval_set.json + eval_set_path)    ← depends on change 3 (classes set before emit)

Change 5 (test SKILL.md, --eval-set flag)        ← after change 4 (consumes the handoff)
Change 6 (test mode refs)                        ← after change 5
Change 7 (test schema)                           ← parallel to change 6

Change 8 (pre-merge delegation, forwards --eval-set) ← after changes 4-7; P1
```
