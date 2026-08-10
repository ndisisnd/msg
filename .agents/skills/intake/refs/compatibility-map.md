---
skill: intake
canonical: .claude/skills/intake/SKILL.md
canonical_digest: 7cd7e8a1e6d8ddaef55e8a14937d08031570c6463f84ba59f6ef85bfd1c0c2ca
status: phase-0-audited-blocked-on-deviations
assertions:
  - INT-CX-001
  - INT-CX-002
  - INT-CX-003
  - INT-CX-004
  - INT-CX-005
  - INT-CX-006
  - INT-CX-007
  - INT-CX-008
evals:
  - intake-file-integrity
  - intake-capture-thin-idea
  - intake-capture-split-hybrid
  - intake-capture-split-large
  - intake-update-cosmetic
  - intake-update-material
  - intake-update-status-lock
  - intake-delete-warning-cancel
  - intake-delete-confirmed-no-renumber
  - intake-legacy-log-migration
  - intake-writer-differential
---

# intake compatibility map

## Audit status

Phase 0 has inventoried the complete canonical file set and the transitive runtime
closure. Nothing in this map approves a Codex behavior difference. Implementation is
blocked on the user decisions for `DEV-CX-001`, `DEV-CX-002`, `DEV-CX-003`, and
`DEV-CX-007`.

Canonical aggregate digest: `7cd7e8a1e6d8ddaef55e8a14937d08031570c6463f84ba59f6ef85bfd1c0c2ca`
(five files, sorted per-file SHA-256 stream). File inventory result: **5 discovered,
5 rows, 5 unique paths, 0 duplicates, 0 omissions**.

## Canonical file coverage

| Canonical path | SHA-256 | Kind | Consumer/load condition | Codex disposition | Codex path | Translation | Proof |
|---|---|---|---|---|---|---|---|
| `.claude/skills/intake/SKILL.md` | `a2fc1258112accd8eb11d71adf56717391b65f261e3d9b9be9ea35ea40c28b38` | entry point | Always loaded for explicit invocation or matching natural-language capture/update/delete intent; dispatches exactly one mode. | generated-copy, runtime adapter blocked on pending deviations | `.agents/skills/intake/CLAUDE-SKILL.md` | Preserve canonical payload; adapter translates invocation/tool/home-path syntax only after approval. | `INT-CX-006`; `intake-file-integrity` |
| `.claude/skills/intake/refs/protocol-intake.md` | `3a0acad79814ae2bc4982d28c7e055a4215bbb4732cd238c2355d29d0671e6db` | protocol | Capture/default mode only; also reused by update Step 4/5 for interview, grade and split semantics. | generated-copy | `.agents/skills/intake/refs/protocol-intake.md` | No product-policy rewrite; runtime path/tool syntax is resolved by the adapter. | `INT-CX-001`, `INT-CX-002`, `INT-CX-006`; capture and material-update evals |
| `.claude/skills/intake/refs/protocol-update.md` | `784b26e6e26ddbefd22d213b997ff11f03fd1b2b5c8da369871267f0ba9f6d1d` | protocol | `--update` anywhere in the argument string or matching update intent; owns target resolution, locks, re-grade/re-split, targeted writes and log migration. | generated-copy | `.agents/skills/intake/refs/protocol-update.md` | Preserve exact lock, no-op, migration, logging and exit-code rules. | `INT-CX-002`, `INT-CX-003`, `INT-CX-007`; update and migration evals |
| `.claude/skills/intake/refs/protocol-delete.md` | `704174d84c830093b8aba967b618793983aac6fba90fc411a7245e00aebe2892` | protocol | `--delete` anywhere in the argument string or matching delete intent; owns warnings, one confirmation, removal and remove-log entry. | generated-copy | `.agents/skills/intake/refs/protocol-delete.md` | Preserve warning order, single multi-row confirm, no-renumber and ledger-only blast radius. | `INT-CX-004`, `INT-CX-005`, `INT-CX-007`; delete evals |
| `.claude/skills/intake/refs/rubric.md` | `b35ca8d08919e6f8956a10af4dd1af971ed3cc515ef9802a128b0694793f6108` | reference | Every capture grade and every material update re-grade; AHA calibration when present. | generated-copy | `.agents/skills/intake/refs/rubric.md` | Preserve Fibonacci bands, sequencing enum, single-turn/no-code-read rule and `C >= 8` gate. | `INT-CX-002`, `INT-CX-008`; split/material-update evals |

## Reference graph and conditional loads

```text
SKILL.md
  capture/default -> protocol-intake.md -> rubric.md
  --update         -> protocol-update.md -> protocol-intake.md Steps 2/3/4 -> rubric.md
  --delete         -> protocol-delete.md -> protocol-update.md target resolution + log contract
all terminal paths -> shared/closing-message.md
unexpected harness failure -> shared/doctor-logging.md -> script-doctor-log.sh
```

`protocol-intake.md` additionally reaches msg's `TEMPLATE-INTAKE.md` only when the
ledger is absent and the user approves scaffolding. `protocol-update.md` and
`protocol-delete.md` never scaffold it.

## Trigger, invocation, mode and flag mapping

| Canonical surface | Required Codex surface | Dispatch invariant | Status |
|---|---|---|---|
| `/intake [idea]`; capture natural-language triggers | `$intake [idea]`; same natural-language intent | No referent to an existing row is capture, never update. | pending `DEV-CX-001` |
| `/intake --update [#n/change]`; update intent | `$intake --update …`; same intent | Flag anywhere wins and is stripped before target resolution. | pending `DEV-CX-001` |
| `/intake --delete [#n …]`; delete intent | `$intake --delete …`; same intent | Flag anywhere wins; warnings and confirm are never skipped. | pending `DEV-CX-001` |
| both `--update` and `--delete` | same | Ask which mode; execute neither until resolved. | exact behavior, UI pending `DEV-CX-003` |

There are exactly three modes. There is no analysis, PRD-writing, status-stamping,
or implicit delete mode.

## Tool, path and human-gate mapping

| Claude contract | Codex requirement | Preserved behavior | Status |
|---|---|---|---|
| `Read`/`Bash` for ledger/AHA reads | Codex read/shell operations | Capture reads `INTAKE.md` + optional AHA only; update adds no codebase read; delete may list `features/` but never read PRD prose. | pending `DEV-CX-003` |
| `Write` for approved ledger scaffold | `apply_patch`/safe file write | Only capture may create `INTAKE.md`, from the exact template body, without overwrite. | pending `DEV-CX-003` |
| `AskUserQuestion` | structured Codex question, else an equivalent turn pause | Same options, defaults, batching and continuation point. | pending `DEV-CX-003` |
| `.claude/scripts` then `$HOME/.claude/scripts` | repo-local `.agents/scripts` then `$HOME/.agents/scripts` | Same helper bytes and exit meanings; never fall through to Claude home in a Codex-only install. | pending `DEV-CX-002` |

Mandatory gates: missing-ledger scaffold confirm (capture only); hybrid split confirm;
`C >= 8` split confirm; update disambiguation/change clarification as needed; delete
warning pass followed by one explicit confirm. Dismissing/cancelling delete writes
nothing. Question budgets remain at most two calls for a normal capture/update run.

## Writes, refusals and state transitions

Allowed writes are exact:

- Capture: create `INTAKE.md` only after approval when absent; append rows through
  `script-intake-stamp.sh --append-row`; each starts `backlog`, with empty `prd`.
- Update: change only `idea`, `goal`, `type`, and auto-derived `grade` on a `backlog`
  row through `--set-cell`; append one `modify`/`add` log row per changed cell/row.
- Delete: remove only selected ledger rows through `--remove-row`; append one
  `remove` log row per removal. Gaps remain.
- Update/delete may create `INTAKE-UPDATE.md` lazily and migrate a legacy inline
  update-log section exactly as the canonical protocol specifies.
- Unexpected harness incidents may append to `devkit/DOCTOR.md` through the shared
  logger; this never changes the primary outcome.

Hard refusals are exact: never read product code, draft a PRD, run an analysis pass,
invent precise estimates, write `status`/`prd`, edit `#`/`date`, scaffold in update or
delete, edit `in-progress`/`completed` rows in update, remove via update, renumber,
delete PRDs/files/branches, or delete without confirmation. Update lock refusals
re-offer selection rather than terminating.

State ownership remains: `intake` creates `backlog`; `plan-pm` owns
`in-progress` + `prd`; `merge --production` owns `completed`; GUI alone may hand-edit
status; intake update owns content; intake delete owns removal.

## Outputs and handoffs

Capture reports every created row and recommends `$plan-pm`. Update shows authoritative
old-to-new cell diffs, log count, any split-created rows, and recommends `$plan-pm` or
another update. Delete repeats dangling `blocked-by` consequences and recommends an
update to re-sequence. Codex handoff syntax is pending `DEV-CX-001`; no handoff is
invoked automatically. Every outcome ends with the shared closing-message contract.

## Transitive runtime closure

### Shared contracts

| Dependency | Consumer/load condition | Required disposition | Proof |
|---|---|---|---|
| `.claude/skills/shared/refs/closing-message.md` | Every mode and terminal after primary output. | Authoritative shared-map edge; runtime syntax adapted only after approval. | `INT-CX-006`; every behavior eval |
| `.claude/skills/shared/refs/doctor-logging.md` | Unexpected helper/tool/retry/write incident only. | Authoritative shared-map edge. | `INT-CX-007`; injected-failure eval |

### Helpers and cross-skill artifacts

| Dependency | Exact consumers | Contract |
|---|---|---|
| `.claude/scripts/script-intake-stamp.sh` | All modes | Shared deterministic writer: `--append-row`, `--set-cell`, `--remove-row`, `--log-append`; preserve exit codes and byte-local edits. Generated byte-identically for Codex. |
| `.claude/scripts/script-doctor-log.sh` | Shared incident path | Append-only unexpected-incident writer; never called for an expected refusal. |
| `.claude/skills/msg/refs/init/templates/TEMPLATE-INTAKE.md` | Capture Step 1 only, missing ledger + approval | Extract `## Template body` verbatim; cross-skill canonical row remains owned by msg's map. |
| `devkit/AHA.md` | Capture/material re-grade, when present | Read once for calibration; absent is silent. |
| `INTAKE.md` | All modes | Source and controlled target. |
| `INTAKE-UPDATE.md` | Update/delete only | Append-only, lazy-created; never read downstream today. |
| `features/` | Delete warning W1 | Directory listing only to confirm a live mapped PRD; never read or write content. |
| `plan-pm`, `plan-review`, `msg --gui`, `merge --production` | Handoffs/ownership boundaries | Recommend or describe ownership only; intake never invokes them except no skill call at all. |

External command closure is `bash`, `git` only where the shared helper uses it, and
standard shell/file utilities embedded in the deterministic helper. No web, network,
model-tier, hook, background-agent, subagent or concurrency dependency exists.

## Pending deviation candidates

- `DEV-CX-001`: slash invocation and handoffs become dollar invocation.
- `DEV-CX-002`: script discovery moves from `.claude` homes to `.agents` homes.
- `DEV-CX-003`: question/file/shell tool realization differs.
- `DEV-CX-007`: Claude `allowed_tools` is not itself a Codex host permission boundary.

No deviation is accepted. A rejection blocks the affected adapter behavior.

## Parity assertions

| ID | Assertion |
|---|---|
| `INT-CX-001` | Every captured row has the canonical columns, next never-reused number, `status=backlog`, and empty `prd`. |
| `INT-CX-002` | Material updates re-grade and re-run both split gates; cosmetic updates preserve grade bytes. |
| `INT-CX-003` | Update refuses `in-progress` and `completed`, never writes lifecycle cells, and re-offers selection. |
| `INT-CX-004` | Delete always warns then explicitly confirms, and never deletes a PRD, branch, or non-ledger file. |
| `INT-CX-005` | Delete never renumbers survivors and preserves historical log rows. |
| `INT-CX-006` | All five canonical files and all reference edges load under the same conditions; closing handoffs preserve semantic targets. |
| `INT-CX-007` | Every allowed/forbidden write and helper exit-code terminal matches the canonical protocol. |
| `INT-CX-008` | Grading remains single-turn, banded only, codebase-free, with `C >= 8` as the reviewability gate. |

## Concrete eval inventory

| Eval | Scenario and oracle | Assertions |
|---|---|---|
| `intake-file-integrity` | Discover five canonical paths, require five unique rows/current digests, generate twice, resolve every link. | `INT-CX-006` |
| `intake-capture-thin-idea` | Missing goal requires bounded interview; row written only after scaffold decision; snapshot schema/status. | `INT-CX-001`, `INT-CX-008` |
| `intake-capture-split-hybrid` | Multi-capability input; assert multi-select confirmation and one independently graded row per accepted idea. | `INT-CX-001`, `INT-CX-008` |
| `intake-capture-split-large` | `C:8` idea; test split and keep-whole branches, with no numeric estimate. | `INT-CX-002`, `INT-CX-008` |
| `intake-update-cosmetic` | Typo-only edit; exact prior grade, targeted cell change, one log entry. | `INT-CX-002`, `INT-CX-007` |
| `intake-update-material` | Scope change; assert re-grade, split-gate eligibility, diff echo and one log entry per change. | `INT-CX-002`, `INT-CX-007` |
| `intake-update-status-lock` | Select in-progress then completed rows; assert refusal, zero writes, and re-selection. | `INT-CX-003` |
| `intake-delete-warning-cancel` | W1-W4 fixture; warnings precede one confirm; cancel leaves repo snapshot identical. | `INT-CX-004` |
| `intake-delete-confirmed-no-renumber` | Multi-row delete; assert only target lines removed, gaps remain, remove logs carry final state/orphan. | `INT-CX-004`, `INT-CX-005` |
| `intake-legacy-log-migration` | Legacy inline log touched by update and delete; assert verbatim one-time migration and idempotency. | `INT-CX-005`, `INT-CX-007` |
| `intake-writer-differential` | Run existing helper fixtures under both runtime packages; compare stdout, exit codes and artifact bytes. | `INT-CX-001`, `INT-CX-005`, `INT-CX-007` |

## Coverage result

Phase-0 mapping ratios are `file=5/5=1.0000`, `reference=all discovered edges/all
discovered edges=1.0000`, `behavior=all inventoried behaviors/asserted=1.0000`,
`eval-specification=all assertions linked to specified evals/all assertions=1.0000`,
and `dependency=all discovered closure items/all discovered closure items=1.0000`.
Runtime proof is **not-run**. Mapping completeness does not approve deviations or claim
the future adapter passes; implementation and release remain blocked.
