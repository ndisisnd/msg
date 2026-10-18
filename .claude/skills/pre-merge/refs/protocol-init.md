---
name: pre-merge-protocol-init
description: Spec for pre-merge setup (runs inline on the first /pre-merge run, then the gate continues) and /pre-merge --update — run the preflight checks, classify nulls against the catalog's applicability for the repo's platforms, ask the real gaps in batches, gated-install them OSS-first, assemble the delta-only components[] manifest in devkit/policy.json, and scaffold the devkit/ENV.md env contract.
type: reference
---

# pre-merge setup (first run) and `/pre-merge --update`

The setup half of the pre-merge gate. **It runs by itself on the first `/pre-merge`
run** — no `components[]` in `devkit/policy.json` ⇒ setup runs inline in the main
conversation, saves `devkit/policy.json`, then **the gate continues in the same run**
(`executor.md` §0). There is no separate setup command; to redo or refresh setup, run
`/pre-merge --update`. It **detects** each step's tooling, **interviews** the user
about the real gaps, **offers to install** the missing pieces (gated, per-item, OSS-first), and
**records** every decision into `devkit/policy.json` — turning today's silent "no tooling → skip"
into an explicit, persisted `components[]` decision the gate reads at run time.

Setup itself **never opens a PR, never merges, never deploys, and never writes
`devkit/PLATFORMS.md`** (the gate that follows a first-run setup runs as usual). Its only outputs are repo mutations under explicit per-item
approval (binaries, stub configs) and the `policy.json` write.

The `devkit/policy.json` schema, status vocabulary, validation rules, and gate read-contract are
defined once in **`../../shared/refs/policy-schema.md`** — the authority. This file cites it for
anything schema-shaped and never redefines it.

---

## Shared setup contract

Both gate skills run the same seven-step setup contract. Pre-merge's flavor:

1. **Prerequisites** — `jq` (the detector needs it) and a `git` remote. Offer `brew install jq` if
   missing; without a remote, note that PR-shaped steps are inert. (`gh` auth is merge's
   concern.)
2. **Load or seed** the policy file — read `devkit/policy.json` if present (re-run = update in
   place, never overwrite from scratch); else start empty.
3. **Detect** — run the `script-preflight-*.sh` family (the preflight ingestion below) and resolve the platform profile.
4. **Interview — in batches, gaps only** (§ *Interview + gated-install flow*). Up to **4**
   related questions per `AskUserQuestion` prompt, each with the recommended default as
   its first option. A question detection already answered is **not asked**. The tuning
   questions (mobile matrix, a11y, regression composition) are asked in the same
   batches when detection left them open — never postponed, never dropped
   (§ *Component questions*). `policies.test_selection` is not raised at all. Every
   answer is recorded, including "skip" and "N/A", so the choice is durable and the
   next run does not re-ask. A new repo expects about 2–3 prompts.
5. **Offer install** — for each gap the user wants filled, run the OSS-first command, gated
   per-item. A tool installed this run is persisted as `ready` — never `installed` (that
   is a transient terminal-display state only; see policy-schema.md's status vocabulary).
6. **Write** `devkit/policy.json` via `.claude/scripts/script-policy-set.py` — the one
   sanctioned writer — as the **last** write of setup, with `--set init=true` and
   `--stamp-by "pre-merge setup"` (stamps `generated` + `generated_by` from the system
   clock). `--stamp-by` alone never sets `init`; the explicit `--set init=true` is what
   flips it. The written file must re-load with **zero** validation warnings. Scaffold
   `devkit/ENV.md` in the same pass.
7. **Summary** — a step→status table to the terminal, then **continue into the gate**
   (first run) or end (`--update`). Setup opens no PR and merges nothing.

---

## Detection source

The `script-preflight-*.sh` family emits one normalized detect report per component, together
covering the full fingerprint of detected tooling — one slot per runner (the probe primitives
live in `script-check-common.sh`).
**Every `null`/`no_tooling` slot is a candidate gap.** Setup does not re-detect by hand; it
reads the reports and the repo's target platforms, then classifies.

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
| `smoke_runner` | `smoke` |
| `security_scanners[]`, `secret_scanner` | `security` |
| _(static SQL scan — no runner slot)_ | `migration` |
| _(subagent — no runner slot)_ | `prd-consistency` · `manual-test-plan` |
| _(`.github/workflows/*.yml` presence — no runner slot)_ | **`steps.ci`** — the one non-component key setup writes |

**Cross-reference against the catalog's applicability.** Read the repo's target platforms
from `devkit/PLATFORMS.md` (the `platform` column): a `null` slot is only a **gap** if the
component's catalog `platforms` applicability covers one of those targets
(`../../shared/refs/component-catalog.md` — the same rule as the executor's coverage-gap
check, `executor.md` §1b). A `null` slot whose component does **not** apply (e.g. `a11y` on a
backend-only repo) is *correctly absent* — propose it as `n/a`, never nag it as a gap. The
platform profile never decides this: it only sets strictness (`platform-profiles.md`). The
`security` and `migration` safety-floor steps apply everywhere, so their nulls are always
real gaps, never `n/a`.

> `migration` has no external binary — it's pre-merge's static SQL-safety scan. Setup records it
> `ready` when the diff surface warrants it and `n/a` for repos with no migrations; there is
> nothing to install.

> **Component questions — asked in the same batches, only when detection left them
> open.** Several components can be *tuned* by a project fact. Setup asks these in the
> interview batches, recommended default first, and skips any that detection answered:
>
> | Component | Asked when | Recommended default (first option) |
> |---|---|---|
> | `mobile` | the repo ships iOS/Android and detection found no matrix (`.flutter-test-matrix.json` / project settings) | no enforced matrix |
> | `a11y` | the repo has a UI surface | the catalog default (`blocking`) |
> | `regression` | the suite's composition is ambiguous (`needs_env`) | `false` |
> | `migration` | never — no `hot_tables[]`; lock findings keep flat severity | — (set later via `--update` if the project wants size-aware grading) |
> | `load` | never — no declared `traffic_mix`; the runner's own profile is used | — (`--update` on request) |
> | `api` | never — no `consumers[]`; breaking-change findings name endpoint + change | — (`--update` on request) |
>
> The gate stays a pure reader of these answers — it never writes `policy.json`.

> **Env provisioner (C23).** When any `needs_env: true` component is present
> (catalog `env` column — integration, migration, e2e, a11y, perf, load, smoke, mobile,
> api-live), setup **detects** the project's sandbox provisioner candidates —
> `docker-compose*.yml` / a testcontainers dep / an ephemeral-DB-branch CLI (e.g.
> Neon/`pg_tmp`) / a deploy command / a mobile simulator — and asks **one** question in
> the interview batches to confirm the pick (or declare one, or skip); a single clear
> candidate is the recommended first option. It also records the migration
> framework's up/down commands for the round-trip (`platform/protocol-migration.md`
> § *Round-trip*) on the `migration` component's tooling. When **two**
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
> Alongside it, setup detects/asks for the **committed seed script** (S-Q1:
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

> **Regression suite composition.** Setup resolves **`regression.needs_env`** from the
> accumulated suite's composition: integration-level tests (DB/network-touching —
> detectable from the suite's imports/markers) → `true`; a pure-unit suite → `false`;
> **ambiguous → asked in the interview batches** (recommended: `false`). `--update` re-resolves it as a fact when the
> suite's composition changes.

> `ci` has no runner slot either — it's the **CI workflow** that runs the gate on the PR and
> produces the status checks that merge's "green CI" and branch protection depend on. Detect
> it directly (not from the fingerprint): a repo has a gap when **no** `.github/workflows/*.yml`
> triggers on `pull_request`.
>
> ```bash
> grep -lE 'pull_request' .github/workflows/*.yml .github/workflows/*.yaml 2>/dev/null
> ```
>
> Empty result → gap: nothing runs the gate on the PR, so "all checks green" is **vacuously true**
> and branch protection has no check to require. Present → record `ci` as `ready`. Setup
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
> never `n/a`. Setup never writes `policies.github_actions`; that decision belongs to
> `/msg --init` / `/msg --update` and is only read here. `steps.ci` stays this protocol's own key
> (merge reads it, never writes it).

**Covered:** every catalog component (`component-catalog.md`), plus the cross-cutting `ci`
workflow. The `deploy_staging` / `deploy_production` / `smoke` **step-keys** are
**merge's** — pre-merge setup leaves them untouched. (merge's setup *reads*
the `ci` record but never writes it — see its `protocol-init.md`.)

---

## Gap taxonomy — the flavors

Every gap the detector surfaces is one of these flavors, read off the detector's own signals (plus, for `ci`, the `policies.github_actions` decision):

| Flavor | How the detector shows it | Setup action | Recorded status |
|---|---|---|---|
| **Binary missing** | `command -v` slot empty (gitleaks, semgrep, trivy, k6, hurl, osv-scanner…) | offer the install command (per-item, gated) | `ready` on install · `deferred`/`opted_out` on decline |
| **Config missing** | dep may exist but no `eslint.config.*` / `playwright.config.*` / `.semgrep.yml` etc. | scaffold a **minimal stub config** + the dep | `ready` on scaffold · `deferred`/`opted_out` on decline |
| **Workflow missing** | no `.github/workflows/*.yml` triggers on `pull_request` (the `ci` gap) **and** `policies.github_actions.enabled ?? true` is true | scaffold `pre-merge.yml` with the detected gate commands substituted in | `ready` on scaffold · `deferred`/`opted_out` on decline |
| **Actions opted out** | same detector signal, but `policies.github_actions.enabled` is `false` | not a gap — offer nothing, report nothing missing | `opted_out` (the policy's `reason`) |
| **N/A for surface** | slot `null` **and** the component's catalog applicability covers none of the repo's target platforms | record only — offer nothing | `n/a` (with `reason`) |

Declining any offered install always records `opted_out` (won't revisit) or `deferred` (will
revisit) **with a `reason`** and installs nothing. Both non-`ready` statuses require a
`reason` per the schema.

**Secret scanner — the safety-floor exception (C9).** The `security` secret scanner (gitleaks/trufflehog) is **not** an ordinary declinable tool. Setup **strongly offers** it and,
if the user declines, records the decision as an explicit **safety-floor gap** (not a quiet
`opted_out`): the interview states that **the gate will `blocker` on every run until a secret
scanner is configured** — there is no green-gate path without secret-scan coverage (`refs/universal/protocol-security.md`, C9). The **install itself still goes through per-item
approval** (no forced mutation); C9 changes the *framing and the recorded gap*, never
the consent model. Every other `security` layer (SAST / deps / container / `/cook`) stays an
ordinary best-effort gap — declining it is a plain note, not a floor gap.

---

## OSS-first install catalog

**Reputable, open-source, free only.** Setup offers the Preferred tool first, the OSS fallback if
the user prefers it, and **never auto-offers a paid/SaaS tool**. When a step's only real
option is paid, setup **names it, explains why**, and records `deferred`/`opted_out` with the paid
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

Ask the real gaps (after the applicability cross-reference) **in batches**: up to **4
related questions per `AskUserQuestion` prompt** (for example the mechanical tools in one
prompt, the test runners in the next), each question with the **recommended default as
its first option**. **Skip every question detection already answered.** Each question
is still its own choice — a batch is never a bulk "install all", and every install is
still approved per item:

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

**Re-run behavior.** `--update` reads the existing `policy.json` and updates it in
place. A step already `opted_out` is **not** re-prompted unless the user explicitly asks to
re-tune. Answers persist across runs precisely so the interview shrinks each time.

---

## Minimal-stub config scaffolding

For the **config-missing** flavor, setup copies a **minimal runnable stub** — just enough that the
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

`pre-merge.yml` is the one stub that is **command-dependent** and **language-dependent**:
setup copies it to `.github/workflows/pre-merge.yml`, keeps **only** the `setup:` block that
matches the detected language (node / python / go / rust / flutter — for node, the detected
package manager's install command), deletes the other blocks, substitutes the `mechanical` /
`unit` / `security` commands it detected (from the fingerprint) into the `[setup: …]`
placeholders, and drops any step whose component the repo lacks. A language with no block
keeps the `setup: other` placeholder, and the summary names it as the one line to fill in.
The scaffolded file never ships Node steps into a non-Node repo. It installs no dependency of its own. Everything else about the gated,
per-item `AskUserQuestion` approval is identical to a config stub.

`.semgrep.yml` is intentionally **not** stubbed — semgrep runs with `--config auto` (its OSS
ruleset) when no project config exists, so no scaffold is needed.

Scaffolding is a mutation, so it is **gated by the same per-item `AskUserQuestion`** as a binary
install — the user approves the config write explicitly. The dep is installed alongside the stub so
the pairing is runnable. Setup should confirm a copied stub matches the installed tool version (pinned schema/toolchain refs can drift).

---

## Recording each decision and setting `init: true`

Every decision lands on its **`components[]` entry's `status`**, using the persisted
vocabulary — **the schema, statuses, and required-field rules are defined in
`../../shared/refs/policy-schema-pre-merge.md`; this spec does not restate them.** In outline:

- **installed / already present** → `ready` (+ the resolved `run` and `tooling`).
- **user skipped, won't revisit** → `opted_out` (+ `reason`), `present:false`.
- **user skipped, will revisit / paid-only** → `deferred` (+ `reason`), `present:false`.
- **not applicable to the repo's platforms** → `n/a` (+ `reason`), `present:false`.
- **known unresolved gap left as-is** → `no_tooling` (+ `reason`), `present:false`.

The one **`steps`** key setup writes is `ci` (`../../shared/refs/policy-schema-merge.md` § `steps.<key>`) — merge's green-CI
check reads it. Pre-merge itself never consults `steps`.

On completion setup **writes `init: true`** (over the `{init:false}` seed `/msg --init` wrote)
and stamps `generated` + `generated_by: "pre-merge setup"` — in one final call:

```bash
.claude/scripts/script-policy-set.py --file devkit/policy.json \
  --set init=true --stamp-by "pre-merge setup"
```

`--stamp-by` alone never touches `init`, so the explicit `--set init=true` is required.
Setup's job is to *record*; the gate's job is to *read*.

The written file must round-trip clean — re-loading it in a gate run produces **zero** validation
warnings. Never write `installed`, and never write a `steps` key other than `ci`.

---

## Preflight ingestion → `components[]`

Setup runs a preflight-driven assembly step: it runs the `script-preflight-*.sh`
family, ingests their normalized reports, and writes the `components[]` manifest into
`devkit/policy.json`. The per-check `script-preflight-*.sh` family is the only detector;
the executor reads each component's resolved `run` from the manifest and every
**constant** from [`../../shared/refs/component-catalog.md`](../../shared/refs/component-catalog.md).
The check-report shape is
[`../../shared/refs/check-report-schema.md`](../../shared/refs/check-report-schema.md).

The assembly runs **after** the interview + gated install (so a just-installed tool is
detected) and **before** the write:

1. **Run all checks.** Execute every `.claude/scripts/script-preflight-*.sh` (ids 01–17,
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
6. **Everything else setup does stays:** the batched interview, the gated per-item
   install, and the final `--set init=true` write.

---

## Enabling the flag — the test-selection interview (`policies.test_selection`)

Test selection is **opt-in and off by default** — an absent key means the gate runs
full suites, which is the safe shape. So setup **does not ask about it**: it seeds
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
   when `enabled:true`, and the interview checks the named one actually exists:

   | `full_run_backstop` | Verified by |
   |---|---|
   | `ci` | a `.github/workflows/*.yml` triggering on `pull_request` (the same detection the `ci` step-key uses, above) **and** `policies.github_actions.enabled` ≠ `false` |
   | `merge` | `policies.release_flow.mode == "staged"` — there is a staging stage to run the full suite at |
   | `both` | **both** of the above verify |

3. **No verified backstop ⇒ warn loudly + explicit override.** Name what
   is missing (no `pull_request` workflow / Actions opted out / `direct` flow) and
   state plainly that enabling now means **nothing runs the full suite anywhere**.
   Require an explicit *"enable anyway"* **plus** a `reason`; then honor it and
   record both. Never enable on a shrug, and never silently downgrade the answer to
   `false` — the decision stays the user's.
4. **On enable — run the initial tagging pass** so the critical floor is non-empty
   from day one instead of accumulating over the first N PRDs. This is
   `protocol-criticality.md` in **full-inventory mode** (§§1–3 with no
   `criticality_review` stamp to diff against): tag with cited evidence → one
   `test(criticality): …` commit → stamp `criticality_review`. Same machinery as the
   gate's automatic pass (`executor.md` §3c.4) — not a second implementation.
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
| critical-test tagging pass (`executor.md` §3c.4) | not run — it runs only when selection is on |
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

1. **Re-run the preflight checks** — same `script-preflight-*.sh` family, fresh
   `.pre-merge/preflight/<slug>.json` reports.
2. **Diff** the fresh detect reports against the recorded `components[]`: which `present`
   flipped (tool added/removed), which `active_when` surface appeared/vanished (first
   migration, new API/mobile surface), any newly-detected component not yet in the
   manifest.
3. **Present the delta for approval BEFORE writing** — a compact
   added/changed/removed table; nothing is written until the user approves.
4. **Apply only**:
   - `present` flips (a runner appeared or disappeared),
   - `active_when` changes — an approved trigger change is written as the entry's own
     `active_when` override in `components[]`, which `script-pipeline-resolve.py` reads
     before the catalog default, so it takes effect on the next run
     (`../../shared/refs/policy-schema-pre-merge.md` § *optional per-entry overrides*),
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
5. **Fill genuinely-new gaps** by reusing setup's batched, gated per-item
   install/scaffold offer — a newly-detected-but-untooled component follows the same
   OSS-first path.
6. **Restamp `source_signature`** and stamp `generated_by: "pre-merge --update"`
   — both via `.claude/scripts/script-policy-set.py`. Re-validate the DAG
   before writing. `--update` writes no step-key other than `ci`, same as setup.

`--update` never runs the gate, opens a PR, merges, or deploys. A `policy.json` with no
`components[]` has nothing to reconcile against, so `--update` runs the full setup
instead (and ends after the save — it does not continue into the gate).

### Gate staleness nudge (read-only — the gate never writes policy)

The **manifest** nudge (`source_signature` mismatch → *"pipeline may be stale — run
`/pre-merge --update`"*) is stated in `executor.md` §0. It prints one line and
proceeds; setup and `--update` write.

---

## Boundaries (what setup never does)

- Never opens a PR, merges, or deploys (on a first run, the gate that follows is a normal gate run).
- Never writes `devkit/PLATFORMS.md` — it *reports* PLATFORMS.md-shaped gaps and delegates to
  `/msg --init` (that file stays `/msg --init`'s; policy-schema.md's writer table has the boundary).
- Never installs a paid/SaaS tool.
- Never mutates without an explicit per-item `AskUserQuestion` approval.
- Never writes `policies.github_actions` — it only *reads* it to decide whether the missing `ci`
  workflow is a gap or a settled opt-out (and to verify a `ci` backstop, § *Enabling the flag*).
  Changing that decision is `/msg --update`'s job. `policies.test_selection` is the asymmetric
  case: pre-merge setup/`--update` **do** write it (shared with `/msg --update`), because the
  interview that sets it needs the resolved manifest.
- Never writes a **critical tag** itself — tags are written by the critical-test tagging pass
  (`protocol-criticality.md`), which setup only *invokes* for the initial tagging pass when
  test selection is enabled.
