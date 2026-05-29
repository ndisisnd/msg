# review — Performance mode

**When it runs:** fifth and final in pipeline order.

**What it checks:** N+1 query patterns, inefficient loops, missing database indexes, unbounded memory allocations, and unnecessary synchronous operations in the diff.

## Flags

Global (always): `--performance`

Domain flags: all active domains from `active_domains[]` that are touched by the diff (see `refs/FLAG-LIST.md`). Use sub-ref flags when scope is narrow (e.g. `--database:indexes`).

## Execution

Spawn one `/cook --<flag>` Agent per flag in parallel. Each agent receives:
- The resolved diff
- The subset of changed files that touch its domain

Collect `{ verdict, findings[] }` from each. Aggregate: mode verdict = worst across all agents.
