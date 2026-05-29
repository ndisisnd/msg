# Improvement Plan — 12-review

**Skill:** review (new skill)
**Change type:** New capability

## Problem

After `eng --build` completes, there is no dedicated agent that reviews the code changes against the PRD and coding standards before a PR is created. The `eng --review` mode exists but conflates building and reviewing. `/review` is a standalone orchestrator that: resolves a diff, fingerprints the codebase, bootstraps an eval-set from the PRD, derives a review surface, confirms it with the user, then fans out to `/cook` sub-agents across five ordered review modes — aggregating all findings into a single structured JSON. Its output is designed to be consumed mechanically by preflight or read directly by a human.

**Position in the agentized workflow:**
```
eng --build  →  /review  →  [address findings]  →  /review (repeat until pass/warn)  →  /docu  →  gh pr create
```

`/review` is iterative: after findings are addressed, re-run `/review` until the verdict is `pass` or acceptable `warn`. Each run is independent — no state carried between runs.

---

## Review modes (locked, in execution order)

| # | Mode | Flag tier | What it checks |
|---|---|---|---|
| 1 | **Quality** | Global + domain | Complexity, naming, maintainability, dead code, API contracts (hard-block) |
| 2 | **Coverage** | None — test-runner driven | Are changed lines exercised by existing tests? Gap report vs eval-set |
| 3 | **Functional** | None — eval-set driven | Does the code satisfy the acceptance criteria / test cases from the eval-set? |
| 4 | **Security** | Global + domain | Injection, auth, input validation, secrets (hardcoded credentials, API keys, tokens) |
| 5 | **Performance** | Global + domain | N+1 queries, inefficient loops, missing indexes, memory usage |

**Ordering rationale:** Quality first ensures structural soundness before behavior is asserted. Coverage second confirms changed lines are exercised before Functional runs assertions. Security and Performance are independent of correctness and run last.

## Flag tiers

**Global flags** (always applied for applicable modes, regardless of domain):

| Mode | Global flags |
|---|---|
| Quality | `--api-design`, `--architecture`, `--error-handling`, `--debug` |
| Security | `--security`, `--auth` |
| Performance | `--performance` |

**Domain flags** (auto-selected from codebase fingerprint — detected once at startup):

| Domain detected | Domain flags available |
|---|---|
| Flutter / Dart | `--flutter`, `--flutter:<ref>`, `--dart`, `--dart:<ref>` |
| React | `--react`, `--react:<ref>` |
| Next.js | `--nextjs`, `--nextjs:<ref>` |
| Node.js | `--nodejs`, `--nodejs:<ref>` |
| TypeScript | `--typescript`, `--typescript:<ref>` |
| GraphQL | `--graphql`, `--graphql:<ref>` |
| Database (PostgreSQL / Redis) | `--database`, `--database:<ref>` |
| Supabase | `--supabase`, `--supabase:<ref>` |

Sub-ref flags (e.g. `--react:hooks`) are selected when only part of a domain is touched by the diff.

---

## Proposed changes

| # | What | How | Why necessary | Why ignorable | Rank |
|---|------|-----|---------------|---------------|------|
| 1 | Create `SKILL.md` for `review` | Write `.claude/skills/review/SKILL.md` covering usage, protocol (steps 1–7), flag tiers, mode table, sub-skill interface contract, constraints | Without the skill file the agent cannot be invoked via `/review` | Never — this is the core deliverable | P0 |
| 2 | Step 1 — Resolve diff | Same pattern as `/docu`: no args → `git diff HEAD`; branch name → `git diff <branch>`; PR number → `gh pr diff <n>`. Hard-exit with "nothing to review" if diff is empty. Hard-refuse on `main` | `/review` has no meaningful work without a diff | Never | P0 |
| 3 | Step 2 — Fingerprint codebase | Inspect repo root once at startup: check for `pubspec.yaml` (Flutter/Dart), `package.json` dependencies (React, Next.js, Node.js), `.ts`/`.tsx` files (TypeScript), `.graphql` files (GraphQL), migration files or `supabase/` dir (Supabase/Database). Store result as `active_domains[]`. Reused by all subsequent steps — never re-derived mid-run | Domain flags must be scoped to what's actually in the repo; loading irrelevant domain standards produces noise | Never | P0 |
| 4 | Step 3 — Locate PRD and bootstrap eval-set | Search `features/prd-*/prd-*.md` ordered by recency. If found: scan for sections named "Acceptance Criteria", "Test Cases", "Assertions" — extract as `eval_set[]`. If no eval-set sections found in PRD, or no PRD found: generate `eval_set[]` from diff + PRD requirements and present to user for confirmation (add / remove / edit entries). Emit eval-set size before proceeding | Functional and Coverage modes need a ground truth; without an eval-set they have nothing to assert against | If diff has no testable behavior (e.g. config-only change), eval-set may be empty | P0 |
| 5 | Step 4 — Derive review surface | Cross-reference diff against PRD: identify PRD rows covered, uncovered changes (scope creep candidates). For each active mode, select applicable flags: global flags always included; domain flags filtered by `active_domains[]` and which files in the diff touch that domain. Produce `surface: { files_changed, prd_rows_covered, uncovered_changes[], modes: [ { mode, flags[] } ] }` | Scoping prevents irrelevant findings; surfacing uncovered changes catches scope creep before PR opens | If no PRD, surface is diff-only | P0 |
| 6 | Step 5 — Confirm surface with user | Call `AskUserQuestion` once, showing: (a) surface summary (files, PRD rows, uncovered changes, eval-set size), (b) full proposed execution plan — each mode with its flags and the files each `/cook` agent will receive. Example: `Quality → /cook --api-design --architecture --react:component-patterns (auth.ts, api/users.ts)`. Options: **Proceed**, **Adjust**, **Cancel**. This is the only interactive gate | User must see and be able to correct the full execution plan before sub-agents spawn | Never — sole human checkpoint | P0 |
| 7 | Step 6 — Run modes in order, fan out `/cook` per mode | For each mode in order (Quality → Coverage → Functional → Security → Performance): spawn all `/cook --<flag>` sub-agents for that mode in parallel; wait for results; if any `block` verdict is returned, stop pipeline and emit findings immediately without running subsequent modes. Coverage invokes the test runner scoped to changed files and compares output against eval-set. Functional runs assertions from eval-set against the diff | Sequential modes prevent wasting tokens on later checks when earlier ones block; parallel fan-out within each mode keeps each mode fast | Never | P0 |
| 8 | Step 7 — Aggregate and emit findings JSON | Merge all mode outputs into: `{ verdict, prd, eval_set[], surface: { ... }, modes: { quality: { verdict, findings[] }, coverage: { verdict, gaps[] }, functional: { verdict, findings[] }, security: { verdict, findings[] }, performance: { verdict, findings[] } } }`. Overall verdict = worst across all modes. Emit JSON to stdout. Write to `features/prd-[n]/review/review-<YYYYMMDD-HHmmss>.json` if PRD path known; stdout-only otherwise | Single aggregated JSON is what preflight and the PR summary consume | Never | P0 |
| 9 | Sub-skill interface contract | Each `/cook --<flag>` sub-agent accepts `diff` and returns `{ verdict: "pass" \| "warn" \| "block", findings: [] }`. Each finding: `{ file, line, rule, severity, message, suggestion }`. Defined once in `review/SKILL.md` | Without a shared contract, mechanical aggregation breaks | Never | P0 |
| 10 | No-PRD fallback | When no PRD found: derive surface from diff alone, generate eval-set from diff, still confirm with user, still run all modes. Emit `"prd": null` in output JSON | `/review` must be usable outside a formal feature branch | Never | P1 |

---

## Verdict semantics

| Verdict | Meaning | Pipeline effect |
|---|---|---|
| `block` | At least one mode returned `block` | Stop pipeline immediately after the blocking mode; do not run subsequent modes |
| `warn` | No blocks; at least one mode returned `warn` | Continue; warnings surface in PR summary |
| `pass` | All modes returned `pass` | Continue silently |

## Constraints

- `/review` does **not** build, fix, or modify source code
- `/review` does **not** check documentation (that is `/docu`'s job)
- `/review` makes exactly **one** `AskUserQuestion` call (Step 5 surface confirmation)
- `/review` does **not** run on `main` directly
- Codebase fingerprint runs once at startup — never re-derived mid-run
- `/review` output JSON is the authoritative review artifact — written to disk when a PRD path is known
