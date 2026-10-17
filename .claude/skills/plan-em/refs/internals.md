---
name: EM Internals
description: Mechanics plan-em runs behind the steps — stage timing, the run-state file, the team-lane heartbeat relay, and prompt-cache field order. Loaded only at the call sites that name a section here.
type: reference
---

# EM Internals

The steps in `refs/protocol-em.md` name a section here at each call site. None of this changes what a run decides: every call below is best-effort (`|| true`), and no step branches on its exit code.

## Stage timing

Fix one `$TIMING_RUN_ID` per run (`em-$(date +%s)`; reuse the heartbeat's `RUN_ID` when there is one). Append one line at each boundary:

```bash
T=.claude/scripts/script-em-timing.sh; [ -f "$T" ] || T="$HOME/.claude/scripts/script-em-timing.sh"
bash "$T" --stage <stage> --reports-dir "$PRD_DIR/reports" --run-id "$TIMING_RUN_ID" --note "<optional>" || true
```

| Stage | Fires when |
|-------|-----------|
| `pre-flight-done` | Step 1 finishes (size resolved) |
| `cert-done` | Step 2 returns `CERTIFIED` |
| `skeleton-done` | Step 3's exec-table skeleton is rendered |
| `plan-half-done` | every agent's `## Engineering —` + `## Todos —` blocks exist |
| `build-asked` | the user answers "Start the build now?" |
| `files-collision-done` | `--fill-files` and the collision decomposition have returned |
| `branch-done` | the branch exists and the lane move (if any) has run |
| `build-wave-<n>-done` | build wave `<n>` has returned |
| `review-check-done` | the review-coverage check has returned |
| `synthesis-done` | Step 5's digest is printed |

The log is append-only at `$PRD_DIR/reports/timings-<date>.log`. The orchestrator marks the boundaries inside its own spawn with the same `$TIMING_RUN_ID` (`refs/protocol-team.md` § Stage timing).

## Run-state file

`$PRD_DIR/reports/em-state.json`, written only by `script-em-state.py` (two-path resolution: `S=.claude/scripts/script-em-state.py; [ -f "$S" ] || S="$HOME/.claude/scripts/script-em-state.py"`). It holds resumability only — never a verdict. Mode selection always comes from the PRD (Step 4 mode detection); when the state file and the PRD disagree, the PRD wins and the state is archived (`--archive`).

| Call site | Command |
|-----------|---------|
| Step 1a′ read | `python3 "$S" --get --file "$PRD_DIR/reports/em-state.json"` |
| Step 4 init (fresh run) | `python3 "$S" --init --file … --mode "$MODE" --size "$SIZE" \|\| true` — `OPEN_EXISTS` (exit 3) on a resumed run is the expected no-op |
| Step 4 roster | `python3 "$S" --set --file … --key roster --value "<agents, comma-separated>" \|\| true` |
| Plan half done | `--set --key waves.plan.status --value done` |
| "Start the build now?" → No | `--set --key waves.build.status --value not-started` (the state stays open) |
| Branch resolved | `--set --key branch --value "$BRANCH"` |
| Each build agent returns | `--set --key waves.build.agents.<agent> --value done` |
| Review coverage | `--set --key waves.build.review_coverage --value "<n>/<n>"` |
| Step 5 close | `--close --file … --outcome ok` (`failed` on an unresolved hard failure) |

Step 1a′ reads the result:

- `NO_STATE`, `CORRUPT`, or `"status": "closed"` → fresh run. Log `validator-fail:script-em-state` only when the file existed and would not parse.
- Open, with `waves.plan.status = done` and `waves.build.status = not-started` → the user stopped after the plan half. No question: continue; Step 4 resolves `$MODE = build`.
- Any other open state → summarise it in one line (`Open run found: mode build, 2 of 4 build agents returned.`) and ask via `AskUserQuestion`: **Resume** (skip work the state marks done) / **Start fresh** (`--archive`, then a fresh run) / **Abort**. Under an autonomy contract, Resume is pre-approved.

A failed `--set` is one DOCTOR row, never a changed verdict. Never add a step only to write a checkpoint.

## Team-lane heartbeat relay

plan-em watches each orchestrator spawn as one leaf and relays its progress (`../../shared/refs/status-heartbeat.md` § *Relaying across a subagent boundary*, `../../shared/refs/agent-watch.md`). plan-em mints its own `TEAM_RUN_ID=emteam-$(date +%s)` per spawn; the orchestrator keeps its own `em-<epoch>`. Never inject `$TEAM_RUN_ID` into the orchestrator: a shared id drains one side's notes into the other and lets either side's `--end` delete the other's state.

`$STATUS_RELAY` is `$PRD_DIR/reports/heartbeat.log`. The orchestrator appends each rendered `REPORT` block there.

```bash
S=.claude/scripts/script-status-tick.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-status-tick.sh"
W=.claude/scripts/script-agent-watch.sh; [ -f "$W" ] || W="$HOME/.claude/scripts/script-agent-watch.sh"
TEAM_RUN_ID=emteam-$(date +%s)
# before the spawn
"$S" --start --phase plan-em-team --run-id "$TEAM_RUN_ID" --total 1 --label "team orchestrator — $MODE"
"$S" --tick  --run-id "$TEAM_RUN_ID" --next "team wave — one orchestrator, <n> leaves"
# right after the spawn message
"$W" --register --run-id "$TEAM_RUN_ID" --leaf orchestrator \
     --evidence "$PRD_DIR/reports/heartbeat.log" --evidence "$PRD_DIR/reports/*" --label "team orchestrator — $MODE"
# on each wake
"$W" --check --run-id "$TEAM_RUN_ID"
"$S" --tick  --run-id "$TEAM_RUN_ID" --note "<newest block from $STATUS_RELAY>" --step "team wave — orchestrator running"
# on every exit path (clean return, hard failure, spawn error, stop)
"$W" --done  --run-id "$TEAM_RUN_ID" --leaf orchestrator
"$S" --end   --run-id "$TEAM_RUN_ID" --outcome "<the orchestrator summary's headline>"
"$W" --close --run-id "$TEAM_RUN_ID"
```

- Wake on the harness task notification, else a Monitor or until-loop at the heartbeat interval. Never a foreground `sleep`.
- Fold only the content lines of the newest block (`done:` / `now:` / `issues:` / `next:`). Drop its `⏱` header.
- Quote the tick output verbatim; `QUIET` prints nothing. `NOTICE` banks a note, `WARN` adds `--finding low`, `STALL` adds `--finding high` plus one visible line naming the orchestrator and its idle age. A stalled orchestrator is reported, never killed.
- An empty or missing `$STATUS_RELAY` is not a fault: tick without `--note`.

## Prompt-cache field order

Every leaf dispatch prompt lists the fields that are identical across sibling leaves first, and the per-leaf fields last. Keep the shared head byte-identical across siblings (same text, order and whitespace): Anthropic's prefix-match prompt cache then serves it to every leaf after the first. Spawn leaves of the same stack next to each other so they share the standards-payload prefix. Leaves read fields by name, never by position, and spawns stay parallel.
