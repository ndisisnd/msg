---
name: PLATFORMS Template
description: Template for devkit/PLATFORMS.md — one row per shipping platform declaring rollback capability, gate tolerance profile, preview kind, preview + staging + production deploy commands, an optional staging config file, a post-deploy smoke check, an executable rollback/rollout-halt lever, an optional version probe for release provenance, and required pre-merge buckets. Read by /pre-merge Step 0 (strictness profile + bucket set) and by /post-merge (per-platform staging/production deploy pipeline + deploy verification + executable rollback + release identity).
type: reference
---

# PLATFORMS Template

`devkit/PLATFORMS.md` tells `/pre-merge` how strict to be **per platform**. Step 0
of the gate reads it, resolves the `tolerance` profile, and from that picks which
platform buckets run and how severity thresholds are set. It is scaffolded by
`/msg --init` (one interview question — which platforms ship) and is idempotent:
`--init` never overwrites an existing file. Edit the rows freely afterward.

`init.sh` assembles the active table below from the `## Doc body` preamble plus one
`### <platform>` default row per shipping platform selected at the interview.

## Column contract

| Column | Meaning |
|---|---|
| `platform` | shipping target: `web` / `ios` / `android` / `macos` (add your own row for anything else) |
| `rollback_possible` | honest per-platform reversibility, drives the release-PR rollback note: `yes` (redeploy the previous build fully restores) / `limited` (a lever exists but does **not** fully un-ship — e.g. a store staged-rollout **halt** stops further exposure but the already-approved build stays out) / `no` (**IRREVERSIBLE** — an approved app-store release cannot be pulled). Defaults: web → `yes`, macOS → `limited`, **Android → `limited`** (staged-rollout halt exists — I6), **iOS → `no`** (a released build is permanent; its *phased release* can still be halted via `rollout_halt_cmd`, but the build is not recallable, so it stays `IRREVERSIBLE`-flagged). |
| `release_model` | `deploy` (synchronous — deploy-cmd exit 0 ⇒ the target is **live**; smoke the live target; rollback = redeploy) or `submission` (asynchronous — deploy-cmd exit 0 ⇒ **submitted to store review**, never "live"; the app goes live downstream, out-of-band; rollback lever = halt the rollout). Defaults by platform: web/macOS → `deploy`, iOS/Android → `submission`. Missing ⇒ post-merge **infers** it from the platform identity and **warns**, never guesses silently (AC-RM1). Every verify/rollback/lifecycle branch keys off this field. |
| `tolerance` | gate profile: `strict` / `standard` / `lenient` — drives bucket set + severity thresholds |
| `preview_kind` | `url` (deployed link) / `artifact` (installable build + poke-notes) / `screenshots` (driven before/after captures — explicit opt-down) |
| `preview_deploy_cmd` | the command `/pre-merge` Step 8 runs to produce the preview (or `[USER: …]` until filled) |
| `staging_deploy_cmd` | the command `/post-merge --staging` runs to deploy the staging environment after merging (or `[USER: …]` until filled; empty ⇒ post-merge asks or skips with a note). For a `submission` platform this is where the **internal / TestFlight track** is named — a non-placeholder value here is what `/post-merge --init` reads as the staging-readiness signal |
| `staging_config` | **optional** — a staging config file this platform's deploy needs (e.g. `.env.staging`). When a **real path** is given, `/post-merge --init` checks it exists on disk as part of staging-readiness (AC-SR2). Blank or `[USER: …]` ⇒ *not declared* — no config-file check (many platforms need none) |
| `production_deploy_cmd` | the command `/post-merge --production` runs to deploy production after the release merges (or `[USER: …]`; empty ⇒ ask/skip with a note) |
| `smoke_cmd` | the command `/post-merge` runs **after each deploy**. Its meaning depends on `release_model`: for a `deploy` platform it verifies the **live target** actually works (e.g. `curl -f <health url>`, a tiny e2e hit) and exits non-zero when broken; for a `submission` platform **nothing is live yet** (the app is in store review), so a smoke_cmd here checks **backend/build health only** and is reported as such — never as "app is live" (AC-RM3). Empty / `[USER: …]` ⇒ verification is skipped with a note (never invented). |
| `rollback_cmd` | **`deploy` model only** — the command that **restores the last-good release** (redeploy the previous artifact), e.g. `vercel rollback`, re-publish the prior appcast build. On a deploy/smoke **failure** `/post-merge` **offers to run it** via `AskUserQuestion` *before* the fix loop (always-ask, never auto — D12; AC-RB1/RB3). Empty / `[USER: …]` ⇒ no executable rollback — `/post-merge` falls back to **notes-only** and flags the gap (AC-RB2). Leave blank (`—`) for a `submission` platform — its lever is `rollout_halt_cmd`. |
| `rollout_halt_cmd` | **`submission` model only** — the command that **halts the staged rollout / phased release** (Play `--rollout 0`, App Store Connect phased-release pause). Offered via `AskUserQuestion` before the fix loop **once a rollout exists** (a `--production` submission whose track is in staged rollout / phased release; not meaningful in `--staging`'s internal track, nor for a rejected-at-upload where nothing was submitted). Halt ≠ full un-ship (the approved build stays out — this is why Android/iOS are not `rollback_possible: yes`). Empty / `[USER: …]` ⇒ notes-only + gap (AC-RB2). Leave blank (`—`) for a `deploy` platform — its lever is `rollback_cmd`. |
| `version_probe` | **optional** — a command that prints the **deployed/submitted artifact's source commit** (full or short sha), e.g. `curl -fsS https://myapp.com/version` returning the live commit, or a mobile build that echoes its embedded `GIT_COMMIT`. `/post-merge --production` runs it to **verify provenance** — that what actually shipped was built from the signed-off commit (AC-RI2): a probe sha outside the signed-off release → `fail` with a provenance finding. Blank / `[USER: …]` ⇒ **not declared** — provenance is asserted *structurally* (post-merge deployed from the merged prod branch) and recorded as unverified, never a fail. Declared-artifact style: no new probing infra, only what a platform states. |
| `required_buckets` | comma-separated platform buckets Step 5 must run for this platform |

## Tolerance profiles (baked-in defaults)

| Profile | Buckets | Coverage | Preview gate | Applies to (default) |
|---|---|---|---|---|
| `strict` | all: e2e, qa, mobile, perf, a11y, coverage, api, load | floor **enforced** (`fail` on shortfall) | **always fires** | iOS (`no` — IRREVERSIBLE), Android (`limited` — halt lever) |
| `standard` | e2e, qa, a11y, coverage, api | floor advisory (`medium`) | fires on UI / API / schema paths | macOS |
| `lenient` | e2e (+ unit-int smoke, always) | advisory only | fires **only** on visual diffs | Web (continuous redeploy) |

The **safety floor runs in every profile** regardless of tolerance — security,
migration, and every human gate (preview approval, staging sign-off, production
double-confirm) are never relaxed. Tolerance only moves bucket selection and
severity thresholds.

## Doc body

```
# PLATFORMS — Pre-merge tolerance profiles

`/pre-merge` reads this file (Step 0) to pick a strictness profile and bucket set
per shipping platform; `/post-merge` reads the `staging_deploy_cmd` /
`production_deploy_cmd` columns to run each platform's deploy pipeline, then — per
the platform's `release_model` — either smokes the live target (`deploy`) or
records the submission and reports backend/build health (`submission`). One row
per platform. `release_model` ∈ deploy | submission (default: web/macOS →
`deploy`, iOS/Android → `submission`; missing ⇒ inferred from the platform with a
warn); `tolerance` ∈ strict | standard | lenient; `preview_kind` ∈ url |
artifact | screenshots. A deploy or smoke cell left as `[USER: …]` or blank means
"not configured" — post-merge asks or skips that deploy (and skips verification)
with a note; it never invents a command. See the column contract in
`.claude/skills/msg/refs/init/templates/template-PLATFORMS.md`. Missing this file →
pre-merge falls back to the `standard` profile and warns to run `/msg --init`.

| platform | rollback_possible | release_model | tolerance | preview_kind | preview_deploy_cmd | staging_deploy_cmd | staging_config | production_deploy_cmd | smoke_cmd | rollback_cmd | rollout_halt_cmd | version_probe | required_buckets |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
```

`rollback_cmd` / `rollout_halt_cmd` are **mutually exclusive per platform** by
release model: a `deploy` platform fills `rollback_cmd` and leaves `rollout_halt_cmd`
blank (`—`); a `submission` platform fills `rollout_halt_cmd` and leaves
`rollback_cmd` blank (`—`). `version_probe` is optional on any platform.

### web
| web | yes | deploy | lenient | url | [USER: preview deploy cmd, e.g. `vercel deploy --prebuilt`] | [USER: e.g. `npm run deploy:staging`] | [USER: optional — staging config file, e.g. `.env.staging`; blank if none] | [USER: e.g. `npm run deploy:production`] | [USER: e.g. `curl -fsS https://myapp.com/api/health`] | [USER: e.g. `vercel rollback` or redeploy the previous build — restores last-good] | — | [USER: optional — prints the live commit, e.g. `curl -fsS https://myapp.com/version`; blank ⇒ structural-only provenance] | e2e |

### ios
| ios | no | submission | strict | artifact | [USER: e.g. `xcodebuild ... && xcrun altool --upload-app` (TestFlight)] | [USER: e.g. `fastlane beta` (TestFlight internal track — names the staging track)] | [USER: optional — staging config, e.g. `fastlane/.env.staging`; blank if none] | [USER: e.g. `fastlane release` (App Store review)] | [USER: e.g. BACKEND/BUILD HEALTH check only — the app is in store review, not live; verifies your backend or the build artifact, never app liveness, e.g. `curl -fsS https://api.myapp.com/health`] | — | [USER: e.g. `fastlane pause_phased_release` — halts the App Store phased release (build stays out, IRREVERSIBLE)] | [USER: optional — prints the built artifact's commit/build; blank ⇒ structural-only provenance] | e2e, qa, mobile, perf, a11y, coverage, api, load |

### android
| android | limited | submission | strict | artifact | [USER: e.g. `./gradlew assembleRelease` (.apk / internal track)] | [USER: e.g. `./gradlew publishStaging` (Play internal track — names the staging track)] | [USER: optional — staging config, e.g. `.env.staging`; blank if none] | [USER: e.g. `./gradlew publishRelease` (Play production)] | [USER: e.g. BACKEND/BUILD HEALTH check only — the app is in store review, not live; verifies your backend or the build artifact, never app liveness, e.g. `curl -fsS https://api.myapp.com/health`] | — | [USER: e.g. `fastlane supply --track production --rollout 0` — halts the staged rollout] | [USER: optional — prints the built artifact's commit/build; blank ⇒ structural-only provenance] | e2e, qa, mobile, perf, a11y, coverage, api, load |

### macos
| macos | limited | deploy | standard | artifact | [USER: e.g. build signed `.app` / `.dmg`] | [USER: e.g. notarize + upload to the staging channel — names the staging channel] | [USER: optional — staging config/channel file; blank if none] | [USER: e.g. notarize + upload to the release channel] | [USER: e.g. a smoke check against the released build / update channel] | [USER: e.g. re-publish the previous appcast item / re-upload the prior signed build] | — | [USER: optional — prints the shipped build's commit; blank ⇒ structural-only provenance] | e2e, qa, a11y, coverage, api |
