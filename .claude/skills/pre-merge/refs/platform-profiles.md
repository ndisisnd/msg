---
name: platform-profiles
description: Resolve the strictness profile + component set from devkit/PLATFORMS.md. Maps each shipping platform's tolerance to required components and severity thresholds; the safety floor runs in every profile.
---

# Platform-mode resolution

Read `devkit/PLATFORMS.md` and resolve, for this run, a **strictness profile** →
which platform components run and how severity thresholds are set.
Component selection and thresholds vary by profile; the **safety floor never does**.

## Read + fallback

1. Read `devkit/PLATFORMS.md`. Parse the pipe table (`platform | rollback_possible | tolerance | staging_deploy_cmd | production_deploy_cmd | required_buckets`) — the last column's on-disk name (`required_buckets`) predates this refactor's terminology rename and is unchanged by it; everywhere below it is called the **required-components** column/set. Pre-merge only consumes the `platform` / `tolerance` / `required_buckets` columns; the deploy commands are `/post-merge`'s (ignore them here).
2. **Missing file** → fall back to the `standard` profile and emit a warning: `"No devkit/PLATFORMS.md — using the standard profile. Run /msg --init to scaffold per-platform tolerance."` Continue; do not refuse.
3. **Multiple rows** (multi-platform repo): resolve the **union** of every row's required-components set, and take the **strictest** `tolerance` present (`strict` > `standard` > `lenient`) for threshold purposes.

## Profiles

| Profile | Platform components run | Coverage floor | Severity thresholds |
|---|---|---|---|
| `strict` | e2e, smoke, mobile, perf, a11y, coverage, api, load | **enforced** — shortfall is a `high` finding → `fail` | as-emitted (no downgrade) |
| `standard` | e2e, smoke, a11y, coverage, api | advisory — shortfall is `medium` | as-emitted |
| `lenient` | e2e (`unit`/`integration` always run) | advisory — shortfall is `low` | non-security findings outside the diff downgrade one extra level |

The row's required-components set (the `required_buckets` column) **overrides** the
profile's default component list — the column is authoritative; the profile default
is used only when a row omits it. Components with no detected runner are skipped (`no_tooling`) regardless of profile.

## Safety floor — every profile, never relaxed

Independent of tolerance, these always run and always gate:

- **`security`** — secret scan + SAST.
- **`migration`** — static SQL-safety scan when the diff touches migrations.
- **The branch-protection green-CI requirement** the PR opens against. Pre-merge holds no human gate of its own — the human look lives at post-merge (`../../shared/refs/safety-floor.md` § *Human gates*).
- The `../../shared/refs/safety-floor.md` safety floor (DB/data pauses, breaking-change pauses, branch isolation, secret scan, no unsanctioned writes).

Tolerance moves **component selection + severity thresholds only** — it can never
switch off a floor item.

## Output of this step

Hold in context for the rest of the run:

```
profile             = strict | standard | lenient
required_components = [ e2e, smoke, ... ] # the resolved component set (sourced from the required_buckets column)
coverage_mode       = enforced | advisory
```
