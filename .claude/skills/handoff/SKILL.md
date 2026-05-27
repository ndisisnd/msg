---
name: handoff
description: >
  Produces a numbered, agent-readable handoff artifact at handoff/<n>.md.
  Auto-derives file refs, worked-on summary, affected modules, open items,
  and next steps from git state and project files. Zero user input required.
model: claude-sonnet-4-6
allowed_tools:
  - Bash
  - Read
  - Write
---

# handoff

## Usage

**Invoke**: `/handoff` — no arguments needed.

- Slash command `/handoff`
- Natural language: "handoff", "create a handoff", "compact session", "write a handoff", "summarise for the next session"
- Context: any repo, any point in a session — outgoing agent or user wants a structured summary for the next session

**Hard refusals:**
- None. Works on clean or dirty trees.

## Inputs

All inputs are derived automatically — no user prompting.

| Name | Source |
|------|--------|
| Unstaged / staged file list | `rtk git status --short` |
| Diff stat | `rtk git diff --stat HEAD` |
| Recent commits | `rtk git log -5 --oneline` |
| Changed file names | `rtk git diff --name-only HEAD` |
| Module map | CLAUDE.md and/or ARCHITECTURE.md (optional) |
| Open items | OPEN-QUESTIONS.md (optional) |
| Inline TODOs | grep TODO/FIXME in changed files (optional) |

## Outputs

| Name | Format | Destination |
|------|--------|-------------|
| Handoff file | Markdown ≤50 lines | `handoff/<n>.md` (next available number) |
| File link | Inline markdown | Emitted to user after write |

## Format contract

```
# HANDOFF — <YYYY-MM-DD HH:MM>

## File Refs
- <status> <path>

## Worked On
- <bullet>

## Affected
- <module/dir>: <files>

## Not Affected Yet
- <item>

## Next Steps
- <action>
```

Max 50 lines total. Bullet points only. No prose paragraphs. No fluff.

## Content rules

**No duplication** — the handoff references work, it does not reproduce it. Do not copy-paste commit messages verbatim, paste diff hunks, quote PRD sections, or repeat code. Every bullet is a pointer, not a copy.

**Redact sensitive data** — before writing, scan each derived bullet for secrets, credentials, PII, internal URLs, API keys, tokens, or personally identifying names. Replace any found value with `[REDACTED]`. If an entire bullet is sensitive, omit it and append `- … (1 item redacted)` to that section.

## Step-by-step protocol

**Step 1/5 — Gather git state**

Run all three commands:

```bash
rtk git status --short
rtk git diff --stat HEAD
rtk git log -5 --oneline
```

Hold output in context. If all three return empty/nothing, the working tree is clean — sections will be empty or say "none".

Also run:

```bash
rtk git diff --name-only HEAD
```

Hold the changed file list for Step 3.

**Step 2/5 — Resolve handoff number and output path**

Check whether the `handoff/` directory exists and what numbered files are already present:

```bash
rtk ls handoff/ 2>/dev/null || echo "EMPTY"
```

If the directory is absent or empty, the next number is `1`. Otherwise parse the existing filenames (`1.md`, `2.md`, …) and take `max + 1`.

Output path: `handoff/<n>.md`

**Step 3/5 — Derive sections**

**File Refs** — from `git status --short` output: one line per file, preserving the two-character status code (M, A, D, ?, etc.). If clean, emit `- none`.

**Worked On** — synthesise ≤5 bullets from `git log -5 --oneline` and `git diff --stat HEAD`. Each bullet names *what* was done, not *how*. If nothing, emit `- none`.

**Affected** — group the files from `git diff --name-only HEAD` by top-level directory or module. Cross-reference CLAUDE.md / ARCHITECTURE.md module map if present; otherwise use directory names. Format: `- <module>: file1, file2`. If clean, emit `- none`.

**Not Affected Yet** — collect items from:
1. OPEN-QUESTIONS.md (if it exists): extract unchecked items
2. `grep -rn "TODO\|FIXME"` in changed files (if any): emit as `- TODO: <file>:<line> <text>`
3. Untracked files from `git status --short` (lines starting with `??`): list them

If nothing found across all three sources, emit `- none identified`.

**Next Steps** — derive ≤5 action bullets from the Not Affected Yet list. If Not Affected Yet is "none identified", derive from Worked On context (e.g. "verify X", "run tests", "review open PR"). Each bullet starts with an imperative verb.

**Step 4/5 — Write the file**

1. Create `handoff/` if absent (the Write tool creates parent dirs automatically — but note the path for the link).
2. Assemble the markdown using the Format contract above. Include a timestamp header: `# HANDOFF — <today's date> <current time>`.
3. Count lines. If over 50, trim the longest section (usually File Refs or Not Affected Yet) by truncating to 5 items and appending `- … (<n> more)`.
4. Write the file using the Write tool at `handoff/<n>.md`.

**Step 5/5 — Emit confirmation**

Emit exactly:

```
[handoff/<n>.md](handoff/<n>.md)
```

as a markdown link. No other prose.

## References

- CLAUDE.md — module map (optional; used in Step 3 Affected)
- ARCHITECTURE.md — layer/module definitions (optional; used in Step 3 Affected)
- OPEN-QUESTIONS.md — open items feed (optional; used in Step 3 Not Affected Yet)
