---
name: Execution Table Template
description: Feature execution breakdown table — three columns; plan-em pre-populates Feature and Agent, and the Files column is derived from the tickets by script, never typed
type: reference
---

# Execution Table Template

The execution table is a flat breakdown of every feature into its discrete execution concerns. `plan-em` creates the skeleton (Feature + Agent pre-populated, Files blank) after the agent roster is approved. The table is an **index over the tickets**, not a spec of its own: the `## Todos` tickets are the single and final build spec.

## Table structure

Three columns:

| Feature — concern | Files | Agent |
|-------------------|-------|-------|

**Column definitions:**

- **Feature — concern** — `<ID>: <name> — <execution concern>`. Combines the PRD feature ID, feature name, and this row's specific execution concern (e.g. `F1: Set daily goal — API contract`). One row per execution concern per feature. This cell is also the `rows` identifier an eng invocation is assigned by, so its text is generated, never hand-typed.
- **Files** — **Derived by script, never by an agent.** The union of the `files` paths of the tickets under this row's F-ID in this row's agent's `## Todos — <Agent>` block, written by `script-em-exec-skeleton.py --fill-files`. This is what makes collision detection mechanical: two rows are unsafe to run in parallel iff their Files sets overlap.
- **Agent** — Pre-populated by `plan-em` from the approved agent roster. Names the agent responsible for this concern, and is how a build invocation confirms row ownership.

**What v5.4 removed, and why.** Two columns are gone:

| Removed | Why |
|---------|-----|
| **Execution steps** (`→ F2-T1, F2-T2`) | A pointer that duplicated information already in the ticket ids themselves. A build agent locates its tickets from `## Todos — <Agent>` / `### F<n>` for its assigned F-IDs — the pointer added a second index that could drift out of agreement with the first, and a whole class of `unresolved-pointer` / `unpointed-ticket` failures with it. |
| **Todos** (`[F1](#todos-f1)`) | A markdown anchor for human navigation only. Nothing mechanical read it, and it cost a cell on every row. |

Rows written before v5.4 keep both columns and keep working — every reader resolves columns by name, so a 5-column table and a 3-column table schedule identically (`script-em-exec-collision.py`, `script-eng-plan-shape.py` check 6, `script-prd-digest.py`).

## Execution concerns to cover

For each feature, create one row per applicable concern. Always evaluate:

| Concern | When to include |
|---------|----------------|
| API contract | Feature exposes or consumes any endpoint |
| Schema migration | Feature reads or writes any database table |
| Authentication | Feature introduces or extends an auth flow |
| Webhook / hook | Feature emits events or hooks into a platform lifecycle |
| Client implementation | Feature has UI or client-side logic |
| Tests | Always — one row per agent covering their owned concerns |

Add rows for any additional concern surfaced by the codebase scan or integration contracts section.

## How plan-em builds the skeleton

After the agent roster is approved, plan-em **decides** the rows but **renders** them with `.claude/scripts/script-em-exec-skeleton.py` (two-path resolution) — so row text is generated deterministically, never hand-typed:

1. For each feature in the PRD, enumerate its applicable execution concerns (using the table above as a checklist) — this judgment stays with the LLM.
2. Assign each concern to the agent that owns it (from the scope mapping).
3. Emit one `{"fid","concern","agent"}` object per `(feature, concern)` row, in row order, as a JSON array and pipe it to `script-em-exec-skeleton.py --write <prd.md>`. The script reads §3 to resolve each `fid → <name>` and writes one row per spec entry with Feature = `<F-ID>: <name> — <concern>` and Agent pre-populated, Files blank. A spec `fid` absent from §3 is a hard error (exit 1) — fix the spec, not the PRD.

**One home.** The rendered skeleton goes into the PRD's **reserved `## 6. Feature execution table` section** — `--write` replaces that section's `_To be populated by plan-em …_` placeholder in place. Never append a second `## Execution Table` heading; that legacy name is read-tolerated by the parsers for PRDs written before v5, and is never written by anything now. The result reads:

```markdown
## 6. Feature execution table

| Feature — concern | Files | Agent |
|-------------------|-------|-------|
| F1: Set daily goal — API contract | | backend-eng |
| F1: Set daily goal — Schema migration | | backend-eng |
| F1: Set daily goal — iOS UI | | mobile-eng-ios |
| F1: Set daily goal — Tests | | backend-eng |
| F2: Track streak — Schema migration | | backend-eng |
| F3: Daily reminder — iOS push | | mobile-eng-ios |
```

## How the Files column gets filled

Not by an agent. Once the plan wave has written the `## Todos — <Agent>` tickets, run the derivation once over the PRD:

```bash
S=.claude/scripts/script-em-exec-skeleton.py; [ -f "$S" ] || S="$HOME/.claude/scripts/script-em-exec-skeleton.py"
python3 "$S" --fill-files "$PRD_DIR/prd-[n]-[slug].md"
```

For each row it unions the `files` paths of every ticket under that row's F-ID in that row's agent's Todos block, and writes the result into the Files cell. Output is one `FILLED <prd> rows=<n> paths=<m>` line.

**Rows sharing an (F-ID, agent) pair get the same Files set.** That is deliberate, not an approximation worth fixing: the column exists to answer a file-disjointness question, and splitting one feature's file set across its concern rows would claim a disjointness the build does not actually have — two concerns of the same feature, built by the same agent, genuinely do touch each other's files.

Two failure lines are worth knowing:

- `MISSING_TICKETS row=<n> fid=<F> agent=<a>` — **hard failure, exit 1, nothing written.** A row names an F-ID with no `### F<n>` block under that agent's `## Todos — <a>`. The plan pass is incomplete; re-run it rather than hand-filling the cell.
- `EMPTY_FILES row=<n> fid=<F> agent=<a>` — informational, exit stays 0. The F-ID's block is the empty-feature sentinel, so the row legitimately touches no files and its cell stays blank.

## Quality gate

Every row must have a non-blank Files cell before the build wave, **except** rows whose feature carries the empty-work sentinel. The gate is not "did the agent remember" — it is "was the derivation run": a blank column means `--fill-files` has not been executed since the tickets were written. Re-run it; never type a cell by hand, because a typed cell and the tickets can disagree and the collision graph is only as true as this column.
