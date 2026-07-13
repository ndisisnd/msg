---
name: buckets-common
description: Shared contract for pre-merge's Step 5 platform buckets (e2e, qa, mobile, perf, a11y, coverage, api, load). Runner guard, bucket-error rule, output envelope, and the gate options (--flaky, --changed-only) migrated from /test.
---

# Step 5 platform buckets — common contract

Which buckets run is decided by the Step 0 platform profile's `required_buckets` —
**never hardcoded**. Each selected bucket runs as its own parallel `Agent` subagent
and reads its runner from the Step 1 tooling fingerprint
(`pre-merge-tooling-detect.sh`); it does not re-detect.

Buckets: `e2e`, `qa` (visual), `mobile`, `perf`, `a11y`, `coverage`, `api`, `load`.
`load` and `perf` run **isolated** (not overlapping other buckets or each other) so
CPU/network contention can't skew their timing numbers.

## Runner guard (each bucket Step 1)

If the bucket's `<bucket>_runner` is `null`: emit `pass_with_warnings` with the
bucket's note (`"No <kind> runner detected — <bucket> bucket skipped."`) and return.
A missing runner skips the bucket — never `fail`. Record it as `skipped: {reason: "no_tooling"}`.

## Bucket-level error rule

A runner crash, missing binary, unreachable target, or auth failure within a bucket
produces `pass_with_warnings` for that bucket — **never `fail`** — so a broken
environment can't falsely block the gate. When some targets succeed, emit the
findings that exist and set the verdict from those.

## Output envelope

Each bucket returns one JSON object:

```json
{ "verdict": "pass" | "pass_with_warnings" | "fail",
  "bucket": "<name>", "runner": "<runner name>", "totals": { }, "findings": [ ] }
```

Every entry in `findings[]` is a **canonical finding object** (`../../../shared/refs/finding-schema.md`).
`source`/`category` = the bucket name (prefixed `pre-merge:bucket:<name>` for `source`
per the schema). `findings[]` is empty on a clean pass — `pass` results belong in
`totals`.

## Gate options (migrated from /test)

- **`--flaky <N>`** — for `e2e` (and unit-int at Step 3): re-run each failing spec/test up to `N` times via its `repro`, stopping on first pass. Passes-on-retry → reclassify as flaky (`severity: medium`, `evidence.flaky: true`, `evidence.retries: <n>`, counts toward `totals.flaky` not `totals.failed`). Still failing after `N` → genuine (`high`). Bucket `fail` only if ≥1 remains failing after retries.
- **`--changed-only`** (with a diff base) — skip a bucket whose surface the diff doesn't touch. UI surface (`*.tsx/*.jsx/*.vue/*.svelte/*.css`, `/components/`, `/pages/`, `/views/`, `/screens/`, Flutter `lib/**/*.dart`) gates `qa`/`a11y`/`perf`/`e2e`/`mobile`; API/backend surface (`/routes/`, `/controllers/`, `/handlers/`, `/api/`, `/server/`, `/services/`, `*.proto`, OpenAPI specs) gates `load`/`api`. **Fail open** — if the changed-file list can't be resolved, run the bucket. `coverage` is never surface-gated.

Per-bucket runner invocation, output parsing, and finding mapping live in each
bucket's own file.
