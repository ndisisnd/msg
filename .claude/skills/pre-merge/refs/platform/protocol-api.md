---
name: api
description: Pre-merge API/contract component — backward-compatibility spec-diff vs base, plus consumer-driven contract tests, HTTP collection runs, and OpenAPI spec conformance via all detected runners. Consumer-named breaking-change findings. Parse to canonical findings.
---

# api component

Guard, error rule, envelope: `../_common.md`. `api_runner` is an **array** (Pact / Newman /
Dredd / Hurl / Spectral / openapi-validator, plus a spec-diff tool — oasdiff / openapi-diff)
from the fingerprint — **all** detected runners are used (contract tests + a spec linter +
the breaking-change diff commonly co-exist); findings merge. `api` answers not just *"is the
spec well-formed"* but *"is this PR backward-compatible"*.

## Breaking-change detection vs base (C15/rec 1 — the contract ratchet)

Linters (Spectral) and replayed contract tests both stay **green on a valid spec that
silently breaks shipped clients** (e.g. a PR renaming `GET /todos` response
`completed → is_completed`, or making `dueDate` nullable). To catch that, `api` diffs the
**base-branch spec against the PR spec** with `oasdiff` / `openapi-diff` and flags
**backward-incompatible** changes as `high`/blocking (AC-API1):

- removed field · removed endpoint · optional → required · narrowed type ·
  tightened enum · (any change the diff tool classifies as breaking).

This is the shared **ratchet-vs-base** pattern (`../../../shared/refs/ratchet-vs-base.md`)
— here the ratcheted metric is **contract compatibility**: fetch the base spec, compare
**like-for-like** (same spec path, PR spec vs base spec), and a backward-incompatible move
is a finding. A **valid-but-breaking** change that passes Spectral + updated contract tests
is **still caught** by this diff (AC-API2) — the diff is additive to the linters, not
gated behind them. Base spec **unavailable** (first run / no base spec) → skip the diff with
a note (`reason: "no_base_spec"`), never fabricate a break.

### Consumer-named findings (C15/rec 2)

A contract-break finding **names which consumer breaks and what they lose**, not
`oas3-schema violation at line 40` — per `../../../shared/refs/attribute-the-cause.md`
(name the cause) + `../../../shared/refs/name-the-user-impact.md` (lead with impact):
*"iOS `TodoListView` decode of `GET /todos` will fail — `dueDate` is now nullable but the
Swift model expects it non-optional."* Resolve consumers (AC-API3/API4):

1. **Pact broker** when present (`PACT_BROKER_BASE_URL`) — the real consumer set.
2. else a declared **`consumers[]`** hint on the catalog/manifest `api` entry
   (`ios`/`android`/`web`).
3. **absent both** → degrade to **endpoint + change** (*"breaking change on `GET /todos` —
   `dueDate` optional→nullable"*) — **no fabricated consumer**.

> **Parked to preview (rec 3).** Spec-vs-implementation drift via **live-server
> conformance** needs a running server — it is **folded into the `preview` pass**, not
> built here (same as migration #3). Noted, not implemented.

## Discover + run (spec linters + contract tests)

Locate each runner's inputs: Pact `pacts/`/`.pact/` (+ broker if `PACT_BROKER_BASE_URL`);
Newman `postman/`/`collections/`/`tests/api/`; Dredd `.dredd/dredd.yml` blueprint or
root OpenAPI; Hurl `*.hurl` under `tests/`/`api/`/root; Spectral/openapi-validator the
primary spec (`openapi.*`/`swagger.*` at root, then `api/`, `docs/api/`, `spec/`); the
spec-diff tool the **same** primary spec (PR vs base). Zero targets across all runners **and**
no spec to diff → `pass_with_warnings`, note `"No API contracts/specs found."` Run each
detected runner in turn.

## Parse

Map: **breaking spec-diff change → `high`/blocking** (consumer-named as above); Pact
interaction violation, Newman assertion/status failure, Dredd status/schema mismatch, Hurl
assertion failure, Spectral/openapi `error` rule → `high`. Newman deprecated header,
Spectral/openapi `warn`, a **non-breaking** spec-diff change (added optional field/endpoint)
→ `medium`/informational.

Finding fields: `rule` = rule-id / schema path / assertion name / `contract-breaking-change`
(e.g. `"pact:POST /users → 201"`, `"oas3-schema"`); `file` = contract/collection/spec/`.hurl`
path; `evidence.tool` = the specific runner (oasdiff/openapi-diff for the diff);
`evidence.consumer` = the resolved consumer(s) or `null`; `suggestion` = actionable fix
(e.g. version the endpoint / keep the field optional). **Partial-results rule:** a failing
runner contributes to `errors[]` but does not force `fail`; verdict from the runners that
completed.

Component fields: `runners[]`, `commands[]`, `base_spec` (+ `breaking_changes[]`, or
`no_base_spec`), `consumers_source` (pact/hint/none), `errors[]`, `totals` (passed/failed/warned).
