# INTAKE-UPDATE — Update log

Edit history for INTAKE.md: content edits, removals and status fixes made by
`/intake` — append-only. INTAKE.md holds the current state; this file is how it
got there, including rows that no longer exist. Rows created by plain capture
are not logged (their `date` cell already records them).

`change` is always one of `modify` (a cell value changed — one entry per cell) ·
`add` (a row created by a split) · `remove` (a row deleted; the `#` is never
reused, so the ledger keeps a visible gap).

| when | row | change | detail |
|------|-----|--------|--------|
| 2026-01-11 | #1 | modify | goal: "prove it" → "prove the case contract" |
