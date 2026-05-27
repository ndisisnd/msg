# Acceptance Criteria — 4-msg-health

1. Selecting "Health" from the `/msg` menu executes the health check inline without requiring a separate command.
2. The health check scans `.claude/skills/*/SKILL.md` and emits one `[OK]` or `[FAIL]` line per skill directory found.
3. The health check reads `.claude/settings.json` and emits `[OK]` if a `hooks` key exists, `[WARN]` if it does not.
4. The health check emits `[OK]` if `CLAUDE.md` exists at the project root, `[FAIL]` if it does not.
5. Every output line is prefixed with exactly one of: `[OK]`, `[WARN]`, `[FAIL]` — no untagged lines.
6. A failing check does not stop subsequent checks from running.
7. The final line of output is a summary: "Health: N checks passed, M warnings, K failures."
