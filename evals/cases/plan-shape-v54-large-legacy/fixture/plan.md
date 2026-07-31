---
title: v5.4 fixture — a pre-v5.4 13-section engineering plan, read-tolerated
---

## Engineering — assertions

### 1. Summary

Ship the login form.

### 2. PRD reference

- **PRD:** `features/prd-1-login/prd-1-login.md`

### 3. Alternatives considered

Session cookies were the only serious option.

### 4. Design decisions

**Decision:** cookie vs token. **Resolution:** cookie.

### 5. Scope mapping

F1 → backend.

### 6. Phases and dependencies

1. **Phase 1 — schema.** **Blocks:** none. **Exit:** merged.

### 7. Integration contracts

None.

### 8. Developer experience

No user-facing API change — internal only.

### 9. Migration and breaking changes

No breaking changes.

### 10. Branching and CI strategy

Feature branch, standard CI.

### 11. Risks and mitigations

None — the change is additive.

### 12. Findings — PRD gaps

None.

### 13. Open questions for human gate

None.

## Todos — assertions

### F1

_No discrete work for this feature._

