---
name: msg --version
description: The /msg --version protocol — read the install-time stamp and emit the installed release in one line
type: reference
---

# Protocol: --version

The one question this answers: **which release of msg is actually installed on this machine?**
It exists because `~/.claude/skills` is a plain copy, not a git checkout — after an install or a
reinstall there is otherwise no way to tell a fresh copy from a stale one, in this repo or any other.

**Step 1 — Read the stamp**

Run exactly one command:

```
cat ~/.claude/skills/msg/VERSION 2>/dev/null || echo "no stamp"
```

`install.sh` writes that file on every install. It is deliberately the *global* path even when a
project ships its own `.claude/skills/msg/` — the installed copy is what other repos load, so the
installed copy is what this mode reports.

**Step 2 — Emit**

Emit the file's single line verbatim, and nothing else:

```
msg v<version> — <commit>, installed <YYYY-MM-DD>
```

If the command printed `no stamp`, emit exactly this instead:

```
msg is installed but unstamped — reinstall to record a version: curl -fsSL https://raw.githubusercontent.com/ndisisnd/msg/main/install.sh | bash
```

An unstamped install means the copy predates `--version`, which is itself the answer: it is older
than v5.6.3. Never guess a version from a changelog, a tag, or this repo's `package.json` — those
describe the source, not what is installed.

Stop. Do not emit anything else.
