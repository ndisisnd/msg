---
name: output-schema
description: JSON schema for the pre-merge final emission. Defines field names, types, severity enum, verdict enum, and refusal shape.
---

# Output Schema

## Top-level shape

```json
{
  "run_id": "<uuid-or-timestamp>",
  "base": "<git ref used as base>",
  "branch": "<current branch name>",
  "timestamp": "<ISO 8601>",
  "commit_count": 0,
  "files_changed": ["path/to/file.ts"],
  "verdict": "pass" | "pass_with_warnings" | "fail" | "refused" | "skipped",
  "summary": {
    "blocker": 0,
    "high": 0,
    "medium": 0,
    "low": 0
  },
  "issues": [],
  "skipped": [],
  "prd_paths": [],
  "prior_issues_loaded": false,
  "profile": "strict" | "standard" | "lenient",
  "issues_file": "features/prd-<N>-<slug>/reports/report-prd-<N>-<K>.json" | "features/reports/report-<K>.json" | null,
  "pr_url": "<feature→staging PR url>" | null,
  "pipeline": { "waves": [["mechanical","security","unit","integration"],["coverage"],["regression"]], "pruned": [ {"id": "e2e", "by": "--changed-only"} ] },
  "test_selection": {
    "mode": "minified",
    "tier": "S",
    "signals": { "modules": 2, "ratio": 0.06, "fan_in_pct": 0.41 },
    "per_check": {
      "unit": { "selected": 42, "total": 731 },
      "integration": { "selected": 118, "total": 118, "fallback_reason": "run_minified: null" }
    }
  }
}
```

- `profile` — the platform-tolerance profile resolved for this run.
- `issues_file` — path to the issues file (the **universal report**, C7) written on a non-clean verdict (`fail`), consumed by `eng --build report=`; `null` on a clean pass. NO-PRD runs fall back to `features/reports/report-<K>.json`.
- `pr_url` — the feature→staging PR opened by OPEN-PR on `pass`/`pass_with_warnings`; `null` otherwise. Pre-merge never merges it.
- `pipeline` — **additive, optional** (v3): the resolved, ordered wave list the executor ran + which components each flag pruned. Observability only — its absence does not change any other field. Under test selection its per-component entries carry the selection suffix — `"unit: minified (42/731, tier S)"`.
- `test_selection` — **additive, optional** (v4): what the run's minified test selection did. **Emitted only when selection actually ran** (`policies.test_selection` enabled, or `--minified`, and not `--full`); **absent** on a full or disabled run — absence is the pre-key shape, never a signal to interpret. Its presence never changes any other field, and `verdict`/`summary`/`issues[]` semantics are identical to a full run. See [`test_selection`](#test_selection--minified-run-honesty) below.
- **All keys above are unchanged from pre-v3; `pipeline` and `test_selection` are additive new keys, never renames of anything existing.**

## `test_selection` — minified-run honesty

A minified run must never be mistaken for a full one. This block is the machine-readable
half of that guarantee (the human-readable halves are the `pipeline` line and the run
report's `## Test results`); it is also the audit trail that makes a backstop miss
attributable — it records exactly what was excluded and why.

| Field | Type | Notes |
|---|---|---|
| `mode` | enum `minified` \| `full` | `full` appears only when selection was **on** but every selection-capable component fell back (rule steps 1–4) — a selection-off run omits the whole block instead |
| `tier` | enum `S` \| `M` \| `L` | the resolved size tier — the **largest** tier any signal landed in (conflicts always resolve toward more testing) |
| `signals` | object | the deterministic prelude inputs the tier was computed from: `modules` (int — distinct modules/targets/packages touched), `ratio` (number — \|affected ∪ critical\| / \|suite\|), `fan_in_pct` (number \| null — highest fan-in percentile among touched files; `null` ⇒ the graph was unavailable and the signal was treated as exceeding the small bound). Same diff + same thresholds ⇒ same values ⇒ same tier |
| `per_check` | object `<component id, {selected, total, fallback_reason?}>` | one entry per **selection-capable** component that ran (`unit`, `integration`, `regression`). `selected`/`total` are test counts |
| `per_check.<id>.fallback_reason` | string | present **only** when that component ran full despite selection being on — the rule step that fired, verbatim: `"force-full: <path>"` · `"run_minified: null"` · `"fallback: <reason>"` · `"tier: L (<trigger>)"` · `"tier: M (widen-to-full)"` (**`integration` only** — the one tier-table cell where a non-L tier still runs full, `refs/executor.md` §3c.1). Absent ⇒ the component genuinely ran minified |

Components with no `run_minified` (`mechanical`, `security`, `migration`, and every
platform component) never appear in `per_check` — they are not selection-capable and
always ran whole. Rule and rubric in `refs/executor.md` §3c; policy fields in
`../../shared/refs/policy-schema-pre-merge.md` §`policies.test_selection`.

## Universal report (the paired issues file — C7)

`issues_file` points at `report-prd-<N>-<K>.json`, the **universal report**. It is the
pre-v3 issues-file shape — `issues[]` + `context` + `summary` + `followUp` — **plus** an
additive `checks[]` block (each per-check result report's `{check, group, verdict, totals,
runner, log_path}`). `issues[]` is the flattened + deduped fix list, each finding
retaining `source` = producing check. `followUp.status` stays **camelCase**. The
verdict JSON above and the universal report share the canonical finding shape.
`checks[]` is additive — not a rename of any existing issues-file key. Full
shape in `refs/executor.md` §5 and `../../shared/refs/check-report-schema.md`.

## Verdict semantics

| Verdict | Meaning | Exit code |
|---|---|---|
| `"pass"` | Zero findings | 0 |
| `"pass_with_warnings"` | Only medium / low findings | 0 |
| `"fail"` | Any blocker or high finding | 1 |
| `"refused"` | Early termination — clean tree, schema mismatch, or out-of-scope instruction | 1 |
| `"skipped"` | User declined at the SYNC conflict pause | 0 |

## issues[] entry shape

Each item in `issues[]` is a **canonical finding object** — the field set, types,
and enums are defined once in `../../shared/refs/finding-schema.md`, with pre-merge's
component-specific notes and evidence extensions in `refs/finding-schema.md`. This file
does not re-list the fields.

ID prefixes name the producing stage: `mech`, `unit`, `regr`, `e2e`, `qa`,
`mobile`, `perf`, `a11y`, `cov`, `api`, `load`, `sec`, `mig`, `func`. See
`refs/finding-schema.md`.

## skipped[]

Array of stages/components omitted from this run. Each entry:

```json
{
  "bucket": "load",
  "reason": "no_tooling" | "not_in_profile" | "not_triggered"
}
```

(the `bucket` key is the literal wire field — unchanged this phase, same reason as
`refs/_common.md`'s component envelope note.)

- `no_tooling` — no detected tool supports the component.
- `not_in_profile` — the component is not in the platform profile's `required_buckets`.
- `not_triggered` — a component whose `active_when` gate wasn't met (`migration` with no migration files, `smoke` with no matching surface, the `prd` group with no PRD).

## Refusal shape

When `verdict` is `"refused"`, the top-level object is:

```json
{
  "verdict": "refused",
  "reason": "no_manifest" | "no_diff" | "schema_mismatch" | "out_of_scope_modify" | "out_of_scope_action",
  "detail": "<human-readable explanation>",
  "base": "<base ref>",
  "prior_issues_loaded": false,
  "issues": []
}
```

See `refs/refusal-patterns.md` for the three canonical shapes.

## Skipped shape

When `verdict` is `"skipped"`:

```json
{
  "verdict": "skipped",
  "reason": "sync_conflict_declined",
  "base": "<base ref>",
  "branch": "<branch>",
  "timestamp": "<ISO 8601>",
  "detail": "<what the human declined and where>"
}
```

- `sync_conflict_declined` — the human aborted the SYNC merge at a semantic conflict.

## Field reference

| Field | Type | Notes |
|---|---|---|
| `run_id` | string | Timestamp-based or UUID; unique per invocation |
| `base` | string | Git ref used as comparison base |
| `branch` | string | `git branch --show-current` at invocation time |
| `timestamp` | string | ISO 8601, UTC |
| `commit_count` | integer | `git rev-list --count <base>..HEAD` |
| `files_changed` | string[] | Relative paths from repo root |
| `verdict` | enum | See verdict table above |
| `summary` | object | Count of findings per severity level |
| `issues` | array | Zero or more findings; see finding-schema.md |
| `skipped` | array | Components omitted and why |
| `prd_paths` | string[] | Paths of loaded PRD files, empty if none |
| `prior_issues_loaded` | boolean | Whether `--prior-issues` file was loaded |
