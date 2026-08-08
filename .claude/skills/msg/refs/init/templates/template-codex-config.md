---
name: Codex project config template
description: Template for .codex/config.toml — the project-layer Codex settings msg needs, and nothing else
type: reference
---

# Codex project config template

The skill writes `.codex/config.toml` from this body verbatim — no substitutions.

Deliberately near-empty. This is a *project* config layer, which means it overrides
settings the developer chose for themselves. msg sets exactly the one key its own
orchestration cannot work without and leaves model, provider and sandbox policy alone.

## Template body

```toml
# Codex project config, written by /msg --init.
#
# Deliberately minimal. Only the subagent limits are set here: model, provider and
# sandbox policy stay whatever your own Codex profile says. A project config layer
# overrides your personal settings, so msg puts as little in it as it can.
#
# max_depth = 2 is the one non-default. msg's gate dispatch nests one level —
# dispatcher spawns a gate run, which spawns a component wave — and Codex's default
# depth of 1 refuses the inner spawn. If depth-2 nesting is unavailable, gates run
# inline instead: slower, same result.
#
# Delete this file if you would rather run msg entirely on your own limits.

[agents]
max_threads = 6
max_depth = 2
```

## Notes

- `max_threads = 6` is Codex's own default, restated so the pair reads as one decision
  rather than leaving the reader to wonder whether the missing key means something.
