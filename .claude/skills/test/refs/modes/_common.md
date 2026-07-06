# test — Common bucket contract

Shared by all ten execution buckets (`unit`, `e2e`, `functional`, `qa`, `load`,
`a11y`, `perf`, `api`, `mobile`, `coverage`). Each mode file references this file
instead of repeating the guard, the bucket-error rule, and the output envelope.

## Runner detection is not re-done here

Every bucket reads its runner (`<bucket>_runner`) from the **Step 1 fingerprint**
emitted by `.claude/scripts/test-tooling-detect.sh` — it does **not** re-detect or
hardcode a runner list. The script is authoritative for each runner's `name`,
`command`, and any config/report paths (as `SKILL.md` Step 1 states). The
recognised-runner set lives in that script alone.

## Runner guard (each bucket's Step 1)

If the bucket's runner is `null`: emit `pass_with_warnings` with the bucket's note
(e.g. `"No <kind> runner detected — <bucket> bucket skipped."`) and return
immediately. A missing runner skips the bucket — never `fail`.

## Bucket-level error rule

A runner crash, missing binary, unreachable target, auth failure, or missing report
within a bucket produces `pass_with_warnings` for that bucket — **never `fail`** — so
a broken environment can't falsely block a merge. Buckets that need finer handling add
their own error table; it only refines this rule, never overrides it to `fail`. When
some targets/sub-checks succeed, emit the findings that exist and set the verdict from
those.

## Output envelope

Each bucket emits one JSON object of this shape:

```json
{
  "verdict": "pass" | "pass_with_warnings" | "fail",
  "bucket": "<bucket name>",
  "runner": "<runner name>",
  "totals": { },
  "findings": [ ]
}
```

Buckets add their own fields (`command`, `thresholds`, `matrix`, `errors`,
`report_path`, …) and shape `totals` to fit. Every entry in `findings[]` is a
**canonical finding object** — full field set, severity/category enums, evidence
shape, and dedup/regression keys are defined once in
`../../../shared/refs/finding-schema.md`. `findings[]` is empty on a clean pass;
`pass`-type results belong in `totals`, never in `findings[]`.
