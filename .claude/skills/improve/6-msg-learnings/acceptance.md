# Acceptance Criteria — 6-msg-learnings

1. Selecting "Learnings" from the `/msg` menu executes the learnings report inline without requiring a separate command.
2. The skill reads all `.md` files in the project memory directory and parses their frontmatter.
3. Only entries with `type: feedback` or `type: project` are included in the output.
4. Each entry is presented as a numbered line in the format: `N. [type] <name>: <body snippet>`.
5. Body snippets are truncated to 80 characters with `…` appended if cut.
6. Entries are sorted by file modification time, most recent first.
7. If no memory files exist or the directory is absent, the skill emits "No learnings recorded yet." and exits cleanly.
8. `type: user` and `type: reference` entries are not shown in v1 output.
