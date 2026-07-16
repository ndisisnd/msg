---
name: policy-schema
description: Canonical schema, status vocabulary, and gate read-contract for devkit/policy.json — the committed, shared policy file seeded by /msg --init, flipped by /msg --init-staging, completed by --doctor, and read by both gates
type: reference
---

# `devkit/policy.json` — the committed policy file

The single authoritative definition of `devkit/policy.json`: the **committed, shared** policy artifact both gate skills (`pre-merge`, `post-merge`) read at run time. It holds **decisions only** — release-flow shape, branch-protection stance, per-step opt-in/out — never per-machine binary presence (that lives in the ephemeral `pre-merge-tooling-detect.sh` fingerprint, never persisted). Because it's committed, its decisions travel to CI and teammates. It sits next to its sibling config `devkit/PLATFORMS.md`.

**Writers — the only three:**

| Writer | Writes |
|---|---|
| `/msg --init` | **seed** — `version`, `init:false`, `generated`, `policies.release_flow` (nothing else) |
| `/msg --init-staging` | **flow flip** — sets `release_flow.mode:"staged"`, `staging_branch:"staging"` after creating the branch |
| `--doctor` | **completion** — fills tooling + `branch_protection`, flips `init:true` |

No gate run ever writes it (AC-OW1). `--doctor` never writes `devkit/PLATFORMS.md` (that stays `/msg --init`'s).

## Canonical v1 schema (annotated)

```json
{
  "version": 1,                          // must be 1; any other value → file treated as absent
  "init": true,                          // lifecycle gate: false → gates auto-run --doctor first
  "generated": "2026-07-16",             // YYYY-MM-DD, stamped by the writing skill
  "generated_by": "post-merge --doctor", // last writer; informational
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

Release-flow answers captured, tooling not yet resolved, `init:false` so the first gate run triggers `--doctor`. Idempotent: `/msg --init` never overwrites an existing `policy.json` (AC-LC7).

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
| `init` | bool | ✔ | `false` (if omitted) | lifecycle gate. `false` → gates auto-run `--doctor` first; `true` → gates run the protocol. `/msg --init` seeds `false`; `--doctor` flips it `true` on completion |
| `generated` | `YYYY-MM-DD` | ✔ | — | stamped by the skill (scripts can't date); informational |
| `generated_by` | enum `msg --init` \| `msg --init-staging` \| `pre-merge --doctor` \| `post-merge --doctor` | ✖ | — | last writer; informational |
| `repo` | object | ✖ | — | evidence/audit only — gates never branch on it |
| `policies` | object | ✖ | `{}` | the enforced half |
| `steps` | object | ✖ | `{}` | per-step decisions |

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

## Closed step-key vocabulary (16 keys)

Any key outside this set → ignored + one warn (AC-S4):

`mechanical` · `unit_int` · `e2e` · `qa` · `a11y` · `perf` · `load` · `api` · `mobile` · `coverage` · `security` · `migration` · `ci` · `deploy_staging` · `deploy_production` · `smoke`

`ci` records whether a `.github/workflows/` pipeline runs the gate on PRs (written by
`pre-merge --doctor`, read by post-merge's green-CI check — see §3). It has no runner and never
runs as a gate *step*; it exists so a missing pipeline surfaces instead of passing vacuously.

## Validation rules

Fail-safe throughout — a malformed policy never aborts a gate run.

1. **Parse failure** — malformed JSON, or `version` ≠ 1 → **treat the whole file as absent**; gates use built-in defaults; emit exactly **one** info line. Never abort the run on a parse error. (AC-S1)
2. **Bad enum** — any enum field out of range → **that field** falls to its documented default + one warn naming it; every other field is still honored. (AC-S2)
3. **Missing justification** — required `reason` missing (relaxed protection `optional`/`skip`, or a non-`ready` step) → decision **honored**, one `unjustified-policy` warn per offending field. A missing justification is a docs smell, not a safety failure — never let it flip to a stricter default. (AC-S3)
4. **Unknown key** — unknown `steps` key or unknown top-level key → ignored, one warn each; known keys unaffected. (AC-S4)
5. **Contradictory flow** — `release_flow.mode:"staged"` with null/absent `staging_branch` → contradictory; **discard `release_flow`** and use the built-in "staging if the branch exists, else prod" fallback + one warn. (AC-S5)
6. **Self-healing `init`** — `init` missing on an existing file → treated as `false`; the next gate run triggers `--doctor`, which sets it `true`.

A `--doctor`-written file re-loaded by a gate produces **zero** validation warnings (round-trip clean, AC-S6).

---

# Read-contract — how the gates resolve the policy file

Both gates load + validate **once per run**. **No file / malformed / `version` ≠ 1 → built-in defaults (today's behavior) + one info line.** Otherwise parse and apply per-field validation (bad enum → that field's default + warn; the rest is honored).

## 0 · `init` — the lifecycle gate (checked first)

```
init = policy.init ?? false          // file present but no `init` → false
```

| State | Gate behavior |
|---|---|
| file **absent** (repo never ran `/msg --init`) | built-in defaults + a one-line nudge to run `/msg --init` or `/pre-merge --doctor`. **No auto-doctor** — an ad-hoc gate run in an unmanaged repo is never hijacked (back-compat, AC-LC6). |
| `init: false` | **auto-run `--doctor` inline before the protocol** (AC-LC2). `--doctor` completes setup and flips `init:true` (AC-LC3), then the gate continues. If the user **aborts** `--doctor`, the gate stops — nothing was set up, so it runs **no** protocol step on a half-configured repo (AC-LC4). |
| `init: true` | run the protocol directly — no doctor (AC-LC5). |

Lifecycle: `/msg --init` seeds `{init:false}` → first `/pre-merge` or `/post-merge` auto-runs `--doctor` → `--doctor` flips `init:true` → every later run is a normal gate. `--doctor` can still be invoked manually anytime to re-tune (it does not depend on `init`).

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

**Direct-mode human-gate note.** In `direct` mode the `--production` ship **preserves every human gate** — double-confirmation, an inline human-test approval, deploy, and smoke — but **waives** the `staging-signoff:` precondition (there is no staging to sign off) and runs **no** staging deploy. Nothing that protects the human is dropped; only the staging *stage* is gone. (AC-RF3, AC-RF4)

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

## 3 · `steps.<key>` (pre-merge 2/3/5/6; post-merge `deploy_*` / `smoke` / `ci`)

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
