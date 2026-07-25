---
name: pre-merge-protocol-init
description: Spec for /pre-merge --init — detect each gate step's tooling from the pre-merge fingerprint, cross-reference nulls against the Step-0 required_buckets, interview + gated-install the gaps OSS-first, and record per-step decisions into devkit/policy.json (Steps 2/3/5/6 only).
type: reference
---

# `/pre-merge --init`

The setup half of the pre-merge gate. It **detects** each step's tooling, **interviews** the user
about the real gaps, **offers to install** the missing pieces (gated, per-item, OSS-first), and
**records** every decision into `devkit/policy.json` — turning today's silent "no tooling → skip"
into an explicit, persisted `steps.<key>` decision the gate reads at run time.

> **Deprecated alias.** `/pre-merge --doctor` still works for one release: it runs `--init` and
> prints a deprecation note naming `--init`/`--update`. New callers should use `--init`.

`--init` **never runs the gate, never opens a PR, never merges, never deploys, and never writes
`devkit/PLATFORMS.md`** (AC-DR1). Its only outputs are repo mutations under explicit per-item
approval (binaries, stub configs) and the `policy.json` write.

The `devkit/policy.json` schema, status vocabulary, validation rules, and gate read-contract are
defined once in **`../../shared/refs/policy-schema.md`** — the authority. This file cites it for
anything schema-shaped and never redefines it.

---

## Shared `--init` contract

Both gate skills run the same seven-step contract (canonical text: the plan's "Shared `--init`
contract"). Pre-merge's flavor:

1. **Prerequisites** — `jq` (the detector needs it) and a `git` remote. Offer `brew install jq` if
   missing; without a remote, note that PR-shaped steps are inert. (`gh` auth is post-merge's
   concern.)
2. **Load or seed** the policy file — read `devkit/policy.json` if present (re-run = update in
   place, never overwrite from scratch); else start empty.
3. **Detect** — run the `preflight-check-*.sh` family (the v3 preflight ingestion below) and resolve the Step-0 profile.
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

The `preflight-check-*.sh` family emits one normalized detect report per component, together
covering the full fingerprint of detected tooling — one slot per runner (the probe primitives
live in `preflight-common.sh`; they superseded the retired monolithic detector at v3 P3).
**Every `null`/`no_tooling` slot is a candidate gap.** `--init` does not re-detect by hand; it
reads the reports and the Step-0 profile, then classifies.

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
| _(`.github/workflows/*.yml` presence — no runner slot)_ | `ci` | cross-cutting — the pipeline that runs the gate on the PR |

**Cross-reference against `required_buckets`.** Resolve the Step-0 profile from `devkit/PLATFORMS.md`
(`refs/platform-profiles.md`): a `null` slot is only a **gap** if its component is in the profile's
`required_buckets`. A `null` slot whose component is **not** required (e.g. `a11y` on a backend-only
repo) is *correctly absent* — propose it as `n/a`, never nag it as a gap (AC-ST1 territory). The
`security` and `migration` safety-floor steps run in every profile, so their nulls are always real
gaps, never `n/a`.

> `migration` has no external binary — it's pre-merge's static SQL-safety scan. `--init` records it
> `ready` when the diff surface warrants it and `n/a` for repos with no migrations; there is
> nothing to install.

> **Large/hot tables question (C17, AC-MIG3).** When `migration` is active (the repo has a
> migrations surface), `--init` asks **one** `AskUserQuestion` for the project's **large or hot
> tables** — the ones where a lock-taking migration (CREATE INDEX without CONCURRENTLY, a
> whole-table rewrite) would be an apparent outage. The answer is recorded on the `migration`
> component as an optional `hot_tables[]` hint (see `component-catalog.md`). It gives the migration
> stage size context to **scale lock-risk severity** (escalate on a hot table, quiet on a tiny
> one) when no schema/stats source is available; with neither stats nor a declared list, lock
> findings keep their current flat severity (AC-MIG4). A sane default is an empty list (no
> size context — flat severity). This is policy, not a tool — nothing is installed.

> **Mobile device/OS matrix (C18, AC-MOB5).** When `mobile` is active (a native iOS/Android
> or Flutter surface), and **no** declared matrix exists (`.flutter-test-matrix.json` /
> manifest mobile matrix), `--init` asks **one** `AskUserQuestion` for the target
> **platforms + OS versions** (e.g. iOS 17, Android 14). The answer is the **enforced**
> `{platform, os}` matrix recorded on the `mobile` component: a declared target with no
> available device/simulator (incl. no macOS host for iOS XCUITest) becomes a `high`
> coverage-gap at gate time, not a silent pass (see `platform/protocol-mobile.md`). This is
> policy, not a tool — nothing is installed.

> **API consumers hint (C15, AC-API4 — optional).** When `api` is active and **no** Pact
> broker is configured (`PACT_BROKER_BASE_URL` absent), `--init` may ask **one** optional
> `AskUserQuestion` for the API's known **consumers** (`ios`/`android`/`web`), recorded as
> the `api` component's optional `consumers[]` hint so a breaking-change finding can name
> which client breaks. Absent both broker and hint, findings degrade to endpoint+change (no
> fabricated consumer). Optional — an empty/absent list is valid, never a validation error.

> **a11y relevance (C13, AC-A11Y4).** When `a11y` is active (a UI surface), `--init` asks
> **one** `AskUserQuestion` for whether accessibility is a **default check for this
> project** — is it **public-facing** (a product real users touch) or **internal/backend**
> (an admin tool, a service). The answer sets the `a11y` component's default **enablement +
> criticality**, recorded in the manifest: **public-facing → default-on / blocking**
> (fails on serious/critical WCAG); **internal / backend → default-off or advisory**
> (findings recorded as context, never block). This makes a11y a project-level decision
> rather than an unconditional default (see `platform/protocol-a11y.md`) — a profile
> override still layers on top. Policy, not a tool — nothing is installed.

> **Env provisioner (C23, AC-SBX6).** When any `needs_env: true` component is present
> (catalog `env` column — integration, migration, e2e, a11y, perf, load, smoke, mobile,
> api-live), `--init` **detects** the project's sandbox provisioner candidates —
> `docker-compose*.yml` / a testcontainers dep / an ephemeral-DB-branch CLI (e.g.
> Neon/`pg_tmp`) / a `preview_deploy_cmd` / a mobile simulator — and asks **one**
> `AskUserQuestion` to confirm the pick (or declare one, or skip). When **two**
> candidates apply at once (full-stack mobile: a simulator **and** a compose backend),
> record a composite **`stacks[]`** — one logical sandbox, both stacks. The answer is
> recorded as the manifest's **`env_provision`** resolution (`policy-schema.md` — the
> neutral provision / seed / reset / teardown interface; post-merge-consumable schema,
> pre-merge-only writer). Alongside it, `--init` detects/asks for the **committed seed
> script** (S-Q1: migrate-from-zero + versioned fixture — never a prod-like snapshot)
> and the optional `perf`/`load` **`scale_factor`**. **Skip / nothing detected ⇒
> `provisioner: "none"`** — recorded, valid, and loud at gate time: every env-needing
> component then carries a `high` `sandbox-unprovisioned` finding per run
> (`refs/executor.md` §3b), never a silent pass. A provisioner without a seed script is
> also recorded and flagged loudly at gate time. Same detect→catalog→record pattern as
> every other resolution; the provisioner itself may be an install offer (e.g. Docker
> absent) under the normal per-item gate (AC-DR2).

> **Regression suite composition (C23, AC-SBX8).** When `regression` is present,
> `--init` resolves **`regression.needs_env`** from the accumulated suite's
> composition: contains integration-level tests (DB/network-touching — detectable from
> the suite's imports/markers, e.g. a testcontainers/DB fixture) → `true` (its
> accumulated-suite run executes inside the sandbox); pure-unit suite → `false`. When
> detection is ambiguous, ask **one** `AskUserQuestion`. Recorded on the `regression`
> component in `components[]`; `--update` re-resolves it as a fact (not a settled
> policy choice) when the suite's composition changes. Policy, not a tool — nothing is
> installed.

> **Load read/write mix (C16, AC-LOAD2).** When `load` is active (an endpoint/data-path
> surface), `--init` asks **one** `AskUserQuestion` for the project's realistic **read/write
> mix** (ratio + concurrency + think-time), recorded as the `load` component's `traffic_mix`
> so the profile exercises the write path and surfaces read/write contention. A **sane
> default** (e.g. 80/20 read/write, moderate concurrency, short think-time) is offered so a
> skip still yields a runnable profile. Policy, not a tool — nothing is installed.

> `ci` has no runner slot either — it's the **CI workflow** that runs the gate on the PR and
> produces the status checks that post-merge's "green CI" and branch protection depend on. Detect
> it directly (not from the fingerprint): a repo has a gap when **no** `.github/workflows/*.yml`
> triggers on `pull_request`.
>
> ```bash
> grep -lE 'pull_request' .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null
> ```
>
> Empty result → gap: nothing runs the gate on the PR, so "all checks green" is **vacuously true**
> and branch protection has no check to require. Present → record `ci` as `ready`. `--init`
> **scaffolds** the workflow (below) but never edits an existing one; if a workflow exists but
> looks unrelated to the gate, record `ready` and note it rather than overwriting.
>
> **First check whether Actions is wanted at all.** Before calling an empty result a gap, resolve
> `ga = policies.github_actions.enabled ?? true` from `devkit/policy.json`
> (`../../shared/refs/policy-schema.md` §2b). `ga:false` → the user has already decided against
> GitHub Actions (no Actions minutes, no Pro plan, or CI hosted elsewhere): this is **not a gap**.
> Record `steps.ci = { status: "opted_out", reason: "<the policy's reason>" }`, offer no scaffold,
> report nothing as missing, and say once that `/msg --update` changes the decision. `ga:true`/absent
> → the gap is real, as above. Note the asymmetry: an *existing* `pull_request` workflow is still
> recorded `ready` whatever `ga` says — the opt-out governs whether to *add* CI, not whether to
> notice CI that exists.
>
> Otherwise `ci` is a repo-wide floor (like `security`/`migration`), so its gap is always real —
> never `n/a`. `--init` never writes `policies.github_actions`; that decision belongs to
> `/msg --init` / `/msg --update` and is only read here. `steps.ci` stays this protocol's own key
> (post-merge reads it, never writes it).

**Steps covered:** `mechanical` (Step 2), `unit_int` (Step 3), the Step-5 platform components (`e2e`,
`qa`, `a11y`, `perf`, `load`, `api`, `mobile`, `coverage`), `security` + `migration` (Step 6), and
the cross-cutting `ci` workflow. The `deploy_staging` / `deploy_production` / `smoke` keys are
**post-merge's** — pre-merge `--init` leaves them untouched. (post-merge `--init` *reads* the
`ci` record at item 2 but never writes it — see its `protocol-init.md`.)

---

## Gap taxonomy — the flavors

Every gap the detector surfaces is one of these flavors, read off the detector's own signals
(plus, for `ci`, the `policies.github_actions` decision):

| Flavor | How the detector shows it | `--init` action | Recorded status |
|---|---|---|---|
| **Binary missing** | `command -v` slot empty (gitleaks, semgrep, trivy, k6, hurl, osv-scanner…) | offer the install command (per-item, gated) | `ready` on install · `deferred`/`opted_out` on decline |
| **Config missing** | dep may exist but no `eslint.config.*` / `playwright.config.*` / `.semgrep.yml` etc. | scaffold a **minimal stub config** + the dep | `ready` on scaffold · `deferred`/`opted_out` on decline |
| **Workflow missing** | no `.github/workflows/*.yml` triggers on `pull_request` (the `ci` gap) **and** `policies.github_actions.enabled ?? true` is true | scaffold `pre-merge.yml` with the detected gate commands substituted in | `ready` on scaffold · `deferred`/`opted_out` on decline |
| **Actions opted out** | same detector signal, but `policies.github_actions.enabled` is `false` | not a gap — offer nothing, report nothing missing | `opted_out` (the policy's `reason`) |
| **N/A for surface** | slot `null` **and** the component is **not** in `required_buckets` | record only — offer nothing | `n/a` (with `reason`) |

Declining any offered install always records `opted_out` (won't revisit) or `deferred` (will
revisit) **with a `reason`** and installs nothing (AC-DR2). Both non-`ready` statuses require a
`reason` per the schema.

**Secret scanner — the safety-floor exception (C9, AC-SF2).** The `security` secret scanner
(gitleaks/trufflehog) is **not** an ordinary declinable tool. `--init` **strongly offers** it and,
if the user declines, records the decision as an explicit **safety-floor gap** (not a quiet
`opted_out`): the interview states that **the gate will `blocker` on every run until a secret
scanner is configured** — there is no green-gate path without secret-scan coverage
(`refs/universal/protocol-security.md`, C9). The **install itself still goes through per-item
approval** (`AC-DR2` — no forced mutation); C9 changes the *framing and the recorded gap*, never
the consent model. Every other `security` layer (SAST / deps / container / `/cook`) stays an
ordinary best-effort gap — declining it is a plain note, not a floor gap.

---

## OSS-first install catalog

**Reputable, open-source, free only.** `--init` offers the Preferred tool first, the OSS fallback if
the user prefers it, and **never auto-offers a paid/SaaS tool** (AC-DR3). When a step's only real
option is paid, `--init` **names it, explains why**, and records `deferred`/`opted_out` with the paid
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

For each real gap (after the `required_buckets` cross-reference), `--init` asks **one
`AskUserQuestion`** — never a bulk prompt, never a bulk install:

- **Offer choices** = the catalog's Preferred and Fallback for that slot, plus a **Skip** option.
- **Install** (Preferred/Fallback chosen) → run the OSS-first command for the picked tool; on
  success record `steps.<key> = { status: "ready", chosen: "<tool>" }`. A tool installed this run
  is persisted `ready`, never `installed`.
- **Config-missing flavor** → additionally scaffold the minimal stub config (below) so the gate has
  something runnable immediately.
- **Workflow-missing flavor (`ci`)** → no catalog tool; the only offer is **Scaffold `pre-merge.yml`**
  (copy the stub to `.github/workflows/`, substitute the detected gate commands) or **Skip**. Scaffold
  → `steps.ci = { status: "ready", chosen: ".github/workflows/pre-merge.yml" }`; skip →
  `deferred`/`opted_out` with a `reason`.
- **Actions-opted-out flavor (`ci`)** → make **no offer at all**: no question, no scaffold, no
  install. Record `steps.ci = { status: "opted_out", reason: "<policy reason>" }` and move on. This
  is the one flavor with no user-facing choice here, because the choice was already made in
  `/msg --init` / `/msg --update` — name that command once if the user wants it back.
- **Skip** → record `opted_out` (won't revisit) or `deferred` (will revisit later) **with a
  `reason`**; install nothing.
- **Paid-only slot** → present the free `deferred`/`opted_out` path only; name the paid tool in the
  `reason`. Never an install button.

**Re-run behavior (AC-DR4).** A second `--init` reads the existing `policy.json` and updates it in
place. A step already `opted_out` is **not** re-prompted unless the user explicitly asks to
re-tune. Answers persist across runs precisely so the interview shrinks each time.

---

## Minimal-stub config scaffolding

For the **config-missing** flavor, `--init` copies a **minimal runnable stub** — just enough that the
gate can execute the tool on the next run (not a curated house style). The templates live in
[`stubs/`](stubs/) (see [`stubs/README.md`](stubs/README.md) for the full stub→step→dep map):

| Stub | Step / component | Dep installed alongside |
|---|---|---|
| `eslint.config.js` | mechanical (lint) | `eslint` (≥9) + `@eslint/js` |
| `biome.json` | mechanical (lint+format) | `@biomejs/biome` |
| `.prettierrc.json` | mechanical (format) | `prettier` |
| `ruff.toml` | mechanical (Python) | `ruff` |
| `vitest.config.ts` | unit_int + coverage | `vitest` + `@vitest/coverage-v8` |
| `playwright.config.ts` | e2e | `@playwright/test` |
| `.size-limit.json` | perf (bundle) | `size-limit` + `@size-limit/preset-app` |
| `pre-merge.yml` → `.github/workflows/` | ci | — (no dep; substitute the detected gate commands) |

`pre-merge.yml` is the one stub that is **command-dependent**: `--init` copies it to
`.github/workflows/pre-merge.yml`, then substitutes the `mechanical` / `unit_int` / `security`
commands it detected (from the fingerprint) into the `[init: …]` placeholders and drops any step
whose component the repo lacks. It installs no dependency of its own. Everything else about the gated,
per-item `AskUserQuestion` approval is identical to a config stub.

`.semgrep.yml` is intentionally **not** stubbed — semgrep runs with `--config auto` (its OSS
ruleset) when no project config exists, so no scaffold is needed.

Scaffolding is a mutation, so it is **gated by the same per-item `AskUserQuestion`** as a binary
install — the user approves the config write explicitly. The dep is installed alongside the stub so
the pairing is runnable. `--init` should confirm a copied stub matches the installed tool version
(pinned schema/toolchain refs can drift).

---

## Writing `steps.<key>` and flipping `init`

`--init` writes one `steps.<key>` entry per step it touched, using the persisted vocabulary and the
`reason`/`chosen` fields — **the schema, statuses, and required-field rules are defined in
`../../shared/refs/policy-schema.md`; this spec does not restate them.** In outline:

- **installed / already present** → `ready` (+ `chosen`).
- **user skipped, won't revisit** → `opted_out` (+ `reason`).
- **user skipped, will revisit / paid-only** → `deferred` (+ `reason`).
- **not in `required_buckets`** → `n/a` (+ `reason`).
- **known unresolved gap left as-is** → `missing` (+ `reason`).

On completion `--init` **flips `init:true`** (from the `{init:false}` seed `/msg --init` wrote) and
stamps `generated` + `generated_by: "pre-merge --init"`. The gate then consumes each entry via the
policy-schema read-contract (§3 `steps.<key>`): `ready` with no live tool → one `medium`
`policy-mismatch` finding then the no-tooling path; `opted_out`/`n/a` → skip silently;
`missing`/`deferred` → the existing `no_tooling` note. `--init`'s job is to *record*; the gate's job
is to *read*.

The written file must round-trip clean — re-loading it in a gate run produces **zero** validation
warnings (AC-S6). Never write `installed`, an unknown step-key, or a step-key outside the closed
15-key vocabulary.

---

## v3 — preflight ingestion → `components[]`

> **v3 (P2 assembly, P3 cutover).** `--init` runs a preflight-driven assembly step: it
> runs the `preflight-check-*.sh` family, ingests their normalized reports, and writes the
> `components[]` manifest into `devkit/policy.json` — the resolved instance of the
> [`../../shared/refs/component-catalog.md`](../../shared/refs/component-catalog.md)
> defaults. The single monolithic `pre-merge` tooling detector is **retired** (deleted at
> v3 P3) — the per-check `preflight-check-*.sh` family is the only detector now, and the
> executor reads each component's resolved `run` from the manifest. The check-report shape is
> [`../../shared/refs/check-report-schema.md`](../../shared/refs/check-report-schema.md).

The assembly runs **after** the interview + gated install (so a just-installed tool is
detected) and **before** the write:

1. **Run all checks.** Execute every `.claude/scripts/preflight-check-*.sh` (ids 01–17,
   `15` retired). Each detects its own tooling/surface and writes a normalized `detect`
   report to `.pre-merge/preflight/<slug>.json` + stdout (AC-CK2/CK3). A missing runner
   is never fatal — the check emits `present:false` + `status:no_tooling`/`n/a`.
   Mandatory checks (`security`, `migration`) always emit a report even when nothing is
   detected (AC-PF2).
2. **Ingest the 16 reports.** For each, validate it round-trips against the check-report
   schema (AC-CK5); reject a malformed report rather than assembling a bad entry.
3. **Assemble `components[]`** (AC-CAT9): start from the catalog default row for each
   `nn`; overlay the detection (`present`, `run`, `tooling`, `status`); apply user
   overrides from the interview (`opted_out`/`deferred` decisions, any user-set
   `criticality`). Each row carries its catalog `needs_env` default (C23);
   `regression.needs_env` is the one resolved value (suite composition, AC-SBX8).
   Ingestion needs **zero** per-check special-casing (AC-CK7) — one uniform loop keyed
   on `nn`. Write the **`env_provision`** resolution (C23, AC-SBX6) beside
   `components[]` from the provisioner interview above.
4. **Validate the DAG is acyclic** (AC-PF3): topo-check the union of every component's
   `depends_on`. A cycle → report it and write **no** manifest (leave `policy.json`
   unchanged).
5. **Write `components[]`** with **no `order` field** (AC-PF4 — ordering is the
   executor's runtime topo-sort) and **stamp `source_signature`** (AC-UP4) — the
   sha256 defined in `policy-schema.md` over the sorted `id:present:run:tooling.chosen`
   lines across all reports.
6. **Everything `--init` already did stays:** the interview, the gated per-item install,
   and the `init:true` flip on completion.

### Q2 — `steps.*` migration (dual-write dropped at P3)

On a **pre-v3** `policy.json` (has `init`/`release_flow`, no `components[]`), `--init`
rewrites the old `steps.*` states into `components[]` **once**, per the mapping table in
`policy-schema.md` (`ready`→`present:true`; `opted_out`/`n/a`→`present:false` + status
**preserved**; `missing`/`deferred`→`present:false` + status). **At v3 P3 the pre-merge
`steps` dual-write is dropped** — the executor reads run-vs-skip from `components[]`
presence (AC-PF6), not the §3 `steps` consult, so `--init` no longer needs to keep
pre-merge's `steps.*` coherent. It still writes the `ci`/`deploy_*`/`smoke` step-keys that
**post-merge** and the green-CI check read (those consumers are not yet on an executor).

---

## Enabling the flag — the test-selection interview (`policies.test_selection`)

The one **policy** question `--init`/`--update` own beyond the gap interview:
*should the gate run only the tests your diff can break, instead of the whole
suite?* It is a decision, never a detection result — so it is asked, recorded, and
then left alone. Schema + read-contract:
[`../../shared/refs/policy-schema.md`](../../shared/refs/policy-schema.md)
§ `policies.test_selection` / §2c; the run-time rule it switches on:
`refs/executor.md` §3c.

**Asked only when a test suite is detected** — i.e. at least one selection-capable
component (`unit`, `integration`, `regression`) is `present` in the assembled
manifest. No test suite ⇒ no question, no key, nothing to explain. Runs **after**
the `components[]` assembly (the answer needs the resolved `run_minified` slots and
the detected platforms), as **one** `AskUserQuestion`:

1. **Explain the trade — one paragraph.** Minified runs select *affected(diff) ∪
   the critical floor* inside `unit`/`integration`/`regression`, so a small PRD
   stops paying for the whole suite at every gate run; the full suite still runs,
   just later, at the declared backstop. It shifts **when** the full cost is paid,
   never **whether**. Say both halves — the win and the deferral — in the same
   breath.
2. **Verify the backstop before accepting it.** `full_run_backstop` is required
   when `enabled:true`, and `--init` checks the named one actually exists:

   | `full_run_backstop` | Verified by |
   |---|---|
   | `ci` | a `.github/workflows/*.yml` triggering on `pull_request` (the same detection the `ci` step-key uses, above) **and** `policies.github_actions.enabled` ≠ `false` |
   | `post-merge` | `policies.release_flow.mode == "staged"` — there is a staging stage to run the full suite at |
   | `both` | **both** of the above verify |

3. **No verified backstop ⇒ warn loudly + explicit override (AC-TS8).** Name what
   is missing (no `pull_request` workflow / Actions opted out / `direct` flow) and
   state plainly that enabling now means **nothing runs the full suite anywhere**.
   Require an explicit *"enable anyway"* **plus** a `reason`; then honor it and
   record both. Never enable on a shrug, and never silently downgrade the answer to
   `false` — the decision stays the user's.
4. **On enable — run the initial tagging pass** so the critical floor is non-empty
   from day one instead of accumulating over the first N PRDs. This is
   `refs/protocol-update-criticality.md` in **full-inventory mode** (§§1–4 with no
   `criticality_review` stamp to diff against): propose with cited evidence → one
   reviewable gate → write the approved markers as one
   `test(criticality): tag prd-<n>..<m> additions` commit → stamp
   `criticality_review`. Same machinery, same human gate — not a second
   implementation.
5. **Write the key** — `enabled`, `reason`, `full_run_backstop`, plus the
   catalog-defaulted `force_full_paths` / `tiers` / `max_affected_ratio` /
   `critical_markers` resolved for the detected platforms
   ([`../../shared/refs/component-catalog.md`](../../shared/refs/component-catalog.md)).
   `enabled:true` with no `reason` is honored + one `unjustified-policy` warn
   (AC-S3), like every other policy justification.

**Settled decision — never re-prompted unasked (AC-UP2 pattern).** Once written,
`--update` leaves `policies.test_selection` alone exactly as it leaves an
`opted_out` step or a user-set `criticality`: it reconciles **facts** (a
`run_minified` that appeared or vanished, a newly-detected platform's
`critical_markers` default), never the decision. *Settled* means not re-prompted
**unasked** — the user can always reopen it explicitly (`/pre-merge --update`,
`/msg --update`), which is exactly how the disable below is performed.

### Disabling — one `--update` run, and it is complete (AC-TS12)

One run that flips `enabled:false` **is** the off switch. There is no teardown
step, no cleanup mode, no second command — because every other artifact the
feature created is **inert by design** when the key is off:

| Artifact | State after disable |
|---|---|
| critical tags in test code / `Critical.xctestplan` / `@Critical` annotations | inert markers — a runner ignores them unless invoked with the selection filter; harmless to keep, instantly reusable on re-enable |
| `components[].run_minified` | never consulted — the executor's §3c rule is only entered when selection resolves on; it runs `run` |
| `tiers`, `force_full_paths`, `critical_markers`, the `criticality_review` stamp | dead config — read **only** inside the selection path |
| staleness nudge + untagged-test count | not computed — the count is taken only on a minified run |
| verdict `test_selection` block / pipeline-line suffix | absent — emitted only when selection actually ran |

The disable run ends with a **one-line retained-inert audit** naming what remains
and that it is inert — e.g. *"test_selection disabled — 48 critical tags and 3
`run_minified` commands retained (inert); re-enable via `/pre-merge --update`."*
It **never** offers to strip the tags or the `run_minified` entries: deleting
reviewed tags destroys the curation investment and makes re-enabling expensive.
Retention is the point.

Escalation ladder, for clarity: `--full` (this run only, nothing written) →
`--update` / `/msg --update` disable (repo-wide, one run, complete).

---

## `--update` — reconcile the manifest with reality

`/pre-merge --update` refreshes an existing manifest without a full re-setup. It
reconciles **facts about the code**, never settled policy choices.

1. **Re-run the preflight checks** — same `preflight-check-*.sh` family, fresh
   `.pre-merge/preflight/<slug>.json` reports.
2. **Diff** the fresh detect reports against the recorded `components[]`: which `present`
   flipped (tool added/removed), which `active_when` surface appeared/vanished (first
   migration, new API/mobile surface), any newly-detected component not yet in the
   manifest.
3. **Present the delta for approval BEFORE writing** (AC-UP1) — a compact
   added/changed/removed table; nothing is written until the user approves.
4. **Apply only** (AC-UP2):
   - `present` flips (a runner appeared or disappeared),
   - `active_when` flips (a surface appeared or disappeared),
   - **new** components, seeded with **catalog defaults**,
   - `regression.needs_env` re-resolution (C23/AC-SBX8 — the suite's composition
     changed) and `env_provision` provisioner flips (a compose file / testcontainers
     dep appeared or vanished) — both **facts**, re-detected like `present`.
   It **never** re-prompts a settled `opted_out`/`n/a` decision, **never** changes a
   **user-set** `criticality`, and **never** re-prompts a settled
   `policies.test_selection` — those are policy, not facts. It does refresh that
   key's **factual** halves (a `run_minified` that appeared or vanished, a
   newly-detected platform's `critical_markers` default) and it is where an
   **explicit** enable/disable is performed (§ *Enabling the flag* — the disable
   is complete in this one run, AC-TS12).
5. **Fill genuinely-new gaps** by reusing `--init`'s gated per-item install/scaffold
   offer (AC-UP3) — a newly-detected-but-untooled component follows the same
   OSS-first `AskUserQuestion` path.
6. **Restamp `source_signature`** (AC-UP4) and stamp `generated_by: "pre-merge --update"`.
   Re-validate the DAG (AC-PF3) before writing. As of v3 P3 the pre-merge `steps` dual-write
   is dropped (the executor runs from `components[]`); `--update` only touches the
   post-merge-owned `ci`/`deploy_*`/`smoke` step-keys, same as `--init`.

`--update` never runs the gate, opens a PR, merges, or deploys — same boundaries as
`--init`. A pre-v3 `policy.json` with no `components[]` is an `--init` case, not
`--update` (there's nothing to reconcile against) — `--update` says so and points to
`--init`.

### Gate staleness nudge (Fork E — the gate stays a pure reader)

A normal `/pre-merge` run **recomputes** `source_signature` cheaply and, on mismatch,
emits *"pipeline may be stale — run `/pre-merge --update`"*, then **proceeds on the
current manifest**. The gate **never** writes `policy.json` or mutates `components[]` —
only `--init`/`--update` write it (AC-UP5/UP6). This nudge lives in the executor's
manifest-read prose (`refs/executor.md` §0).

Its **test-tree sibling** works identically and is defined in
`refs/protocol-update-criticality.md`: a *minified* run counts untagged tests
read-only against the `criticality_review` stamp and, over the threshold (default
25), prints *"N untagged tests since the last criticality review — run
`/pre-merge --update-criticality`"*, then proceeds. Same contract — the gate reads,
never writes a tag or a policy key (AC-TS2).

---

## Boundaries (what `--init` never does)

- Never runs the pre-merge protocol, opens a PR, merges, or deploys (AC-DR1).
- Never writes `devkit/PLATFORMS.md` — it *reports* PLATFORMS.md-shaped gaps and delegates to
  `/msg --init` (that file stays `/msg --init`'s; policy-schema.md's writer table has the boundary).
- Never installs a paid/SaaS tool (AC-DR3).
- Never mutates without an explicit per-item `AskUserQuestion` approval (AC-DR2).
- Never writes `policies.github_actions` — it only *reads* it to decide whether the missing `ci`
  workflow is a gap or a settled opt-out (and to verify a `ci` backstop, § *Enabling the flag*).
  Changing that decision is `/msg --update`'s job. `policies.test_selection` is the asymmetric
  case: pre-merge `--init`/`--update` **do** write it (shared with `/msg --update`), because the
  interview that sets it needs the resolved manifest.
- Never writes a **critical tag** into a test file — that is `--update-criticality`'s write
  (`refs/protocol-update-criticality.md`), which `--init` only *invokes* for the initial tagging
  pass under its own human gate.
