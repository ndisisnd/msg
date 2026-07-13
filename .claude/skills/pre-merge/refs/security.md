---
name: security
description: Gate Step 6 — Security stage (safety floor, every profile). Stage 0 secret scan + dependency/SAST scanners, then a /cook-backed semantic pass over the diff's domains. Migrated from /review Security mode + the old pre-merge security bucket.
---

# Step 6 — SECURITY stage (safety floor)

Runs in **every** profile — tolerance never relaxes it. Two layers: deterministic
scanners (Stage 0) then a `/cook`-backed semantic pass. Both surface to the verdict;
they are independent signals (no short-circuit between them).

## Stage 0 — Scanners (deterministic)

Run every scanner the Step 1 fingerprint reported (`detected.security_scanners[]`),
in parallel:

| Type | Scanner | Command | Finding |
|---|---|---|---|
| secret | gitleaks | `rtk gitleaks detect --no-git --source=<files> --no-banner --redact` | each hit → `blocker`, snippet **redacted** (rule name only) |
| secret | trufflehog | `rtk trufflehog filesystem --no-update --json <files>` | as above |
| sast | semgrep | `rtk semgrep scan --config auto <files>` (or `--config .semgrep.yml`) | `ERROR`→`high`, `WARNING`→`medium`, `INFO`→`low` |
| dependency | pnpm/npm/yarn audit, trivy fs, snyk | `rtk <pm> audit --json` / `rtk trivy fs --format json .` | CVSS ≥ 9 → `high`, 7–8.9 → `medium`, < 7 → `low` (dev-only downgrade per `refs/severity-rubric.md`) |
| container | trivy image | `rtk trivy image --format json <image>` | `CRITICAL`/`HIGH` → `high`, `MEDIUM` → `medium`, `LOW` → `low` |

Secret scanning is diff-scoped by default; `--full-secret-scan` scans the full tree.
A secret-scanner hit is **never** downgraded (test-file / unreachable exceptions in
the rubric do not apply to secrets). Scanner logs → `.pre-merge/<ts>/security-<scanner>.log`.
`source: secrets:<scanner>` / `sast:semgrep` / `dependency:<tool>`, `category: security`.

## Semantic pass (/cook-backed)

One `Agent` subagent for the whole stage. Assemble `/cook` flags: globals
`--security --auth` + the security-scoped sub-ref for each active domain touched by
the diff (prefer the focused sub-ref — the broad shelf adds non-security noise):

| Active domain | Preferred flag |
|---|---|
| React / Next.js / TypeScript / GraphQL / Flutter | `--<domain>:security` |
| Supabase | `--supabase:rls` + `--supabase:keys-and-clients` (else `--supabase`) |
| Database | `--database:sql-gotchas` (else `--database`) |
| Node.js / Dart | `--nodejs` / `--dart` (no `:security` sub-ref) |

Compile `/cook` **once** for the assembled flag set; inject the payload into the
subagent (it does not call `/cook` itself). It reviews the diff for injection paths,
auth/authorization gaps, insufficient input validation, and remaining hardcoded
credentials. `source: pre-merge:security`, `category: security`. Stage verdict =
worst of Stage 0 findings and the semantic subagent's verdict.

`/cook` unresolvable (skill not installed) → run Stage 0 only and record the semantic
pass as `skipped`, `reason: "no_cook"` in the verdict — a degrade, never a failure.
