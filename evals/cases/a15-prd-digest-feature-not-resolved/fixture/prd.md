---
name: prd-3-login-dash
feature: Login
module: auth
platform: web
status: eng
product-tuned: yes
eng-tuned: yes
reviewed: no
created: 2026-07-30
summary: Exec table rows rendered "F1 — name" instead of the canonical "F1: name".
---

# PRD-3 — Login (exec rows rendered with a dash)

## 1. Summary

The §3 ids resolve fine; the §6 Feature cells are written `F1 — Login form`,
which the `--feature` exec filter (`startswith("F1:")`) cannot match.

## 3. Features & acceptance criteria

| ID | Feature | Acceptance criterion | Dependencies |
|----|---------|----------------------|--------------|
| F1 | Login form | Submitting valid credentials lands the user on /home | — |
| F2 | Session cookie | A successful login sets an HttpOnly session cookie | F1 |

## 6. Feature execution table

| Feature | Execution steps | Files | Todos | Agent |
|---------|-----------------|-------|-------|-------|
| F1 — Login form | Build the POST /login handler | src/api/login.ts | [F1](#todos-f1) | backend-eng |
| F2 — Session cookie | Set the cookie on a 200 | src/api/session.ts | [F2](#todos-f2) | backend-eng |
