---
name: security
description: Gate Step 6 — Security stage (safety floor, every profile). Stage 0 secret scan + dependency/SAST scanners, then a /cook-backed semantic pass over the diff's domains. Migrated from /review Security mode + the old pre-merge security component.
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
| dependency | pnpm/npm/yarn audit, trivy fs, snyk | `rtk <pm> audit --json` / `rtk trivy fs --format json .` | CVSS ≥ 9 → `high`, 7–8.9 → `medium`, < 7 → `low` (dev-only downgrade per `../severity-rubric.md`) |
| container | trivy image | `rtk trivy image --format json <image>` | `CRITICAL`/`HIGH` → `high`, `MEDIUM` → `medium`, `LOW` → `low` |

Secret scanning is diff-scoped by default; `--full-secret-scan` scans the full tree.
A secret-scanner hit is **never** downgraded (test-file / unreachable exceptions in
the rubric do not apply to secrets). Scanner logs → `.pre-merge/<ts>/security-<scanner>.log`.
`source: secrets:<scanner>` / `sast:semgrep` / `dependency:<tool>`, `category: security`.

## Guaranteed secret-scan floor (C9 — the floor can't hollow out)

`security` is `mandatory` and never opts out, but its layers were all conditional —
a repo with **no scanner and no `/cook`** could run nothing and still green. C9 closes
that: **secret-scan coverage is a hard requirement to *pass*.**

- **Secret scanner present** → always run it (above). A hit → `blocker` (AC-SF1).
- **No secret scanner detected at all** (`detected.secret_scanner` empty / no
  gitleaks/trufflehog) → emit a `blocker` **without** running one:
  `rule: no-secret-scanner`, `category: security`, `source: pre-merge:security`,
  message *"No secret scanner is configured — the safety floor requires secret-scan
  coverage before this gate can pass"* + `evidence.snippet: "safety-floor-unmet"`.
  There is **no green-gate path without secret-scan coverage** (AC-SF1/SF4). The fix
  is `/pre-merge --init` (it strongly offers gitleaks), not a forced install here —
  the install stays per-item approved (`AC-DR2` preserved).
- **This blocker is not declinable at gate time** — a passing gate can never have had
  zero secret-scan coverage (AC-SF4). Only `--init` recording the scanner (or the user
  installing one) clears it.

**Everything else stays best-effort/degradable (AC-SF3).** Absence of SAST (semgrep),
dependency scanning (audit/trivy/osv), container scanning (trivy image), or the `/cook`
semantic pass is a **note**, never a blocker — recorded as `skipped` with a `reason`
(`no_sast` / `no_dep_scanner` / `no_cook`), a degrade, not a failure. The secret
scanner is the **only** layer whose absence blocks; the rest inform.

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
