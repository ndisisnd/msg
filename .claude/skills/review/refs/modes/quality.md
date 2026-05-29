# review — Quality mode

**When it runs:** first in pipeline order.

**What it checks:** code complexity, naming conventions, maintainability, dead code, and API contract soundness. Structural issues here are hard-block candidates — a structurally unsound codebase should not proceed to behavioral checks.

## Flags

Global (always): `--api-design`, `--architecture`, `--error-handling`, `--debug`

Domain flags: all active domains from `active_domains[]` that are touched by the diff (see `refs/FLAG-LIST.md`). Use sub-ref flags when only part of a domain is in scope.

## Execution

Spawn one `/cook --<flag>` Agent per flag in parallel. Each agent receives:
- The resolved diff
- The subset of changed files that touch its domain

Collect `{ verdict, findings[] }` from each. Aggregate: mode verdict = worst across all agents.
