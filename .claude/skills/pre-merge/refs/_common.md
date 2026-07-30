---
name: common
description: Shared contract for pre-merge's platform components (e2e, qa, mobile, perf, a11y, coverage, api, load). Runner guard, component-error rule, output envelope, and the gate options (--flaky, --changed-only).
---

# Platform components — common contract

Which components run is decided by the resolved pipeline (`executor.md` §1) layered
with the platform profile's required-components set (`refs/platform-profiles.md`, sourced from the `required_buckets`
column of `devkit/PLATFORMS.md` — the column's on-disk name predates this rename and
is unchanged by it) — **never hardcoded**. Each selected component runs as its own
parallel `Agent` subagent and uses the `run` command resolved for it in
`devkit/policy.json` `components[]` (detected at `--init`/`--update` by the
`preflight-check-*.sh` family); it does not re-detect.

Components: `e2e`, `mobile`, `perf`, `a11y`, `coverage`, `api`, `load`, `smoke`. `load` and `perf` run **isolated** (not overlapping other components or each other) so CPU/network contention can't skew
their timing numbers.

## Runner guard (each component's first act)

If the component's `<name>_runner` is `null`: emit `pass_with_warnings` with the
component's note (`"No <kind> runner detected — <name> component skipped."`) and
return. A missing runner skips the component — never `fail`. Record it as
`skipped: {reason: "no_tooling"}`.

## Component-level error rule

A runner crash, missing binary, unreachable target, or auth failure within a
component produces `pass_with_warnings` for that component — **never `fail`** — so a
broken environment can't falsely block the gate. When some targets succeed, emit the
findings that exist and set the verdict from those.

**One exception — an error on a surface the diff touches is graded, not whispered.**
A component that *errors out* while the diff changes exactly the surface it covers
has told you nothing about the change you are shipping, and the soft path above would
green it silently forever (a permanently broken e2e container is the worst case). So:

- The component's surface **is in the diff** (the same `--changed-only` surface map
  below) → emit **one `medium` finding**, `rule: component-errored`,
  `source: pre-merge:bucket:<name>`, message naming the component, the error, and the
  changed surface it failed to cover. The component verdict stays
  `pass_with_warnings` — this grades the blind spot, it does not fail the gate on a
  bad environment.
- The component's surface is **not** in the diff → today's soft path, unchanged: a
  note, no finding.

No new machinery: a component that errors run after run produces the same finding
each time, so `--prior-issues` marks it a regression through the ordinary
`(category, file, rule)` match, and the second occurrence reads as the standing
breakage it is.

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

- **`--flaky <N>`** — for `e2e` (and the `unit`/`integration` components): re-run each failing spec/test up to `N` times via its `repro`, stopping on first pass. Passes-on-retry → reclassify as flaky (`severity: medium`, `evidence.flaky: true`, `evidence.retries: <n>`, counts toward `totals.flaky` not `totals.failed`). Still failing after `N` → genuine (`high`). Component `fail` only if ≥1 remains failing after retries.
- **`--changed-only`** (with a diff base) — skip a component whose surface the diff doesn't touch. UI surface (`*.tsx/*.jsx/*.vue/*.svelte/*.css`, `/components/`, `/pages/`, `/views/`, `/screens/`, Flutter `lib/**/*.dart`) gates `qa`/`a11y`/`perf`/`e2e`/`mobile`; API/backend surface (`/routes/`, `/controllers/`, `/handlers/`, `/api/`, `/server/`, `/services/`, `*.proto`, OpenAPI specs) gates `load`/`api`. **Fail open** — if the changed-file list can't be resolved, run the component. `coverage` is never surface-gated.
  - **Not the same knob as `policies.test_selection`, and they compose.** `--changed-only` prunes **whole platform components** by diff surface (an untouched surface ⇒ that component doesn't run at all); minified test selection narrows **which tests run inside** `unit`/`integration`/`regression` (`../../shared/refs/policy-schema-pre-merge.md` §2c, `executor.md` §3c). Different layers, independently resolved — a run can do both, and both fail open to running more, never less.

Per-component runner invocation, output parsing, and finding mapping live in each
component's own file.
