---
name: merge-output-schema
description: What merge emits — a clean run's summary, and the canonical findings it raises on a deploy failure, a smoke failure, a macOS release-check failure, a provenance mismatch or a test-selection miss. Findings conform to shared/refs/finding-schema.md with source `merge`.
---

# Output Schema

Merge's primary artifact is its **run report**
(`../shared/refs/report-schema.md`, `skill: merge`). It additionally emits
structured JSON in two cases: a refusal (`refs/refusal-patterns.md`) and a
failure (a canonical finding).

Every block below is **additive**: fields are only ever added, never renamed or
reshaped, and a reader that predates a block simply does not see it. That rule
holds for the whole file and is not restated per block.

## Clean-run summary (printed on success)

```json
{
  "verdict": "pass",
  "mode": "staging" | "production",
  "prd_paths": ["features/prd-101-task-crud/prd-101-task-crud.md"],
  "merged_pr": "<pr url>",
  "merge_commit": "<sha>",
  "deploy": { "ran": true, "target": "<url/build id>", "skipped": [] },
  "verify": { "ran": true, "passed": true, "skipped": [] },
  "platforms": [
    { "platform": "web", "release_model": "deploy",     "outcome": "deployed" },
    { "platform": "ios", "release_model": "submission", "outcome": "submitted",
      "track": "App Store review (Waiting for Review)",
      "submitted_at": "2026-07-21T11:07:18Z",
      "monitor": "App Store Connect",
      "live_status": "handed_off" }
  ],
  "staging_signoff": "2026-07-13@4f2c9a1e8b7d6c5a4938271605f4e3d2c1b0a9f8",
  "release_identity": {                 // --production only
    "version": "2.3.0",
    "build": 418,
    "tag": "v2.3.0+418",                // null on a failed/skipped tag
    "bump": "minor"                     // "major" | "minor" | "patch" | "explicit"
  },
  "release_lock": {                     // --production only
    "ref": "release-lock-main",
    "acquired": true,
    "acquired_at": "2026-07-21T11:07:18Z",
    "released": true,
    "released_at": "2026-07-21T11:14:02Z"
  },
  "report": "features/prd-101-.../reports/report-3.md"
}
```

`verify`: `ran:false` / `passed:null` when nothing was configured; `passed:false`
alongside the finding on a failure; `skipped` lists platforms with no usable
`smoke_cmd`.

### `platforms[]`

| `outcome` | Meaning | Applies to |
|---|---|---|
| `deployed` | the target is live and (if smoked) verified | `deploy` model |
| `submitted` | the artifact was submitted to its store track — **never** "live"; `track` names the target | `submission` model |
| `skipped` | no deploy command configured | either |

A `submission` entry additionally carries:

| Field | Meaning |
|---|---|
| `track` | the store track submitted to (e.g. `App Store review (Waiting for Review)`, `Mac App Store review (Waiting for Review)`, `Play production (staged rollout 10%, pending review)`) |
| `submitted_at` | ISO-8601 timestamp of the accepted submit |
| `monitor` | the console for the handoff (`App Store Connect` / `Google Play Console`) |
| `live_status` | the polling seam: defaults to **`handed_off`**, which is what merge always emits — it does not poll. Reserved values for a future store-status poll — `processing` \| `in_review` \| `rejected` \| `rolling_out` \| `live`. Readers treat an unknown value as opaque and **absence as `handed_off`** |

On a `--production` run each entry may also carry:

| Field | Meaning |
|---|---|
| `build_number` | the build derived for this release (all platforms share `release_identity.build`) — surfaced per platform because stores gate on it |
| `provenance` | `verified` \| `asserted_unverified` \| `fail` (a probe reported a commit **outside** this release's window — drives verdict `fail`) |
| `smoke` | how the v2 smoke contract ran (below) |
| `rollback` | the failed-ship rollback offer (below) |

**Smoke** (`refs/verify-deploy.md` § *Smoke contract v2*):

```json
"smoke": { "mode": "one_shot", "attempts": 1, "window": null }
```

| Field | Meaning |
|---|---|
| `mode` | `one_shot` (bare `smoke_cmd`) · `poll` (waited for a late-live target) · `watch` (re-checked health over a window) · `poll+watch` |
| `attempts` | total `cmd` invocations: `1` for one-shot; `1 + poll-retries`; `1 + watch-re-checks`; summed when composed |
| `window` | `held` (every re-check passed) · `degraded` (a re-check failed → `smoke-failed`, routes to the rollback offer) · `timed_out` (a poll never saw exit 0 → `smoke-never-live`) · `null` (one-shot) |

**Rollback** — present only when a lever was offered on a failed ship
(`SKILL.md` § *Failed-ship loop*):

```json
"rollback": {
  "offered": true,
  "lever": "rollback_cmd",         // "rollback_cmd" | "rollout_halt_cmd" | null
  "approved": false,               // never auto — false = declined / autonomy-default
  "cmd_exit": null,
  "outcome": "declined"
}
```

| `outcome` | Meaning |
|---|---|
| `rolled_back` | `rollback_cmd` ran, exit 0 — last-good restored |
| `halted` | `rollout_halt_cmd` ran, exit 0 — staged rollout / phased release halted |
| `declined` | offered, human said no (or autonomy-default-decline) — the fix loop still runs |
| `unconfigured_gap` | no lever configured — notes-only, flagged as a gap |
| `failed` | the lever ran but exited non-zero — surfaced with its `cmd_exit` |

### `release_lock`

Recorded straight from `script-release-lock.sh`'s keys
(`refs/production.md` § *Release lock*).

| Field | Meaning |
|---|---|
| `ref` | the lock tag, `release-lock-<prod>` |
| `acquired` | did **this** run acquire it. `false` only on the infra-error fail-open |
| `acquired_at` | ISO-8601 acquire time; `null` when not acquired |
| `released` | `true` on every graceful exit — success, failed ship (released at ship-terminal, before the fix-loop handoff), refusal-after-acquire; `false` **only** on a hard process kill, which the TTL + manual unlock reclaim |
| `released_at` | when this run released it; `null` if never acquired or still held |

This block carries **no `stale_detected` field**. A run that *held* the lock
cleanly never met a stale one — had it, it would have refused. Stale detection
lives in the `release_in_flight` refusal's `lock` block
(`refs/refusal-patterns.md`): the clean-run block belongs to the run that **held**
the lock, the refusal's block to the run that was **blocked**.

## Deploy-failure finding

A non-zero deploy exit does not un-merge anything, so merge surfaces it as a
finding rather than swallowing it. Conforms to
`../shared/refs/finding-schema.md`:

```json
{
  "id": "deploy-001",
  "source": "merge",
  "severity": "high",
  "category": "deploy",
  "rule": "<mode>_deploy_cmd exited non-zero",
  "message": "Staging deploy for web failed (exit 1)",
  "file": null,
  "line": null,
  "evidence": {
    "tool": "merge",
    "snippet": "<last lines of the deploy log — redact secrets>"
  },
  "suggestion": "Check the deploy target's credentials/config; re-run the deploy command.",
  "repro": "<the exact staging_deploy_cmd / production_deploy_cmd>",
  "regression_of": null
}
```

`category: deploy` covers deploy failures; a refusal uses the refusal JSON shape
instead (it carries no findings).

## Smoke-verification failure findings

Same canonical shape; consequences in `refs/verify-deploy.md`. All
`category: deploy`, `severity: high`, verdict `fail`:

| `rule` | When |
|---|---|
| `smoke-failed` | the first-verdict `cmd` exited non-zero, **or** a `watch_window` re-check degraded after an initial pass (`window: "degraded"`) — the target is up but unhealthy |
| `smoke-never-live` | a `poll` ran to its timeout without a single exit 0 (`window: "timed_out"`) — the target **never came up within the bounded wait**, a different diagnosis than *up-but-broken* |

## macOS release-check findings (`deploy` model)

A directly-distributed macOS platform carries three config-gated checks
(`refs/verify-deploy.md` § *macOS release checks*). Undeclared ⇒ nothing runs and
nothing is flagged. When declared and failing, each emits a **distinct, specific**
finding — never a generic deploy failure — all `source: merge`,
`category: deploy`, `severity: high`, verdict `fail`:

| `rule` | Check | Fires when |
|---|---|---|
| `notarization-stall` | notarization (`notarize_status_cmd`, polled) | still non-terminal (`In Progress`) at the poll ceiling — a **stall**, distinct from a reject and from a build break |
| `notarization-invalid` | notarization | the notary reached a terminal `Invalid` / `Rejected` status |
| `signing-fail` | signing / Gatekeeper (`signing_smoke_cmd`) | `spctl --assess` / `codesign --verify` rejected the artifact — the shipped `.app` will not open on a user's Mac |
| `appcast-stale` | appcast (`appcast_url`) | the Sparkle feed is unreachable **or** missing the release's `NEXT_VERSION` — the update channel did not publish |

Canonical shape (notarization-stall shown; the others differ only in `rule` /
`message` / `repro`):

```json
{
  "id": "notarize-001",
  "source": "merge",
  "severity": "high",
  "category": "deploy",
  "rule": "notarization-stall",
  "message": "macOS notarization did not reach a terminal status within 10m (last: In Progress, submission 7b1d4c30-99aa-4e21-b7f3-1c2d3e4f5a6b)",
  "file": null,
  "line": null,
  "evidence": {
    "tool": "merge",
    "snippet": "<last lines of the notarize_status_cmd output — the `status:` line>"
  },
  "suggestion": "Notarization is stalled, not failed — re-poll `xcrun notarytool info <id>` or check Apple's notary service status; the failed-ship loop offers the deploy rollback (re-publish the prior appcast build) before the fix loop.",
  "repro": "<the exact notarize_status_cmd>",
  "regression_of": null
}
```

The notarization async shape mirrors a `submission`'s *processing* state
(`refs/submission.md`) — the vocabulary (submit → processing → terminal) and the
poll primitive are shared, not re-invented.

## Provenance-failure finding (`--production`)

A declared `version_probe` reporting a commit **outside** this release's window
emits the canonical shape with `category: deploy`,
`rule: "provenance-mismatch"`, `severity: high` — the artifact that shipped was
built from a commit no human certified (`refs/release-identity.md`). Sets verdict
`fail` and skips the intake stamp, the tag and the `done` transition. No probe →
no finding; provenance is recorded as `asserted_unverified`.

## Test-selection-miss finding (`--staging`, policy-conditional)

Only emitted when `policies.test_selection.enabled` resolves `true`
(`../shared/refs/policy-schema-pre-merge.md` §2c) and the backstop's full run
fails a test pre-merge's minified verdict **selected away**. The detection
contract lives in `refs/staging.md` § *Test-selection-miss detection*; this is its
wire shape:

```json
{
  "id": "ts-miss-001",
  "source": "merge",
  "severity": "high",
  "category": "unit",
  "rule": "test-selection-miss",
  "message": "tests/unit/taskController.test.ts › applies stale-write guard failed on the ci backstop after pre-merge's minified run selected it away",
  "file": "tests/unit/taskController.test.ts",
  "line": null,
  "evidence": {
    "tool": "merge",
    "snippet": "unit: minified (42/731, tier S) — excluded: not-affected"
  },
  "suggestion": "Tag this test critical and run `/pre-merge --update-criticality`, or disable selection with `/msg --update`.",
  "repro": "<the exact failing CI check name, or the staging re-test command>",
  "regression_of": null
}
```

- `category` mirrors the test's owning component where the vocabulary has a slot
  (`unit`/`integration`). **A `regression`-component miss uses `other` —
  deliberately.** The category enum in `../shared/refs/finding-schema.md` is
  **closed** (its only sanctioned extension point is documented extra keys inside
  `evidence`), and it has no `regression` member; adding one would change a shared
  enum every consumer switches on. The owning component is carried losslessly in
  `rule` + `evidence.snippet`, so the miss stays fully attributable.
- `evidence.snippet` quotes the exact `test_selection.per_check` pipeline suffix
  showing the component ran minified and what excluded this test — the audit trail
  that makes the miss attributable, never asserted from memory.
- Two or more of these findings inside 30 days adds one report line recommending
  `/pre-merge --update-criticality` or `/msg --update`, and names this finding's
  `file` as a `force_full_paths` candidate — mechanism owned by `refs/staging.md`.
- Additive to whatever refusal/finding already covers the backstop failure itself
  (`red_ci`, a failed staging sign-off); it never substitutes for it and never
  turns a clean run non-clean on its own.

## Verdict values

| Verdict | Meaning | Exit |
|---|---|---|
| `pass` | merged (+ deployed or deploy-skipped-with-note, + smoke verified or verify-skipped-with-note, + provenance verified/asserted, + tagged) | 0 |
| `fail` | merged but a deploy errored, failed its smoke check, or failed provenance (finding emitted) — no tag cut | 1 |
| `refused` | a precondition/gate blocked before the sanctioned action (incl. `nonmonotonic_build` before a submission's submit) | 1 |
| `skipped` | a human cancelled at a gate | 0 |
