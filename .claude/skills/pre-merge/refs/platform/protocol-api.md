---
name: api
description: Pre-merge API/contract component — contract tests, HTTP collection runs, and OpenAPI spec conformance via all detected runners, plus a backward-compatibility spec-diff vs base when a base spec exists. Parse to canonical findings.
---

# api component

Guard, error rule, envelope: `../_common.md`. `api_runner` is an **array** (Pact / Newman /
Dredd / Hurl / Spectral / openapi-validator, plus a spec-diff tool — oasdiff / openapi-diff)
from the component's resolved tooling — **all** detected runners are used (contract tests +
a spec linter + the breaking-change diff commonly co-exist); findings merge.

## Breaking-change detection vs base — when a base spec exists

Linters and replayed contract tests both stay green on a valid spec that silently
breaks shipped clients (a renamed response field, a newly nullable date). So when a
**base-branch spec** is retrievable, `api` diffs it against the PR spec with
`oasdiff` / `openapi-diff` and flags **backward-incompatible** changes as
`high`/blocking: removed field · removed endpoint · optional → required · narrowed
type · tightened enum · anything the diff tool classifies as breaking. This is the
shared **ratchet-vs-base** pattern (`../../../shared/refs/ratchet-vs-base.md`), with
contract compatibility as the ratcheted metric.

**No base spec** (first run, no spec in the base branch) → **skip the diff with a
note** (`reason: "no_base_spec"`). Never fabricate a break.

### Naming the affected consumer — only from a real source

A contract-break finding names **which consumer breaks and what they lose** when the
repo actually declares its consumers — a Pact broker (`PACT_BROKER_BASE_URL`) or a
`consumers[]` hint on the `api` component. With one of those:
*"iOS `TodoListView` decode of `GET /todos` will fail — `dueDate` is now nullable but
the Swift model expects it non-optional."*

**Neither present** (the common case) → **degrade to endpoint + change**:
*"breaking change on `GET /todos` — `dueDate` optional→nullable"*. **No fabricated
consumer, ever.** Record `consumers_source` = `pact` | `hint` | `none` so the grade is
auditable.

> **Live-server conformance** (spec-vs-implementation drift) needs a running server and
> is run in the env wave, against the C23 sandbox — not here.

## Discover + run (spec linters + contract tests)

Locate each runner's inputs: Pact `pacts/`/`.pact/` (+ broker if `PACT_BROKER_BASE_URL`);
Newman `postman/`/`collections/`/`tests/api/`; Dredd `.dredd/dredd.yml` blueprint or
root OpenAPI; Hurl `*.hurl` under `tests/`/`api/`/root; Spectral/openapi-validator the
primary spec (`openapi.*`/`swagger.*` at root, then `api/`, `docs/api/`, `spec/`); the
spec-diff tool the **same** primary spec (PR vs base). Zero targets across all runners **and**
no spec to diff → `pass_with_warnings`, note `"No API contracts/specs found."` Run each
detected runner in turn.

## Parse

Map: **breaking spec-diff change → `high`/blocking**; Pact interaction violation, Newman
assertion/status failure, Dredd status/schema mismatch, Hurl assertion failure,
Spectral/openapi `error` rule → `high`. Newman deprecated header, Spectral/openapi `warn`,
a **non-breaking** spec-diff change (added optional field/endpoint) → `medium`/informational.

Finding fields: `rule` = rule-id / schema path / assertion name / `contract-breaking-change`
(e.g. `"pact:POST /users → 201"`, `"oas3-schema"`); `file` = contract/collection/spec/`.hurl`
path; `evidence.tool` = the specific runner (oasdiff/openapi-diff for the diff);
`evidence.consumer` = the resolved consumer(s) or `null`; `suggestion` = actionable fix
(e.g. version the endpoint / keep the field optional). **Partial-results rule:** a failing
runner contributes to `errors[]` but does not force `fail`; verdict from the runners that
completed.

Component fields: `runners[]`, `commands[]`, `base_spec` (+ `breaking_changes[]`, or
`no_base_spec`), `consumers_source` (pact/hint/none), `errors[]`, `totals` (passed/failed/warned).
