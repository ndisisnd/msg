---
name: check-report-schema
description: The single normalized check-report schema shared by both gates' preflight layer. ONE schema, two sections — `detect` (written by the preflight-check-*.sh scripts at --init/--update) and `result` (written by the executor at gate time, Phase 3). Ingestion (--init/--update) reads `detect` to assemble components[]; aggregation reads `result`.
type: reference
---

# The normalized check-report schema

Every check in the pipeline is self-describing through **one** report shape, defined
here once (AC-CK5, resolves **Q8**: one schema, not two). A report has two sections:

| Section | Written by | When | Consumed by |
|---|---|---|---|
| `detect` | `preflight-check-<nn>-<slug>.sh` (C4) | `--init` / `--update` | ingestion → `components[]` (this phase, P2) |
| `result` | the pipeline executor (C6/C7) | every gate run | verdict/universal-report aggregation (**P3**) |

The two sections share the normalized-format discipline so ingestion and aggregation
are uniform end-to-end (no bespoke per-check parsing — AC-CK7).

> **This phase (P2).** The preflight scripts write the **`detect`** section only. The
> **`result`** section is documented here now but **written by the executor from P3** —
> nothing in P2 emits it.

## Artifact paths (AC-CK2, AC-RR1)

| Section | Path | Lifetime |
|---|---|---|
| `detect` | `.pre-merge/preflight/<slug>.json` | overwritten each `--init`/`--update`; the ingestion input |
| `result` | `.pre-merge/<ts>/<slug>.json` | one per gate run (`<ts>` = run timestamp); written **always** — pass, fail, or skip (P3) |

`<slug>` is the component id (`mechanical`, `unit`, …) — matches the `protocol-<slug>.md`
stem and the `preflight-check-<nn>-<slug>.sh` script. `.pre-merge/` is a runtime
artifact dir (gitignored), never committed.

---

## `detect` section (written by the preflight scripts — P2)

Emitted to `.pre-merge/preflight/<slug>.json` **and** stdout by every
`preflight-check-*.sh`. Mandatory components (`security`, `migration`) **always** emit a
report even when nothing is detected (`present:false`) — the safety floor can't go
silent (AC-PF2).

```json
{
  "check": "mechanical",
  "id": "01",
  "group": "universal",
  "present": true,
  "active_when": "always",
  "tooling": { "chosen": "eslint,tsc", "version": null },
  "run": "npx eslint <files>; npx tsc --noEmit",
  "criticality": "critical",
  "cost": "cheap",
  "depends_on": [],
  "status": "ready",
  "notes": "detected: eslint,tsc"
}
```

| Field | Type | Notes |
|---|---|---|
| `check` | string | the component **slug** (`mechanical`…`smoke`) — matches the report filename + catalog `id` |
| `id` | string | the stable, zero-padded **`nn`** catalog id (`"01"`…`"17"`, minus retired `15`) — never reused, group-orthogonal |
| `group` | enum `universal`\|`platform`\|`prd` | the component's gating source (its `refs/` folder, C3) |
| `present` | bool | `true` only when the check's tooling **or** surface is detected (AC-PF2/CK3) |
| `active_when` | string | the presence gate: `always` \| `prd` \| `ui-surface` \| `api-surface` \| `perf-config` \| `migrations` \| `mobile-surface` \| `ui-or-deploy-surface` \| `preview-fired` |
| `tooling` | `{chosen, version}` \| `null` | the resolved runner (`chosen` may be a comma-list for multi-runner checks; `version` best-effort, often `null`); `null` for subagent/surface-only checks |
| `run` | string \| `null` | **script/hybrid**: the resolved command · **subagent/gate**: the `<group>/protocol-<slug>.md` ref (AC-CK3, per catalog `kind`); `null` when nothing resolved |
| `criticality` | enum `critical`\|`blocking`\|`advisory`\|`config-driven` | catalog default (a profile may override at assembly; `config-driven` = advisory until the project sets budgets) |
| `cost` | enum `cheap`\|`moderate`\|`expensive` | relative runtime — informs wave scheduling |
| `depends_on` | string[] | hard effect edges only (AC-CAT3): `coverage→[unit,integration]`, `smoke→[preview]`, `regression`→all other universal/prd |
| `status` | enum `ready`\|`no_tooling`\|`n/a` | **detection fact** (not a user decision): `ready` = present+tooling · `no_tooling` = active but no runner (a gap) · `n/a` = surface absent / gate not met |
| `notes` | string | freeform evidence — what was detected, degrade reasons, mandatory notes |

### `status` — detection facts only

The three `detect` statuses describe **what the code has**, never a policy choice. User
decisions (`opted_out` / `deferred`) are applied by ingestion as an **overlay** on top of
detection (see `protocol-init.md`), never emitted by a script. This keeps `--update`'s
diff honest: a script re-reporting `no_tooling` never overwrites a settled `opted_out`.

---

## `result` section (written by the executor — P3, documented now)

> **Written by the executor from P3.** Not emitted in P2. Documented here so P3 fills a
> known shape rather than inventing one. Path: `.pre-merge/<ts>/<slug>.json`, written on
> **every** run — pass, fail, or skip (AC-RR1).

```json
{
  "check": "unit",
  "group": "universal",
  "verdict": "pass",
  "runner": "vitest",
  "ran_at": "2026-07-20T12:00:00Z",
  "totals": { "passed": 24, "failed": 0, "skipped": 0, "flaky": 0 },
  "findings": [],
  "log_path": ".pre-merge/<ts>/unit.log",
  "skip_reason": null
}
```

| Field | Type | Notes |
|---|---|---|
| `check` / `group` | string / enum | same identity fields as `detect` |
| `verdict` | enum `pass`\|`pass_with_warnings`\|`fail`\|`skipped` | per-check outcome (AC-RR2) |
| `runner` | string | the tool that actually ran |
| `ran_at` | ISO-8601 | run timestamp |
| `totals` | `{passed, failed, skipped, flaky}` | positive trace even on a clean pass (AC-RR4) |
| `findings` | canonical finding[] | `../shared/refs/finding-schema.md` shape, `source = <check>` |
| `log_path` | string | raw stage log |
| `skip_reason` | string \| `null` | required when `verdict: skipped` (AC-RR6) |

The universal report (`report-prd-<N>-<K>.json`, C7) is **derived** from these per-check
result reports — `checks[]` = the full run picture, `issues[]` = the flattened+deduped
fix list. No finding appears in the universal report that isn't traceable to a `result`
section (AC-UR6).

---

## Round-trip rule (AC-CK5)

Every check round-trips clean against this schema: the JSON a `preflight-check-*.sh`
writes re-parses with all `detect` keys present and correctly typed, `check` matching the
filename slug, and `id` matching the catalog `nn`. Ingestion validates this on read and
rejects a malformed report rather than assembling a bad `components[]` entry.
