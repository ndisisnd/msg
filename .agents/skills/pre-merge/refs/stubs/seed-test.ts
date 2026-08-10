/**
 * Committed seed fixture for the C23 test-sandbox — skeleton.
 *
 * Copied by `/pre-merge --init` under per-item approval, then referenced from
 * `devkit/ENV.md`'s fenced `env` block:
 *
 *   seed:  <migrate-from-zero> && tsx scripts/seed-test.ts
 *   reset: <drop + migrate-from-zero> && tsx scripts/seed-test.ts
 *
 * Two rules this file exists to enforce (S-Q1):
 *
 *  1. **Migrate from zero, never restore a snapshot.** A prod-like dump drags
 *     real user data into a sandbox and rots the moment the schema moves. The
 *     seed runs after the project's own migrations, against an empty database.
 *  2. **Versioned and reviewed.** The fixture is committed, so a test that
 *     depends on "the seeded admin user" fails in review when someone changes
 *     what that user is — not silently at 2am.
 *
 * `scale_factor` (optional, from `ENV.md`) multiplies the *generated* rows so
 * `perf` and `load` exercise a realistic table size. It never changes the
 * hand-written fixtures below — those are the ones tests assert on.
 */

const SCALE = Number(process.env.SEED_SCALE_FACTOR ?? 1);

async function main() {
  // ── 1 · Deterministic fixtures — tests assert on these by name/id ─────────
  // Keep this list small, stable, and self-describing.
  //
  // await db.insert(users).values([
  //   { id: "u_admin", email: "admin@example.test", role: "admin" },
  //   { id: "u_member", email: "member@example.test", role: "member" },
  // ]);

  // ── 2 · Generated bulk rows — scaled, never asserted on ───────────────────
  // const rows = Array.from({ length: 100 * SCALE }, (_, i) => ({
  //   id: `u_bulk_${i}`,
  //   email: `bulk${i}@example.test`,
  //   role: "member",
  // }));
  // await db.insert(users).values(rows);

  console.log(`seeded (scale_factor=${SCALE})`);
}

main().catch((err) => {
  // Fail loudly: a half-seeded sandbox produces confusing test failures that
  // look like product bugs.
  console.error("seed failed:", err);
  process.exit(1);
});
