# HANDOFF — 2026-05-29 — test Phase 2 (--api bucket)

## Purpose

This handoff is a precise, verifiable record of every change made during Phase 2 of the /test skill expansion. A verifier agent should be able to confirm each change by diffing against the prior state (handoff/4.md) or reading the files directly.

---

## Files Changed

### NEW: `.claude/skills/test/refs/modes/api.md`

Created from scratch. Full content verified below by section headers:

- `# test — API bucket`
- **When it runs:** eighth bucket — after Performance (sequential), or concurrently under `--fast`.
- **What it checks:** API contracts and OpenAPI spec validity — consumer-driven contract tests, HTTP collection runs, and schema conformance.
- **Step 1 — Guard:** six recognised runners in detection order: Pact, Newman, Dredd, Hurl, Spectral, openapi-validator. Key distinction: **all detected runners are used** (not just first match), because Pact + Spectral co-existing is common.
- **Step 2 — Discover:** per-runner target resolution rules (pacts/ dir, Postman collection files, .dredd/dredd.yml, *.hurl files, openapi.yaml/swagger.yaml). Emits `"No API contracts, collections, or OpenAPI specs found."` and returns on zero targets.
- **Step 3 — Run:** sequential per runner (concurrent under `--fast`). Three outcomes: `pass`, `fail`, `pass_with_warnings`.
- **Step 4 — Parse:** severity mapping table (Pact violation → `fail`, Newman assertion failure → `fail`, Newman missing header → `warn`, Dredd mismatch → `fail`, Hurl assertion failure → `fail`, Spectral error → `fail`, Spectral warn → `warn`, openapi-validator error → `fail`, openapi-validator warning → `warn`). Totals: `passed`, `failed`, `warned`.
- **Error handling table:** 7 error conditions, all producing `pass_with_warnings`. Partial results rule: at least one successful runner → emit findings from that runner.
- **Output JSON shape:** top-level keys `verdict`, `bucket`, `runners` (array), `commands` (array), `errors` (array of `{runner, reason}`), `totals` (`passed`, `failed`, `warned`), `findings`.
- **Finding shape:** `id` = `"api-<n>"`, `severity`, `file`, `line` (number or null), `rule`, `message`, `repro`, `suggestion`. No `evidence` field (API bucket does not produce screenshots).

---

### MODIFIED: `.claude/skills/test/SKILL.md`

Five discrete changes in document order:

#### 1. Frontmatter `description` (lines 3–10)

Old (7 lines):
```
description: >
  Execution-focused test skill. Runs unit/integration, e2e, functional,
  visual (QA), and load test buckets via detected runners. Per-mode flags
  (--unit, --e2e, --functional, --qa, --load) target individual buckets;
  --fast runs all selected buckets in parallel. Accepts --eval-set to
  consume eval_set.json written by /review. Emits structured JSON findings
  compatible with the pre-merge finding schema.
```

New (8 lines):
```
description: >
  Execution-focused test skill. Runs unit/integration, e2e, functional,
  visual (QA), load, accessibility, performance budget, and API/contract
  test buckets via detected runners. Per-mode flags (--unit, --e2e,
  --functional, --qa, --load, --a11y, --perf, --api) target individual
  buckets; --fast runs all selected buckets in parallel. Accepts --eval-set
  to consume eval_set.json written by /review. Emits structured JSON
  findings compatible with the pre-merge finding schema.
```

#### 2. Mode flags list (Usage section)

Added one line after `--perf`:
```
- `--api` — run only the API / contract testing bucket
```

#### 3. Step 1/5 — Detect tooling

Added one bullet after `perf_runner`:
```
- **`api_runner`** — API / contract testing runner object, or `null` if none detected. Recognised tools: Pact, Newman/Postman, Dredd, Hurl, Spectral, openapi-validator. Multiple runners may be detected simultaneously (see `refs/modes/api.md`).
```

#### 4. Step 3/5 — Confirm and gate (execution plan display)

Added one line to the fenced code block after `Performance`:
```
API / Contract    → <api_runner.commands>
```

#### 5. Step 4/5 — Run buckets

**Skip condition bullet** — updated mode flag list from:
```
(`--unit`, `--e2e`, `--functional`, `--qa`, `--load`)
```
to:
```
(`--unit`, `--e2e`, `--functional`, `--qa`, `--load`, `--a11y`, `--perf`, `--api`)
```

**Bucket table** — added row 8:
```
| 8 | API / Contract | `--api` | `refs/modes/api.md` | `api_runner` is `null` |
```

**Sequential note** — changed `1→7` to `1→8`.

#### 6. References section

Added one line after `refs/modes/perf.md`:
```
- `refs/modes/api.md` — API / contract testing runner invocation and contract/schema violation reporting
```

---

### MODIFIED: `.claude/skills/test/refs/schema.md`

One line added to the `buckets` object in the Output JSON schema block, after the `perf` entry:

Old:
```json
    "perf":       { "verdict": "...", "runner": "...", "totals": {}, "findings": [] }
```

New (trailing comma added to `perf` line, new `api` line added):
```json
    "perf":       { "verdict": "...", "runner": "...", "totals": {}, "findings": [] },
    "api":        { "verdict": "...", "runners": [], "commands": [], "totals": {}, "findings": [] }
```

Note: `api` uses `runners` (array) and `commands` (array) instead of singular `runner`/`command`, reflecting that multiple API runners may run simultaneously.

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| All detected runners run (not first-match) | Pact + Spectral co-existing in one repo is the norm, not an edge case. First-match would silently drop the spec linter. |
| `pass_with_warnings` for all error conditions | Consistent with every other bucket — broken CI env must not block merge. |
| Partial results rule | If one runner fails but another succeeds, emit what was found rather than wiping the run. |
| No `evidence` field in findings | API violations are textual (status codes, schema mismatches) — no screenshots. Matches Load and Perf precedent. |
| `--api` added to skip-condition bullet in Step 4 | The bullet previously only listed the original 5 flags; `--a11y` and `--perf` were also missing. Fixed all three. |

---

## Not Affected

- Phase 3: `--mobile` bucket (Detox, Maestro, Appium, XCUITest, Espresso)
- `--coverage` bucket (minimum coverage gate enforcement)
- Browser compatibility matrix (BrowserStack, Sauce Labs)
- No existing mode files were modified

## Next Steps

- Commit this changeset (new `api.md` + 3 modified files)
- Start Phase 3: design `--mobile` bucket with device/OS matrix support
- Consider `--coverage` bucket for minimum threshold gate enforcement
