# test — Init mode

`/test --init` is the **setup/advisory** mode. It does NOT run tests. It profiles the
codebase, decides which test buckets this project actually *needs*, recommends third-party
tools and packages for the gaps, optionally installs them, and writes a `test.json` cache
that the execution path reads on every later run.

Two deterministic inputs drive it — never re-derive either by hand:

| Input | Script | Answers |
|-------|--------|---------|
| **Installed** runners | `test-tooling-detect.sh` | what is wired up *right now* |
| **Shape** profile | `test-init-profile.sh` | what *kind* of project this is |

The skill computes the **gap** = (needed by shape) − (installed). That gap is the recommendation.

---

## Shape → needed buckets

Apply every row whose condition matches the profile. A bucket is "needed" if any matching
row marks it needed. `unit` and `coverage` are needed for every non-empty codebase.

| Profile condition | Buckets it makes needed |
|-------------------|-------------------------|
| any source code | `unit`, `coverage` |
| `shape.has_http_api` or `shape.has_db` | `unit` (integration tier), `load`, `api` |
| `shape.has_openapi` | `api` (contract) |
| `shape.has_ui` and not `is_mobile` | `e2e`, `qa`, `a11y`, `perf` |
| `is_mobile` (Flutter) | `mobile`, `e2e` (integration_test) |
| a PRD workflow exists (`features/prd-*`) | `functional` |
| `is_library` | `unit`, `coverage` only (drop e2e/qa/a11y/perf unless `has_ui`) |
| `is_cli` | `unit`, `functional`, `coverage` |

Record, per needed bucket, a one-line `rationale` tied to the profile signal that triggered it
(e.g. `"React UI detected → user-facing flows need e2e"`).

---

## Bucket → recommended tool + packages

Pick ONE tool per bucket using the language/framework. Prefer a tool already installed
(from the detect fingerprint); only recommend a new one when the bucket has no runner.
When two are viable, the **first** listed is the default recommendation; surface the
alternative in the `tools` entry's `reason`.

| Bucket | Stack | Default tool → packages (dev) | Alternatives |
|--------|-------|-------------------------------|--------------|
| unit | Vite/TS/React | Vitest → `vitest`, `@vitest/coverage-v8` | Jest → `jest`, `ts-jest`, `@types/jest` |
| unit | non-Vite JS/TS | Jest → `jest`, `ts-jest`, `@types/jest` | Vitest |
| unit | Python | pytest → `pytest`, `pytest-cov` | — |
| unit | Dart/Flutter | built-in `flutter test` (no package) | — |
| e2e | web | Playwright → `@playwright/test` | Cypress → `cypress` |
| e2e | Flutter | `integration_test` (SDK) + `patrol` | `maestro` (CLI, no package) |
| qa / visual | web | Playwright snapshots (reuse `@playwright/test`) | Chromatic → `chromatic`; Percy → `@percy/cli` |
| load | http | k6 (CLI install, no npm) | Artillery → `artillery`; autocannon → `autocannon` |
| a11y | web | axe → `@axe-core/cli`, `axe-playwright` | pa11y → `pa11y-ci`; `jest-axe` |
| perf | web | Lighthouse CI → `@lhci/cli` + size-limit → `size-limit`, `@size-limit/preset-app` | bundlesize → `bundlesize` |
| api / contract | http | Spectral → `@stoplight/spectral-cli` (lint) + Pact → `@pact-foundation/pact` (consumer) | Dredd → `dredd`; Newman → `newman` |
| mobile | Flutter | `patrol` → add `patrol` dev dep | `maestro` (CLI) |
| coverage | — | inherit the unit runner's coverage flag (no extra package) | — |

CLI-only tools (k6, maestro) are NOT npm packages — record them under `tools` with
`install: "<brew/curl hint>"`, never under `packages.recommended_to_install`.

---

## test.json schema

Written to `.claude/test/test.json`. One object. A **Replace** run overwrites it wholesale;
an **Analyse + update** run (Step I-0, when a cache already exists) reconciles in place —
adding now-needed entries and removing entries no longer warranted, preserving unaffected fields.

```json
{
  "version": 1,
  "generated_at": "<YYYY-MM-DDTHH:mm:ssZ>",
  "project": {
    "type": "fullstack | web-frontend | backend-api | mobile | cli | library | unknown",
    "languages": ["typescript", "..."],
    "frameworks": ["react", "next", "..."],
    "package_manager": "npm | pnpm | yarn | pub | pip | poetry | null"
  },
  "needed_buckets": [
    {
      "bucket": "e2e",
      "needed": true,
      "status": "configured | missing | partial",
      "rationale": "<why this codebase needs it>",
      "recommended_tool": "Playwright",
      "recommended_packages": ["@playwright/test"]
    }
  ],
  "tools": [
    {
      "name": "Playwright",
      "bucket": "e2e",
      "status": "installed | recommended",
      "install": "npm i -D @playwright/test  (then npx playwright install)",
      "reason": "<one line — why this over the alternative>"
    }
  ],
  "packages": {
    "installed": ["vitest"],
    "recommended_to_install": ["@playwright/test", "@axe-core/cli"],
    "install_command": "npm i -D @playwright/test @axe-core/cli"
  }
}
```

### Field rules

- `status` per bucket: `configured` when a runner is already detected; `missing` when needed
  but no runner; `partial` when a runner exists but key packages/config are absent.
- `packages.installed` — the union of test-related deps the detect fingerprint already found.
- `packages.recommended_to_install` — only npm packages for `missing`/`partial` buckets the
  user approved at the gate. Empty array if the user declined all installs.
- `install_command` — single line using `package_manager.run_prefix`'s install form
  (`npm i -D …`, `pnpm add -D …`, `yarn add -D …`). `null` when nothing to install.

---

## Consumption by the execution path

Step 1 of the main protocol reads `.claude/test/test.json` if present. For each
`needed_buckets` entry with `needed: true` whose runner came back `null` from detection,
annotate that bucket in the Step 3 plan with `⚠ needed but not configured — run /test --init`.
`test.json` never overrides detection commands — detection stays authoritative for *how* to
run; `test.json` only adds the *should-exist* dimension and the warnings.
