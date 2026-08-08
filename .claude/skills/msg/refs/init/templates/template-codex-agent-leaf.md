---
name: Codex msg-leaf role template
description: Template for .codex/agents/msg-leaf.toml — the worker role msg's Codex leg spawns instead of naming a model tier
type: reference
---

# Codex msg-leaf role template

The skill writes `.codex/agents/msg-leaf.toml` from this body verbatim — no substitutions.

The Codex-leg binding for msg's `model: sonnet` leaf dispatch. A leaf receives a fully
specified packet and executes it; it does not plan.

## Template body

```toml
# msg-leaf — the worker role, written by /msg --init.
#
# The Codex-leg binding for msg's "model: sonnet" leaf dispatch. A leaf receives a
# fully-specified packet — a bounded file scope with its rows, standards payload and
# escape hatch — and executes it. Low effort is the point: the thinking already
# happened in the lead.
#
# No `model` key, for the same reason as msg-lead.toml.

name = "msg-leaf"
description = "msg worker: executes one fully-specified packet — a bounded file scope with its rows, standards payload and escape hatch — and returns a structured result. Delegated to explicitly by msg protocols — never auto-selected."
reasoning_effort = "low"
```
