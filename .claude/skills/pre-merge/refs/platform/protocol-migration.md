---
name: migration
description: The migration component (safety floor, conditional). Static SQL-safety scan on added migration lines, then a /cook semantic pass when a DB flag assembles. Runs only when the diff touches a migration file.
---

# `migration` — the schema-safety component (safety floor, conditional)

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

## Expand/contract safety — same-PR destructive rename (C17)

The plain static scan flags a `DROP`/`RENAME` on the migration line, but the real
rolling-deploy disaster is a **destructive/renaming schema change shipped in the same PR
as app code that still references the changed name**: mid-deploy, old pods query the
dropped/renamed name → 500s for a slice of users until the rollout completes.

Detect it by **correlating the diff** (reuse the executor's `resolve-diff` surface,
shared with `api`/`load`):

1. From the migration files' **added** lines, collect each `DROP COLUMN` / `DROP TABLE` /
   `RENAME COLUMN` / `RENAME TABLE` target (the old column/table name).
2. Scan the **app-code** changes in the *same PR* for references to that old name (model fields, query strings, ORM column maps).
3. **Same PR contains both** the destructive/renaming migration **and** an app-code
   reference to the changed name → `high` (`rule: expand-contract-unsafe`,
   `category: architecture`), with the **expand/contract remedy** in `suggestion`: *add
   the new column → backfill → dual-write → switch reads → drop the old — across separate
   deploys, never one atomic PR.*
4. **Split across PRs** (the migration change and the app-code reference land in
   different PRs — the safe expand step) → **no** expand/contract finding fires.
   Correlation is same-PR only, so the safe rollout path is silent — no false positive.

This is additive to the Stage 0 static findings (a `DROP COLUMN` still flags on its own
line); the correlation adds the rolling-window `high` when app code references it too.

## Lock-risk severity — flat unless the repo supplies size context

Lock-risk findings (`CREATE INDEX` without `CONCURRENTLY`, whole-table rewrites via
`ALTER COLUMN ... TYPE`) keep the **flat severity** in the Stage 0 table. A
multi-minute write-lock on a large table is far worse than the same statement on a
tiny config table, but the gate has no way to tell them apart without size context it
cannot derive from the diff.

- **Size context available** — live row-count/table-size stats, or a `hot_tables[]`
  list declared on the `migration` component → adjust: a large/hot table escalates
  (`medium` → `high`), a small one quiets (→ `low`). Note the adjustment in
  `evidence.snippet` (`"table <name> in hot_tables[] — escalated"`).
- **No size context** (the default) → **flat severity, no adjustment, no nag.** The
  finding still fires; only its grade stays put.

## Round-trip — up, down, up (env wave, sandbox only)

Proves each new migration can be applied, rolled back and re-applied. It is
destructive, so it runs **only** in the C23 sandbox database (`../executor.md` §3b),
never against shared state.

1. **Pick the commands** from the migration framework detected in the diff. Setup
   records them on the `migration` component's tooling; with none recorded, use this
   table:

   | Framework | Up | Down (one step) |
   |---|---|---|
   | Rails | `bin/rails db:migrate` | `bin/rails db:rollback STEP=<n>` |
   | Django | `python manage.py migrate` | `python manage.py migrate <app> <previous>` |
   | Alembic | `alembic upgrade head` | `alembic downgrade -<n>` |
   | Flyway | `flyway migrate` | `flyway undo` (needs undo scripts) |
   | numbered `*.up.sql` / `*.down.sql` | apply each `.up.sql` in order | apply the matching `.down.sql` in reverse order |
   | Prisma, Supabase | — | **forward-only** |

   `<n>` = the number of migrations this diff adds.
2. **Run up → down → up** in the sandbox database, after `seed`. Each step's exit code
   and first error line are recorded.
3. **Any error is a `blocker`**: `rule: migration-roundtrip-failed`,
   `category: architecture`, `file` = the failing migration, message naming the step
   (`down` failed on `20261017_add_due_date`) and the quoted error. `migration` is a
   `critical` component, so this aborts the run (`../severity-rubric.md` § *Fail-fast*).

Record `roundtrip: {ran: true, steps: ["up","down","up"], ok: true|false}`.

**Not run, said honestly.** Forward-only framework (Prisma, Supabase) ⇒
`roundtrip: {ran: false, reason: "forward-only"}`, matching the down-migration rule
above. No sandbox (`devkit/ENV.md` absent or its provisioner unresolved) ⇒
`roundtrip: {ran: false, reason: "no sandbox"}`. The report line reads *"migration
round-trip: not run — <reason>"*. Never "passed", never omitted, and never listed as a
check that ran.

## Semantic pass (/cook-backed)

Only when a DB flag assembles: `--supabase:migrations` (Supabase active + diff touches
`supabase/migrations/`) and/or `--database:sql-gotchas` (Database active). Neither → run
Stage 0 only. Compile `/cook` once, inject into one `Agent` subagent reviewing the
migration files (not app code that merely calls the schema). `source: pre-merge:migration`.
Stage verdict = worst of Stage 0 findings and the semantic verdict. `/cook` unresolvable →
Stage 0 only, semantic pass recorded `skipped`, `reason: "no_cook"` (degrade, not failure).
