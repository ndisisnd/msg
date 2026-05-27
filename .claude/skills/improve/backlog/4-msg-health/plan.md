# Improvement Plan — 4-msg-health

**Skill:** msg (health sub-command)
**Change type:** New capability
**Depends on:** plan 3-msg-root-skill (root skill + menu must exist)

## Problem

Users have no way to verify that their msg setup is intact. Skills can be missing, hooks can go unregistered, and config files can drift — all silently. A health check surfaces these gaps before they cause confusing failures mid-task.

## Proposed changes

| # | What | How | Why necessary | Why ignorable | Rank |
|---|------|-----|---------------|---------------|------|
| 1 | Add health check to `/msg` menu | Extend the root skill's `AskUserQuestion` menu to include "Health — check skills, hooks, and config". When selected, execute the health check inline. | The root menu is the only entry point; health must be reachable from it. | Not ignorable — health is inaccessible without menu integration. | P1 |
| 2 | Scan `.claude/skills/*/SKILL.md` | For each directory under `.claude/skills/`, verify `SKILL.md` exists. Emit `[OK]` or `[FAIL]` per skill. | Missing SKILL.md means a skill is broken or incomplete. | Could be scoped to a subset if skill count is large. | P1 |
| 3 | Check `.claude/settings.json` for hook registrations | Read `.claude/settings.json`, confirm at least one `hooks` entry exists. Emit `[OK]` or `[WARN]` (not FAIL — hooks are optional). | Hooks drive automation; a missing hooks block means automated behaviours are silently absent. | Emit WARN not FAIL — some projects intentionally have no hooks. | P1 |
| 4 | Verify `CLAUDE.md` exists in project root | Check for `.claude/CLAUDE.md` or root-level `CLAUDE.md`. Emit `[OK]` or `[FAIL]`. | CLAUDE.md is the project's instruction source; missing it means Claude ignores all custom guidance. | Not ignorable in the msg context. | P2 |
| 5 | Emit summary line | After all checks, emit a final summary: "Health: N checks passed, M warnings, K failures." | Gives users a quick at-a-glance verdict without reading every line. | Could be omitted if the checklist is short, but adds clarity. | P2 |

---

## Design notes

- All checks emit one line each: `[OK] <description>`, `[WARN] <description>`, or `[FAIL] <description>`.
- Checks run sequentially; a failed check does not abort subsequent checks.
- Output should be readable in a terminal without colour — bracket prefixes carry all semantic meaning.
