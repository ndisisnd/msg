---
name: AGENTS Template
description: Template for AGENTS.md — the project memory file OpenAI Codex reads before every task, emitted beside CLAUDE.md
type: reference
---

# AGENTS Template

The skill writes AGENTS.md from this body, substituting `{{project_name}}` from Step 2.

## Why this is a pointer and not a copy (open item O4, resolved)

Claude Code reads `CLAUDE.md`; Codex reads `AGENTS.md`. Both files describe the same
project, so the only real question is which of three shapes to emit. All three were
considered and two were rejected:

- **Full copy** — rejected. Two files holding the same instructions drift the first
  time anyone edits one of them, and a stale memory file fails silently: the agent
  builds against conventions that were revised months ago and nothing errors. Codex
  also truncates an oversized project doc rather than refusing it (`project_doc_max_bytes`,
  32 KiB by default), so a project whose `CLAUDE.md` grows past the cap would get a
  copy cut off mid-instruction with no warning.
- **Symlink `AGENTS.md` → `CLAUDE.md`** — rejected. It solves drift, but a committed
  symlink materialises as a plain text file on Windows checkouts without developer
  mode, and any tool that appends to `AGENTS.md` silently writes into `CLAUDE.md`
  instead. It also leaves nowhere to put the Codex-leg notes below.
- **Pointer** — chosen. A short real file that names `CLAUDE.md` as the single source
  and tells the agent to read it now. One extra file read per session buys a memory
  file that cannot drift, cannot be truncated, works on every platform, and still has
  room for the handful of facts that are genuinely Codex-only.

The trade-off is stated in the emitted file itself, so a developer opening `AGENTS.md`
understands within one line why it is nearly empty.

## Template body

```markdown
# {{project_name}} — Codex Instructions

**Read `CLAUDE.md` at the repo root now.** It is this project's single memory file:
stack, conventions, file map, and how to work here. Everything below is only the part
that differs when the harness is OpenAI Codex rather than Claude Code.

This file is a pointer, not a copy. The project's instructions are maintained in one
place so the two harnesses cannot drift apart — do not duplicate `CLAUDE.md`'s content
here. Codex-only notes belong here; anything true of both harnesses belongs in
`CLAUDE.md`.

## Running msg skills under Codex

- Invoke a skill by typing `$name` (for example `$intake`, `$plan-pm`, `$eng`), or pick
  it from `/skills`. The `/name` form in `CLAUDE.md` is Claude Code syntax.
- msg skills never activate on their own under Codex. Each one ships
  `policy.allow_implicit_invocation: false`, because these are explicit commands with
  real consequences — a PRD rewritten, a branch merged, a deploy run.
- Skills resolve from `~/.agents/skills/`. If `$msg` is not found, msg was installed
  for Claude Code only; re-run its installer with `--codex`.
- Every other Claude-shaped instruction you will meet inside a msg protocol — tool
  names, spawn syntax, the Claude-only environment variables — has a Codex binding in
  `~/.agents/skills/shared/refs/harness-map.md`. Read that map before following a
  protocol, not after something fails.

## The commit gate needs your trust

`.codex/hooks.json` wires msg's CHANGELOG gate: it blocks `git commit` until the staged
change is summarised in `CHANGELOG.md`.

Codex trust-gates project hooks. Until you approve this project's `.codex/` layer, the
hook **does not run and does not warn** — a silently untrusted gate is a silently open
gate. Approve it when Codex prompts, and approve it again after anyone edits
`.codex/hooks.json`, since trust is granted per content hash.

The hook resolves the gate script locally first (`<repo>/.claude/scripts/changelog-gate.py`),
then falls back to the installed copy at `$HOME/.claude/scripts/changelog-gate.py`. If
neither exists it exits quietly rather than blocking every command — so "no gate
installed" and "gate untrusted" look the same from the outside. If the gate matters to
your release flow, verify it is live rather than assuming.
```

## Notes

- One substitution only (`{{project_name}}`). Nothing here is stack-specific, because
  stack facts live in `CLAUDE.md` by design.
- Skipped, never overwritten, if `AGENTS.md` already exists — a repo that already had
  one keeps its own.
