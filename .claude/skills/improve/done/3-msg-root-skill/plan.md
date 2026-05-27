# Improvement Plan — 3-msg-root-skill

**Skill:** msg (new root skill)
**Change type:** New capability

## Problem

There is no entry point for the msg project. A new user has no way to discover what msg can do or navigate to the right skill. Every skill is siloed — users must already know the command name to use it.

## Proposed changes

| # | What | How | Why necessary | Why ignorable | Rank |
|---|------|-----|---------------|---------------|------|
| 1 | Create `/msg` root skill whose menu IS the skills directory | Write `SKILL.md` at `.claude/skills/msg/`. On every invocation, enumerate `.claude/skills/*/SKILL.md` (excluding `improve/`, `refs/`, hidden dirs), extract a ≤30-character description per skill, and present all skills as options in a single `AskUserQuestion` (single-select, no free text). The user picks one skill; the root skill emits the invoke command for the selection and stops. No argument shortcuts bypass the menu. | The menu doubles as the skills index — no separate discovery step needed. Without it, users must already know a skill's name before using it. | Not ignorable — this is the primary deliverable. | P1 |
| 2 | Extract ≤30-char description from each SKILL.md | For each skill, read `SKILL.md` and use: frontmatter `description:` field if ≤30 chars; otherwise the first non-heading body line, truncated to 30 chars. | AskUserQuestion option labels must be short enough to read at a glance. | Not ignorable — without descriptions the menu options are name-only and non-informative. | P1 |
| 3 | Graceful degradation for missing/malformed SKILL.md | If a skill directory has no `SKILL.md` or no extractable description, use `[no description]` as the option label. Include the skill in the menu regardless. | In-progress skills should still appear rather than silently drop from the menu. | Not ignorable — a hard error here breaks the entire menu. | P1 |

---

## Design notes

- **Menu-first invariant:** every invocation of `/msg` presents the `AskUserQuestion` menu. No argument bypasses it.
- The menu options are the skills themselves — there is no separate "Skills" option. Health, insights, and learnings (plans 4–6) are skills that appear in the menu like any other.
- Single selection only. No multi-select, no free-text input.
- After selection, emit exactly: the skill name and its invoke command (e.g. "`/plan-em` — Engineering plan generator"). Nothing else.
- Skills are listed alphabetically by directory name.

## Out of scope (see sibling plans)

- Health check logic → plan 4-msg-health
- Insights report → plan 5-msg-insights
- Learnings report → plan 6-msg-learnings
- ~~Plan 7-msg-skills is folded into this plan.~~
