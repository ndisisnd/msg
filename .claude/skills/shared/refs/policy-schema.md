---
name: policy-schema
description: The shared core of devkit/policy.json — file lifecycle, writers, release_flow, github_actions, validation rules, and the read-contract sections both gates load. Per-gate sections live in policy-schema-pre-merge.md and policy-schema-merge.md.
type: reference
---

# `devkit/policy.json` — the committed policy file (shared core)

The single authoritative definition of `devkit/policy.json`: the **committed, shared** policy artifact both gate skills (`pre-merge`, `merge`) read at run time. It holds **decisions only** — release-flow shape, branch-protection stance, whether GitHub Actions CI is wanted at all, per-step opt-in/out — never per-machine binary presence (that is detected by the ephemeral `script-preflight-*.sh` family at `--init`/`--update` time and resolved into each component's `run` command, never persisted as a standalone fingerprint). Because it's committed, its decisions travel to CI and teammates. It sits next to its sibling configs `devkit/PLATFORMS.md` and `devkit/ENV.md`.

## This file is the core — the halves are separate

A gate run should load only what it reads. The schema is therefore three files:

| File | Holds | Loaded by |
|---|---|---|
| **`policy-schema.md`** (this file) | file lifecycle + writers · `repo` · `policies.release_flow` · `policies.github_actions` · validation rules · read-contract §0 / §1 / §2b | **both** gates, every run |
| [`policy-schema-pre-merge.md`](policy-schema-pre-merge.md) | `components[]` · `policies.test_selection` (+ read-contract §2c) · `source_signature` · `criticality_review` | **pre-merge** only |
| [`policy-schema-merge.md`](policy-schema-merge.md) | `policies.branch_protection` (§2) · `policies.staging_readiness` · `steps.<key>` (+ §3) · `release_model` (§4) · `staging_ready` (§5) · the release lock (§6) | **merge** only |

Read-contract section numbers are **stable across the split** — §2c is still §2c, it just lives in the pre-merge half. A citation only changes filename, never number.

The **env-setup contract** is not in `policy.json` at all: it is [`devkit/ENV.md`](env-contract.md), a human-authored devkit doc both gates read (the `PLATFORMS.md` precedent). See [`env-contract.md`](env-contract.md).

**Writers — the only ones:**

| Writer | Writes |
|---|---|
| `/msg --init` | **seed** — `version`, `init:false`, `generated`, `policies.release_flow`, and `policies.github_actions` when the CI question was asked (nothing else) |
| `/msg --update` | **CI decision** — sets/changes `policies.github_actions`, and the **test-selection decision** `policies.test_selection` (the only keys it writes; it otherwise delegates to `/msg --init`'s top-up) |
| `/msg --init-staging` | **flow flip** — sets `release_flow.mode:"staged"`, `staging_branch:"staging"` after creating the branch |
| pre-merge setup (the first `/pre-merge` run) | **completion** — runs the preflight checks, assembles `components[]`, stamps `source_signature`, fills tooling, then writes `init:true` with an explicit `--set init=true`. Also scaffolds `devkit/ENV.md` — a devkit doc, not a policy key |
| merge setup (the first `/merge` run) and `/merge --update` | **completion / reconcile** — fills `branch_protection`, `steps.deploy_*`/`smoke`, `policies.merge` (`risky_paths`, `ci_wait_minutes`), records `staging_ready` (`staged` flow only), writes `init:true`. Reads `release_flow` and reports a mismatch — never writes it (`/msg --init` is its one writer) |
| a `/merge` run | **risky-path growth** — appends a newly found auth/payment folder to `policies.merge.risky_paths` (never removes one) |
| `--update` | **reconcile** — re-runs the preflight checks, diffs `components[]` vs reality, applies approved `present`/`run`/`tooling`/`status`/`active_when` changes and new components, restamps `source_signature` (never re-grades user-set `criticality`, never re-prompts `opted_out`/`n/a`) |
| pre-merge's critical-test tagging (gate step, test selection on) | **criticality stamp** — writes critical markers into the test files (committed on the branch) and restamps `criticality_review` (`{reviewed_at, suite_hash}`). Never re-grades or removes an existing tag (AC-TS7); writes **no other** policy key |

Every write goes through **`.claude/scripts/script-policy-set.py`** — the one sanctioned
writer. It sets a dotted key path, creates missing parents, preserves every sibling,
stamps `generated`/`generated_by` from the system clock, re-parses the result, and rolls
back a bad write. No skill hand-authors this file.

No gate run writes it (AC-OW1, AC-UP6) — a gate only recomputes `source_signature`
read-only to nudge (Fork E). Two exceptions, both pre-merge: a first run's setup (which
completes before the gate starts), and the `criticality_review` stamp of the
critical-test tagging step. Setup never writes `devkit/PLATFORMS.md` (that stays `/msg --init`'s).

## Canonical v1 schema (annotated — core keys)

```json
{
  "version": 1,                          // must be 1; any other value → file treated as absent
  "init": true,                          // lifecycle gate: false → the next gate run sets itself up first
  "generated": "2026-07-16",             // YYYY-MM-DD, stamped by script-policy-set.py
  "generated_by": "merge setup",   // last writer; informational
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
    "github_actions": {
      "enabled": false,                  // false → the gates never expect Actions to run
      "reason": "private repo on GitHub Free — no Actions minutes to spend"
    }
    // branch_protection, staging_readiness → policy-schema-merge.md
    // test_selection                     → policy-schema-pre-merge.md
    // agent_watch                        → below, § policies.agent_watch
    // intake                             → below, § policies.intake
  }
  // components[], source_signature, criticality_review → policy-schema-pre-merge.md
  // steps{}, staging_ready               → policy-schema-merge.md
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
    "release_flow": { "mode": "staged", "prod_branch": "main", "staging_branch": "staging" },
    "intake": { "brainstorm": true },
    "github_actions": { "enabled": true }
  }
}
```

`policies.github_actions` appears in the seed only when `/msg --init` actually
asked the CI question (it is gated on a GitHub remote — see
`msg/refs/protocol-init.md` Step 5). Omitted ⇒ the gates behave exactly as they
did before the key existed.

## Field spec

### Top-level

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `version` | int | ✔ | — | must be `1`; any other value → whole file treated as absent (AC-S1) |
| `init` | bool | ✔ | `false` (if omitted) | lifecycle gate. `false` → the next gate run sets itself up first (§0); `true` → gates run the protocol. `/msg --init` seeds `false`; each gate's setup writes `true` on completion |
| `generated` | `YYYY-MM-DD` | ✔ | — | stamped by `script-policy-set.py` from the system clock (`--stamp-by`); informational |
| `generated_by` | enum `msg --init` \| `msg --update` \| `msg --init-staging` \| `pre-merge setup` \| `pre-merge --update` \| `merge setup` \| `merge --update` | ✖ | — | last writer; informational. Older repos may still carry `merge --init`, or (before v5) `post-merge --init` / `post-merge --update`; nothing branches on this field, so the old string is read and displayed as written, never rejected or rewritten |
| `repo` | object | ✖ | — | evidence/audit only — gates never branch on it |
| `policies` | object | ✖ | `{}` | the enforced half |
| `components` | object[] | ✖ | — | the **preflight manifest** — the per-project deltas over the catalog. Purely **additive** to the same file (AC-PF5). Spec: [`policy-schema-pre-merge.md`](policy-schema-pre-merge.md) § `components[]` |
| `source_signature` | string | ✖ | — | staleness hash of the detect-section tuple across all preflight reports (AC-UP4). Spec: [`policy-schema-pre-merge.md`](policy-schema-pre-merge.md) |
| `criticality_review` | object | ✖ | — | the test-tree review stamp `{reviewed_at, suite_hash}`. Spec: [`policy-schema-pre-merge.md`](policy-schema-pre-merge.md) |
| `steps` | object | ✖ | `{}` | per-step decisions — **merge's** `ci` / `deploy_staging` / `deploy_production` / `smoke` keys only. Spec: [`policy-schema-merge.md`](policy-schema-merge.md) |
| `staging_ready` | object | ✖ | — | per-platform staging-readiness resolved by merge setup / `--update`. Spec: [`policy-schema-merge.md`](policy-schema-merge.md) § 5 |

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

### `policies.github_actions` — is GitHub Actions CI expected at all?

The user's answer to "do you want GitHub Actions running your CI?". Not every
repo can afford one: private repos on GitHub Free meter Actions minutes, and some
teams run CI elsewhere or not at all. This key lets them say so **once**, in a
committed file, instead of every gate run rediscovering the absence and nagging.

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `enabled` | bool | ✔ | `true` | `false` → gates treat the **CI stage as inactive**: an empty PR check set is intentional, never a gap to report or scaffold away |
| `reason` | string | recommended when `enabled:false` | — | governance note (e.g. "no Actions minutes on Free"); missing → honored + `unjustified-policy` warn (AC-S3) |

**Written only by `/msg --init` (Step 5) and `/msg --update`** — it is the user's
setup decision, not a detection result. No gate run ever writes it (AC-OW1).
Absent object ⇒ `enabled: true` ⇒ pre-key behaviour, so existing `policy.json`
files need no migration.

### `policies.intake` — the intake brainstorm switch

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `brainstorm` | bool | ✖ | `false` when absent | `true` → plain `/intake` suggests in-scope related ideas. `/msg --init` seeds `true`. Absent (a project seeded before the key) → `false`, so existing projects see no change |

Read only by `intake` (`intake/SKILL.md` § Usage). Written by `/msg --init` (seed) and by
`/intake --brainstorm on|off`, both through `script-policy-set.py`. A bare `--brainstorm`
turns suggestions on for one run and writes nothing. **Not** read by the gates.

### `policies.plan_pm` / `policies.plan_em` — the auto-review switches

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `review` | bool | ✖ | `false` when absent | `true` → the skill runs `/plan-review` on its PRD at the end of its run. `false` → the closing message only suggests it |

`policies.plan_pm.review` is read only by `plan-pm`; `policies.plan_em.review` only by `plan-em`
(at the end of the plan half). Written by `/plan-pm --review on|off` and `/plan-em --review on|off`
through `script-policy-set.py`. A bare `--review` runs plan-review for one run and writes nothing.
`/msg --init` does not seed them. plan-em's certification gate does not depend on this switch:
an uncertified PRD is still certified before engineering.

### Retired: `policies.status_cadence`

Progress messages are always on, every 5 minutes (`status-heartbeat.md` § *Cadence*).
An old `policies.status_cadence` key (`enabled`, `interval_minutes`) is **ignored
without error** — no validation warning, no migration. No writer adds it.

### `policies.agent_watch` — the subagent stall-detection thresholds

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `enabled` | bool | ✖ | `true` | `false` disables stall detection project-wide, absent a per-run override |
| `notice_minutes` | int | ✖ | `5` | idle age at which a leaf is banked as a note — no finding |
| `warn_minutes` | int | ✖ | `10` | idle age at which a leaf raises a `low` finding |
| `stall_minutes` | int | ✖ | `15` | idle age at which a leaf is assumed stalled — `high` finding plus one visible line asking the human to decide |

Read only by `.claude/scripts/script-agent-watch.sh`, once, at the first
`--register` of a run — absent, unreadable or malformed falls through silently to
the built-in defaults. Ordering `notice < warn < stall` is enforced by the script
with one stderr note. **Not** read by `script-policy-read.py`, so no skill plumbs
this key itself. Per-run override (`MSG_WATCH_THRESHOLD`, `0` disables) and the
escalation ladder: `agent-watch.md`.

**These four keys are the whole schema — there is deliberately no `action` key.**
The watch is observational: no auto-stop exists in any configuration, and no policy
setting can create one. Only a human stops a leaf.

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

The sections below are the **shared** half. Pre-merge additionally loads
[`policy-schema-pre-merge.md`](policy-schema-pre-merge.md) (§2c); merge additionally
loads [`policy-schema-merge.md`](policy-schema-merge.md) (§2, §3, §4, §5, §6).
Neither loads the other's.

## 0 · `init` — the lifecycle gate (checked first)

```
init = policy.init ?? false          // file present but no `init` → false
```

Neither gate has a separate setup command: each gate's **first run** sets itself up
inline, saves, and continues into the gate in the same run. Each gate tests its **own**
setup marker, because `init:true` from one gate says nothing about the other:

| Gate | Set up when | Not set up ⇒ |
|---|---|---|
| pre-merge | `components[]` is present | run pre-merge setup inline (`pre-merge/refs/protocol-init.md`), save, continue. A malformed file stops with its parse error (`pre-merge/refs/executor.md` §0) |
| merge | `policies.merge` is present **and** `init` is not `false` | run merge setup inline (`merge/refs/protocol-init.md`), save, continue. The user aborts setup ⇒ the gate stops and runs **no** protocol step on a half-configured repo |
| either | file **absent** | run `/msg --init` first (it seeds the file and owns `release_flow`), then the gate's setup |

Lifecycle: `/msg --init` seeds `{init:false}` → the first `/pre-merge` and the first
`/merge` each run their own setup → each setup writes `init:true` → every later run is a
normal gate. To redo setup, run `/pre-merge --update` or `/merge --update`.

## 1 · `release_flow` (both gates)

```
flow = policies.release_flow.mode           ?? "staged"
prod = policies.release_flow.prod_branch    ?? "main"
stg  = policies.release_flow.staging_branch ?? "staging"
```

| `flow` | pre-merge base | merge `--staging` | merge `--production` |
|---|---|---|---|
| `staged` | `stg` (→ `prod` if `stg` absent — long-standing fallback) | merge feature→`stg` | PR `stg`→`prod` |
| `direct` | `prod` | **refuse** `no_staging_stage` (name `/merge --production` + `/msg --init-staging`) | single ship feature→`prod` |

**Direct-mode human-gate note.** In `direct` mode the `--production` ship **preserves every human gate** — double-confirmation, the **inline human-test approval** (defined once in `merge/refs/production.md` § *Inline human-test approval*; fires **before the merge**, immediately after the double-confirm and before the release lock is acquired — the merge to `prod` is the irreversible action, so a Cancel leaves nothing merged and nothing held), deploy, and smoke. The **staging-scoped stages** — enumerated once in `policy-schema-merge.md` §1b, never re-listed here — are **inactive because they do not apply**: there is no staging to deploy, test, or sign off. Inactive is not *skipped* (tooling missing) and not *relaxed* (threshold lowered): every stage that still applies runs at **full rigor**, and the safety floor is never among the inactive set. Fewer checks, never weaker ones. (AC-RF3, AC-RF4, AC-NS1/NS2/NS3) — canonical definition in `policy-schema-merge.md` §1b.

## 2b · `github_actions` (merge green-CI checks; both `--init`s)

```
ga = policies.github_actions.enabled ?? true
```

| `ga` | gate behavior |
|---|---|
| `true` (or absent) | **unchanged** — every CI expectation and note documented elsewhere applies verbatim (AC-GA5) |
| `false` | the **CI stage is inactive**: an **empty** PR/commit status set is intentional — proceed silently, no `vacuous-ci` note, no "run `/pre-merge --update`" nudge, no workflow-scaffold offer. Report one line: "GitHub Actions disabled by policy (`<reason>`) — change with `/msg --update`" (AC-GA1, AC-GA3) |

**`false` never means "ignore CI that exists."** If the PR *does* report checks —
an external CI posting commit statuses, a leftover workflow, a required check
from branch protection — they are evaluated exactly as under `true`: red or
pending still refuses (`red_ci`/`pending_ci`). The opt-out governs **only** the
*empty-set* case, i.e. the absence of a pipeline (AC-GA2).

**Inactive, not skipped or relaxed.** No threshold moves and no human gate is
removed: double-confirmation, human-test approval, deploy, smoke, and the safety
floor are untouched (AC-GA4). Canonical vocabulary in `policy-schema-merge.md` §1b.

**Branch protection is unaffected.** `script-branch-protection.sh --bootstrap`
already sets `required_status_checks {strict:true, contexts:[]}`, so protection
verifies `PROTECTED` with zero named checks — `ga:false` and
`branch_protection.mode:"enforced"` compose without conflict.

**Precedence over `steps.ci`.** When `ga` is `false`, merge's empty-check-set
resolution against `steps.ci` is not consulted at all — the user's explicit opt-out
beats a stale detection record (AC-GA6). See
[`policy-schema-merge.md`](policy-schema-merge.md) §3.
