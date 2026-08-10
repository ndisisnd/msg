# Codex compatibility deviation gate

Status: **decision gate closed 2026-08-10.** All 16 runtime entries decided (14
approved, 2 rejected as deviations — canonical behavior preserved). Ambiguities:
all seven (AMB-CX-001..007) decided 2026-08-10.
User-directed canonical corrections applied same day (baseline re-frozen): kermit
PR mechanism (001), merge ENV.md read (002), blocker secret-scanner severity
(003), doctor-detect consumption by both inits (004), "success" closing wording
(006).

This ledger records every currently known difference between the canonical Claude
harness and a proposed Codex realization. A pending entry blocks implementation of the
affected behavior. Reclassification as a semantics-preserving translation also requires
explicit user approval.

## Pending deviations

| ID | Difference | Evidence or current proposal | Why it matters | Status |
|---|---|---|---|---|
| DEV-CX-001 | Invocation syntax | Claude uses `/skill`; Codex uses `$skill`. | Every menu, handoff, help route, and closing message changes visibly. | approved-translation |
| DEV-CX-002 | Discovery and installed paths | The plan proposes `.agents`; the pre-existing `harness-map.md` instead says Codex should install into `.claude` through symlinks. | The two approaches conflict. The wrong choice can create drift or make Codex mutate/depend on Claude state. | approved-translation |
| DEV-CX-003 | Tool and question bindings | Claude protocols name `AskUserQuestion`, `Agent`, `Skill`, and other Claude tools. The pre-existing map proposes prose questions and read-and-follow skill chaining. | UI, pause semantics, tool enforcement, and run continuity can differ. | approved-translation |
| DEV-CX-004 | Project instructions | Claude uses `CLAUDE.md`; Codex discovers `AGENTS.md`. The pre-existing map proposes `CLAUDE.md` first and `AGENTS.md` as fallback. | Conflicting files could change product and engineering decisions. | approved-translation |
| DEV-CX-005 | Subagent lifecycle | Claude background agents, polling, watch, steering, and relay must map to Codex collaboration. | Ownership, liveness, resume behavior, and independent review can change. | approved-translation |
| DEV-CX-006 | Model tiers | Canonical protocols name Opus and Sonnet. The pre-existing map replaces these with role TOMLs and inherited models/reasoning. | This is potentially semantic and may change quality, cost, or load-bearing capability. | approved-deviation |
| DEV-CX-007 | Permissions and hooks | Claude uses `allowed_tools` and `.claude/settings.json`; the pre-existing map proposes Codex hooks plus a trust probe. | Host-enforced authority may become behavioral guidance, or a silently untrusted hook may fail open. | approved-translation |
| DEV-CX-008 | External skills | msg integrates with optional `cook` and exposes `kermit`; Codex compatibility is not yet proven. | The core flow may hand off to a missing or different external contract. | approved-translation |
| DEV-CX-009 | Implicit invocation | Canonical descriptions allow natural-language activation. The pre-existing map disables Codex implicit invocation for every msg skill. | Users lose a supported trigger path, so this is not one-to-one behavior. | rejected |
| DEV-CX-010 | Heartbeat and stall watch | The pre-existing map removes hold-the-turn polling and replaces timed heartbeat/watch behavior with wave-boundary checkpoints. | Correctness may remain, but progress visibility and stall detection are observably reduced. | rejected |
| DEV-CX-011 | Subagent-owned human gate relay | Canonical build packets may surface the never-preapproved database/data pause from a leaf. Codex subagents may need to return that gate request to the root thread. | Gate ownership and resume flow change unless an exact relay is proven. | approved-translation |
| DEV-CX-012 | Prompt-cache behavior | Claude team prompts deliberately use byte-identical stable heads for Anthropic prefix caching. Codex can preserve ordering but the same cache semantics/performance are not established. | Functional output may match while the promised cost/performance behavior does not. | approved-deviation |
| DEV-CX-013 | Concurrency width and scheduling | Canonical background/queued waves and the current Codex thread cap expose different scheduling mechanics. | Dependency order can match while wave width, queuing, timing, and status cadence differ. | approved-deviation |
| DEV-CX-014 | GUI prompt runner and quick actions | `msg` GUI defaults `/api/prompt` to `claude -p` and hardcodes Claude slash commands and wording. | Without a Codex runner and `$skill` UI mapping, the interactive Prompt console remains Claude-only. | approved-translation |
| DEV-CX-015 | Host GUI approval | `emulate` must launch macOS GUI applications. Codex's host sandbox may require an explicit approval before commands such as `open -a Simulator` can run. | A new approval pause would make a previously automatic launch observably different. | approved-deviation |
| DEV-CX-016 | Emulator process lifetime | Claude's emulator protocol uses background execution to keep the development server alive after the skill finishes. Codex can yield a live terminal session, but equivalent post-turn lifetime and cleanup have not yet been proven. | The skill could report success while the server exits, leaks, or no longer serves the opened simulator. | approved-translation |

## Full deviation records

Every record below is an implementation stop. “Proposed” means the smallest mapping
to evaluate; it is not permission to implement it.

### DEV-CX-001 — invocation syntax

- **Canonical behavior:** Skill entry points, handoffs, menus, GUI actions and closing
  messages use `/msg`, `/intake`, `/plan-pm`, `/plan-review`, `/plan-em`, `/eng`,
  `/pre-merge`, `/merge` and `/emulate`. Sources: all nine canonical `SKILL.md`
  files, `shared/refs/closing-message.md`, `shared/refs/fix-loop.md`, and
  `msg/refs/gui/index.html`.
- **Blocking Codex constraint:** Codex skills are installed under `.agents/skills`
  and explicitly invoked as `$skill`; `/...` is the host's command surface.
- **Alternatives attempted:** Preserve natural-language triggers; inspect a slash
  alias/custom-prompt route; retain slash text only as quoted Claude documentation.
  None provides the same skill invocation without colliding with host commands.
- **Proposed difference:** Translate only active-runtime invocation tokens and
  handoffs from `/name` to `$name`; keep mode flags and intent routing unchanged.
- **User/product impact:** Commands are visibly different, while selected workflows
  and outputs should remain the same.
- **Compensating control:** Token-aware generation plus golden checks that reject
  stray active-runtime slash handoffs and reject changes inside canonical payloads.
- **Affected maps/assertions/evals:** All nine skill maps and the shared map; every
  trigger, handoff, menu, GUI quick-action and closing-message assertion/eval.
- **Decision:** `approved-translation` — user approved 2026-08-10. Translate
  active-runtime `/name` tokens to `$name` under the stated compensating controls.

### DEV-CX-002 — discovery and installed paths

- **Canonical behavior:** Runtime assets resolve repo-local `.claude/skills` and
  `.claude/scripts`, then Claude home fallbacks; `install.sh` installs Claude assets.
  Sources: all canonical entry points with helper lookup, `install.sh`,
  `shared/refs/session-cache.md`, and `shared/refs/exec-mode-pref.md`.
- **Blocking Codex constraint:** Codex's documented team and personal skill roots are
  `.agents/skills` and `$HOME/.agents/skills`; a Codex-only install must not depend on
  mutable Claude installation state.
- **Alternatives attempted:** Reuse `.claude` directly, symlink it, dual-write both
  roots, or place a resolver in each skill. Direct reuse/symlinks violate isolation;
  dual-write risks drift; per-skill resolvers duplicate policy.
- **Proposed difference:** A single Codex resolver and separate Codex installer use
  repo-local `.agents` first and Codex home second. Claude locations remain read-only
  migration inputs only if the user explicitly enables them.
- **User/product impact:** Installed paths differ, but a Claude install remains
  byte-stable and Codex works independently.
- **Compensating control:** Temporary-home isolation evals snapshot `.claude` before
  and after installation and require identical bytes.
- **Affected maps/assertions/evals:** All maps that resolve helpers, references,
  preferences or cache state; installer, packaging, path-precedence and isolation
  assertions/evals.
- **Decision:** `approved-translation` — user approved 2026-08-10. Isolated
  `.agents` roots; no dependency on or mutation of Claude install state.

### DEV-CX-003 — tool and question bindings

- **Canonical behavior:** Protocols directly name Claude tools including `Read`,
  `Write`, `Edit`, `Bash`, `AskUserQuestion`, `Agent`, `Skill`, `WebSearch` and
  `WebFetch`. Sources: canonical skill frontmatter and all protocol/reference rows
  identified in the per-skill tool maps.
- **Blocking Codex constraint:** Codex exposes equivalent capabilities through
  different tool names and some question/agent controls vary by client surface.
- **Alternatives attempted:** Execute Claude tool tokens literally, use prose-only
  instructions, and inline called skills. Literal tokens do not bind; prose-only
  questions weaken structured gates; inlining breaks skill ownership.
- **Proposed difference:** Bind each semantic operation to the Codex-native tool,
  preserving inputs, authority, pause point, return data and continuation. If a
  surface cannot preserve a gate, that path blocks rather than falling back.
- **User/product impact:** Tool chrome can differ. Workflow decisions, artifacts and
  safety gates must not.
- **Compensating control:** A complete tool matrix and eval fixture for every binding,
  including cancel, unavailable-tool and resume paths.
- **Affected maps/assertions/evals:** All ten maps; all tool, user-gate, subagent,
  external-skill, web, write-boundary and failure-path assertions/evals.
- **Decision:** `approved-translation` — user approved 2026-08-10. User confirmed
  Codex hook surface is equivalent while tool names differ; bind each semantic
  operation to the Codex-native tool surface per the official tools guide
  (https://developers.openai.com/api/docs/guides/tools: web search, file search,
  tool search, function calling, programmatic tool calling, remote MCP servers,
  skills, shell, computer use, image generation). Exact gate/authority/pause-resume
  contract tests remain mandatory; a surface that cannot preserve a gate blocks.

### DEV-CX-004 — project instruction discovery

- **Canonical behavior:** Planning and engineering protocols read or assume project
  `CLAUDE.md`; msg init scaffolds `template-CLAUDE.md`. Sources:
  `msg/refs/init/templates/template-CLAUDE.md`, `plan-pm/SKILL.md`,
  `plan-em/SKILL.md`, `eng/SKILL.md`, and their scoped protocols.
- **Blocking Codex constraint:** Codex automatically discovers `AGENTS.md`, not
  `CLAUDE.md`; two independently editable instruction files can disagree.
- **Alternatives attempted:** Ignore `CLAUDE.md`, read it in addition to `AGENTS.md`,
  duplicate it, or generate a short `AGENTS.md` pointer. Ignoring loses canonical
  input; dual independent sources lack deterministic precedence; duplication drifts.
- **Proposed difference:** Preserve canonical `CLAUDE.md` as the product source and
  create/reconcile a minimal Codex-discovered pointer with an explicit conflict rule.
- **User/product impact:** Repositories gain or use an `AGENTS.md` entry point; an
  unresolved conflict must stop the run instead of silently changing a decision.
- **Compensating control:** Conflict fixtures, digest linkage and a no-overwrite gate
  for an existing human-authored `AGENTS.md`.
- **Affected maps/assertions/evals:** `msg`, `plan-pm`, `plan-em`, `eng`, plus any
  downstream context-precedence assertions/evals.
- **Decision:** `approved-translation` — user approved 2026-08-10. `AGENTS.md` is a
  thin pointer to `CLAUDE.md` (single source of instructions); if both exist with
  conflicting content the run stops rather than guessing. Matches the pointer
  design the earlier v6 branch reached independently.

### DEV-CX-005 — subagent lifecycle

- **Canonical behavior:** Orchestrators spawn named foreground/background agents,
  watch and steer them, preserve independent reviewer identities, relay artifacts and
  resume at phase gates. Sources: `plan-em/refs/protocol-team.md`, eng build/review
  protocols, `shared/refs/gate-dispatch.md`, `agent-watch.md` and `status-heartbeat.md`.
- **Blocking Codex constraint:** Codex uses child threads with spawn, wait, list,
  steer and interrupt semantics rather than Claude's `Agent` call contract.
- **Alternatives attempted:** Sequential execution, self-review, wave-only polling,
  and Codex child-thread orchestration. The first three weaken concurrency,
  independence or liveness; child threads remain the parity candidate.
- **Proposed difference:** Translate lifecycle operations to child threads while
  keeping packet ownership, identities, dependency waves, artifact relay and main
  thread gates exact.
- **User/product impact:** Thread presentation and timing can differ; responsibility
  and outcome must not.
- **Compensating control:** Stubbed lifecycle evals prove spawn counts, distinct run
  IDs, steering, terminal cleanup, resume points and no self-review.
- **Affected maps/assertions/evals:** `plan-em`, `eng`, `pre-merge`, `merge`, `shared`;
  all orchestration, dispatch, watch, heartbeat and independent-review cases.
- **Decision:** `approved-translation` — user approved 2026-08-10. Subagents map to
  Codex child threads; identity, relay, watch, steer and resume contract tests
  remain mandatory.

### DEV-CX-006 — model tiers

- **Canonical behavior:** Selected agent packets require named Anthropic model tiers,
  including Opus and Sonnet. Sources: plan-em team packets, eng orchestration packets,
  and release gate agent packets where a tier is named.
- **Blocking Codex constraint:** Codex cannot run Anthropic model identities through
  its native subagent model selector; capability and reasoning controls are different.
- **Alternatives attempted:** Inherit the parent model, use role TOMLs, map by price,
  or map by capability/quality evals. Inheritance and price are not equivalent;
  untested role TOMLs are only configuration, not proof.
- **Proposed difference:** Use an explicit packet-class-to-Codex model/reasoning map
  only after differential quality thresholds pass.
- **User/product impact:** Cost, latency and output quality may differ even when the
  workflow is structurally identical.
- **Compensating control:** Pin the mapping, record it in reports, and block any
  packet class that fails its quality and independence eval.
- **Affected maps/assertions/evals:** `plan-em`, `eng`, `pre-merge`, `merge`, `shared`;
  every agent-packet, synthesis, review and quality-comparison eval.
- **Decision:** `approved-deviation` — user approved 2026-08-10 with a pinned tier
  map: Opus-tier packets → Codex `Terra`; Sonnet-tier packets → Codex `Luna`.
  Record the mapping in reports; quality/independence evals per packet class still
  gate each use.

### DEV-CX-007 — permissions and hooks

- **Canonical behavior:** Claude frontmatter `allowed-tools`, permission settings and
  `.claude/settings.json` hooks constrain or augment execution. Sources: all canonical
  skill frontmatter, `.claude/settings.json`, and hook-dependent protocol rows.
- **Blocking Codex constraint:** Codex sandbox/approval policy is host configuration;
  a skill cannot guarantee that its prose or frontmatter creates the same OS-enforced
  boundary on every surface.
- **Alternatives attempted:** Copy Claude frontmatter, rely on prose, install Codex
  hooks, or require a sandbox profile. Copying does not bind; prose is not enforcement;
  hooks and profiles need explicit trust/configuration.
- **Proposed difference:** Use the narrowest available Codex sandbox and approvals,
  with protocol-level refusal checks as defense in depth; block when a required host
  boundary cannot be established.
- **User/product impact:** Additional host approvals may appear; an unsafe permissive
  host must not expand the skill's declared authority.
- **Compensating control:** Permission-matrix evals, destructive-action canaries and
  startup verification that fails closed.
- **Affected maps/assertions/evals:** All ten maps, `.claude/settings.json` baseline,
  every tool-authority, write-boundary, human-gate and hook assertion/eval.
- **Decision:** `approved-translation` — user approved 2026-08-10. User confirmed
  Codex hooks are equivalent; keep fail-closed startup verification,
  permission-matrix evals and destructive-action canaries — prose alone is not
  enforcement.

### DEV-CX-008 — external skill dependencies

- **Canonical behavior:** msg exposes `kermit`; plan/engineering/release paths may
  invoke `intake`, `plan-review`, `eng` and optional `cook`. Sources: `msg/SKILL.md`,
  `plan-pm/refs/protocol-pm.md`, eng protocols, pre-merge security protocol and
  `shared/refs/fix-loop.md`.
- **Blocking Codex constraint:** Availability in the current workstation does not
  prove the v6 package installs matching external contracts everywhere.
- **Alternatives attempted:** Assume global installation, inline external protocols,
  omit optional paths, or declare/verify dependencies. The first is non-portable;
  inlining forks ownership; omission is not parity.
- **Proposed difference:** Package or declare versioned Codex dependencies and run a
  startup contract probe; optional canonical degradations stay optional and explicit.
- **User/product impact:** A missing dependency becomes a clear blocked/degraded path
  rather than an apparently successful but incomplete workflow.
- **Compensating control:** Clean-home install tests and contract fixtures for every
  cross-skill invocation and return shape.
- **Affected maps/assertions/evals:** `msg`, `plan-pm`, `plan-em`, `eng`, `pre-merge`,
  `merge`, `shared`; menu, handoff, fix-loop and optional-cook evals.
- **Decision:** `approved-translation` — user approved 2026-08-10. External
  dependencies must be declared and version-checked with clean-home probes; no
  silent omission.

### DEV-CX-009 — implicit invocation

- **Canonical behavior:** Every skill description includes natural-language trigger
  intent in addition to explicit slash invocation. Sources: all nine canonical
  `SKILL.md` descriptions and trigger sections.
- **Blocking Codex constraint:** None established. Codex skill descriptions support
  natural-language activation.
- **Alternatives attempted:** The pre-existing `harness-map.md` proposed disabling
  implicit invocation; retaining canonical trigger descriptions is the exact option.
- **Proposed difference:** None recommended. Reject the disablement proposal and
  preserve natural-language triggers.
- **User/product impact:** Disabling it would make users remember `$skill` for flows
  Claude selects from ordinary requests.
- **Compensating control:** Positive and negative trigger-rate evals for every skill.
- **Affected maps/assertions/evals:** All nine skill maps and every trigger/dispatch
  assertion/eval.
- **Decision:** `rejected` — user decided 2026-08-10. Do not disable
  natural-language activation; canonical trigger behavior is preserved.

### DEV-CX-010 — heartbeat and stall watch

- **Canonical behavior:** Long agent runs emit timed observational heartbeats and use
  stall-watch rules without changing verdicts. Sources: `shared/refs/agent-watch.md`,
  `status-heartbeat.md`, `gate-dispatch.md`, plus consumers in plan-em, eng,
  pre-merge and merge.
- **Blocking Codex constraint:** None established. Codex child threads can remain
  active while the root waits, receives updates and steers work.
- **Alternatives attempted:** Wave-boundary-only checkpoints from the pre-existing
  map and timed root-thread watching. Wave-only updates lose observable behavior;
  timed watching remains the parity candidate.
- **Proposed difference:** None recommended. Preserve cadence, stall thresholds,
  observational status and no-auto-stop behavior.
- **User/product impact:** The proposed degradation would reduce progress visibility
  and delay discovery of stuck agents.
- **Compensating control:** Fake-clock watch tests and exact status-line goldens.
- **Affected maps/assertions/evals:** `plan-em`, `eng`, `pre-merge`, `merge`, `shared`,
  and `msg --gui` if it renders those states.
- **Decision:** `rejected` — user decided 2026-08-10. Preserve timed
  heartbeat/stall-watch behavior; wave-boundary-only checkpoints are not accepted.

### DEV-CX-011 — subagent-owned human gate relay

- **Canonical behavior:** An eng build leaf that detects an unapproved database/data
  action pauses for `AskUserQuestion` and continues only with the answer. Sources:
  eng build packet/orchestration protocols and the shared safety floor.
- **Blocking Codex constraint:** A Codex child thread does not own the root chat's
  structured user-input UI; it may need to return a gate request to the orchestrator.
- **Alternatives attempted:** Preapprove the action, let the leaf ask in prose, abort
  the leaf, or relay a structured pause to root and resume the same child. The first
  three weaken the gate or continuity; relay/resume is the parity candidate.
- **Proposed difference:** Gate presentation moves to the root thread; the detecting
  leaf retains ownership and resumes from the same checkpoint after an exact answer.
- **User/product impact:** The question appears from the orchestrator rather than the
  leaf, but no action starts early and the decision set is unchanged.
- **Compensating control:** Structured gate envelopes, same-thread resume IDs, and
  tests for approve, deny, cancel, stale answer and duplicate delivery.
- **Affected maps/assertions/evals:** `eng`, `plan-em`, `shared`; database-touch,
  packet lifecycle, gate ownership and resume assertions/evals.
- **Decision:** `approved-translation` — user approved 2026-08-10. The root thread
  relays the leaf's gate question verbatim; the leaf owns the gate and the same
  leaf resumes from the same checkpoint after the answer, proven by trace.

### DEV-CX-012 — prompt-cache behavior

- **Canonical behavior:** Team packet prompts keep a byte-identical stable head and
  ordering to obtain Anthropic prefix-cache reuse. Sources: plan-em team protocol and
  eng packet protocols that state stable-head/cache ordering.
- **Blocking Codex constraint:** Codex can preserve bytes and order but cannot promise
  Anthropic's cache implementation, hit rate or billing semantics.
- **Alternatives attempted:** Preserve ordering, remove the performance promise, or
  claim Codex cached-input equivalence. Only byte/order preservation is provable from
  the harness; provider performance equivalence is not.
- **Proposed difference:** Preserve functional prompt bytes/order and classify cache
  performance as an explicit non-functional deviation unless measured equivalence is
  established.
- **User/product impact:** Outputs may match while latency or token cost differs.
- **Compensating control:** Stable-head digest tests and benchmark reporting that
  never represents byte stability as a cache hit guarantee.
- **Affected maps/assertions/evals:** `plan-em`, `eng`, and any release/shared agent
  packet that consumes the same prompt pattern; prompt-shape and benchmark evals.
- **Decision:** `approved-deviation` — user approved 2026-08-10. Preserve stable
  prompt bytes/order; disclose cache cost/performance as an unproved non-functional
  difference.

### DEV-CX-013 — concurrency width and scheduling

- **Canonical behavior:** Claude protocols define background/queued waves,
  dependency order and status cadence. Sources: plan-em team protocol, eng build
  orchestration, release executor/dispatch and shared watch contracts.
- **Blocking Codex constraint:** Codex exposes a configurable child-thread cap and
  asynchronous scheduling rather than Claude's queue implementation; the current
  session's total slot count is not a portable skill guarantee.
- **Alternatives attempted:** Force serial work, configure matching width, or preserve
  dependency waves while allowing host scheduling. Serial work changes behavior;
  configured width still needs proof across clients.
- **Proposed difference:** Preserve packet DAG, maximum declared width and phase
  barriers; disclose only unavoidable timing/queue presentation differences.
- **User/product impact:** Completion order and heartbeat timing may vary even when
  dependency safety and outputs match.
- **Compensating control:** Fake workers and clocks verify maximum concurrency,
  dependency barriers, no duplicate packet and deterministic consolidation.
- **Affected maps/assertions/evals:** `plan-em`, `eng`, `pre-merge`, `merge`, `shared`;
  all wave, dispatch, watch and consolidation evals.
- **Decision:** `approved-deviation` — user approved 2026-08-10. Preserve packet
  DAG and declared width; disclose only unavoidable timing/queue presentation
  differences.

### DEV-CX-014 — GUI runner and quick actions

- **Canonical behavior:** `msg --gui` serves a prompt console whose API invokes
  `claude -p --permission-mode acceptEdits`; visible copy and quick actions use Claude
  naming and slash commands. Sources: `msg/refs/gui/server.py`, `index.html`,
  `protocol-gui.md` and `styles.css`.
- **Blocking Codex constraint:** The hard-coded Claude process cannot execute Codex
  skills and the UI cannot infer the active runtime.
- **Alternatives attempted:** Leave the console Claude-only, replace Claude globally,
  or add an isolated runtime selector/adapter. The first loses a mode; the second
  alters Claude output; isolation is the parity candidate.
- **Proposed difference:** Add a Codex-specific runner and `$skill` quick-action/copy
  mapping while keeping the Claude runner and rendered Claude experience byte-stable.
- **User/product impact:** Codex users see Codex naming and commands; Claude users see
  no change.
- **Compensating control:** Runtime-specific server/UI snapshots, command injection
  tests, and a Claude snapshot proving no changed bytes or defaults.
- **Affected maps/assertions/evals:** `msg`, `shared`; GUI route, server command,
  quick-action, permissions, active-runtime copy and isolation evals.
- **Decision:** `approved-translation` — user approved 2026-08-10. Isolated Codex
  runner/UI variant; Claude runner and rendered experience stay byte-stable.

### DEV-CX-015 — host GUI approval

- **Canonical behavior:** `emulate` launches Simulator/emulator/browser windows and
  brings the target app to the user's desktop. Sources: `emulate/SKILL.md`,
  `emulate/refs/protocol.md`, `emulate/refs/runners.md` and emulate helper scripts.
- **Blocking Codex constraint:** Codex sandbox policy can require explicit host
  approval for macOS GUI commands outside the workspace.
- **Alternatives attempted:** Run inside the workspace sandbox, instruct the user to
  open the app, preconfigure a trusted command rule, or request host escalation. GUI
  control cannot occur inside a filesystem-only sandbox; manual opening loses parity.
- **Proposed difference:** Surface the minimum host approval only when required by the
  active Codex permission profile, then execute the exact canonical launch.
- **User/product impact:** Some Codex sessions gain an extra approval pause before the
  window opens.
- **Compensating control:** Narrow command targets, read-only preflight, clear approval
  purpose and a refusal path with zero partial launch state.
- **Affected maps/assertions/evals:** `emulate` and shared safety authority; GUI launch,
  approval, refusal and no-partial-state evals.
- **Decision:** `approved-deviation` — user approved 2026-08-10. The extra host
  approval pause is an accepted, disclosed operational difference.

### DEV-CX-016 — emulator process lifetime

- **Canonical behavior:** A development server/emulator launched in the background
  remains usable after the skill reports, with canonical sweep/reuse behavior.
  Sources: `emulate/refs/protocol.md`, `runners.md`, `script-emulate-preflight.sh` and
  `script-emulate-sweep.sh`.
- **Blocking Codex constraint:** Codex terminal sessions can yield while a process is
  running, but post-turn lifetime, parent-signal behavior and cleanup parity are not
  yet established across supported clients.
- **Alternatives attempted:** Foreground blocking, shell detachment, managed live
  terminal sessions and external process managers. Foreground never returns;
  unmanaged detachment risks leaks; managed sessions need lifecycle proof.
- **Proposed difference:** Use the smallest managed launcher that proves health before
  success and records enough state for exact reuse/sweep/cleanup behavior.
- **User/product impact:** Without proof, the app could close immediately or leave a
  stale server; therefore success remains blocked.
- **Compensating control:** End-to-end lifetime tests across turn completion, reuse,
  failure, cancellation and cleanup, with port/PID ownership checks.
- **Affected maps/assertions/evals:** `emulate`; server launch, health, GUI-open,
  reuse, sweep, cancellation and terminal-output evals.
- **Decision:** `approved-translation` — user approved 2026-08-10. Smallest managed
  launcher; health, reuse, cancellation and cleanup proof required before success;
  degraded lifetime is not accepted.

## Canonical ambiguities blocking an exact map

These are contradictions or apparent dead dependencies inside the Claude source itself,
not Codex limitations. The compatibility layer is not allowed to choose a side. Each
requires a canonical decision before the affected map can reach 1.0000.

| ID | Conflicting canonical evidence | Required decision | Status |
|---|---|---|---|
| AMB-CX-001 | Pre-merge `refusal-patterns.md` says “create the PR” is out of scope and says pre-merge does not create PRs; `pre-merge/SKILL.md` and OPEN-PR require it to create exactly one PR. | Confirm which source owns PR creation, then reconcile the canonical contradiction separately from Codex adaptation. | decided 2026-08-10: pre-merge opens exactly one PR to its target base (staging, else the branch it gates into, e.g. main) and never merges it; refusal text refers to extra/user-directed PR actions. Mechanism resolved 2026-08-10: user directed a canonical change — OPEN-PR now invokes `/kermit --pr` (loud-degrade fallback to `gh pr create` when kermit is absent); `pre-merge/SKILL.md` and `refusal-patterns.md` updated, baseline re-frozen. |
| AMB-CX-002 | Shared `env-contract.md` declares merge as a consumer, but no merge-scoped file loads or uses `ENV.md`. | Confirm whether merge must consume the environment contract or the consumer declaration is stale. | decided 2026-08-10: merge must read `devkit/ENV.md` — canonical change applied: read wired into `merge/SKILL.md` refs, `staging.md` Step 4 and `production.md` Step 1 (read-only, absent → warn-and-proceed). |
| AMB-CX-003 | Shared `tooling-detection.md` says an absent secret scanner emits `warn`; the authoritative security protocol and safety floor require a `blocker`. | Confirm the canonical severity. | decided 2026-08-10: `blocker` — the security protocol/safety floor wins; `tooling-detection.md`'s `warn` is the losing text, to be reconciled canonically. |
| AMB-CX-004 | `script-doctor-detect.sh` says pre-merge and merge init consume it, but neither scoped init protocol invokes it and both spell out related probes independently. | Confirm whether both protocols must call the helper or the helper is stale/dead. | decided 2026-08-10: both init protocols must consume it — canonical change applied: `merge/refs/protocol-init.md` item 1 and `pre-merge/refs/protocol-init.md` step 3 now run `script-doctor-detect.sh` instead of hand-derived probes. |
| AMB-CX-005 | `merge/SKILL.md` places the production release-lock read in phase 1, while `merge/refs/production.md` checks and acquires the lock in phase 2 after the human gates. | Confirm the authoritative lock timing and ensure the losing text is reconciled in the Claude contract before adaptation. | decided 2026-08-10: combined reading confirmed — lock is **checked** in phase 1 (fail fast) and **acquired** in phase 2 only after all human gates; the two files agree under this reading, no canonical edit required. |
| AMB-CX-006 | Shared `closing-message.md` describes a production release as live, while `merge/refs/submission.md` prohibits saying the release is live. | Confirm the permitted production closing language and its evidence threshold. | decided 2026-08-10: never say "live"; a green production release closes as "success". `merge/refs/submission.md` wins; `closing-message.md` is the losing text. |
| AMB-CX-007 | `emulate/SKILL.md` says the skill writes nothing to the repository, is read-only against the working tree, and has only OS-process side effects; `emulate/refs/runners.md` creates `.emulate/` logs and DerivedData inside the repository when that path is ignored. | Confirm whether the safety claim means no tracked/product-state writes or literally no filesystem writes under the repository. | decided 2026-08-10: emulate writes nothing except gitignored runtime artifacts (`.emulate/` logs, DerivedData); no tracked/product-state writes. |

## Pre-existing Codex work classification

The untracked `.agents/skills/shared/refs/` tree existed before this branch was created.
It has been preserved without adoption:

- 20 files are byte-identical to canonical shared references.
- `agent-watch.md` and `gate-dispatch.md` add a Codex preamble.
- `harness-map.md` is Codex-only and contains the proposals cited above.

These files are evidence and candidate implementation material. They are not approved
compatibility output. No later phase may treat their claims as settled until the
corresponding deviation record is decided.

## Required decision process

For each entry, Phase 0 must add the exact canonical sources, documented Codex
constraint, alternatives attempted, smallest proposed difference, user impact,
compensating control, and affected assertions/evals. Then the user decides:

- `approved-translation`: proven semantics-preserving runtime translation.
- `approved-deviation`: accepted semantic/operational difference, still disclosed.
- `rejected`: exact parity remains required; continue research or block the skill.

Pending and rejected deviation entries block implementation of the differing behavior
and block release. Pending canonical ambiguities block completion of every affected map
and must not be “resolved” only in the Codex layer.
