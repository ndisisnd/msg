---
name: Codex msg-lead role template
description: Template for .codex/agents/msg-lead.toml — the orchestrator role msg's Codex leg spawns instead of naming a model tier
type: reference
---

# Codex msg-lead role template

The skill writes `.codex/agents/msg-lead.toml` from this body verbatim — no substitutions.

msg's protocols name a model tier directly when they spawn an orchestrator
(`model: opus`). Codex's per-spawn model override is not a durable mechanism, so on the
Codex leg that tier is expressed as a named role instead; `shared/refs/harness-map.md`
binds the two together.

## Template body

```toml
# msg-lead — the orchestrator role, written by /msg --init.
#
# msg's protocols name a model tier when they spawn an orchestrator ("model: opus").
# Codex's per-spawn model override is not durable, so on the Codex leg that tier is
# this named role instead.
#
# No `model` key on purpose: msg dropped per-skill model pins so a run stays on
# whichever model you already chose. Reasoning effort is the part that actually has to
# differ between an orchestrator and a leaf.

name = "msg-lead"
description = "msg orchestrator: plans waves, decomposes work into file-disjoint packets, dispatches leaf agents, and synthesises their returns. Delegated to explicitly by msg protocols — never auto-selected."
model_reasoning_effort = "high"
```
