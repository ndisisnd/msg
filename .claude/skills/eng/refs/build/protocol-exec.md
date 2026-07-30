---
name: Execution Steps Guide
description: How eng agents fill the Execution steps and Files columns in the PRD's execution table — a ticket-id pointer plus the row's file set; the tickets themselves are the build spec
type: reference
---

# Execution steps + Files — the row's two cells

The **tickets are the build spec** (`refs/plan/template-todo.md`; `refs/build/protocol.md` § Spec source). The execution table is the index over them: each row points at the tickets that deliver it and lists the files it touches. Nothing in the row restates a ticket's contents.

You fill two cells on every row where the **Agent** column matches your agent name.

## Execution steps — a pointer to ticket ids

Write the ticket ids that deliver this row, in ticket-id order, prefixed with `→`:

```
→ F2-T1, F2-T2
```

**Rules:**

- Every id must resolve to a real `F<n>-T<k>` ticket under this PRD's `## Todos — <Agent Name>` block. An id that does not resolve is a **hard failure** — the build has no spec for the row.
- Every ticket you write for an owned F-ID appears in exactly one row's pointer cell. A ticket nobody points at is invisible to the row-scoped build.
- No prose, no numbered steps, no dependency notation. Ordering lives on the ticket (`depends-on`), the objective and the verification live on the ticket (`objective`, `done-when`), and the exact identifiers live on the ticket (`files`, `done-when`). Writing any of it here creates a second spec that will drift.
- A row with genuinely no discrete work still points at the feature's empty-block sentinel — see `refs/plan/template-todo.md`.

## Files — the collision key

A comma/space-separated list of every repo-relative path this row creates or modifies — **derived from the union of the `files` fields of the tickets the row points at**, so the two cells cannot disagree. This is what makes collision detection mechanical (`plan-em-exec-collision.py`), so it must be complete.

## Worked example

PRD feature F2: Track streak, assigned to `eng-backend`:

| Feature | Execution steps | Files | Todos | Agent |
|---------|----------------|-------|-------|-------|
| F2: Track streak — Schema migration | → F2-T1, F2-T2 | migrations/0043_add_streaks.sql, src/models/streak.py | [F2](#todos-f2) | eng-backend |

## Quality gate

Every row your agent owns must have **both** cells filled before you return your output. An empty Execution steps cell, an id that resolves to no ticket, or an empty Files cell is a hard failure — the first two leave the row without a spec, the third breaks collision detection.
