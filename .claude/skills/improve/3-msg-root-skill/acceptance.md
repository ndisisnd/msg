# Acceptance Criteria — 3-msg-root-skill

## Change 1: `/msg` root skill — menu as skills directory

1. A file exists at `.claude/skills/msg/SKILL.md` with valid frontmatter.
2. Invoking `/msg` (with or without any argument) always presents a single `AskUserQuestion` — no argument bypasses it.
3. The menu options are the skills themselves, one per skill directory under `.claude/skills/` (excluding `improve/`, `refs/`, hidden dirs).
4. Each option label is the skill name; each option description is ≤30 characters extracted from that skill's `SKILL.md`.
5. The menu is single-select; no multi-select and no free-text input is offered.
6. If a skill's description cannot be extracted, the option shows `[no description]` — the skill still appears in the menu.
7. Skills are listed alphabetically by directory name.
8. After selection, the skill emits exactly: the skill name and its invoke command. Nothing else.
9. No separate "Skills" menu option exists — the menu itself is the index.

## Change 2: description extraction

10. The description is taken from the frontmatter `description:` field if it is ≤30 characters.
11. If the frontmatter description exceeds 30 characters or is absent, the first non-heading, non-empty body line is used, truncated to 30 characters.
12. Truncated descriptions do not append `…` or any suffix — they are cut at exactly 30 characters.

## Change 3: graceful degradation

13. A skill directory with no `SKILL.md` does not cause an error — it appears in the menu with `[no description]`.
14. A skill directory with a `SKILL.md` that has no extractable description also appears with `[no description]`.
