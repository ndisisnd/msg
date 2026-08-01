---
name: prd-1-login
---

## 3. Features & acceptance criteria

| ID | Feature | Acceptance criteria |
|----|---------|---------------------|
| F1 | Login form | The form posts and errors render |
| F2 | Session cookie | The cookie is set with SameSite=Lax |

## 6. Feature execution table

| Feature — concern | Files | Agent |
|-------------------|-------|-------|
| F1: Login form — API contract | | backend-eng |
| F1: Login form — Tests | | backend-eng |
| F2: Session cookie — cookie policy | | backend-eng |
| F2: Session cookie — iOS UI | | mobile-eng-ios |

## Todos — backend-eng

### F1

- **F1-T1 — Build the login handler**
  - **objective:** accept credentials and issue a session
  - **type:** code
  - **files:** `src/api/login.ts` (add), `src/api/router.ts` (edit)
  - **depends-on:** none
  - **done-when:** POST /login returns 200 on valid credentials

- **F1-T2 — Cover the handler**
  - **objective:** assert the happy and error paths
  - **type:** test
  - **files:** `tests/api/login.test.ts` (add), `src/api/login.ts` (edit)
  - **depends-on:** F1-T1
  - **done-when:** both paths assert

### F2

- **F2-T1 — Set the session cookie**
  - **objective:** set SameSite=Lax on a successful login
  - **type:** code
  - **files:** `src/api/session.ts` (add)
  - **depends-on:** F1-T1
  - **done-when:** the cookie carries SameSite=Lax

## Todos — mobile-eng-ios

### F2

_No discrete work for this feature._
