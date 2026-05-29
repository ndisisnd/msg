# Improvement Plan — 11-docu

**Skill:** docu (new skill)
**Change type:** New capability

## Problem

When code changes — endpoint versions, GraphQL fields, renamed modules, config keys — the surrounding documentation (READMEs, ARCHITECTURE.md, PRD, AHA.md) silently falls out of sync. There is currently no lightweight way to surface those stale references immediately after a diff and offer targeted inline fixes. The `docu` skill fills that gap: it reads the current diff, identifies what changed, and checks named doc files for outdated references — then shows the exact suggested edits and asks whether to apply each one.

## Proposed changes

| # | What | How | Why necessary | Why ignorable | Rank |
|---|------|-----|---------------|---------------|------|
| 1 | Create `SKILL.md` for `docu` | Write `.claude/skills/docu/SKILL.md` covering usage, protocol (steps 1–5), and constraints | Without the skill file the agent cannot be invoked via `/docu` | Never — this is the core deliverable | P0 |
| 2 | Step 1 — Resolve diff | Accept `/docu` (no args → `git diff HEAD`) or `/docu <branch\|PR>` (diff against named ref or GitHub PR number) | Lets the skill work on both local WIP and PR review flows | If user always runs on HEAD only | P0 |
| 3 | Step 2 — Discover doc files | Auto-scan for `README.md`, `docs/**/*.md`, `ARCHITECTURE.md`, `PRD*.md`, `AHA.md` at repo root and up to 2 dirs deep | User shouldn't need to specify paths; coverage should be automatic | If repo has no docs | P1 |
| 4 | Step 3 — Detect stale references | Read diff + each doc file; identify lines that reference a changed entity (endpoint path, version string, field/method name, module path, config key) | Core detection logic — without this the skill produces nothing useful | Never | P0 |
| 5 | Step 4 — Per-finding inline prompt | For each stale reference: print `[file:line]` context snippet + suggested replacement, then call `AskUserQuestion` asking "Apply this fix?" (Yes / Skip / Stop) | Gives the user control without overwhelming them; matches stated UX preference | If user prefers bulk apply; can be added later | P1 |
| 6 | Step 5 — Apply approved edits | Use `Edit` tool to apply each confirmed fix in place | No point surfacing fixes if they can't be applied | If user says "surface only" at invocation | P1 |
| 7 | Constraints in SKILL.md | Explicitly scope out: generating new documentation, auditing code quality, checking test coverage | Keeps the skill lightweight and prevents scope creep | Never | P1 |

---

## Agent spec (for /agent-build)

**Name:** `docu`

**One-sentence purpose:** After a code change, check README, ARCHITECTURE.md, PRD, and AHA.md for stale references and offer to apply targeted inline fixes.

**Trigger / invocation:**
- `/docu` — diffs against HEAD automatically
- `/docu <branch>` — diffs against a named branch
- `/docu <PR#>` — fetches the PR diff via `gh pr diff <n>`

**Tools needed:** `Bash` (git diff, gh pr diff, file discovery), `Read` (load doc files), `Edit` (apply fixes), `AskUserQuestion` (per-finding confirm)

**Protocol (5 steps):**
1. **Resolve diff** — no args → `git diff HEAD`; branch arg → `git diff <branch>`; PR# → `gh pr diff <n>`. Abort with a clear message if the diff is empty.
2. **Discover docs** — find `README.md`, `docs/**/*.md`, `ARCHITECTURE.md`, `PRD*.md`, `AHA.md` up to 2 dirs deep. Skip missing categories silently.
3. **Detect staleness** — for each doc file, identify lines referencing any entity that changed in the diff (endpoint paths, version strings, field/method/module names, config keys). Collect findings as `{ file, line, stale_text, suggested_text, reason }`.
4. **Report + confirm** — if no findings, print "✓ Docs look up to date." and exit. Otherwise, for each finding print a compact block (file:line, old → new, reason) and call `AskUserQuestion` with options: **Apply** / **Skip** / **Stop all**.
5. **Apply** — for each confirmed finding, call `Edit` to replace stale text. Print a final tally: `N applied, M skipped.`

**Constraints / out of scope:**
- Does NOT generate new documentation
- Does NOT check code quality, test coverage, or logic correctness
- Does NOT modify source code
- Skips binary files and generated files (node_modules, dist, .lock)
- Max doc files scanned: 20 (avoid runaway on huge monorepos)

**Output:** Terminal output only (no report file written). Lightweight — total output should fit in a single scrollable terminal view.
