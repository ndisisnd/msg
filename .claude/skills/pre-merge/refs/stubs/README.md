# Doctor stub configs

Minimal, runnable config templates that `/pre-merge --doctor` copies into a target
repo for the **config-missing** gap flavor (a tool's dependency exists, or is being
installed, but no config file is present so the gate can't run it) — plus the
**workflow-missing** flavor (`pre-merge.yml`), scaffolded when no `.github/workflows/`
pipeline produces PR status checks.

Each stub is deliberately minimal — just enough for the corresponding bucket/step
to execute — and is meant to be tuned by the project afterward. The doctor writes
the stub **and** installs the matching dependency under the same per-item approval
(`AskUserQuestion`); it never writes a config the user didn't approve.

| Stub | Step / bucket | Installs alongside |
|---|---|---|
| `eslint.config.js` | mechanical (lint) | `eslint` (≥9), `@eslint/js` |
| `biome.json` | mechanical (lint+format) | `@biomejs/biome` |
| `.prettierrc.json` | mechanical (format) | `prettier` |
| `ruff.toml` | mechanical (Python lint) | `ruff` |
| `vitest.config.ts` | unit_int + coverage | `vitest`, `@vitest/coverage-v8` |
| `playwright.config.ts` | e2e | `@playwright/test` |
| `.size-limit.json` | perf (bundle) | `size-limit`, `@size-limit/preset-app` |
| `pre-merge.yml` | ci (`.github/workflows/`) | — (no dep; doctor substitutes detected gate commands) |

**Version note:** pinned schema/toolchain references in these stubs (e.g. Biome's
`$schema` URL) may drift as the tools release. The doctor should confirm the stub
matches the installed tool version; treat these as starting points, not lockstep
mirrors. Spec: [`../protocol-doctor.md`](../protocol-doctor.md).
