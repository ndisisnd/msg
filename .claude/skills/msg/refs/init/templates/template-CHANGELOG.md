---
name: CHANGELOG Template
description: Template for project changelog — written and maintained by the kermit commit-gate hook
type: reference
---

# Changelog

All notable changes to this project are documented here.
This file is maintained via `/kermit` — the commit-gate hook (`.claude/scripts/changelog-gate.py`) blocks `git commit`/`git push` until the staged diff is summarized here. Do not edit manually outside that flow.

Format: one entry per change, grouped by release, most recent first.
Each entry: `- <type>(<scope>): <what changed and why it matters>`

Types: `feat` · `fix` · `refactor` · `docs` · `chore` · `perf` · `security`

---

## [Unreleased]

<!-- The kermit commit-gate hook appends entries here before each commit. -->
