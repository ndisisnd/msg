---
name: review
description: >
  After eng --build, resolve a diff, fingerprint the codebase, bootstrap an
  eval-set from the PRD, confirm the review surface, then fan out to /cook
  sub-agents across five always-on review modes plus two conditional modes
  (Migration, A11y/i18n) that only run when the diff matches their trigger —
  with mechanical gates (lint / format / typecheck / secret scan via local
  tooling) layered in ahead of the semantic agents — aggregating findings
  into a single structured JSON. Consumed by preflight or read directly by
  a human.
allowed_tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
  - Agent
---

# review

Code review orchestrator. Runs after `eng --build`, before `gh pr create`. Findings are never carried between runs — each run's `findings[]` reflect only the current diff. When a PRD is known, the fingerprint/eval-set/surface (not findings) may be reused from a cache if the diff hasn't changed since the last run — see `refs/cache.md`.

```
eng --build  →  /test  →  /review  →  [address findings]  →  /review (repeat until pass/warn)  →  /test --eval-set  →  /pre-merge  →  gh pr create
```

## Usage

- `/review` — diffs against HEAD
- `/review <branch>` — diffs against a named branch
- `/review <PR#>` — fetches PR diff via `gh pr diff <n>`
- `/review --full-secret-scan` — opts Security mode Stage 0 into scanning the full working tree (default is diff-only). Composable with branch and PR args, e.g. `/review feature/x --full-secret-scan` or `/review 42 --full-secret-scan`.
- `/review --min-severity <blocker|high|medium|low>` — drop findings below this severity from the emitted output (default: no floor, all severities emitted). Applied in Step 7 after dedup, so dedup's highest-severity-wins logic always runs on the full set first. Verdict computation and the written run-directory JSON are unaffected — only the emitted `findings[]` arrays are filtered. Intended for callers (e.g. `ship`'s iterate loop) that only act on high-signal findings and want a smaller payload to parse each pass.

**Hard refusals:** does NOT modify source code; does NOT check documentation; makes exactly ONE `AskUserQuestion` call (Step 5).

## Inputs / Outputs

| | Name | Source / Destination |
|--|------|----------------------|
| In | Diff | `git diff HEAD` / `git diff <branch>` / `gh pr diff <n>` |
| In | PRD | Auto-discovered from `features/prd-*/prd-*.md` (most recent first) |
| Out | Findings JSON | stdout always; `features/prd-[n]/review/review-<YYYYMMDD-HHmmss>.json` when PRD known |

Schema, sub-skill contract, verdict semantics: `refs/schema.md`.

## Protocol

### Step 1/7 — Resolve diff

| Arg | Command |
|-----|---------|
| None | `rtk git diff HEAD` |
| None, bare invocation on `main` | `rtk git diff HEAD~1 HEAD` |
| Branch name | `rtk git diff <branch>` |
| PR number | `gh pr diff <n>` |

Run `rtk git branch --show-current` to determine the current branch. `review` is workflow-agnostic — runs on any branch including `main`. Bare `/review` on `main` falls back to `git diff HEAD~1 HEAD` so trunk-based and solo workflows still get a review surface. Named-branch and PR invocations work unchanged from any branch. If the resulting diff is empty: exit `Nothing to review — diff is empty.`

### Step 2/7 — Fingerprint codebase

**Cache check (first, before anything else in this step):** locate the PRD (cheap glob over `features/prd-*/prd-*.md` by recency — the full eval-set bootstrap in Step 3 is separate and more expensive). If a PRD is found, check `features/prd-<n>/review/.surface-cache.json` against the current diff's hash. On a cache hit, skip the rest of Step 2 and all of Steps 3-4 — load the cached fingerprint/eval-set/surface and go straight to Step 5. Full protocol: `refs/cache.md`. No PRD found, or cache miss (no file, or diff changed) → proceed below exactly as documented.

Run once at startup; never re-derive mid-run. Detection signals, runner mappings, and the authoritative `/cook` flag inventory all live in `refs/FLAG-LIST.md` — load it once here.

**Tooling detection (script, not manual):** run the deterministic detector via Bash — `rtk .claude/scripts/test-tooling-detect.sh` — and read the JSON it prints to stdout. Take `mechanical_runners[]` and `secret_scanner` **directly from that JSON**; do **not** read `shared/refs/tooling-detection.md` at runtime (the script is authoritative for both — the ref is maintainer documentation only). If the script is unavailable or emits no runners, treat `mechanical_runners[]` as `[]` (Quality Stage 0 no-ops) and `secret_scanner` as `null` (Security Stage 0 emits a `warn`).

Produce four outputs from this step:

- **`active_domains[]`** — list of detected technology domains (used by Steps 4–6 for flag assembly). Signals: `refs/FLAG-LIST.md#domain-detection-review-step-2-fingerprint`.
- **`mechanical_runners[]`** — the `mechanical_runners` array from the detector JSON (lint/format/typecheck runners, used by Quality mode Stage 0). Each entry has `{ name, command, expects_zero_exit, severity_on_fail }`. Empty list if nothing detected — Quality Stage 0 becomes a no-op.
- **`secret_scanner`** — the `secret_scanner` object from the detector JSON (highest-priority detected secret scanner, used by Security mode Stage 0), or `null` if none. When `null`, Security Stage 0 emits a `warn` finding rather than blocking.
- **`flag_inventory`** — in-memory set of every valid flag token parsed from `refs/FLAG-LIST.md` (concerns + per-domain + sub-refs). Used by Step 4 to validate assembled flags.

### Step 3/7 — Locate PRD; bootstrap eval-set

Discovery runs in this order, merging results into `eval_set[]` and deduplicating by assertion text:

1. **PRD sections** — search `features/prd-*/prd-*.md` by recency; extract "Acceptance Criteria", "Test Cases", or "Assertions" sections.
2. **Test files in the diff** — for each `*.test.*`, `*.spec.*`, or `__tests__/` file present in the diff, parse `it(...)`, `test(...)`, `describe(...)` strings as assertions.
3. **Co-located tests** — for each changed source file, check for a sibling test file (same basename, `.test.*` or `.spec.*` suffix, or matching path under `__tests__/`) even if not in the diff; extract assertions as in step 2.
4. **schemas.json** — if the located PRD has a sibling `agent-audit/` or `audit/` run dir (e.g. `features/prd-<n>/agent-audit/schemas.json`), read the `assertions` field and merge.
5. **Conventional test directories** — scan `tests/`, `e2e/`, `integration/` for files tagged to the PRD slug (filename or content contains `prd-<n>`); extract assertions.

If all five sources yield zero assertions, generate `eval_set[]` from the diff as a fallback. Emit the numbered merged list to stdout. User refines at Step 5 via **Adjust**.

Also derive `eval_set_path` in this step:
- If PRD is known: `eval_set_path = features/prd-<n>/review/eval_set.json`
- If PRD is unknown: `eval_set_path = null`

This value is passed to Functional mode (Step 6) and emitted in the top-level output (Step 7). Functional mode writes `eval_set.json` to this path after classifying assertions.

Set `eval_set_source` in the top-level output JSON to one of:
- `"prd"` — every assertion from PRD sections.
- `"tests"` — every assertion from test files (in-diff or co-located).
- `"schemas"` — every assertion from `schemas.json`.
- `"diff"` — every assertion generated from the diff (no other source produced results).
- `"mixed"` — assertions came from two or more of the above sources.

Emit before continuing: `Eval-set: <N> assertions (prd: <a>, tests: <b>, schemas: <c>, diff: <d>).` where the four counts sum to N (omit zero buckets only if it improves readability; otherwise show all four).

**Classify each merged assertion** into `executable` / `intent` / `negative` using the taxonomy table in `refs/modes/functional.md` Step 1. Classification happens once, here, because Coverage mode (Step 6, order 2) runs before Functional mode (Step 6, order 3) and needs the `class` to suppress assertion-gaps for deferred executables. Attach `class` to each `eval_set[]` entry in memory; Functional mode reads it rather than re-deriving it.

### Step 4/7 — Derive review surface

Cross-reference diff against PRD: produce `files_changed`, `uncovered_changes[]` (scope creep candidates). Assemble flags per mode using `active_domains[]` and the global + per-domain tables in `refs/FLAG-LIST.md`. **Validate every assembled flag against `flag_inventory` (loaded in Step 2) — any flag absent from the inventory is silently dropped.**

**Undetected-domain check:** match `files_changed` against the extension list in `refs/FLAG-LIST.md#extensions-with-no-domain-specific-coverage`. If any match, set `surface.undetected_domain_note` to `"<N> changed files in <ext list> have no domain-specific review — /cook has no matching standards shelf"` (omit the field entirely when no matches). This only flags a known no-coverage list — it does not fire for domain-less files that were never expected to match (config, docs, styles, etc).

**Cache write:** if a PRD is known, write `features/prd-<n>/review/.surface-cache.json` with this run's `diff_hash`, fingerprint (Step 2), classified `eval_set` (Step 3), and this surface. Full protocol: `refs/cache.md`. Skip if no PRD is known.

Surface schema: `refs/schema.md`.

### Step 5/7 — Confirm surface ← sole AskUserQuestion call

Show surface summary + full execution plan (each mode → flags + files). Example:
```
Quality    → /cook --api-design --architecture --react  (auth.ts, api/users.ts)
Coverage   → sibling-test check + assertion refs       (auth.ts, api/users.ts)
Functional → eval-set assertions vs diff               (3 assertions)
Security   → /cook --security --auth --typescript      (auth.ts, api/users.ts)
Performance→ /cook --performance --database            (api/users.ts)
```
If `surface.undetected_domain_note` is set, print it directly above the execution plan so the user sees the coverage gap before approving — it is not a mode, so it never appears as a row.

Migration and A11y/i18n rows are added to the plan only when their trigger condition (defined inline in Step 6) matches — omit the row entirely otherwise, e.g.:
```
Migration  → /cook --supabase:migrations                (supabase/migrations/003_add_index.sql)
A11y/i18n  → static scan (no /cook flags)                (components/Nav.tsx)
```

Options: **Proceed** / **Adjust** (update surface + `eval_set[]`, continue without re-asking) / **Cancel** (exit, no findings). No further `AskUserQuestion` calls. Adjustments are not written back to the cache (`refs/cache.md`) — the cache always reflects the auto-derived Steps 2-4 output, never a manual override.

### Step 6/7 — Run modes in order; one subagent per mode

**Compile standards once (before spawning any mode subagent):** the four cook-backed modes (Quality, Security, Performance, Migration) draw their standards from `/cook`. Call `/cook` **once per distinct stack this run** — pass the union of every cook-backed mode's assembled flags in a single invocation — and hold the compiled standards payload. Then, for each mode, inject the slice of that payload matching the mode's flags into that mode's **single** subagent prompt. Mode subagents do **not** call `/cook` themselves. The compiled payload names each rule's source flag, so per-rule attribution survives into aggregated findings. Shared cook-backed execution contract: `refs/modes/_common.md`.
_Fallback:_ if this pre-compile step was skipped (review reached Step 6 with no precompiled payload), each cook-backed mode compiles `/cook` **once** for its own flag set — never once per flag.

**Conditional-mode triggers (evaluated here — load the mode file only on a match):**

- **Migration** (order 6) — runs only when the diff touches at least one migration file: `supabase/migrations/*.sql`, `**/migrations/*.sql`, `**/migrations/*.ts`, `prisma/migrations/**`, or `db/migrate/**`. On a match, load `refs/modes/migration.md` and run it; otherwise skip the mode entirely (no Stage 0, no subagent, omitted from output) and do **not** read `migration.md`.
- **A11y/i18n** (order 7) — runs only when `active_domains[]` includes React, Next.js, or Flutter **and** the diff adds/modifies at least one UI file in that domain (`.tsx`/`.jsx` for React/Next.js; a `.dart` file containing a `Widget` build method for Flutter). On a match, load `refs/modes/a11y-i18n.md` and run it; otherwise skip the mode entirely (omitted from output) and do **not** read `a11y-i18n.md`.

Order and per-mode stage layout:

| Order | Mode | Stage 0 (mechanical, runs first) | Semantic stage |
|-------|------|-----------------------------------|----------------|
| 1 | Quality | Mechanical gate — lint / format / typecheck via `mechanical_runners[]`; any `block` short-circuits and skips the semantic stage. | One subagent (`refs/modes/_common.md`) with the Quality flags + rubric amendment. Flags: globals `--api-design --architecture --error-handling --debug` + active-domain flags touched by the diff. Details: `refs/modes/quality.md`. |
| 2 | Coverage | — (no Stage 0) | Static-only: sibling-test check + assertion-reference protocol against `eval_set`. No `/cook`. `refs/modes/coverage.md`. |
| 3 | Functional | — (no Stage 0) | Static-only: eval-set assertion protocol against the diff. No `/cook`. `refs/modes/functional.md`. |
| 4 | Security | Secret scan — runs `secret_scanner` (diff-only by default, full-tree with `--full-secret-scan`); always proceeds to semantic stage regardless of verdict. | One subagent (`refs/modes/_common.md`) with the Security flags (injection / auth / input-validation). Flags: globals `--security --auth` + security-scoped domain sub-refs. Details: `refs/modes/security.md`. |
| 5 | Performance | — (no Stage 0) | One subagent (`refs/modes/_common.md`) with the Performance flags. Flags: global `--performance` + active-domain flags touched by the diff (sub-ref flags when scope is narrow, e.g. `--database:indexes`). Checks: N+1 query patterns, inefficient loops, missing DB indexes, unbounded memory allocations, unnecessary synchronous operations. |
| 6 | Migration *(conditional — see trigger above)* | Static migration-safety scan (irreversible ops, missing defaults, non-concurrent indexes, missing down-migration); always proceeds to semantic stage regardless of verdict. | One subagent (`refs/modes/_common.md`) with the Migration flags, only if a Supabase/Database flag was assembled. Details: `refs/modes/migration.md`. |
| 7 | A11y/i18n *(conditional — see trigger above)* | — (no Stage 0) | Static-only: missing accessibility attributes, hardcoded strings bypassing existing i18n. No `/cook` sub-agents — no matching concern shelf exists yet. `refs/modes/a11y-i18n.md`. |

Modes 6-7 are conditional (triggers above): if the trigger doesn't match, the mode is skipped entirely (no Stage 0, no subagent, omitted from output) rather than emitted as an empty result. Modes 1-5 always run.

For each mode: run Stage 0 first (if defined), then spawn the mode's **single** semantic subagent (skip this if the mode is static-only or no flags were assembled); wait; collect `{ verdict, findings[] }` per sub-skill contract (`refs/schema.md`). Aggregate Stage 0 findings with the semantic finding into the mode output. On any mode-level `block`: stop pipeline immediately, skip remaining modes, go to Step 7.

**Quality-mode only:** the Quality subagent's prompt gets the rubric amendment from `refs/modes/quality.md#sub-agent-prompt-amendment` appended, plus `uncovered_changes[]` (from Step 4) as an additional input. No other mode receives the rubric amendment or `uncovered_changes[]`.

**Post-collection dedup (all modes):** After collecting the mode's subagent output, apply a deduplication pass: collapse findings sharing `(category, file, line, rule)` — the canonical dedup key (`refs/schema.md`, `../shared/refs/finding-schema.md`) — into a single entry, keeping the one with the highest severity (`blocker` > `high` > `medium` > `low`). Concatenate distinct `source` values from collapsed findings into a comma-separated string on the surviving finding (e.g. `"--api-design,--architecture"`).

### Step 7/7 — Aggregate and emit

Merge mode outputs into output schema (`refs/schema.md`). Overall verdict = worst across completed modes (`block` > `warn` > `pass`), computed from the full, unfiltered finding set.

If PRD known, write `features/prd-<n>/review/review-<YYYYMMDD-HHmmss>.json` **before** applying `--min-severity` — the run-directory artifact always keeps every finding regardless of the flag.

**Findings-count summary line:** emit before the JSON, always (this is the human-reading path — `stdout` is read directly by a person per the top-level Inputs/Outputs table): `Findings: <blocker> blocker, <high> high, <medium> medium, <low> low across <N> modes.` Counts are across the full, unfiltered finding set — the summary always reflects everything found, even when `--min-severity` trims what follows it.

**Apply `--min-severity` (if passed):** filter every mode's `findings[]` to drop entries below the given floor (`blocker > high > medium > low`), then emit the filtered JSON to stdout. Coverage's `gaps[]` and Functional's `n/a` entries are not findings and are never filtered.

Omit unrun modes from output. Include `eval_set_path` in the top-level output (value derived in Step 3; `null` if PRD unknown).

**Sub-PRD next-step offer (printed, not a question):** after emitting the JSON and summary line, print one plain-text next-step line offering a follow-up sub-PRD for any additional changes surfaced by this review:

```
Next: to capture additional changes as a tracked follow-up, run /plan-pm --sub <this PRD number> to spin off a sub-PRD (nested under the parent, builds on the same branch).
```

Substitute the PRD number when a PRD is known; when it isn't, print the bare `/plan-pm --sub` form. This is an emitted suggestion only — it adds **no** `AskUserQuestion` call, so the "exactly ONE `AskUserQuestion` (Step 5)" contract holds. See `plan-pm`'s § Sub-PRD mode.

## References

- `refs/FLAG-LIST.md` — domain detection signals + authoritative `/cook` flag inventory (single source of truth for `active_domains[]` detection and Step 4 flag validation). Mechanical-runner and secret-scanner detection are consumed at runtime from `.claude/scripts/test-tooling-detect.sh` JSON (Step 2); `../shared/refs/tooling-detection.md` is retained only as maintainer documentation of the detection tables.
- `refs/modes/_common.md` — shared cook-backed semantic-stage execution contract (one subagent per mode, injected standards payload, standalone fallback), referenced by the Quality/Security/Performance/Migration modes.
- `refs/schema.md` — sub-skill interface contract, output JSON schema, verdict semantics (findings conform to the shared canonical finding object)
- `../shared/refs/finding-schema.md` — canonical finding object shared with /test and /pre-merge (severity enum, dedup/regression keys, verdict normalization)
- `refs/modes/quality.md` — Quality mode: flags, orchestrator rubric (extends `/cook`'s flag coverage with orchestrator-owned checks), and sub-agent prompt amendment
- `refs/modes/coverage.md` — Coverage mode: test-runner protocol
- `refs/modes/functional.md` — Functional mode: eval-set assertion protocol
- `refs/modes/security.md` — Security mode: flags and what it checks
- Performance mode is folded into Step 6 (flags + checks in the mode table; execution via `refs/modes/_common.md`) — no separate mode file.
- `refs/modes/migration.md` — Migration mode: trigger condition, static safety scan, flags (conditional — runs 6th, loaded only on trigger match)
- `refs/modes/a11y-i18n.md` — A11y/i18n mode: trigger condition, static-only checks (conditional — runs 7th, no `/cook` flags)
- `refs/cache.md` — surface/fingerprint cache: read/write paths, invalidation, interaction with Adjust
