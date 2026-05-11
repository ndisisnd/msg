---
name: msg-commit
description: Generates a Conventional Commits message from staged diff, LLM change summary, or user description. Subject only; body only for breaking changes. No explanation, no emoji, no attribution. Use when the user asks for a commit message or has staged changes ready to commit.
model: claude-sonnet-4-6
allowed_tools:
  - Bash
  - AskUserQuestion
---

## Usage

**Invoke**: `/msg-commit`

- Slash command `/msg-commit`
- Natural-language: "commit message", "write a commit", "what should I commit", "summarise these changes as a commit"
- Context: after `git add`, after the LLM has made file changes

## Inputs

| Name | Format | Source |
|------|--------|--------|
| staged diff | text output of `git diff --staged` | shell, auto-run |
| change summary | prose list of changed files and what changed | LLM conversation context |
| user description | free text describing what changed | user message |

## Outputs

| Name | Format | Destination |
|------|--------|-------------|
| commit message | plain-text subject; optional breaking-change body | shown inline |
| action | copy or commit | user choice via prompt |

## Step-by-step protocol

**Step 1 — Determine input**

Run `git diff --staged` via Bash. If output is non-empty, use it as `change_source`. If empty, check the current conversation for an LLM-generated change summary and use that. If neither exists, use the user's prompt description. Produce: `change_source`.

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

Print `subject`. If `body` is non-empty, print a blank line then `body`.

**Step 7 — Ask what to do**

Ask the user:

> (1) copy message  (2) run git commit

- `1` / copy → print the commit message again in a fenced code block for easy copying. Nothing else.
- `2` / commit → run `git commit -m "<subject>"` via Bash. If `body` is non-empty, use `git commit -m "<subject>" -m "<body>"` instead. Print the command output. Nothing else.

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
