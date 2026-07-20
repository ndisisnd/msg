---
name: executor
description: The preflight-driven pipeline executor (C1/C5) — reads devkit/policy.json components[], prunes by presence + flags, topo-sorts on depends_on into parallel waves, runs each component, fails fast by criticality, and aggregates the per-check result reports into the verdict JSON + universal report. Replaces the old fixed Steps 0–9 gate.
type: reference
---

# The pipeline executor

The gate is a **manifest-driven executor**, not a fixed step list. It reads the
resolved `components[]` manifest from `devkit/policy.json`
(`../../shared/refs/policy-schema.md` §`components[]`; catalog defaults +
detection + user overrides seeded by `--init`/`--update`), computes the run order
at runtime, and runs the resolved pipeline. Nothing here re-derives component
metadata by hand — every component's `id`/`group`/`kind`/`criticality`/`cost`/
`depends_on`/`run`/`active_when`/`mandatory`/`present` comes from the manifest
(`../../shared/refs/component-catalog.md` is its source of defaults).

The **spine is un-prunable** (Fork B): `SYNC` is the mandatory DAG root — every
component implicitly depends on it, so the tree is synced before anything runs —
and `OPEN-PR / issues-loop` is the terminal. Neither is a `components[]` entry;
both bracket the resolved pipeline.

## 0 · Load the manifest (Fork C — the no-manifest refusal)

Load + validate `devkit/policy.json` once per run (`policy-schema.md` read-contract).
Then gate on `components[]`:

| Manifest state | Executor behavior |
|---|---|
| `components[]` present, non-empty | **run** — proceed to §1 |
| `components[]` **absent** (file absent, malformed, or `version` ≠ 1) | **REFUSE `no_manifest`** — name `/pre-merge --init`, run **zero** components |
| **pre-v3** `policy.json` (`init`/`release_flow` present, **no** `components[]`) | **REFUSE `no_manifest`** + upgrade nudge — name `/pre-merge --init` |

The refusal shape is `../refs/refusal-patterns.md` §`no_manifest`. This is the
**breaking cutover** (AC-PF13/PF14): the old "file absent → run on built-in
defaults" fallback is **retired** (`AC-LC6`/`AC-ST5` retired). There is no
defaults path — a run without a manifest does nothing but tell the user to run
`--init`. The old per-step `steps.<key>` self-consult is likewise superseded by
component **presence** (an absent component simply isn't in the pipeline).

**Staleness nudge (Fork E, read-only).** With a valid manifest, recompute
`source_signature` cheaply (`policy-schema.md` §`source_signature`) and, on
mismatch, print one line — *"pipeline may be stale — run `/pre-merge --update`"* —
then **proceed on the current manifest**. The executor **never** writes
`policy.json` or mutates `components[]` (AC-UP5/UP6); only `--init`/`--update` do.

## 1 · Resolve the pipeline (prune)

Build the run set from `components[]` (AC-PF6):

1. **Presence.** Include a component iff `present:true` **or** `mandatory:true`.
   `security` + `migration` are always `mandatory` and can never be pruned
   (Fork D, AC-PF12) — with no scanner detected, `security` still runs its
   `/cook` semantic pass; `migration` is `active_when` the diff touches migrations.
2. **`active_when` gate.** Drop a present component whose presence gate isn't met
   this run — `prd` needs a `--prd`; `ui-surface`/`api-surface`/`migrations`/
   `mobile-surface`/`perf-config` need the matching surface in the diff;
   `preview-fired` needs the preview to have fired. `smoke` is present only when
   `preview` fired.
3. **Flag pruning** (record what each prunes for observability, §5):
   - `--changed-only` — drop a platform component whose surface the diff doesn't
     touch (`../_common.md` surface map). Fail-open: unresolved diff → keep it.
   - `--prd <path>` — **enables** `prd`-group components (`prd-consistency`,
     `manual-test-plan`); without it they are pruned (a no-PRD hotfix skips them).
   - `--flaky <N>` changes retry behavior, not membership.

An **absent** component produces **no** step and **no** "skipped/no_tooling" note
(AC-PF6) — that noise lived in the old per-step consult and is gone. (A component
that ran but had nothing to do still writes a `skipped` result report — §4, that
is a *ran-and-skipped* trace, not an absent component.)

## 2 · Order the pipeline (Fork B — runtime topo-sort)

Compute order every run — the manifest carries **no** frozen `order` field (AC-PF4).

1. **Topological sort on `depends_on`** (the only hard edges — AC-CAT3/SEQ6):
   `coverage → {unit, integration}`, `smoke → {preview}`,
   `manual-test-plan → {prd-consistency}` (C22), and `regression`'s tail-pin
   (`depends_on` every other universal/prd component). Everything else is
   independent (the catalog's `sync` marker means "needs the synced branch",
   **not** a dependency edge).
2. **Tie-break** components with no dependency path between them (same wave) by
   `criticality` (critical → blocking → advisory/config-driven) then `cost`
   (cheap → moderate → expensive) — AC-PF7. This is a **display/scheduling** order
   within a wave; it never overrides a hard edge.
3. **Reject a cycle.** The DAG is validated acyclic at `--init` (AC-PF3); if a
   loaded manifest is somehow cyclic, refuse rather than loop.

The sort yields **waves** — each wave is the set of components whose dependencies
all completed in an earlier wave (Kahn levels). For a universal+prd web-app
manifest this collapses today's 6 serial steps into **3 waves** (C5, AC-SEQ1):

| Wave | Components (tie-break order shown) | Why |
|---|---|---|
| **1** | `mechanical` (critical, short-circuits) · `security` (critical) · `unit` · `integration` · `prd-consistency` *(prd; only with `--prd`)* | need only `sync` — no effect edges among them |
| **2** | `coverage` | `depends_on {unit, integration}` — parses their output |
| **3** | `regression` | tail-pinned: `depends_on` all other universal/prd |

Platform components (`e2e`, `a11y`, `perf`, `api`, `load`, `mobile`) are
independent of the universal set (they only `depend_on sync`), so they join
Wave 1 when present. `preview` (only-on-green, late) and `smoke` (`depends_on
preview`) land in the tail waves alongside/after `regression`.

## 3 · Run the waves + fail-fast

Run waves **in order**. For every edge `A depends_on B`, B fully completes before
A starts (AC-PF8) — true under every flag combination. Within a wave:

- **Independent components run concurrently** as parallel `Agent` subagents
  (AC-PF9/SEQ6). `load` and `perf` run **isolated** (not overlapping each other or
  other components) so contention can't skew their numbers (`../_common.md`).
- **Dependent components never run concurrently** — a dependent waits for its
  whole `depends_on` set.

**Only-on-green tier.** `regression`'s test-authoring sub-step, `preview`, and
`smoke` run only after the correctness components are green — never author/deploy
onto a red branch (catalog "Only-on-green tier"; AC-SEQ3). `regression`'s
*accumulated-suite run* always executes at the tail (it's the final
"doesn't-break-production" gate before the PR); only its *authoring* is gated on
green. `prd-consistency` is Wave 1, judges each acceptance criterion against the
diff's code paths + existing tests, and is **independent of regression** — it
never blocks on regression's fresh authoring (AC-SEQ5).

**Fail-fast by `criticality`** (AC-PF11 — this is the DAG generalization of the
old red-step short-circuit; grading in `../severity-rubric.md`):

| Failed component's `criticality` | Effect |
|---|---|
| `critical` (e.g. `mechanical`, `security`, `migration`) | **abort** the remaining pipeline immediately — no later wave runs (AC-SEQ4) |
| `blocking` (e.g. `unit`, `integration`, `e2e`, `regression`, `prd-consistency`) | fail the verdict, mark this component's **downstream dependents `blocked`**, but let **independent** branches in-flight finish so the verdict aggregates the full picture |
| `advisory` / `config-driven` (until the project sets budgets) | **never aborts** — findings recorded, pipeline continues |

A component marked `blocked` (its dependency failed) is not run; it writes a
`skipped` result report with `skip_reason: "blocked:<dep>"` (§4).

## 4 · Write the per-check result report (C6 — always-write)

**Every** component that runs — pass, fail, or skip — writes a normalized
**result report** to `.pre-merge/<ts>/<check>.json` on **every** run, never
failure-only (AC-RR1). `<ts>` is the run timestamp; the dir is a gitignored
runtime artifact. This is the `result` section of the one check-report schema
(`../../shared/refs/check-report-schema.md`):

```json
{ "check": "unit", "group": "universal",
  "verdict": "pass|pass_with_warnings|fail|skipped",
  "runner": "vitest", "ran_at": "<ISO-8601>",
  "totals": { "passed": 24, "failed": 0, "skipped": 0, "flaky": 0 },
  "findings": [ /* canonical findings, source = "<check>", or [] */ ],
  "log_path": ".pre-merge/<ts>/unit.log",
  "skip_reason": null }
```

- Keep it **lean** — `findings[]` carries only the canonical finding shape
  (`../../shared/refs/finding-schema.md`); a clean pass writes `findings: []` and a
  positive `totals` (AC-RR4: you can tell "ran + passed 24" from "skipped"). No
  prose, no duplicated finding bodies.
- `unit` emits the **same** shape as every other check — no Step-3 exceptionalism
  (AC-RR5).
- A **skipped** check still writes a report with `verdict: "skipped"` +
  `skip_reason` (AC-RR6) — e.g. `"no_tooling"`, `"env_unreachable"`,
  `"blocked:unit"`, `"surface_absent"`.
- Mandatory-component reports are always written even when they degrade
  (`security` with no scanner → its `/cook` pass result).

These per-check result reports are the executor's **single uniform aggregation
input** — the verdict and the universal report are both *derived* from them, never
authored separately (AC-RR6/UR6).

## 5 · Aggregate → verdict JSON + universal report (C7)

Read back the per-check result reports and aggregate (this replaces the old
per-stage collect):

1. **Collect** every result report's `findings[]`; filter nulls.
2. **Dedup** by `(category, file, line, rule)` — keep highest severity, concatenate
   `source` (`../../shared/refs/finding-schema.md`).
3. **Triage** with `../severity-rubric.md` (in-diff weighting, dev-only /
   unreachable downgrades, profile coverage floor).
4. **Mark regressions** from `--prior-issues` on `(category, file, rule)`.
5. **Verdict:** `fail` (any blocker/high) · `pass_with_warnings` (only medium/low)
   · `pass` (zero) · `refused`/`skipped` (early-termination paths).

**Verdict JSON (stdout — the final emission, `../refs/output-schema.md`).** Shape
is **unchanged** (AC-PF16) so `eng --build report=`, `fix-loop.md`, and `/msg --gui`
keep working — only the *source* of the stages changed. The one additive,
optional field is `pipeline` (observability, AC-PF15) — the resolved ordered wave
list + what each flag pruned. It is **additive**, never a rename of an existing
key.

**Universal report (`report-prd-<N>-<K>.json` — the eng-ingestible issues file).**
Written on a non-clean verdict into the run report's paired `.json`
(`../../shared/refs/report-schema.md` path rules). It **extends** the existing
issues-file shape (`issues[]` + `context` + `summary` + `followUp`) with a
`checks[]` block — additive, no rename (AC-PF16/UR2):

```json
{ "run_id": "...", "gate": "pre-merge", "verdict": "fail",
  "context": { "base": "...", "branch": "...", "prd": "...",
               "files_changed": [ ], "diff_stat": { } },
  "summary": { "blocker": 0, "high": 1, "medium": 2, "low": 0 },
  "checks": [ /* each result report's {check, group, verdict, totals, runner, log_path} */ ],
  "issues": [ /* flattened + deduped canonical findings — the FIX LIST */ ],
  "followUp": { "status": "open",
                "suggested_command": "eng --build report=<this path>" } }
```

- `checks[]` = the full run picture (what ran, pass/fail/skip, totals) — sourced
  directly from the per-check result reports (AC-UR6).
- `issues[]` = the flattened + deduped `(category,file,line,rule)` fix list; each
  finding keeps `source` = producing check and is eng-fixable (`file`, `line`,
  `rule`, `severity`, `message`, `repro`, `suggestion` — AC-UR3/UR5).
- **`followUp.status` is camelCase — preserve it verbatim** (AC-UR4): `eng --build`
  writes it back, `/msg --gui` reads it. Never rename to `follow_up`/`status`
  casing.
- The verdict JSON and the universal report share the **canonical finding shape**
  (AC-UR7) — neither invents fields the other lacks.

## 6 · Terminal + run report

- **Terminal issue summary** on **every** report write, all verdicts, per
  `../../shared/refs/report-schema.md`. A clean run prints exactly
  `Issue summary — 0 issues`.
- **Run report `## Test results`** has one line per check for pass **AND** fail,
  derived from `checks[]`; `tests_passed`/`tests_failed` frontmatter is summed from
  the result reports' `totals` (AC-RR3). `## How to verify` lists the resolved,
  ordered pipeline + what was pruned (AC-PF15).

## Contract stability (AC-PF16 — load-bearing)

The verdict JSON top-level keys and the issues-file `issues[]` shape are
**unchanged** by this cutover — `pipeline` (verdict JSON) and `checks[]` (issues
file) are **additive**. `eng --build report=`, `../../shared/refs/fix-loop.md`, and
`/msg --gui` read the same keys they always did. Only the source of the stages —
a fixed 0–9 list → the resolved `components[]` pipeline — changed.
