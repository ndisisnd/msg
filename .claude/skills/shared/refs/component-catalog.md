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
folder split, the `preflight-check-*` scripts, wave sequencing, and result
reporting all key off this file — nothing downstream re-derives component
metadata by hand.

> **This phase (P1).** This file transcribes the catalog defaults and wires the
> `ref` pointers to the moved protocol files. The `preflight-check-<nn>-<slug>.sh`
> scripts named by `check` below do not exist yet — they land in Phase 2 (C4).
> Nothing in this phase changes gate run order or pass/fail behavior.

## Entry schema

```
{ id, nn, group, kind, criticality, cost, depends_on[], active_when,
  platforms[], mandatory, run, ref, check }
```

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
| `mandatory` | `true` only for `security` and `migration` (AC-CAT4) — never opts out, only degrades per their own safety-floor rules |
| `run` | resolved by detection at `--init`/`--update` time from the Step 1 tooling fingerprint (`shared/refs/tooling-detection.md`) — the catalog names the **detection field**, not a fixed command |
| `ref` | `<group>/protocol-<slug>.md` — the protocol file (prose + grading logic) |
| `check` | `preflight-check-<nn>-<slug>.sh` — the normalized detect script (Phase 2, C4) |

## The components (17 live, 18 authored)

**C20 note:** `qa` (`15`) is merged into `preview` (`16`) — the single human-review
gate. Id `15` is **retired, not reused**; `[NN]` stays a stable global id. The
catalog below carries 18 rows for continuity with the id space, one of which is
a retired tombstone (so 17 are live). Row 18 (`manual-test-plan`, C22) is the
newest live component.

| nn | id | group | kind | criticality | cost | depends_on | active_when | platforms | mandatory |
|----|----|-------|------|------|------|-----------|-------------|-----------|------|
| 01 | mechanical | universal | script | **critical** | cheap | sync | always | all | – |
| 02 | unit | universal | script | blocking | cheap | sync | always | all | – |
| 03 | integration | universal | script | blocking | moderate | sync | always | all | – |
| 04 | regression | universal | hybrid | blocking | expensive | **tail (all others)** | always | all | – |
| 05 | security | universal | hybrid | **critical** | moderate | sync | always | all | **✔** |
| 06 | coverage | universal | script | config-driven† | moderate | **unit, integration** | always | all | – |
| 07 | prd-consistency | **prd** | subagent | blocking | expensive | sync | **prd** | all | – |
| 08 | e2e | platform | subagent | blocking | expensive | sync | ui-surface | **web** | – |
| 09 | a11y | platform | subagent | **blocking** | moderate | sync | ui-surface | UI | – |
| 10 | perf | platform | subagent | config-driven† | expensive | sync | perf-config | UI | – |
| 11 | api | platform | subagent | blocking | moderate | sync | api-surface | srv | – |
| 12 | load | platform | subagent | config-driven† | expensive | sync | api-surface | srv | – |
| 13 | migration | platform | hybrid | **critical** | moderate | sync | **migrations** | DB³ | **✔** |
| 14 | mobile | platform | subagent | blocking | expensive | sync | mobile-surface | mob✦ | – |
| **15** | ~~qa~~ | — | — | — | — | — | **retired (qa merged into preview, C20/D26); never reused** | — | — |
| 16 | preview | platform | **gate** | blocking | expensive | sync (only-on-green, late wave) | **UI or api/migration/deploy surface** (union, C20) | all‡ | – ᵍ |
| 17 | smoke | platform | subagent | blocking | moderate | **preview** | preview-fired | all‡ | – |
| 18 | manual-test-plan | **prd** | subagent | **advisory** ᵐ | moderate | **prd-consistency** | **prd** | all | – |

### `run` / `ref` / `check` resolution

`ref` and `check` are fully mechanical from `nn`/`id`/`group`; `run` names the
tooling-fingerprint field (or subagent protocol) the component reads at gate time
— it is never a fixed command.

| nn | id | run (detection field / mechanism) | ref | check |
|----|----|------------------------------------|-----|-------|
| 01 | mechanical | `mechanical_runners[]` | `universal/protocol-mechanical.md` | `preflight-check-01-mechanical.sh` |
| 02 | unit | `test_runner` | `universal/protocol-unit.md` | `preflight-check-02-unit.sh` |
| 03 | integration | `test_runner` (same field as `unit`; Phase 2 splits detection) | `universal/protocol-integration.md` | `preflight-check-03-integration.sh` |
| 04 | regression | `test_runner` (accumulated suite) + spawned eng-subagent authoring | `universal/protocol-regression.md` | `preflight-check-04-regression.sh` |
| 05 | security | `security_scanners[]` / `secret_scanner` + `/cook` semantic pass | `universal/protocol-security.md` | `preflight-check-05-security.sh` |
| 06 | coverage | `coverage_runner` | `universal/protocol-coverage.md` | `preflight-check-06-coverage.sh` |
| 07 | prd-consistency | subagent (PRD digest + diff judgment, `/cook`-adjacent) | `prd/protocol-prd-consistency.md` | `preflight-check-07-prd-consistency.sh` |
| 08 | e2e | `e2e_runner` | `platform/protocol-e2e.md` | `preflight-check-08-e2e.sh` |
| 09 | a11y | `a11y_runner` | `platform/protocol-a11y.md` | `preflight-check-09-a11y.sh` |
| 10 | perf | `perf_runner` (`{runtime, bundle}`) | `platform/protocol-perf.md` | `preflight-check-10-perf.sh` |
| 11 | api | `api_runner` (array) | `platform/protocol-api.md` | `preflight-check-11-api.sh` |
| 12 | load | `load_runner` | `platform/protocol-load.md` | `preflight-check-12-load.sh` |
| 13 | migration | static SQL-safety scan + `/cook` semantic pass | `platform/protocol-migration.md` | `preflight-check-13-migration.sh` |
| 14 | mobile | `mobile_runner` | `platform/protocol-mobile.md` | `preflight-check-14-mobile.sh` |
| ~~15~~ | ~~qa~~ | — retired, no script — | — | — no `preflight-check-15-qa.sh` — |
| 16 | preview | `preview_deploy_cmd` + `qa_runner` (visual capture, merged) | `platform/protocol-preview.md` | `preflight-check-16-preview.sh` |
| 17 | smoke | `smoke_runner` (new, resolves Q3) | `platform/protocol-smoke.md` (new, Phase 6/C21) | `preflight-check-17-smoke.sh` |
| 18 | manual-test-plan | subagent (PRD digest + reuse of `prd-consistency`'s per-item evidence grades — no runner) | `prd/protocol-manual-test-plan.md` | `preflight-check-18-manual-test-plan.sh` |

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
- **ᵍ** — **human-review gate** (C19 → merged C20): `preview` captures the
  feature's UI states **and** stands up the live/pokeable env, then serves one
  unified artifact for explicit human sign-off — blocking; no auto
  pixel-threshold pass. Absorbs the retired `qa`.
- **ᵐ** — **emit-only** (C22): `manual-test-plan` is `advisory` and **never blocks
  the PR** — it generates a significance-rated human-test checklist (reusing
  `prd-consistency`'s per-item evidence grades) and emits it; it never contributes a
  blocker/high to the verdict. Skipped entirely on a no-PRD hotfix (like the rest of
  the `prd` group).

## Only-on-green tier

`regression` (its authoring sub-step), `preview`, and `smoke` run only after the
correctness components have passed — no deploying/authoring onto a red branch.
This is an **execution policy layered on top of `depends_on`**, not a hard edge
in the dependency graph itself.

## Hard edges (the only ones — AC-CAT3)

`depends_on` carries **only** true effect edges. Everything else in the table
above marked `sync` means "needs the synced branch, otherwise independent" —
**not** a dependency edge. The four real edges:

1. `coverage → {unit, integration}` — coverage parses their output.
2. `smoke → preview` — smoke checks the fired preview's liveness.
3. `regression` **tail-pins** — `depends_on` every other universal/prd component
   (C5); it authors + commits this PRD's tests only after everything else has
   validated the branch, then runs the accumulated suite last.
4. `manual-test-plan → prd-consistency` (C22) — `manual-test-plan` **reuses**
   `prd-consistency`'s per-item evidence grades to compute each checklist item's
   automation-gap, so it runs after `prd-consistency`. This is the **4th** hard
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

## Firming notes (platform rows, 2026-07-18; `qa` merged into `preview` by C20)

- **Applicability vs. runner coverage.** `a11y`/`perf` apply to **all clients**
  (`UI`); their current runners are web-only (axe, Lighthouse) — mobile/macOS
  coverage is an **enforced `platform-coverage-gap` finding** (C12), not a
  silent pass. (`qa`'s visual review folded into the `preview` gate, C20 — which
  produces a per-platform artifact, so no web-only-runner gap there.) `e2e`
  stays **web**: native UI-e2e is `mobile`'s concern (the e2e↔mobile split), so
  an iOS target's UI-e2e gap fires via `mobile`, not `e2e`.
- **`mobile`** is a self-contained Android/iOS vertical (Flutter widget/
  integration + Patrol/Maestro + device matrix); native (XCUITest/Espresso)
  support is a gap → enforced when iOS/Android is targeted (C12).
- **`migration`** carries an optional **`hot_tables[]`** hint (C17) — the project's
  large/hot tables, declared at `--init` (`protocol-init.md`). It gives the migration
  stage size context to **scale lock-risk severity** (escalate on a hot table, quiet on
  a tiny one) when no schema/stats source is available; absent both stats and the list,
  lock findings keep their flat severity (AC-MIG3/MIG4). Optional — an empty/absent list
  means "no size context", never a validation error.
- **`a11y`** corrected from a provisional advisory to **blocking** (fails on
  serious/critical WCAG). **`smoke`** resolves Q3 (`depends_on preview`).

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
