# Acceptance Criteria — 8-session-handoff

1. A file exists at `.claude/skills/handoff/SKILL.md` with a valid skill header, trigger phrases including "handoff" and "/handoff", and a numbered protocol section.
2. Invoking `/handoff` in a repo with git changes produces a `HANDOFF.md` at the repo root without prompting the user for any input.
3. `HANDOFF.md` contains exactly five sections in order: File Refs, Worked On, Affected, Not Affected Yet, Next Steps.
4. `HANDOFF.md` is ≤50 lines long (including blank lines and headers).
5. The **File Refs** section lists each file from `git status --short` with its status code (M/A/D/?).
6. The **Worked On** section contains ≤5 bullet points synthesized from recent commit messages and/or the staged diff.
7. The **Affected** section groups changed files by module or directory — not a raw file list.
8. The **Not Affected Yet** section includes items from OPEN-QUESTIONS.md (if present), inline TODO/FIXME comments in changed files, and untracked/unstaged files — or emits "none identified" if nothing is found.
9. The **Next Steps** section contains ≤5 action bullets derived from the Not Affected Yet list.
10. After writing, the skill emits a clickable markdown link `[HANDOFF.md](HANDOFF.md)` to the user.
11. The skill contains no prose paragraphs in its output — bullet points only, terse phrasing.
12. Running the skill on a repo with no git changes (clean working tree) still produces a valid `HANDOFF.md` (sections may be empty or say "none").
