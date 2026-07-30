# Init stub configs

Minimal, runnable config templates that `/pre-merge --init` copies into a target
repo for the **config-missing** gap flavor (a tool's dependency exists, or is being
installed, but no config file is present so the gate can't run it) — plus the
**workflow-missing** flavor (`pre-merge.yml`), scaffolded when no `.github/workflows/`
pipeline produces PR status checks.

Each stub is deliberately minimal — just enough for the corresponding component/step
to execute — and is meant to be tuned by the project afterward. `--init` writes
the stub **and** installs the matching dependency under the same per-item approval
(`AskUserQuestion`); it never writes a config the user didn't approve.

| Stub | Step / component | Installs alongside |
|---|---|---|
| `eslint.config.js` | mechanical (lint) | `eslint` (≥9), `@eslint/js` |
| `biome.json` | mechanical (lint+format) | `@biomejs/biome` |
| `.prettierrc.json` | mechanical (format) | `prettier` |
| `ruff.toml` | mechanical (Python lint) | `ruff` |
| `vitest.config.ts` | unit + integration + coverage | `vitest`, `@vitest/coverage-v8` |
| `playwright.config.ts` | e2e | `@playwright/test` |
| `.size-limit.json` | perf (bundle) | `size-limit`, `@size-limit/preset-app` |
| `pre-merge.yml` | ci (`.github/workflows/`) | — (no dep; `--init` substitutes detected gate commands) |
| `docker-compose.test.yml` | the C23 test-sandbox (`devkit/ENV.md` `provision`/`teardown`) | — (needs Docker on the machine) |
| `seed-test.ts` / `seed-test.py` | the C23 seed fixture (`devkit/ENV.md` `seed`/`reset`) | — (uses the project's own ORM/driver) |

**The env stubs are the `devkit/ENV.md` companions (C23).** They are offered only when
`--init` found no provisioner and the user wants one scaffolded. Accepting them fills the
matching verbs in `devkit/ENV.md`
([`../../../shared/refs/env-contract.md`](../../../shared/refs/env-contract.md)); declining
leaves `[USER: …]` placeholders and the loud `sandbox-unprovisioned` degrade at gate time.
Both are starting points — the compose file names services the project actually runs, and
the seed script is a skeleton the project fills with its own fixture.

**Version note:** pinned schema/toolchain references in these stubs (e.g. Biome's
`$schema` URL) may drift as the tools release. `--init` should confirm the stub
matches the installed tool version; treat these as starting points, not lockstep
mirrors. Spec: [`../protocol-init.md`](../protocol-init.md).
