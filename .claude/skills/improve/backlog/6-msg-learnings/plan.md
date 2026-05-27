# Improvement Plan — 6-msg-learnings

**Skill:** msg (learnings sub-command)
**Change type:** New capability
**Depends on:** plan 3-msg-root-skill (root skill + menu must exist)

## Problem

Feedback and project memories accumulate in the memory directory across sessions but are never surfaced unless Claude reads them implicitly. Users have no way to review what has been learned about their preferences, past incidents, or project context — making it impossible to audit, correct, or build on that knowledge.

## Proposed changes

| # | What | How | Why necessary | Why ignorable | Rank |
|---|------|-----|---------------|---------------|------|
| 1 | Add learnings to `/msg` menu | Extend the root skill menu to include "Learnings — review accumulated memory". When selected, run the learnings report inline. | The root menu is the only entry point. | Not ignorable — learnings is inaccessible without menu integration. | P1 |
| 2 | Read memory directory and filter by type | Read all `.md` files in the project memory directory (`~/.claude/projects/.../memory/`). Parse frontmatter for `type: feedback` and `type: project` entries. | These two types contain the most actionable and durable learnings. | `type: user` and `type: reference` entries could also be included — deferrable to a later plan. | P1 |
| 3 | Emit numbered learnings list sorted by recency | Present each entry as a numbered item: `N. [type] <name>: <body snippet (first 80 chars)>`. Sort by file mtime, most recent first. | Recency ordering surfaces the most current context first. | Could sort alphabetically — lower value for review purposes. | P2 |
| 4 | Graceful degradation when memory dir is empty | If no memory files exist or the directory is absent, emit "No learnings recorded yet." | Users who haven't accumulated memory should see a clean message, not an error. | Not ignorable — a hard error here breaks the session. | P1 |

---

## Design notes

- Memory directory path: resolve from the project working directory slug (same pattern as auto-memory system).
- Snippet truncation: cut at 80 chars, append `…` if truncated.
- Type label in brackets: `[feedback]` or `[project]`.
- Do not emit `type: user` or `type: reference` entries in v1 — keep the list focused on actionable learnings.
