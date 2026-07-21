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

## Smoke-verification failure finding

A deploy that succeeds but fails its `smoke_cmd` emits the same canonical shape
with `rule: "smoke-failed"` — full example and consequences in
`refs/verify-deploy.md`. The clean-run summary's `verify` block records the
outcome either way: `ran: false` / `passed: null` when nothing was configured,
`passed: false` alongside the finding on a failure, `skipped` listing platforms
with no usable `smoke_cmd`.

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
