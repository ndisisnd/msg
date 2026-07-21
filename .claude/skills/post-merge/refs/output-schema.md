---
name: post-merge-output-schema
description: What post-merge emits — a clean run's summary, and the canonical finding it raises on a deploy failure or refusal. Findings conform to shared/refs/finding-schema.md with source `post-merge`.
---

# Output Schema

Post-merge's primary artifact is its **run report** (`../shared/refs/report-schema.md`,
`skill: post-merge`). It additionally emits structured JSON in two cases: a
refusal (`refs/refusal-patterns.md`) and a deploy failure (a canonical finding).

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
  "platforms": [                        // ADDITIVE (C1/C5/CV2/AC-CONTRACT1) — per-platform release model + outcome; absent on pre-C1 runs
    { "platform": "web", "release_model": "deploy",     "outcome": "deployed" },   // deploy model: exit 0 ⇒ live
    { "platform": "ios", "release_model": "submission", "outcome": "submitted",    // submission model: exit 0 ⇒ submitted, never "live"
      "track": "App Store review (Waiting for Review)",                            // C5 lifecycle fields (additive)
      "submitted_at": "2026-07-21T11:07:18Z",
      "monitor": "App Store Connect",                                             // console name for the handoff
      "live_status": "handed_off" }                                              // AC-SB5 polling seam; default "handed_off"
  ],
  "staging_signoff": "2026-07-13@4f2c9a1e8b7d6c5a4938271605f4e3d2c1b0a9f8",  // <date>@<certified sha>; --staging only, on approval; null otherwise
  "release_identity": {                 // ADDITIVE (C4/CV2) — --production only; absent on --staging & pre-C4 runs
    "version": "2.3.0",                 // resolved next version (default minor bump from the last v* tag on prod)
    "build": 418,                       // commit count on prod at release — monotonic by construction
    "tag": "v2.3.0+418",                // cut on prod ONLY on a successful release (Step 9); null on a failed/skipped tag
    "bump": "minor"                     // "major" | "minor" (default) | "patch" | "explicit"
  },
  "release_lock": {                     // ADDITIVE (C8/P5/CV2) — --production only; absent on --staging & pre-P5 runs
    "ref": "release-lock-main",         // the lock tag (release-lock-<prod>)
    "acquired": true,                   // did THIS run acquire the lock (false on infra-error fail-open)
    "acquired_at": "2026-07-21T11:07:18Z",  // tagger date of the acquire; null if not acquired
    "released": true,                   // released at termination; false ONLY on a hard-kill dangle (TTL then reclaims)
    "released_at": "2026-07-21T11:14:02Z",  // when this run released it; null if still held / never acquired
    "stale_detected": false             // true when a prior stale lock (age > TTL) was reported to the human this run
  },
  "report": "features/prd-101-.../reports/report-3.md"
}
```

**`platforms[]` — additive per-platform release-model surface (C1).** New fields
only — nothing above is renamed or reshaped (CV2/AC-CONTRACT1). Each entry carries
the resolved `release_model` (`deploy` | `submission`) and an `outcome`:

| `outcome` | Meaning | Applies to |
|---|---|---|
| `deployed` | the target is live and (if smoked) verified | `deploy` model |
| `submitted` | the artifact was submitted to its store track — **never** "live" (AC-RM3/AC-SB1); `track` names the target | `submission` model |
| `skipped` | no deploy command configured | either |

A `submission` entry additionally carries the C5 lifecycle fields, all **additive**
— none renames or reshapes the fields above (CV2/AC-CONTRACT1):

| Field | Meaning |
|---|---|
| `track` | the store track the artifact was submitted to (e.g. `App Store review (Waiting for Review)`, `Play production (staged rollout 10%, pending review)`) |
| `submitted_at` | ISO-8601 timestamp of the accepted submit |
| `monitor` | the console name for the handoff (`App Store Connect` / `Google Play Console`) — the human pointer, AC-SB3 |
| `live_status` | the **polling seam** (AC-SB5): defaults to **`handed_off`**; v4 always emits this (post-merge does not poll, D2). Reserved values for v4.1 store-status polling — `processing` \| `in_review` \| `rejected` \| `rolling_out` \| `live` — can populate it **without a breaking change**. Readers treat an unknown value as opaque and **absence as `handed_off`**. |

`deploy` entries carry none of these — they are `submission`-only, so a
`deploy`-model reader is unaffected.

**Release-identity per-platform fields (C4/CV2/AC-CONTRACT1 — additive).** On a
`--production` run each `platforms[]` entry may additionally carry (all optional,
absent on `--staging` and pre-C4 runs):

| Field | Meaning |
|---|---|
| `build_number` | the build derived for this release (all platforms share the repo-wide `release_identity.build`) — surfaced per platform because stores gate on it |
| `provenance` | `verified` (a `version_probe` reported a commit inside the signed-off release), `asserted_unverified` (no `version_probe` declared — structural assertion only), or `fail` (probe reported a commit **outside** the signed-off release — AC-RI2; drives verdict `fail`) |

**Rollback-offer fields (C3/CV2/AC-CONTRACT1 — additive, failed-ship only).** On a
failed ship, each failing `platforms[]` entry carries a `rollback` object recording
the always-ask offer (`SKILL.md` § *Failed-ship loop* step 1) — present only when a
rollback was offered, absent on a clean run:

```json
"rollback": {
  "offered": true,                 // was the lever offered (a configured rollback_cmd / rollout_halt_cmd)
  "lever": "rollback_cmd",         // "rollback_cmd" (deploy) | "rollout_halt_cmd" (submission) | null (unconfigured → notes-only gap, AC-RB2)
  "approved": false,               // did the human approve running it (never auto — D12); false = declined / autonomy-default-decline
  "cmd_exit": null,                // the lever's exit code when approved+run; null when declined or unconfigured
  "outcome": "declined"            // "rolled_back" | "halted" | "declined" | "unconfigured_gap" | "failed" (lever ran non-zero)
}
```

| `outcome` | Meaning |
|---|---|
| `rolled_back` | `deploy` platform: `rollback_cmd` ran, exit 0 — last-good restored |
| `halted` | `submission` platform: `rollout_halt_cmd` ran, exit 0 — staged rollout / phased release halted |
| `declined` | offered, human said no (or autonomy-default-decline) — the fix loop still runs (AC-RB3) |
| `unconfigured_gap` | no lever configured — notes-only, flagged as a gap (AC-RB2) |
| `failed` | the lever ran but exited non-zero — surfaced with its `cmd_exit` |

**Smoke v2 fields (C7/CV2/AC-CONTRACT1 — additive).** Each `platforms[]` entry
carries the smoke verification mode, recording how the v2 contract ran
(`refs/verify-deploy.md` § *Smoke contract v2*). All additive — a bare one-shot
smoke emits the defaults below, so a pre-v2 reader is unaffected (AC-SM1):

```json
"smoke": {
  "mode": "one_shot",      // "one_shot" | "poll" | "watch" | "poll+watch"
  "attempts": 1,           // how many times `cmd` ran (poll retries + watch re-checks + 1)
  "window": null           // "held" | "degraded" | "timed_out" | null (one-shot / no window)
}
```

| Field | Meaning |
|---|---|
| `mode` | `one_shot` (bare `smoke_cmd`, AC-SM1) · `poll` (waited for a late-live target, AC-SM3) · `watch` (re-checked health over a window, AC-SM2) · `poll+watch` (both — poll then watch) |
| `attempts` | total `cmd` invocations: `1` for one-shot; `1 + poll-retries`; `1 + watch-re-checks`; summed when composed |
| `window` | `held` (every watch re-check passed) · `degraded` (a watch re-check failed → `smoke-failed`, routes to the rollback offer) · `timed_out` (a poll never saw exit 0 within the bound → `smoke-never-live`) · `null` (one-shot, or poll-that-passed with no watch declared) |

**Release-lock fields (C8/CV2/AC-CONTRACT1 — additive, `--production` only).** The
`release_lock` block (above) records the concurrency lock's per-run state
(`refs/production.md` § *Release lock*, `../shared/refs/policy-schema.md` §6). All
additive — absent on `--staging` and pre-P5 runs, so no existing reader is affected:

| Field | Meaning |
|---|---|
| `ref` | the lock tag name, `release-lock-<prod>` (e.g. `release-lock-main`) |
| `acquired` | did **this** run acquire the lock. `false` only on the infra-error fail-open (a non-contention push error → proceed without the guard, one `low` note) |
| `acquired_at` | ISO-8601 tagger date of the acquire; `null` when not acquired |
| `released` | did this run release it at termination (AC-LK2). `true` on every graceful exit — success, failed ship, refusal-after-acquire; `false` **only** on a hard process kill, which the 2h TTL + manual unlock then reclaim |
| `released_at` | when this run released it; `null` if never acquired or still held |
| `stale_detected` | `true` when a **prior** stale lock (age > 2h TTL) was surfaced to the human with the manual-unlock instruction this run (CV1 escape hatch) |

A **contended** acquire does not produce this block — it produces the
`release_in_flight` **refusal** instead (its own `lock` block names the holder,
`refs/refusal-patterns.md`). The clean-run `release_lock` block is for the run that
**held** the lock; the refusal's `lock` block is for the run that was **blocked**.

## Deploy-failure finding

A non-zero deploy exit does not un-merge anything — the merge already happened —
so post-merge surfaces it as a finding rather than swallowing it. Conforms to
`../shared/refs/finding-schema.md` (the same object every gate stage emits):

```json
{
  "id": "deploy-001",
  "source": "post-merge",
  "severity": "high",
  "category": "deploy",
  "rule": "<mode>_deploy_cmd exited non-zero",
  "message": "Staging deploy for web failed (exit 1)",
  "file": null,
  "line": null,
  "evidence": {
    "tool": "post-merge",
    "snippet": "<last lines of the deploy log — redact secrets>"
  },
  "suggestion": "Check the deploy target's credentials/config; re-run the deploy command.",
  "repro": "<the exact staging_deploy_cmd / production_deploy_cmd>",
  "regression_of": null
}
```

- `source` is `post-merge` (the value added to the finding-schema source enum in P5).
- `category: deploy` is used for deploy failures; a refusal uses the refusal JSON shape instead (it carries no findings).

## Smoke-verification failure finding (incl. v2 verdicts)

A deploy that succeeds but fails its smoke emits the same canonical shape — full
example and consequences in `refs/verify-deploy.md`. The v2 contract adds two
**distinct** failure rules alongside the plain one; all `category: deploy`,
`severity: high`, verdict `fail`:

| `rule` | When (v2, `refs/verify-deploy.md` § *Smoke contract v2*) |
|---|---|
| `smoke-failed` | the first-verdict `cmd` ran and exited non-zero (one-shot or the first poll pass), **or** a `watch_window` re-check degraded after an initial pass (`window: "degraded"`) — the target is up but unhealthy |
| `smoke-never-live` | a `poll` ran to its `<timeout>` without a single exit 0 (`window: "timed_out"`) — the target **never came up within the bounded wait**; a different diagnosis than *up-but-broken*, so a distinct rule (AC-SM3) |

The clean-run summary's `verify` block records the outcome either way: `ran: false`
/ `passed: null` when nothing was configured, `passed: false` alongside the finding
on a failure, `skipped` listing platforms with no usable `smoke_cmd`. The
per-platform `smoke: {mode, attempts, window}` object (above) records which v2 mode
ran.

## macOS release-check findings (`--staging` / `--production`, C6, `deploy` model)

macOS (`release_model: deploy`) carries three config-gated checks
(`refs/verify-deploy.md` § *macOS release checks*). Each undeclared surface runs
**nothing** and emits **no finding** (D13). When declared and failing, each emits a
**distinct, specific** finding — never a generic deploy failure (AC-MAC1) — all
`source: post-merge`, `category: deploy`, `severity: high`, verdict `fail`, routed
through the same failed-ship loop (rollback offer before the fix loop):

| `rule` | Check | Fires when | AC |
|---|---|---|---|
| `notarization-stall` | notarization (`notarize_status_cmd`, polled via the C7 poll primitive) | the notary status is still non-terminal (`In Progress`) at the poll ceiling — a **stall**, distinct from a reject and from a build break (the P0 finding #4 defect) | AC-MAC1 |
| `notarization-invalid` | notarization | the notary reached a terminal `Invalid` / `Rejected` status | AC-MAC1 |
| `signing-fail` | signing / Gatekeeper (`signing_smoke_cmd`) | `spctl --assess` / `codesign --verify` rejected the built artifact — the shipped `.app` will not open on a user's Mac | AC-MAC2 |
| `appcast-stale` | appcast (`appcast_url`) | the Sparkle feed is unreachable **or** missing the release-identity `NEXT_VERSION` — the update channel did not publish the new version | AC-MAC3 |

Canonical shape (notarization-stall shown; the others differ only in `rule` /
`message` / `repro`):

```json
{
  "id": "notarize-001",
  "source": "post-merge",
  "severity": "high",
  "category": "deploy",
  "rule": "notarization-stall",
  "message": "macOS notarization did not reach a terminal status within 10m (last: In Progress, submission 7b1d4c30-99aa-4e21-b7f3-1c2d3e4f5a6b)",
  "file": null,
  "line": null,
  "evidence": {
    "tool": "post-merge",
    "snippet": "<last lines of the notarize_status_cmd output — the `status:` line>"
  },
  "suggestion": "Notarization is stalled, not failed — re-poll `xcrun notarytool info <id>` or check Apple's notary service status; the failed-ship loop offers the deploy rollback (re-publish the prior appcast build) before the fix loop.",
  "repro": "<the exact notarize_status_cmd>",
  "regression_of": null
}
```

The notarization async shape **mirrors a `submission`'s *processing* state**
(`refs/submission.md`) — the vocabulary (submit → processing → terminal) and the
poll primitive are shared, not re-invented.

## Provenance-failure finding (`--production`, C4/AC-RI2)

A declared `version_probe` reporting a commit **outside** the signed-off release
(not the certified sha, not an ancestor of prod) emits the canonical shape with
`category: deploy`, `rule: "provenance-mismatch"`, `severity: high` — the artifact
that shipped was built from a commit no human certified (`refs/release-identity.md`).
Sets verdict `fail` and skips the intake stamp (Step 8) and the release tag
(Step 9). No `version_probe` declared → no finding; provenance is recorded as
`asserted_unverified` in the platform entry, never a fail.

## Verdict values

| Verdict | Meaning | Exit |
|---|---|---|
| `pass` | merged (+ deployed or deploy-skipped-with-note, + smoke verified or verify-skipped-with-note, + provenance verified/asserted, + tagged) | 0 |
| `fail` | merged but a deploy errored, failed its smoke check, or failed provenance (finding emitted) — no tag cut | 1 |
| `refused` | a precondition/gate blocked before the sanctioned action (incl. `nonmonotonic_build` before a submission submit) | 1 |
| `skipped` | a human cancelled at a gate | 0 |
