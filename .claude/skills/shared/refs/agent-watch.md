---
name: agent-watch
description: Cross-skill contract for dispatching a leaf wave backgrounded and watching it — the poll loop, the stall-detection call surface, the thresholds, and the escalation ladder that never auto-stops anything
type: reference
---

Running under OpenAI Codex? Read `shared/refs/harness-map.md` first and apply its bindings; under Claude Code, skip it.

# Agent watch — a wave in flight is observed, not awaited blindly

When a mode fans out leaf subagents it used to hand the turn away for the whole
wave: spawn, block, wake up when everything returned. Two things break there. The
run goes silent for the length of the wave, so the ~5-minute heartbeat degrades to
one report per wave. And a leaf that is **stuck** looks exactly like a leaf that is
**slow** — nothing is watching, so nobody finds out until the wave never ends.

This contract fixes both with one shape: spawn the leaves **backgrounded**, keep the
turn, and poll. Each poll wake is a real checkpoint carrying real content — which
leaves finished, which are quiet, how long they have been quiet — so the heartbeat
fires on something close to a true interval and a stall surfaces while a human can
still act on it.

It is **observational**, in the same sense as
[`status-heartbeat.md`](status-heartbeat.md). Watching a wave never changes a
verdict, a gate, a refusal, or what the run does next. In particular: **no auto-stop
exists in any configuration.** A stall is reported, never acted on. Only a human
stops a leaf.

## The loop

The whole contract in order. A mode adopts it wherever it fans out leaves; a mode
with no leaves has nothing to poll and keeps plain checkpoint ticks.

1. **Spawn the wave backgrounded, in one message.** All of the wave's leaves go out
   together with `run_in_background: true`, so the orchestrator keeps the turn
   instead of blocking on them.
2. **Register each leaf** with `script-agent-watch.sh --register`, naming the
   evidence globs where that leaf's work lands — its report path, its result-report
   path, its task output log. Evidence is how liveness is measured; a leaf
   registered with no evidence globs can only ever be judged by its spawn time.
3. **Pre-announce the wave** in a `--tick --next` before entering the loop, so the
   quiet stretch is bounded and explained rather than mysterious.
4. **Poll until every leaf has returned.** Wake at roughly the heartbeat interval:
   the harness's task notification where it delivers one, otherwise a Monitor or
   until-loop. **A protocol must never busy-wait, and never `sleep`-spin in the
   foreground.** On every wake, in this order:
   - **Collect finished leaves.** Fold each returning leaf's `status:` line in as a
     `--note` on the heartbeat, and `--done` it in the watch state.
   - **`--check`** the watch state for the whole wave.
   - **`--tick`** the heartbeat, carrying the watch results (see the ladder below)
     and a `--step` naming the wave's progress, e.g. `wave 2 — 3/5 leaves`.
   - **Quote the tick's output verbatim.** `REPORT` is followed by the rendered
     block, emitted as-is; `QUIET` produces no chat output at all.
5. **Close both states on every exit path** — `--end` on the heartbeat and `--close`
   on the watch. Success, refusal, failed gate, mid-run stop: all of them close.
   A run that only closes on success leaks one state file per bad run.

Nothing here inserts a step or a delay purely to create a checkpoint. The poll wake
*is* the checkpoint, and it carries real content every time.

## The call surface

The script owns **all** idle-age arithmetic. No skill re-derives an age, compares a
timestamp, or decides a tier in prose.

```bash
W=.claude/scripts/script-agent-watch.sh; [ -f "$W" ] || W="$HOME/.claude/scripts/script-agent-watch.sh"
"$W" --register --run-id <id> --leaf <leaf-id> [--evidence <glob>]... [--label <text>]
"$W" --check    --run-id <id>
"$W" --done     --run-id <id> --leaf <leaf-id>
"$W" --close    --run-id <id>
```

- **`--run-id`** is the same id the heartbeat uses for this phase — chosen once,
  reused verbatim by every later call, on both scripts.
- **`--register`** is called once per spawned leaf, immediately after the spawn
  message. `--evidence` repeats, once per glob. `--label` is a human-readable name
  for the report lines.
- **`--check`** prints one line per still-registered leaf, plus a summary line last:

  ```
  OK <leaf> [<age>m]
  NOTICE <leaf> idle <n>m
  WARN <leaf> idle <n>m
  STALL <leaf> idle <n>m
  WATCH_SUMMARY=<ok>/<notice>/<warn>/<stall>
  ```

  `WATCH_SUMMARY` exists so a caller can read the wave's health without parsing
  every line.
- **`--done`** drops a returned leaf from the watched set. A leaf that has returned
  is never idle.
- **`--close`** removes the state file. Every exit path, no exceptions.
- **`--now <epoch>`** exists for the eval harness's fixed clock. **Never pass it from
  a protocol.**

## Thresholds

Three tiers, resolved **once** at the first `--register` of the run and stored — the
same no-mid-run-drift rule as the heartbeat's cadence, so a policy edit mid-wave
cannot move an already-open window.

| Source | Meaning |
|---|---|
| `MSG_WATCH_THRESHOLD` env var | minutes; `0` disables watching entirely for this run |
| `policies.agent_watch` in `devkit/policy.json` | `{enabled, notice_minutes, warn_minutes, stall_minutes}`; absent, unreadable or malformed falls through silently |
| default | enabled, **notice 5 / warn 10 / stall 15** minutes |

The tiers line up with the 5-minute poll cadence deliberately: a quiet leaf degrades
one tier per wake, so a human watching the run sees the trajectory — quiet, noticed,
warned, stalled — instead of a surprise jump. **A leaf idle ≥ 15 minutes is assumed
stalled.** There is no benefit of the doubt beyond that point.

Ordering `notice < warn < stall` is enforced by the script with one stderr note. No
skill validates the ordering itself.

## The escalation ladder

Binding. Each tier maps to exactly one response, and the response is always
informational.

| Tier | Response |
|---|---|
| `OK` | nothing. |
| `NOTICE` (idle ≥ notice) | banked as a `--note` — "leaf `e2e` quiet 6m". **No finding.** It drains into the next report like any other note. |
| `WARN` (idle ≥ warn) | `--finding low` **plus** the note. The next heartbeat's `issues:` line carries it. |
| `STALL` (idle ≥ stall) | `--finding high`, **and** the one sanctioned out-of-band visible line (below). |

### The stall line — the single exception to orchestrator silence

On `STALL`, the orchestrator emits one visible line **even between reports**, naming
the leaf, its idle age, and the human's options:

```
⚠ leaf e2e idle 15m — assumed stalled. Stop the task, or let it ride?
```

It repeats on every subsequent check while the stall persists. This is the only line
a protocol may emit outside a `REPORT` block, and it exists because a stuck run is
exactly when silence is most expensive.

**It asks; it never acts.** There is no auto-stop, no timeout-kill, no "stop after N
stalls" setting, and no policy key that could turn one on — see
`policies.agent_watch` in [`policy-schema.md`](policy-schema.md), which deliberately
has no `action` key. The ladder's entire job is to make sure a human knows in time.

## Invariants

1. **Observational.** Watching never changes a verdict, a gate, or a refusal, and
   never substitutes for a human gate. A `STOP` still stops; a stall still doesn't.
2. **It can never break a run.** Missing, unreadable or corrupt state means the
   script prints nothing useful and exits 0. Its only non-zero exit is `2`, for a
   genuine caller usage error.
3. **Skills never branch on exit codes.** A failed watch call is dropped, not
   retried, and never logged as an incident; the wave carries on exactly as it would
   have.
4. **Leaves never tick and never watch.** They return one `status:` line, per
   [`status-heartbeat.md`](status-heartbeat.md) § Only the orchestrator speaks. The
   orchestrator is the only caller of either script.
5. **Both states close on every exit path** — `--end` and `--close`, on success and
   on failure alike.
