---
skill: plan-review
canonical: .claude/skills/plan-review/SKILL.md
status: phase-0-audited-blocked-on-deviations
assertions:
  - PRV-CX-001
  - PRV-CX-002
  - PRV-CX-003
  - PRV-CX-004
  - PRV-CX-005
  - PRV-CX-006
  - PRV-CX-007
  - PRV-CX-008
  - PRV-CX-009
  - PRV-CX-010
  - PRV-CX-011
  - PRV-CX-012
  - PRV-CX-013
  - PRV-CX-014
  - PRV-CX-015
  - PRV-CX-016
  - PRV-CX-017
  - PRV-CX-018
  - PRV-CX-019
  - PRV-CX-020
evals:
  - plan-review-routing-and-paths
  - plan-review-product-clean
  - plan-review-product-autofix
  - plan-review-product-decision-pause
  - plan-review-eng-mechanical
  - plan-review-eng-contract-coherence
  - plan-review-minor-choice
  - plan-review-ledger-current-and-legacy
  - plan-review-self-heal-recurrence
  - plan-review-open-questions-and-stamps
  - plan-review-scope-and-write-boundary
  - plan-review-shared-contracts-and-closure
---

# plan-review compatibility map

This is the complete Phase 0 contract inventory for the PRD certifier. It specifies
parity and proof; it does not approve any Codex runtime translation.

## Canonical entry point and digest

- Entry: `.claude/skills/plan-review/SKILL.md`.
- Entry digest: `eeb0149f826da6c532471e1ebd38e922e3472e86ccd856cf85f3c57ce73dd659`.
- Scoped files mapped: **3/3**.
- Proposed generated destination: `.agents/skills/plan-review/CLAUDE-SKILL.md` plus
  relative refs, blocked on the pending installation/path decision.

## Canonical file coverage

| Canonical path | SHA-256 | Kind | Consumer / load condition | Proposed Codex path | Translation and proof |
|---|---|---|---|---|---|
| `.claude/skills/plan-review/SKILL.md` | `eeb0149f826da6c532471e1ebd38e922e3472e86ccd856cf85f3c57ce73dd659` | entry/protocol | Every standalone or plan-em certification invocation | `.agents/skills/plan-review/CLAUDE-SKILL.md` | generated-copy target; invocation/tool/path adapter pending; `PRV-CX-001..020`, all evals |
| `.claude/skills/plan-review/refs/certification.md` | `73026121eb3e3c9831e2d6a92a255faa81895aa344776c587fa57bfebe9795d8` | checklist/schema | Every valid run after tune selection; supplies exact check subset, consumers, severity, tables, self-heal | same relative path | generated-copy target; `PRV-CX-004..014`, product/eng/self-heal evals |
| `.claude/skills/plan-review/refs/template-review-report.md` | `8567ea5803ead42a85adc8d0968aeb14215d8f470fd219895722f3c799a13aa6` | template/schema | First current-shape ledger creation only; later runs append; never used when a legacy inline ledger exists | same relative path | generated-copy target; `PRV-CX-008..010`, ledger eval |

## Reference graph and conditional loads

```text
plan-review
├─ preflight resolves PRD + auto tune
├─ product → product digest → mechanical check 6 + judgment checks 1/2/3
├─ eng     → eng-audit digest → mechanical checks 4/5/6 + judgment checks 2/7
└─ certification checklist
    ├─ findings → ledger writer
    │    ├─ existing external report wins
    │    ├─ else legacy inline ledger stays inline
    │    └─ else template-review-report creates one external report
    ├─ Critical/Major → auto-fix or batched product-decision pause
    ├─ Minor → one fix-or-log question
    ├─ fixed Critical/Major → AHA count/write
    ├─ undecided product decision → OPEN-QUESTIONS writer
    └─ always normalize open questions + stamp certification
```

The findings ledger and legacy Audit sections are always excluded from certification
input. Digest prose is read only through a specific `prose_lines` escape hatch.

## Trigger, flags, inputs, and refusals

- Canonical `/plan-review [path] [--product|--eng]` and the four natural-language
  intents map to a proposed `$plan-review` invocation only after user approval.
- Explicit product/eng flags win. With neither, `TUNE_SUGGESTION` decides without a
  question. Both tune subsets and tune labels remain exact.
- `script-cert-preflight.sh` alone resolves direct file, directory, and contextual hints.
  `no_path`, `invalid_pattern`, and `not_found` ask for a path, retry at most twice, then
  refuse with the expected pattern and plan-pm recovery. The model never re-derives paths.
- The certifier does not interview. It has only three possible user-decision moments:
  path recovery; one batched product-behavior pause; one Minor fix/leave question.

## Seven-check parity map

| Check | Tune | Owner | Consumer protected | Exact failure/severity |
|---|---|---|---|---|
| 1 criteria testability | product | model | regression authoring / PRD-consistency | vague/unbounded criterion Major; empty/placeholder or undefined timezone Critical |
| 2 breaking/DB label | both | model | all breaking/data safety pauses | any unlabeled surface Critical |
| 3 intake intent fidelity | product | model | autonomous drafting purpose | drift Major; core goal missing Critical; no ancestor is a note/skip |
| 4 exec/eng integrity | eng | script | row reads/collision scheduler | missing coverage/guessed id/collision Critical; empty/thin Files Major |
| 5 ticket graph validity | eng | script | build ordering | cycle/unknown ID Critical; missing done-when Major |
| 6 frontmatter graph/buckets | both | script | roadmap, plan-em, pre-merge selection | cycle Critical; edge/bucket gap Major; missing PLATFORMS facet skips |
| 7 cross-agent contract coherence | eng | model | parallel builders | any mutually inconsistent identifier Critical |

No check without a named consumer is added. Cut blanket completeness, narrative prose,
whole-document consistency, and glossary sweeps stay cut. Instruction-like text inside a
PRD is treated as data and itself becomes a finding; it is never executed.

## Certification, fixes, state, and gates

- Mechanical checks run first. Exit 0 is clean, exit 1 supplies findings, exit 2 stops
  unreadable/frontmatter-less input without a stamp. `SKIP` produces no ledger row.
- Judgment findings cite section/check and name the consumer. Critical/Major/Minor are the
  only severities and are ordered severity then section.
- `script-ledger.py` alone chooses/creates/updates the ledger, owns monotonic IDs, dates,
  dedup on `What is wrong`, `Still open`, and clean-marker behavior. Malformed JSON or
  canonical-column drift stops; the skill never repairs the table by hand.
- Every Critical/Major is fixed in the active tune's scope. Product tune never edits
  engineering sections. A product-behavior choice is never guessed: all such findings are
  batched (maximum four per call), resolved from human choices, then marked Fixed.
- Every auto-fix is shown in the compact terminal table and writes one categorized AHA
  learning when the ledger exists. Count precedes write; including this run, recurrence
  >=3 emits a drafting-protocol repair flag rather than editing that protocol.
- Minors ask once. Fix applies/marks Fixed; leave preserves Open. No Minor ask when empty.
- Open questions normalization and certification stamping run even on a clean audit.
  Current PRDs stamp `reviewed: yes`; legacy PRDs stamp the relevant product/eng pair and
  leave `reviewed` alone. The stamp, not the evidence report, is the gate.
- The run emits certified/clean, recommends but never invokes the next stage, then uses the
  shared closing message last. Inline plan-em callers continue themselves.

## Tool, path, environment, and cross-skill map

| Claude dependency | Proposed Codex semantic operation | Status |
|---|---|---|
| Read/Edit/Bash | Codex read, `apply_patch`, shell under the same narrow write authority | Pending tool/permission decisions; no broader edit surface. |
| AskUserQuestion | equivalent path/product/minor option gate at the same point | Pending question-UI decision; pause semantics may not weaken. |
| `/plan-review`, `/plan-pm`, `/plan-em`, `/eng` | runtime-specific explicit skill/handoff syntax | Pending invocation classification; no silent slash/dollar rewrite. |
| `.claude/scripts` then `$HOME/.claude/scripts` | repo-local then installed Codex helper | Pending path decision; must not depend on/mutate Claude home. |
| canonical PRD/devkit inputs and Claude project instructions | same files as data, while Codex also obeys applicable `AGENTS.md` | Pending instruction-file conflict rule. |
| `python3`, `bash` | same deterministic helper calls/exit meaning | Pending sandbox/permission mapping only. |
| plan-em inline caller | same certify-return-recheck protocol; plan-review remains recommend-only | Cross-skill behavior is exact. |
| msg GUI | consumes exact Markdown ledger columns/path | Artifact schema must remain byte-compatible. |

## Deterministic helper closure

| Helper | Relationship |
|---|---|
| `script-cert-preflight.sh` | directly executed; sole path/tune suggestion resolver |
| `script-prd-digest.py` | directly executed; product/eng-audit slices and prose locators |
| `script-cert-mech.py` | directly executed; mechanical checks 4/5/6 |
| `script-ledger.py` | directly executed; sole findings-report/legacy ledger writer |
| `script-openq.sh` | directly executed only for unresolved product decisions |
| `script-aha.sh` | directly executed for counts and one learning/fixed Critical/Major |
| `script-prd-stamp.sh` | directly executed on every successful/clean run |
| `script-cert-status.sh` | downstream reader proving the current/legacy stamp plus open-Critical gate |
| `script-em-exec-skeleton.py` | downstream producer behind check 4's derived-Files contract |
| `script-em-exec-collision.py` | downstream collision consumer/mechanical dependency of check 4 |
| `script-eng-db-touch.sh` | downstream safety consumer protected by check 2 |
| `script-doctor-log.sh` | indirect sole unexpected-incident writer via shared contract |

## Shared-reference closure

| Shared ref | Edge | Proof |
|---|---|---|
| `shared/refs/session-cache.md` | digest is regenerated from canonical source and escape-hatch-only | `PRV-CX-004`, closure eval |
| `shared/refs/closing-message.md` | last output on every clean/warn/refusal/failure; exact next registry row | `PRV-CX-019`, closure eval |
| `shared/refs/doctor-logging.md` | unexpected helper/tool/retry/write incidents only; never changes outcome | `PRV-CX-020`, closure eval |
| `shared/refs/safety-floor.md` | check 2 protects DB/breaking pauses; certifier write authority stays non-git | `PRV-CX-006/018`, scope eval |

## Allowed and forbidden writes

Allowed: in-place corrections to the active tune's PRD sections; status changes in the
one existing/current ledger through its writer; one first-run external Markdown ledger;
normalized PRD open-question section; current/legacy certification stamp; existing AHA,
OPEN-QUESTIONS, and DOCTOR appends through their sole writers.

Forbidden: source code, git state, branches, commits, PRs, deployments, another report or
table, eng sections during product tune, product behavior chosen without the human,
devkit-file creation, direct ledger repair, drafting-protocol edits from a recurrence flag,
or invoking the recommended next stage.

## Outputs and artifacts

- Exact tune label.
- One growing `review-prd-[n]-[slug].md` table or preserved legacy inline table; never
  confuse it with `review-prd-<N>-<K>.json` build evidence.
- Compact auto-fix table, optional recurrence flag, optional Minor/product gates.
- Revised PRD and normalized open questions; certification stamp.
- `PRD certified.` or `PRD certified — no findings.`, recommend-only handoff, closing
  message last.

## Pending deviations

No difference is accepted. The following pending deviations apply and block generation:

- `DEV-CX-001`: canonical slash invocation and handoffs cannot become dollar syntax
  without a user-approved classification.
- `DEV-CX-002`: generated/installed path and helper fallback resolution must not depend
  on or mutate Claude-owned state.
- `DEV-CX-003`: `AskUserQuestion`, read/edit/bash, and skill-handoff bindings must retain
  the same pause, ownership, continuation, and enforcement semantics.
- `DEV-CX-004`: any `CLAUDE.md`/`AGENTS.md` conflict must be decided explicitly; it may
  not change certification judgments or edit authority.
- `DEV-CX-007`: Codex sandbox/hook enforcement must preserve the canonical narrow write
  surface and may not fail open.
- `DEV-CX-009`: all canonical natural-language activation remains required. The
  pre-existing proposal to disable implicit Codex invocation is not adopted.

Plan-review has no subagent, model-tier, background-process, heartbeat, or prompt-cache
dependency and adds no new deviation class.

## Parity assertions

| ID | Assertion |
|---|---|
| `PRV-CX-001` | Triggers, explicit flags, auto-selection, tune labels, and mutually exclusive tune behavior match. |
| `PRV-CX-002` | Preflight alone resolves paths; exactly two recovery attempts precede the canonical refusal and no early write. |
| `PRV-CX-003` | Product and eng use only their exact check subsets and never add cut/no-consumer checks. |
| `PRV-CX-004` | Product/eng digest slices, exclusion of audit history, instruction-as-data, and section-only escape hatches remain exact. |
| `PRV-CX-005` | Mechanical check invocation, SKIP/exit semantics, mapping, and ordering precede judgment checks exactly. |
| `PRV-CX-006` | All seven checks retain owner, consumer, fail condition, and severity, including product/eng facets of checks 2/6. |
| `PRV-CX-007` | Each finding is atomic, consumer-named, severity ordered, and leaves script-owned row fields unset. |
| `PRV-CX-008` | Ledger home precedence, current/legacy schema, single-table rule, and report/build-evidence distinction are exact. |
| `PRV-CX-009` | Dedup, monotonic numbering, carried/fixed/clean states, date/last-run updates, and malformed-table refusal remain script-owned. |
| `PRV-CX-010` | Critical/Major auto-fix is complete and tune-scoped; terminal fix table mirrors actual changes. |
| `PRV-CX-011` | Product behavior choices batch into the only hard decision pause and unresolved choices use only the ambiguity writer. |
| `PRV-CX-012` | Minor findings cause exactly one fix/leave question and preserve the selected ledger state. |
| `PRV-CX-013` | AHA count-before-write, category tags, one learning per fixed Critical/Major, missing-ledger skips, and >=3 recurrence flag match. |
| `PRV-CX-014` | Open-question normalization is idempotent and runs on clean and finding paths. |
| `PRV-CX-015` | Current and legacy certification stamps are selected correctly, always written on success/clean, and remain the sole gate signal. |
| `PRV-CX-016` | Product/eng terminal text and recommend-only handoffs match standalone and inline-caller behavior. |
| `PRV-CX-017` | The only created artifact is the first external ledger; all other allowed writes are in-place/existing-ledger writes. |
| `PRV-CX-018` | Product/eng edit scopes and every forbidden source/git/next-stage/ledger-repair action remain blocked. |
| `PRV-CX-019` | Closing message follows certification output and is last on every outcome with runtime-correct handoff syntax pending approval. |
| `PRV-CX-020` | Unexpected incidents log through DOCTOR only; documented input/findings/helper outcomes are not mislogged or re-verdictated. |

## Concrete eval cases

| Eval | Fixture/action | Required observations | Assertions |
|---|---|---|---|
| `plan-review-routing-and-paths` | flag/auto cases; file/dir/no/invalid path over three attempts | exact tune/subset; two retries then refusal; no pre-resolution writes | 001,002,003 |
| `plan-review-product-clean` | current PRD, no findings, no AHA | check 6 then 1/2/3; Clean row; normalization; reviewed stamp; clean terminal | 003..009,014..017 |
| `plan-review-product-autofix` | vague criterion, unlabeled DB touch, intent drift | severity exact; product-only patches; fix table; Fixed rows; AHA per C/M | 006,007,010,013,018 |
| `plan-review-product-decision-pause` | five contradictory behavior findings; some left undecided | batches <=4; suggestions; no guesses; openq writes/skips exact | 010,011,014 |
| `plan-review-eng-mechanical` | missing Files/F-ID, collision, cycle, unknown ID, no done-when, graph gap | script FINDING/SKIP/exit mapping; exact severity; all repaired or blocked | 003,005..010 |
| `plan-review-eng-contract-coherence` | two agent sections disagree on endpoint/schema ID | check 7 Critical; eng-only correction; no product edit | 004,006,007,010,018 |
| `plan-review-minor-choice` | Minor-only then fix/leave variants | one question; correct PRD/ledger state; no AHA learning | 012,013 |
| `plan-review-ledger-current-and-legacy` | absent report, existing report, legacy inline, repeat, malformed header | home precedence; one table; numbering/dedup/status; hard stop on drift | 008,009,017 |
| `plan-review-self-heal-recurrence` | counts 0/2, missing/malformed AHA | count before write; third-run flag names protocol; no protocol edit | 013,020 |
| `plan-review-open-questions-and-stamps` | bullets/table/placeholders; current and legacy frontmatter | exact table/status/idempotence and correct scalar stamp only | 014,015 |
| `plan-review-scope-and-write-boundary` | product finding in eng text plus attempted source/git/extra report | product leaves eng; unauthorized actions absent; one create max | 010,017,018 |
| `plan-review-shared-contracts-and-closure` | digest/mechanical/ledger/stamp/log failures with stubs | exact exit/fallback/logging/closing; all 3 digests and 12-helper closure current | 004,005,008,009,015,019,020 |

## Coverage accounting

- Phase-0 mapping ratio — file: `3/3 = 1.0000`.
- Phase-0 mapping ratio — reference: `2/2 = 1.0000` scoped refs, with all `4/4`
  shared-reference edges mapped.
- Phase-0 mapping ratio — behavior: `9/9 = 1.0000` tune/check branches (product four,
  eng five; shared checks counted in each executed tune).
- Phase-0 mapping ratio — eval-specification: `20/20 = 1.0000` assertions linked to
  concrete eval designs.
- Phase-0 mapping ratio — dependency: `12/12 = 1.0000` direct, downstream, transitive,
  and indirect helper closure.
- Runtime proof = `not-run` (correct for Phase 0; adapter execution is blocked by pending
  deviation decisions).
