---
name: policy-schema-merge
description: The merge half of the devkit/policy.json schema — branch_protection (§2), staging_readiness, steps.<key> (+ §3), release_model (§4), staging_ready (§5), and the release lock (§6). Pre-merge never loads this file.
type: reference
---

# `devkit/policy.json` — the merge half

The sections **only merge reads**. The shared core (lifecycle, writers,
`release_flow`, `github_actions`, validation rules, read-contract §0/§1/§2b) is
[`policy-schema.md`](policy-schema.md); pre-merge's sections are
[`policy-schema-pre-merge.md`](policy-schema-pre-merge.md). Section numbers are shared
across the three files — §2 is §2 wherever it lives.

## `policies.branch_protection` — per-branch protection stance

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `mode` | enum `enforced` \| `optional` \| `skip` | ✔ | `enforced` | repo-wide default, resolved per branch |
| `reason` | string | required when `mode` ≠ `enforced` | — | governance note; missing → honored + `unjustified-policy` warn (AC-S3) |
| `overrides` | object `<branch, mode>` | ✖ | `{}` | per-branch mode; resolved as `overrides[b] ?? mode` |

## `policies.staging_readiness` — the staging-readiness guard stance

Governs how merge `--staging` reacts to an **unready** staging environment
(gaps recorded in `staging_ready`, below). **Mirrors `branch_protection`'s
vocabulary and default** — same three modes, same safe default.

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `mode` | enum `enforced` \| `optional` \| `skip` | ✖ | `enforced` | `enforced` → a recorded gap **refuses** the ship; `optional` → **warns + proceeds**; `skip` → don't guard. Default matches `branch_protection` (`enforced`) — the safe stance |
| `reason` | string | required when `mode` ≠ `enforced` | — | governance note; missing → honored + `unjustified-policy` warn (AC-S3), as with `branch_protection` |

A **missing `staging_ready` record** (pre-C9 init, or never `--init`ed) is
handled by the guard as a *warn + proceed regardless of `mode`* — it is never a
refusal (see §5); `mode` governs only the **recorded-gap** case.

## `steps.<key>` — merge's per-step decisions

**Four live keys** — `ci`, `deploy_staging`, `deploy_production`, `smoke`. These are the
only `steps` entries any consumer still reads; pre-merge decides run-vs-skip from
`components[]` presence and never consults `steps` (AC-PF6). Pre-merge `--init` still
*writes* `steps.ci` (it detects the workflow) — merge reads it.

```json
"steps": {
  "ci":                { "status": "ready", "chosen": ".github/workflows/pre-merge.yml" },
  "deploy_staging":    { "status": "ready" },
  "deploy_production": { "status": "ready" },
  "smoke":             { "status": "missing", "reason": "declared in PLATFORMS.md, never verified" }
}
```

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `status` | enum `ready` \| `opted_out` \| `n/a` \| `missing` \| `deferred` | ✔ | — | persisted vocabulary — **no `installed`** (a just-installed tool is persisted as `ready`) |
| `reason` | string | required for `opted_out`/`n/a`/`deferred` | — | missing → honored + `unjustified-policy` warn (AC-S3) |
| `chosen` | string \| string[] | ✖ | — | the tool(s) selected for a `ready` step |
| `last_checked` | `YYYY-MM-DD` | ✖ | — | informational |

Any `steps` key outside `ci` · `deploy_staging` · `deploy_production` · `smoke` →
ignored + one warn (AC-S4).

---

# Read-contract (merge)

## 2 · `branch_protection` (Step 1 `--staging` / Step 2 `--production`)

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

## 3 · `steps.<key>` (`deploy_*` / `smoke` / `ci`)

| `status` | gate behavior |
|---|---|
| `ready` | detect live tool → run. **Live tool absent** → one `medium` `policy-mismatch` finding ("marked `ready`, no runner detected") **then** the step's own no-tooling path. Never silent. (AC-ST2, AC-ST3) |
| `opted_out` | **skip silently** — zero findings, zero warnings (AC-ST1) |
| `n/a` | **skip silently** — zero findings (AC-ST1) |
| `missing` | skip with the existing `no_tooling` note (known unresolved gap) (AC-ST4) |
| `deferred` | as `missing` (known gap, user will revisit) (AC-ST4) |
| key absent / no file | **built-in fall-back, unchanged** (back-compat invariant, AC-ST5) |

**`ci` — read by merge's green-CI check, not run as a step.** It records whether a
`.github/workflows/` pipeline runs the gate on PRs (written by `pre-merge --init`). It has
no runner and never runs as a gate *step*; it exists so a missing pipeline surfaces instead
of passing vacuously. When merge's PR check finds an **empty** status-check set
(nothing ran), it resolves `steps.ci`: `ready` → emit one `low` `vacuous-ci` note
("`ci` expected a pipeline but the PR reported zero checks"); `opted_out`/`n/a` → the empty
set is intentional, proceed silently; `missing`/`deferred`/absent → existing behavior, no
new note. It never blocks the merge — branch protection remains the enforcement.

**Precedence: `github_actions` outranks `steps.ci`.** When `ga` is `false`
([`policy-schema.md`](policy-schema.md) §2b) the empty-set resolution above is not consulted
at all — the user's explicit opt-out beats a stale detection record, so a `steps.ci: ready`
written before the opt-out never produces a `vacuous-ci` note. `steps.ci` still governs the
empty-set case whenever `ga` is `true` or absent (AC-GA6).

**Invariant.** Except for the `policy-mismatch` finding above (AC-ST3), a `steps` entry **never** changes a gate's pass/fail verdict — it only decides run-vs-skip and how loudly a gap is surfaced (AC-ST6).

## 4 · `release_model` (per platform)

`release_model` is authored the same way `tolerance` is: a
**per-platform column in `devkit/PLATFORMS.md`**, not a `policy.json` field
(D7). One human-authored source, one resolved consumer — no drift. Merge
reads it per shipping platform and branches every deploy/verify/rollback/lifecycle
decision on it (`merge/SKILL.md` § *Release model*):

| `release_model` | Meaning | Deploy-cmd exit 0 means | Verification | Rollback lever |
|---|---|---|---|---|
| `deploy` | synchronous (web, server, **directly-distributed macOS**) | the target is **live** | smoke the live target (`merge/refs/verify-deploy.md`) | redeploy the last-good build — **`rollback_cmd`**, offered on a failed ship before the fix loop (C3, `merge/SKILL.md`) |
| `submission` | asynchronous (iOS, Android, **Mac App Store macOS**) | **submitted** to store review — never "live" | submission accepted; a configured smoke is **backend/build health**, never app liveness (`merge/refs/submission.md`) | halt the rollout — **`rollout_halt_cmd`**, offered once a rollout exists (C3) |

**Resolution + inference (AC-RM1).** For each shipping platform, resolve
`release_model` from its PLATFORMS.md row. **Missing / blank → infer from platform
identity** (`web`/`server` → `deploy`; `ios`/`android` → `submission`) and
emit a **warn in the resolution output** naming the platform and the inferred
value — never guess silently. An unknown platform with no `release_model` defaults
to `deploy` with the same warn.

**`macos` is the one identity that does not settle the model.** A
directly-distributed, Sparkle-updated `.app` is `deploy`; a Mac App Store build is
`submission` (App Store Connect is the same console iOS uses). So a **macOS row
declares its model**. An undeclared one still falls back to `deploy` so the run
proceeds, and carries a macOS-specific warn naming the declaration as the fix —
the fallback is a courtesy, not an inference from identity.

**Mirrored into the resolved manifest (D7).** This follows the authored-source →
resolved-consumer pattern `tolerance` already uses (a PLATFORMS.md profile that
resolves into a component's `criticality`). When merge becomes component-driven
(its own executor phase), each shipping platform's resolved `release_model` is
**mirrored into that platform's resolved `components[]` entry** — the executor reads
the identical value, no second read path. Until then merge reads the PLATFORMS.md
column directly.

## 5 · `staging_ready` (`--staging`)

`staging_ready` is a **resolved fact, not settled policy** — the same additive
style as `release_model`'s resolution, but persisted rather than re-derived each
run. Merge `--init` writes it (item 6, `refs/protocol-init.md`) by running
the **declared-artifact checks** per shipping platform under `release_flow=staged`;
`--staging` **reads** it to guard the ship. Because it is a fact, it is
**re-derived on every re-init** and carries no user decisions to preserve (unlike
`branch_protection`/`opted_out`, which `--update` never re-grades). In `direct`
flow it is **absent** — there is no staging to verify (AC-SR4).

```json
"staging_ready": {
  "resolved_at": "2026-07-21",
  "resolved_by": "merge --init",
  "platforms": {
    "web": { "ready": true,  "gaps": [] },
    "ios": {
      "ready": false,
      "gaps": [
        "staging_deploy_cmd is a [USER: …] placeholder — set it to your internal/TestFlight track deploy (e.g. `fastlane beta`), then re-run /merge --init"
      ]
    }
  }
}
```

| Field | Type | Notes |
|---|---|---|
| `resolved_at` | `YYYY-MM-DD` | when readiness was last derived (stamped by `script-policy-set.py` from the system clock) |
| `resolved_by` | string | writer provenance — `merge --init` (informational) |
| `platforms` | object `<platform, {ready, gaps}>` | one entry per shipping platform in `PLATFORMS.md` |
| `platforms.<p>.ready` | bool | `true` iff every declared staging artifact for `<p>` is present + non-placeholder (item 6) |
| `platforms.<p>.gaps` | string[] | empty when `ready`; else each entry names the **exact missing artifact + the exact fix** (AC-SR2) |

**Read-contract (`--staging` guard, `refs/staging.md`).** Resolve
`mode = policies.staging_readiness.mode ?? "enforced"` (mirrors `branch_protection`):

| Record state | Guard behavior |
|---|---|
| **absent** (pre-C9 init / never `--init`ed) | **warn + proceed regardless of `mode`** — one `low` note recommending `/merge --init`; **never a refusal** solely because the record predates C9 |
| present, **every** shipping platform `ready:true` | proceed silently |
| present, **any** platform with `gaps[]` | `enforced` → **refuse** (`staging_unready`), listing each platform's gaps + fix; `optional` → **warn + proceed**, one `low` note per unready platform; `skip` → don't guard |

The guard is **inactive under `release_flow=direct`** (there is no staging — the
staging-scoped stages do not apply; `merge/SKILL.md` § *Release flow*).

## 6 · Release lock (`--production`) — C8

The **release lock** serializes production ships so two `--production` runs (two
terminals, two teammates, a retry over a live ship) cannot race on `prod`
(`merge/refs/production.md` § *Release lock*). It is **runtime state on the
remote, not a `policy.json` decision** — like a resolved `release_model` and unlike
`branch_protection`, it is derived/held per run, never persisted as settled policy.
Documented here because this file is the canonical home for merge's
release-shape contract (`release_model` §4, `staging_ready` §5).

| Aspect | Value |
|---|---|
| **Mechanism** | an **annotated git tag** `release-lock-<prod>` (e.g. `release-lock-main`) pushed to the remote — reuses P3's pushed-tag primitive; a tag is metadata on a commit, writes **no tracked file**, so the safety floor holds (D8) |
| **Where the state lives** | the **remote** (`refs/tags/release-lock-<prod>`) — survives across machines, so a teammate on another laptop sees the same lock. Not in `policy.json`, not a local file |
| **Atomicity** | a tag ref is never fast-forwarded — pushing an existing tag name is **rejected** without `--force`; that rejection is the atomic compare-and-swap-to-absent (create ⇒ acquired, reject ⇒ someone holds it) |
| **Holder metadata** | the annotated tag message carries `held-by` / `mode` / `at` / `sha` / `prds` — read to name the in-flight run in a `release_in_flight` refusal (AC-LK1) |
| **Acquire point** | `--production` only, **after Step 3 (double-confirm), before Step 4 (open PR)** — late enough that every pre-flight refusal (Steps 1–2, a Step 3 cancel) skips the lock, early enough to cover the mutating window (Steps 4–9). Both flows (`staged` + `direct`) acquire — a direct feature→`prod` ship races the same way |
| **Release** | unconditional for any run that acquired it — deletes the remote tag, never dangles on a graceful exit (AC-LK2). Timing: success / refusal-after-acquire (Step 4 `no_prd`, post-acquire coverage-drift `stale_signoff`, `direct` inline human-test `human_test_declined`, Step 5 `red_ci`/`no_review`/`merge_failed`, Step 6 `nonmonotonic_build`) → at run termination; **failed ship → at ship-terminal, *before* the fix-loop handoff**, so the long fix loop never holds the lock (`merge/refs/production.md` § *Release lock*) |
| **TTL / staleness** | **120 minutes (2h)**, from the tagger date. A lock older than the TTL is **stale** — reported with the manual-unlock instruction, **never** blindly refused forever and **never** auto-stolen (auto-steal reopens the race). Fixed constant (no new config surface — CV1/D4) |
| **Manual unlock (escape hatch)** | `git push origin :refs/tags/release-lock-<prod>` (delete the remote tag), then `git tag -d release-lock-<prod>` locally. A wedged lock must never dead-end a solo dev (CV1) — this one-liner is documented prominently in `production.md`, `staging.md`, and `refusal-patterns.md` |
| **`--staging` interaction** | `--staging` **reads** the lock as a pre-flight (before Step 2) and **refuses** `release_in_flight` if a non-stale production release holds it — a staging merge mid-production-ship advances `staging` past the certified window (C2). Asymmetric: `--staging` never **acquires** (its merge is near-atomic) |
| **Infra-error fail-open** | an acquire push that fails for a **non-contention** reason (network/permission, not "already exists") emits one `low` note and **proceeds without the guard** — the lock is a safety *assist*, not a floor; a flaky network must not block the one dev (CV1) |

The lock is **absent from `policy.json`** and adds **no required field** (CV2 — the
schema change is purely documentary/additive). Its per-run state surfaces in the
run report's additive `release_lock` block (`merge/refs/output-schema.md`).
