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

## Live conformance — the running app against its spec (env wave)

Spec-vs-implementation drift needs a running server, so this half runs in the **env
wave**, inside the C23 sandbox (`../executor.md` §3b), after `smoke` proves the app is
alive.

1. **Start the app** in the sandbox (`devkit/ENV.md` `provision` + `seed`). Its base URL
   comes from the env block.
2. **Pick the endpoints.** Every endpoint the diff touches (a route file, a handler, or
   the spec path itself changed), plus a sample of up to **10** other endpoints from the
   spec, chosen in spec order. A spec with 10 endpoints or fewer runs them all.
3. **Send each endpoint one request** built from the spec: the documented method, path
   parameters from the spec's `example` values (else a minimal valid value from the
   schema), and a request body from the request schema's example when one is required.
   Use the seed fixture's credentials when the operation declares security.
4. **Compare** the status code to the operation's documented responses and the response
   body to that response's schema (required fields present, types match, no field the
   schema forbids).
5. **Each mismatch is one finding**: `high`, `rule: api-live-mismatch`,
   `category: api`, `file` = the spec path, message naming method + path + what differed
   (`GET /todos → 500, spec documents 200` / `GET /todos → dueDate is null, spec says
   string`).

Record `live: {ran: true, endpoints: <n>, sampled: <n>, mismatches: <n>}`.

**No sandbox ⇒ not run.** `devkit/ENV.md` absent, or the provisioner unresolved
(§3b *loud degrade*) ⇒ do **not** run against an ambient server. Record
`live: {ran: false, reason: "no sandbox"}` and the report line reads *"live API check:
not run — no sandbox"*. Never "passed", never omitted, and never listed as a check that
ran. No spec ⇒ `live: {ran: false, reason: "no spec"}`.

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
