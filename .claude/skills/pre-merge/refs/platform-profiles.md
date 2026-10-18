---
name: platform-profiles
description: Resolve the strictness profile from devkit/PLATFORMS.md. Maps each shipping platform's tolerance to how strict each check is (blocking vs advisory) and to severity thresholds; it never decides whether a check runs. The safety floor runs in every profile.
---

# Platform-mode resolution

Read `devkit/PLATFORMS.md` and resolve, for this run, a **strictness profile** → how
strict each check is (blocking vs advisory) and how severity thresholds are set.
**Which checks run is not a profile decision.** A check runs when its catalog trigger
(`active_when`) matches the change and its tool is detected
(`../../shared/refs/component-catalog.md`). The profile changes strictness only; the
**safety floor never changes**.

## Read + fallback

1. Read `devkit/PLATFORMS.md`. Parse the pipe table. Pre-merge consumes only the `platform` and `tolerance` columns; the deploy commands are `/merge`'s (ignore them here). A `required_buckets` column, when present, is ignored: the catalog and detection decide which checks run.
2. **Missing file** → fall back to the `standard` profile and emit a warning: `"No devkit/PLATFORMS.md — using the standard profile. Run /msg --init to scaffold per-platform tolerance."` Continue; do not refuse.
3. **Multiple rows** (multi-platform repo): take the **strictest** `tolerance` present (`strict` > `standard` > `lenient`).

## Profiles

| Profile | Blocking platform checks (the rest run advisory) | Coverage floor | Severity thresholds |
|---|---|---|---|
| `strict` | e2e, smoke, mobile, perf, a11y, coverage, api, load | **enforced** — shortfall is a `high` finding → `fail` | as-emitted (no downgrade) |
| `standard` | e2e, smoke, a11y, coverage, api | advisory — shortfall is `medium` | as-emitted |
| `lenient` | e2e, smoke | advisory — shortfall is `low` | non-security findings outside the diff downgrade one extra level |

A platform check outside the profile's blocking list still runs when the catalog and
detection say so; its findings are downgraded to advisory (they never fail the gate).
`unit`, `integration` and the safety floor are never downgraded by a profile. Smoke
never skips (`_common.md` § Runner guard).

## Safety floor — every profile, never relaxed

Independent of tolerance, these always run and always gate:

- **`security`** — secret scan + SAST.
- **`migration`** — static SQL-safety scan when the diff touches migrations.
- **The branch-protection green-CI requirement** the PR opens against. Pre-merge holds no human gate of its own — the human look lives at merge (`../../shared/refs/safety-floor.md` § *Human gates*).
- The `../../shared/refs/safety-floor.md` safety floor (DB/data pauses, breaking-change pauses, branch isolation, secret scan, no unsanctioned writes).

Tolerance moves **strictness + severity thresholds only** — it never adds or removes
a check, and it can never switch off a floor item.

## Output of this step

Hold in context for the rest of the run:

```
profile             = strict | standard | lenient
blocking_platform   = [ e2e, smoke, ... ] # the profile's blocking platform checks (table above)
coverage_mode       = enforced | advisory
```
