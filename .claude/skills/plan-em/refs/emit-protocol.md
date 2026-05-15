# Emit protocol

Run at the end of Step 6, before the human approval gate. Scan the saved RFC for every trigger below. Collect all findings into a single table, ordered P0 first, then P1.

## Severity definitions

| Severity | Meaning |
|----------|---------|
| P0 | Blocks engineering kickoff. Must be resolved before the user approves the RFC. |
| P1 | Does not block, but requires user review. User can approve but should acknowledge. |

## P0 triggers — block the gate

| Trigger | Location |
|---------|----------|
| Any feature in §6 scope mapping cannot be assigned to a domain (implementation path unclear) | RFC §6 |
| A feature requires a new service, breaking schema change, or new external dependency — and no decision or alternative is documented | RFC §5 |
| Any design decision in §5 is marked OPEN with no owner or resolution path | RFC §5 |
| Any finding in §13 is marked **Critical** | RFC §13 |
| An agent in §7 has no features assigned in §6 (orphaned agent) | RFC §7 |

## P1 triggers — flag for review

| Trigger | Location |
|---------|----------|
| §4 alternatives has fewer than one rejected option with a stated reason | RFC §4 |
| Any phase in §8 is missing a blocking dependency or exit criterion | RFC §8 |
| Any risk in §12 has no mitigation stated | RFC §12 |
| Any finding in §13 is marked **Major** | RFC §13 |
| §14 timeline has an agent without an engineer-day estimate | RFC §14 |

## Emit format

If any findings exist, emit a findings table before the approval gate:

```
## Emit — RFC-[n] issues requiring attention

| Severity | Finding | Location | Action required |
|----------|---------|----------|-----------------|
| P0       | ...     | ...      | ...             |
| P1       | ...     | ...      | ...             |
```

**If P0 findings exist:** present the table, then run one `AskUserQuestion` per P0 item asking the user to decide or provide the resolution. Do not show the approval gate until all P0 items are resolved. Re-save the RFC after each resolution.

**If only P1 findings exist:** emit the table inline (no `AskUserQuestion`). Note: "These are non-blocking. Review before approving." Then proceed to the approval gate.

**If no findings:** emit `Emit — No issues flagged.` and proceed directly to the approval gate.
