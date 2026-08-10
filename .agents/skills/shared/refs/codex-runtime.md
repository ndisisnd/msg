---
name: codex-runtime
description: The shared Claude-to-Codex runtime contract for msg — invocation syntax, tool bindings, asset path resolution, subagent lifecycle, human-gate ownership, watch cadence, model tiers, permissions, project instructions and external skills, with the approved deviation that authorises each one
type: reference
---

# Codex runtime — one translation layer, no product changes

Every msg skill on Codex reads this file before it reads its canonical payload.
It answers one question and only that question: *when the canonical Claude
workflow says "do X", what exactly does doing X mean on Codex?*

It contains no product policy. The canonical payload
(`<skill>/CLAUDE-SKILL.md`, byte-identical to `.claude/skills/<skill>/SKILL.md`)
remains the single source of truth for modes, questions, refusals, write
boundaries, artifacts and handoffs. Nothing here may drop, weaken, reorder or
add one of those.

## How to use this file

1. Read this contract. It is short on purpose.
2. Read the skill's `refs/compatibility-map.md` for the per-file coverage,
   translation and proof table, and for the deviations scoped to that skill.
3. Read the canonical payload and execute it, substituting only the bindings
   below.

If executing the payload on Codex appears to require any change that is not
authorised by a decided `DEV-CX` record in `codex/deviations.md`, **stop**. Raise
it as a new deviation record and wait for a decision. There is no
`not-applicable`, no `best effort`, no silent fallback and no changed golden.

Every rule below cites the decided record that authorises it. Records marked
`approved-deviation` are real, disclosed differences — they are never described
as parity. Records marked `rejected` are listed too, because a rejection is an
instruction to preserve the canonical behaviour exactly.

## 1. Invocation syntax — `DEV-CX-001` (approved-translation)

| Context | Claude | Codex |
|---|---|---|
| User invokes a skill | `/msg` | `$msg` |
| A payload tells you to hand off | `/pre-merge` | `$pre-merge` |
| Menus, pickers, closing messages, next-step lines | `/skill` | `$skill` |
| Natural-language activation | supported | supported, unchanged |

Rules:

- Translate **active-runtime invocation tokens only**. Mode flags (`--build`,
  `--staging`), file paths, branch names and prose are untouched.
- Never rewrite the canonical payload. The payload keeps Claude's slash form
  because it is the frozen Claude contract; treat that text as documentation of
  the other runtime and emit the `$` form to the user.
- Natural-language triggers stay enabled for all nine skills. `DEV-CX-009`
  proposed disabling implicit invocation on Codex and was **rejected** — a user
  who says "log an idea" must still reach `intake` without typing anything.

## 2. Tool bindings — `DEV-CX-003` (approved-translation)

Each Claude tool named in a canonical protocol binds to the Codex-native
capability below, per the OpenAI tools guide. Inputs, authority, pause point,
returned data and continuation point must be preserved exactly.

| Claude tool | Codex binding | What must not change |
|---|---|---|
| `Read` | File reads / targeted search (`rg`, ranged reads) | The set of files read and the read scope. |
| `Write`, `Edit` | `apply_patch` | Which paths may be written, and the sanctioned-write list. |
| `Bash` | Shell tool | The command, its exit-code meaning, and the gate it feeds. |
| `AskUserQuestion` | Structured user-input surface where the client offers one; otherwise a single concise question turn that halts the run | The decision, the option set, the default, and the exact point the run resumes from. |
| `Agent` | Codex subagents (child threads) — see §4 | Role, task boundary, independence, concurrency cap, returned evidence. |
| `Skill(name)` | Explicit load of the named Codex skill, with its path passed to child threads | No workflow may be inlined, substituted or skipped. |
| `WebSearch`, `WebFetch` | Codex web/connector tools | The source constraints the canonical protocol imposes. |
| Background execution | Managed child thread or managed terminal session — see §4 and §13 | Liveness, ownership, cleanup. |

**Fail closed.** If the active Codex surface cannot preserve a gate — for
example it offers no way to halt for a mandatory approval — that path **blocks**
with a stated reason. It does not degrade to a weaker prompt and it does not
proceed. A startup verification proves the required surfaces exist before a
gated mode begins.

## 3. Asset and helper resolution — `DEV-CX-002` (approved-translation)

Codex roots only. A Codex run never depends on, reads by default, or writes to
Claude installation state.

Search order, first hit wins:

1. `<repo>/.agents/scripts` · `<repo>/.agents/skills`
2. `$HOME/.agents/scripts` · `$HOME/.agents/skills` (override with
   `MSG_AGENTS_HOME`)
3. *Opt-in migration read only:* `<repo>/.claude/...` then `$HOME/.claude/...`,
   and only when the user sets `MSG_CODEX_ALLOW_CLAUDE_LEGACY=1`. These are
   read-only inputs; nothing is ever written there.

`.agents/scripts/script-codex-resolve.sh` implements this order. Skill-relative
references inside payloads (`refs/…`, `shared/refs/…`) resolve against the
generated `.agents/skills/` tree, which preserves the canonical relative
structure exactly, so those links need no rewriting.

A Codex-only install writing into `$HOME/.claude` is a release-blocking failure.

## 4. Subagents — `DEV-CX-005` (approved-translation), `DEV-CX-013` (approved-deviation)

Claude's `Agent` lifecycle maps to Codex child threads:

| Claude operation | Codex operation |
|---|---|
| Spawn named agent with a packet | Spawn a child thread with the same packet bytes |
| Background + poll | Child thread runs while the root waits and watches |
| Steer a running agent | Send a message to the running child thread |
| Collect result | Read the child thread's returned artifact |
| Independent reviewer | A **distinct** child thread — never the author, never the root |

What must hold, and is proven by trace in every orchestration eval:

- **Ownership.** One packet, one owning thread. Packets stay file-disjoint.
- **Identity.** Run IDs are disjoint; the reviewer's identity differs from the
  builder's. Self-review is never an acceptable substitute.
- **Dependency order.** The packet DAG and its phase barriers are preserved.
- **Resume.** A completed packet is never re-run after an interruption.
- **No hidden degradation.** If multi-agent execution is unavailable, a skill
  that requires independent agents uses the documented safe sequential
  independent path or refuses. It never silently runs every role in the main
  thread.

Disclosed difference (`DEV-CX-013`): Codex's thread cap and scheduler are not
Claude's queue. The DAG, the maximum declared width and the phase barriers are
preserved; completion order, queue presentation and heartbeat timing may differ.
That is a real difference, disclosed, not parity.

## 5. Human gates — `DEV-CX-011` (approved-translation)

Every mandatory human gate in a canonical payload stays mandatory, with the same
decision and the same option set.

Gates are presented in the **root thread**, because a child thread does not own
the root chat's user-input surface. When a leaf detects a gate condition — the
never-preapproved database/data/production-configuration pause is the canonical
case:

1. The leaf stops before taking any action and emits a structured gate envelope.
2. The root relays the leaf's question **verbatim** — wording, options and
   default unchanged.
3. The answer returns to the **same** leaf, which resumes from the **same**
   checkpoint.

The leaf owns the gate throughout. Nothing starts early, no decision set is
edited, and approve / deny / cancel / stale-answer / duplicate-delivery all have
trace-proven behaviour.

## 6. Heartbeat and stall watch — `DEV-CX-010` (rejected: preserve canonical)

Timed observational heartbeats and the stall-watch ladder are **preserved on
Codex**. The proposal to replace them with wave-boundary-only checkpoints was
rejected.

- Keep the elapsed-time cadence, not one report per wave.
- Keep the stall thresholds and the escalation ladder.
- Keep heartbeats observational: they never change a verdict and never
  auto-stop a run.

The root thread watches child threads on the canonical cadence and uses the same
status helpers, so status output stays byte-identical.

## 7. Model tiers — `DEV-CX-006` (approved-deviation)

Pinned map, recorded in every report that names a packet class:

| Canonical tier | Codex model |
|---|---|
| Opus-tier packet (orchestration, synthesis, adversarial review) | `Terra` |
| Sonnet-tier packet (scoped leaf build, mechanical checks) | `Luna` |

This is an accepted semantic difference, not a translation: cost, latency and
output quality may differ. No packet class may substitute a model silently, and
each packet class stays gated on its own quality-and-independence eval.

## 8. Permissions, sandbox and hooks — `DEV-CX-007` (approved-translation)

Claude's `allowed-tools` frontmatter and `.claude/settings.json` hooks are host
enforcement. On Codex the equivalent is the sandbox/approval profile plus Codex
hooks.

- Use the **narrowest** sandbox and approval profile the mode needs.
- Protocol-level refusal checks stay in place as defence in depth. Prose is not
  enforcement — it is the second layer, never the only one.
- Startup verification **fails closed**: if a required host boundary cannot be
  established, the mode blocks rather than running unprotected.
- A permissive host never expands a skill's declared write authority
  (`CX-G007`). Extra host approval prompts are allowed; removed msg gates are
  not.
- `.claude/settings.json` and `.claude/settings.local.json` are never read as
  Codex configuration inputs.

## 9. Project instructions — `DEV-CX-004` (approved-translation)

`CLAUDE.md` remains the single source of project instructions. Codex discovers
`AGENTS.md`, so `AGENTS.md` is a **thin pointer** to `CLAUDE.md` — not a copy,
not a second policy surface.

- Where a repo has both and their content **conflicts**, the run **stops** and
  reports the conflict. It never guesses and never silently prefers one.
- An existing human-authored `AGENTS.md` is never overwritten.
- `msg --init` on Codex scaffolds the canonical `CLAUDE.md` plus the pointer;
  all shared `devkit/` artifacts are unchanged.

## 10. External skills — `DEV-CX-008` (approved-translation)

`kermit` and optional `cook`, and the cross-skill calls to `intake`,
`plan-review` and `eng`, are **declared dependencies with version checks**.

- A startup contract probe verifies presence and version before a path that
  needs one runs.
- A missing dependency produces a clear blocked-or-degraded state that says so.
  Silent omission of an optional path is not parity.
- Canonical degradations that are already optional stay optional and stay
  explicit — for example `$pre-merge`'s PR step calls `$kermit --pr` and
  loud-degrades to `gh pr create` when kermit is absent.

## 11. Deterministic helpers stay byte-identical — `CX-G006`

The 67 helpers under `.agents/scripts/` are byte-identical copies of the
canonical `.claude/scripts/` implementations, not rewrites. Both runtimes run the
same code, so every machine emission — verdict JSON, check reports, status
lines, policy resolution — is byte-identical across runtimes and the existing
`evals/run.sh` suite remains the deterministic parity floor.

A helper's exit-code meaning is part of its contract. Exit 3 stays a designed
outcome, not a harness incident.

## 12. GUI runner — `DEV-CX-014` (approved-translation)

`msg --gui` serves the same local board. The prompt console gets an **isolated
Codex runner variant**: a Codex process and `$skill` quick actions and copy. The
Claude runner, its defaults and its rendered bytes stay unchanged, proven by
snapshot. Any OS-level window-opening approval is a runtime approval, not a new
msg product gate.

## 13. Emulator — `DEV-CX-015` (approved-deviation), `DEV-CX-016` (approved-translation)

- **Host approval (`DEV-CX-015`, disclosed difference).** Codex's sandbox may
  require an explicit approval before a macOS GUI command such as
  `open -a Simulator` runs. Surface the minimum approval, with a clear purpose,
  then execute the exact canonical launch. Refusal leaves zero partial launch
  state.
- **Process lifetime (`DEV-CX-016`).** Use the smallest managed launcher that
  keeps the dev server alive after the turn ends. Success is reported only after
  a health check passes and enough state is recorded for canonical reuse, sweep
  and cleanup. A degraded lifetime is not an acceptable success.
- `emulate` still writes nothing to the repository beyond gitignored runtime
  artifacts (`.emulate/` logs, DerivedData) — no tracked or product-state writes.

## 14. Prompt caching — `DEV-CX-012` (approved-deviation)

Packet prompts keep their byte-identical stable head and ordering, and that is
digest-tested. Anthropic's prefix-cache hit rate and billing semantics are **not**
reproduced or claimed. Benchmarks may report byte stability; they must never
present it as a cache-hit guarantee.

## 15. The generated tree

`.agents/` is built by `codex/script-build-codex-skills.py` from the canonical
tree and is committed so a repo-local Codex session works with no install step.

| Path | Origin |
|---|---|
| `.agents/skills/<skill>/SKILL.md` | generated thin adapter (`name` + `description` frontmatter only) |
| `.agents/skills/<skill>/CLAUDE-SKILL.md` | byte-identical copy of the canonical `SKILL.md` |
| `.agents/skills/<skill>/refs/**`, `scripts/**`, stubs, templates | byte-identical copies |
| `.agents/skills/<skill>/agents/openai.yaml` | generated Codex metadata |
| `.agents/skills/shared/refs/**` | byte-identical copies of the canonical shared contracts |
| `.agents/scripts/**` | byte-identical copies of the 67 canonical helpers, plus `script-codex-resolve.sh` |
| `refs/compatibility-map.md` (all ten), this file, `harness-map.md` | hand-authored; the generator never writes or prunes them |

Rules:

- Regeneration is deterministic and idempotent: no timestamps, no absolute
  paths, no environment-dependent bytes. Building twice yields the same tree.
- The generator is read-only against `.claude/`, `install.sh`, `package.json`
  and the frozen baselines.
- Edit the canonical Claude source or the templates under `codex/`, then
  regenerate. Hand-editing a generated file is drift and the checker fails it.
- `codex/script-check-codex-compat.py` verifies discovery, frontmatter shape,
  byte fidelity, reference resolution and Claude isolation.

`harness-map.md` is pre-existing user work retained as evidence. It predates the
decision gate and contains proposals that were later **rejected**
(`DEV-CX-009`, `DEV-CX-010`) or decided differently (`DEV-CX-002`). Where it
disagrees with this file, **this file wins**.

## 16. Decision index

| Record | Decision | Where it lands |
|---|---|---|
| `DEV-CX-001` invocation syntax | approved-translation | §1 |
| `DEV-CX-002` discovery and installed paths | approved-translation | §3 |
| `DEV-CX-003` tool and question bindings | approved-translation | §2 |
| `DEV-CX-004` project instructions | approved-translation | §9 |
| `DEV-CX-005` subagent lifecycle | approved-translation | §4 |
| `DEV-CX-006` model tiers | approved-deviation | §7 |
| `DEV-CX-007` permissions and hooks | approved-translation | §8 |
| `DEV-CX-008` external skills | approved-translation | §10 |
| `DEV-CX-009` implicit invocation | rejected — preserve canonical | §1 |
| `DEV-CX-010` heartbeat and stall watch | rejected — preserve canonical | §6 |
| `DEV-CX-011` leaf-owned gate relay | approved-translation | §5 |
| `DEV-CX-012` prompt-cache behaviour | approved-deviation | §14 |
| `DEV-CX-013` concurrency width and scheduling | approved-deviation | §4 |
| `DEV-CX-014` GUI runner and quick actions | approved-translation | §12 |
| `DEV-CX-015` host GUI approval | approved-deviation | §13 |
| `DEV-CX-016` emulator process lifetime | approved-translation | §13 |

The authoritative records, with their canonical sources, alternatives attempted
and compensating controls, live in `codex/deviations.md`. Read that ledger before
proposing anything new.
