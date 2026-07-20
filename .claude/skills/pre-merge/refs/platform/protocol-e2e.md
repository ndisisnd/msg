---
name: e2e
description: Pre-merge e2e component — run end-to-end tests via the detected runner, parse failures to canonical findings. Supports --flaky retry.
---

# e2e component

Guard, error rule, envelope, `--flaky`/`--changed-only`: `../_common.md`. Runner
(`e2e_runner`) from the Step 1 fingerprint.

## Run

| Detected runner | Command |
|---|---|
| Playwright | `rtk npx playwright test` |
| Cypress | `rtk npx cypress run` |
| Flutter integration | `rtk flutter test integration_test/` |
| CI override | `rtk <package_manager> run <ci_script>` |

Full suite by default. With a diff base + runner spec-filtering (Playwright `--grep`,
Cypress `--spec`), best-effort map changed source files to spec files by name and
scope; if the guessed mapping resolves to zero specs, run the full suite (never a
silent empty scope).

## Parse

- Exit 0 → `pass` (`pass_with_warnings` if specs skipped).
- Non-zero with failures → each failing spec is one finding, `severity: high` (matches the e2e severity floor).
- Non-zero crash/startup error → `pass_with_warnings`, note `"E2E runner failed to start — results unreliable."`.

Finding fields: `rule` = test title / `describe > it` path; `file` = spec path;
`evidence.spec` = spec file; `evidence.file` = screenshot/trace artifact or `null`;
`repro` = single-spec re-run command. `--flaky` retry per `../_common.md`.

Totals: `{ passed, failed, skipped, flaky }` (`flaky` only under `--flaky`).
