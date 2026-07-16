---
name: pre-merge-protocol-doctor
description: Spec for /pre-merge --doctor — detect each gate step's tooling from the pre-merge fingerprint, cross-reference nulls against the Step-0 required_buckets, interview + gated-install the gaps OSS-first, and record per-step decisions into devkit/policy.json (Steps 2/3/5/6 only).
type: reference
---

# `/pre-merge --doctor`

The setup half of the pre-merge gate. It **detects** each step's tooling, **interviews** the user
about the real gaps, **offers to install** the missing pieces (gated, per-item, OSS-first), and
**records** every decision into `devkit/policy.json` — turning today's silent "no tooling → skip"
into an explicit, persisted `steps.<key>` decision the gate reads at run time.

`--doctor` **never runs the gate, never opens a PR, never merges, never deploys, and never writes
`devkit/PLATFORMS.md`** (AC-DR1). Its only outputs are repo mutations under explicit per-item
approval (binaries, stub configs) and the `policy.json` write.

The `devkit/policy.json` schema, status vocabulary, validation rules, and gate read-contract are
defined once in **`../../shared/refs/policy-schema.md`** — the authority. This file cites it for
anything schema-shaped and never redefines it.

---

## Shared `--doctor` contract

Both gate skills run the same seven-step contract (canonical text: the plan's "Shared `--doctor`
contract"). Pre-merge's flavor:

1. **Prerequisites** — `jq` (the detector needs it) and a `git` remote. Offer `brew install jq` if
   missing; without a remote, note that PR-shaped steps are inert. (`gh` auth is post-merge's
   concern.)
2. **Load or seed** the policy file — read `devkit/policy.json` if present (re-run = update in
   place, never overwrite from scratch); else start empty.
3. **Detect** — run `pre-merge-tooling-detect.sh` (below) and resolve the Step-0 profile.
4. **Interview** — one `AskUserQuestion` per real gap and per open policy question. Every answer
   is recorded, including "skip" and "N/A", so the choice is durable and the next run does not
   re-ask (AC-DR4).
5. **Offer install** — for each gap the user wants filled, run the OSS-first command, gated
   per-item (AC-DR2). A tool installed this run is persisted as `ready` — never `installed` (that
   is a transient terminal-display state only; see policy-schema.md's status vocabulary).
6. **Write** `devkit/policy.json`, stamp `generated` (the skill stamps the ISO date — scripts
   can't), and flip `init:true`. The written file must re-load with **zero** validation warnings
   (AC-S6).
7. **Summary** — a step→status table to the terminal. No gate run, no PR, no merge.

---

## Detection source

`pre-merge-tooling-detect.sh` already emits the full fingerprint of detected tooling — one slot per
runner. **Every `null` slot is a candidate gap.** Doctor does not re-detect by hand; it reads the
fingerprint and the Step-0 profile, then classifies.

**Fingerprint slot → canonical step-key** (the key written under `steps.<key>`):

| Detector slot | `steps.<key>` | Gate step |
|---|---|---|
| `mechanical_runners[]`, `build_tool` | `mechanical` | Step 2 |
| `test_runner` | `unit_int` | Step 3 |
| `e2e_runner` | `e2e` | Step 5 |
| `qa_runner` | `qa` | Step 5 |
| `a11y_runner` | `a11y` | Step 5 |
| `perf_runner` (+ `bundle_analyzer`) | `perf` | Step 5 |
| `load_runner` | `load` | Step 5 |
| `api_runner[]` | `api` | Step 5 |
| `mobile_runner` | `mobile` | Step 5 |
| `coverage_runner` | `coverage` | Step 5 |
| `security_scanners[]`, `secret_scanner` | `security` | Step 6 |
| _(static SQL scan — no runner slot)_ | `migration` | Step 6 |

**Cross-reference against `required_buckets`.** Resolve the Step-0 profile from `devkit/PLATFORMS.md`
(`refs/platform-profiles.md`): a `null` slot is only a **gap** if its bucket is in the profile's
`required_buckets`. A `null` slot whose bucket is **not** required (e.g. `a11y` on a backend-only
repo) is *correctly absent* — propose it as `n/a`, never nag it as a gap (AC-ST1 territory). The
`security` and `migration` safety-floor steps run in every profile, so their nulls are always real
gaps, never `n/a`.

> `migration` has no external binary — it's pre-merge's static SQL-safety scan. Doctor records it
> `ready` when the diff surface warrants it and `n/a` for repos with no migrations; there is
> nothing to install.

**Steps covered:** `mechanical` (Step 2), `unit_int` (Step 3), the Step-5 platform buckets (`e2e`,
`qa`, `a11y`, `perf`, `load`, `api`, `mobile`, `coverage`), and `security` + `migration` (Step 6).
The `deploy_staging` / `deploy_production` / `smoke` keys are **post-merge's** — pre-merge `--doctor`
leaves them untouched.

---

## Gap taxonomy — the three flavors

Every gap the detector surfaces is one of three flavors, read off the detector's own signals:

| Flavor | How the detector shows it | Doctor action | Recorded status |
|---|---|---|---|
| **Binary missing** | `command -v` slot empty (gitleaks, semgrep, trivy, k6, hurl, osv-scanner…) | offer the install command (per-item, gated) | `ready` on install · `deferred`/`opted_out` on decline |
| **Config missing** | dep may exist but no `eslint.config.*` / `playwright.config.*` / `.semgrep.yml` etc. | scaffold a **minimal stub config** + the dep | `ready` on scaffold · `deferred`/`opted_out` on decline |
| **N/A for surface** | slot `null` **and** the bucket is **not** in `required_buckets` | record only — offer nothing | `n/a` (with `reason`) |

Declining any offered install always records `opted_out` (won't revisit) or `deferred` (will
revisit) **with a `reason`** and installs nothing (AC-DR2). Both non-`ready` statuses require a
`reason` per the schema.

---

## OSS-first install catalog

**Reputable, open-source, free only.** Doctor offers the Preferred tool first, the OSS fallback if
the user prefers it, and **never auto-offers a paid/SaaS tool** (AC-DR3). When a step's only real
option is paid, doctor **names it, explains why**, and records `deferred`/`opted_out` with the paid
tool named in `reason` — it never installs it.

| Step / slot | Preferred (OSS, free) | Fallback (OSS) | Flagged paid — **not** auto-offered |
|---|---|---|---|
| Lint (JS/TS) | Biome | ESLint | — |
| Format | Biome / Prettier | — | — |
| Typecheck (TS) | `tsc` (bundled) | — | — |
| Lint/format (Py) | Ruff | flake8 + black | — |
| Typecheck (Py) | mypy | — | — |
| Unit/int (JS) | Vitest | Jest | — |
| Unit/int (Py) | pytest | — | — |
| e2e | Playwright | Cypress (runner is free) | — |
| Visual / qa | **Playwright snapshots** (built-in, free) | BackstopJS | Chromatic, Percy (SaaS) |
| a11y | axe-core CLI / pa11y | Lighthouse | — |
| perf | Lighthouse CI | — | — |
| bundle | size-limit | bundlesize | — |
| load | k6 | Artillery (OSS core) | k6 Cloud, paid load SaaS |
| api | Schemathesis / Dredd / Spectral | Newman (Postman CLI, free) | Postman paid tiers |
| secrets | gitleaks | trufflehog | — |
| SAST | semgrep (OSS rules) | — | Semgrep paid rulesets |
| deps | osv-scanner (Google) / `pnpm\|npm audit` | trivy fs | Snyk (paid tiers) |
| container | trivy image | — | — |

---

## Interview + gated-install flow

For each real gap (after the `required_buckets` cross-reference), doctor asks **one
`AskUserQuestion`** — never a bulk prompt, never a bulk install:

- **Offer choices** = the catalog's Preferred and Fallback for that slot, plus a **Skip** option.
- **Install** (Preferred/Fallback chosen) → run the OSS-first command for the picked tool; on
  success record `steps.<key> = { status: "ready", chosen: "<tool>" }`. A tool installed this run
  is persisted `ready`, never `installed`.
- **Config-missing flavor** → additionally scaffold the minimal stub config (below) so the gate has
  something runnable immediately.
- **Skip** → record `opted_out` (won't revisit) or `deferred` (will revisit later) **with a
  `reason`**; install nothing.
- **Paid-only slot** → present the free `deferred`/`opted_out` path only; name the paid tool in the
  `reason`. Never an install button.

**Re-run behavior (AC-DR4).** A second `--doctor` reads the existing `policy.json` and updates it in
place. A step already `opted_out` is **not** re-prompted unless the user explicitly asks to
re-tune. Answers persist across runs precisely so the interview shrinks each time.

---

## Minimal-stub config scaffolding

For the **config-missing** flavor, doctor copies a **minimal runnable stub** — just enough that the
gate can execute the tool on the next run (not a curated house style). The templates live in
[`stubs/`](stubs/) (see [`stubs/README.md`](stubs/README.md) for the full stub→step→dep map):

| Stub | Step / bucket | Dep installed alongside |
|---|---|---|
| `eslint.config.js` | mechanical (lint) | `eslint` (≥9) + `@eslint/js` |
| `biome.json` | mechanical (lint+format) | `@biomejs/biome` |
| `.prettierrc.json` | mechanical (format) | `prettier` |
| `ruff.toml` | mechanical (Python) | `ruff` |
| `vitest.config.ts` | unit_int + coverage | `vitest` + `@vitest/coverage-v8` |
| `playwright.config.ts` | e2e | `@playwright/test` |
| `.size-limit.json` | perf (bundle) | `size-limit` + `@size-limit/preset-app` |

`.semgrep.yml` is intentionally **not** stubbed — semgrep runs with `--config auto` (its OSS
ruleset) when no project config exists, so no scaffold is needed.

Scaffolding is a mutation, so it is **gated by the same per-item `AskUserQuestion`** as a binary
install — the user approves the config write explicitly. The dep is installed alongside the stub so
the pairing is runnable. Doctor should confirm a copied stub matches the installed tool version
(pinned schema/toolchain refs can drift).

---

## Writing `steps.<key>` and flipping `init`

Doctor writes one `steps.<key>` entry per step it touched, using the persisted vocabulary and the
`reason`/`chosen` fields — **the schema, statuses, and required-field rules are defined in
`../../shared/refs/policy-schema.md`; this spec does not restate them.** In outline:

- **installed / already present** → `ready` (+ `chosen`).
- **user skipped, won't revisit** → `opted_out` (+ `reason`).
- **user skipped, will revisit / paid-only** → `deferred` (+ `reason`).
- **not in `required_buckets`** → `n/a` (+ `reason`).
- **known unresolved gap left as-is** → `missing` (+ `reason`).

On completion doctor **flips `init:true`** (from the `{init:false}` seed `/msg --init` wrote) and
stamps `generated` + `generated_by: "pre-merge --doctor"`. The gate then consumes each entry via the
policy-schema read-contract (§3 `steps.<key>`): `ready` with no live tool → one `medium`
`policy-mismatch` finding then the no-tooling path; `opted_out`/`n/a` → skip silently;
`missing`/`deferred` → the existing `no_tooling` note. Doctor's job is to *record*; the gate's job
is to *read*.

The written file must round-trip clean — re-loading it in a gate run produces **zero** validation
warnings (AC-S6). Never write `installed`, an unknown step-key, or a step-key outside the closed
15-key vocabulary.

---

## Boundaries (what `--doctor` never does)

- Never runs the pre-merge protocol, opens a PR, merges, or deploys (AC-DR1).
- Never writes `devkit/PLATFORMS.md` — it *reports* PLATFORMS.md-shaped gaps and delegates to
  `/msg --init` (that file stays `/msg --init`'s; policy-schema.md's writer table has the boundary).
- Never installs a paid/SaaS tool (AC-DR3).
- Never mutates without an explicit per-item `AskUserQuestion` approval (AC-DR2).
