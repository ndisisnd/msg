---
id: prd-8-a8-populated
depends_on: []
---

# PRD 8 — A8 populated exec-table fixture

Identical to `prd-a8-blank.md` except that §6 already holds two rows of real
engineering work in the Execution steps / Files cells.

## 3. Features & acceptance criteria

| ID | Feature | Acceptance criteria | Dependencies |
|----|---------|---------------------|--------------|
| F1 | Login form | User can sign in | — |
| F2 | Session cookie | Cookie set on sign-in | — |

## 6. Feature execution table

| Feature | Execution steps | Files | Todos | Agent |
|---------|----------------|-------|-------|-------|
| F1: Login form — API contract | 1. Add POST /session 2. Validate creds | src/api/session.ts | [F1](#todos-f1) | backend-eng |
| F2: Session cookie — cookie policy | 1. Set SameSite=Lax | src/api/cookie.ts | [F2](#todos-f2) | backend-eng |

## 8. Todos

_None yet._
