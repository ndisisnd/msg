---
skill: plan-pm
canonical: .claude/skills/plan-pm/SKILL.md
canonical_digest: 159b6a58ff5d4694241b94b96daad2c6de73ba51b04e20847b0b9715027edd4a
status: phase-0-audited-blocked-on-deviations
assertions:
  - PPM-CX-001
  - PPM-CX-002
  - PPM-CX-003
  - PPM-CX-004
  - PPM-CX-005
  - PPM-CX-006
  - PPM-CX-007
  - PPM-CX-008
evals:
  - plan-pm-file-integrity
  - plan-pm-from-row
  - plan-pm-raw-prose-calls-intake
  - plan-pm-open-question-pause
  - plan-pm-breaking-safety-pause
  - plan-pm-sub-numbering
  - plan-pm-sub-parent-branch
  - plan-pm-update-v5
  - plan-pm-update-idempotent
  - plan-pm-update-preserves-reviewed
  - plan-pm-helper-differential
---

# plan-pm compatibility map

## Audit status

The canonical five-file set and complete runtime closure are inventoried. No
translation or deviation is approved. Implementation is blocked on user decisions for
`DEV-CX-001`, `DEV-CX-002`, `DEV-CX-003`, `DEV-CX-004`, and `DEV-CX-007`.

Aggregate digest: `159b6a58ff5d4694241b94b96daad2c6de73ba51b04e20847b0b9715027edd4a`.
Inventory: **5 discovered, 5 rows, 5 unique paths, 0 duplicate/omitted paths**.

## Canonical file coverage

| Canonical path | SHA-256 | Kind | Consumer/load condition | Codex disposition | Codex path | Translation | Proof |
|---|---|---|---|---|---|---|---|
| `.claude/skills/plan-pm/SKILL.md` | `8b2f6e0d0d1c502b8df068268f5541093de7d11e4a0f1070d972d94aa4a5538e` | entry point | Always for explicit/default/sub/update invocation or matching natural-language intent; owns devkit pre-read and dispatch. | generated-copy, adapter blocked | `.agents/skills/plan-pm/CLAUDE-SKILL.md` | Preserve payload; translate runtime invocation/tools/paths only after deviation decisions. | `PPM-CX-006`; `plan-pm-file-integrity` |
| `.claude/skills/plan-pm/refs/protocol-pm.md` | `b4d3f0bf153a896e0dd422fe261b711e0ac92a643ff97fdb913c18432898de95` | protocol | Default mode; also base protocol for `--sub` after its four deltas. | generated-copy | `.agents/skills/plan-pm/refs/protocol-pm.md` | Preserve five-step order, autonomous drafting, exact two pause classes and lifecycle stamp. | `PPM-CX-001`–`004`, `PPM-CX-007`; creation evals |
| `.claude/skills/plan-pm/refs/protocol-sub.md` | `3c94811079921539dda35ccadb1acc264e65028710f0aaff914cf0198c48cba8` | protocol | `--sub` or sub-PRD intent; loaded before protocol-pm and alters only parent resolution, intake seed, numbering/placement and frontmatter. | generated-copy | `.agents/skills/plan-pm/refs/protocol-sub.md` | Preserve parent branch/folder/lane sharing and mandatory dotted-ID intake ancestor. | `PPM-CX-001`, `PPM-CX-002`, `PPM-CX-008`; sub evals |
| `.claude/skills/plan-pm/refs/protocol-update.md` | `8e2a57714cf5e6fcd1fd2f965654aa8f44ded315f6d7977ab1322d5bc1774c68` | protocol | `--update`, update/migrate intent; replaces the five-step creation protocol. | generated-copy | `.agents/skills/plan-pm/refs/protocol-update.md` | Preserve L1/L2 split, only S1–S4 edits, invariant checks, retry ceiling and multi-target outcome. | `PPM-CX-005`, `PPM-CX-007`; update evals |
| `.claude/skills/plan-pm/refs/template-prd.md` | `02537102b6892fa294bc29954e34341b4ed7386edcef0d010ce1e6e65e7cde2b` | template/schema | Default/sub Step 3 initialization; update U3 source for exact placeholders and shape. | generated-copy | `.agents/skills/plan-pm/refs/template-prd.md` | Byte-identical template contract: current frontmatter, seven ordered sections, permanent F-IDs and reserved sections. | `PPM-CX-002`, `PPM-CX-005`; shape/update evals |

## Reference graph and load conditions

```text
SKILL.md
  default -> protocol-pm.md -> template-prd.md
               raw prose -> Skill(intake) -> resume Step 1
  --sub   -> protocol-sub.md deltas -> protocol-pm.md -> template-prd.md
  --update -> protocol-update.md -> template-prd.md exact style/placeholders
default/sub terminal -> shared/closing-message.md
update terminal       -> shared/closing-message.md
unexpected incident   -> shared/doctor-logging.md
digest reads          -> shared/session-cache.md freshness rule
```

## Trigger, mode and flag inventory

| Canonical surface | Codex requirement | Resolution invariant | Status |
|---|---|---|---|
| `/plan-pm`, `#n`, matching plan/draft language | `$plan-pm`, same natural-language intent | Exactly one intake row per creation run. | pending `DEV-CX-001` |
| `--sub [parent path/number]` and sub-PRD intent | same flag/intent | Parent: explicit, branch inference, then picker; explicit miss hard-refuses. | pending `DEV-CX-001` |
| `--update [path/number/--all]` and migration intent | same | Standalone maintenance path; no intake read/write and no creation protocol. | pending `DEV-CX-001` |

The only creation variants are top-level and sub-PRD. `--update` is not creation.
A request to skip PRD and start engineering hard-refuses and recommends plan-em only
after a PRD exists.

## Inputs and precedence

Default creation resolves: explicit `#n` or exact text match; otherwise picker; raw
prose with no row invokes intake using the prose verbatim, then re-reads the ledger.
Pre-run reads are `devkit/AHA.md`, root `CLAUDE.md`, `devkit/ARCHITECTURE.md`, and
`devkit/OPEN-QUESTIONS.md`, in parallel when present. Missing devkit context warns but
does not block or create files. `GLOSSARY.md` is written only for genuinely new terms;
`DESIGN-SYSTEM.md` is deliberately not read.

The Codex adapter must explicitly read canonical `CLAUDE.md` because Codex does not
automatically discover it. Whether init also creates/reconciles `AGENTS.md` is pending
`DEV-CX-004`; the map does not assume the two instruction files are equivalent.

## Tool, path, web and human-gate mapping

| Claude contract | Codex requirement | Invariant | Status |
|---|---|---|---|
| `Read`/`Bash`/`Edit`/`Write` | Codex read, shell and patch/file operations | Same read set and sanctioned destinations; helper outputs/exit codes control flow. | pending `DEV-CX-003/007` |
| `AskUserQuestion` | structured Codex ask or equivalent turn pause | Same options, defaults, batched questions and continuation points. | pending `DEV-CX-003` |
| `Skill("intake", prose)` | explicitly invoke Codex intake skill | Intake retains row ownership; plan-pm cannot synthesize the row itself. | pending `DEV-CX-001/003/008` |
| `WebSearch`/`WebFetch` allowed | Codex web tools only if needed to resolve an actual product fact | No mandatory network call; source use may not bypass the user-decision or anti-fabrication rules. | pending `DEV-CX-003` |
| repo-local `.claude/scripts`, then Claude home | Codex repo-local `.agents/scripts`, then Codex home | Same helper bytes; no Claude-home dependency. | pending `DEV-CX-002` |

Creation pauses only for: one batched unresolved-question call and a separate
breaking/DB/data/production-config safety call. The final follow-up ask remains. Sub mode
may need the parent picker. Update without a target asks for target(s). No section-by-
section approval exists. Browser/network availability is not a new gate.

## Writes, refusals and state transitions

Default creates one folder/file under `features/planned/prd-N-slug/`, writes the
current frontmatter and all seven sections, mirrors §3 PRD dependencies, may append a
new glossary term, may append a real learning to AHA, and stamps only the source intake
row's `status=in-progress` and `prd` mapping. It never writes engineering content into
§6/§7. Sub mode creates a nested dotted-ID PRD inside the parent's existing lane and
shares the parent branch; it creates no independent lane or branch.

Update changes only named existing PRD targets. Mechanical L1 may migrate legacy
frontmatter/section/report shape; L2 may only normalize open questions, scrub dropped
concepts where already editing, restore exactly three objective bullets, and restore
reserved placeholders. It must preserve §3/§4 text, F-IDs, populated §6/§7/agent blocks,
and `reviewed: yes`, except the canonical downgrade rule for unrepresentable content.

Hard refusals: no engineering-without-PRD; no creation without an intake ancestor;
invalid explicit sub parent; no top-level parent exists; invalid update target; L1
evidence collision; shape gate still failing after the protocol's retry ceiling. The
agent never edits validators to accept its output.

## Outputs and handoffs

Every creation output names the exact PRD path and `Open questions left: N`. Zero is
green, nonzero yellow. It recommends, never invokes, `$plan-em` on green. Sub mode names
the nested path. Update emits one target outcome row and an aggregate green/yellow/red
result. Handoff syntax is pending `DEV-CX-001`; semantic targets cannot change.

## Complete transitive runtime closure

### Shared contracts

| Dependency | Consumer/load condition | Proof |
|---|---|---|
| `.claude/skills/shared/refs/closing-message.md` | Every terminal in all modes. | `PPM-CX-006`; all behavior evals |
| `.claude/skills/shared/refs/doctor-logging.md` | Unexpected helper/tool/retry/write failures. | `PPM-CX-007`; failure-injection eval |
| `.claude/skills/shared/refs/session-cache.md` | Digest freshness in plan-review-facing contracts; PRD reads are regenerated, never stale. | `PPM-CX-006`; helper differential |

### Helpers, artifacts and cross-skill calls

| Dependency | Load condition and contract |
|---|---|
| `.claude/scripts/script-prd-scan.sh` | Default/sub Step 2, all lanes and nested PRDs; JSONL inventory and deps. |
| `.claude/scripts/script-prd-number` | Default `prd`; sub `sub <parent-n>`; deterministic next IDs. |
| `.claude/scripts/script-prd-deps-mirror.sh` | Default/sub after §3; union PRD IDs into `deps`/legacy `depends_on`, idempotently. |
| `.claude/scripts/script-prd-shape.py` | Fresh creation checks 1–5; update checks 1–6; its exit is a hard gate. |
| `.claude/scripts/script-prd-update.py` | Update U2 L1 migration and dry run. |
| `.claude/scripts/script-intake-stamp.sh` | Default/sub Step 5 lifecycle mapping only; raw-prose row creation remains intake's call. |
| `.claude/scripts/script-aha.sh` | Conditional real-learning append; terse fields and stable categories. |
| `.claude/scripts/script-doctor-log.sh` | Shared unexpected-incident path. |
| `intake` skill | Raw prose and every sub-PRD seed; returns a real row or creation stops. |
| `INTAKE.md` | Creation source and Step 5 target; update mode neither reads nor writes it. |
| `features/{planned,wip,done}` + legacy flat path | Prior scan; top-level creation always planned; sub placement follows parent. |
| `devkit/AHA.md`, `CLAUDE.md`, `devkit/ARCHITECTURE.md`, `devkit/OPEN-QUESTIONS.md` | Optional pre-run context with the exact absent-file behavior above. |
| `devkit/GLOSSARY.md` | Append new domain terms only; no PRD glossary section. |

External command closure: `bash`, `python3`, `grep`, normal filesystem utilities and
`git branch --show-current` for sub-parent inference. No required `gh`, deployment,
commit, hook, subagent, background task, model-tier or concurrency dependency.

## Pending deviation candidates

- `DEV-CX-001`: slash-to-dollar invocation and handoff syntax.
- `DEV-CX-002`: `.claude`/Claude-home helper resolution versus isolated Codex paths.
- `DEV-CX-003`: tool names, skill invocation and question UI.
- `DEV-CX-004`: canonical `CLAUDE.md` constraints versus Codex `AGENTS.md` discovery.
- `DEV-CX-007`: `allowed_tools` versus Codex sandbox/approval enforcement.
- `DEV-CX-008`: intake must exist and be callable as a Codex-compatible dependency.

No candidate is approved or silently compensated for.

## Parity assertions

| ID | Assertion |
|---|---|
| `PPM-CX-001` | No new feature/sub PRD is drafted without its own intake ancestor. |
| `PPM-CX-002` | New PRDs use the same deterministic numbering, dependency mirror, current template and shape gate. |
| `PPM-CX-003` | Open questions are batched and breaking/critical choices remain a distinct mandatory gate. |
| `PPM-CX-004` | Creation stamps exactly the source row `in-progress` plus PRD mapping. |
| `PPM-CX-005` | Update preserves certified contract text, F-IDs, review stamp and engineering work except canonical migration changes. |
| `PPM-CX-006` | Five canonical files, every reference edge and all shared dependencies resolve under identical conditions. |
| `PPM-CX-007` | Allowed writes, hard refusals, helper exit terminals and closing output match the canonical contract. |
| `PPM-CX-008` | Sub-PRDs are dotted, nested in the parent lane, share its branch and still run the full pipeline. |

## Concrete eval inventory

| Eval | Scenario/oracle | Assertions |
|---|---|---|
| `plan-pm-file-integrity` | Five unique canonical rows/current digests; all links and dependency edges resolve after two identical generations. | `PPM-CX-006` |
| `plan-pm-from-row` | Resolve existing row, scan/mirror, draft current shape, stamp that row; compare normalized artifact. | `PPM-CX-001`, `002`, `004` |
| `plan-pm-raw-prose-calls-intake` | No matching row; trace must show intake invocation before any PRD scan/write. | `PPM-CX-001`, `004` |
| `plan-pm-open-question-pause` | Unresolvable facts form one batch; skipped answers remain open and yield yellow. | `PPM-CX-003`, `007` |
| `plan-pm-breaking-safety-pause` | Shipped-contract and DB/config fixtures; assert distinct gate even with zero open questions. | `PPM-CX-003` |
| `plan-pm-sub-numbering` | Existing minors; assert next dotted number, fresh intake row and nested current-template PRD. | `PPM-CX-001`, `002`, `008` |
| `plan-pm-sub-parent-branch` | Explicit, branch-inferred, picker and invalid-parent cases; assert parent-lane placement/no new branch. | `PPM-CX-008` |
| `plan-pm-update-v5` | Legacy fixture through L1/L2; compare moved report/frontmatter/sections and protected bytes. | `PPM-CX-005`, `007` |
| `plan-pm-update-idempotent` | Run converged update twice; second run changes zero bytes. | `PPM-CX-005` |
| `plan-pm-update-preserves-reviewed` | Reviewed PRD with populated engineering sections; assert stamp and contract/engineering bytes survive. | `PPM-CX-005` |
| `plan-pm-helper-differential` | Reuse number, scan, deps, shape and update fixtures; compare stdout, exits and bytes across packages. | `PPM-CX-002`, `005`, `007` |

## Coverage result

Phase-0 mapping ratios are `file=5/5=1.0000`, `reference=all discovered edges/all
discovered edges=1.0000`, `behavior=all inventoried behaviors/asserted=1.0000`,
`eval-specification=all assertions linked to specified evals/all assertions=1.0000`,
and `dependency=all discovered closure items/all discovered closure items=1.0000`.
Runtime proof is **not-run**. Mapping completeness does not approve deviations or claim
the future adapter passes; implementation and release remain blocked.
