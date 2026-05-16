---
name: msg-commit
description: >
  Read the staged git diff or the last unpublished commit, generate a Conventional Commits message, emit it, then ask once whether to run git commit on behalf of the user. Invoke with /commit-this.
model: claude-haiku-4-5-20251001
allowed_tools:
  - Bash
  - Read
  - AskUserQuestion
---

## Usage

**Invoke**: `/msg-commit`

- Slash command `/msg-commit`
- Natural-language: "commit message", "write a commit", "what should I commit", "summarise these changes as a commit"

## Step-by-step protocol

Do not narrate steps or emit step numbers. Output only the three progress lines shown below at the exact moments specified.

**Step 1 — Determine input**

Output exactly: `Checking git diff...`

Run both commands via Bash:
1. `git diff --staged --name-only` → produces `file_list` (all staged files)
2. `git diff --staged` → produces `change_source` (full diff content)

If `file_list` is empty, print `No diffs found. If you have made changes remember to stage them first!` and stop.

**Step 2 — Select type**

Output exactly: `Creating message...`

From `change_source`, choose exactly one type from this list — no others are valid:

`feat` `fix` `chore` `perf` `refactor` `docs` `test` `build` `ci` `style` `revert`

Produce: `type`.

**Step 3 — Infer scope**

Derive an optional scope from the primary changed directory or module (e.g. `auth`, `api`, `db`). Omit scope if the change spans unrelated modules or the directory name adds no signal. Produce: `scope` (string or empty).

**Step 4 — Write subject**

Read `refs/protocol.md` for subject rules. Compose `type(scope?): description` covering ALL files in `file_list` — do not anchor on the first changed file only. Produce: `subject`.

**Step 5 — Check for breaking change**

If `change_source` removes or renames a public interface, adds a required parameter, or breaks backwards compatibility: produce `body = "BREAKING CHANGE: <one-line detail>"`. Otherwise `body` is empty.

**Step 6 — Emit**

Output exactly: `Your commit message`

ALWAYS emit the commit command in a fenced code block immediately after the progress line. Never skip or merge this step with Step 7.

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

Call `AskUserQuestion` with exactly three options:

| Option | Label | Action |
|--------|-------|--------|
| 1 | End session | Stop. |
| 2 | Run git commit | Execute the exact command from Step 6 via Bash. Print the command output. |
| 3 | Commit & push | Execute git commit then `git push` via Bash. Print both outputs. |
