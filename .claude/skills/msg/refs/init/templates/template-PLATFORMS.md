---
name: PLATFORMS Template
description: Template for devkit/PLATFORMS.md — one row per shipping platform declaring rollback capability, gate tolerance profile, preview kind, preview + staging + production deploy commands, and required pre-merge buckets. Read by /pre-merge Step 0 (strictness profile + bucket set) and by /post-merge (per-platform staging/production deploy pipeline).
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
| `tolerance` | gate profile: `strict` / `standard` / `lenient` — drives bucket set + severity thresholds |
| `preview_kind` | `url` (deployed link) / `artifact` (installable build + poke-notes) / `screenshots` (driven before/after captures — explicit opt-down) |
| `preview_deploy_cmd` | the command `/pre-merge` Step 8 runs to produce the preview (or `[USER: …]` until filled) |
| `staging_deploy_cmd` | the command `/post-merge --staging` runs to deploy the staging environment after merging (or `[USER: …]` until filled; empty ⇒ post-merge asks or skips with a note) |
| `production_deploy_cmd` | the command `/post-merge --production` runs to deploy production after the release merges (or `[USER: …]`; empty ⇒ ask/skip with a note) |
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
`production_deploy_cmd` columns to run each platform's deploy pipeline. One row
per platform. `tolerance` ∈ strict | standard | lenient; `preview_kind` ∈ url |
artifact | screenshots. A deploy cell left as `[USER: …]` or blank means "not
configured" — post-merge asks or skips that deploy with a note (it never invents
a command). See the column contract in
`.claude/skills/msg/refs/init/templates/template-PLATFORMS.md`. Missing this file →
pre-merge falls back to the `standard` profile and warns to run `/msg --init`.

| platform | rollback_possible | tolerance | preview_kind | preview_deploy_cmd | staging_deploy_cmd | production_deploy_cmd | required_buckets |
|---|---|---|---|---|---|---|---|
```

### web
| web | yes | lenient | url | [USER: preview deploy cmd, e.g. `vercel deploy --prebuilt`] | [USER: e.g. `npm run deploy:staging`] | [USER: e.g. `npm run deploy:production`] | e2e |

### ios
| ios | no | strict | artifact | [USER: e.g. `xcodebuild ... && xcrun altool --upload-app` (TestFlight)] | [USER: e.g. `fastlane beta` (TestFlight)] | [USER: e.g. `fastlane release` (App Store review)] | e2e, qa, mobile, perf, a11y, coverage, api, load |

### android
| android | no | strict | artifact | [USER: e.g. `./gradlew assembleRelease` (.apk / internal track)] | [USER: e.g. `./gradlew publishStaging` (internal track)] | [USER: e.g. `./gradlew publishRelease` (Play production)] | e2e, qa, mobile, perf, a11y, coverage, api, load |

### macos
| macos | limited | standard | artifact | [USER: e.g. build signed `.app` / `.dmg`] | [USER: e.g. notarize + upload to the staging channel] | [USER: e.g. notarize + upload to the release channel] | e2e, qa, a11y, coverage, api |
