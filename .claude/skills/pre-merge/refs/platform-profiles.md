---
name: platform-profiles
description: Gate Step 0 — resolve the strictness profile + component set from devkit/PLATFORMS.md. Maps each shipping platform's tolerance to required components and severity thresholds; the safety floor runs in every profile.
---

# Step 0 — Platform-mode resolution

Read `devkit/PLATFORMS.md` and resolve, for this run, a **strictness profile** →
which platform components Step 5 runs and how severity thresholds are set.
Component selection and thresholds vary by profile; the **safety floor never does**.

## Read + fallback

1. Read `devkit/PLATFORMS.md`. Parse the pipe table (`platform | rollback_possible | tolerance | preview_kind | preview_deploy_cmd | staging_deploy_cmd | production_deploy_cmd | required_buckets`) — the last column's on-disk name (`required_buckets`) predates this refactor's terminology rename and is unchanged by it; everywhere below it is called the **required-components** column/set. Pre-merge only consumes the strictness/preview columns; `staging_deploy_cmd` / `production_deploy_cmd` are `/post-merge`'s (ignore them here).
2. **Missing file** → fall back to the `standard` profile and emit a warning: `"No devkit/PLATFORMS.md — using the standard profile. Run /msg --init to scaffold per-platform tolerance."` Continue; do not refuse.
3. **Multiple rows** (multi-platform repo): resolve the **union** of every row's required-components set, and take the **strictest** `tolerance` present (`strict` > `standard` > `lenient`) for threshold purposes. Each row's `preview_kind` / `preview_deploy_cmd` is carried per-platform into Step 8 (a strict platform still gets its artifact preview even alongside a lenient web row).

## Profiles

| Profile | Components run (Step 5) | Coverage floor | Severity thresholds | Preview gate (Step 8) |
|---|---|---|---|---|
| `strict` | e2e, qa, mobile, perf, a11y, coverage, api, load | **enforced** — shortfall is a `high` finding → `fail` | as-emitted (no downgrade) | **always fires** |
| `standard` | e2e, qa, a11y, coverage, api | advisory — shortfall is `medium` | as-emitted | fires on the D6 path heuristic (UI / API / schema) |
| `lenient` | e2e (unit-int smoke always runs at Step 3) | advisory — shortfall is `low` | non-security findings outside the diff downgrade one extra level | fires **only** on visual-diff paths |

The row's required-components set (the `required_buckets` column) **overrides** the
profile's default component list — the column is authoritative; the profile default
is used only when a row omits it. Components with no detected runner are skipped
(`no_tooling`) regardless of profile.

## Safety floor — every profile, never relaxed

Independent of tolerance, these always run and always gate:

- **Security** stage (Step 6) — secret scan + SAST.
- **Migration** stage (Step 6) — static SQL-safety scan when the diff touches migrations.
- **Human gates** — preview-deploy approval (Step 8, when triggered), and the branch-protection green-CI requirement the PR opens against (Step 9).
- The `../../shared/refs/safety-floor.md` safety floor (DB/data pauses, breaking-change pauses, branch isolation, secret scan, no unsanctioned writes).

Tolerance moves **component selection + severity thresholds only** — it can never
switch off a floor item.

## Output of this step

Hold in context for the rest of the run:

```
profile           = strict | standard | lenient
required_components = [ e2e, qa, ... ]      # resolved component set for Step 5 (sourced from the required_buckets column)
coverage_mode     = enforced | advisory
preview_map       = { <platform>: { preview_kind, preview_deploy_cmd } }
preview_always    = true | false            # strict → true
```
