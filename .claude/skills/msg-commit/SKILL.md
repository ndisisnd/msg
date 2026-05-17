---
name: msg-commit
description: >
  Generate a Conventional Commits message from staged git changes and offer to run git commit.
  TRIGGER when: user runs git add or stages changes, user asks to commit, user asks for a commit message.
  Invoke with /msg-commit.
model: claude-haiku-4-5-20251001
allowed_tools:
  - Bash
  - AskUserQuestion
---

## Usage

**Invoke**: `/msg-commit`

## Subject rules

Compose `type(scope?): description` applying all rules:

- Imperative mood (`add`, `fix`, `remove` — not `added`, `fixes`, `removing`)
- Lowercase first word of description
- No trailing period
- Prefer ≤50 chars total; hard cap 72
- No emoji, no AI attribution, no co-author lines

Choose exactly one type — no others are valid:

`feat` `fix` `chore` `perf` `refactor` `docs` `test` `build` `ci` `style` `revert`

## Body rules

Add a body only for:

- Non-obvious why (motivation isn't clear from the subject alone)
- Breaking changes → `BREAKING CHANGE: <detail>`
- Migration notes
- Linked issues → `Closes #123`

Wrap every body line at 72 chars. Separate subject from body with a blank line.

## Exemplars

**No body — correct:**
```
fix(auth): handle expired token on silent refresh
```

**No body — incorrect** (why is non-obvious; body required):
```
fix(cache): add 5-second delay before retry
```
↑ Missing why: should explain the underlying cause (e.g. rate-limit window, race condition).

**With body — correct:**
```
refactor(api): rename user_id to userId

BREAKING CHANGE: user_id field renamed to userId across all endpoints.
Update all API consumers before deploying.
```

## Protocol

Do not narrate steps or emit step numbers. Output only the three progress lines shown below at the exact moments specified.

**Step 1 — Determine input**

Output exactly: `Checking git diff...`

Run both commands via Bash:
1. `git diff --staged --name-only` → produces `file_list` (all staged files)
2. `git diff --staged` → produces `change_source` (full diff content)

If `file_list` is empty, print `No diffs found. If you have made changes remember to stage them first!` and stop.

**Step 2 — Select type**

Output exactly: `Creating message...`

From `change_source`, choose exactly one type from the Subject rules above. Produce: `type`.

**Step 3 — Infer scope**

Derive an optional scope from the primary changed directory or module (e.g. `auth`, `api`, `db`). Omit scope if the change spans unrelated modules or the directory name adds no signal. Produce: `scope` (string or empty).

**Step 4 — Write subject**

Apply the Subject rules above. Compose `type(scope?): description` covering ALL files in `file_list` — do not anchor on the first changed file only. Produce: `subject`.

**Step 5 — Decide on body**

Apply the Body rules above. If any condition is met, compose a body following the exemplars. Otherwise `body` is empty.

**Step 6 — Emit**

Output exactly: `Your commit message`

ALWAYS emit the commit command in a fenced code block immediately after the progress line. Never skip or merge this step with Step 7.

- No body:
  ```
  git commit -m "<subject>"
  ```
- With body:
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
