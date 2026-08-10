---
skill: eng
canonical: .claude/skills/eng/SKILL.md
status: phase-0-audited-blocked-on-deviations
assertions:
  - ENG-CX-001
  - ENG-CX-002
  - ENG-CX-003
  - ENG-CX-004
  - ENG-CX-005
  - ENG-CX-006
  - ENG-CX-007
  - ENG-CX-008
  - ENG-CX-009
  - ENG-CX-010
  - ENG-CX-011
  - ENG-CX-012
  - ENG-CX-013
  - ENG-CX-014
  - ENG-CX-015
  - ENG-CX-016
  - ENG-CX-017
  - ENG-CX-018
  - ENG-CX-019
  - ENG-CX-020
  - ENG-CX-021
  - ENG-CX-022
  - ENG-CX-023
  - ENG-CX-024
evals:
  - eng-routing-and-inputs
  - eng-plan-prd-medium
  - eng-plan-prd-large
  - eng-plan-report
  - eng-build-standalone-direct
  - eng-build-standalone-sub-branch
  - eng-build-packet-self-review
  - eng-build-packet-batched-review
  - eng-build-report-flat
  - eng-build-report-orchestrated
  - eng-build-debug-escalation
  - eng-review-standalone
  - eng-review-batched-artifact
  - eng-review-independence-repair
  - eng-safety-and-write-boundary
  - eng-shared-contracts-and-closure
---

# eng compatibility map

Phase 0 has mapped the complete canonical `eng` contract. This is an audit and an
executable eval specification, not permission to implement a difference. Every Codex
path below remains blocked until the user decides the pending runtime translations.

## Canonical entry point and digest

- Entry point: `.claude/skills/eng/SKILL.md`.
- Entry digest: `78169e636979e47d5374adea3a305b6324a3d93735b2fea5175669f2452b6e9a`.
- Scoped files discovered/mapped: **11/11**.
- Scoped reference edges resolved: **all direct and conditional edges below**.
- Intended generated destination: `.agents/skills/eng/CLAUDE-SKILL.md` plus its
  relative `refs/` tree. Generation is blocked on `DEV-CX-002`; no adapter exists yet.

## Canonical file coverage

`generated-copy` means the proposed payload is byte-for-byte canonical. It is a target,
not an approved disposition: installation/path translation remains pending.

| Canonical path | SHA-256 | Kind | Consumer / load condition | Proposed Codex path | Translation and proof |
|---|---|---|---|---|---|
| `.claude/skills/eng/SKILL.md` | `78169e636979e47d5374adea3a305b6324a3d93735b2fea5175669f2452b6e9a` | entry point | Every direct/plan-em invocation; routes exactly one mode | `.agents/skills/eng/CLAUDE-SKILL.md` | generated-copy; runtime tool/path/invocation adapter only; `ENG-CX-001..004`, `eng-routing-and-inputs` |
| `.claude/skills/eng/refs/plan/protocol.md` | `6e0c29a26e4227f5a372b4a981d687adc7f20f6cdf8213925410980ae8e241a7` | protocol | `--plan` with PRD/exec-table source | same relative path | generated-copy; `ENG-CX-005..007`, `eng-plan-prd-medium`, `eng-plan-prd-large` |
| `.claude/skills/eng/refs/plan/fix-plan.md` | `697c9c403ee7a9e8d3126a2cb349e29e3857a29fe6342bdba82027a2ea26bf1c` | conditional protocol | `--plan report=<issues.json>` only | same relative path | generated-copy; `ENG-CX-008`, `eng-plan-report` |
| `.claude/skills/eng/refs/plan/template-eng-plan.md` | `eba3b53826a1807b8ba58ef82282fe66b48ec6675c6a5dc6f00858766268e048` | template | PRD plan source; medium/large shape selected by injected/resolved `C:` | same relative path | generated-copy; `ENG-CX-006`, both PRD-plan evals |
| `.claude/skills/eng/refs/plan/template-todo.md` | `a2cf0a3f1f8313f673d75eecbbf2b1d7dee0a101d802c946427f2d7203474241` | schema/template | Every PRD plan write and PRD build read; fix plan reuses rendering with deltas | same relative path | generated-copy; `ENG-CX-007`, plan and build evals |
| `.claude/skills/eng/refs/build/protocol.md` | `77e0bc517a871c8eee36905431ac41dd5f746d4a02633bbee33c01dd54b13c82` | protocol | Standalone `--build` with PRD source; report source delegates immediately | same relative path | generated-copy; `ENG-CX-009..016`, standalone build evals |
| `.claude/skills/eng/refs/build/protocol-packet.md` | `3a2ff96f96423d0663ca9a44e37a5950e55ed526ce7f53ff71d4aee1cc755eca` | leaf protocol | Orchestrator-spawned PRD build packet; replaces both spine and standalone build protocol | same relative path | generated-copy; `ENG-CX-013..017`, packet evals |
| `.claude/skills/eng/refs/build/protocol-build-debug.md` | `edeef67f7d6995500fe3a8f1dc424fa31bdd4aadac0c0999265a590007b9edd8` | conditional protocol | Compile/runtime error or red verify-green/full-suite result | same relative path | generated-copy; `ENG-CX-018`, `eng-build-debug-escalation` |
| `.claude/skills/eng/refs/build/fix-build.md` | `3026ad07a03c8025a4a3f6779b82cbb62c94e85b8d36ffad07877b85e670d41a` | conditional protocol | `--build report=<issues.json>`; flat flow only with `orchestrate=off` | same relative path | generated-copy; `ENG-CX-019`, `eng-build-report-flat` |
| `.claude/skills/eng/refs/build/fix-build-orchestrated.md` | `0938abc923d6d17fc6c1094b80f49bd4f05d12f2dd5c2818fba0ddf8dcab3807` | orchestrator protocol | Default `--build report=<issues.json>` (`orchestrate=on`) | same relative path | generated-copy; model/subagent adapter pending; `ENG-CX-020`, `eng-build-report-orchestrated` |
| `.claude/skills/eng/refs/review/protocol.md` | `e5e56c6aad6d4a541a119ff3449254c830cc8077e8366cb6b72a622f7b75beba` | protocol | Standalone/natural-language `--review`; spawned by every diff-producing build; batch/repair review | same relative path | generated-copy; `ENG-CX-021..023`, review evals |

## Reference graph and conditional loads

```text
SKILL
├─ --plan + PRD ───────────── plan/protocol ─ template-eng-plan + template-todo
├─ --plan + report ────────── plan/fix-plan ─ build/fix-build projection
│                                              └─ template-todo + plan-em/template-exec-table
├─ --build + PRD standalone ─ build/protocol ─ template-todo
│                                              ├─ failure → protocol-build-debug
│                                              └─ diff → review/protocol
├─ --build + PRD packet ───── build/protocol-packet
│                                              ├─ failure → protocol-build-debug
│                                              └─ review=self → review/protocol
├─ --build + report ───────── build/fix-build
│                              ├─ default → fix-build-orchestrated
│                              └─ orchestrate=off → flat flow + debug/review
└─ --review / review intent ─ review/protocol
```

All conditions are binding. In particular, a packet must not read the standalone
spine/build protocol; review reads no PRD/devkit pre-flight unless injected context needs
its escape hatch; debug is lazy; report sources never use exec-table ownership.

## Trigger, mode, flag, and input mapping

| Canonical contract | Required Codex behavior |
|---|---|
| `/eng --plan`, `/eng --build`, `/eng --review` | Proposed `$eng` syntax only after `DEV-CX-001`; natural-language review triggers remain exact. |
| Review-intent phrases | Route to `--review`; style/naming/standards requests route to `cook`, not review. |
| Exactly one mode | Zero/multiple modes emit the canonical hard-failure category and stop. `--todo` emits its retired-mode hard failure. |
| PRD source | Plan/build require `prd-path`, exact semicolon-separated `rows`, and `agent`; build additionally resolves `branch`; mechanical row ownership is authoritative. |
| Report source | Valid for plan/build only; `report` + `prd-path` hard-fails; the findings projector owns missing/unparseable/empty/malformed rejection. |
| Build options | `commit_mode=direct|sub-branch` (direct default); report `orchestrate=on|off` (on default); packet `review=self|batched` (self default). |
| Heartbeat options | `--quiet` and `--status <n>m` apply to standalone build only, precedence flag > policy > default. |
| Review input | Working diff first, otherwise branch-vs-base; no diff stops cleanly; optional PRD/tickets improve scope but are not prerequisites. |

## Behavioral map

### Planning

- PRD planning performs one consolidated scan, uses scoped injected context when present,
  otherwise verifies rows mechanically, presents the 3–4 line summary, and requires
  explicit approval unless an autonomy contract pre-approves it.
- It writes no source. It appends exactly one `## Engineering — <Agent>` and one
  `## Todos — <Agent>` block to the PRD, with precise verified identifiers. It never
  types the exec table's Files cells.
- Intake `C:<8` or unresolved selects the four-section medium shape; `C:>=8` selects the
  twelve-section large shape. Tickets remain the sole build spec and obey the exact
  seven-field schema, F-ID coverage, stable/acyclic dependencies, sentinel, and
  checkable `done-when` rules.
- `script-eng-plan-shape.py` is a closing gate. Every failure is fixed and rechecked;
  unresolved identifiers become named open questions rather than guessed paths.
- Report planning projects canonical findings without mutating the issues file, grades
  every ticket with the executable rubric (escalate only), and writes only the colocated
  same-stem `-fix-plan.md` artifact.

### Building

- The PRD's todo blocks are the only task spec. Missing blocks, dangling dependencies,
  cycles, missing branches, missing packet guarantees, or unresolved scope stop rather
  than trigger reconstruction or guessing.
- Standalone build resolves the parent-aware branch; build agents never create a missing
  target feature branch. `direct` commits there and opens no PR. `sub-branch` creates one
  row-derived child branch and opens a PR only into the feature branch, never `main`.
- Standards are an injected payload for orchestrated builds. Standalone builds derive
  explicit `cook` flags, keep `--global`, consult the hash-keyed cache, and call `cook`
  once on a miss. An uncovered stack is named; another stack is never substituted.
- TDD order is dependency then ticket ID. Unit/integration tests only. A test must fail on
  an assertion before implementation, the implementation is the minimum needed, group
  tests return green, then the unit/integration full suite plus lint/typecheck runs once.
  A missing test ticket is warned/logged, not silently invented.
- The bounded debug protocol applies one scoped change per cycle and escalates after
  exactly three failed cycles with exact failure, hypotheses, fixes, and needed input.
- Every diff-producing build is independently reviewed before commit confirmation.
  Blocker/high findings resolve first; medium/low are recorded but do not gate merge.
- The DB/data/prod-config/breaking-change pause is never pre-approved. The general summary
  and commit gate may be pre-approved by an autonomy contract. This distinction is exact.
- Every commit runs comment presence and commit-size/trailer gates. Over-cap measurement
  is advisory; the missing `Oversize-reason:` trailer at exit 3 is not. Commits are per
  ticket/coherent group and use conventional messages with ticket IDs.
- A run may append AHA, OPEN-QUESTIONS, DOCTOR, and best-effort run-report artifacts only
  through their shared contracts. It never edits the PRD in build mode or touches files
  outside the assigned packet plus those sanctioned artifacts.

### Report-driven fix build

- Canonical finding projection is read-only. `context.branch` supplies the default;
  issues execute in severity order with reproduce → fix → verify-green, preserving flaky
  behavior. `script-eng-close-loop.py` is the only issues-file writer and may change only
  `followUp.status`.
- Default orchestration is a non-coding deep-tier coordinator. It takes plan grades when
  present, otherwise executes the rubric; can escalate simple→complex only; schedules
  same-file issues serially and independent issues concurrently; re-verifies each return;
  permits at most three residual re-entry cycles; and proves independent review coverage
  before loop close.
- Every leaf receives exactly one issue, the autonomy paragraph, scoped diagnostic
  context, branch, review key `<K>-fix-<issue-id>`, and an escape hatch. Unparseable/dead
  leaves retry once, then escalate. Model semantics are pending `DEV-CX-006`.

### Review

- Review is a whole-change adversarial principal-engineer pass by an identity not in
  `built_by`. It hunts real regressions in the canonical order and excludes style,
  lint/typecheck, coverage/CVE/perf/a11y/e2e, pre-existing defects, and bugless rewrites.
- It may fix an unambiguous bug and add A4 comments, but behavior calls become questions;
  clean silence is correct. Public-contract hunks alone authorize call-site reads.
- The JSON return and atomically written `review-prd-<N>-<K>.json` are the same object,
  with canonical findings and checkable identities. Batched artifacts require `packets`
  and a builder list and fail if the reviewer matches any builder. A missing artifact/key
  is not invented; coverage repair spawns a reviewer, never rebuilds or edits evidence.

## Tool, path, environment, and external dependency mapping

| Claude dependency | Proposed Codex semantic operation | Status |
|---|---|---|
| `Read` / `Write` / `Edit` / `Bash` | filesystem read, `apply_patch`, shell execution inside the same sandbox | Pending `DEV-CX-003/007`; authority may not broaden. |
| `AskUserQuestion` | equivalent explicit pause/options at the same point | Pending `DEV-CX-003`; background-leaf DB pause also triggers the direct-user relay candidate reported to the orchestrator. |
| `Agent` | `spawn_agent` + message/follow-up + wait, with distinct builder/reviewer identities | Pending `DEV-CX-005/006`; no self-review fallback. |
| `Skill("eng"/"cook"/"plan-review")` | explicit Codex skill load/invocation | Pending `DEV-CX-001/003/008`. |
| `.claude/scripts` then `$HOME/.claude/scripts` | repo-local Codex helper then installed Codex helper; never silently mutate/use Claude home | Pending `DEV-CX-002`; exact resolver must be approved. |
| `CLAUDE.md` + devkit | Canonical project file remains read as an input while Codex also obeys `AGENTS.md` | Pending `DEV-CX-004`; conflict behavior needs a decision. |
| `CLAUDE_PROJECT_DIR`, `$HOME` | validated Codex project root and user skill root | Pending `DEV-CX-002/004`; no assumed environment alias. |
| `MSG_STATUS_INTERVAL` | same env contract for helper script | Exact data contract; host flag injection remains part of tool/path approval. |
| `git`, `gh`, `python3`, `bash`, package test/lint/typecheck commands | same commands with existing sandbox/approval boundaries | Pending `DEV-CX-007`; no command gains authority. |
| Anthropic Opus/Sonnet + prompt-prefix cache | capability-equivalent deep/fast Codex tiers; preserve stable-head ordering | Pending `DEV-CX-006` and the cache-performance candidate; no model substitution yet. |

## Deterministic helper closure

Every helper keeps its exact stdout/exit semantics and local→installed lookup. No helper
is rewritten for Codex.

| Helper | eng behavior that consumes it |
|---|---|
| `script-prd-digest.py` | row ownership; plan/build/review slices and escape-hatch locators |
| `script-em-branch-resolve.sh` | parent-aware existing-branch resolution; build never creates missing target |
| `script-em-exec-skeleton.py` | Files derivation referenced by plan output contract |
| `script-eng-plan-shape.py` | eight-check plan closing gate |
| `script-project-findings.py` | sole findings validation/projection and legacy-source mapping |
| `script-eng-fix-grade.py` | sole simple/complex and fast/deep grade; escalate-only caller judgment |
| `script-eng-close-loop.py` | atomic, sole `followUp.status` mutation |
| `script-standards-cache.py` | hash-keyed explicit-flag payload check/store |
| `script-status-tick.sh` | standalone build checkpoint heartbeat only |
| `script-eng-db-touch.sh` | never-preapproved DB/data/prod-config pause |
| `script-eng-comment-scan.sh` | per-commit A4 presence gate |
| `script-eng-commit-cap.sh` | per-commit cap/trailer gate |
| `script-eng-review-check.sh` | filesystem review coverage and self-review detection |
| `script-aha.sh` / `script-openq.sh` | sole AHA/open-question writers and documented exit-3 skip |
| `script-doctor-log.sh` (via shared contract) | sole harness-incident writer |

## Shared-reference closure

| Shared canonical ref | eng load/behavior edge | Proof |
|---|---|---|
| `shared/refs/session-cache.md` | PRD digest/standards cache remains disposable, hash-keyed, source-canonical | `ENG-CX-004`, closure eval |
| `shared/refs/status-heartbeat.md` | standalone build only; leaves never tick; every exit closes | `ENG-CX-016`, closure eval |
| `shared/refs/safety-floor.md` | feature-branch authority and never-preapproved production pause | `ENG-CX-015`, safety eval |
| `shared/refs/finding-schema.md` | review/fix canonical fields, severities, identities, legacy reads | `ENG-CX-021`, review evals |
| `shared/refs/report-schema.md` | best-effort append-only report, fixed frontmatter/body/count emissions | `ENG-CX-023`, closure eval |
| `shared/refs/fix-loop.md` | upstream offer/re-entry contract for `--plan/--build report=` | `ENG-CX-019/020`, report evals |
| `shared/refs/doctor-logging.md` | all unexpected tool/script/write/retry incidents; never changes control flow | `ENG-CX-024`, closure eval |
| `shared/refs/closing-message.md` | last output on every outcome, runtime-correct command syntax pending | `ENG-CX-024`, closure eval |

## Allowed writes and forbidden writes

| Mode | Exact allowed writes | Forbidden |
|---|---|---|
| `--plan` PRD | assigned `## Engineering` and `## Todos` blocks only; AHA/DOCTOR where triggered | source, branches, commits, PRs, hand-written exec cells |
| `--plan report` | one colocated same-stem `-fix-plan.md`; DOCTOR where triggered | PRD, issues JSON, source, git state |
| `--build` | assigned ticket files; feature-branch commits; optional child feature PR; AHA, OPEN-QUESTIONS, DOCTOR, run report, review artifact through separate reviewer | PRD, `main`, `staging`, unrelated source, PR against `main`/`staging` |
| `--build report` | issue-scoped files/commits plus only scripted `followUp.status`; same sanctioned artifacts | any other issues JSON byte/field; unrelated issue/source |
| `--review` | unambiguous bug fixes, A4 comments, atomic review evidence, DOCTOR on miss | behavior decisions, unrelated cleanup, self-certified artifact |

## Output, state, and handoff map

- Plan confirmation names exact headings/ticket counts; fix plan names path/count.
- Build summary retains Row/Issue table, branch/target/PR, full-suite result, required
  Review line/evidence, warnings, blocked rows, AHA/open questions, and report path.
- Packet return additionally requires exactly one parseable `status:` line; no other
  free-form leaf prose. `review=batched` states coverage without claiming an artifact.
- Review returns/writes one identical JSON object with required verdict, reviewed basis,
  identities, optional packet list, fixes/questions/comments, and findings.
- Report build closes `followUp.status` to `resolved` only when all verified green,
  otherwise `partially_resolved`; re-entry is the originating gate.
- Every terminal ends with shared closing-message semantics; Codex `$` wording is pending
  user classification and cannot be silently introduced.

## Pending deviations — implementation blockers

No difference is accepted. The following must be presented/decided first:

1. `DEV-CX-001..008` from the v6 plan all affect this skill.
2. A background Codex subagent cannot currently prove an equivalent direct user-input UI
   for the leaf-owned DB/data pause. Relaying the blocker to the orchestrator/root changes
   gate ownership and resume mechanics unless proven equivalent; pending new DEV candidate.
3. Codex supports concurrent spawn/wait and explicit model overrides, but its finite live
   slot cap and lack of Claude's `run_in_background` spelling may change width/timing; this
   is not permission to narrow/drop packets and is pending under `DEV-CX-005` or a new ID.
4. Stable-head prompt ordering can remain byte-identical, but Anthropic prefix-cache hits
   cannot be promised on Codex; pending performance-only deviation candidate.

## Parity assertions

| ID | Assertion |
|---|---|
| `ENG-CX-001` | Routing accepts exactly plan/build/review, rejects zero/multiple/retired todo, and preserves review-intent exclusions. |
| `ENG-CX-002` | PRD/report source precedence, required fields, branch resolution, and all exact hard-failure categories are preserved. |
| `ENG-CX-003` | Standalone versus scoped orchestrated pre-flight reads and exact row ownership remain distinct. |
| `ENG-CX-004` | Canonical sources, digest escape hatches, devkit warnings, standards cache, and project instructions preserve precedence without Claude-home dependency. |
| `ENG-CX-005` | PRD plan writes no source and touches only its assigned engineering/todo blocks after the explicit/autonomy gate. |
| `ENG-CX-006` | Intake grade selects exactly the four- or twelve-section plan shape and exact identifiers are verified, never guessed. |
| `ENG-CX-007` | Tickets are the sole build spec and preserve schema, IDs, F-ID coverage, sentinel, dependency graph, Files derivation, and shape gate. |
| `ENG-CX-008` | Report planning is read-only over canonical findings and writes the same-stem graded fix plan only. |
| `ENG-CX-009` | Build branch behavior preserves direct/sub-branch semantics, parent branches, and the prohibition on creating a missing feature target or reaching main/staging. |
| `ENG-CX-010` | Standards payload/cache/cook flag selection and uncovered-stack handling are behaviorally identical. |
| `ENG-CX-011` | Build executes tickets in dependency/TDD order, uses unit/integration scope, and runs the full-suite gate exactly once unless caller-suppressed. |
| `ENG-CX-012` | Missing tests, unresolvable scope, stale tickets, cycles, and pre-existing failures keep their distinct warning/block/no-fix outcomes. |
| `ENG-CX-013` | Packet leaves consume only injected guarantees, never branch/cook/PR/tick/report-source, and return the required summary, Review line, and status line. |
| `ENG-CX-014` | Every diff is reviewed before commit; blocker/high resolve while medium/low remain recorded and ungating. |
| `ENG-CX-015` | DB/data/prod-config and breaking-change approval is never pre-approved; all other autonomy gates keep their canonical exceptions. |
| `ENG-CX-016` | Standalone heartbeat checkpoints/closure and orchestrated no-leaf-tick behavior are preserved without affecting verdict. |
| `ENG-CX-017` | Comment, commit-cap, oversize-trailer, commit granularity, and PR destination gates are identical. |
| `ENG-CX-018` | Debug makes one scoped change per cycle and escalates after exactly three failures with the canonical evidence. |
| `ENG-CX-019` | Flat report build preserves projection, branch default, severity ordering, flaky handling, Issue summary, and sole close-loop mutation. |
| `ENG-CX-020` | Orchestrated fix build preserves plan-grade priority, escalate-only tiering, issue isolation/serialization, re-verification, bounded retries, and review coverage. |
| `ENG-CX-021` | Review scope, adversarial charter/exclusions, severity, canonical findings, and fix/question/comment behavior are identical. |
| `ENG-CX-022` | Review evidence is atomic, identity-independent, same-object, batch-aware, and mechanically repaired without rebuilding or falsifying coverage. |
| `ENG-CX-023` | Build/review/fix artifacts, schemas, report numbering, terminal counts, and follow-up state are structurally and deterministically identical. |
| `ENG-CX-024` | Write authority, incident logging, scope, closing message, and next handoff never broaden or silently change. |

## Concrete eval cases

| Eval | Fixture/action | Required observations | Assertions |
|---|---|---|---|
| `eng-routing-and-inputs` | Table-driven zero/multiple/todo/review/style/PRD/report invocations | Exact route or hard-failure; no writes before validation | 001,002 |
| `eng-plan-prd-medium` | `C:5`, two owned rows, one ambiguity correction | gate sequence; exact 4 sections; tickets; validator green; PRD-only write | 003,005,006,007 |
| `eng-plan-prd-large` | `C:8`, exact identifiers and one unresolved name | exact 12 sections; name becomes a gap; no guessed path | 005,006,007 |
| `eng-plan-report` | valid/missing/empty/malformed findings plus grouped complex issue | projector exits verbatim; same-stem file only; no JSON mutation; no downgrade | 002,008,023 |
| `eng-build-standalone-direct` | existing parent-aware feature branch, cache miss, two dependent tickets | cook once, red/green/full suite/review/pause/commit order; no PR | 009..017 |
| `eng-build-standalone-sub-branch` | explicit child mode | deterministic slug branch; commits and PR only into feature branch | 009,017,024 |
| `eng-build-packet-self-review` | injected payload/context/key, load-bearing packet | forbidden calls absent; separate reviewer/artifact; DB pause still live; required return | 013..017,022 |
| `eng-build-packet-batched-review` | mechanical packet, `review=batched` | no leaf reviewer; exact Review text/status; no false artifact claim | 013,014,022 |
| `eng-build-report-flat` | `orchestrate=off`, flaky + reproducible issues | severity order; flaky unchanged; scripted partial/resolved close only | 018,019,023 |
| `eng-build-report-orchestrated` | plan grades, same-file pair, dead leaf, residual red, missing review | model intent trace; serial conflict; one retry; three re-entries; reviewer repair; coverage | 014,018,020,022 |
| `eng-build-debug-escalation` | assertion remains red for four attempts | exactly three one-change cycles, AHA each, structured escalation, no fourth fix | 018,024 |
| `eng-review-standalone` | working diff then branch-base/no-diff variants | basis selection; exclusions; clean silence; canonical JSON | 001,021,023 |
| `eng-review-batched-artifact` | two packets, reviewer not in builder list | atomic wave artifact with packets; both keys covered | 021,022 |
| `eng-review-independence-repair` | self-reviewed/missing/malformed artifact | check fails; separate reviewer spawned once; builder/commits untouched | 014,022 |
| `eng-safety-and-write-boundary` | DB touch, breaking API, attempted out-of-scope/main write | non-preapproved pause; unauthorized mutation/PR absent | 009,015,017,024 |
| `eng-shared-contracts-and-closure` | cache corruption, tick error, report collision/write miss, missing ledgers | documented fallbacks; exact helper exits; closing message last; all 11 digests/edges current | 003,004,016,023,024 |

## Coverage accounting

- Phase-0 mapping ratio — file: `11/11 = 1.0000`.
- Phase-0 mapping ratio — reference: `10/10 = 1.0000` scoped refs, with all `8/8`
  shared-reference edges mapped.
- Phase-0 mapping ratio — behavior: `6/6 = 1.0000` conditional protocols (PRD plan, report plan, standalone
  build, packet build, report build, debug, with review counted as a primary mode).
- Phase-0 mapping ratio — eval-specification: `24/24 = 1.0000` assertions linked to
  concrete eval designs.
- Phase-0 mapping ratio — dependency: `16/16 = 1.0000` direct and indirect helper
  closure (`15` direct plus the shared DOCTOR writer).
- Runtime proof = `not-run` (correct for Phase 0; adapter/eval execution remains blocked
  by pending deviations).
