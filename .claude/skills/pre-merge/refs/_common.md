---
name: common
description: Shared contract for pre-merge's Step 5 platform components (e2e, qa, mobile, perf, a11y, coverage, api, load). Runner guard, component-error rule, output envelope, and the gate options (--flaky, --changed-only) migrated from /test.
---

# Step 5 platform components — common contract

Which components run is decided by the Step 0 platform profile's resolved required-
components set (`refs/platform-profiles.md`, sourced from the `required_buckets`
column of `devkit/PLATFORMS.md` — the column's on-disk name predates this rename and
is unchanged by it) — **never hardcoded**. Each selected component runs as its own
parallel `Agent` subagent and uses the `run` command resolved for it in
`devkit/policy.json` `components[]` (detected at `--init`/`--update` by the
`preflight-check-*.sh` family); it does not re-detect.

Components: `e2e`, `qa` (visual — folded into `platform/protocol-preview.md`, C20),
`mobile`, `perf`, `a11y`, `coverage`, `api`, `load`. `load` and `perf` run **isolated**
(not overlapping other components or each other) so CPU/network contention can't skew
their timing numbers.

## Runner guard (each component's Step 1)

If the component's `<name>_runner` is `null`: emit `pass_with_warnings` with the
component's note (`"No <kind> runner detected — <name> component skipped."`) and
return. A missing runner skips the component — never `fail`. Record it as
`skipped: {reason: "no_tooling"}`.

## Component-level error rule

A runner crash, missing binary, unreachable target, or auth failure within a
component produces `pass_with_warnings` for that component — **never `fail`** — so a
broken environment can't falsely block the gate. When some targets succeed, emit the
findings that exist and set the verdict from those.

## Output envelope

Each component returns one JSON object:

```json
{ "verdict": "pass" | "pass_with_warnings" | "fail",
  "bucket": "<name>", "runner": "<runner name>", "totals": { }, "findings": [ ] }
```

(the envelope's `bucket` key is the literal wire field pre-merge's aggregation and
the `/msg --gui` board already read — unchanged this phase; see the note in
`../../shared/refs/finding-schema.md`'s `source` field.) Every entry in `findings[]`
is a **canonical finding object** (`../../shared/refs/finding-schema.md`).
`source`/`category` = the component name (prefixed `pre-merge:bucket:<name>` for
`source` per the schema — also unchanged this phase, same reason). `findings[]` is
empty on a clean pass — `pass` results belong in `totals`.

## Gate options (migrated from /test)

- **`--flaky <N>`** — for `e2e` (and unit-int at Step 3): re-run each failing spec/test up to `N` times via its `repro`, stopping on first pass. Passes-on-retry → reclassify as flaky (`severity: medium`, `evidence.flaky: true`, `evidence.retries: <n>`, counts toward `totals.flaky` not `totals.failed`). Still failing after `N` → genuine (`high`). Component `fail` only if ≥1 remains failing after retries.
- **`--changed-only`** (with a diff base) — skip a component whose surface the diff doesn't touch. UI surface (`*.tsx/*.jsx/*.vue/*.svelte/*.css`, `/components/`, `/pages/`, `/views/`, `/screens/`, Flutter `lib/**/*.dart`) gates `qa`/`a11y`/`perf`/`e2e`/`mobile`; API/backend surface (`/routes/`, `/controllers/`, `/handlers/`, `/api/`, `/server/`, `/services/`, `*.proto`, OpenAPI specs) gates `load`/`api`. **Fail open** — if the changed-file list can't be resolved, run the component. `coverage` is never surface-gated.

Per-component runner invocation, output parsing, and finding mapping live in each
component's own file.
