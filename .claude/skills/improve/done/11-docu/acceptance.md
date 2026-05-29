# Acceptance Criteria — 11-docu

1. `.claude/skills/docu/SKILL.md` exists and is non-empty.
2. Running `/docu` with no arguments reads `git diff HEAD`; if the diff is empty the skill exits with a clear "nothing to check" message.
3. Running `/docu <branch>` diffs against the named branch; running `/docu <PR#>` fetches the diff via `gh pr diff <n>`.
4. The skill auto-discovers `README.md`, `docs/**/*.md`, `ARCHITECTURE.md`, `PRD*.md`, and `AHA.md` without the user specifying paths.
5. Discovery is capped at 20 doc files; files in `node_modules/`, `dist/`, and `.lock` paths are skipped.
6. When a doc file references an entity that changed in the diff (endpoint path, version string, field/method/module name, config key), a finding is emitted containing: file path, line number, stale text, suggested replacement, and a one-line reason.
7. When no findings are detected, the skill prints "✓ Docs look up to date." and exits — no further prompts.
8. For each finding, `AskUserQuestion` is called with three options: Apply / Skip / Stop all.
9. Selecting "Apply" causes `Edit` to replace the stale text in the doc file; the file is modified in place.
10. Selecting "Skip" moves to the next finding without modifying the file.
11. Selecting "Stop all" halts processing of remaining findings immediately.
12. After all findings are processed (or stopped), the skill prints a tally: `N applied, M skipped.`
13. The skill does not modify any source code files — only documentation files.
14. The skill does not generate new documentation sections; it only updates existing references.
15. SKILL.md explicitly lists out-of-scope items: new doc generation, code quality, test coverage, source code modification.
16. Total terminal output fits in a single scrollable view for a typical diff with ≤5 findings.
