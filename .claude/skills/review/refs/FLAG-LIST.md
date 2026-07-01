# Cook Flag Reference

Complete list of every valid `/cook` flag plus the domain detection signals `/review` uses to fingerprint a codebase. This is a hand-maintained snapshot of `vocab/tag-vocabulary.json` and `standards/*/refs/` — it is **not** generated at runtime; update it manually when the vocab or standards shelves change.

This file owns `active_domains[]` detection and the `/cook` flag inventory only. **Test runner, mechanical runner, and security scanner detection tables** live in `../shared/refs/tooling-detection.md` — that file is the single source of truth for `test_runner`, `mechanical_runners[]`, and `security_scanners[]` / `secret_scanner`. Do not duplicate those tables here.

---

## Domain detection (review Step 2 fingerprint)

Run checks in parallel. Populate `active_domains[]` from signals found:

| Signal | Domain(s) added |
|--------|----------------|
| `pubspec.yaml` found (maxdepth 2) | Flutter, Dart |
| `.ts` or `.tsx` files found (maxdepth 4) | TypeScript |
| `.graphql` files found (maxdepth 4) | GraphQL |
| `supabase/` dir or `.sql` migration files found | Supabase, Database |
| `react` in `package.json` deps | React |
| `next` in `package.json` deps | Next.js |
| `express`, `fastify`, `koa`, or `@nestjs/core` in `package.json` deps | Node.js |
| `pg`, `ioredis`, or `redis` in `package.json` deps | Database |
| `@supabase/supabase-js` or `supabase` in `package.json` deps | Supabase |

Domains not detected produce no domain flags. `active_domains[]` is set once and never re-derived mid-run.

### Extensions with no domain-specific coverage

`/cook` has no standards shelf for these languages — changed files matching them never receive domain-specific review, only the global concern flags. Step 4 checks the diff against this list and surfaces a warning (see `SKILL.md` Step 4) rather than silently under-covering the change:

`.py`, `.go`, `.rs`, `.java`, `.rb`, `.php`, `.c`, `.cpp`, `.cs`, `.swift`, `.kt`, `.scala`

Extend this list when a new shelf-less language shows up in a review; remove an entry once its shelf is added under `standards/`.

---

## Global flags (always included, regardless of domain)

| Mode | Global flags |
|------|-------------|
| Quality | `--api-design`, `--architecture`, `--error-handling`, `--debug` |
| Security | `--security`, `--auth` |
| Performance | `--performance` |

Domain flags (listed in the per-domain tables below) apply to Quality, Security, and Performance modes only. Each flag is further scoped to files in the diff that actually touch that domain. Sub-ref flags (e.g. `--react:hooks`) are preferred over the broad domain flag when scope is clear.

---

## Shelf

| Flag | Loads |
|---|---|
| `--global` | `standards/global/SKILL.md` + all 8 concern refs (P0 + full concern set) |

---

## Concerns

Each concern flag loads a single ref from `standards/global/refs/`. No P0 SKILL.md loads.

| Flag | Loads |
|---|---|
| `--api-design` | `standards/global/refs/api-design.md` |
| `--architecture` | `standards/global/refs/architecture.md` |
| `--auth` | `standards/global/refs/auth.md` |
| `--cicd` | `standards/global/refs/cicd.md` |
| `--debug` | `standards/global/refs/debug.md` |
| `--error-handling` | `standards/global/refs/error-handling.md` |
| `--performance` | `standards/global/refs/performance.md` |
| `--security` | `standards/global/refs/security.md` |

---

## Domains

A bare domain flag loads the full shelf: `standards/<domain>/SKILL.md` + all refs.  
A sub-ref flag (`--<domain>:<ref>`) loads only that one ref — no SKILL.md.  
Combine both to get SKILL.md + one ref: `--react --react:hooks`.

### `--dart`

| Flag | Loads |
|---|---|
| `--dart` | `standards/dart/SKILL.md` + all refs |
| `--dart:testing` | `standards/dart/refs/testing.md` |
| `--dart:tooling` | `standards/dart/refs/tooling.md` |

### `--database`

| Flag | Loads |
|---|---|
| `--database` | `standards/database/SKILL.md` + all refs |
| `--database:postgresql-anti-patterns` | `standards/database/refs/postgresql-anti-patterns.md` |
| `--database:postgresql-best-practices` | `standards/database/refs/postgresql-best-practices.md` |
| `--database:postgresql-checklist` | `standards/database/refs/postgresql-checklist.md` |
| `--database:postgresql-implementation` | `standards/database/refs/postgresql-implementation.md` |
| `--database:redis-best-practices` | `standards/database/refs/redis-best-practices.md` |
| `--database:redis-checklist` | `standards/database/refs/redis-checklist.md` |
| `--database:sql-gotchas` | `standards/database/refs/sql-gotchas.md` |

### `--flutter`

| Flag | Loads |
|---|---|
| `--flutter` | `standards/flutter/SKILL.md` + all refs |
| `--flutter:architecture` | `standards/flutter/refs/architecture.md` |
| `--flutter:cicd` | `standards/flutter/refs/cicd.md` |
| `--flutter:concurrency` | `standards/flutter/refs/concurrency.md` |
| `--flutter:dependency-injection` | `standards/flutter/refs/dependency-injection.md` |
| `--flutter:design-system` | `standards/flutter/refs/design-system.md` |
| `--flutter:error-handling` | `standards/flutter/refs/error-handling.md` |
| `--flutter:localization` | `standards/flutter/refs/localization.md` |
| `--flutter:navigation` | `standards/flutter/refs/navigation.md` |
| `--flutter:networking` | `standards/flutter/refs/networking.md` |
| `--flutter:notifications` | `standards/flutter/refs/notifications.md` |
| `--flutter:security` | `standards/flutter/refs/security.md` |
| `--flutter:state-management` | `standards/flutter/refs/state-management.md` |
| `--flutter:testing` | `standards/flutter/refs/testing.md` |

### `--graphql`

| Flag | Loads |
|---|---|
| `--graphql` | `standards/graphql/SKILL.md` + all refs |
| `--graphql:performance` | `standards/graphql/refs/performance.md` |
| `--graphql:schema-design` | `standards/graphql/refs/schema-design.md` |
| `--graphql:security` | `standards/graphql/refs/security.md` |
| `--graphql:testing` | `standards/graphql/refs/testing.md` |
| `--graphql:tooling` | `standards/graphql/refs/tooling.md` |

### `--nextjs`

| Flag | Loads |
|---|---|
| `--nextjs` | `standards/nextjs/SKILL.md` + all refs |
| `--nextjs:app-router` | `standards/nextjs/refs/app-router.md` |
| `--nextjs:architecture` | `standards/nextjs/refs/architecture.md` |
| `--nextjs:data-fetching` | `standards/nextjs/refs/data-fetching.md` |
| `--nextjs:i18n` | `standards/nextjs/refs/i18n.md` |
| `--nextjs:pages-router` | `standards/nextjs/refs/pages-router.md` |
| `--nextjs:rendering-and-caching` | `standards/nextjs/refs/rendering-and-caching.md` |
| `--nextjs:security` | `standards/nextjs/refs/security.md` |
| `--nextjs:server-actions` | `standards/nextjs/refs/server-actions.md` |
| `--nextjs:server-components` | `standards/nextjs/refs/server-components.md` |
| `--nextjs:state-management` | `standards/nextjs/refs/state-management.md` |
| `--nextjs:styling-and-optimization` | `standards/nextjs/refs/styling-and-optimization.md` |
| `--nextjs:testing` | `standards/nextjs/refs/testing.md` |
| `--nextjs:tooling` | `standards/nextjs/refs/tooling.md` |

### `--nodejs`

| Flag | Loads |
|---|---|
| `--nodejs` | `standards/nodejs/SKILL.md` + all refs |
| `--nodejs:async-errors` | `standards/nodejs/refs/async-errors.md` |
| `--nodejs:runtime-safety` | `standards/nodejs/refs/runtime-safety.md` |
| `--nodejs:testing` | `standards/nodejs/refs/testing.md` |
| `--nodejs:tooling` | `standards/nodejs/refs/tooling.md` |

### `--react`

| Flag | Loads |
|---|---|
| `--react` | `standards/react/SKILL.md` + all refs |
| `--react:component-patterns` | `standards/react/refs/component-patterns.md` |
| `--react:hooks` | `standards/react/refs/hooks.md` |
| `--react:performance` | `standards/react/refs/performance.md` |
| `--react:security` | `standards/react/refs/security.md` |
| `--react:state-management` | `standards/react/refs/state-management.md` |
| `--react:testing` | `standards/react/refs/testing.md` |
| `--react:tooling` | `standards/react/refs/tooling.md` |

### `--supabase`

| Flag | Loads |
|---|---|
| `--supabase` | `standards/supabase/SKILL.md` + all refs |
| `--supabase:checklist` | `standards/supabase/refs/checklist.md` |
| `--supabase:database-functions` | `standards/supabase/refs/database-functions.md` |
| `--supabase:edge-functions` | `standards/supabase/refs/edge-functions.md` |
| `--supabase:keys-and-clients` | `standards/supabase/refs/keys-and-clients.md` |
| `--supabase:migrations` | `standards/supabase/refs/migrations.md` |
| `--supabase:rls` | `standards/supabase/refs/rls.md` |

### `--typescript`

| Flag | Loads |
|---|---|
| `--typescript` | `standards/typescript/SKILL.md` + all refs |
| `--typescript:security` | `standards/typescript/refs/security.md` |
| `--typescript:testing` | `standards/typescript/refs/testing.md` |
| `--typescript:tooling` | `standards/typescript/refs/tooling.md` |
