---
name: status-heartbeat
description: Cross-skill contract for the ~5-minute status heartbeat emitted during the long phases — the checkpoint rule, the report shape, who may speak, and how it degrades
type: reference
---

# Status heartbeat — the run says where it is, every ~5 minutes

The long phases (`eng --build`, `/pre-merge`, `/merge`, and `plan-em`'s waves) can
run for tens of minutes with nothing on screen. This contract makes them speak: a
short, fixed-shape status block roughly every five minutes, so a watching human
always knows the phase, what finished since the last update, what is running now,
and whether anything is blocking.

It is **observational**. It never changes a verdict, a refusal, a gate, or what a
run does next, and it never substitutes for a human gate — a `STOP` still stops.

## The checkpoint rule (why this is not a timer)

A skill can only speak when it holds the turn. Nothing interrupts a running `Bash`
call or a spawned subagent to inject a line, and the model cannot read a clock
between turns. So the heartbeat is a **cadence-checked checkpoint**: at every point
where the orchestrator naturally regains control it calls the tick script, which
answers `REPORT` or `QUIET`. The guarantee is therefore:

> at most one report per interval, emitted at the first checkpoint after the
> interval expires — never more often, never later than the next checkpoint.

Checkpoints belong wherever control returns anyway: a wave boundary, a per-check
result-report write, a completed ticket, a numbered protocol step, a returning
subagent, a **poll-loop wake**. **Never insert a step, a command, or a delay solely
to create a checkpoint** — a heartbeat that changes the shape of the run has cost
more than it bought.

The poll wake is the checkpoint that tightens the guarantee. When a wave is
dispatched backgrounded and polled — the standard shape for leaf fan-out, per
[`agent-watch.md`](agent-watch.md) — the orchestrator regains control roughly every
interval for the whole length of the wave. So for the duration of a wave:

> reports land within ~1 poll interval of when they are due — effectively a real
> 5-minute cadence, not one report per wave.

## The call surface

The script owns every elapsed-time and interval decision. No skill does that
arithmetic in prose.

```bash
S=.claude/scripts/script-status-tick.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-status-tick.sh"
"$S" --start --phase <name> --run-id <id> [--total <n>] [--label <text>]
"$S" --tick  --run-id <id> [--step "<running now>"] [--done <n>] [--note "<event>"] [--finding <blocker|high|medium|low>] [--next "<text>"]
"$S" --end   --run-id <id> [--outcome "<text>"]
```

- **`--run-id`** is chosen once at `--start` — `<skill>-<epoch seconds>` — and reused verbatim by every later call in the run.
- **`--tick` always records, and only sometimes reports.** Notes bank across silent ticks and drain into the next report exactly once, which is what makes "what happened since the last update" possible without the model remembering anything.
- **Quote the script's output; never re-render it.** A `--tick` printing `QUIET` produces no chat output at all. A `--tick` printing `REPORT` is followed by the rendered block — emit it as-is.
- `--now <epoch>` exists for the eval harness's fixed clock. Never pass it from a protocol.

**`--end` fires on every exit from the phase — not just the happy one.** A refusal,
a mid-run stop, a failed check, a failed ship: each still closes the heartbeat, with
`--outcome` naming what actually happened. Two reasons. The moment a run ends badly
is the moment a watching human most wants a closing summary, and `--end` is what
removes the state file — a phase that only closes on success leaks one file per bad
run. Where a protocol has several exits, close at each of them.

## The report shape

Rendered by the script so the wording cannot drift between skills. Reference only —
the script is the source of truth:

```
⏱ <elapsed> · <phase> · <done>/<total> · <label>
done: <events banked since the last report, joined by "; ">
now: <what is running>
issues: <n blocker / n high / n medium>
next: <what the run reaches next>
```

Every line below the header is omitted when it has nothing to say, so a minimal
report is two lines. Elapsed renders `Nm` under an hour, `Hh Mm` beyond it.

## Only the orchestrator speaks

Leaf subagents never call the tick script and never emit status. Their output is
not user-visible, and a second speaker would interleave into nonsense. Instead a
leaf returns **one line** in its return payload:

```
status: <ticket-or-packet-id> <done|blocked> — <≤8-word summary>
```

The orchestrator ticks once per returning leaf and folds that line in as a
`--note`. This is the only sanctioned path from a subagent into the heartbeat.

**One exception, and only one.** When a watched leaf has been idle past the stall
threshold, the orchestrator emits a single visible line naming the leaf, its idle
age, and the human's options — out of band, between reports. It is defined in
[`agent-watch.md`](agent-watch.md) § The stall line, and it is informational: it
asks a human to decide, and never stops anything itself. No other out-of-band line
is sanctioned.

## Relaying across a subagent boundary

When the orchestrator itself runs inside a subagent — a gate behind a dispatcher
([`gate-dispatch.md`](gate-dispatch.md)), a `plan-em --team` orchestrator behind
plan-em — its ticks are real and recorded but **nobody sees them**. Only a
subagent's final return payload reaches the user; its intermediate output does
not. Two rules make the inner run's progress visible, and both are load-bearing.

**Run-ids stay disjoint.** The outer dispatcher mints its own id; the inner run
keeps its own. Never reuse the inner id, and never let the inner run see the
outer one. Sharing an id does **not** relay anything — it destroys it. A `--tick`
that reports drains the notes bank (`--start`'s state is emptied) and resets the
report window, so whichever process ticks first takes everything and leaves the
other with `QUIET` against an empty bank; and `--end` deletes the state file
outright, so the inner run's close tears down the outer run's state mid-flight.

**The relay is a file, not shared state.** The inner run appends every rendered
`REPORT` block to a relay log in the run's artifact directory as it is produced —
`.pre-merge/<ts>/heartbeat.log` for a gate, `<prd-dir>/reports/heartbeat.log` for
a team wave. The **outer** run dictates the path and injects it; the inner run
never learns the outer id. On each poll wake the dispatcher reads the newest
block and folds it in as its own `--note`. Progress the human sees is real inner
progress, one relay hop later.

The relay file doubles as the inner run's liveness evidence for
[`agent-watch.md`](agent-watch.md): the same append that gives the dispatcher
something to say also proves the run is alive. Appending is best-effort — a
failed append never fails, blocks, or re-verdicts a run.

## Long blocking steps

A single component — a full test suite, an e2e run, a deploy — can outlast the
interval with no checkpoint inside it. Two mitigations, in order of preference:

1. **Pre-announce.** The tick immediately *before* a known-long step names it and
   its expected duration in `next:`, so the silence is bounded and explained rather
   than mysterious. This applies everywhere and costs nothing.
2. **Background and poll.** For steps that routinely exceed the interval and
   already write a structured log, run the step backgrounded and poll its log at
   interval — each poll is a legitimate checkpoint carrying real content
   (`now: unit — 412/900 tests`). Use this only where the log is genuinely
   parseable; a fabricated progress number is worse than silence.

For **leaf waves** this is no longer a mitigation — background-and-poll is the
standard dispatch shape, with the loop, the watch calls and the escalation ladder
specified in [`agent-watch.md`](agent-watch.md). It stays a mitigation for a single
long *foreground* command, which has no leaves to watch and nothing to poll but its
own log.

## Cadence resolution

Resolved once at `--start`, highest first — a mid-run policy edit must not move an
already-open report window:

| Source | Meaning |
|---|---|
| `MSG_STATUS_INTERVAL` env var | minutes; `0` disables the heartbeat entirely for this run. Where the per-run `--quiet` / `--status <n>m` flags land |
| `policies.status_cadence` in `devkit/policy.json` | `{enabled, interval_minutes}`; absent, unreadable or malformed falls through silently |
| default | enabled, 5 minutes |

The per-run flags are how a human reaches the env var. Before the `--start` call,
the orchestrator exports it once: `--quiet` → `MSG_STATUS_INTERVAL=0`,
`--status <n>m` → `MSG_STATUS_INTERVAL=<n>`. Neither flag given, nothing is
exported and policy decides. No skill parses the interval further than that.

Any resolved interval below **2 minutes** is clamped to 2 with one stderr note — a
30-second heartbeat on a 40-minute gate is spam, not visibility. `0` is a distinct
state and is never clamped.

## Degradation

The heartbeat can never break a run. A missing, unreadable, or corrupt state file
makes `--tick` print `QUIET` and exit 0. The script's only non-zero exit is `2`,
for a genuine caller usage error — an unknown flag, a missing `--run-id`, a
severity outside the enum, a non-integer count. **A tick that fails is dropped, not
retried, and never logged as an incident**; the phase carries on exactly as it
would have. Skills do not branch on the script's exit code.
