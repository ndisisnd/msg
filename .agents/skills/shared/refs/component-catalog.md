---
name: component-catalog
description: The single source of component metadata for both gates — the catalog defaults --init/--update seed into devkit/policy.json's components[]. Executor sequencing, folder placement, check-script naming, and reporting all key off this file.
type: reference
---

# The component catalog (keystone artifact)

`shared/refs/component-catalog.md` ships the **defaults** every gate starts from.
The per-project `devkit/policy.json` `components[]` array is the *resolved
instance*: catalog defaults + live detection + user overrides (`--init`/`--update`
seed it; see `pre-merge/refs/protocol-init.md`). The executor, the `refs/`
folder split, the `script-preflight-*` scripts, wave sequencing, and result
reporting all key off this file — nothing downstream re-derives component
metadata by hand.

## Entry schema

```
{ id, nn, group, kind, criticality, cost, depends_on[], active_when,
  platforms[], needs_env, mandatory, run, run_minified, ref, check }
```

Everything here except `run` / `run_minified` is a **constant** — identical in every
repo. The per-project `components[]` manifest therefore stores only the resolved
`run`/`run_minified`/`tooling`/`status`/`present` plus explicit user overrides, and
joins back to this table by `id` at run time (`policy-schema-pre-merge.md`
§ `components[]`). A catalog edit is live for every repo on the next gate run, with
no migration.

| Field | Meaning |
|---|---|
| `id` | component slug — matches the `protocol-<slug>.md` stem |
| `nn` | stable, zero-padded, **global** catalog id (group-orthogonal — a group change never renumbers a check); **never reused** |
| `group` | `universal` \| `platform` \| `prd` — the component's *gating source* (its folder, C3) |
| `kind` | `script` \| `subagent` \| `hybrid` \| `gate` |
| `criticality` | default grading tier; a platform profile may override it (Q1); `†` = config-driven (below) |
| `cost` | `cheap` \| `moderate` \| `expensive` — relative runtime, informs scheduling |
| `depends_on[]` | hard effect edges only (AC-CAT3) — see "Hard edges", below |
| `active_when` | the presence gate — when the component runs at all |
| `platforms[]` | **applicability**, not runner coverage (legend below) |
| `needs_env` | **C23** — `true` iff the component requires a running app/DB and therefore runs **inside** the ephemeral test-sandbox (legend `env` column; see "The env-needing tier", below). `false` = static/in-process, runs outside, never triggers provisioning |
| `mandatory` | `true` only for `security` and `migration` (AC-CAT4) — never opts out, only degrades per their own safety-floor rules |
| `run` | resolved by detection at `--init`/`--update` time from the Step 1 tooling fingerprint (`shared/refs/tooling-detection.md`) — the catalog names the **detection field**, not a fixed command |
| `run_minified` | **additive** — the **selection-capable** invocation of the same runner (affected ∪ critical), resolved by the same detection pass alongside `run`. Only the **selection-capable** components (`ˢᵉˡ` below — `unit`, `integration`, `regression`) can carry one; every other row is `null`. `null` ⇒ that component **always runs full**, silently (not a gap). Consumed only under `policies.test_selection` (`policy-schema-pre-merge.md`; `pre-merge/refs/executor.md` § *Test selection*) |
| `ref` | `<group>/protocol-<slug>.md` — the protocol file (prose + grading logic) |
| `check` | `script-preflight-<nn>-<slug>.sh` — the normalized detect script (Phase 2, C4) |

## The components (16)

**Ids `15` and `16` are retired and never reused** — `qa` merged into `preview`
(`16`), and `preview` itself was **cut** (the feature-branch preview duplicated the
staging human test; the human judgment moved to merge's staging sign-off and
the direct-flow attestation — `shared/refs/safety-floor.md`). `nn` is a stable
global id, so the sequence skips both rather than renumbering. Row 18
(`manual-test-plan`, C22) is the newest component.

| nn | id | group | kind | criticality | cost | depends_on | active_when | platforms | env | mandatory |
|----|----|-------|------|------|------|-----------|-------------|-----------|-----|------|
| 01 | mechanical | universal | script | **critical** | cheap | sync | always | all | – | – |
| 02 | unit | universal | script | blocking | cheap | sync | always | all | – | – |
| 03 | integration | universal | script | blocking | moderate | sync | always | all | **✔**ˢ | – |
| 04 | regression | universal | hybrid | blocking | expensive | **tail (all others)** | always | all | condᶜ | – |
| 05 | security | universal | hybrid | **critical** | moderate | sync | always | all | – | **✔** |
| 06 | coverage | universal | script | config-driven† | moderate | **unit, integration** | always | all | – | – |
| 07 | prd-consistency | **prd** | subagent | **advisory** ᴸ | expensive | sync | **prd**ᵃ | all | – | – |
| 08 | e2e | platform | subagent | blocking | expensive | sync | ui-surface | **web** | **✔**ˢ | – |
| 09 | a11y | platform | subagent | **blocking** | moderate | sync | ui-surface | UI | **✔**ˢ | – |
| 10 | perf | platform | subagent | config-driven† | expensive | sync | perf-config | UI | **✔**ˢ | – |
| 11 | api | platform | subagent | blocking | moderate | sync | api-surface | srv | liveˡ | – |
| 12 | load | platform | subagent | config-driven† | expensive | sync | api-surface **+ diff-scoped**ᵈ | srv | **✔**ˢ | – |
| 13 | migration | platform | hybrid | **critical** | moderate | sync | **migrations** | DB³ | **✔**ˢ | **✔** |
| 14 | mobile | platform | subagent | blocking | expensive | sync | mobile-surface | mob✦ | **✔**ˢ | – |
| 17 | smoke | platform | subagent | blocking | **cheap** | sync | **UI or api/migration/deploy surface** (union) | all‡ | **✔**ˢ | – |
| 18 | manual-test-plan | **prd** | subagent | **advisory** ᵐ | moderate | **prd-consistency** | **prd**ᵃ | all | – | – |

### `run` / `ref` / `check` resolution

`ref` and `check` are fully mechanical from `nn`/`id`/`group`; `run` names the
tooling-fingerprint field (or subagent protocol) the component reads at gate time
— it is never a fixed command.

| nn | id | run (detection field / mechanism) | ref | check |
|----|----|------------------------------------|-----|-------|
| 01 | mechanical | `mechanical_runners[]` | `universal/protocol-mechanical.md` | `script-preflight-01-mechanical.sh` |
| 02 | unit | `test_runner`ˢᵉˡ | `universal/protocol-unit.md` | `script-preflight-02-unit.sh` |
| 03 | integration | `test_runner` (same field as `unit`)ˢᵉˡ | `universal/protocol-integration.md` | `script-preflight-03-integration.sh` |
| 04 | regression | `test_runner` (accumulated suite) + spawned eng-subagent authoring ˢᵉˡ ⁽ᵃᶜᶜᵘᵐᵘˡᵃᵗᵉᵈ ʰᵃˡᶠ ᵒⁿˡʸ⁾ | `universal/protocol-regression.md` | `script-preflight-04-regression.sh` |
| 05 | security | `security_scanners[]` / `secret_scanner` + `/cook` semantic pass | `universal/protocol-security.md` | `script-preflight-05-security.sh` |
| 06 | coverage | `coverage_runner` | `universal/protocol-coverage.md` | `script-preflight-06-coverage.sh` |
| 07 | prd-consistency | subagent (PRD digest + diff judgment, `/cook`-adjacent) | `prd/protocol-prd-consistency.md` | `script-preflight-07-prd-consistency.sh` |
| 08 | e2e | `e2e_runner` | `platform/protocol-e2e.md` | `script-preflight-08-e2e.sh` |
| 09 | a11y | `a11y_runner` (web axe/pa11y **+ native** iOS/macOS `performAccessibilityAudit` + Android accessibility-test-framework, C13) + project-enablement/criticality flag (`--init`, AC-A11Y4) | `platform/protocol-a11y.md` | `script-preflight-09-a11y.sh` |
| 10 | perf | `perf_runner` (`{runtime, bundle}`) — ratchet-vs-base + e2e-flow interaction (C14) | `platform/protocol-perf.md` | `script-preflight-10-perf.sh` |
| 11 | api | `api_runner` (array, incl. spec-diff `oasdiff`/`openapi-diff`) + optional `consumers[]` hint (C15) | `platform/protocol-api.md` | `script-preflight-11-api.sh` |
| 12 | load | `load_runner` — diff-scoped to touched endpoints + declared `traffic_mix` (C16) | `platform/protocol-load.md` | `script-preflight-12-load.sh` |
| 13 | migration | static SQL-safety scan + `/cook` semantic pass | `platform/protocol-migration.md` | `script-preflight-13-migration.sh` |
| 14 | mobile | `mobile_runner` (set: **native** XCUITest/XCTest + Espresso/JUnit **and** Flutter/Patrol/Maestro, C18) + **enforced declared `{platform,os}` matrix** | `platform/protocol-mobile.md` | `script-preflight-14-mobile.sh` |
| 17 | smoke | `smoke_runner` — **default-liveness floor** when unconfigured + the configured golden-path command (C21) | `platform/protocol-smoke.md` (C21) | `script-preflight-17-smoke.sh` |
| 18 | manual-test-plan | subagent (PRD digest + reuse of `prd-consistency`'s per-item evidence grades — no runner) | `prd/protocol-manual-test-plan.md` | `script-preflight-18-manual-test-plan.sh` |

## Legend

`platforms[]` = **applicability** — where the concern applies, per C12; a
web-only *runner* against a broader applicability is an **enforced
`platform-coverage-gap` finding**, never a silent pass.

- **all** — all 5 platforms (web, iOS, macOS, Android, backend)
- **UI** — all clients (web + iOS + macOS + Android, not backend)
- **web** — web only
- **srv** — backend (+ web BFF/SSR)
- **mob✦** — Android + iOS, **self-contained** (owns its own widget/integration/e2e — no double-run with `e2e`)
- **DB³** — backend + web-fullstack + mobile-with-local-db
- **‡** — applies everywhere, run *forks per platform* (url / artifact / sim)
- **†** — **config-driven criticality**: advisory by default, **blocking when the
  project configures explicit budgets/thresholds** (also honors a profile
  override) — applies to `perf`, `load`, `coverage`
- **ᵈ** — **diff-scoped** (C16): `load` runs **and** gates only when the PR touches an
  endpoint handler or a shared data-access path (via the executor's `resolve-diff`),
  scoped to the affected endpoints; a PR touching neither **skips** load entirely. Makes
  an expensive component affordable to gate — but does **not** change whether configured
  thresholds block (criticality stays `†` config-driven); diff-scoping governs *when* it
  runs, not *whether* thresholds block.
- **ᴸ** — **advisory by epistemic limit** (C11): `prd-consistency` grades a diff with an
  LLM. It can judge *"is there evidence someone attempted this criterion, and does a
  test exist?"*; it cannot certify correctness. So its findings are **recorded, never
  blocking** — they are routed to the human who can judge, via `manual-test-plan`'s
  significance-rated checklist, walked at merge `--staging`. This includes the `out-of-scope` scope-creep finding:
  the same limit applies, so it is evidence for the human walk-through, not a hard
  block.
- **ᵃ** — **`active_when: prd` resolves from PRD auto-discovery**: a `features/prd-<N>-*/`
  directory matched to the branch enables the `prd` group by default; `--prd <path>` is
  an explicit override for an unmatched or ambiguous case. **No PRD found ⇒ the whole
  `prd` group is pruned**, exactly as a no-PRD hotfix always did.
- **ᵐ** — **emit-only** (C22): `manual-test-plan` is `advisory` and **never blocks
  the PR** — it generates a significance-rated human-test checklist (reusing
  `prd-consistency`'s per-item evidence grades) and emits it; it never contributes a
  blocker/high to the verdict. Skipped entirely on a no-PRD hotfix (like the rest of
  the `prd` group).
- **ˢ** — **`needs_env: true`** (C23): requires a running app/DB — runs **inside** the
  ephemeral test-sandbox (see "The env-needing tier", below). `–` in the `env` column =
  `needs_env: false` — static/in-process, runs outside, never triggers provisioning.
- **ᶜ** — **conditional `needs_env`** (C23, AC-SBX8): `regression.needs_env` follows its
  **suite composition** — `true` only if the accumulated regression suite contains
  integration-level tests; resolved at `--init`/`--update` and recorded in the manifest.
- **ˡ** — **live-half only** (C23): the `api` **component** is `needs_env: false` — its
  base-vs-PR **spec-diff** is static and runs outside. Only its **#3 live-conformance
  pass** (spec-vs-implementation against a running server) runs inside the sandbox,
  with the env wave.
- **ˢᵉˡ** — **selection-capable** (`policies.test_selection`): the component can resolve a
  `run_minified` invocation and therefore participate in minified runs. **Exactly three
  rows** — `unit` (02), `integration` (03), `regression` (04, accumulated half only). Every
  other component's `run_minified` is `null` and it always runs full. Selection-capable is
  **not** selection-*enabled*: with the policy absent/disabled (its default), a `ˢᵉˡ` row
  runs its full suite exactly as before the key existed (AC-TS1/AC-TS12). The
  mandatory floor (`security`, `migration`) and `mechanical` are **never** selection-capable
  (AC-TS5).

## Only-on-green tier

`regression` (its authoring sub-step) runs only after the correctness components
have passed — no authoring onto a red branch.
This is an **execution policy layered on top of `depends_on`**, not a hard edge
in the dependency graph itself. **The C23 sandbox provisioning joins this tier**
(below): the env-needing wave's environment is stood up only after the static
correctness waves are green.

## The env-needing tier (C23 — test-sandbox)

The `needs_env: true` components (`env` column) run inside **one ephemeral, isolated
sandbox** per gate run — own DB/state/ports, torn down after every run (pass or fail),
concurrent-run safe. The static majority (`needs_env: false`) runs outside, exactly as
before; a static component never triggers provisioning and never enters the sandbox
(AC-SBX2). The lifecycle is the executor's (`pre-merge/refs/executor.md` §3b):

- **Only-on-green provisioning** (AC-SBX3): the sandbox is stood up **only after** the
  static correctness waves pass — a run that fails `mechanical`/`unit` never provisions,
  zero env cost on a fail-fast. Same policy layer as the only-on-green tier above.
- **One env, one lifecycle** (AC-SBX5): every env-needing component — including
  `smoke`'s liveness/golden-path run and `api`'s live-conformance half — shares that
  single sandbox. No component ever provisions a second env.
- **Seed strategy** (S-Q1 resolved): migrate-from-zero + a committed, versioned seed
  fixture — never a prod-like snapshot. `perf`/`load` may declare a generated larger
  dataset (scale factor in the manifest, produced by the seed script).
- **Fix-loop reuse** (S-Q2 resolved): within one fix-loop, the stack stays warm and
  the DB is reset (drop → remigrate → re-seed) between iterations.
- **`devkit/ENV.md`** — *how* the env comes up is project-specific (docker-compose /
  testcontainers / ephemeral DB branch / preview-deploy / simulator), detected at
  `--init` and recorded in the committed **`devkit/ENV.md`** contract file
  (`env-contract.md`) — human prose around one fenced block with a neutral
  provision / seed / reset / teardown interface, read by both gates (schema shared,
  machinery not). A repo needing two provisioners at once (full-stack mobile:
  simulator + compose backend) records a composite **`stacks[]`** — still **one
  logical sandbox**, all stacks provisioned and torn down together.
- **No provisioner ⇒ loud degrade** (AC-SBX6, the D28 safety-floor pattern):
  non-destructive env-needing checks run against the ambient environment with a `high`
  `sandbox-unprovisioned` finding ("cannot run hermetically — no sandbox provisioner");
  **destructive** checks (migration up→down→up) are skipped-with-note — never run
  against shared state, never a silent pass.

## The selection-capable tier (`policies.test_selection`)

Three components carry a `run_minified` (legend `ˢᵉˡ`): `unit`, `integration`,
`regression`. When `policies.test_selection` resolves **enabled** (opt-IN — absent
⇒ off, `policy-schema-pre-merge.md` §2c), the executor may run them over
**affected(diff) ∪ critical-floor** instead of the whole suite, per the size-tier
rubric in `pre-merge/refs/executor.md` § *Test selection*. Everything below is a
**default** the per-project `policy.json` overrides — the catalog never dictates a
project's globs or tag vocabulary, and none of it is read on a disabled run
(AC-TS12).

### `force_full_paths` defaults (per detected platform)

A diff touching **any** of these runs the full suite (rule step 1 ⇒ tier **L**) —
these are the surfaces whose blast radius selection cannot bound. `--init` seeds
the universal rows plus the rows for each detected platform.

| Scope | Default globs | Why |
|---|---|---|
| **universal** | `devkit/**` · `**/migrations/**` · `**/shared/**` · `**/lockfiles/**` | pipeline/policy config, schema changes (the `migration` component is `mandatory` and never selected anyway), and cross-cutting shared code — every one of them can break a test the diff never names |
| **web (JS/TS)** | `package.json` · `package-lock.json` · `pnpm-lock.yaml` · `yarn.lock` · `tsconfig*.json` | dependency + compiler-config changes are suite-wide by construction |
| **python** | `pyproject.toml` · `poetry.lock` · `requirements*.txt` · `conftest.py` | `conftest.py` re-fixtures the whole tree |
| **go** | `go.mod` · `go.sum` | module-graph-wide |
| **apple** | `*.xcodeproj/**` · `*.xcworkspace/**` · `Package.swift` · `Podfile.lock` · `*.xctestplan` | target/scheme membership decides *which* tests exist |
| **android** | `*.gradle*` · `gradle/libs.versions.toml` · `gradle.properties` · `settings.gradle*` | module graph + dependency catalog |

### `critical_markers` defaults (the critical floor's vocabulary)

Tags live **in test code** — ground truth, reviewed in PRs. Policy records only
the vocabulary; the catalog supplies the platform default `--init` resolves.

| Platform | Default marker | Mechanism |
|---|---|---|
| `web` | `@critical` | title tag — Playwright `--grep @critical`; vitest/jest via `--testNamePattern` (or a `tests/critical/` glob) |
| `python` | `critical` | `@pytest.mark.critical`, registered in config so a typo errors rather than selecting nothing |
| `go` | `TestCritical` | `TestCritical*` naming convention (`go test` has no tag primitive) |
| `apple` | `Critical.xctestplan` | a committed XCTest **test plan** enumerating the critical suites (`xcodebuild -testPlan Critical`) — the plan file *is* the declared critical set: reviewable and versioned |
| `android` | `com.<org>.test.Critical` | a `@Critical` annotation class in a shared test-util module, filtered via `-Pandroid.testInstrumentationRunnerArguments.annotation=` (instrumented) / JUnit tag (unit) |

The preflight script **verifies the declared marker resolves** (marker registered
/ `.xctestplan` present / annotation class compiles). A declared-but-broken marker
is a `medium` `policy-mismatch` finding (AC-ST3 pattern) — never a silently empty
critical floor.

### `regression`'s special contract (pointer)

`regression` is selection-capable on its **accumulated half only**. Its two-part
contract is defined once in `pre-merge/refs/executor.md` § *Test selection* and
`universal/protocol-regression.md`; the catalog records only that it exists:

- **accumulated suite** (`tests/regression/prd-*/`) — selectable: critical ∪ affected,
  widened one dependency hop at tier **M**.
- **this PRD's newly authored tests** — **always run in full, never selected away**
  (AC-TS5); this is what protects the D9 ratchet.
- Regression tests are **born tagged**: the authoring eng subagent applies the
  platform's critical marker in the same commit to any test derived from a
  PRD acceptance criterion the PRD marks P0/critical — the primary defense against
  tag drift.

Selection never touches the mandatory floor: `mechanical`, `security`, and
`migration` have no `run_minified` and always run whole (AC-TS5). `coverage` is
not selection-capable either, but it is **selection-aware** — when its
`unit`/`integration` dependencies ran minified, coverage deltas are computed over
the diff's files only (a suite-wide number from a partial run is meaningless) and
its report says so.

## Hard edges (the only ones — AC-CAT3)

`depends_on` carries **only** true effect edges. Everything else in the table
above marked `sync` means "needs the synced branch, otherwise independent" —
**not** a dependency edge. The three real edges (the retired 2nd edge,
`smoke → preview`, died with the `preview` component):

1. `coverage → {unit, integration}` — coverage parses their output.
2. `regression` **tail-pins** — `depends_on` every other universal/prd component
   (C5); it authors + commits this PRD's tests only after everything else has
   validated the branch, then runs the accumulated suite last.
3. `manual-test-plan → prd-consistency` (C22) — `manual-test-plan` **reuses**
   `prd-consistency`'s per-item evidence grades to compute each checklist item's
   automation-gap, so it runs after `prd-consistency`. This is the **3rd** hard
   edge (amends AC-CAT3 / AC-SEQ6's "only edges" enumeration). It does not create a
   cycle: `prd-consistency` has no `depends_on` back onto `manual-test-plan` (it
   `depends_on sync` only), so the edge is one-directional and the DAG stays acyclic.

## `mandatory`

`true` **exactly** for `security` and `migration` (AC-CAT4) — a platform profile
can shift their *criticality tier* but can never opt them out entirely; both
still degrade gracefully per their own safety-floor rules (`security`: C9;
`migration`: static-scan-always-runs) rather than block installation.

`security` carries the **C9 guaranteed secret-scan floor**: SAST / deps / container /
`/cook` layers are best-effort (absence = note), but when **no secret scanner** is
detected the component emits a `blocker` (`no-secret-scanner`, `safety-floor-unmet`) —
there is no green-gate path without secret-scan coverage. The scanner install stays
per-item approved at `--init` (`AC-DR2`). See
`pre-merge/refs/universal/protocol-security.md` (C9) and `safety-floor.md`.

## Firming notes (platform rows, 2026-07-18)

- **Applicability vs. runner coverage.** `a11y`/`perf` apply to **all clients**
  (`UI`); their current runners are web-only (axe, Lighthouse) — mobile/macOS
  coverage is an **enforced `platform-coverage-gap` finding** (C12), not a
  silent pass. `e2e` stays **web**: native UI-e2e is `mobile`'s concern (the e2e↔mobile split), so
  an iOS target's UI-e2e gap fires via `mobile`, not `e2e`.
- **`mobile`** is a self-contained Android/iOS vertical. As of **C18** it detects + runs
  **native iOS (XCUITest/XCTest, Swift)** and **native Android (Espresso/JUnit, Kotlin)**
  runners **in addition** to the Flutter path (widget/integration + Patrol/Maestro) — a
  native app with no Dart files is no longer "no test files → green". The `mobile_runner`
  slot is now a **set** (native + Flutter). Native runner support is **real coverage**, no
  longer a C12 flag — when a platform's native runner runs, C12's native-mobile gap for
  that platform is satisfied (AC-MOB3). The **declared `{platform, os}` matrix is
  enforced**: a declared target with no available device/simulator (incl. no macOS host
  for iOS XCUITest) is a `high` `platform-coverage-gap` (C12), **not** a silent
  `pass_with_warnings` (AC-MOB2); `--init` establishes the matrix when absent.
- **`perf`** (C14) measures **cold-load runtime metrics + bundle size** against the
  project's configured budgets (the hard bar, `†`), with a **no-regression ratchet vs
  base** applied only when comparable base numbers exist (`ratchet-vs-base.md`; no base
  numbers ⇒ skipped with a note). Bundle findings **attribute the culprit import** when
  the bundle stats resolve one (`attribute-the-cause.md`), else size + route.
- **`api`** (C15) gains a **backward-compatibility spec-diff vs base** (`oasdiff`/`openapi-diff`
  — removed/narrowed/required/deleted → `high`/blocking, the contract-compat ratchet,
  `ratchet-vs-base.md`); findings are **consumer-named** (Pact broker → optional `consumers[]`
  hint → endpoint+change, no fabricated consumer — `attribute-the-cause.md` +
  `name-the-user-impact.md`); no base spec ⇒ the diff is skipped with a note. Rec #3
  (live-server conformance) runs in the **env wave**, against the C23 sandbox.
- **`load`** (C16) is **diff-scoped** (legend `ᵈ` — runs/gates only on an endpoint/data-path
  touch, scoped to the affected endpoints) and runs the project's own runner profile
  (an optional declared `traffic_mix` overrides it); breaches **name the bottleneck**
  when a per-operation trace exists (`attribute-the-cause.md`), else metric + endpoint.
  Config-driven criticality unchanged (`†`).
- **`migration`** carries an optional **`hot_tables[]`** hint (C17) — the project's
  large/hot tables. With it (or live table stats) lock-risk severity scales: escalate on
  a hot table, quiet on a tiny one. **Absent both — the default — lock findings keep
  their flat severity**, and nothing is asked for up front.
- **`a11y`** (C13) audits the **resolved target set** (the runner's own config, else
  route discovery, else Storybook — a project whose specs drive interactive states gets
  those states audited), and gains **native runner support** (iOS/macOS
  `performAccessibilityAudit` + Android accessibility-test-framework — real coverage when
  a native runner is present, no longer a C12 flag). Findings **lead with user impact +
  flow** (`name-the-user-impact.md`), WCAG id secondary. Its **default enablement/
  criticality is a project-level `--init` decision** (AC-A11Y4): public-facing product →
  default-on/blocking; internal tool / backend → default-off/advisory — the row's default
  `blocking` is the public-facing default, not unconditional. Tagged **low-priority** in
  the build sequence (AC-A11Y5).
- **`smoke`** (C21) is a **cheap env-wave** component with no hard edge — it runs the app the
  C23 sandbox stood up and answers *"is this build actually alive on its golden paths?"*.
  Two behaviors: a **no-vacuous-skip default-liveness floor** (no `smoke_cmd` still runs a
  liveness check — URL 200 / artifact launches — so the component can never pass
  vacuously; safety-floor pattern like C9/D28) and **critical-path coverage** (the
  project's configured smoke command — 1–3 golden paths incl. the core action — not just
  homepage 200). Its result feeds the verdict directly as a `blocking` component. A
  genuinely un-smokeable surface degrades **loudly**, never silent green. *(Its former
  role — preview's health precondition, the 2nd hard edge, the R1 prompt block — died
  with the `preview` cut; the checks themselves survive unchanged.)*

## Resolves

- **Q1** — the platform profile is a thin per-component `criticality`
  override layer (e.g. `strict` bumps `a11y`/`coverage` → blocking; `lenient`
  drops them → advisory). No separate `required_buckets` list — presence is
  `active_when` + detection.
- **Q4** — all component metadata lives here; `protocol-<slug>.md` holds only
  run/grade prose + a light header pointer back to this file.
- **Q5** — this file is the single home of the defaults; `--init`/`--update`
  seed `devkit/policy.json`'s `components[]` from it, then overlay detection
  (`present`/`run`) + user overrides.
