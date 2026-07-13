---
name: PLATFORMS Template
description: Template for devkit/PLATFORMS.md — one row per shipping platform declaring rollback capability, gate tolerance profile, preview kind, deploy command, and required pre-merge buckets. Read by /pre-merge Step 0 to resolve the strictness profile + bucket set.
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
per shipping platform. One row per platform. `tolerance` ∈ strict | standard |
lenient; `preview_kind` ∈ url | artifact | screenshots. See the column contract in
`.claude/skills/msg/refs/init/templates/template-PLATFORMS.md`. Missing this file →
pre-merge falls back to the `standard` profile and warns to run `/msg --init`.

| platform | rollback_possible | tolerance | preview_kind | preview_deploy_cmd | required_buckets |
|---|---|---|---|---|---|
```

### web
| web | yes | lenient | url | [USER: preview deploy cmd, e.g. `vercel deploy --prebuilt`] | e2e |

### ios
| ios | no | strict | artifact | [USER: e.g. `xcodebuild ... && xcrun altool --upload-app` (TestFlight)] | e2e, qa, mobile, perf, a11y, coverage, api, load |

### android
| android | no | strict | artifact | [USER: e.g. `./gradlew assembleRelease` (.apk / internal track)] | e2e, qa, mobile, perf, a11y, coverage, api, load |

### macos
| macos | limited | standard | artifact | [USER: e.g. build signed `.app` / `.dmg`] | e2e, qa, a11y, coverage, api |
