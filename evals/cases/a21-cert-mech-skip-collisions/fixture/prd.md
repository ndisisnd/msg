---
title: A21 fixture — the exec table's Files column renamed to Paths
---

# A21 drift fixture

The exec table below is identical to `prd-a21-ok.md` except the **Files**
column is headed **Paths** — the one column the collision check reads. Before
A21 that produced zero collisions at exit 0, and cert-mech's capture threw the
sub-script's stderr WARNING away, so check 4 reported clean on a table whose
two rows both touch `src/login.tsx`.

## 3. Features & acceptance criteria

| ID | Feature | Acceptance criteria |
|----|---------|---------------------|
| F1 | Login form | the form posts and errors render |
| F2 | Session cookie | the cookie is set with SameSite=Lax |

## 6. Feature execution table

| Row | Feature | Agent | Paths | Execution steps |
|-----|---------|-------|-------|-----------------|
| 1 | F1 | frontend-eng | src/login.tsx | build the form |
| 2 | F2 | backend-eng | src/session.ts, src/login.tsx | set the cookie |

## Engineering — assertions

### Scope mapping

F1 and F2 map to src/login.tsx and src/session.ts.
