---
name: Codex hooks template
description: Template for .codex/hooks.json — wires msg's CHANGELOG commit gate on the OpenAI Codex leg
type: reference
---

# Codex hooks template

The skill writes `.codex/hooks.json` from this body verbatim — no substitutions.

## Where the gate script actually lives downstream

In the msg repo itself the gate is `<repo>/.claude/scripts/changelog-gate.py`, because
the msg repo is where that script is authored. In a project scaffolded by `/msg --init`
it is not: msg's installer copies its scripts to `$HOME/.claude/scripts/`, and nothing
ever vendors a copy into the scaffolded project. So a wiring that only did
`git rev-parse --show-toplevel` — the shape the msg repo's own `.codex/hooks.json` uses —
would point at a file that does not exist, and the gate would never run.

The command below therefore uses the same locally-first-then-installed-root idiom the
rest of msg uses for its scripts (`protocol-init.md` states it in prose): try
`<repo>/.claude/scripts/`, fall back to `$HOME/.claude/scripts/`, and exit 0 if neither
is present.

Three deliberate choices, each with a cost worth naming:

- **`$HOME` is used, and nothing else absolute is.** `$CLAUDE_PROJECT_DIR` is set by
  Claude Code and by nothing else, so a Codex hook wired through it resolves to an empty
  path and the gate silently stops running. `/Users/...` is one developer's machine. But
  `$HOME` resolves on whoever's machine runs it and is the only way to reach an installed
  script that genuinely lives outside the repo — so it stays, as a named exception.
- **`cd` to the repo root before running.** The gate's own `git diff --cached` is
  cwd-relative, and Codex does not guarantee the cwd it runs hooks from. From the wrong
  directory the gate finds no staged changes and fails **open**. Resolving the root and
  entering it removes that ambiguity.
- **Fail open when the script is missing.** A hook that errors on every `Bash` call in a
  project where msg's scripts were never installed is worse than a missing gate. The cost
  is that "gate absent" and "gate present" look identical from outside — which is why the
  emitted `AGENTS.md` tells the developer to verify liveness rather than assume it.

## Template body

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "sh -c 'R=\"$(git rev-parse --show-toplevel 2>/dev/null)\"; G=\"$R/.claude/scripts/changelog-gate.py\"; [ -f \"$G\" ] || G=\"$HOME/.claude/scripts/changelog-gate.py\"; [ -f \"$G\" ] || exit 0; cd \"${R:-.}\" && exec python3 \"$G\"'",
            "statusMessage": "Checking CHANGELOG.md…"
          }
        ]
      }
    ]
  }
}
```

## Notes

- Codex hooks are trust-gated per content hash. Editing this file revokes trust, and an
  untrusted hook does not error — it just stops running. That is documented for the
  developer in the emitted `AGENTS.md`, not here.
- `changelog-gate.py` itself is harness-neutral and ships byte-identical on both legs; it
  already speaks the shared `permissionDecision` envelope and already ignores Codex's
  extra stdin fields (`model`, `turn_id`).
