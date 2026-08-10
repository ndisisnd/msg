---
skill: plan-em
canonical: .claude/skills/plan-em/SKILL.md
status: phase-0-audited-blocked-on-deviations
assertions:
  - PEM-CX-001
  - PEM-CX-002
  - PEM-CX-003
  - PEM-CX-004
  - PEM-CX-005
  - PEM-CX-006
  - PEM-CX-007
  - PEM-CX-008
  - PEM-CX-009
  - PEM-CX-010
  - PEM-CX-011
  - PEM-CX-012
  - PEM-CX-013
  - PEM-CX-014
  - PEM-CX-015
  - PEM-CX-016
  - PEM-CX-017
  - PEM-CX-018
  - PEM-CX-019
  - PEM-CX-020
  - PEM-CX-021
  - PEM-CX-022
  - PEM-CX-023
  - PEM-CX-024
evals:
  - plan-em-mode-preference
  - plan-em-preflight-and-resume
  - plan-em-certification-and-roster
  - plan-em-solo-medium-fused
  - plan-em-team-medium-fused
  - plan-em-solo-large-plan-build
  - plan-em-team-large-plan-build
  - plan-em-team-collision-and-models
  - plan-em-team-watch-and-relay
  - plan-em-review-coverage-repair
  - plan-em-db-pause-and-branch-safety
  - plan-em-interruption-recovery
  - plan-em-synthesis-and-closing
  - plan-em-shared-contracts-and-closure
---

# plan-em compatibility map

Phase 0 has mapped the complete `plan-em` manager/orchestrator contract. The map does not
approve any Codex translation. Team orchestration, model tiers, direct subagent questions,
paths, and host permissions remain user-decision blockers.

## Canonical entry point and digest

- Entry point: `.claude/skills/plan-em/SKILL.md`.
- Entry digest: `79e1da0a4addbc0ced913fae30a2cb998ad9439704a1ee04c103fca35b1a4750`.
- Scoped files discovered/mapped: **4/4**.
- Intended destination: `.agents/skills/plan-em/CLAUDE-SKILL.md` plus relative refs;
  generation is blocked on `DEV-CX-002`.

## Canonical file coverage

| Canonical path | SHA-256 | Kind | Consumer / load condition | Proposed Codex path | Translation and proof |
|---|---|---|---|---|---|
| `.claude/skills/plan-em/SKILL.md` | `79e1da0a4addbc0ced913fae30a2cb998ad9439704a1ee04c103fca35b1a4750` | entry/router | Every invocation; validates PRD and selects persisted team/solo lane | `.agents/skills/plan-em/CLAUDE-SKILL.md` | generated-copy target; runtime adapter pending; `PEM-CX-001..003`, mode/preflight evals |
| `.claude/skills/plan-em/refs/protocol-em.md` | `9194f2abafc3e714854e9d95d6435b98422921338e895676f42da9c4d0a44f06` | primary protocol | Every valid invocation, all five steps; solo dispatch and team handoff | same relative path | generated-copy target; `PEM-CX-002..018`, all flow evals |
| `.claude/skills/plan-em/refs/protocol-team.md` | `8ee7ea959f85e719fb17b2bfdbe3745924335e4d1f6d6b91c6d45f822bdc13d9` | conditional orchestrator protocol | Team lane only; `plan`, `build`, or `fused` backgrounded coordinator | same relative path | generated-copy target; subagent/model translation pending; `PEM-CX-012..022`, team evals |
| `.claude/skills/plan-em/refs/template-exec-table.md` | `c86f7aa58d8de702e4488ddac3ee59e6894dc18a88ea34c2be6a010b3d6c1f0c` | schema/template | Roster-approved skeleton judgment/render; later Files derivation and collision graph | same relative path | generated-copy target; `PEM-CX-008/009`, roster/flow evals |

## Reference graph and mode state machine

```text
plan-em router → protocol-em steps 0–5
  ├─ team pref / inline flag → team (default) or solo
  ├─ product certification → plan-review --product when needed
  ├─ roster gate → exec-table template + deterministic renderer
  └─ size + PRD evidence chooses MODE
       medium + missing sections → fused
       medium + all sections     → build (interruption resume)
       large  + missing sections → plan
       large  + all sections     → build

Step 4 lane
  solo → direct eng leaves per roster stack
  team → one watched orchestrator reading protocol-team
            plan: one Opus planner per stack
            build: collision-script packets/waves + tiered build/review
            fused: plan → Files/shape → branch/stamps → build in one spawn
```

Run-state JSON helps resume returned build agents but never selects mode, verdict, or
heartbeat state. PRD evidence wins; stale state is archived. A medium interrupted after
planning resumes at build. A large plan wave ends and a new invocation builds.

## Trigger, flags, inputs, and refusals

| Contract | Required Codex behavior |
|---|---|
| Invocation | Proposed `$plan-em <prd>` only after `DEV-CX-001`; preserve natural-language triggers and runtime-correct handoffs. |
| PRD | Existing `.md` under planned/wip/done top-level or nested lifecycle path, or legacy flat equivalent. Missing/invalid refuses before output writes. |
| Lane flags | `--team`/`--solo` mutually exclusive; inline wins and persists; local pref then global; absent defaults team without creating a file. |
| Heartbeat flags | `--quiet`/`--status <n>m`, flag > policy > default; only orchestrators speak. |
| Human inputs | Open-state Resume/Fresh/Abort; dependency conflict only; uncovered platform; one roster approval; never-preapproved DB pause; batched synthesis Critical decisions. |
| No extra sizing flag | Intake `C:` alone selects medium/large; unresolvable defaults medium. |

## End-to-end behavioral map

### Pre-flight, certification, roster

- Resolve matched `$PRD_DIR` once. Read AHA, GLOSSARY, ARCHITECTURE, canonical project
  instructions, DESIGN-SYSTEM, OPEN-QUESTIONS, then the deterministic plan digest. Missing
  devkit stops; missing individual files warn; full PRD prose is escape-hatch-only.
- Open state asks Resume/Fresh/Abort, except autonomy pre-approves Resume. Fresh archives;
  corrupt/closed is fresh, and corrupt existing state logs an incident.
- Cross-PRD scan compares only the certified `deps` graph. Clean graph asks nothing.
  Genuine contradiction asks Trust/Amend/Stop; amendments update frontmatter and mirrored
  dependency cell through the writer. Scanner infrastructure failure logs and continues
  with an empty prior inventory.
- Findings produce/replace `preflight.md`; clean scan writes no file and deletes a stale
  one. Inline output contains only actionable findings; clean emits the exact clean line.
- Product certification is an automatic precondition. First uncertified is expected and
  invokes `plan-review --product`; still uncertified after repair stops/logs. Large build
  likewise runs eng certification/`plan-review --eng`; medium never does and must use the
  mechanical plan-shape gate instead.
- Standards derive explicit, conservatively scoped per-stack `cook` flags and use the
  persistent source-hash cache before one call per distinct stack. Unsupported platforms
  pause. Agent identity comes from supported stack flags, never PRD guesswork.
- The roster is one stack/language agent each, preceded by product intent and followed by
  one approval/revise gate. It is approved per PRD and is not re-asked on build resume.
  The deterministic skeleton writes the sole reserved three-column table; Files stays
  blank until derived from tickets. Missing ticket blocks re-dispatch their planner;
  nobody hand-fills Files.

### Solo lane

- Plan: one parallel `eng --plan` leaf per roster stack, inherited model, shared stable
  prompt head, row-scoped tail, house rules, injected grade, no standards payload. The
  manager creates the sole `## Todos` umbrella before fan-out. Leaves write their own
  engineering/todo blocks; the manager stamps `specced` after all exist.
- Build: large-only eng certification, then one resolver decides branch create/checkout/
  fresh-cut and lane move. The manager alone executes emitted git/lane operations and
  stamps `wip` (not a sub-PRD). Collision checker prevents overlapping agents running
  concurrently. One packet leaf per stack receives the packet protocol, checked-out
  branch, scoped context, standards, agent key, and builder identity.
- Resumed solo build dispatches only state agents not marked done. It verifies review
  coverage across all dispatched identities, repairs each gap with a separate reviewer
  once, and hard-fails a synthesis that cannot state coverage.

### Team lane

- Plan-em remains thin: after identical preconditions it starts its own heartbeat/watch,
  spawns one deep-tier orchestrator asynchronously, registers heartbeat/report evidence,
  holds the turn, polls, folds only inner REPORT body lines into outer notes, never shares
  run IDs, never kills a stalled coordinator, and closes both states on every exit.
- The coordinator is non-coding. It consumes roster, rows, standards, digest, size/grade,
  timing ID, relay path, and branch for build only. It never re-certifies, re-runs cook, or
  resolves a branch except at the documented fused midpoint.
- Team plan remains one planner packet per stack because duplicate section writes race.
  All plan leaves use the deep tier. Team build must consume `PACKET`/`WAVE` output from
  the collision script. It may only sub-split a wave for ticket dependencies, never merge
  packets, move rows, widen concurrency, or silently drop/cap work.
- Model policy is semantic intent: deep coordinator/planners; deep load-bearing/uncertain
  packets; fast mechanical packets. The exact Codex model mapping is pending. Every packet
  records tier and reason.
- Every wave is backgrounded, registered, polled, and ticked from return status lines.
  Watch tiers are observational. Stalls ask the user and never stop work. Packet death or
  unparseable output retries once then escalates/logs.
- After every build wave: run the never-preapproved DB/data guard; deep/load-bearing leaves
  self-spawn independent reviewers; the coordinator creates one batch review for fast
  mechanical packets in that wave; filesystem coverage checks all keys. Missing/self
  review is repaired by a separate reviewer once, never by rebuilding or editing evidence.
  Coverage failure is explicit and prevents a green-looking consolidation.

### Medium fused and large two-wave paths

- Medium fused performs product cert → plan half → Files derivation → per-agent plan-shape
  gate with one repair → branch/lane/status → collision decomposition → build/review → one
  synthesis. No eng certification. A red post-repair shape check stops before any build.
- In team fused, the single coordinator owns the midpoint branch operation because the
  parent cannot interject into one async spawn. This is its only branch authority; leaves
  still never touch branch state.
- Large plan ends after engineering/todos/specced and recommends re-running plan-em. Large
  build is a new invocation, reuses roster, certifies engineering, resolves branch once,
  builds/reviews, and recommends pre-merge.
- Lifecycle stamps fire on work state, not invocation boundary: `specced` when plans/todos
  exist; `wip` when branch exists. Pre-v5 and sub-PRD carve-outs stay intact.

### Synthesis and terminal

- Synth slice is the normal source; prose is section-specific escape hatch only. Fused
  gets one ~5-line combined summary. Large plan/build gets one paragraph per agent.
- Findings retain Critical/Major/Minor, location, and action. Critical decisions are
  batched and applied; cert-contract failures rerun certification rather than hand patch.
- State closes `ok`/`failed`; an abandoned gate stays open for recovery. Closing message
  is last and comes from the exact plan/fused/build registry row. Plan-em recommends but
  never invokes the next stage.

## Subagent packets, ownership, concurrency, interrupt/watch/resume

| Actor | Owns | Must not |
|---|---|---|
| plan-em root | pre-flight, certs, roster gate, skeleton, standards; solo branch/lane/stamps; team outer watch; synthesis | write source, merge, duplicate leaf work |
| team coordinator | authoritative decomposition, tier choice, async waves, inner watch/relay, DB pause, review batches/repair, consolidation; fused midpoint branch only | write plans/code; re-cert/cook; widen waves; use outer run ID |
| plan leaf | one stack's engineering/todo blocks | create umbrella; standards/build/git; write another stack's section |
| build leaf | packet ticket files/commits and self-review when assigned | branch operations, cook, PR, tick/watch, report source, other packet files |
| review leaf | whole packet/wave diff and atomic evidence | share any builder identity; invent keys/coverage; rebuild commits |

Codex has explicit async spawn/wait and model overrides. That capability is mapped, not
assumed equivalent: finite concurrency, background spelling, direct leaf questions, and
pause/resume ownership remain pending deviations. A stalled Codex thread must never be
auto-interrupted. User steering resumes through the existing root/orchestrator and must
not reorder packets or bypass coverage.

## Tool, path, environment, command, hook/state map

| Claude dependency | Proposed Codex semantic operation | Status |
|---|---|---|
| `Agent`, `run_in_background`, notifications/Monitor | `spawn_agent`, async thread status, `wait_agent`, follow-up/message relay | Pending `DEV-CX-005`; current four-slot cap cannot silently narrow/drop packets. |
| `model: opus/sonnet` | explicit capability-tier model override | Pending `DEV-CX-006`; no family chosen. |
| `AskUserQuestion` | same decision/options/pause at same authority owner | Pending `DEV-CX-003`; background leaf DB pause requires exact user relay or deviation. |
| `Skill(plan-review/cook/eng)` | explicit corresponding Codex skill use | Pending `DEV-CX-001/003/008`. |
| Read/Edit/Write/Bash | Codex filesystem patch/read/shell under same write boundaries | Pending `DEV-CX-003/007`. |
| `.claude/scripts` → `$HOME/.claude/scripts` | repo-local → installed Codex helper resolver | Pending `DEV-CX-002`; no Claude-home dependency. |
| `.claude/msg/pref.json`, cache, status/watch state | Codex-local equivalents preserving schema/precedence; canonical source remains unchanged | Pending `DEV-CX-002`; do not overwrite Claude prefs/cache. |
| `$CLAUDE_PROJECT_DIR`, `$HOME`, `MSG_STATUS_INTERVAL`, `MSG_WATCH_THRESHOLD` | validated project/home roots and same helper env semantics | Pending path/env classification; status/watch values remain exact. |
| `CLAUDE.md` plus devkit | read canonical project constraints while also obeying `AGENTS.md` | Pending `DEV-CX-004`; conflicts cannot be silently resolved. |
| `git checkout/-b/push`, `python3`, `bash`, `awk`, `cook` | same command intent/order and sandbox approvals | Pending `DEV-CX-007/008`. |
| Claude hooks/settings/allowed tools | Codex sandbox and skill contract | Pending `DEV-CX-007`; state/write authority must be host-enforced as far as possible. |
| Anthropic prompt prefix cache | preserve stable-head/tail bytes and same-stack contiguity | Cache-hit/performance parity unproven; pending candidate, never a behavior excuse. |

## Deterministic helper closure

| Helper | Exact owned behavior |
|---|---|
| `script-prd-digest.py` | plan/synth slices and PRD-evidence mode selection |
| `script-prd-scan.sh` | lane-aware prior PRD inventory/deps |
| `script-prd-deps-mirror.sh` | dependency frontmatter/table writeback |
| `script-cert-status.sh` | product/eng certification repair-once preconditions |
| `script-standards-cache.py` | per-stack cook payload cache |
| `script-em-exec-skeleton.py` | sole skeleton renderer and Files derivation |
| `script-em-exec-collision.py` | authoritative collisions, packets, waves, missing-files error |
| `script-eng-plan-shape.py` | medium fused eng-cert replacement and plan contract gate |
| `script-em-branch-resolve.sh` | read-only parent-aware action/branch/lane resolver |
| `script-prd-stamp.sh` | lifecycle stamps |
| `script-em-state.py` | best-effort open/resume/archive/agent/coverage/close state |
| `script-em-timing.sh` | append-only best-effort structural stage boundaries |
| `script-status-tick.sh` | inner/outer observational heartbeats |
| `script-agent-watch.sh` | observational registration/idle tiers/closure |
| `script-eng-db-touch.sh` | after-wave never-preapproved production/data pause |
| `script-eng-review-check.sh` | review artifact coverage/self-review proof |
| `script-aha.sh` | conditional sole AHA writer |
| `script-doctor-log.sh` (shared contract) | incident logging only |

## Shared and cross-skill closure

| Dependency | Edge | Proof |
|---|---|---|
| `shared/refs/exec-mode-pref.md` | local/global team/solo schema, seed/read/persist precedence | `PEM-CX-002`, mode eval |
| `shared/refs/session-cache.md` | digest and standards cache remain source-keyed/disposable | `PEM-CX-005`, closure eval |
| `shared/refs/status-heartbeat.md` | checkpoint/relay/run-ID/only-orchestrator semantics | `PEM-CX-016`, watch eval |
| `shared/refs/agent-watch.md` | async wave poll, liveness evidence, informational ladder, no auto-stop | `PEM-CX-017`, watch eval |
| `shared/refs/safety-floor.md` | branch authority and always-on DB/data pause | `PEM-CX-019`, safety eval |
| `shared/refs/finding-schema.md` | review artifacts/findings and identity proof through eng | `PEM-CX-020`, review eval |
| `shared/refs/doctor-logging.md` | every unexpected helper/tool/retry/write incident, no verdict change | `PEM-CX-023`, closure eval |
| `shared/refs/closing-message.md` | exact plan/fused/build final handoff, last output | `PEM-CX-024`, synthesis eval |
| `plan-review` | product auto-cert; large eng auto-cert; repair-once | `PEM-CX-006`, cert eval |
| `cook` | supported-stack authority and compile-once payload | `PEM-CX-007`, roster eval |
| `eng --plan/--build/--review` | owned leaves and independent review repair | `PEM-CX-011..021`, lane evals |

## Allowed writes and forbidden writes

Allowed manager writes are exact: inline-flag preference; `preflight.md`; PRD dependency
mirror, single exec skeleton/Todos umbrella, lifecycle stamps; AHA/DOCTOR; em state;
timings/heartbeat relay; branch/lane operations at the documented manager/fused-owner
point. Eng/reviewer leaves own their separately mapped writes.

Plan-em and its coordinator must never implement source, merge, write another agent's
section/tickets, hand-type Files, duplicate the exec table, falsify review artifacts,
reuse a shipped branch, stamp a sub-PRD, auto-kill a stalled leaf, or bypass a
certification/shape/DB/review-coverage gate.

## Output and artifact map

- Optional full `preflight.md`, otherwise exact clean inline line and no stale file.
- Product-intent + approved roster table, deterministic exec skeleton, Files derivation.
- Engineering/todo blocks in PRD; status `specced`/`wip`; feature branch/lane state.
- Per-packet/agent build summaries and review artifacts; heartbeat relay; append-only
  timings; resumability JSON; synthesis with explicit review coverage.
- Suggested branch only for plan wave; actual branch for fused/build. Final next step is
  registry-derived and runtime syntax remains pending.

## Pending deviations — implementation blockers

No difference is accepted. `DEV-CX-001..008` all apply. Additionally:

1. Direct user questions from a background leaf (especially the never-preapproved DB
   pause) have no proven Codex-equivalent UI/ownership path; pending new candidate.
2. Codex supports concurrent async threads but presently exposes a finite four-slot team.
   Queueing may preserve results while changing concurrency/timing; no packet may be
   dropped or serialised silently. Pending under `DEV-CX-005` or a new candidate.
3. Exact Opus/Sonnet capability/cost intent needs approved Codex tier assignments.
4. Anthropic prefix-cache behavior is not portable even though stable prompt ordering is;
   pending performance-only candidate.
5. Claude project/home/pref/cache paths and `CLAUDE.md`/`AGENTS.md` coexistence require an
   approved resolver/conflict rule before adapter work.

## Parity assertions

| ID | Assertion |
|---|---|
| `PEM-CX-001` | Trigger/path lifecycle patterns and hard refusals are exact and write nothing on invalid input. |
| `PEM-CX-002` | Team/solo flag, persistence, local/global precedence, default, and mutual exclusion are exact. |
| `PEM-CX-003` | Intake grade and PRD engineering evidence select medium/large and fused/plan/build exactly. |
| `PEM-CX-004` | Open/corrupt/closed run state preserves Resume/Fresh/Abort, archive, PRD-wins, and agent-skip behavior without carrying verdict. |
| `PEM-CX-005` | Pre-flight read order, digest escape hatch, missing-file rules, deps conflict gate, preflight artifact lifecycle, and size resolution match. |
| `PEM-CX-006` | Product and large-eng certifications run inline, repair once, and block dispatch if still uncertified; medium uses shape gate only. |
| `PEM-CX-007` | Cook flag scoping/cache, supported-platform authority, one-agent-per-stack roster, intent preface, and one per-PRD approval are identical. |
| `PEM-CX-008` | Skeleton has one reserved home, deterministic F-ID/name/concern/agent rows, blank Files, and never duplicates/hand-types. |
| `PEM-CX-009` | Files derivation, missing-ticket repair, collision errors, and three-/five-column compatibility remain mechanical and authoritative. |
| `PEM-CX-010` | Scoped prompt packets preserve stable/varying fields, grade/house rules/standards/escape hatch, and exact row ownership. |
| `PEM-CX-011` | Solo plan/build fan-out remains one leaf per stack, parallel only when safe, with correct models/payloads/keys and resume skips. |
| `PEM-CX-012` | Team root spawns exactly one non-coding deep coordinator and preserves outer/inner ownership boundaries. |
| `PEM-CX-013` | Team plan remains one deep planner per stack and never splits concurrent writers of the same heading. |
| `PEM-CX-014` | Collision script packets/waves are authoritative; only dependency sub-splits are allowed; no silent cap/drop/widening occurs. |
| `PEM-CX-015` | Deep/fast model intent and per-packet reasons preserve load-bearing/mechanical/uncertain routing, pending approved model IDs. |
| `PEM-CX-016` | Heartbeats retain checkpoint cadence, leaf status ownership, relay content, disjoint run IDs, and all-exit closure without affecting verdict. |
| `PEM-CX-017` | Watch registration/poll/tier ladder remains observational, never busy-waits or auto-stops, and closes on every exit. |
| `PEM-CX-018` | Medium fused and interruption-resume ordering, shape repair-once, lifecycle triggers, and single synthesis are exact. |
| `PEM-CX-019` | Branch/lane resolver authority, shipped/sub-PRD carve-outs, feature isolation, and every after-wave DB pause are exact. |
| `PEM-CX-020` | Independent self/batch/repair review routing and atomic filesystem coverage are proven for every packet/agent/wave. |
| `PEM-CX-021` | Dead/unparseable leaves retry once, review gaps repair once, and residual failures escalate/log without rebuild or fabricated evidence. |
| `PEM-CX-022` | Stage timing/state/status/review consolidation remains complete, append-only/best-effort where specified, and cannot produce false green. |
| `PEM-CX-023` | Manager/coordinator/leaf write ownership, scope, incident logging, and forbidden source/merge actions never broaden. |
| `PEM-CX-024` | Synth output shape, batched Critical handling, state closure, registry handoff, and closing-message position are exact. |

## Concrete eval cases

| Eval | Fixture/action | Required observations | Assertions |
|---|---|---|---|
| `plan-em-mode-preference` | absent/local/global/corrupt prefs; solo/team/both flags | exact precedence/persist/strip/default/failure; no unwanted creation | 001,002 |
| `plan-em-preflight-and-resume` | clean/findings/stale preflight; missing devkit/file; open/corrupt/stale state; deps conflict | exact reads/questions/writes/deletes/archive and PRD-evidence winner | 004,005,023 |
| `plan-em-certification-and-roster` | unreviewed then repaired; still critical; warm/miss cook; uncovered platform; revised roster | cert order/block; one cook/stack; intent+one gate; deterministic table | 006..009 |
| `plan-em-solo-medium-fused` | `C:5`, two stacks, clean packets | one cert; plan/Files/shape/branch/build/review/synth order; both stamps | 003,006,009..011,018..020,024 |
| `plan-em-team-medium-fused` | same fixture, team default | one coordinator; one inner run; fused midpoint owner; packet waves; one synthesis | 012..020,022,024 |
| `plan-em-solo-large-plan-build` | `C:8`, two invocations | product cert then plan+specced; second invocation reuses roster, eng cert, branch/build | 003,006..011,019,024 |
| `plan-em-team-large-plan-build` | same, team lane | one coordinator per invocation; no re-cert/cook/branch inside non-fused coordinator | 006,012,013,019,022 |
| `plan-em-team-collision-and-models` | overlapping rows, dependency split, migration, CRUD, uncertain packet | script packets unchanged; waves only narrowed; deep/fast intent and reasons; no drop | 009,014,015,023 |
| `plan-em-team-watch-and-relay` | slow/notice/warn/stall/returning coordinator and leaf, append miss | background poll; REPORT-body relay; distinct IDs; no auto-stop; all states close | 016,017,022 |
| `plan-em-review-coverage-repair` | deep artifact, batch artifact, self/missing/malformed evidence | all keys checked; separate reviewer once; no builder rerun/evidence edit; explicit residual fail | 020,021,022 |
| `plan-em-db-pause-and-branch-safety` | data file after wave, shipped branch, sub-PRD, attempted leaf branch/main operation | human pause; resolver action exact; only owner mutates branch; unauthorized writes absent | 019,023 |
| `plan-em-interruption-recovery` | die after plan half and after one build leaf | medium resolves build; state skips done leaf; stale disagreement archives; coverage still complete | 003,004,018,020..022 |
| `plan-em-synthesis-and-closing` | fused clean/warn, large plan, large build, Critical synth question, hard fail | exact summary tier, finding fields, state result, branch line, registry step last | 022,024 |
| `plan-em-shared-contracts-and-closure` | digest/cache/watch/timing/state/log failures with helper stubs | documented exit semantics; no verdict drift; all 4 digests/edges and 18 helpers current | 005,009,016,017,022..024 |

## Coverage accounting

- Phase-0 mapping ratio — file: `4/4 = 1.0000`.
- Phase-0 mapping ratio — reference: `3/3 = 1.0000` scoped refs, with all `11/11`
  shared/cross-skill dependency edges mapped.
- Phase-0 mapping ratio — behavior: `2/2 = 1.0000` primary protocols, with all plan/build/fused and
  team/solo branches inventoried.
- Phase-0 mapping ratio — eval-specification: `24/24 = 1.0000` assertions linked to
  concrete eval designs.
- Phase-0 mapping ratio — dependency: `18/18 = 1.0000` direct and indirect helper
  closure (`17` direct plus the shared DOCTOR writer).
- Runtime proof = `not-run` (correct for Phase 0; adapter/eval execution remains blocked
  by pending deviation decisions).
