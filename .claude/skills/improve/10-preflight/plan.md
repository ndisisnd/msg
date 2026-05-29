# Improvement Plan — 10-preflight

**Skill:** preflight (new skill)
**Change type:** New capability
**Size:** Large

## Problem

When an agent finishes building code, there is no pre-PR quality gate it runs on itself before `gh pr create`. Without one, the agent can create PRs with failing tests, stale documentation, broken API contracts, or accidental secrets already embedded in the diff. The human reviewer ends up doing mechanical checking rather than judgment work — and a secret in a PR is already public the moment it's created.

The `preflight` skill fills this gap. It runs in the agent's workflow immediately after `eng --build` completes and before the PR is created. It is fully agentized: no interactive prompts during the run, no human involvement until the PR is ready. The human only sees work that has already passed the agent's own bar.

**Position in the agentized workflow:**
```
eng --build  →  /preflight  →  gh pr create  →  CI  →  human review
```

**Dependency map — sub-skills called by canary:**

| Sub-skill | Status | Role in canary |
|---|---|---|
| `eng --review` | Exists (in progress) | Code quality + test gate |
| `secret-scan` | Not yet built | Hard-block: secrets in diff |
| `breaking-change` | Not yet built | Hard-block: API/interface breaks |
| `docu` | Planned (11-docu) | Soft-warn + self-heal: stale doc refs |
| `pr-prep` | Not yet built | Soft-warn: PR hygiene |

Preflight is an **orchestrator**. It does not duplicate each sub-skill's logic — it calls them in sequence, reads their output, and aggregates the verdict. Each sub-skill must conform to the interface contract defined in item 9 below.

---

## Proposed changes

| # | What | How | Why necessary | Why ignorable | Rank |
|---|------|-----|---------------|---------------|------|
| 1 | Create `SKILL.md` for `preflight` | Write `.claude/skills/preflight/SKILL.md` covering: usage, protocol (steps 1–7), verdict semantics, sub-skill interface contract, constraints | Without the skill file the agent cannot invoke `/preflight` | Never — this is the core deliverable | P0 |
| 2 | Step 1 — Scope resolution | Derive three fields from context: (a) `branch` — current `git branch --show-current`; (b) `diff` — `git diff main...HEAD`; (c) `prd_path + rows` — from `eng --review` output if available, else from explicit args, else `null`. Hard-refuse if `git diff main...HEAD` is empty (nothing to check). Emit a one-line scope summary before proceeding: branch name, commit count, files changed | Canary needs a concrete diff to scan; a stale or empty diff produces meaningless results | Only if called with an explicit `--diff` override | P0 |
| 3 | Step 2 — Secret scan (hard block) | Invoke `secret-scan` with the resolved diff. Read its verdict. If verdict is `block`: emit finding (step, file, line, secret type masked), exit with `BLOCK`, stop pipeline. Secret-scan must run before any other check — a secret in a PR is already public the moment `gh pr create` executes | Catching a secret post-PR means it's already in git history; pre-PR is the only safe gate | Never | P0 |
| 4 | Step 3 — Code quality gate via `eng --review` (hard block) | Invoke `eng --review` with `prd_path` and `rows` if available. If `prd_path` is null, invoke in diff-only mode (eng reads the diff and runs tests scoped to changed files, without an exec-table). Read the JSON verdict field. If verdict is `fail`: emit the `blocker` and `critical_count`, exit with `BLOCK`, stop pipeline | Test failures and critical assertion gaps mean the code does not meet its own contract; a PR in this state wastes reviewer time | Only if neither PRD path nor diff-only mode is available | P0 |
| 5 | Step 4 — Breaking change detection (hard block) | Invoke `breaking-change` with the resolved diff. It scans for: removed or renamed public exports, changed function/method signatures, removed REST endpoints or changed HTTP methods, removed or renamed GraphQL fields, removed DB columns or changed column types. For each confirmed break: records `file`, `identifier`, `change_type`, `impact`. If any finding exists: emit findings list, exit with `BLOCK`, stop pipeline | Breaking changes need to be intentional and explicitly flagged; unintentional breaks damage callers and dependents silently | Only if the diff touches no public interfaces | P1 |
| 6 | Step 5 — Stale doc detection + self-heal (soft warn) | Invoke `docu` with the resolved diff. Collect findings (`{ file, line, stale_text, suggested_text, reason }`). For each finding, attempt to auto-apply the fix via `Edit` without asking the user. After self-heal, re-collect any remaining unfixed findings. Remaining findings are soft warnings — they do not block the pipeline. Log: how many were auto-healed vs how many remain | Agent can fix stale doc refs itself with no human input; surfacing them as a block would slow down the pipeline for something the agent can resolve | Only if repo has no doc files | P1 |
| 7 | Step 6 — PR hygiene check (soft warn) | Invoke `pr-prep` with branch name, commit list, and diff. It checks: (a) branch name follows convention (no bare `main`, `fix`, `temp`); (b) commit messages are well-formed (no bare "wip", "fixup", "asdf"); (c) no debug-only commits (console.log dumps, commented-out test blocks); (d) PR description template fields are populated if a template exists. All findings are soft warnings — they do not block | PR hygiene issues slow down human review; catching them pre-PR means the reviewer sees clean work on first open | Low severity — human can spot these too | P2 |
| 8 | Verdict aggregation and terminal output | After all steps complete: aggregate findings. `BLOCK` if any hard-block finding was emitted (step 2, 3, or 4). `WARN` if soft warnings remain from steps 5–6. `PASS` if clean. Emit a single structured terminal summary: one line per step showing status (✓ pass / ⚠ warn / ✗ block), finding count, and action taken. On `BLOCK`: exit non-zero, stop the pipeline, do not proceed to `gh pr create`. On `WARN` or `PASS`: exit zero, pipeline continues. Total output must fit in a single scrollable terminal view | Downstream steps need a signal to proceed or halt; the summary gives the agent (and any human reading logs) a clear picture of what passed and what didn't | Never | P0 |
| 9 | Sub-skill interface contract (defined in SKILL.md) | Each sub-skill called by preflight must conform to: **Input** — accepts `diff` (string, git diff output) as its primary argument. **Output** — returns a structured object with at minimum `{ verdict: "pass" \| "warn" \| "block", findings: [] }`. Preflight reads this object and does not parse free-form text. This contract is defined once in `preflight/SKILL.md` and referenced by each sub-skill's own plan | Without a shared interface, the orchestrator cannot reliably read each sub-skill's output | Never — relaxing the contract breaks the orchestrator | P0 |
| 10 | Preflight run artifact | After every run, write `features/prd-[n]/preflight/preflight-<YYYYMMDD-HHmmss>.json` if `prd_path` is known; otherwise write `.preflight-last.json` at repo root. Schema: `{ run_id, branch, timestamp, commit_count, files_changed, verdict, steps: { secret_scan: { verdict, findings[] }, review: { verdict, blocker, critical_count, summary }, breaking_change: { verdict, findings[] }, docu: { self_healed[], remaining[] }, pr_prep: { findings[] } } }`. The PR summary comment (written by `pr-prep` or the broader PR creation flow) references this file | Provides an audit trail; the human reviewer can read exactly what the agent checked and what it fixed | Only if no prd_path and root write is also unavailable | P1 |

---

## Verdict semantics (defined once, used everywhere)

| Verdict | Meaning | Pipeline effect |
|---|---|---|
| `BLOCK` | A hard-block finding was emitted by secret-scan, eng --review, or breaking-change | Exit non-zero. Do not create PR. Agent must fix and re-run preflight |
| `WARN` | Only soft warnings remain (docu, pr-prep). No hard blocks | Exit zero. Pipeline continues to `gh pr create`. Warnings appear in PR summary |
| `PASS` | All steps clean | Exit zero. Pipeline continues silently |

## Pipeline position and constraints

- Preflight runs **after** `eng --build` and **before** `gh pr create`
- Preflight does **not** run on `main` or a branch with no commits ahead of main
- Preflight does **not** replace CI — it is the agent's own pre-ship check, not the authoritative merge gate
- Preflight does **not** prompt the user interactively during the run — it is fully agentized
- Preflight does **not** modify source code — only doc files (via docu self-heal) and the preflight artifact

## Parked — sub-skills to build separately

Each sub-skill below needs its own `/improve` plan before it can be built:

- `secret-scan` — detect secrets/credentials in a diff (gitleaks wrapper or LLM-based scan)
- `breaking-change` — detect API/interface breaks from a diff
- `pr-prep` — validate branch hygiene, commit messages, PR description template

`docu` is already planned under 11-docu. `eng --review` is planned under 7.3-eng-review.
