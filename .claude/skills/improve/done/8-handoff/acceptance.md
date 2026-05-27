# Acceptance Criteria — 8-session-handoff

1. A file exists at `.claude/skills/handoff/SKILL.md` with a valid skill header, trigger phrases including "handoff" and "/handoff", and a numbered protocol section.
2. Invoking `/handoff` in a repo with git changes produces a numbered file at `handoff/<n>.md` (creating the `handoff/` directory if absent) without prompting the user for any input.
3. Each successive invocation writes the next available number (e.g. `handoff/1.md`, `handoff/2.md`) — it never overwrites an existing file.
4. The handoff file contains exactly five sections in order: File Refs, Worked On, Affected, Not Affected Yet, Next Steps.
5. The handoff file is ≤50 lines long (including blank lines and headers).
6. The **File Refs** section lists each file from `rtk git status --short` with its status code (M/A/D/?).
7. The **Worked On** section contains ≤5 bullet points synthesized from recent commit messages and/or the staged diff (derived via `rtk git log -5 --oneline`).
8. The **Affected** section groups changed files by module or directory — not a raw file list.
9. The **Not Affected Yet** section includes items from OPEN-QUESTIONS.md (if present), inline TODO/FIXME comments in changed files, and untracked/unstaged files — or emits "none identified" if nothing is found.
10. The **Next Steps** section contains ≤5 action bullets derived from the Not Affected Yet list.
11. After writing, the skill emits a clickable markdown link `[handoff/<n>.md](handoff/<n>.md)` to the user.
12. The skill contains no prose paragraphs in its output — bullet points only, terse phrasing.
13. Running the skill on a repo with no git changes (clean working tree) still produces a valid handoff file (sections may be empty or say "none").
14. All git introspection uses `rtk`-prefixed commands (`rtk git status`, `rtk git log`, `rtk git diff`).
