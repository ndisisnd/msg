---
name: ship
description: >
  Autonomous build-and-ship loop. Resolves a PRD (by path, or by prose that
  searches existing PRDs), spins up eng --build subagents across the execution
  table, then loops /review → fix until review reports no issues, and runs
  /pre-merge immediately after. Holds the session continuously and runs
  hands-off — approval gates are skipped EXCEPT when a change touches database
  files (migrations, schema, ORM models/entities, seeds/fixtures) or introduces
  a breaking change, which force a pause. Invoke with /ship <PRD path | prose>.
model: claude-sonnet-4-6
allowed_tools:
  - Agent
  - Bash
  - Read
  - AskUserQuestion
---

# ship

Autonomous build-and-ship loop orchestrator. One command takes an eng-tuned PRD from execution table to merge-ready.

```
/ship  →  resolve PRD  →  eng --build (subagents)  →  ┌─ /review ──┐  →  /pre-merge  →  done
                                                       │   fix      │
                                                       └─ loop until ┘
                                                       no more issues
```

`ship` is the engineering counterpart to `/plan`. Where `plan` produces an eng-tuned PRD, `ship` executes it.

## Usage

**Invoke**: `/ship <PRD path | prose>` plus optional flags.

| Form | Meaning |
|------|---------|
| `/ship features/prd-3-foo/prd-3-foo.md` | Use this PRD directly |
| `/ship streak tracking` | **Prose searches existing PRDs** — finds the best-matching PRD under `features/prd-*/` |
| `--base <ref>` | Diff base for review / pre-merge (default `origin/main`) |
| `--max-rounds <N>` | Max review→fix iterations before asking the user (default `5`) |

The prose form **does not generate a PRD** — it searches for one. To create a PRD first, run `/plan`.

**Hard refusals:**
- **No matching PRD:** if prose matches zero PRDs, refuse: `No PRD matches "<query>". Run /plan to create one, or pass a PRD path.` Terminate.
- **No execution table:** if the resolved PRD has no `## Execution Table` with rows, refuse: `PRD <path> has no execution table — run /plan-em (or /plan) on it first.` Terminate.
- **Never pushes or merges:** `ship` runs up to and including `/pre-merge`. It never runs `git push`, `gh pr merge`, `git merge`, or creates a PR. The branch is left merge-ready for the user.

## Autonomy contract

State this contract to the user before starting, then proceed:

> Building and shipping this PRD autonomously. eng, review, and pre-merge run hands-off in subagents — I won't stop for their approval gates. I will pause only when a change **touches a database file** (migrations, schema, ORM models/entities, seeds/fixtures) or introduces a **breaking change** — those need your sign-off because they affect production. I loop review→fix until no issues remain, then run pre-merge. I never push or merge.

## Permission policy

`ship` runs hands-off by delegating eng/review/pre-merge to **subagents** (via the `Agent` tool). Subagents run non-interactively, so each sub-skill's approval gate is auto-resolved to "proceed" — no prompt reaches the user. Every spawned subagent prompt must include:

> You are running autonomously with no user present. When the skill's protocol reaches an approval gate (`AskUserQuestion`), treat it as approved ("Yes, proceed" / "Run" / "Proceed") and continue. Only stop if genuinely blocked by missing information that cannot be inferred from the PRD or codebase — if so, return the blocker instead of guessing.

The **only** interactive pauses `ship` itself makes:

| Pause | When | Gate |
|-------|------|------|
| PRD disambiguation | Prose matches more than one PRD | Step 1 |
| **Database-touch guardrail** | A build or fix touches a database file | Step 4 (and re-checked after each fix round) |
| **Breaking-change guardrail** | A subagent reports a breaking change | Step 4 |
| Review round cap | `--max-rounds` reached with issues remaining | Step 5 |
| Pre-merge failure | pre-merge returns `fail` (blocker/high) | Step 6 |

**Database files** (force a pause when touched) — detected by `scripts/ship-db-touch.sh`:
- `**/migrations/**`, `supabase/migrations/**`, `**/*.sql`, `schema.prisma`
- `**/models/**`, `**/entities/**`, `*.entity.*`
- `**/seeds/**`, `**/fixtures/**`, `seed.*`

## Protocol

### Step 1 — Resolve the PRD

Determine `prd_path`:

- **Path input** (`*.md` that exists) → use it directly.
- **Prose input** → run the search helper (resolve local first, then the global install):
  ```bash
  S=.claude/scripts/ship-find-prd.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/ship-find-prd.sh"; bash "$S" "<prose>"
  ```
  It prints ranked candidate PRD paths, best first.
  - **0 candidates** → hard-refuse (`No PRD matches …`).
  - **1 candidate** → use it; emit `Resolved PRD: <path>`.
  - **2+ candidates** → `AskUserQuestion` (single-select) listing the top candidates + "None of these" (→ refuse).

Then validate: read the PRD and confirm a `## Execution Table` with at least one data row exists. If not → hard-refuse (`… has no execution table …`).

Derive from the path: `n` and `slug` from `features/prd-[n]-[slug]/prd-[n]-[slug].md`, and `branch = feat/prd-[n]-<slug>`.

### Step 2 — Parse the execution table

Read the `## Execution Table`. For every data row capture `{ feature_id, feature_cell, concern, agent }` where `feature_cell` is the exact `<ID>: <name> — <concern>` text of the **Feature** column. Group rows by the **Agent** column value → one build subagent per agent.

Pre-flag **database-concern rows**: any row whose concern is `Schema migration` / mentions `schema`, `migration`, `seed`, `model`, or `entity`. These are expected database touches — they will trip the Step 4 guardrail by design.

### Step 3 — Build phase (spin up subagents)

**Create the feature branch once** (concurrent creation from `main` corrupts the tree):
```bash
git rev-parse --verify --quiet "feat/prd-<n>-<slug>" >/dev/null || git switch -c "feat/prd-<n>-<slug>" main
```

Then spawn **one `Agent` per agent group, all in a single message** (parallel). Each agent's prompt includes:

1. The autonomy-contract paragraph from § Permission policy.
2. "Read `.claude/skills/eng/SKILL.md` fully and follow its protocol."
3. Mode flag: `--build`
4. `prd-path`: `prd_path`
5. `rows`: this agent's `feature_cell` values, semicolon-separated
6. `branch`: `feat/prd-[n]-<slug>`
7. `agent`: the **Agent** column value for these rows
8. "Return: a one-paragraph build summary, the list of files you created/modified, and an explicit `BREAKING: <desc>` line for any change that alters a contract, schema, or public API that already-shipped code depends on (or `BREAKING: none`)."

Collect every subagent's summary, touched-file list, and breaking-change report.

### Step 4 — Guardrail (after build, before review)

Run the database-touch detector against the branch (resolve local first, then global):
```bash
S=.claude/scripts/ship-db-touch.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/ship-db-touch.sh"; bash "$S" "<base>"
```
It prints touched database files (empty = none).

Decide:
- **Database files touched** (non-empty output) **OR** any subagent returned `BREAKING:` (not `none`) → **PAUSE**. Present via `AskUserQuestion` (single-select):
  > This build touched production-sensitive surfaces:
  > • Database files: `<list>`
  > • Breaking changes: `<list>`
  > How do you want to proceed?
  - **Approve & continue** → proceed to Step 5.
  - **Stop** → terminate with a summary of what was built and left on the branch. Do not review or pre-merge.
- **Neither** → continue to Step 5 silently (autonomous).

### Step 5 — Review loop

Initialise `round = 0`. Loop:

1. `round += 1`.
2. Spawn **one `Agent`** running review against the base. Its prompt: the autonomy paragraph + "Run `Skill(\"review\", \"<base>\")` from branch `feat/prd-[n]-<slug>` (so the diff is the branch's changes vs `<base>`). Return the path to the written findings JSON (`features/prd-[n]/review/review-*.json`), the overall `verdict`, and the counts of `block` / `warn` / `info` findings."
3. Read the findings JSON. Define **open issues** = findings with severity `block` or `warn` (`info` is not an issue).
4. **Exit conditions:**
   - Zero open issues (verdict `pass`) → exit loop → Step 6.
   - `round == max_rounds` with issues remaining → `AskUserQuestion`: **Run more rounds** (reset cap, continue) / **Stop and report** (terminate with the open issues listed).
5. **Fix** the open issues: spawn `Agent` subagents (grouped by owning agent/file) running `eng --build` scoped to ONLY the findings — pass the findings JSON path and instruct: "Fix exactly these review findings on branch `feat/prd-[n]-<slug>`. Do not expand scope. Return touched files and any `BREAKING:` report."
6. **Re-apply the Step 4 guardrail** to the fix diff. If it trips, PAUSE as in Step 4 before looping back to (2).
7. Loop back to (2).

### Step 6 — Pre-merge (immediately after issues are done)

Spawn **one `Agent`** running pre-merge. Prompt: the autonomy paragraph + "Run `Skill(\"pre-merge\", \"--base <base> --prd <prd_path>\")` from branch `feat/prd-[n]-<slug>`. Return the emitted findings JSON, its `verdict`, and the blocker/high counts."

Read the verdict:
- `pass` / `pass_with_warnings` → emit the final ship summary (below). Done.
- `fail` (blocker/high present) → emit the blockers, then `AskUserQuestion`: **Fix and re-run** (→ back to Step 5 scoped to the pre-merge blockers) / **Stop and report** (terminate with blockers listed). `ship` never pushes regardless.

### Final ship summary

```
Ship complete — PRD prd-[n]-[slug].
Branch: feat/prd-[n]-<slug>  (merge-ready — not pushed)
Build: <agents> agent(s), <files> files changed.
Review: <rounds> round(s) → verdict pass (0 open issues).
Pre-merge: <verdict> (<blockers> blockers, <highs> highs).
Next: gh pr create   /   /handoff
```

Never push, merge, or open a PR — that is the user's call.

## References

- `.claude/skills/eng/SKILL.md` — `--build` mode: branch, work steps, commit/PR contract. Spawned per agent group in Steps 3 & 5.
- `.claude/skills/review/SKILL.md` — five-mode code review; writes `features/prd-[n]/review/review-*.json`. Spawned in Step 5.
- `.claude/skills/pre-merge/SKILL.md` — pre-push gate; emits the final verdict JSON. Spawned in Step 6.
- `scripts/ship-find-prd.sh` — ranks existing PRDs against a prose query (Step 1).
- `scripts/ship-db-touch.sh` — reports database files touched in the diff vs base (Step 4 guardrail).
- `/plan` — the planning counterpart that produces the eng-tuned PRD `ship` consumes.
