---
name: policy-schema
description: Canonical schema, status vocabulary, and gate read-contract for devkit/policy.json — the committed, shared policy file seeded by /msg --init, flipped by /msg --init-staging, completed by --init (--doctor is a deprecated one-release alias), and read by both gates
type: reference
---

# `devkit/policy.json` — the committed policy file

The single authoritative definition of `devkit/policy.json`: the **committed, shared** policy artifact both gate skills (`pre-merge`, `post-merge`) read at run time. It holds **decisions only** — release-flow shape, branch-protection stance, per-step opt-in/out — never per-machine binary presence (that is detected by the ephemeral `preflight-check-*.sh` family at `--init`/`--update` time and resolved into each component's `run` command, never persisted as a standalone fingerprint). Because it's committed, its decisions travel to CI and teammates. It sits next to its sibling config `devkit/PLATFORMS.md`.

**Writers — the only three:**

| Writer | Writes |
|---|---|
| `/msg --init` | **seed** — `version`, `init:false`, `generated`, `policies.release_flow` (nothing else) |
| `/msg --init-staging` | **flow flip** — sets `release_flow.mode:"staged"`, `staging_branch:"staging"` after creating the branch |
| `--init` | **completion** — runs the preflight checks, assembles `components[]`, stamps `source_signature`, fills tooling + `branch_protection`, flips `init:true` |
| `--update` | **reconcile** — re-runs the preflight checks, diffs `components[]` vs reality, applies approved `present`/`active_when`/new-component changes, restamps `source_signature` (never re-grades user-set `criticality`, never re-prompts `opted_out`/`n/a`) |

No gate run ever writes it (AC-OW1, AC-UP6) — a gate only recomputes `source_signature`
read-only to nudge (Fork E). `--init` never writes `devkit/PLATFORMS.md` (that stays `/msg --init`'s).

**Deprecated alias.** `--doctor` still works for one release: it runs `--init` and prints a
deprecation note naming `--init`/`--update`.

## Canonical v1 schema (annotated)

```json
{
  "version": 1,                          // must be 1; any other value → file treated as absent
  "init": true,                          // lifecycle gate: false → gates auto-run --init first
  "generated": "2026-07-16",             // YYYY-MM-DD, stamped by the writing skill
  "generated_by": "post-merge --init",   // last writer; informational
  "repo": {                              // evidence/audit only — gates never branch on it
    "host": "github",
    "visibility": "private",
    "branch_protection_available": false,
    "detected_via": "gh api → 403 upgrade-required on a private Free repo"
  },
  "policies": {                          // the enforced half
    "release_flow": {
      "mode": "staged",                  // staged = feature→staging→prod; direct = feature→prod
      "prod_branch": "main",
      "staging_branch": "staging"        // null in direct mode
    },
    "branch_protection": {
      "mode": "optional",                // enforced | optional | skip (repo-wide default)
      "reason": "private repo on GitHub Free — branch-protection API unavailable",
      "overrides": { "main": "enforced" } // per-branch: resolved as overrides[b] ?? mode
    }
  },
  "steps": {                             // one entry per canonical step-key
    "mechanical":        { "status": "ready",     "chosen": ["eslint", "tsc"] },
    "unit_int":          { "status": "ready",     "chosen": "vitest" },
    "e2e":               { "status": "opted_out",  "reason": "no e2e surface yet" },
    "a11y":              { "status": "n/a",        "reason": "backend-only repo" },
    "security":          { "status": "ready",     "chosen": ["gitleaks", "semgrep", "osv-scanner"] },
    "ci":                { "status": "ready",     "chosen": ".github/workflows/pre-merge.yml" },
    "deploy_staging":    { "status": "ready" },
    "deploy_production": { "status": "ready" },
    "smoke":             { "status": "missing",    "reason": "declared in PLATFORMS.md, never verified" }
  }
}
```

## Seed skeleton — what `/msg --init` writes

Release-flow answers captured, tooling not yet resolved, `init:false` so the first gate run triggers `--init`. Idempotent: `/msg --init` never overwrites an existing `policy.json` (AC-LC7).

```json
{
  "version": 1,
  "init": false,
  "generated": "2026-07-16",
  "generated_by": "msg --init",
  "policies": {
    "release_flow": { "mode": "staged", "prod_branch": "main", "staging_branch": "staging" }
  }
}
```

## Field spec

### Top-level

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `version` | int | ✔ | — | must be `1`; any other value → whole file treated as absent (AC-S1) |
| `init` | bool | ✔ | `false` (if omitted) | lifecycle gate. `false` → gates auto-run `--init` first; `true` → gates run the protocol. `/msg --init` seeds `false`; `--init` flips it `true` on completion |
| `generated` | `YYYY-MM-DD` | ✔ | — | stamped by the skill (scripts can't date); informational |
| `generated_by` | enum `msg --init` \| `msg --init-staging` \| `pre-merge --init` \| `pre-merge --update` \| `post-merge --init` \| `post-merge --update` | ✖ | — | last writer; informational. `pre-merge --doctor`/`post-merge --doctor` still appear on files written during the one-release deprecation window (aliases of `--init`) |
| `repo` | object | ✖ | — | evidence/audit only — gates never branch on it |
| `policies` | object | ✖ | `{}` | the enforced half |
| `components` | object[] | ✖ | — | the **v3 preflight manifest** — the resolved per-project pipeline (catalog defaults + detection + user overrides). Purely **additive** to the same file (AC-PF5). See [`components[]`](#components--the-v3-preflight-manifest) |
| `source_signature` | string | ✖ | — | staleness hash of the detect-section tuple across all preflight reports; stamped by `--init`/`--update` (AC-UP4). Gate recomputes it read-only to warn on drift (AC-UP5). See below |
| `steps` | object | ✖ | `{}` | per-step decisions. **Deprecated (v3):** superseded by `components[]`; **dual-written** by `--init`/`--update` until P3 flips the gate to the executor, then dropped. The pre-P3 gate still reads it |

### `repo` (informational — gates never branch on it)

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `host` | enum `github` \| `gitlab` \| `other` \| `none` | ✖ | `github` | only `github` protection is wired today |
| `visibility` | enum `public` \| `private` \| `unknown` | ✖ | — | — |
| `branch_protection_available` | bool | ✖ | `true` | — |
| `detected_via` | string | ✖ | — | freeform evidence note |

### `policies.release_flow` — the pipeline shape

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `mode` | enum `staged` \| `direct` | ✔* | `staged` | `staged` = feature→staging→prod; `direct` = feature→prod (no staging branch) |
| `prod_branch` | string | ✔* | `main` | production branch (`main`/`master`) |
| `staging_branch` | string \| null | ✔ when `staged` | `staging` | `null` in `direct` mode |

\* the whole `release_flow` object is optional (gates default to `staged`/`main`/`staging`); within a present object these fields resolve as above.

### `policies.branch_protection` — per-branch protection stance

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `mode` | enum `enforced` \| `optional` \| `skip` | ✔ | `enforced` | repo-wide default, resolved per branch |
| `reason` | string | required when `mode` ≠ `enforced` | — | governance note; missing → honored + `unjustified-policy` warn (AC-S3) |
| `overrides` | object `<branch, mode>` | ✖ | `{}` | per-branch mode; resolved as `overrides[b] ?? mode` |

### `steps.<key>` — one entry per canonical step-key

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `status` | enum `ready` \| `opted_out` \| `n/a` \| `missing` \| `deferred` | ✔ | — | persisted vocabulary — **no `installed`** (a just-installed tool is persisted as `ready`) |
| `reason` | string | required for `opted_out`/`n/a`/`deferred` | — | missing → honored + `unjustified-policy` warn (AC-S3) |
| `chosen` | string \| string[] | ✖ | — | the tool(s) selected for a `ready` step |
| `last_checked` | `YYYY-MM-DD` | ✖ | — | informational |

### `components[]` — the v3 preflight manifest

The resolved per-project pipeline. `--init`/`--update` assemble it by seeding the
[`component-catalog.md`](component-catalog.md) defaults, overlaying live detection (from
the `preflight-check-*.sh` reports — `present`/`run`/`tooling`), then applying user
overrides. **Additive** — it lives beside `release_flow`/`branch_protection`/`init`,
which are untouched (AC-PF5). The v3 pre-merge **executor** reads it as the pipeline
source (P3, live — `pre-merge/refs/executor.md`); a `/pre-merge` run with **no**
`components[]` refuses `no_manifest` (Fork C, AC-PF13/PF14). Post-merge keeps its
pre-executor lifecycle until its own executor plan lands.

```json
"components": [
  {
    "id": "mechanical",
    "nn": "01",
    "group": "universal",
    "kind": "script",
    "present": true,
    "mandatory": false,
    "active_when": "always",
    "criticality": "critical",
    "cost": "cheap",
    "depends_on": [],
    "needs_env": false,
    "run": "npx eslint <files>; npx tsc --noEmit",
    "tooling": { "chosen": "eslint,tsc", "version": null },
    "status": "ready",
    "source": "preflight-check-01-mechanical.sh"
  }
]
```

| Field | Type | Notes |
|---|---|---|
| `id` | string | component slug — matches `protocol-<slug>.md` + the check-report `check` |
| `nn` | string | stable zero-padded global catalog id (`"01"`…`"17"`, minus retired `15`); never reused, group-orthogonal |
| `group` | enum `universal`\|`platform`\|`prd` | gating source (folder) |
| `kind` | enum `script`\|`subagent`\|`hybrid`\|`gate` | how the component runs |
| `present` | bool | in the pipeline this run only when `true` (or `mandatory`); an absent component produces **no** step and **no** skip note (AC-PF6) |
| `mandatory` | bool | `true` **exactly** for `security` + `migration` (AC-CAT4) — never opts out, only degrades per its own safety-floor rule |
| `active_when` | string | presence gate (`always`, `prd`, `ui-surface`, `migrations`, `preview-fired`, …) |
| `criticality` | enum `critical`\|`blocking`\|`advisory`\|`config-driven` | grading tier + fail-fast class; a platform profile may override (Q1); **user-set values are never re-graded by `--update`** (AC-UP2) |
| `cost` | enum `cheap`\|`moderate`\|`expensive` | wave-scheduling hint |
| `depends_on` | string[] | hard effect edges only; the graph MUST be **acyclic** — `--init` rejects a cycle and writes no manifest (AC-PF3) |
| `needs_env` | bool | **C23** — `true` iff the component runs inside the ephemeral test-sandbox (catalog `env` column). Catalog-defaulted; `regression`'s value is **resolved at `--init`** from its suite composition (AC-SBX8) |
| `run` | string \| null | resolved command (script/hybrid) or `<group>/protocol-<slug>.md` ref (subagent/gate) |
| `tooling` | `{chosen,version}` \| null | the detection overlay |
| `status` | enum `ready`\|`no_tooling`\|`n/a`\|`opted_out`\|`deferred` | detection status (`ready`/`no_tooling`/`n/a`) or the carried-over user decision (`opted_out`/`deferred`) |
| `source` | string | the `preflight-check-<nn>-<slug>.sh` that produced this entry (audit) |

**No `order` field** — ordering is a runtime topo-sort on `depends_on` (Fork B, AC-PF4);
the manifest never freezes a sequence.

### `env_provision` — the C23 sandbox provisioner resolution

Sibling of `components[]` (additive — AC-SBX7). Records *how* this project stands up
the ephemeral test-sandbox the `needs_env: true` components run in. Detected/declared
at `--init` (`pre-merge/refs/protocol-init.md`); the executor consumes it at §3b.
**Neutral verb interface by design** — post-merge may *read* it later (shared schema,
never shared machinery); pre-merge remains its only writer.

```json
"env_provision": {
  "provisioner": "docker-compose",
  "provision": "docker compose -f docker-compose.test.yml up -d --wait",
  "seed": "npm run db:migrate && npm run db:seed",
  "reset": "npm run db:reset && npm run db:seed",
  "teardown": "docker compose -f docker-compose.test.yml down -v",
  "seed_script": "scripts/seed-test.ts",
  "scale_factor": null
}
```

| Field | Type | Notes |
|---|---|---|
| `provisioner` | enum `docker-compose`\|`testcontainers`\|`db-branch`\|`preview-deploy`\|`simulator`\|`none` | the detected/declared mechanism; `none` = no provisioner — env-needing components degrade **loudly** at gate time (AC-SBX6), never a silent pass |
| `provision` | string \| null | stand up the isolated stack (own DB/state/ports) |
| `seed` | string \| null | migrate-from-zero + apply the committed seed fixture (S-Q1: never a prod-like snapshot) |
| `reset` | string \| null | cheap data-only reset between fix-loop iterations (S-Q2: drop → remigrate → re-seed; stack stays warm) |
| `teardown` | string \| null | full teardown — run after **every** gate run, pass or fail (AC-SBX4) |
| `seed_script` | string \| null | the committed seed script; absent while a provisioner exists ⇒ loud D28-style note at gate time, never a silent empty-DB run |
| `scale_factor` | number \| null | optional generated-dataset multiplier for `perf`/`load` realism (S-Q1) — produced by the seed script, never a snapshot |

`provisioner: "none"` (or the whole object absent) is valid — it means `--init` found
nothing and the user declined to declare one; the gate then emits the `high`
`sandbox-unprovisioned` finding per run. Absence is **never** a validation error.

**Composite environments — `stacks[]` (additive).** A full-stack-mobile repo needs two
provisioners at once (a `simulator` for the app **and** a `docker-compose` backend it
talks to). `env_provision` may therefore carry an optional **`stacks[]`** array —
each entry is one `{provisioner, provision, seed, reset, teardown, …}` object in the
shape above:

```json
"env_provision": {
  "stacks": [
    { "provisioner": "docker-compose", "provision": "docker compose -f dc.test.yml up -d --wait", "seed": "...", "reset": "...", "teardown": "docker compose -f dc.test.yml down -v" },
    { "provisioner": "simulator", "provision": "xcrun simctl boot test-sbx && install <build>", "seed": null, "reset": "xcrun simctl erase test-sbx", "teardown": "xcrun simctl shutdown test-sbx" }
  ]
}
```

- The **flat shape stays valid** as the single-stack case — `stacks[]` is never
  required, and readers MUST treat a flat object as `stacks: [<that object>]`.
- The stacks are **one logical sandbox** (AC-SBX2/SBX5 unchanged): the executor
  provisions all stacks together, runs the env wave against the composite, promotes
  the composite to preview, and tears **all** stacks down together — never partially.
- A verb null on one stack (a simulator has no `seed`) is valid; the loud
  seed-script rule applies per-stack only where a DB exists.

### `source_signature` — staleness hash

A hash of the **detect-section tuple** across all preflight reports, stamped by
`--init`/`--update` (AC-UP4). Defined precisely so the gate can recompute it cheaply:

```
source_signature = "sha256:" + sha256(
  join("\n", sort(
    for each preflight report r:  "<r.id>:<r.present>:<r.run>:<r.tooling.chosen>"
  ))
)
```

i.e. sha256 over the newline-joined, **sorted** `id:present:run:tooling.chosen` lines
(one per check; `null` run/chosen render as the literal `null`). The gate recomputes this
read-only each run; on mismatch it warns *"pipeline may be stale — run
`/pre-merge --update`"*, proceeds on the current manifest, and **never writes** (Fork E,
AC-UP5/UP6).

### Q2 — `steps.<key>` → `components[]` migration

`--init` rewrites a pre-v3 `steps.*` block into `components[]` **once**, mapping the old
per-step status onto component fields (then keeps `steps` dual-written until P3):

| old `steps.<key>.status` | → component fields |
|---|---|
| `ready` | `present: true` (detection re-resolves `run`/`tooling`) |
| `opted_out` | `present: false`, `status: opted_out` (**preserved** — `--update` never re-prompts it, AC-UP2) |
| `n/a` | `present: false`, `status: n/a` (**preserved**) |
| `missing` | `present: false`, `status: no_tooling` (a known gap) |
| `deferred` | `present: false`, `status: deferred` (preserved; will revisit) |

Step-key → component id: `mechanical`→`mechanical`, `unit_int`→`unit`+`integration`,
`e2e`/`a11y`/`perf`/`load`/`api`/`mobile`/`coverage`/`security`→same id, `qa`→`preview`
(merged, C20), `migration`→`migration`, `smoke`→`smoke`. `ci`/`deploy_staging`/
`deploy_production` have no pre-merge component — they stay `steps`-only (post-merge's).

## Closed step-key vocabulary (16 keys)

Any key outside this set → ignored + one warn (AC-S4):

`mechanical` · `unit_int` · `e2e` · `qa` · `a11y` · `perf` · `load` · `api` · `mobile` · `coverage` · `security` · `migration` · `ci` · `deploy_staging` · `deploy_production` · `smoke`

`ci` records whether a `.github/workflows/` pipeline runs the gate on PRs (written by
`pre-merge --init`, read by post-merge's green-CI check — see §3). It has no runner and never
runs as a gate *step*; it exists so a missing pipeline surfaces instead of passing vacuously.

## Validation rules

Fail-safe throughout — a malformed policy never aborts a gate run.

1. **Parse failure** — malformed JSON, or `version` ≠ 1 → **treat the whole file as absent**; gates use built-in defaults; emit exactly **one** info line. Never abort the run on a parse error. (AC-S1)
2. **Bad enum** — any enum field out of range → **that field** falls to its documented default + one warn naming it; every other field is still honored. (AC-S2)
3. **Missing justification** — required `reason` missing (relaxed protection `optional`/`skip`, or a non-`ready` step) → decision **honored**, one `unjustified-policy` warn per offending field. A missing justification is a docs smell, not a safety failure — never let it flip to a stricter default. (AC-S3)
4. **Unknown key** — unknown `steps` key or unknown top-level key → ignored, one warn each; known keys unaffected. (AC-S4)
5. **Contradictory flow** — `release_flow.mode:"staged"` with null/absent `staging_branch` → contradictory; **discard `release_flow`** and use the built-in "staging if the branch exists, else prod" fallback + one warn. (AC-S5)
6. **Self-healing `init`** — `init` missing on an existing file → treated as `false`; the next gate run triggers `--init`, which sets it `true`.

An `--init`-written file re-loaded by a gate produces **zero** validation warnings (round-trip clean, AC-S6).

---

# Read-contract — how the gates resolve the policy file

Both gates load + validate **once per run**. **No file / malformed / `version` ≠ 1 → built-in defaults (today's behavior) + one info line.** Otherwise parse and apply per-field validation (bad enum → that field's default + warn; the rest is honored).

## 0 · `init` — the lifecycle gate (checked first)

```
init = policy.init ?? false          // file present but no `init` → false
```

| State | Gate behavior |
|---|---|
| file **absent** (repo never ran `/msg --init`) | built-in defaults + a one-line nudge to run `/msg --init` or `/pre-merge --init`. **No auto-init** — an ad-hoc gate run in an unmanaged repo is never hijacked (back-compat, AC-LC6). |
| `init: false` | **auto-run `--init` inline before the protocol** (AC-LC2). `--init` completes setup and flips `init:true` (AC-LC3), then the gate continues. If the user **aborts** `--init`, the gate stops — nothing was set up, so it runs **no** protocol step on a half-configured repo (AC-LC4). |
| `init: true` | run the protocol directly — no init run (AC-LC5). |

Lifecycle: `/msg --init` seeds `{init:false}` → first `/pre-merge` or `/post-merge` auto-runs `--init` → `--init` flips `init:true` → every later run is a normal gate. `--init` can still be invoked manually anytime to re-tune (it does not depend on `init`). (`--doctor` is a deprecated one-release alias for `--init` throughout this lifecycle.)

> **v3 pre-merge override (Fork C, AC-PF13/PF14).** The pre-merge executor gates on the
> **`components[]` manifest**, not on the `init` states above: a `/pre-merge` run with no
> `components[]` (file absent, malformed, or a pre-v3 policy) **refuses `no_manifest`** and
> names `/pre-merge --init` — it does **not** fall back to built-in defaults and does
> **not** auto-run `--init` inline (`AC-LC6`/`AC-ST5` retired). See
> `pre-merge/refs/executor.md`. Post-merge still follows the `init` table above until its
> own executor lands.

## 1 · `release_flow` (both gates)

```
flow = policies.release_flow.mode           ?? "staged"
prod = policies.release_flow.prod_branch    ?? "main"
stg  = policies.release_flow.staging_branch ?? "staging"
```

| `flow` | pre-merge base | post-merge `--staging` | post-merge `--production` |
|---|---|---|---|
| `staged` | `stg` (→ `prod` if `stg` absent — existing SKILL fallback) | merge feature→`stg` | PR `stg`→`prod` |
| `direct` | `prod` | **refuse** `no_staging_stage` (name `/post-merge --production` + `/msg --init-staging`) | single ship feature→`prod` |

**Direct-mode human-gate note.** In `direct` mode the `--production` ship **preserves every human gate** — double-confirmation, an inline human-test approval, deploy, and smoke. The **staging-scoped stages** — enumerated once in `post-merge/SKILL.md` § *Release flow*, never re-listed here — are **inactive because they do not apply**: there is no staging to deploy, test, or sign off. Inactive is not *skipped* (tooling missing) and not *relaxed* (threshold lowered): every stage that still applies runs at **full rigor**, and the safety floor is never among the inactive set. Fewer checks, never weaker ones. (AC-RF3, AC-RF4, AC-NS1/NS2/NS3) — canonical definition in `post-merge/SKILL.md` § *Release flow*.

## 2 · `branch_protection` (post-merge Step 1 `--staging` / Step 2 `--production`)

Per target branch `b`:

```
mode_b = overrides[b] ?? branch_protection.mode ?? "enforced"
```

| `mode_b` | on `--verify b` |
|---|---|
| `enforced` | `PROTECTED` → proceed · `UNPROTECTED` → **refuse** (`unprotected`), list missing controls (AC-BP1) |
| `optional` | `PROTECTED` → proceed · `UNPROTECTED` → **warn + proceed**, one `low` note in the report (AC-BP2) |
| `skip` | don't run `--verify`; report "protection check skipped by policy" (AC-BP3) |

**`NO_GH` / `NO_REMOTE` → refuse regardless of `mode_b`** — a PR can't be merged without them; the refusal cites the missing prerequisite, not protection. The protection mode governs **only** the `UNPROTECTED` case. (AC-BP5) No file → `enforced` everywhere (= today, AC-BP6). Per-branch differences resolve via `overrides` — e.g. `overrides.main:"enforced"` under top-level `mode:"optional"` enforces on `main` while `staging` stays optional (AC-BP4).

## 3 · `steps.<key>` (post-merge `deploy_*` / `smoke` / `ci`; pre-merge consult retired at v3 P3)

> **v3 note.** Pre-merge's per-step `steps.<key>` consult (the old Steps 2/3/5/6 skip/run
> decision) is **retired** — the executor decides run-vs-skip from component **presence**
> in `components[]` (an absent component simply isn't in the pipeline; AC-PF6). The table
> below still governs **post-merge**'s `deploy_staging`/`deploy_production`/`smoke` and the
> cross-cutting `ci` record, which are not yet on an executor.

| `status` | gate behavior |
|---|---|
| `ready` | detect live tool → run. **Live tool absent** → one `medium` `policy-mismatch` finding ("marked `ready`, no runner detected") **then** the step's own no-tooling path. Never silent. (AC-ST2, AC-ST3) |
| `opted_out` | **skip silently** — zero findings, zero warnings (AC-ST1) |
| `n/a` | **skip silently** — zero findings (AC-ST1) |
| `missing` | skip with the existing `no_tooling` note (known unresolved gap) (AC-ST4) |
| `deferred` | as `missing` (known gap, user will revisit) (AC-ST4) |
| key absent / no file | **built-in fall-back, unchanged** (back-compat invariant, AC-ST5) |

**`ci` — read by post-merge's green-CI check, not run as a step.** When post-merge's PR check finds an **empty** status-check set (nothing ran), it resolves `steps.ci`: `ready` → emit one `low` `vacuous-ci` note ("`ci` expected a pipeline but the PR reported zero checks") so a broken/absent workflow surfaces instead of a silent vacuous pass; `opted_out`/`n/a` → the empty set is intentional, proceed silently; `missing`/`deferred`/absent → existing behavior, no new note. It never blocks the merge — branch protection remains the enforcement.

**Invariant.** Except for the `policy-mismatch` finding above (AC-ST3), a `steps` entry **never** changes a gate's pass/fail verdict — it only decides run-vs-skip and how loudly a gap is surfaced (AC-ST6).

## 4 · `release_model` (post-merge, per platform)

`release_model` is authored the same way `tolerance` and `preview_kind` are: a
**per-platform column in `devkit/PLATFORMS.md`**, not a `policy.json` field
(D7). One human-authored source, one resolved consumer — no drift. Post-merge
reads it per shipping platform and branches every deploy/verify/rollback/lifecycle
decision on it (`post-merge/SKILL.md` § *Release model*):

| `release_model` | Meaning | Deploy-cmd exit 0 means | Verification | Rollback lever |
|---|---|---|---|---|
| `deploy` | synchronous (web, macOS, server) | the target is **live** | smoke the live target (`post-merge/refs/verify-deploy.md`) | redeploy the last-good build |
| `submission` | asynchronous (iOS, Android) | **submitted** to store review — never "live" | submission accepted; a configured smoke is **backend/build health**, never app liveness (`post-merge/refs/submission.md`) | halt the rollout |

**Resolution + inference (AC-RM1).** For each shipping platform, resolve
`release_model` from its PLATFORMS.md row. **Missing / blank → infer from platform
identity** (`web`/`macos`/`server` → `deploy`; `ios`/`android` → `submission`) and
emit a **warn in the resolution output** naming the platform and the inferred
value — never guess silently. An unknown platform with no `release_model` defaults
to `deploy` with the same warn.

**Mirrored into the resolved manifest (D7).** This follows the authored-source →
resolved-consumer pattern `tolerance` already uses (a PLATFORMS.md profile that
resolves into a component's `criticality`, §`components[]`). When post-merge
becomes component-driven (its own executor phase), each shipping platform's
resolved `release_model` is **mirrored into that platform's resolved
`components[]` entry** — the executor reads the identical value, no second read
path. Until then post-merge reads the PLATFORMS.md column directly.
