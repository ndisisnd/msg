---
name: msg-commit
description: >
  Read the staged git diff or the last unpublished commit, generate a Conventional Commits message, emit it, then ask once whether to run git commit on behalf of the user. Invoke with /commit-this.
model: claude-haiku-4-5-20251001
allowed_tools:
  - Bash
  - AskUserQuestion
---

## Usage

**Invoke**: `/msg-commit`

- Slash command `/msg-commit`
- Natural-language: "commit message", "write a commit", "what should I commit", "summarise these changes as a commit"

## Step-by-step protocol

**Step 1 — Determine input**

Run `git diff --staged` via Bash. If output is non-empty, use it as `change_source`. If empty, print `No diffs found, terminate commit. If you have made changes remember to run stage the changes!` and stop — do not proceed to later steps.

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
| 3 | Commit & push | Execute git commit and push automatically to branch | 