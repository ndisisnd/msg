---
name: migration
description: Gate Step 6 — Migration stage (safety floor, conditional). Static SQL-safety scan on added migration lines, then a /cook semantic pass when a DB flag assembles. Migrated from /review Migration mode.
---

# Step 6 — MIGRATION stage (safety floor, conditional)

Part of the safety floor: runs in **every** profile, but only when the diff touches
a migration file. No migration file → skip entirely (noted, not a finding).

## Trigger

Diff touches at least one of: `supabase/migrations/*.sql`, `**/migrations/*.sql`,
`**/migrations/*.ts`, `prisma/migrations/**`, `db/migrate/**`. Else skip.

## Stage 0 — Static safety scan

On the **added** lines of each matching migration file only:

| Pattern | Finding | Severity |
|---|---|---|
| `DROP TABLE` / `DROP COLUMN` | Irreversible data loss — no rollback once applied | `blocker` |
| `ALTER COLUMN ... TYPE` (no safe-cast note) | Type change can lock the table / truncate data | `high` |
| `ADD COLUMN ... NOT NULL` with no `DEFAULT` | Fails against existing rows — needs backfill/default | `high` |
| `CREATE INDEX` without `CONCURRENTLY` (Postgres) | Write-locks the table for the build | `medium` |
| `RENAME COLUMN` / `RENAME TABLE` | Breaks in-flight code reading the old name | `medium` |

`source: migration:static`, `category: architecture`, `rule` = matched pattern name,
`evidence.snippet` = offending line.

**Down-migration check** (only for frameworks that pair up/down by convention — Rails
`db/migrate/*.rb` needs `def down`/`def change`; numbered `*.up.sql`/`*.down.sql` pairs
need the `.down.sql` sibling). Supabase/Prisma are forward-only — never checked.
Missing pair → `medium`, `rule: missing-down-migration`.

## Semantic pass (/cook-backed)

Only when a DB flag assembles: `--supabase:migrations` (Supabase active + diff touches
`supabase/migrations/`) and/or `--database:sql-gotchas` (Database active). Neither → run
Stage 0 only. Compile `/cook` once, inject into one `Agent` subagent reviewing the
migration files (not app code that merely calls the schema). `source: pre-merge:migration`.
Stage verdict = worst of Stage 0 findings and the semantic verdict. `/cook` unresolvable →
Stage 0 only, semantic pass recorded `skipped`, `reason: "no_cook"` (degrade, not failure).
