---
name: gate-dispatch
description: Cross-skill contract for running a gate in a subagent behind a thin main-thread dispatcher — the pre-spawn refusal probe, the backgrounded spawn, the gate-scoped watch, the byte-identical verdict relay, and the phase-split rule that keeps every human gate in the main thread
type: reference
---

# Gate dispatch — the gate runs in a subagent, the main thread only dispatches

A gate run is the heaviest thing a session does. Component protocols, tool logs,
per-check result reports, the whole aggregation trail — all of it used to land in
the main conversation, where it competes for context with the work the person is
actually doing. None of it is content a human reads; it is machinery, and machinery
belongs somewhere else.

This contract moves it. The **run** executes inside a subagent. The **main thread**
becomes a thin **dispatcher**: it probes for a cheap refusal, spawns the run
backgrounded, watches it, relays progress, re-emits the result, and does nothing
else. The dispatcher never runs a check, never touches git, and never writes an
artifact — the subagent does all of that, exactly as an inline run would have.

Two things follow, and they are the whole point:

- **The main context stays lean.** What returns to the conversation is the verdict,
  the issue summary and the closing message — the same three things a person reads
  today, without the thousands of lines underneath them.
- **The turn stays alive.** Because the spawn is backgrounded, the dispatcher keeps
  its turn and the heartbeat ticks on a real cadence. A long gate no longer means a
  dark conversation.

It is the same machinery as [`agent-watch.md`](agent-watch.md) and
[`status-heartbeat.md`](status-heartbeat.md), applied one level up. Nothing new is
invented here; the dispatcher is simply "the orchestrator" in the watch contract's
sense, for a wave of exactly one leaf.

## The five steps

### 1 · Pre-spawn probe — a refusal costs no subagent

Run the mode's **cheap** refusal checks inline first, before any spawn. These are
the ones answered by a file existence test or a one-line command — pre-merge's
`no_manifest` and `no_diff`, merge's mode-argument and `release_flow` checks. If one
trips, refuse in the main thread with the mode's existing refusal shape and stop.
Spawning a subagent only to have it refuse in its first ten seconds is pure waste.

Anything that needs the pipeline resolved, the policy fully read, or a network call
is **not** a cheap probe. Those refusals happen inside the subagent and come back
through the normal relay.

### 2 · Spawn backgrounded — one call, one leaf

One `Agent` call with `run_in_background: true`. The prompt carries the skill
invocation, the fully resolved flags, and the run's context — CWD, branch, base
branch, and the artifact directory the dispatcher will read from. Resolve flags
**before** the spawn so the subagent never re-parses user phrasing.

The `Agent` tool's `model` parameter accepts short names only; pick per current
conventions for the skill.

### 3 · Register and watch — a run-id of its own

Register the single leaf with `script-agent-watch.sh`, using a **gate-scoped
run-id** and the run's artifact paths as evidence globs:

```bash
W=.claude/scripts/script-agent-watch.sh; [ -f "$W" ] || W="$HOME/.claude/scripts/script-agent-watch.sh"
GATE_ID="gate-$(date +%s)"
"$W" --register --run-id "$GATE_ID" --leaf gate \
     --evidence ".pre-merge/<ts>/*" --label "pre-merge gate"
```

Then run the poll loop exactly as [`agent-watch.md`](agent-watch.md) specifies:
pre-announce in a `--tick --next`, wake at roughly the heartbeat interval, fold the
returning leaf in as a `--note`, `--check`, `--tick`, quote the tick verbatim. The
escalation ladder is unchanged — `NOTICE` banks a note, `WARN` adds a `low`
finding, `STALL` adds a `high` finding plus the one sanctioned visible line. **The
watch stays observational**: a stalled gate subagent is reported, never killed.

**The run-id namespaces are disjoint and that is load-bearing.** The dispatcher
mints `gate-<epoch>`; the executor inside the subagent keeps its own
`premerge-<epoch>`; merge's phases keep `merge-<epoch>`. Two watch states exist
during a run and they must never collide — a dispatcher that reused the inner id
would see the executor's per-component leaves and report on checks it does not own.
**Never reuse the inner run's id, and never let the inner run see the gate id.**

Only the **dispatcher's** ticks reach the user. The subagent's own heartbeat and
watch are internal; per
[`status-heartbeat.md`](status-heartbeat.md) § *Only the orchestrator speaks*, a
leaf does not narrate. So that the dispatcher's ticks still carry real content, the
subagent's `REPORT` blocks land in the run artifact directory as they are produced,
and the dispatcher folds the newest one into its own `--note` on each wake. Progress
the human sees is therefore the real inner progress, one relay hop later.

### 4 · Relay, don't rewrite

On return the dispatcher re-emits, in the mode's normal order:

1. the terminal **`Issue summary`** block,
2. the **verdict JSON**, and
3. the **closing message**.

The verdict JSON is **read from the artifact file the subagent wrote** and emitted
byte-identically. It is never paraphrased, re-derived, or reconstructed from the
subagent's return text — a subagent's prose summary is a summary, and a summary of a
machine emission is a different machine emission. The subagent writes `verdict.json`
into the run artifact directory precisely so the dispatcher can `cat` it:

```bash
cat .pre-merge/<ts>/verdict.json
```

If that file is missing, the run did not complete its emission contract: report the
gate as failed to emit, log a harness incident per
[`doctor-logging.md`](doctor-logging.md), and do **not** synthesise a verdict from
the return text. A fabricated pass is worse than an admitted gap.

### 5 · Close on every exit path

`--end` on the heartbeat and `--close` on the watch, on success and failure alike —
clean verdict, failed gate, refusal, spawn error, mid-run stop. A dispatcher that
only closes on success leaks one state file per bad run. This is the existing
invariant, restated here because the dispatcher is a second place it now applies.

## Phase-split — where a human gate lives

`AskUserQuestion` is not available inside a subagent. A gate whose identity *is* its
human gates therefore cannot run as one monolithic subagent, and it does not:
it runs **phase-split**. Mechanical phases execute in subagents; **every human gate
stays in the main thread**, asked by the dispatcher, with the answer fed into the
next phase.

Each subagent phase returns a small structured hand-back rather than prose — the
verdict-so-far plus a **gate request** naming which question to ask. The dispatcher
asks it **verbatim, per the mode ref's existing wording**. The dispatcher chooses
*when* to ask, never *what* to ask, and never whether.

Two rules bound this, and neither bends:

- **No gate weakens.** Every `AskUserQuestion` in today's protocols still fires, in
  the main thread, with the same wording and in the same order. Phase-splitting is a
  change to where the mechanical work runs — not to what a human is asked.
- **A phase too small to be worth a subagent runs inline.** Spawning has real
  overhead; a single sanctioned script write after an approval is cheaper in the
  main thread. Modes name their own inline phases.

## What stays in the main thread

Interactive and interview modes are cheap, conversational and gate-dense. They stay
inline, unchanged, and never dispatch:

- any `--init`, `--update`, or other interview mode;
- refusals answered by the pre-spawn probe;
- every human gate, per the phase-split rule above.

Everything else — the bare gate run, with any combination of run flags — goes to the
subagent.

## Invariants

1. **The dispatcher does no work.** It probes, spawns, watches, relays and closes.
   It runs no check, writes no artifact, and never touches git.
2. **Byte-identical output.** The verdict JSON and every report file are identical to
   what an inline run would have produced. Dispatch is an execution-location change,
   not an output change.
3. **No gate weakens.** Every human gate fires in the main thread, same wording,
   same order.
4. **Observational watch.** A stalled gate subagent is reported, never stopped —
   [`agent-watch.md`](agent-watch.md)'s ladder, unchanged, no auto-stop in any
   configuration.
5. **Disjoint run-ids.** `gate-<epoch>` for the dispatcher; the inner run keeps its
   own. Neither reads the other's watch state.
6. **Both states close on every exit path** — `--end` and `--close`, success and
   failure alike.
