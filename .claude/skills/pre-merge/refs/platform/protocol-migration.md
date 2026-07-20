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

## Expand/contract safety — same-PR destructive rename (C17, AC-MIG1/MIG2)

The plain static scan flags a `DROP`/`RENAME` on the migration line, but the real
rolling-deploy disaster is a **destructive/renaming schema change shipped in the same PR
as app code that still references the changed name**: mid-deploy, old pods query the
dropped/renamed name → 500s for a slice of users until the rollout completes.

Detect it by **correlating the diff** (reuse the executor's `resolve-diff` surface,
shared with `api`/`load`):

1. From the migration files' **added** lines, collect each `DROP COLUMN` / `DROP TABLE` /
   `RENAME COLUMN` / `RENAME TABLE` target (the old column/table name).
2. Scan the **app-code** changes in the *same PR* for references to that old name
   (model fields, query strings, ORM column maps).
3. **Same PR contains both** the destructive/renaming migration **and** an app-code
   reference to the changed name → `high` (`rule: expand-contract-unsafe`,
   `category: architecture`), with the **expand/contract remedy** in `suggestion`: *add
   the new column → backfill → dual-write → switch reads → drop the old — across separate
   deploys, never one atomic PR.*
4. **Split across PRs** (the migration change and the app-code reference land in
   different PRs — the safe expand step) → **no** expand/contract finding fires (AC-MIG2).
   Correlation is same-PR only, so the safe rollout path is silent — no false positive.

This is additive to the Stage 0 static findings (a `DROP COLUMN` still flags on its own
line); the correlation adds the rolling-window `high` when app code references it too.

## Size-aware lock severity (C17, AC-MIG3/MIG4)

Lock-risk findings — `CREATE INDEX` without `CONCURRENTLY`, whole-table rewrites
(`ALTER COLUMN ... TYPE`) — **scale severity by the target table's size**, so the gate
stops crying wolf on a tiny config table and stops under-warning on a large/hot one (a
multi-minute write-lock = apparent outage):

- **Size context available** → adjust the static severity: a **large/hot** table
  escalates (e.g. `CREATE INDEX` non-concurrent `medium` → `high`); a **small** table
  quiets (→ `low`). Size context comes from a **schema/stats hint** where available
  (row-count/table-size stats), else the **`--init`-declared `hot_tables[]`** list on the
  `migration` catalog entry (a table named there is treated as hot/large).
- **No size context** (no stats **and** no `hot_tables[]`) → the finding keeps its
  **current flat severity** — no regression when the hint is absent (AC-MIG4).

Note the applied adjustment in `evidence.snippet` (`"table <name> in hot_tables[] —
escalated"` / `"no size context — flat severity"`) so the grade is auditable.

## Semantic pass (/cook-backed)

Only when a DB flag assembles: `--supabase:migrations` (Supabase active + diff touches
`supabase/migrations/`) and/or `--database:sql-gotchas` (Database active). Neither → run
Stage 0 only. Compile `/cook` once, inject into one `Agent` subagent reviewing the
migration files (not app code that merely calls the schema). `source: pre-merge:migration`.
Stage verdict = worst of Stage 0 findings and the semantic verdict. `/cook` unresolvable →
Stage 0 only, semantic pass recorded `skipped`, `reason: "no_cook"` (degrade, not failure).
