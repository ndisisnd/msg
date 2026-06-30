---
name: docu
description: >
  After a code change, check README, devkit/ARCHITECTURE.md, the PRD, and
  devkit/AHA.md for stale references and offer to apply targeted inline fixes.
  Works on local diffs (HEAD) or a named branch or PR number.
model: claude-sonnet-4-6
allowed_tools:
  - Bash
  - Read
  - Edit
  - AskUserQuestion
---

# docu

## Usage

**Invoke**:
- `/docu` — diffs against HEAD automatically
- `/docu <branch>` — diffs against a named branch
- `/docu <PR#>` — fetches the PR diff via `gh pr diff <n>`

Natural language triggers: "check docs for stale references", "update docs after this change", "sync docs with the diff", "run docu"

**Hard refusals:**
- Does NOT modify source code files — documentation files only.
- Does NOT generate new documentation sections.
- Does NOT check code quality, test coverage, or logic correctness.

## Inputs

| Name | Source |
|------|--------|
| Diff | `git diff HEAD` (no args), `git diff <branch>` (branch arg), `gh pr diff <n>` (PR# arg) |
| Doc files | Auto-discovered (see Step 2) |

## Outputs

Terminal output only — no report file written. Total output fits in a single scrollable view for ≤5 findings.

## Out of scope

- Generating new documentation
- Auditing code quality
- Checking test coverage
- Modifying source code files
- Modifying binary files, generated files (`node_modules/`, `dist/`, `.lock` files)

## Step-by-step protocol

**Step 1/5 — Resolve diff**

Determine the diff source based on invocation args:

- **No args**: `rtk git diff HEAD`
- **Branch name** (not a number): `rtk git diff <branch>`
- **PR number** (numeric arg): `gh pr diff <n>`

If the resulting diff is empty, print:

```
✓ No changes detected — nothing to check.
```

and exit immediately.

**Step 2/5 — Discover doc files**

Search for documentation files up to 3 directory levels deep from repo root. The msg framework stores its docs under `devkit/` and PRDs at `features/prd-[n]-[feature-slug]/prd-[n]-[feature-slug].md`, so target those canonical paths first, then fall back to bare-root docs for non-msg repos. Find files matching these patterns (in priority order):

1. `README.md` (root)
2. `devkit/ARCHITECTURE.md`, `devkit/AHA.md`, `devkit/GLOSSARY.md`, `devkit/DESIGN-SYSTEM.md`, `devkit/OPEN-QUESTIONS.md`
3. `features/prd-*/prd-*.md` (lowercase, slugged PRD dirs)
4. `docs/**/*.md`
5. Bare-root `ARCHITECTURE.md` / `AHA.md` (fallback for non-msg repos)

Run:

```bash
rtk find . -maxdepth 3 -type f \
  \( -name "README.md" -o -path "*/devkit/*.md" -o -name "ARCHITECTURE.md" \
     -o -name "AHA.md" -o -path "*/features/prd-*/prd-*.md" \
     -o -path "*/docs/*.md" \) \
  ! -path "*/node_modules/*" ! -path "*/dist/*" ! -name "*.lock" \
  2>/dev/null | head -20
```

Skip files in `node_modules/`, `dist/`, and `.lock` paths silently. Cap at **20 files** total. If no doc files are found, print:

```
✓ No documentation files found — nothing to check.
```

and exit.

**Step 3/5 — Detect stale references**

For each discovered doc file:

1. Read the file with the `Read` tool.
2. Read the diff (already resolved in Step 1).
3. Identify lines in the doc file that reference an entity that **changed** in the diff. Look for:
   - **Endpoint paths** — URL paths, route strings (e.g. `/api/v1/users` → `/api/v2/users`)
   - **Version strings** — version numbers, release tags
   - **Field / method / module names** — renamed or removed identifiers
   - **Config keys** — environment variable names, config property names
   - **Module paths** — import paths, file paths referenced in docs
   - **Domain terms** (`devkit/GLOSSARY.md`) and **component / token names** (`devkit/DESIGN-SYSTEM.md`) — renamed vocabulary or UI primitives
4. For each stale reference, collect a finding:
   ```
   { file, line_number, stale_text, suggested_text, reason }
   ```
   - `stale_text`: the exact old text in the doc file
   - `suggested_text`: the replacement derived from the diff
   - `reason`: one-line explanation (e.g. "endpoint renamed from /v1 to /v2 in commit")
5. Skip false positives — only flag lines where the doc text clearly refers to the changed entity, not incidental matches.

If zero findings across all doc files, print:

```
✓ Docs look up to date.
```

and exit.

**Step 4/5 — Report and confirm per finding**

For each finding, print a compact block:

```
📄 <file>:<line_number>
  Old: <stale_text>
  New: <suggested_text>
  Why: <reason>
```

Then call `AskUserQuestion` with:

```
question: "Apply this fix?"
options:
  - Apply   — replace the stale text in the file
  - Skip    — leave this line unchanged, move to next finding
  - Stop all — halt processing remaining findings immediately
```

Track counts: `applied = 0`, `skipped = 0`.

If user selects **Stop all**, break out of the loop immediately without processing further findings.

**Step 5/5 — Apply edits and print tally**

For each finding where the user selected **Apply**:

1. Call `Edit` to replace `stale_text` with `suggested_text` in the doc file.
2. Increment `applied`.

For each **Skip**, increment `skipped`.

After all findings are processed (or after Stop all), print the final tally:

```
<N> applied, <M> skipped.
```

If Stop all was selected, note how many findings were not reached:

```
<N> applied, <M> skipped, <K> not reviewed (stopped).
```

## References

- `devkit/ARCHITECTURE.md` — may be a doc target and a source of module names
- `devkit/AHA.md` — may contain version strings or endpoint references
- `features/prd-*/prd-*.md` — slugged PRD docs, a primary drift target
- `gh pr diff` — GitHub CLI, required for `/docu <PR#>` invocation
