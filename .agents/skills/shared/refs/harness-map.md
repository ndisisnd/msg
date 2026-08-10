---
name: harness-map
description: The Claude-to-Codex binding table — how msg's canonical tool vocabulary (AskUserQuestion, Agent, Skill, Monitor, run_in_background, model tiers) is executed when the harness is OpenAI Codex CLI rather than Claude Code, plus the spawn-propagation rule, hook-trust probe, and the degradations that are allowed
type: reference
---

# Harness map — one translation layer instead of a rewritten vocabulary

msg runs on two harnesses: Claude Code and OpenAI Codex CLI. The skills are the
same bytes on both — the Codex leg is symlinks into `.claude/skills/`, never a
fork, never a copy that drifts.

That leaves one problem. msg's protocol prose names Claude Code's tools directly
and constantly: it says `AskUserQuestion` when it means *stop and ask the human*,
`Agent` when it means *spawn a worker*, `model: opus` when it means *this one
needs to think hard*. Rewriting ~1,800 of those mentions into some harness-neutral
vocabulary would be a huge diff across every protocol, and it would make the text
worse — vaguer, and further from what a Claude-side reader actually types.

So the protocols keep speaking Claude. **This file is the dictionary.** Under
Codex you read the protocol as written, and whenever it names a construct in the
table below, you do the Codex column instead.

Two things follow from that, and they are the whole reason this file has rules and
not just a table:

- A dictionary only helps a reader who has it. msg deliberately cuts spawned
  workers off from `SKILL.md`, so the preamble that points here never reaches
  them on its own — the **spawn-propagation rule** fixes that.
- Some Claude constructs have no Codex equivalent at all. Those degrade, and the
  degradations are listed so nobody mistakes one for a bug or, worse, works around
  it by dropping a human gate.

## Am I running under Codex?

**Primary signal: your own knowledge of what you are.** A model running in Codex
CLI knows it is in Codex CLI, the same way it knows its own name. Trust that
first — it is right essentially always, and it costs nothing.

**Tie-break, only when genuinely unsure:** the two harnesses leave different
environment fingerprints. Run this once and cache the answer for the session:

```bash
if env | grep -q '^CODEX_'; then echo "codex"
elif [ -n "${CLAUDE_PROJECT_DIR:-}${CLAUDECODE:-}" ]; then echo "claude"
else echo "unknown"; fi
```

**On `unknown`, assume Claude Code.** Claude is msg's canonical harness, its
behaviour is the one every eval pins, and the Codex column's substitutions are
only ever *needed* under Codex — applying them on Claude would replace working
tools with prose imitations of themselves. Guessing wrong in the Claude direction
costs nothing on Claude and is loudly obvious on Codex (a tool that isn't there).

## The binding table

| Canonical (what the protocol text says) | What it means under Codex |
|---|---|
| `AskUserQuestion` | Ask in prose with the options **numbered**, same wording, same order, same default. Then **stop and wait for the user's turn.** Codex's `request_user_input` tool exists but is Plan-mode only, so prose is the portable form. A prose question blocks exactly as hard as the tool does — the run does not continue until the human answers. **Never proceed on silence, never pick for them.** |
| `Agent` tool spawn | `spawn_agent`, with a descriptive `task_name`. The role comes from `.codex/agents/` (project) or `~/.codex/agents/` (user) — see the model-tier row. The parent **waits** for the child's result; there is no fire-and-forget. |
| `run_in_background: true` + hold-the-turn poll loop | **Not available.** Codex's parent cannot keep the turn while children run. Spawn and wait instead. Anything built on the poll loop — the ~5-minute heartbeat (`status-heartbeat.md`), the stall watchdog (`agent-watch.md`) — falls back to the checkpoint contract those files already document: report at wave boundaries rather than on a timer. **This is safe by construction:** the watch is observational, it never gates or stops anything, so losing it loses visibility and no correctness. |
| `model: opus` / `model: sonnet` | The role TOMLs `msg-lead` and `msg-leaf`. Opus-tier work (planning, decomposition, synthesis) delegates to `msg-lead`; Sonnet-tier work (executing one fully-specified packet) delegates to `msg-leaf`. Codex's per-spawn model override has proven unreliable, so the **role** is the durable mechanism — the roles set reasoning effort, not a model pin, which keeps the run on whichever model the developer already chose. |
| `Skill("x", args)` chaining | Open the other skill's `SKILL.md` — `~/.agents/skills/x/SKILL.md`, or `.agents/skills/x/SKILL.md` in a repo that dogfoods the leg — and execute it inline with the given args. It is a read-and-follow, not a separate session: the current run continues, carrying its state. |
| `Monitor` / until-loop | until-loop only. Where a protocol offers `Monitor` *or* an until-loop, take the until-loop branch. |
| `$CLAUDE_PROJECT_DIR` | `$(git rev-parse --show-toplevel)`. Codex does not set `CLAUDE_PROJECT_DIR`. Never hardcode an absolute path as a substitute. |
| `/name` invocation (e.g. `/msg --init`) | `$name` — Codex invokes skills with a `$` sigil, or from the `/skills` picker. Same skill, same arguments, different sigil. Custom `~/.codex/prompts` slash commands are deprecated in favour of skills, so `$name` is the durable form. |
| Project memory `CLAUDE.md` | `CLAUDE.md` if present, else `AGENTS.md`. Codex reads `AGENTS.md` at the repo root before every task; `/msg --init` emits both, so a scaffolded project works on either harness. When a protocol says "read the project memory file", read whichever of the two exists — `CLAUDE.md` wins if both do. |

Everything not in this table is the same on both harnesses. In particular: every
path msg uses — `~/.claude/skills`, `~/.claude/scripts`, the project's
`.claude/msg/` state directory, the `VERSION` stamp — is identical under Codex,
because the Codex leg installs to the same places and reaches them through
symlinks. Under Codex, `.claude/` is simply a directory msg owns. Do not "port"
those paths; changing them breaks both legs at once.

## Rule 1 — spawn propagation

A `SKILL.md` preamble tells a reader this file exists. Spawned workers never see
it: `eng/refs/build/protocol-packet.md` tells a leaf **not** to read `eng/SKILL.md`,
and every orchestrator composes packet prompts that point at refs rather than at
the skill entry point. That is deliberate — it is what keeps leaf context small —
but it means a leaf under Codex would inherit Claude vocabulary with no dictionary.

**So: under Codex, every spawn prompt you compose must include this preamble line.**
Verbatim, at the top of the packet, before the packet's own content:

> Running under OpenAI Codex? Read `shared/refs/harness-map.md` first and apply its bindings; under Claude Code, skip it.

This applies at every dispatch point — `eng/refs/build/protocol-packet.md`,
`plan-em/refs/protocol-team.md`, `shared/refs/gate-dispatch.md`,
`shared/refs/agent-watch.md` — and it applies recursively: a spawned orchestrator
that spawns its own leaves passes the line down again.

## Rule 2 — hooks are trust-gated, so prove the gate is alive

Codex hooks are deliberately Claude-compatible: same event names, same stdin JSON,
same `hookSpecificOutput.permissionDecision` envelope. msg's `changelog-gate.py`
therefore ships byte-identical and needs no Codex-specific version.

The wiring differs in one way that matters. **Codex hooks are trust-gated** — a
non-managed hook needs per-hash user trust, and a project hook additionally needs
the project's `.codex/` layer trusted. Edit the hook and the hash changes, so trust
must be granted again. An untrusted hook does not error; it simply does not run.

That failure mode is the dangerous one: a silently untrusted changelog gate is a
silently *open* changelog gate, and a release ships without its entry. **So on the
Codex leg, prove the gate is alive before relying on it** — run the probe below at
the start of any run that treats the gate as a safety net, `merge` above all. This
is an instruction to you, the agent reading this map, not a step already wired into
`merge`'s protocol: the gate is a Claude-side hook, and nothing in msg's protocol
text knows it might be untrusted.

**The probe.** Run a command whose text contains `git commit` but which does
nothing:

```
true # git commit probe
```

A live gate denies it (CHANGELOG.md is not staged). A dead gate lets it through.

**Its one false negative:** if CHANGELOG.md is already staged, the live gate
allows the probe too, and a dead gate is indistinguishable from a live one. So
check the staging state **first** — if the changelog is already staged, either
unstage it for the probe or treat the result as inconclusive and say so. Never
report "gate live" off a probe run in that state.

## Rule 3 — human gates do not degrade

`shared/refs/safety-floor.md` is unchanged on both harnesses. Staging sign-off,
the production double-confirm, the rollback offer, the pause before touching a
database — all of them still block under Codex. The `AskUserQuestion` row changes
*how the question is rendered*, never *whether it is asked* and never whether the
run waits for the answer.

One consequence worth stating plainly: **`codex exec` cannot run msg's human-gated
protocols.** Non-interactive runs strip the human-input surface, so a protocol that
must ask will refuse rather than assume. That is correct behaviour, not a gap —
`merge`'s identity is its gates. Interactive Codex sessions are the supported way
to run them.

## Rule 4 — skills are explicit here

Codex invokes skills implicitly by description match, on by default. Every msg
skill ships `agents/openai.yaml` turning that **off**. msg's skills are commands
with consequences — a gate, a merge, a release — and none of them should fire
because a prompt happened to sound like their description.

The visible difference: on Claude, describing what you want can activate the right
skill. Under Codex it does nothing until you type `$name`. Deliberate — safety over
convenience.
