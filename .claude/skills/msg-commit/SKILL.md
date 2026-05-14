---
name: msg-commit
description: >
  Generates a Conventional Commits message from staged git diff. Invoke
  whenever the user asks for a commit message, says "commit this", "write a
  commit", "what should I commit", "summarise these changes", or has staged
  changes ready. Runs `git diff --staged`, derives type/scope/subject, emits
  a fenced `git commit` command, then asks the user to copy or run it.
model: claude-haiku-4-5-20251001
allowed_tools:
  - Bash
  - AskUserQuestion
---

## Usage

**Invoke**: `/msg-commit`

- Slash command `/msg-commit`
- Natural-language: "commit message", "write a commit", "what should I commit", "summarise these changes as a commit"

## Inputs

| Name | Format | Source |
|------|--------|--------|
| staged diff | text output of `git diff --staged` | shell, auto-run |

## Outputs

| Name | Format | Destination |
|------|--------|-------------|
| commit message | plain-text subject; optional breaking-change body | shown inline |
| action | copy or commit | user choice via prompt |

## Step-by-step protocol

**Step 1 — Determine input**

Run `.claude/scripts/check-staged.sh` via Bash.

- Exit 0 → use stdout as `change_source` and continue.
- Exit non-zero → print the stderr message verbatim and stop. Do not proceed to later steps.

**Step 2 — Select type**

From `change_source`, choose exactly one type from this list — no others are valid:

`feat` `fix` `chore` `perf` `refactor` `docs` `test` `build` `ci` `style` `revert`

Produce: `type`.

**Step 3 — Infer scope**

Derive an optional scope from the primary changed directory or module (e.g. `auth`, `api`, `db`). Omit scope if the change spans unrelated modules or the directory name adds no signal. Produce: `scope` (string or empty).

**Step 4 — Write subject**

Compose `type(scope?): description`. Apply all rules:

- Imperative mood (`add`, `fix`, `remove` — not `added`, `fixes`, `removing`)
- Lowercase first word of description
- No trailing period
- Prefer ≤50 chars total; hard cap 72
- No emoji, no AI attribution, no co-author lines

Produce: `subject`.

**Step 5 — Check for breaking change**

If `change_source` removes or renames a public interface, adds a required parameter, or breaks backwards compatibility: produce `body = "BREAKING CHANGE: <one-line detail>"`. Otherwise `body` is empty.

**Step 6 — Emit**

ALWAYS emit the commit command in a fenced code block before doing anything else. Never skip or merge this step with Step 7.

- No breaking change:
  ```
  git commit -m "<subject>"
  ```
- With breaking change:
  ```
  git commit -m "<subject>" -m "<body>"
  ```

The fenced block MUST appear in your output before Step 7 runs.

**Step 7 — Ask what to do**

Call `AskUserQuestion` with exactly two options:

| Option | Label | Action |
|--------|-------|--------|
| 1 | End session | Stop. |
| 2 | Run git commit | Execute the exact command from Step 6 via Bash. Print the command output. |

## Examples

```
feat(auth): add OAuth2 login support
fix(api): handle null response from /users endpoint
chore: update dependencies
refactor(db): extract query builder to separate module
perf(cache): replace Redis with in-memory LRU
docs: add API authentication guide
test(auth): add unit tests for token refresh logic
build: upgrade webpack to v5
ci: add lint step to GitHub Actions
style(nav): fix button alignment
revert: "feat(auth): add OAuth2 login support"
```

Breaking change:

```
refactor(api): rename user_id to userId

BREAKING CHANGE: user_id field renamed to userId across all endpoints
```

Scope omitted (cross-cutting change):

```
chore: update all npm dependencies
refactor: migrate string utils to shared module
```
