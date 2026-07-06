# review — Security mode

**When it runs:** fourth in pipeline order — after Functional, before Performance.

**What it checks:** dedicated secret scanning (Stage 0, via gitleaks/trufflehog when detected) plus injection vulnerabilities, authentication and authorization gaps, insufficient input validation, and any remaining hardcoded credentials or API keys (semantic stage, via `/cook` flags).

## Flags

Global (always): `--security`, `--auth`

Domain flags: for each active domain from `active_domains[]` touched by the diff, prefer the security-scoped sub-ref over the broad domain flag. Security mode is the one place a focused sub-ref is almost always correct — the broad shelf adds non-security noise.

| Active domain | Preferred flag | Fallback if not security-relevant |
|---|---|---|
| React | `--react:security` | — |
| Next.js | `--nextjs:security` | — |
| TypeScript | `--typescript:security` | — |
| GraphQL | `--graphql:security` | — |
| Flutter | `--flutter:security` | — |
| Supabase | `--supabase:rls` + `--supabase:keys-and-clients` | `--supabase` |
| Database | `--database:sql-gotchas` | `--database` |
| Node.js | `--nodejs` | — (no `:security` sub-ref) |
| Dart | `--dart` | — (no `:security` sub-ref) |

For Supabase diffs, include both `--supabase:rls` and `--supabase:keys-and-clients` when the diff touches policies/clients respectively; otherwise pick the one that matches. Authoritative flag list: `refs/FLAG-LIST.md`.

## Stage 0 — Secret scan

Runs **before** the `/cook` semantic stage. Operates on `secret_scanner` from Step 2 of `SKILL.md` and the `--full-secret-scan` flag from `SKILL.md` Usage.

| `secret_scanner` value | `--full-secret-scan` | Action |
|------------------------|----------------------|--------|
| `null` | any | Emit a single `warn` finding: `"No secret scanner detected — install gitleaks for full coverage."` Then proceed to semantic stage. |
| set | absent (default) | Run `secret_scanner.command_diff` (`<files>` substituted with the diff file list). Parse hits. |
| set | present | Run `secret_scanner.command_full` (no `<files>` substitution). Parse hits. |

Each scanner hit produces one finding:
- `severity: "block"`
- `source: "secrets:<scanner>"` (e.g. `"secrets:gitleaks"`)
- `file` and `line` populated from scanner output
- `category: "security"`
- `message`/`suggestion`: describe the leaked secret kind and recommend rotation + removal from history.

**No short-circuit:** Stage 0 **always** proceeds to the semantic stage regardless of its own verdict. Secret leaks and semantic security issues are independent signals; both surface to the user in one pass.

## Execution (semantic stage)

Shared contract: `_common.md`. One subagent for the whole mode (not one per
flag), receiving the resolved diff, the changed files touching its domains, all
assembled Security flags, and the compiled standards payload. Mode verdict =
worst of the subagent's verdict AND Stage 0 findings.
