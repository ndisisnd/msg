# test — API bucket

**When it runs:** eighth bucket in `--sequential` order — after Performance; by default runs concurrently as its own subagent.

**What it checks:** API contracts and OpenAPI spec validity — consumer-driven contract tests, HTTP collection runs, and schema conformance.

## Execution

Guard, bucket-error rule, and output envelope: see `_common.md`. `api_runner` is an **array** of detected runners (Pact / Newman / Dredd / Hurl / Spectral / openapi-validator), each with name + command from the Step 1 fingerprint — this bucket does not re-detect.

### Step 1 — Guard

Per `_common.md`: if `api_runner` is `null`, emit `pass_with_warnings` with note `"No API testing runner detected — API bucket skipped."` and return immediately.

Unlike other buckets, **all** detected runners are used — it is common for a repo to have both contract tests (Pact/Newman) and a spec linter (Spectral) simultaneously. Findings are merged and de-prefixed.

### Step 2 — Discover contracts / specs / collections

For each detected runner, locate its inputs:

- **Pact** — find all `*.json` consumer contract files in `pacts/` or `.pact/`. If `PACT_BROKER_BASE_URL` is set in env, also verify against the Pact Broker.
- **Newman** — find all Postman collection `*.json` files in `postman/`, `collections/`, `tests/api/` (recursive).
- **Dredd** — use config from `.dredd/dredd.yml`; read `blueprint` key for the API spec path. Fall back to searching for `openapi.yaml` / `swagger.yaml` at project root.
- **Hurl** — find all `*.hurl` files under `tests/` and `api/` (recursive) and at the project root (non-recursive).
- **Spectral / openapi-validator** — find the primary API spec: search `openapi.yaml`, `openapi.json`, `swagger.yaml`, `swagger.json` at project root first, then `api/`, `docs/api/`, `spec/`.

Emit: `API targets: <N> contracts/specs/collections detected.`

If zero targets are found across all runners: emit `pass_with_warnings` with note `"No API contracts, collections, or OpenAPI specs found."` and return immediately.

### Step 3 — Run

Execute each detected runner in turn within this bucket's subagent. Capture stdout, stderr, exit code, and any JSON/HTML report output.

- **Exit 0, all checks passed** → verdict `pass` for that runner.
- **Contract mismatches or schema violations found** → verdict `fail`; create one finding per violated contract or schema error.
- **Non-zero exit, runner crash** → verdict `pass_with_warnings` with note `"<runner> failed to start — results unreliable."`.

### Step 4 — Parse results

Map runner-native output to finding severity:

| Runner | Failure type | Severity |
|--------|-------------|----------|
| Pact | Consumer contract interaction violation | `fail` |
| Newman | HTTP assertion failure or unexpected status code | `fail` |
| Newman | Deprecated / missing response header | `warn` |
| Dredd | HTTP status mismatch or response body schema mismatch | `fail` |
| Hurl | HTTP assertion failure | `fail` |
| Spectral | `error`-severity rule | `fail` |
| Spectral | `warn`-severity rule | `warn` |
| openapi-validator | `error` | `fail` |
| openapi-validator | `warning` | `warn` |

For each violation, extract:

- `file` — contract file, collection file, spec file, or `.hurl` file path
- `line` — line number within the spec or file if the runner provides it, else `null`
- `rule` — rule ID, schema path, or assertion name (e.g. `"pact:POST /users → 201"`, `"oas3-schema"`, `"status-code-2xx"`)
- `message` — description of the mismatch or violation
- `repro` — command to re-run just this contract, collection, or spec file
- `suggestion` — actionable fix (e.g. `"Update provider state for consumer 'UserService'"`, `"Add missing required property 'id' to response schema"`)

Also record aggregate totals across all runners:

- `totals.passed` — number of assertions / schema rules that passed
- `totals.failed` — number of assertions / schema rules that failed
- `totals.warned` — number of warnings

Findings conform to the canonical finding object (`../../../shared/refs/finding-schema.md`). Map the table above's `fail`/`warn` failure type to canonical severity: `fail` → `high`, `warn` → `medium`. `evidence.tool` is the runner that produced the finding (Pact/Newman/Dredd/Hurl/Spectral/openapi-validator); `evidence.file` mirrors the top-level `file`; `evidence.snippet` carries the violation description.

## Error handling

Applies `_common.md`'s bucket-error rule (every error → `pass_with_warnings`, never `fail`) with these api-specific cases:

| Error condition | Verdict | Note in output |
|----------------|---------|----------------|
| Runner binary not found / not installed | `pass_with_warnings` | `"<runner> not found — install it or add to devDependencies."` |
| Runner crashes on startup (non-zero, no report) | `pass_with_warnings` | `"<runner> failed to start — results unreliable."` Include stderr excerpt (max 5 lines). |
| No contract / spec / collection files found | `pass_with_warnings` | `"No API contracts, collections, or OpenAPI specs found."` |
| Pact Broker unreachable | `pass_with_warnings` | `"Pact Broker at <url> unreachable — contract verification skipped."` Fall back to local `pacts/` files if present. |
| Newman target server unreachable | `pass_with_warnings` | `"Newman: target server at <url> unreachable — collection run skipped."` |
| Spec file parse error | `pass_with_warnings` | `"Could not parse spec at <path>: <error>."` |
| Partial runner failure (one runner fails, others succeed) | Emit partial findings; overall `pass_with_warnings` if no `fail` findings from successful runners | Attach a top-level `"errors"` array listing each failed runner and its reason. |

**Partial results rule:** if at least one runner completes successfully, emit its findings and set the verdict based on those findings. A failing runner contributes to `"errors"` but does not force `fail` on its own.

## Output

Envelope + finding shape per `_common.md`. Bucket fields:

```json
"runners": ["<runner1>", "<runner2>"], "commands": ["<cmd1>", "<cmd2>"],
"errors": [ { "runner": "<runner>", "reason": "<error description>" } ],
"totals": { "passed": 0, "failed": 0, "warned": 0 }
```

Findings: category/source `api`; per the Step 4 severity map (fail→high, warn→medium); `evidence.tool` = the specific runner (Pact/Newman/Dredd/Hurl/Spectral/openapi-validator).

`fail` if any contract violation or `error`-severity schema violation is found. `pass_with_warnings` if only `warn`-severity findings, no targets found, or all runners crashed. `pass` if all checks pass with zero violations.
