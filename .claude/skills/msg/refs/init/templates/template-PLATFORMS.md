---
name: PLATFORMS Template
description: Template for devkit/PLATFORMS.md — one row per shipping platform declaring rollback capability, gate tolerance profile, preview kind, preview + staging + production deploy commands, an optional staging config file, a post-deploy smoke check, and required pre-merge buckets. Read by /pre-merge Step 0 (strictness profile + bucket set) and by /post-merge (per-platform staging/production deploy pipeline + deploy verification).
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
| `rollback_possible` | `yes` (redeploy fixes it) / `no` (shipped is permanent — app-store review) / `limited` |
| `release_model` | `deploy` (synchronous — deploy-cmd exit 0 ⇒ the target is **live**; smoke the live target; rollback = redeploy) or `submission` (asynchronous — deploy-cmd exit 0 ⇒ **submitted to store review**, never "live"; the app goes live downstream, out-of-band; rollback lever = halt the rollout). Defaults by platform: web/macOS → `deploy`, iOS/Android → `submission`. Missing ⇒ post-merge **infers** it from the platform identity and **warns**, never guesses silently (AC-RM1). Every verify/rollback/lifecycle branch keys off this field. |
| `tolerance` | gate profile: `strict` / `standard` / `lenient` — drives bucket set + severity thresholds |
| `preview_kind` | `url` (deployed link) / `artifact` (installable build + poke-notes) / `screenshots` (driven before/after captures — explicit opt-down) |
| `preview_deploy_cmd` | the command `/pre-merge` Step 8 runs to produce the preview (or `[USER: …]` until filled) |
| `staging_deploy_cmd` | the command `/post-merge --staging` runs to deploy the staging environment after merging (or `[USER: …]` until filled; empty ⇒ post-merge asks or skips with a note). For a `submission` platform this is where the **internal / TestFlight track** is named — a non-placeholder value here is what `/post-merge --init` reads as the staging-readiness signal |
| `staging_config` | **optional** — a staging config file this platform's deploy needs (e.g. `.env.staging`). When a **real path** is given, `/post-merge --init` checks it exists on disk as part of staging-readiness (AC-SR2). Blank or `[USER: …]` ⇒ *not declared* — no config-file check (many platforms need none) |
| `production_deploy_cmd` | the command `/post-merge --production` runs to deploy production after the release merges (or `[USER: …]`; empty ⇒ ask/skip with a note) |
| `smoke_cmd` | the command `/post-merge` runs **after each deploy**. Its meaning depends on `release_model`: for a `deploy` platform it verifies the **live target** actually works (e.g. `curl -f <health url>`, a tiny e2e hit) and exits non-zero when broken; for a `submission` platform **nothing is live yet** (the app is in store review), so a smoke_cmd here checks **backend/build health only** and is reported as such — never as "app is live" (AC-RM3). Empty / `[USER: …]` ⇒ verification is skipped with a note (never invented). |
| `required_buckets` | comma-separated platform buckets Step 5 must run for this platform |

## Tolerance profiles (baked-in defaults)

| Profile | Buckets | Coverage | Preview gate | Applies to (default) |
|---|---|---|---|---|
| `strict` | all: e2e, qa, mobile, perf, a11y, coverage, api, load | floor **enforced** (`fail` on shortfall) | **always fires** | iOS, Android (no rollback) |
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

| platform | rollback_possible | release_model | tolerance | preview_kind | preview_deploy_cmd | staging_deploy_cmd | staging_config | production_deploy_cmd | smoke_cmd | required_buckets |
|---|---|---|---|---|---|---|---|---|---|---|
```

### web
| web | yes | deploy | lenient | url | [USER: preview deploy cmd, e.g. `vercel deploy --prebuilt`] | [USER: e.g. `npm run deploy:staging`] | [USER: optional — staging config file, e.g. `.env.staging`; blank if none] | [USER: e.g. `npm run deploy:production`] | [USER: e.g. `curl -fsS https://myapp.com/api/health`] | e2e |

### ios
| ios | no | submission | strict | artifact | [USER: e.g. `xcodebuild ... && xcrun altool --upload-app` (TestFlight)] | [USER: e.g. `fastlane beta` (TestFlight internal track — names the staging track)] | [USER: optional — staging config, e.g. `fastlane/.env.staging`; blank if none] | [USER: e.g. `fastlane release` (App Store review)] | [USER: e.g. BACKEND/BUILD HEALTH check only — the app is in store review, not live; verifies your backend or the build artifact, never app liveness, e.g. `curl -fsS https://api.myapp.com/health`] | e2e, qa, mobile, perf, a11y, coverage, api, load |

### android
| android | no | submission | strict | artifact | [USER: e.g. `./gradlew assembleRelease` (.apk / internal track)] | [USER: e.g. `./gradlew publishStaging` (Play internal track — names the staging track)] | [USER: optional — staging config, e.g. `.env.staging`; blank if none] | [USER: e.g. `./gradlew publishRelease` (Play production)] | [USER: e.g. BACKEND/BUILD HEALTH check only — the app is in store review, not live; verifies your backend or the build artifact, never app liveness, e.g. `curl -fsS https://api.myapp.com/health`] | e2e, qa, mobile, perf, a11y, coverage, api, load |

### macos
| macos | limited | deploy | standard | artifact | [USER: e.g. build signed `.app` / `.dmg`] | [USER: e.g. notarize + upload to the staging channel — names the staging channel] | [USER: optional — staging config/channel file; blank if none] | [USER: e.g. notarize + upload to the release channel] | [USER: e.g. a smoke check against the released build / update channel] | e2e, qa, a11y, coverage, api |
