# INTAKE — Backlog ledger

The graded backlog of feature ideas and bugs. `/intake` appends rows;
`plan-pm` stamps `in-progress` + the `prd` mapping when it plans a row;
`merge --production` stamps `completed` when the mapped PRD ships.

**Status lifecycle:** `backlog` → `in-progress` (plan-pm creates + maps the PRD)
→ `completed` (merge --production ships the mapped PRD).

| # | date | type | idea | goal | grade | status | prd |
|---|------|------|------|------|-------|--------|-----|
| 1 | 2026-01-10 | feature | eval runner | prove the case contract | C:3 T:2 S:now | backlog |  |
| 2 | 2026-01-12 | bug | tally miscounts | stop silent empty tallies | C:2 T:1 S:next | backlog |  |
