---
name: pre-merge-protocol-init
description: Spec for /pre-merge --init and --update — run the preflight checks, cross-reference nulls against the Step-0 required_buckets, interview + gated-install the gaps OSS-first, assemble the delta-only components[] manifest in devkit/policy.json, and scaffold the devkit/ENV.md env contract.
type: reference
---

# `/pre-merge --init`

The setup half of the pre-merge gate. It **detects** each step's tooling, **interviews** the user
about the real gaps, **offers to install** the missing pieces (gated, per-item, OSS-first), and
**records** every decision into `devkit/policy.json` — turning today's silent "no tooling → skip"
into an explicit, persisted `components[]` decision the gate reads at run time.

`--init` **never runs the gate, never opens a PR, never merges, never deploys, and never writes
`devkit/PLATFORMS.md`**. Its only outputs are repo mutations under explicit per-item
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
3. **Detect** — run the `preflight-check-*.sh` family (the preflight ingestion below) and resolve the platform profile.
4. **Interview** — one `AskUserQuestion` per real **tooling gap** only. Component tuning
   questions are seeded with their documented default instead of being asked
   (§ *Component questions are seeded, not asked*), and `policies.test_selection` is not
   raised at all. Every answer is recorded, including "skip" and "N/A", so the choice is
   durable and the next run does not re-ask.
5. **Offer install** — for each gap the user wants filled, run the OSS-first command, gated
   per-item. A tool installed this run is persisted as `ready` — never `installed` (that
   is a transient terminal-display state only; see policy-schema.md's status vocabulary).
6. **Write** `devkit/policy.json` via `.claude/scripts/script-policy-set.py` — the one
   sanctioned writer. It stamps `generated` + `generated_by` from the system clock (`--stamp-by "pre-merge --init"`) and flips `init:true`. The written file must re-load
   with **zero** validation warnings. Scaffold `devkit/ENV.md` in the same pass.
7. **Summary** — a step→status table to the terminal. No gate run, no PR, no merge.

---

## Detection source

The `preflight-check-*.sh` family emits one normalized detect report per component, together
covering the full fingerprint of detected tooling — one slot per runner (the probe primitives
live in `preflight-common.sh`).
**Every `null`/`no_tooling` slot is a candidate gap.** `--init` does not re-detect by hand; it
reads the reports and the Step-0 profile, then classifies.

**Detector slot → component `id`** (the `components[]` entry the detection lands in —
one entry per catalog row; the slot names are the catalog's `run` column):

| Detector slot | component `id` |
|---|---|
| `mechanical_runners[]`, `build_tool` | `mechanical` |
| `test_runner` | `unit` · `integration` · `regression` |
| `e2e_runner` | `e2e` |
| `a11y_runner` | `a11y` |
| `perf_runner` (+ `bundle_analyzer`) | `perf` |
| `load_runner` | `load` |
| `api_runner[]` | `api` |
| `mobile_runner` | `mobile` |
| `coverage_runner` | `coverage` |
| `preview_deploy_cmd` (+ visual capture) | `preview` |
| `smoke_runner` | `smoke` |
| `security_scanners[]`, `secret_scanner` | `security` |
| _(static SQL scan — no runner slot)_ | `migration` |
| _(subagent — no runner slot)_ | `prd-consistency` · `manual-test-plan` |
| _(`.github/workflows/*.yml` presence — no runner slot)_ | **`steps.ci`** — the one non-component key `--init` writes |

**Cross-reference against `required_buckets`.** Resolve the Step-0 profile from `devkit/PLATFORMS.md` (`refs/platform-profiles.md`): a `null` slot is only a **gap** if its component is in the profile's
`required_buckets`. A `null` slot whose component is **not** required (e.g. `a11y` on a backend-only
repo) is *correctly absent* — propose it as `n/a`, never nag it as a gap (territory). The
`security` and `migration` safety-floor steps run in every profile, so their nulls are always real
gaps, never `n/a`.

> `migration` has no external binary — it's pre-merge's static SQL-safety scan. `--init` records it
> `ready` when the diff surface warrants it and `n/a` for repos with no migrations; there is
> nothing to install.

> **Component questions are seeded, not asked (default-and-defer).** Several components
> can be *tuned* by a project fact — `mobile`'s target `{platform, os}` matrix, `a11y`'s
> enablement/criticality, `regression`'s `needs_env` composition. **`--init` asks none of
> them.** It records the documented sane default silently and moves on, because a repo
> that has never run the gate has no basis to answer, and nine upfront questions are the
> most expensive part of first-run setup.
>
> | Component | Seeded default at `--init` | Asked when |
> |---|---|---|
> | `mobile` | the matrix detection resolved (`.flutter-test-matrix.json` / project settings); nothing declared ⇒ no enforced matrix | the first gate run where `mobile` actually activates |
> | `a11y` | the catalog default (`blocking`) for a UI surface | the first gate run where `a11y` actually activates |
> | `regression` | `needs_env` resolved from the suite's composition; ambiguous ⇒ `false` | the first gate run where the resolution is still ambiguous |
> | `migration` | no `hot_tables[]` — lock findings keep flat severity | only if the project asks for size-aware grading |
> | `load` | no declared `traffic_mix` — the runner's own profile is used | only if the project asks for a declared mix |
> | `api` | no `consumers[]` — breaking-change findings name endpoint + change | only if the project asks for consumer-named findings |
>
> **Ask-on-first-activation.** The first time a component actually runs in a gate run
> with its question unanswered, the gate prints **one** line naming the tuning it could
> use and the command that records it — *"`a11y` ran on its default (blocking); run
> `/pre-merge --update` to set its project-level enablement."* The answer is written by
> `--update` through its existing approved-delta path, so **the gate stays a pure
> reader** — it never writes `policy.json`. One nudge per component per repo; the
> defaults keep working if it is ignored forever.

> **Env provisioner (C23).** When any `needs_env: true` component is present
> (catalog `env` column — integration, migration, e2e, a11y, perf, load, smoke, mobile,
> api-live), `--init` **detects** the project's sandbox provisioner candidates —
> `docker-compose*.yml` / a testcontainers dep / an ephemeral-DB-branch CLI (e.g.
> Neon/`pg_tmp`) / a `preview_deploy_cmd` / a mobile simulator — and asks **one**
> `AskUserQuestion` to confirm the pick (or declare one, or skip). When **two**
> candidates apply at once (full-stack mobile: a simulator **and** a compose backend),
> record a composite **`stacks[]`** — one logical sandbox, both stacks. The answer is
> written into **`devkit/ENV.md`** — the committed env-setup contract
> ([`../../shared/refs/env-contract.md`](../../shared/refs/env-contract.md)): human prose
> (prerequisites, ports, seed-fixture location, gotchas) around **one** fenced `env`
> block carrying the neutral provision / seed / reset / teardown verbs. It is a devkit
> doc, **not** a `policy.json` key — one source of truth for env setup, shared with the
> humans and agents who also need it, following the `PLATFORMS.md` precedent.
>
> **Scaffold, don't interrogate.** Fill every value detection resolved; write a
> `[USER: …]` placeholder — naming exactly what to put there — wherever it didn't.
> `ENV.md` is **committed** (not gitignored): it is documentation.
>
> Alongside it, `--init` detects/asks for the **committed seed script** (S-Q1:
> migrate-from-zero + versioned fixture — never a prod-like snapshot) and the optional
> `perf`/`load` **`scale_factor`**, and may offer the companion stubs
> ([`stubs/docker-compose.test.yml`](stubs/docker-compose.test.yml),
> [`stubs/seed-test.ts`](stubs/seed-test.ts)) under the usual per-item approval —
> accepting them fills the matching verbs.
>
> **Skip / nothing detected ⇒ `provisioner: "none"`** — recorded, valid, and loud at
> gate time: every env-needing component then carries a `high` `sandbox-unprovisioned`
> finding per run (`refs/executor.md` §3b), never a silent pass. A remaining
> `[USER: …]` placeholder in a consumed verb resolves the same way. A provisioner
> without a seed script is also recorded and flagged loudly. The provisioner itself may
> be an install offer (e.g. Docker absent) under the normal per-item gate.

> **Regression suite composition.** `--init` resolves **`regression.needs_env`** from the
> accumulated suite's composition: integration-level tests (DB/network-touching —
> detectable from the suite's imports/markers) → `true`; a pure-unit suite → `false`;
> **ambiguous → `false`, recorded, and re-resolved on the first run that proves
> otherwise** (no upfront question). `--update` re-resolves it as a fact when the
> suite's composition changes.

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

**Covered:** every catalog component (`component-catalog.md`), plus the cross-cutting `ci`
workflow. The `deploy_staging` / `deploy_production` / `smoke` **step-keys** are
**post-merge's** — pre-merge `--init` leaves them untouched. (post-merge `--init` *reads*
the `ci` record at item 2 but never writes it — see its `protocol-init.md`.)

---

## Gap taxonomy — the flavors

Every gap the detector surfaces is one of these flavors, read off the detector's own signals (plus, for `ci`, the `policies.github_actions` decision):

| Flavor | How the detector shows it | `--init` action | Recorded status |
|---|---|---|---|
| **Binary missing** | `command -v` slot empty (gitleaks, semgrep, trivy, k6, hurl, osv-scanner…) | offer the install command (per-item, gated) | `ready` on install · `deferred`/`opted_out` on decline |
| **Config missing** | dep may exist but no `eslint.config.*` / `playwright.config.*` / `.semgrep.yml` etc. | scaffold a **minimal stub config** + the dep | `ready` on scaffold · `deferred`/`opted_out` on decline |
| **Workflow missing** | no `.github/workflows/*.yml` triggers on `pull_request` (the `ci` gap) **and** `policies.github_actions.enabled ?? true` is true | scaffold `pre-merge.yml` with the detected gate commands substituted in | `ready` on scaffold · `deferred`/`opted_out` on decline |
| **Actions opted out** | same detector signal, but `policies.github_actions.enabled` is `false` | not a gap — offer nothing, report nothing missing | `opted_out` (the policy's `reason`) |
| **N/A for surface** | slot `null` **and** the component is **not** in `required_buckets` | record only — offer nothing | `n/a` (with `reason`) |

Declining any offered install always records `opted_out` (won't revisit) or `deferred` (will
revisit) **with a `reason`** and installs nothing. Both non-`ready` statuses require a
`reason` per the schema.

**Secret scanner — the safety-floor exception (C9).** The `security` secret scanner (gitleaks/trufflehog) is **not** an ordinary declinable tool. `--init` **strongly offers** it and,
if the user declines, records the decision as an explicit **safety-floor gap** (not a quiet
`opted_out`): the interview states that **the gate will `blocker` on every run until a secret
scanner is configured** — there is no green-gate path without secret-scan coverage (`refs/universal/protocol-security.md`, C9). The **install itself still goes through per-item
approval** (no forced mutation); C9 changes the *framing and the recorded gap*, never
the consent model. Every other `security` layer (SAST / deps / container / `/cook`) stays an
ordinary best-effort gap — declining it is a plain note, not a floor gap.

---

## OSS-first install catalog

**Reputable, open-source, free only.** `--init` offers the Preferred tool first, the OSS fallback if
the user prefers it, and **never auto-offers a paid/SaaS tool**. When a step's only real
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
  success record the component `{ present: true, status: "ready", run: "<cmd>", tooling: {...} }`.
  A tool installed this run
  is persisted `ready`, never `installed`.
- **Config-missing flavor** → additionally scaffold the minimal stub config (below) so the gate has
  something runnable immediately.
- **Workflow-missing flavor (`ci`)** → no catalog tool; the only offer is **Scaffold `pre-merge.yml`** (copy the stub to `.github/workflows/`, substitute the detected gate commands) or **Skip**. Scaffold
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

**Re-run behavior.** A second `--init` reads the existing `policy.json` and updates it in
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
| `vitest.config.ts` | unit + integration + coverage | `vitest` + `@vitest/coverage-v8` |
| `playwright.config.ts` | e2e | `@playwright/test` |
| `.size-limit.json` | perf (bundle) | `size-limit` + `@size-limit/preset-app` |
| `pre-merge.yml` → `.github/workflows/` | ci | — (no dep; substitute the detected gate commands) |

`pre-merge.yml` is the one stub that is **command-dependent**: `--init` copies it to
`.github/workflows/pre-merge.yml`, then substitutes the `mechanical` / `unit` / `security`
commands it detected (from the fingerprint) into the `[init: …]` placeholders and drops any step
whose component the repo lacks. It installs no dependency of its own. Everything else about the gated,
per-item `AskUserQuestion` approval is identical to a config stub.

`.semgrep.yml` is intentionally **not** stubbed — semgrep runs with `--config auto` (its OSS
ruleset) when no project config exists, so no scaffold is needed.

Scaffolding is a mutation, so it is **gated by the same per-item `AskUserQuestion`** as a binary
install — the user approves the config write explicitly. The dep is installed alongside the stub so
the pairing is runnable. `--init` should confirm a copied stub matches the installed tool version (pinned schema/toolchain refs can drift).

---

## Recording each decision and flipping `init`

Every decision lands on its **`components[]` entry's `status`**, using the persisted
vocabulary — **the schema, statuses, and required-field rules are defined in
`../../shared/refs/policy-schema-pre-merge.md`; this spec does not restate them.** In outline:

- **installed / already present** → `ready` (+ the resolved `run` and `tooling`).
- **user skipped, won't revisit** → `opted_out` (+ `reason`), `present:false`.
- **user skipped, will revisit / paid-only** → `deferred` (+ `reason`), `present:false`.
- **not in `required_buckets`** → `n/a` (+ `reason`), `present:false`.
- **known unresolved gap left as-is** → `no_tooling` (+ `reason`), `present:false`.

The one **`steps`** key `--init` writes is `ci` (`../../shared/refs/policy-schema-post-merge.md` § `steps.<key>`) — post-merge's green-CI
check reads it. Pre-merge itself never consults `steps`.

On completion `--init` **flips `init:true`** (from the `{init:false}` seed `/msg --init` wrote)
and stamps `generated` + `generated_by: "pre-merge --init"` — all three via
`.claude/scripts/script-policy-set.py --stamp-by "pre-merge --init"`, which dates the file
from the system clock. `--init`'s job is to *record*; the gate's job is to *read*.

The written file must round-trip clean — re-loading it in a gate run produces **zero** validation
warnings. Never write `installed`, and never write a `steps` key other than `ci`.

---

## Preflight ingestion → `components[]`

`--init` runs a preflight-driven assembly step: it runs the `preflight-check-*.sh`
family, ingests their normalized reports, and writes the `components[]` manifest into
`devkit/policy.json`. The per-check `preflight-check-*.sh` family is the only detector;
the executor reads each component's resolved `run` from the manifest and every
**constant** from [`../../shared/refs/component-catalog.md`](../../shared/refs/component-catalog.md).
The check-report shape is
[`../../shared/refs/check-report-schema.md`](../../shared/refs/check-report-schema.md).

The assembly runs **after** the interview + gated install (so a just-installed tool is
detected) and **before** the write:

1. **Run all checks.** Execute every `.claude/scripts/preflight-check-*.sh` (ids 01–17,
   `15` retired). Each detects its own tooling/surface and writes a normalized `detect`
   report to `.pre-merge/preflight/<slug>.json` + stdout. A missing runner
   is never fatal — the check emits `present:false` + `status:no_tooling`/`n/a`.
   Mandatory checks (`security`, `migration`) always emit a report even when nothing is
   detected.
2. **Ingest the 16 reports.** For each, validate it round-trips against the check-report
   schema; reject a malformed report rather than assembling a bad entry.
3. **Assemble `components[]` — deltas only**. Each entry gets exactly the
   five detection fields (`id`, `present`, `run`, `run_minified`, `tooling`, `status`)
   plus any **explicit** user override from the interview (`opted_out`/`deferred` decisions with their `reason`, a user-set `criticality`, any component tuning hints the project has since supplied (`hot_tables[]`, `consumers[]`, `traffic_mix`, the mobile matrix), and `regression.needs_env` — the one resolved `needs_env`).
   **Do not copy catalog metadata into the manifest**: `nn`, `group`, `kind`, `cost`,
   `depends_on`, `active_when`, `platforms`, `mandatory`, the default `criticality`
   and every other component's `needs_env` resolve from
   [`component-catalog.md`](../../shared/refs/component-catalog.md) by `id` at run time.
   Copying them is what created the drift class this shape closes — a catalog
   change could never reach an existing manifest. Also **not** persisted: `test_selector` (audit-only; it
   stays in the check reports) and `source` (derivable from `id` + the catalog's
   `check` column). Ingestion needs **zero** per-check special-casing — one
   uniform loop keyed on `id`.
4. **Validate the DAG is acyclic**: topo-check the union of every present
   component's **catalog** `depends_on`. A cycle → report it and write **no** manifest (leave `policy.json` unchanged). `script-pipeline-resolve.py` exits `4` on a cycle;
   reuse it rather than hand-checking.
5. **Write `components[]`** with **no `order` field** (ordering is the executor's runtime topo-sort) and **stamp `source_signature`** — the
   sha256 defined in `policy-schema-pre-merge.md` over the sorted
   `id:present:run:tooling.chosen` lines across all reports. The write goes through
   `.claude/scripts/script-policy-set.py` (`--set components=<json>`), the one
   sanctioned `policy.json` writer — never a hand-authored edit.
5b. **Scaffold `devkit/ENV.md`** from the provisioner interview (below) — a devkit
   doc, not a policy key.
6. **Everything `--init` already did stays:** the interview, the gated per-item install,
   and the `init:true` flip on completion.

---

## Enabling the flag — the test-selection interview (`policies.test_selection`)

Test selection is **opt-in and off by default** — an absent key means the gate runs
full suites, which is the safe shape. So `--init` **does not ask about it**: it seeds
nothing, explains nothing, and adds no key. The interview below runs **on request** —
`/pre-merge --update` or `/msg --update`, or whenever the user asks to stop paying for
the whole suite on every run. Schema + read-contract:
[`../../shared/refs/policy-schema.md`](../../shared/refs/policy-schema.md)
§ `policies.test_selection` / §2c; the run-time rule it switches on:
`refs/executor.md` §3c.

**Meaningful only when a test suite is detected** — at least one selection-capable
component (`unit`, `integration`, `regression`) is `present` in the manifest. No test
suite ⇒ nothing to enable. It runs **after** the `components[]` assembly (the answer
needs the resolved `run_minified` slots and the detected platforms), as **one**
`AskUserQuestion`:

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

3. **No verified backstop ⇒ warn loudly + explicit override.** Name what
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
   `critical_markers` resolved for the detected platforms ([`../../shared/refs/component-catalog.md`](../../shared/refs/component-catalog.md)).
   `enabled:true` with no `reason` is honored + one `unjustified-policy` warn, like every other policy justification.

**Settled decision — never re-prompted unasked (pattern).** Once written,
`--update` leaves `policies.test_selection` alone exactly as it leaves an
`opted_out` step or a user-set `criticality`: it reconciles **facts** (a
`run_minified` that appeared or vanished, a newly-detected platform's
`critical_markers` default), never the decision. *Settled* means not re-prompted
**unasked** — the user can always reopen it explicitly (`/pre-merge --update`,
`/msg --update`), which is exactly how the disable below is performed.

### Disabling — one `--update` run, and it is complete

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
3. **Present the delta for approval BEFORE writing** — a compact
   added/changed/removed table; nothing is written until the user approves.
4. **Apply only**:
   - `present` flips (a runner appeared or disappeared),
   - `active_when` flips (a surface appeared or disappeared),
   - **new** components, seeded with **catalog defaults**,
   - `regression.needs_env` re-resolution (C23 — the suite's composition changed) — a **fact**, re-detected like `present`,
   - **`devkit/ENV.md` deltas** — a compose file appeared, a seed script moved, a
     placeholder is now resolvable. Proposed in the same approved-delta table; a
     hand-edited verb is never silently overwritten (`env-contract.md`).
   **Catalog metadata needs no reconcile at all** — the manifest never copied it, so a
   new `depends_on` edge or a shifted criticality default is live on the next run (this is the drift hole, closed by the delta-only shape).
   It **never** re-prompts a settled `opted_out`/`n/a` decision, **never** changes a
   **user-set** `criticality`, and **never** re-prompts a settled
   `policies.test_selection` — those are policy, not facts. It does refresh that
   key's **factual** halves (a `run_minified` that appeared or vanished, a
   newly-detected platform's `critical_markers` default) and it is where an
   **explicit** enable/disable is performed (§ *Enabling the flag* — the disable is complete in this one run).
5. **Fill genuinely-new gaps** by reusing `--init`'s gated per-item install/scaffold
   offer — a newly-detected-but-untooled component follows the same
   OSS-first `AskUserQuestion` path.
6. **Restamp `source_signature`** and stamp `generated_by: "pre-merge --update"`
   — both via `.claude/scripts/script-policy-set.py`. Re-validate the DAG
   before writing. `--update` writes no pre-merge `steps` entry; it only touches the
   post-merge-owned `ci`/`deploy_*`/`smoke` step-keys, same as `--init`.

`--update` never runs the gate, opens a PR, merges, or deploys — same boundaries as
`--init`. A `policy.json` with no `components[]` is an `--init` case, not
`--update` (there's nothing to reconcile against) — `--update` says so and points to
`--init`.

### Gate staleness nudges (read-only — the gate never writes)

Two nudges exist and neither lives here: the **manifest** nudge (`source_signature`
mismatch → *"pipeline may be stale — run `/pre-merge --update`"*) is stated in
`refs/executor.md` §0, and its **test-tree sibling** (untagged tests since the last
`criticality_review`) in `refs/protocol-update-criticality.md` § *Staleness nudge*.
Both print one line and proceed; the gate reads, `--init`/`--update`/
`--update-criticality` write.

---

## Boundaries (what `--init` never does)

- Never runs the pre-merge protocol, opens a PR, merges, or deploys.
- Never writes `devkit/PLATFORMS.md` — it *reports* PLATFORMS.md-shaped gaps and delegates to
  `/msg --init` (that file stays `/msg --init`'s; policy-schema.md's writer table has the boundary).
- Never installs a paid/SaaS tool.
- Never mutates without an explicit per-item `AskUserQuestion` approval.
- Never writes `policies.github_actions` — it only *reads* it to decide whether the missing `ci`
  workflow is a gap or a settled opt-out (and to verify a `ci` backstop, § *Enabling the flag*).
  Changing that decision is `/msg --update`'s job. `policies.test_selection` is the asymmetric
  case: pre-merge `--init`/`--update` **do** write it (shared with `/msg --update`), because the
  interview that sets it needs the resolved manifest.
- Never writes a **critical tag** into a test file — that is `--update-criticality`'s write (`refs/protocol-update-criticality.md`), which `--init` only *invokes* for the initial tagging
  pass under its own human gate.
