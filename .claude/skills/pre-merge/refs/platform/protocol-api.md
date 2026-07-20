---
name: api
description: Pre-merge API/contract component — consumer-driven contract tests, HTTP collection runs, and OpenAPI spec conformance via all detected runners. Parse to canonical findings.
---

# api component

Guard, error rule, envelope: `../_common.md`. `api_runner` is an **array** (Pact / Newman /
Dredd / Hurl / Spectral / openapi-validator) from the fingerprint — **all** detected
runners are used (contract tests + a spec linter commonly co-exist); findings merge.

## Discover + run

Locate each runner's inputs: Pact `pacts/`/`.pact/` (+ broker if `PACT_BROKER_BASE_URL`);
Newman `postman/`/`collections/`/`tests/api/`; Dredd `.dredd/dredd.yml` blueprint or
root OpenAPI; Hurl `*.hurl` under `tests/`/`api/`/root; Spectral/openapi-validator the
primary spec (`openapi.*`/`swagger.*` at root, then `api/`, `docs/api/`, `spec/`). Zero
targets across all runners → `pass_with_warnings`, note `"No API contracts/specs found."`
Run each detected runner in turn.

## Parse

Map: Pact interaction violation, Newman assertion/status failure, Dredd status/schema
mismatch, Hurl assertion failure, Spectral/openapi `error` rule → `high`. Newman
deprecated header, Spectral/openapi `warn` → `medium`.

Finding fields: `rule` = rule-id / schema path / assertion name (e.g. `"pact:POST /users → 201"`,
`"oas3-schema"`); `file` = contract/collection/spec/`.hurl` path; `evidence.tool` = the
specific runner; `suggestion` = actionable fix. **Partial-results rule:** a failing
runner contributes to `errors[]` but does not force `fail`; verdict from the runners
that completed.

Component fields: `runners[]`, `commands[]`, `errors[]`, `totals` (passed/failed/warned).
