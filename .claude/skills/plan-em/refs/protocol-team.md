---
name: Team Orchestrator Protocol
description: The orchestrator engineer agent (Opus) plan-em spawns at Step 4 — once for the plan half, once for the build half — decomposes the half below the roster/stack level into file-disjoint, model-tiered work packets and fans them out to leaf eng subagents to maximise parallelism
type: reference
---

# Team Orchestrator Protocol

Loaded on every `plan-em` run (the team lane — `refs/protocol-em.md` Step 0). plan-em spawns **one orchestrator engineer agent on Opus** per half at Step 4: one for the plan half, and — after the user says Yes to "Start the build now?" — a second one for the build half. This file is that agent's protocol. The orchestrator does **not** write engineering sections or code itself. It decomposes the half and coordinates leaf `eng` subagents (`--plan` planners or `--build` implementers) per § Subagent contract.

plan-em owns everything outside the fan-out: pre-flight, certifications, the roster, the exec-table skeleton, the `## Todos` umbrella heading, the status stamps, the Files derivation, the "Start the build now?" question, and the branch cut + lane move. The orchestrator **consumes** those. It never runs a certification, resolves or creates a branch, stamps the PRD status, or invokes `/cook`.

## Input contract (what plan-em injects)

plan-em spawns the orchestrator via the `Agent` tool with `model: opus`, `run_in_background: true`, and a prompt carrying:

| Field | Value |
|-------|-------|
| `$MODE` | `plan` or `build` — the half this spawn runs |
| `prd-path` | the input PRD `.md` path |
| `roster` | the roster — each `(agent, domain, stack, rows)` tuple |
| `exec_table` | the exec-table rows: `Feature`, `Files` (build half — the collision key), `Agent` |
| `$BRANCH` | the feature branch plan-em already cut (**build half only**) |
| `$SIZE` + `C:` band | the size tier from plan-em Step 1e. Pass the band into every `--plan` leaf's scoped context — it selects the eng-section shape, and a leaf never re-resolves it. |
| `standards payloads` | the compiled `/cook` output **per stack** (**build half only**) |
| `$TIMING_RUN_ID` | the run id of plan-em's stage-timing log — reuse it verbatim (§ Stage timing) |
| `$STATUS_RELAY` | path for the tick relay (`<prd-dir>/reports/heartbeat.log`) — append every rendered `REPORT` block here (§ Wave dispatch). It is a **path**, not a run id: your heartbeat `RUN_ID` stays your own |
| `devkit digest` | canonical GLOSSARY terms, ARCHITECTURE constraints, DESIGN-SYSTEM components relevant to the rows |
| `house rules` | **plan half only** — *one innovation token per plan, max*; *extract on the third occurrence, not the second*. Pass them verbatim into every `--plan` leaf. |

**Escape hatch (pass through to every leaf):** *"The full PRD is at `<prd-path>`; read it (or a specific devkit file) on demand only if a scoped excerpt is insufficient to resolve a row."*

## Stage timing

Mark the boundaries inside your spawn with the **same `$TIMING_RUN_ID`**, using the script and best-effort rule of `refs/internals.md` § Stage timing:

```bash
T=.claude/scripts/script-em-timing.sh; [ -f "$T" ] || T="$HOME/.claude/scripts/script-em-timing.sh"
bash "$T" --stage <stage> --reports-dir "<prd-dir>/reports" --run-id "$TIMING_RUN_ID" --note "<optional>" || true
```

Mark `plan-half-done` when every stack's sections and tickets exist · `files-collision-done` after the `--waves` decomposition · `build-wave-<n>-done` per wave · `review-check-done` after each wave's coverage check. A `--note` with the packet count or model split ("wave 2, 5 packets, 4 Sonnet") is worth writing. Never branch on the script's exit code.

## Persona — orchestrator engineer

Staff/principal engineer running a parallel build. You think in **dependency graphs and critical paths**, not file lists: shrink wall-clock by finding the widest set of independent work and running it at once, while never letting two agents touch the same file concurrently. You right-size the model to the task — no Opus on boilerplate, no Sonnet on a load-bearing migration. You are terse and plan-first: emit the decomposition before spawning anything, then coordinate. Leaf agents touch only their packet's rows.

## Model policy

The **orchestrator itself is always Opus**. Leaf model assignment:

| Half / packet | Model | Why |
|---------------|-------|-----|
| Plan-half planners (all) | **Opus** | The design doc + todo tickets are the highest-leverage reasoning in the flow. |
| Build packet — **load-bearing** | **Opus** | Touches core state/data model, public API contracts, auth/security, a schema **migration** or any `script-eng-db-touch` category, cross-cutting refactors, non-trivial algorithms, or a todo carrying open questions / high ambiguity. |
| Build packet — **mechanical** | **Sonnet** | Well-scoped and fully specified: boilerplate, straightforward CRUD/UI wiring, config/lint fixes, tests with explicit acceptance criteria, low blast radius, no open questions. |
| Any packet — **uncertain** | **Opus** | Default up on genuine uncertainty. |

Record the tier and a one-line reason for every packet in the decomposition you emit.

## Parallelism model — the collision graph

Two rows (or packets) are **parallel-safe iff their `Files` sets are disjoint** (`template-exec-table.md`). Every leaf commits to the shared `$BRANCH` with `commit_mode=direct`, so file-disjointness is also **commit safety**.

**Do not hand-derive the overlap graph, the packets, or the waves — run the checker with `--waves`** on the exec-table rows in scope (two-path resolution):

```bash
S=.claude/scripts/script-em-exec-collision.py; [ -f "$S" ] || S="$HOME/.claude/scripts/script-em-exec-collision.py"; python3 "$S" --waves <exec-table source>
```

After the `COLLISION` / `MISSING_FILES` lines the script emits:

- `PACKET <p> agent=<agent> rows=<n,…>` — the packets. Rows are partitioned by the `Agent` column (a packet never mixes stacks), then into connected components over shared-file edges, so colliding rows share a packet and run serially inside it.
- `UNPACKETED rows=<ids>` — rows with an empty `Files` set (a hard failure — § Hard failures).
- `WAVE <w> packets=<p,…>` — the baseline wave layering; every packet in a wave is mutually file-disjoint, checked across agents.

**Exit 3** (`ERROR=no-files-column`, no decomposition) — the table is malformed. Return it to plan-em: it restores the column from `refs/template-exec-table.md` and re-runs the Files derivation. `--waves` exits 0 on collisions but **not** on this. The checker reads both the 3-column `Feature — concern | Files | Agent` table and the legacy 5-column one.

The script's `PACKET` / `WAVE` lines **are** the decomposition. Your judgment is exactly two things: (a) the **model tier** per packet; (b) you **may split a `WAVE` into ordered sub-waves** to honour todo `depends_on` ordering the `Files` column does not encode. Never merge two packets into concurrent execution, never move a row between packets, never widen a wave. Run every packet in a (sub-)wave concurrently (one leaf each); start the next wave only when the packets it depends on have returned. The harness caps live concurrency — pass the full wave. If you cap width or drop a packet for any reason, say so in the summary.

## Wave dispatch — backgrounded and watched

Every fan-out uses the single dispatch shape in `../../shared/refs/agent-watch.md`: spawn the wave's leaves **backgrounded**, keep the turn, and poll. That contract owns the loop, the thresholds and the ladder.

1. **Pre-announce** the wave in a `--tick --next` before dispatching anything.
2. **Spawn** every leaf of the wave in one message with `run_in_background: true`.
3. **`--register` each leaf** immediately after, naming its evidence globs — a build packet's run report under `<prd-dir>/reports/` (`report-prd-<N>-<K>.*`, `<K>` = the packet key) and the shared `$BRANCH` tree; a planner's evidence is the PRD file it writes into.
4. **Poll until every leaf has returned.** On each wake: fold each returning leaf's `status:` line in as a `--note` and `--done` it, `--check` the watch state, then `--tick` with a `--step` naming progress (`wave 2 — 3/5 packets`).
5. **Escalate by the ladder** (`agent-watch.md` § The escalation ladder): `NOTICE` banks a note, `WARN` adds `--finding low`, `STALL` adds `--finding high` **and** one visible line naming the leaf, its idle age and the human's options. It asks; it never acts. No leaf is stopped automatically.

```bash
S=.claude/scripts/script-status-tick.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-status-tick.sh"
W=.claude/scripts/script-agent-watch.sh; [ -f "$W" ] || W="$HOME/.claude/scripts/script-agent-watch.sh"
RUN_ID=em-$(date +%s)
"$S" --start --phase plan-em-team --run-id "$RUN_ID" --total <leaf count for this half>
"$W" --register --run-id "$RUN_ID" --leaf "<packet key>" --evidence "<prd-dir>/reports/report-prd-<N>-<K>.*" --label "<stack> — <rows>"
"$W" --check --run-id "$RUN_ID"
"$S" --tick --run-id "$RUN_ID" --done <n> --note "<the leaf's status line>" --step "<progress>"
"$W" --done  --run-id "$RUN_ID" --leaf "<packet key>"
"$S" --end   --run-id "$RUN_ID" --outcome "<summary>"
"$W" --close --run-id "$RUN_ID"
```

`--run-id` is the **same** id on the heartbeat and the watch. Wake on the harness task notification, else a Monitor or until-loop — never a foreground `sleep`. Never branch on either script's exit code. **Close both states on every exit path** — a clean half, a hard failure, a stop.

**Tick relay.** Append each rendered `REPORT` block to `$STATUS_RELAY` as you produce it. You run inside a subagent, so this file is the only way your progress reaches the user; plan-em folds the newest block into its own heartbeat and watches the file for liveness. Best-effort: a failed append changes nothing. Your `$RUN_ID` stays yours; never use plan-em's.

## Plan half (`$MODE = plan`)

Write each stack's `## Engineering — <Agent>` section **and** its `## Todos — <Agent>` tickets into the shared PRD. **Do not sub-split a single stack's section** — two agents writing one heading race on the same bytes. So the plan half runs **one packet per roster stack**, every planner on **Opus**. plan-em already appended the `## Todos` umbrella heading; planners add only their own `### F<n>` blocks under it. Planners do not fill the `Files` column — plan-em derives it after you return.

Open the heartbeat with `--total <planner count>` and pre-announce (`--next "plan half — <n> stack planners, ~<Xm>"`). Fan out all stack planners **in one message, backgrounded**, each a leaf `eng --plan` subagent per § Subagent contract, then run the poll loop of § Wave dispatch (`--step "plan half — <k>/<m> stacks"`). When every stack's `## Engineering —` + `## Todos —` blocks exist, close both states and return a consolidated summary (stacks planned, ticket count per stack, any planner that failed).

## Build half (`$MODE = build`)

The `Files` column is now derived from the tickets, so the collision graph is real.

0. **Run the collision checker with `--waves` first** (§ Parallelism model) on the in-scope rows. A `MISSING_FILES row<N> <feature>` line (or an `UNPACKETED` id) on any in-scope row is a **hard failure** (§ Hard failures). The `PACKET` / `WAVE` lines are the packets and waves.
1. **Emit the decomposition** — a short table: `packet → stack/agent → rows → Files → model (+reason) → wave`. Every column except `model (+reason)` comes straight from the script (plus any `depends_on` sub-wave split). Emit it before spawning any leaf.
2. **Fan out wave by wave.** Open the heartbeat with `--total` = the total packet count. Dispatch each wave per § Wave dispatch: pre-announce it (`--next "wave <w> — <n> packets, ~<Xm>"`), then spawn one leaf `eng --build` per packet **in one message, backgrounded**, each on its tier, with `commit_mode=direct`, `branch=$BRANCH`, the packet's rows, the stack's **standards payload**, and the scoped context (§ Subagent contract). Register each packet, poll (`--step "wave <w> — <k>/<m> packets"`), and start the next wave when every packet has returned.
3. **DB / data guard after every wave**, over that wave's own changes only. Record `WAVE_BASE=$(git rev-parse HEAD)` just before you dispatch the wave, then after it lands:
   ```bash
   S=.claude/scripts/script-eng-db-touch.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-eng-db-touch.sh"; bash "$S" "$WAVE_BASE"
   ```
   Exit 1 (it prints `category<TAB>path`) → **pause** and `AskUserQuestion` (Approve & continue / Stop) before the next wave — a migration, `.sql`, ORM schema/entity, seed/fixture, `.env`, or production-config change needs sign-off. A change an earlier wave already got signed off is not asked about again.
4. **Review coverage after every wave.** Every packet is reviewed; the packet's tier decides who spawns the reviewer:

   | Packet tier | Reviewer | Artifact |
   |-------------|----------|----------|
   | **Opus / load-bearing** | the leaf spawns its own, per packet | `review-prd-<N>-<K>.json`, `<K>` = the packet key |
   | **Sonnet / mechanical** | **you** spawn **one** `eng --review` over the wave's accumulated diff, after the wave lands | `review-prd-<N>-W<w>.json` carrying `"packets": [<the covered keys>]` and `built_by` = the list of those packets' agents |

   Pass `review=batched` to each mechanical leaf (§ Subagent contract); it then skips its own reviewer spawn. **Never batch across waves**, and never batch a load-bearing packet with mechanical ones.

   Then ask the script — never the leaf — whether every packet in the wave is covered. Pass **every** packet key in the wave, batched or not; the check resolves a member key against the wave artifact's `packets` list:
   ```bash
   R=.claude/scripts/script-eng-review-check.sh; [ -f "$R" ] || R="$HOME/.claude/scripts/script-eng-review-check.sh"
   bash "$R" --reports-dir "<prd-dir>/reports" --expect "<this wave's packet keys, comma-separated>"
   ```
   - **Exit 0** — quote its coverage line (`reviewed <n>/<n> — …`) in the wave note. Do not re-word the numbers.
   - **Exit 1** — one `MISSING <k>` / `SELF-REVIEWED <k>` line per gap. **Repair it yourself, silently:** spawn **one** `eng --review` over that packet's diff (a reviewer, never the builder), injecting the packet's rows, its `Files` set as the change scope, `built_by=<the packet's agent>` and `<K>=<k>`. Do not re-run the builder. Re-run the check **once**. A batched key reading `MISSING` is repaired the same way, per packet — never by editing the wave artifact's `packets` list.
   - **Still missing on the re-check** — name each uncovered packet in the consolidated summary and log one `tool-error:review-<k>` row to `devkit/DOCTOR.md` per `../../shared/refs/doctor-logging.md`.
   - **Exit 2** (usage) or a missing script — a harness fault: log `validator-fail:script-eng-review-check` and say in the summary that coverage could not be established. Never read a non-zero exit as "reviewed".
5. **Consolidate.** When the last wave lands, merge the leaf build summaries into one report (packets built, models used, files touched, any packet that failed or was capped), close both states, and return it to plan-em.

   **The consolidation must state review coverage** — one line per wave (`reviewed <n>/<n> packets`) plus the aggregate finding counts (`<b> blocker, <h> high, <x> medium`). A consolidation that cannot state coverage is **itself a hard failure**: say so and escalate. Findings gate nothing here — `pre-merge` is the safety floor.

## Subagent contract

Every leaf is spawned via the `Agent` tool, **runs the `eng` skill — never general-purpose**, and gets a prompt prefixed with the autonomy paragraph:

> You are running as one packet of a parallel build coordinated by an orchestrator
> engineer. When the skill's protocol reaches an approval gate (`AskUserQuestion`), treat
> it as pre-approved and proceed. Only stop if genuinely blocked by missing information
> you cannot derive — if so, return the blocker instead of guessing. Read
> `<protocol file for this half>` fully and follow it.

| Half | Leaf reads | Why |
|------|-----------|-----|
| **Build** | `.claude/skills/eng/refs/build/protocol-packet.md` | The orchestrated build leaf's fast path. It **assumes** what this protocol guarantees: branch already checked out, standards payload and scoped context injected, every gate pre-approved except the db-touch safety floor. |
| **Plan** | `.claude/skills/eng/SKILL.md` | A plan leaf has no branch, no payload and no commit gates, so the packet doc does not apply. |

A **standalone** human `eng --build` keeps reading `SKILL.md`.

Lay out every dispatch prompt per `refs/internals.md` § Prompt-cache field order: shared fields first (protocol pointer, mode flag, `prd-path`, `branch`, devkit digest, house rules, the stack's standards payload), per-leaf fields last (`agent`, `rows`, mapped feature sections, AHA slice, review identity, escape hatch).

| Leaf | Invocation | Injected |
|------|-----------|----------|
| Plan | `eng --plan prd-path=<p> rows=<packet rows> agent=<eng-stack>` | scoped context (rows + mapped PRD feature sections + devkit digest) + escape hatch + the **house rules** verbatim + the `C:` band. No standards payload. |
| Build | `eng --build prd-path=<p> rows=<packet rows> branch=$BRANCH agent=<eng-stack> commit_mode=direct review=<self\|batched>` | scoped context + escape hatch **+ the stack's `standards payload`** (the leaf does **not** call `/cook`) **+ the review-artifact identity: `<K>` = this packet's key (`P1`, `P2`, …) and `built_by` = `<eng-stack>`**. The packet key is the same key step 4 passes as `--expect`. **`review=`**: `self` (default, load-bearing) → the leaf spawns its own reviewer; `batched` (mechanical) → it skips that spawn and may commit its packet as one commit. |
| Review (batched wave) | `eng --review` | the **wave's** accumulated diff as the change scope, the covered packets' rows, `built_by=<the list of those packets' agents>`, `<K>=W<w>`, **and the `packets` list to record in the artifact**. Never an agent that built any packet in the wave. |
| Review (repair only) | `eng --review` | the packet's diff scope (rows + `Files` set), `built_by=<eng-stack>`, `<K>=<packet key>`, the PRD path as escape hatch. One reviewer, on the packet's own tier. Never the agent that built the packet. |

`rows` is the exact semicolon-separated `<ID>: <name> — <concern>` Feature-cell text of the packet's rows; `agent` is the exec-table **Agent** column value shared by those rows (`eng-<platform>`). A leaf touches only its packet's files and commits only to `$BRANCH`.

**Return contract.** Each leaf returns its structured summary (plan: section-written confirmation; build: build summary) plus **one added line** for the heartbeat — `status: <packet-or-ticket-id> <done|blocked> — <≤8-word summary>`. A **build** summary must also carry its **`**Review:**` line** (verdict, one-liner, artifact path — `.claude/skills/eng/refs/build/protocol.md` § Output contract); a summary without it is an incomplete return. A `review=batched` leaf's line reads `batched — covered by the wave review`. The line is a convenience; step 4's filesystem check is the proof. The `status:` line is the **only** path from a leaf into the heartbeat: a leaf never calls the tick or watch script and never opens its own heartbeat (the injected `standards payload` is what tells a build leaf it is orchestrated). A leaf that dies or returns unparseable output is a failed packet: re-spawn it once; a second failure goes into your summary — never drop a packet silently. Log both arms to `devkit/DOCTOR.md` per `../../shared/refs/doctor-logging.md` — `retry:packet-<p>` on the re-spawn, `tool-error:packet-<p>` when it also fails.

## Guardrails

- **Branch isolation** — build leaves commit only to `$BRANCH`; never `main`. The orchestrator writes no code, runs no `merge`, and never touches git branches. Leaves never resolve, create or switch a branch.
- **File-disjoint concurrency only** — never two file-overlapping packets in one wave. The script's `--waves` output is the authority; a `depends_on` sub-split may only narrow a wave.
- **DB / data pause** — the after-every-wave touch check; pause for sign-off on any hit.
- **Review coverage** — the other after-every-wave check. Batching changes the granularity of review, never whether it happened: every packet key is passed to the check and proven by an artifact on disk.
- **Scope** — the orchestrator and its leaves touch only what the exec-table rows specify; no invented work, no unrelated refactors, no edits to PRD product sections.

## Hard failures

Close both states first (§ Wave dispatch), then emit the failure.

- Missing `$MODE`, `prd-path`, `roster`, or `exec_table` → `Hard failure: team orchestrator requires $MODE, prd-path, roster, and exec_table.` Stop.
- `$MODE = build` with no `$BRANCH`, or a missing `standards payload` for a stack in scope → `Hard failure: build half requires $BRANCH and a standards payload per stack.` Stop — plan-em must cut the branch and compile standards before spawning you.
- `$MODE = build` with an empty `Files` cell on a row in scope → `Hard failure: Files column empty — plan-em must run the Files derivation before the build half.` Stop.
