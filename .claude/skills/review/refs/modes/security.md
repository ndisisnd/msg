# review — Security mode

**When it runs:** fourth in pipeline order — after Functional, before Performance.

**What it checks:** injection vulnerabilities, authentication and authorization gaps, insufficient input validation, and hardcoded credentials or API keys in the diff. This is a code-review check — not a dedicated secret scanner (gitleaks/truffleHog).

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

## Execution

Spawn one `/cook --<flag>` Agent per flag in parallel. Each agent receives:
- The resolved diff
- The subset of changed files that touch its domain

Collect `{ verdict, findings[] }` from each. Aggregate: mode verdict = worst across all agents.
