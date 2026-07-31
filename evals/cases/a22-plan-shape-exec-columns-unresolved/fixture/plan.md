---
title: A22 fixture — exec-table column drift (Agent -> Owner, Execution steps -> Steps)
---

# A22 drift fixture

## 6. Feature execution table

| Feature | Owner | Steps |
|---------|-------|-------|
| F1: Login form | assertions | → F1-T1 |
| F2: Session cookie | assertions | → F2-T1 |

## Engineering — assertions

### Scope mapping

F1, F2.

## Todos — assertions

### F1

- **F1-T1 — Build the login form**
  - **objective:** render the form and post it
  - **type:** code
  - **files:** `src/login.tsx` (add)
  - **depends-on:** none
  - **done-when:** the form posts and errors render

### F2

- **F2-T1 — Set the session cookie**
  - **objective:** set SameSite=Lax on login
  - **type:** code
  - **files:** `src/session.ts` (add)
  - **depends-on:** F1-T1
  - **done-when:** the cookie is set with SameSite=Lax
