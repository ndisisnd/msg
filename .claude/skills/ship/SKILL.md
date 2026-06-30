---
name: ship
description: >
  Autonomous build-and-ship loop. Resolves a PRD (by path, or by prose that
  searches existing PRDs), spins up eng --build subagents across the execution
  table, then loops /review → /test → fix until both report no issues, and runs
  /pre-merge immediately after. Testing runs through the /test skill (consuming
  the eval_set), never raw runner commands. Holds the session continuously and runs
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
/ship  →  resolve PRD  →  eng --build  →  ┌─ /review → /test → fix ─┐  →  /pre-merge  →  done
                                          └──── loop until both ─────┘
                                                report no issues
```

`ship` is the engineering counterpart to `/plan`. Where `plan` produces an eng-tuned PRD, `ship` executes it.

Like `plan`, `ship` **owns no build, review, test, or gate protocol of its own** — it drives the pipeline stages itself, in order, threading the feature branch and PRD path forward. The difference is the mechanism: `plan` invokes its stages in-session via the `Skill` tool (sequential, interactive); `ship` invokes its stages as **subagents via the `Agent` tool** (so build agents run in parallel and each stage's own approval gate is auto-resolved by the autonomy contract — see § Permission policy). Each subagent runs a sub-skill's full, unmodified protocol.

**Testing goes through the `/test` skill, never raw runner commands.** `ship` does not shell out to `npm test` / `pytest` / `flutter test` itself, and its build agents skip `eng --build`'s raw-runner full-suite gate (Step 3) — full-suite verification is the dedicated **Test** stage, which runs `/test` and executes the `eval_set` assertions `/review` defers. (Build agents still run their per-feature TDD red/green checks while building — that granular cycle is intrinsic to `eng` and stays.)

## Pipeline stages

`ship` drives these five stages itself. Resolve / parse / guardrail are supporting work around them, not stages.

| # | Stage | Driven by | Detailed step | Sub-skill protocol |
|---|-------|-----------|---------------|--------------------|
| 1 | **Build** | parallel `Agent`s (one per agent group) | Step 3 | `eng --build` |
| 2 | **Review** | one `Agent` | Step 5 (loop) | `/review` |
| 3 | **Test** | one `Agent` | Step 5 (loop) | `/test --eval-set` |
| 4 | **Fix** | scoped `Agent`s (loops until both Review and Test are clean) | Step 5 (loop) | `eng --build` (findings-scoped) |
| 5 | **Pre-merge** | one `Agent` | Step 6 | `/pre-merge` |

Stages 2–4 form the **review → test → fix loop** (`ship`'s one iterative stage — it is *not* one-shot): each round runs `/review` then `/test`, and any open issue from *either* feeds the fix stage. `ship` controls all five; no sub-skill chains to the next on its own. The genuinely interactive pauses `ship` itself makes are the two guardrails and the round/verdict gates in § Permission policy — everything else is auto-resolved inside the subagents.

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

> Building and shipping this PRD autonomously. eng, review, test, and pre-merge run hands-off in subagents — I won't stop for their approval gates. Testing runs through the `/test` skill, not raw test commands. I will pause only when a change **touches a database file** (migrations, schema, ORM models/entities, seeds/fixtures) or introduces a **breaking change** — those need your sign-off because they affect production. I loop review → test → fix until both report no issues, then run pre-merge. I never push or merge.

## Permission policy

`ship` runs hands-off by delegating eng/review/test/pre-merge to **subagents** (via the `Agent` tool). Subagents run non-interactively, so each sub-skill's approval gate is auto-resolved to "proceed" — no prompt reaches the user. Every spawned subagent prompt must include:

> You are running autonomously with no user present. When the skill's protocol reaches an approval gate (`AskUserQuestion`), treat it as approved ("Yes, proceed" / "Run" / "Proceed") and continue. Only stop if genuinely blocked by missing information that cannot be inferred from the PRD or codebase — if so, return the blocker instead of guessing.

The **only** interactive pauses `ship` itself makes:

| Pause | When | Gate |
|-------|------|------|
| PRD disambiguation | Prose matches more than one PRD | Step 1 |
| **Database-touch guardrail** | A build or fix touches a database file | Step 4 (and re-checked after each fix round) |
| **Breaking-change guardrail** | A subagent reports a breaking change | Step 4 |
| Review/test round cap | `--max-rounds` reached with issues remaining (from `/review` or `/test`) | Step 5 |
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

### Step 3 — Stage 1: Build (spin up subagents)

**Branch contract.** `ship` creates ONE feature branch `feat/prd-<n>-<slug>` and every build/fix agent commits **directly onto it** (eng `commit_mode: direct`) — no per-agent sub-branches, no PRs. This is the branch `/review`, `/test`, and `/pre-merge` all diff against `<base>`, so the agents' commits must be on it for those stages to see anything. Parallel agents stay safe because each agent group owns a disjoint set of files (Step 2 grouped rows by Agent).

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
6. `branch`: `feat/prd-[n]-<slug>` — **the feature branch ship created; this is where your commits must land.**
7. `commit_mode`: `direct`
8. `agent`: the **Agent** column value for these rows
9. **Branch contract (critical):** "Run in `commit_mode: direct` — commit your work **directly onto `branch` (`feat/prd-[n]-<slug>`)**. Do NOT cut a per-agent sub-branch and do NOT open a PR (skip eng build-protocol Step 8). ship reviews and tests this exact branch, so commits left on a sub-branch would be invisible. You and the other parallel build agents each own a disjoint set of files (one agent group per `agent`), so committing to the shared feature branch is safe — touch only the files your assigned rows specify."
10. "Skip the full-suite gate (eng `--build` protocol Step 5 — the raw `npm test` / `pytest` / `flutter test` run). The ship workflow runs `/test` as a dedicated stage after review, so do not run the full suite yourself. Still complete your per-feature TDD red/green checks while building."
11. "Return: a one-paragraph build summary, the list of files you created/modified, and an explicit `BREAKING: <desc>` line for any change that alters a contract, schema, or public API that already-shipped code depends on (or `BREAKING: none`)."

Collect every subagent's summary, touched-file list, and breaking-change report.

**Post-build non-empty-diff gate.** Before doing anything else, verify the build agents actually committed to the feature branch — otherwise review/test/pre-merge would diff an empty branch:
```bash
git diff --quiet "<base>...feat/prd-<n>-<slug>" && echo EMPTY || echo NONEMPTY
```
If this prints `EMPTY` (no commits / no diff vs base), **hard-fail and stop** — do not proceed to the guardrail or review:
> Build produced no commits on `feat/prd-<n>-<slug>` (empty diff vs `<base>`). The build agents did not land code on the feature branch — check the eng build-mode branch contract (they must run `commit_mode: direct` and commit to `branch`, not a sub-branch). Aborting before review/test, which would otherwise review nothing.

Only continue to Step 4 once the diff is non-empty.

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

### Step 5 — Stages 2–4: Review → Test → Fix loop

Initialise `round = 0`. Each round runs **Review** then **Test**, pools the open issues from both, and fixes them. Loop:

1. `round += 1`.
2. **Review (Stage 2).** Spawn **one `Agent`** running review against the base. Its prompt: the autonomy paragraph + "Run `Skill(\"review\", \"<base>\")` from branch `feat/prd-[n]-<slug>` (so the diff is the branch's changes vs `<base>`). Return the path to the written findings JSON (`features/prd-[n]/review/review-*.json`), the `eval_set_path` it wrote (`features/prd-[n]/review/eval_set.json`, or `null`), the overall `verdict`, and the counts of `block` / `warn` / `info` findings."
3. **Test (Stage 3).** Spawn **one `Agent`** running the test skill, consuming the eval_set review just wrote. Its prompt: the autonomy paragraph + "Run `Skill(\"test\", \"--base <base> --prd <prd_path> --eval-set <eval_set_path>\")` from branch `feat/prd-[n]-<slug>`. Always pass `--prd <prd_path>` (it anchors the findings output to `features/prd-[n]/test/` and, if `eval_set_path` is `null`, bootstraps the eval_set from the PRD). Return the emitted findings JSON path, the overall `verdict`, and the `fail` finding count." This is the workflow's full-suite verification — it replaces the raw-runner gate the build agents skipped, and it executes the `executable` assertions `/review` deferred to `/test`.
4. **Pool open issues.** Read both findings JSONs. Define **open issues** = review findings with severity `block` or `warn` (`info` is not an issue) **plus** every `/test` finding that contributes to a `fail` verdict (a bucket that returned `pass_with_warnings` from a broken-environment error is *not* an open issue — see `/test`'s bucket-level error rule). 
5. **Exit conditions:**
   - Zero pooled open issues (review verdict `pass` **and** test verdict `pass`/`pass_with_warnings`) → exit loop → Step 6.
   - `round == max_rounds` with issues remaining → `AskUserQuestion`: **Run more rounds** (reset cap, continue) / **Stop and report** (terminate with the open issues listed).
6. **Fix (Stage 4).** Spawn `Agent` subagents (grouped by owning agent/file) running `eng --build` (with `commit_mode: direct`) scoped to ONLY the pooled findings — pass both findings JSON paths and instruct: "Fix exactly these review and test findings, committing **directly onto branch `feat/prd-[n]-<slug>`** (`commit_mode: direct`; no sub-branch, no PR) so the next round's `/review`/`/test` diff against `<base>` sees your fixes. Do not expand scope. Return touched files and any `BREAKING:` report." Build agents skip the full-suite gate as in Step 3 (the loop re-runs `/test` next round).
7. **Re-apply the Step 4 guardrail** to the fix diff. If it trips, PAUSE as in Step 4 before looping back to (2).
8. Loop back to (2).

### Step 6 — Stage 5: Pre-merge (immediately after issues are done)

Spawn **one `Agent`** running pre-merge. Prompt: the autonomy paragraph + "Run `Skill(\"pre-merge\", \"--base <base> --prd <prd_path>\")` from branch `feat/prd-[n]-<slug>`. Return the emitted findings JSON, its `verdict`, and the blocker/high counts."

Read the verdict:
- `pass` / `pass_with_warnings` → emit the final ship summary (below). Done.
- `fail` (blocker/high present) → emit the blockers, then `AskUserQuestion`: **Fix and re-run** (→ back to Step 5 scoped to the pre-merge blockers) / **Stop and report** (terminate with blockers listed). `ship` never pushes regardless.

### Final ship summary

```
Ship complete — PRD prd-[n]-[slug].
Branch: feat/prd-[n]-<slug>  (merge-ready — not pushed)
Build: <agents> agent(s), <files> files changed.
Review → Test: <rounds> round(s) → review pass, test <verdict> (0 open issues).
Pre-merge: <verdict> (<blockers> blockers, <highs> highs).
Next: gh pr create   /   /handoff
```

Never push, merge, or open a PR — that is the user's call.

## References

- `.claude/skills/eng/SKILL.md` — `--build` mode: work steps and the **branch contract**. ship spawns build agents with `commit_mode: direct`, so they commit straight to the feature branch ship reviews (no per-agent sub-branch, no PR). Spawned per agent group in Steps 3 & 5.
- `.claude/skills/review/SKILL.md` — five-mode code review; writes `features/prd-[n]/review/review-*.json` and `eval_set.json`; defers `executable` assertions to `/test`. Spawned in Step 5.
- `.claude/skills/test/SKILL.md` — execution-focused test skill; consumes `eval_set.json` via `--eval-set` and runs the workflow's full-suite verification. Spawned in Step 5 (replaces raw runner commands). 
- `.claude/skills/pre-merge/SKILL.md` — pre-push gate; emits the final verdict JSON. Spawned in Step 6.
- `scripts/ship-find-prd.sh` — ranks existing PRDs against a prose query (Step 1).
- `scripts/ship-db-touch.sh` — reports database files touched in the diff vs base (Step 4 guardrail).
- `/plan` — the planning counterpart that produces the eng-tuned PRD `ship` consumes.
