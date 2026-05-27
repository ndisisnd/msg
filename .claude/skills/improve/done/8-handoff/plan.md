# Improvement Plan — 8-session-handoff

**Skill:** handoff
**Change type:** New capability

## Problem

Any session or agent may need to hand off mid-flight with no structured summary. The incoming agent must re-derive context from git log, open files, and conversation history — wasting tokens and risking missed context. There is no lightweight, agent-readable artifact that captures (1) which files matter, (2) what changed, (3) what's affected, and (4) what's left undone.

## Proposed changes

| # | What | How | Why necessary | Why ignorable | Rank |
|---|------|-----|---------------|---------------|------|
| 1 | Create `handoff` skill SKILL.md | New file at `.claude/skills/handoff/SKILL.md` with trigger phrases ("handoff", "/handoff", "compact session") and a 5-step protocol | Without the skill file, no agent can invoke it | N/A — this is the core deliverable | P1 |
| 2 | Auto-derive **File refs** | Run `rtk git status --short` + `rtk git diff --stat HEAD` to list touched files with their status (M/A/D/?) | File refs are the primary navigation aid for the incoming session or agent | Only if working tree is clean | P1 |
| 3 | Auto-derive **What was worked on** | Read last 5 commit messages (`rtk git log -5 --oneline`) + staged diff summary; synthesize a ≤5-bullet summary | Any incoming session needs a quick narrative without reading the full diff | Never — this is the "story" section | P1 |
| 4 | Auto-derive **What has been affected** | Cross-reference `rtk git diff --name-only HEAD` with CLAUDE.md / ARCHITECTURE.md module map; list affected modules/layers | Module-level impact is more useful than raw file list | If CLAUDE.md/ARCHITECTURE.md absent, fall back to directory grouping | P2 |
| 5 | Auto-derive **What was not affected yet** | Read OPEN-QUESTIONS.md, any `TODO`/`FIXME` comments in changed files, and unstaged/untracked files; emit as a short list | Critical for the incoming session or agent to know what's still open | If nothing found, emit "none identified" | P2 |
| 6 | Generate **Recommended next steps** | Derive from the "not affected" list + any failing tests (`rtk git stash` detection, test output if present); emit ≤5 action bullets | Saves the incoming session or agent from having to re-read the handoff to know where to start | Can omit if user says no — user said yes | P2 |
| 7 | Write output to numbered file in `handoff/` folder | Use the Write tool; create `handoff/` dir if absent; find the next available number (1, 2, 3…) and write `handoff/<n>.md`; enforce ≤50 lines total | Output must be agent-consumable without truncation; numbered files preserve handoff history | N/A | P1 |
| 8 | Emit file link to user | After writing, emit `[handoff/<n>.md](handoff/<n>.md)` as a markdown link | Confirms where to find the output | N/A | P3 |

---

## Format contract (enforced by the skill)

```
# HANDOFF — <date> <time>

## File Refs
- M path/to/file.ts
- A path/to/new.ts

## Worked On
- <bullet 1>
- …

## Affected
- <module/layer>: <files>

## Not Affected Yet
- <open item>

## Next Steps
- <action>
```

Max 50 lines. No prose paragraphs. No fluff.

---

## Exemplar

**Skill:** handoff
**Change type:** New capability

### Problem

Mid-session handoffs produce walls of context that the incoming session or agent can't parse efficiently. A structured, auto-derived artifact fixes this with zero manual effort from the outgoing session.

### Proposed changes

*(see table above)*
