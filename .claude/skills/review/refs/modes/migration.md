# review — Migration mode

**When it runs:** sixth in pipeline order — after Performance. **Conditional:** only runs when the diff touches a migration file. All other modes always run; Migration is skipped (and omitted from output, same as an unrun mode) when the condition below doesn't match.

**What it checks:** irreversible or unsafe database migrations — dropped tables/columns, unsafe type changes, missing defaults on new `NOT NULL` columns, non-concurrent index creation, and (where the framework pairs them) a missing down-migration.

## Trigger condition

Diff touches at least one file matching:
- `supabase/migrations/*.sql`
- `**/migrations/*.sql` or `**/migrations/*.ts` (generic SQL/TS migration dirs)
- `prisma/migrations/**`
- `db/migrate/**` (Rails)

If none match, skip this mode entirely — do not run Stage 0 or spawn `/cook` agents, and omit `migration` from the output `modes` object.

## Flags

Domain-conditional, not global — Migration mode has no always-on flags:

| Condition | Flag |
|---|---|
| Supabase active (`active_domains[]` includes Supabase) and diff touches `supabase/migrations/` | `--supabase:migrations` |
| Database active (`active_domains[]` includes Database) | `--database:sql-gotchas` |

If neither condition matches (a migration file was touched but no matching domain was detected — e.g. a bare `.sql` file with no Supabase/Database signal elsewhere in the repo), run Stage 0 only and skip the semantic stage.

## Stage 0 — Static migration-safety scan

Runs before the semantic stage, on the *added* lines of each matching migration file only (not the whole file — a migration that only re-runs prior safe statements shouldn't re-flag them).

| Pattern in added lines | Finding | Severity |
|---|---|---|
| `DROP TABLE` / `DROP COLUMN` | Irreversible data loss — no rollback path once applied. | `blocker` |
| `ALTER TABLE ... ALTER COLUMN ... TYPE` (without an explicit safe-cast note in a preceding comment) | Type change can lock the table and silently truncate/reject existing data. | `high` |
| `ALTER TABLE ... ADD COLUMN ... NOT NULL` with no `DEFAULT` clause | Fails immediately against existing rows unless the table is empty; needs a backfill step or a default. | `high` |
| `CREATE INDEX` without `CONCURRENTLY` (Postgres-family SQL only) | Takes a write lock on the table for the duration of the build. | `medium` |
| `RENAME COLUMN` / `RENAME TABLE` | Breaks any in-flight code still reading the old name until deploy completes. | `medium` |

Each hit produces one finding conforming to the canonical finding object (`../../shared/refs/finding-schema.md`):
- `source: "migration:static"`
- `category: "architecture"`
- `rule`: the matched pattern name (e.g. `"drop-table"`, `"alter-column-type"`, `"add-not-null-no-default"`, `"create-index-no-concurrent"`, `"rename"`)
- `file` / `line`: the migration file and the matching added line
- `evidence.snippet`: the offending line

**Down-migration check:** only for frameworks that pair up/down files by convention (Rails `db/migrate/*.rb` — must define `def down` or `def change`; numbered SQL pairs named `*.up.sql`/`*.down.sql` — the `.down.sql` sibling must exist). Supabase and Prisma migrations are forward-only by design — never check for a down-migration on those. Missing pair → one `medium` finding, `rule: "missing-down-migration"`.

**No short-circuit:** like Security Stage 0, Migration Stage 0 always proceeds to the semantic stage (if flags were assembled) regardless of its own verdict — static pattern hits and semantic review are independent signals.

## Execution (semantic stage)

Spawn one `/cook --<flag>` Agent per flag assembled above, in parallel. Each agent receives the resolved diff and the subset of changed files matching the trigger condition (migration files only — Migration mode does not review application code that merely *calls* a migrated schema).

Collect `{ verdict, findings[] }` from each. Aggregate: mode verdict = worst across all agents AND Stage 0 findings.

## Output

```json
{
  "verdict": "pass" | "warn" | "block",
  "findings": []
}
```

Omitted from the top-level `modes` object entirely when the trigger condition doesn't match (not emitted as an empty/`n/a` mode).
