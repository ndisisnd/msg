---
name: policy-schema-pre-merge
description: The pre-merge half of the devkit/policy.json schema — the components[] delta manifest, policies.test_selection (+ read-contract §2c), source_signature, and criticality_review. Post-merge never loads this file.
type: reference
---

# `devkit/policy.json` — the pre-merge half

The sections **only pre-merge reads**. The shared core (lifecycle, writers,
`release_flow`, `github_actions`, validation rules, read-contract §0/§1/§2b) is
[`policy-schema.md`](policy-schema.md); post-merge's sections are
[`policy-schema-post-merge.md`](policy-schema-post-merge.md). Section numbers are
shared across the three files — §2c is §2c wherever it lives.

## `components[]` — the preflight manifest (deltas only)

The manifest records **per-project facts only**. Everything constant across every repo —
`nn`, `group`, `kind`, `cost`, `depends_on`, `active_when`, `platforms`, `mandatory`, and
the *default* `criticality` — is **catalog metadata**, resolved at run time by joining each
entry's `id` against [`component-catalog.md`](component-catalog.md). The manifest never
copies it.

**Why deltas, not a snapshot.** A copied constant is a drift class: `--update` reconciles
facts, so a catalog change (a new `depends_on` edge, a shifted criticality default) would
never reach an existing manifest. Not copying it is the fix — a catalog edit is live for
every repo on the next gate run, with no migration (AC-UP2).

`--init`/`--update` assemble the manifest by running the `preflight-check-*.sh` family and
recording what detection found plus what the user decided. **Additive** — it lives beside
`release_flow`/`github_actions`/`init`, which are untouched (AC-PF5). The pre-merge
**executor** reads it as the pipeline source (`pre-merge/refs/executor.md`); a `/pre-merge`
run with **no** `components[]` refuses `no_manifest` (Fork C, AC-PF13/PF14).

```json
"components": [
  {
    "id": "mechanical",
    "present": true,
    "run": "npx eslint <files>; npx tsc --noEmit",
    "run_minified": null,
    "tooling": { "chosen": "eslint,tsc", "version": null },
    "status": "ready"
  },
  {
    "id": "regression",
    "present": true,
    "run": "npx vitest run tests/regression",
    "run_minified": "npx vitest related --changed",
    "tooling": { "chosen": "vitest", "version": null },
    "status": "ready",
    "needs_env": true
  },
  {
    "id": "a11y",
    "present": true,
    "run": "platform/protocol-a11y.md",
    "run_minified": null,
    "tooling": null,
    "status": "opted_out",
    "criticality": "advisory"
  }
]
```

### The five always-present fields

| Field | Type | Notes |
|---|---|---|
| `id` | string | component slug — the **join key** into `component-catalog.md`, and the stem of `protocol-<slug>.md` + the check-report `check`. An `id` with no catalog row → ignored + one warn (AC-S4 pattern) |
| `present` | bool | in the pipeline this run only when `true` (or the catalog marks it `mandatory`); an absent component produces **no** step and **no** skip note (AC-PF6) |
| `run` | string \| null | the **resolved** command (script/hybrid) or `<group>/protocol-<slug>.md` ref (subagent/gate) — the one genuinely per-project value |
| `run_minified` | string \| null | the resolved **selection-capable** invocation of the same runner (affected ∪ critical), detected alongside `run`. Non-null only on the selection-capable components (`unit`, `integration`, `regression`). **`null` ⇒ the component always runs full** — silent, not a gap. Never consulted unless selection resolves enabled (AC-TS12) |
| `tooling` | `{chosen,version}` \| null | the detection overlay — which tool was picked, at what version |
| `status` | enum `ready`\|`no_tooling`\|`n/a`\|`opted_out`\|`deferred` | detection status (`ready`/`no_tooling`/`n/a`) or the carried-over user decision (`opted_out`/`deferred`) |

### The optional per-entry overrides

Written **only** when the user decided something or `--init` resolved a project fact the
catalog cannot know. Absent ⇒ the catalog default applies.

| Field | Type | Written when |
|---|---|---|
| `criticality` | enum `critical`\|`blocking`\|`advisory`\|`config-driven` | the user or a platform profile overrode the catalog default. **Never re-graded by `--update`** (AC-UP2). Absent ⇒ catalog default, and a later catalog change reaches this repo |
| `needs_env` | bool | **C23** — only where the value is *resolved*, not catalog-constant: `regression`, whose value follows its suite composition (AC-SBX8). Every other component inherits the catalog `env` column |
| `hot_tables[]` | string[] | `migration` — the large/hot tables declared at `--init` (C17) |
| `consumers[]` | string[] | `api` — the known API consumers declared at `--init` (C15) |
| `traffic_mix` | object | `load` — the declared read/write mix (C16) |
| `matrix[]` | `{platform, os}[]` | `mobile` — the enforced device/OS matrix (C18) |
| `reason` | string | required alongside `status` `opted_out`/`n/a`/`deferred` — missing → honored + `unjustified-policy` warn (AC-S3) |

### What the manifest does **not** carry

- **`nn` · `group` · `kind` · `cost` · `depends_on` · `active_when` · `platforms` ·
  `mandatory`** — catalog constants, resolved by `id` at run time. The executor and the
  preflight scripts read the catalog, never a manifest copy.
- **`order`** — ordering is a runtime topo-sort on the catalog's `depends_on` (Fork B,
  AC-PF4); the manifest never freezes a sequence.
- **`test_selector`** — the freeform note naming the detected selection mechanism. Audit
  only, nothing ever branched on it. The `preflight-check-*.sh` reports still carry it
  (`check-report-schema.md` § `detect`) — it is simply not persisted.
- **`source`** — the producing `preflight-check-<nn>-<slug>.sh`. Fully derivable from `id`
  + the catalog's `check` column.
- **`env_provision`** — moved out of `policy.json` entirely, to `devkit/ENV.md`
  ([`env-contract.md`](env-contract.md)). One source of truth for env setup, shared with
  the humans who need it.

### Reconciling (`--update`)

Because the manifest is deltas, `--update`'s job is small and complete:

| Reconciled | How |
|---|---|
| `present` flips | a runner appeared or disappeared — re-detected fact |
| `run` / `run_minified` / `tooling` | re-detected fact |
| `status` `ready` ↔ `no_tooling` | re-detected fact |
| new components | a catalog row with no manifest entry — seeded from fresh detection |
| `needs_env` on `regression` | re-resolved from suite composition (AC-SBX8) |
| **catalog metadata** | **nothing to reconcile — it was never copied.** This is the AC-UP2 drift hole closed |

`--update` **never** re-prompts a settled `opted_out`/`n/a`, **never** changes a user-set
`criticality`, and **never** re-prompts `policies.test_selection` — those are policy, not facts.

## `policies.test_selection` — is minified test selection wanted at all?

The user's answer to "should the gate run only the tests your diff can break,
instead of the whole suite?". `--changed-only` already prunes whole **platform**
components by diff surface; this key extends pruning **inside** the `unit`,
`integration`, and `regression` components — *selected = affected(diff) ∪
critical-floor*, else fall back to the full suite. Small PRDs stop paying for a
700-test suite at every gate run, while the full suite still runs at a declared
backstop (CI and/or post-merge). Like `github_actions`, this is a **decision the
team makes once**, in a committed file — never something a gate run rediscovers.

```json
"test_selection": {
  "enabled": false,
  "reason": "small-PRD gate runs were taking 40+ min on the full suite",
  "full_run_backstop": "ci",
  "force_full_paths": ["package.json", "**/lockfiles/**", "**/migrations/**", "devkit/**", "src/shared/**", "*.gradle*", "*.xcodeproj/**"],
  "tiers": { "small_max_modules": 2, "small_max_affected_ratio": 0.10, "medium_max_modules": 6, "medium_max_fan_in_pct": 0.90 },
  "max_affected_ratio": 0.5,
  "critical_markers": { "web": "@critical", "python": "critical", "go": "TestCritical", "apple": "Critical.xctestplan", "android": "com.<org>.test.Critical" }
}
```

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `enabled` | bool | ✔ | `false` | `false`/absent → `unit`/`integration`/`regression` run their **full** suites exactly as before the key existed (AC-TS1) |
| `reason` | string | recommended when `enabled:true` | — | governance note; missing → honored + `unjustified-policy` warn (AC-S3) |
| `full_run_backstop` | enum `ci` \| `post-merge` \| `both` | required when `enabled:true` | — | **where the full suite still runs.** Minified shifts *when* the full cost is paid, never *whether*. The enabling interview verifies the named backstop exists (`ci` → a `.github/workflows/` gate workflow **and** `github_actions.enabled` ≠ `false`; `post-merge` → `release_flow.mode == "staged"`); unverifiable → warn loudly + require an explicit override plus `reason`, still honored (AC-TS8) |
| `force_full_paths` | string[] | ✖ | catalog defaults | glob paths whose cross-cutting blast radius defeats selection — a diff touching **any** of them runs the full suite (rule step 1 ⇒ tier **L**, `pre-merge/refs/executor.md` §3c). Defaults per detected platform in [`component-catalog.md`](component-catalog.md) |
| `tiers` | object | ✖ | below | the S/M boundary knobs for the size-tier rubric (`pre-merge/refs/executor.md` §3c.1) |
| `tiers.small_max_modules` | int | ✖ | `2` | **S** requires `modules ≤` this |
| `tiers.small_max_affected_ratio` | number | ✖ | `0.10` | **S** requires `ratio ≤` this |
| `tiers.medium_max_modules` | int | ✖ | `6` | **M** requires `modules ≤` this; above it → **L** |
| `tiers.medium_max_fan_in_pct` | number | ✖ | `0.90` | fan-in percentile bound: a touched file at or above this percentile is **not S**. Graph unavailable ⇒ treated as exceeding the bound (degrade toward more testing, AC-TS10) |
| `max_affected_ratio` | number | ✖ | `0.5` | the **M/L** boundary — an affected set larger than this share of the suite isn't worth selecting; run full |
| `critical_markers` | object `<platform, string>` | ✖ | catalog defaults | the per-platform **tag vocabulary** naming the critical floor (`web`/`python`/`go`/`apple`/`android`). Policy records only the vocabulary — the tags themselves live in test code (ground truth, reviewed in PRs). Resolved per detected platform at `--init`; a declared-but-unresolvable marker is a `medium` `policy-mismatch` finding (AC-ST3 pattern), never a silent empty critical set |

**Written only by `/msg --update` and pre-merge `--init`/`--update`/
`--update-criticality`** — it is the user's setup decision, not a detection
result. (`--init`/`--update` run the enabling interview and resolve the
catalog-defaulted fields; `--update-criticality` touches nothing inside this
object — it restamps the sibling `criticality_review` only.) **No gate run ever
writes it** (AC-OW1, AC-TS2); a gate never writes a critical tag either.

**Back-compat — opt-IN, deliberately inverted.** Absent object ⇒
`enabled: false` ⇒ **pre-key behaviour verbatim**, so existing `policy.json`
files need **no migration** (AC-TS1). This inverts `github_actions`' absent ⇒
`true` default on purpose: CI is the assumed-good baseline you opt *out* of,
whereas selection narrows what a gate runs and must therefore be opted *in*
explicitly, with a named backstop.

**Disable is one run (AC-TS12).** Flipping `enabled:false` via `/msg --update` is
the complete off switch — every other artifact the feature created is
inert-by-design: critical tags in test code, `components[].run_minified`, `tiers`,
`force_full_paths`, `critical_markers`, and the `criticality_review` stamp are all
read **only** inside the selection path. No teardown step exists or is needed;
the disable run prints a one-line retained-inert audit and never offers to strip
tags or `run_minified`.

## `source_signature` — staleness hash

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
(one per check; `null` run/chosen render as the literal `null`). The tuple is exactly the
manifest's own delta fields — which is why the signature simplified with the lighter
manifest: nothing catalog-derived enters it. The gate recomputes this read-only each run;
on mismatch it warns *"pipeline may be stale — run `/pre-merge --update`"*, proceeds on
the current manifest, and **never writes** (Fork E, AC-UP5/UP6).

## `criticality_review` — the test-tree review stamp

Sibling of `source_signature` (additive), and the same idea applied to the **test
tree** instead of the preflight reports: it records when the critical-tag
inventory was last reconciled, so the next pass can diff against it.

```json
"criticality_review": { "reviewed_at": "2026-07-26", "suite_hash": "sha256:…" }
```

| Field | Type | Notes |
|---|---|---|
| `reviewed_at` | `YYYY-MM-DD` | when the last criticality pass completed (stamped by `script-policy-set.py` from the system clock) |
| `suite_hash` | string | `"sha256:"` + hash over the enumerated test tree (sorted test-file paths + each file's declared markers), so a pass can enumerate only what changed since |

**Writers — two, both human-gated:** pre-merge `--update-criticality`, and the
test-selection **enabling interview**'s initial tagging pass (so the critical
floor is non-empty from day one). **No gate run ever writes it** (AC-OW1,
AC-TS2) — a minified run may *read* it (and cheaply count untagged tests) to
print a read-only staleness nudge, then proceeds. Absent stamp ⇒ "never
reviewed"; never a validation error. Like every other selection artifact it is
**dead config when `test_selection` resolves disabled** (AC-TS12).

---

# Read-contract (pre-merge)

## 2c · `test_selection` (the executor's `unit`/`integration`/`regression`)

```
ts = policies.test_selection.enabled ?? false          // opt-IN — absent means off
```

**Per-run flag precedence — `--full` > `--minified` > policy:**

| Resolution | Effect |
|---|---|
| `--full` present | selection **off** for this run regardless of `ts` — the kill switch. Nothing is written |
| `--minified` present (no `--full`) | selection **on** for this run even when `ts` is `false` — lets a team trial it. Nothing is written |
| neither flag | selection follows `ts` |

| `ts` (resolved) | gate behavior |
|---|---|
| `false` (or absent) | **unchanged** — `unit`/`integration`/`regression` run their full suites exactly as before the key existed; **no** selection artifact is read (`run_minified`, `tiers`, `force_full_paths`, `critical_markers`, `criticality_review`, in-code tags), and **no** `test_selection` block or pipeline suffix is emitted (AC-TS1, AC-TS12) |
| `true` | the executor applies the 5-step selection rule below per **selection-capable** component (`unit`, `integration`, `regression`) and records what it selected (AC-TS6) |

**The selection rule (5 steps, evaluated in order per test component)** — canonical
prose + the size-tier rubric live in `pre-merge/refs/executor.md` §3c; summarized
here because this file is the policy read-contract:

```
1. diff hits force_full_paths   → full  (note: "force-full: <path>")
2. run_minified == null         → full  (silent — the runner can't select)
3. affected set unresolvable    → full  (note: "fallback: <reason>")   [fail open, AC-TS4]
4. size tier == L               → full  (note: "tier: L (<trigger>)")
5. else                         → run_minified per the tier; record selected/total + tier
```

Selection is **deterministic** (AC-TS3): the affected set comes from runner-native
selection or the code graph, the critical floor from declared tags — same diff +
same manifest + same tags ⇒ same selected set, enumerated in the verdict JSON.
Every resolution failure **fails open to the full suite** with a one-line note,
never to a narrower run. `mechanical`/`security`/`migration` and this PRD's newly
authored regression tests are **never** selected away (AC-TS5).

**`enabled:true` with no `reason` → honored + one `unjustified-policy` warn**
(AC-S3), exactly as `branch_protection`/`github_actions` handle a missing
justification: a missing governance note is a docs smell, never a reason to flip
to a stricter default. An `enabled:true` with an **unverifiable
`full_run_backstop`** is the separate, louder case — it requires the explicit
enable-anyway override plus `reason` at the interview (AC-TS8), not at read time.
