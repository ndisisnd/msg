---
id: prd-13-a13-unresolved
status: planned
depends_on: []
---

# PRD 13 — A13 dependencies mentioned but no such column

The §3 table has no Dependencies column; a criteria cell mentions dependencies
and carries a real PRD id. The loose `/dependencies/` detector fires, the strict
column resolution finds nothing, and the old script mirrored zero ids at exit 0.

## 3. Features & acceptance criteria

| ID | Feature | Acceptance criteria |
|----|---------|---------------------|
| F1 | Saved searches | Blocked on dependencies: prd-5-search-index must ship first |

## 6. Feature execution table

| Feature | Execution steps | Files | Todos | Agent |
|---------|----------------|-------|-------|-------|
