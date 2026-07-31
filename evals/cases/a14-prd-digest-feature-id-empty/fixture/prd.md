---
name: prd-2-login-drift
feature: Login
module: auth
platform: web
status: eng
product-tuned: yes
eng-tuned: yes
reviewed: no
created: 2026-07-30
summary: Same PRD, but the features table calls its id column "F-ID".
---

# PRD-2 — Login (drifted id column)

## 1. Summary

Same PRD as prd-a14-ok, except the §3 id column is headed `F-ID`, which
`pick(row, "id", "feature id")` does not resolve.

## 3. Features & acceptance criteria

| F-ID | Feature | Acceptance criterion | Dependencies |
|------|---------|----------------------|--------------|
| F1 | Login form | Submitting valid credentials lands the user on /home | — |
| F2 | Session cookie | A successful login sets an HttpOnly session cookie | F1 |

## 6. Feature execution table

| Feature | Execution steps | Files | Todos | Agent |
|---------|-----------------|-------|-------|-------|
| F1: Login form — API contract | Build the POST /login handler | src/api/login.ts | [F1](#todos-f1) | backend-eng |
| F2: Session cookie — cookie policy | Set the cookie on a 200 | src/api/session.ts | [F2](#todos-f2) | backend-eng |
