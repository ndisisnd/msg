---
skill: shared
canonical: .claude/skills/shared/
canonical_digest: 4367e015656df918017df34cd74944a3d695cec48b6351fba066afe37b76fda3
status: phase-0-audited-blocked-on-deviations
assertions:
  - SHR-CX-001
  - SHR-CX-002
  - SHR-CX-003
  - SHR-CX-004
  - SHR-CX-005
  - SHR-CX-006
  - SHR-CX-007
  - SHR-CX-008
  - SHR-CX-009
  - SHR-CX-010
  - SHR-CX-011
  - SHR-CX-012
evals:
  - shared-file-digest-bijection
  - shared-consumer-edge-closure
  - shared-finding-and-report-wire-contract
  - shared-policy-resolution-matrix
  - shared-safety-and-human-gates
  - shared-dispatch-watch-and-heartbeat
  - shared-fix-loop-ordering
  - shared-doctor-and-cache-degradation
---

# Shared contracts compatibility map

This is the authoritative Phase 0 map for every canonical shared contract. It maps
the complete 22-file shared tree and every discovered skill consumer. It does not
approve a Codex translation or implement an adapter. Candidate runtime differences
remain blocked by the deviation-first gate.

## Coverage evidence

| Measure | Evidence | Result |
|---|---|---|
| Canonical files | `git ls-files '.claude/skills/shared/**'` | 22 |
| Explicit rows below | exact-path rows, no wildcard | 22 |
| Unique row/path match | sorted canonical paths compared with first column | `22/22 = 1.0000` inventory coverage |
| Aggregate digest | SHA-256 over the sorted per-file SHA-256 stream | `4367e015656df918017df34cd74944a3d695cec48b6351fba066afe37b76fda3` |
| Generated destinations | one corresponding `.agents/skills/shared/refs/<name>` path per source | 22 |
| Behavioral/eval proof | assertions and eval designs below | mapped, not yet executed |

### Standardized Phase 0 accounting

| Dimension | Mapped / canonical | Ratio | Runtime proof |
|---|---:|---:|---|
| Files | 22 / 22 | `1.0000` | not-run |
| References/contracts | 22 / 22 | `1.0000` | not-run |
| Behavior domains | 12 / 12 assertions | `1.0000` | not-run |
| Eval specifications | 8 / 8 | `1.0000` | not-run |
| Dependency assignments | 31 / 31 directly consuming helpers | `1.0000` | not-run |

The runtime-inventory cross-check contains **37 direct helper-to-shared-reference
edges** across those 31 helpers. All 37 are assigned through the consumer rows and
reference graph. This is mapping completeness, not execution proof.

The consumer list combines direct reference edges with declared semantic consumers
inside the shared contracts. Self-references are omitted from the skill list but remain
in the reference graph.

## Canonical file coverage and complete consumers

All rows use `generated-copy`: Phase 1 will generate a byte-faithful canonical payload.
Any runtime-specific behavior is supplied by the Codex adapter, not by editing these
contracts. `DEV-CX-001` through `DEV-CX-010`, plus `DEV-CX-012/013`, are pending
where applicable; none is approved.

| Canonical path | SHA-256 | Kind | Complete skill consumers and load condition | Codex path | Runtime translation | Proof |
|---|---|---|---|---|---|---|
| `.claude/skills/shared/refs/agent-watch.md` | `58d9305df9b8dd84be1e11618b14c59c241328fc4c1cb1f9e43133ebf2b31751` | protocol | `eng`, `plan-em`, `pre-merge`; whenever a leaf wave is backgrounded/polled. `merge` consumes it transitively through gate-dispatch. | `.agents/skills/shared/refs/agent-watch.md` | Agent background/watch operations map to Codex spawn/list/wait/steer without changing observational-only semantics or the no-auto-stop rule. | `SHR-CX-005`; `shared-dispatch-watch-and-heartbeat` |
| `.claude/skills/shared/refs/attribute-the-cause.md` | `f6654c5304f11274d4935723a1df4e24a562cc2abb052ffbe79ae946c4128d79` | rule | `pre-merge`; perf, API and load findings when causal evidence exists. | `.agents/skills/shared/refs/attribute-the-cause.md` | No tool translation; preserve honest degradation when causal evidence is absent. | `SHR-CX-009`; `shared-finding-and-report-wire-contract` |
| `.claude/skills/shared/refs/check-report-schema.md` | `9ec458f6c46cd89227c16b954d9ce284bbb99532e680b86ed87d670aa3feb385` | schema | `pre-merge`; `--init/--update` detect reports and every gate component result report. | `.agents/skills/shared/refs/check-report-schema.md` | Preserve detect/result fields, paths and always-write result rule byte-for-byte. | `SHR-CX-002`; `shared-finding-and-report-wire-contract` |
| `.claude/skills/shared/refs/closing-message.md` | `570c2dfcf9aeb2adee91b7b2e7993429a9a9c5c1f0afb2c688765fdf97b73561` | protocol | All nine skills: `msg`, `intake`, `plan-pm`, `plan-review`, `plan-em`, `eng`, `pre-merge`, `merge`, `emulate`; every terminal except the named msg pure-emission modes. | `.agents/skills/shared/refs/closing-message.md` | Keep verdict-to-colour and ordering; translate user-facing `/skill` commands to `$skill` only after `DEV-CX-001` approval. | `SHR-CX-003`; `shared-finding-and-report-wire-contract` |
| `.claude/skills/shared/refs/component-catalog.md` | `528a732cb8ea87c0cbbe29146dce68a77c7741d8ee9c644acae61dd0d988829f` | catalog | `pre-merge`; `--init/--update`, pipeline resolution, all component protocols and test selection. | `.agents/skills/shared/refs/component-catalog.md` | The same catalog is passed to the same resolver; no Codex-side ordering or metadata inference. | `SHR-CX-004`; `shared-policy-resolution-matrix` |
| `.claude/skills/shared/refs/doctor-logging.md` | `3fa9f0d6e74dbbd1b150d93b4a9864a2fd18863c695d92a6793258c8fce71716` | protocol | All nine skills on unexpected harness incidents; `msg --doctor` is the sole reader. | `.agents/skills/shared/refs/doctor-logging.md` | Codex tool failures map to the same five signature classes and same appender; designed exit 3 remains non-incident. | `SHR-CX-010`; `shared-doctor-and-cache-degradation` |
| `.claude/skills/shared/refs/env-contract.md` | `e7196610962a3941fa6f2c0027d348acf3a008b6771e7e46d7d4b15867d6c32d` | schema/protocol | `msg` scaffolds context; `pre-merge --init/--update` writes and gate executor reads; the contract also declares `merge` read-only consumption, but no merge-scoped ref invokes it (pending `AMB-CX-002`). | `.agents/skills/shared/refs/env-contract.md` | Preserve fenced JSON, placeholder resolution, one/composite sandbox and loud-degrade behavior. Do not invent merge consumption. | `SHR-CX-004`, `SHR-CX-012`; `shared-policy-resolution-matrix` |
| `.claude/skills/shared/refs/exec-mode-pref.md` | `af9625ff509c2cb8235a9c9103a45fbf1723e5e4eebf0d8e74706fd89f7e8586` | protocol | `msg --init/--update` seeds; `plan-em` reads/persists `team|solo`. | `.agents/skills/shared/refs/exec-mode-pref.md` | Local/global Codex preference paths require `DEV-CX-002`; precedence and no-overwrite rules stay identical. | `SHR-CX-006`; `shared-policy-resolution-matrix` |
| `.claude/skills/shared/refs/finding-schema.md` | `e4c0c851c95862ff1c36e385ca8cb475738fd565332c231d7e88a2dcce3942eb` | schema | `pre-merge`, `merge`, `eng`; also `msg --gui`, fix loops and plan-em consume their persisted findings transitively. | `.agents/skills/shared/refs/finding-schema.md` | Closed top-level field set, enums, dedup/regression keys and legacy read mapping are unchanged. | `SHR-CX-002`; `shared-finding-and-report-wire-contract` |
| `.claude/skills/shared/refs/fix-loop.md` | `f4e5e1ec053b59ce6513780c8ee4104be1c11925e71633e3b439c75cf1bcb33a` | protocol | `pre-merge` and `merge` after failed runs; invokes `eng --plan`, then orchestrated `eng --build`; merge rollback/halt offer precedes it. | `.agents/skills/shared/refs/fix-loop.md` | Main-thread questions and cross-skill calls need `DEV-CX-001/003/005/006/008`; order, autonomy rules and same-report path remain fixed. | `SHR-CX-007`; `shared-fix-loop-ordering` |
| `.claude/skills/shared/refs/gate-dispatch.md` | `07c22dd651cefa085246bd5e4d60c4383d22bec06d4577083ad397254b6fd6af` | protocol | `pre-merge` gate runs and `merge` mechanical phases; uses agent-watch/status heartbeat and keeps human gates in the main thread. | `.agents/skills/shared/refs/gate-dispatch.md` | Claude Agent/background lifecycle maps to Codex collaboration only after `DEV-CX-003/005/006`; dispatcher remains workless and relays artifact bytes unchanged. | `SHR-CX-005`; `shared-dispatch-watch-and-heartbeat` |
| `.claude/skills/shared/refs/name-the-user-impact.md` | `345aa5709fbe6b27ceb7717c572efdfbaf3f5292aaeacebf7c3538cc39190af3` | rule | `pre-merge`; a11y, mobile, smoke and API/perf causal framing where cited. | `.agents/skills/shared/refs/name-the-user-impact.md` | No runtime translation; preserve impact-first and no-fabrication rule. | `SHR-CX-009`; `shared-finding-and-report-wire-contract` |
| `.claude/skills/shared/refs/policy-schema-merge.md` | `1c38ead2a3056e7ac4880037841030787473d20159c6c64c7f55912cd1bfcb10` | schema | `merge` all modes; `pre-merge --init` writes the shared `steps.ci` decision; merge reads branch protection, steps, release model, readiness and lock. | `.agents/skills/shared/refs/policy-schema-merge.md` | Same policy scripts and defaults; no model-side re-derivation. | `SHR-CX-004`; `shared-policy-resolution-matrix` |
| `.claude/skills/shared/refs/policy-schema-pre-merge.md` | `68ec91da53464da7e0ef09e0d3c727d1070832b3f4154a98f933feb0d9fda6c5` | schema | `pre-merge` all modes; `msg --update` changes selection decision; `merge --staging` reads durable test-selection evidence for miss attribution. | `.agents/skills/shared/refs/policy-schema-pre-merge.md` | Same manifest/test-selection schema, source signature and criticality stamp; merge loads only its explicitly cited selection subset. | `SHR-CX-004`; `shared-policy-resolution-matrix` |
| `.claude/skills/shared/refs/policy-schema.md` | `6f29c7c29064eeded5359afc14dc4ae4fbf3f804cbc134fbb2bcc387b8992108` | schema | `msg`, `pre-merge`, `merge`; seed/update writers plus both gate read contracts. Agent-watch and status scripts independently read their policy keys. | `.agents/skills/shared/refs/policy-schema.md` | Same `script-policy-set.py` writer and `script-policy-read.py` merge read path; Codex path isolation needs `DEV-CX-002`. | `SHR-CX-004`; `shared-policy-resolution-matrix` |
| `.claude/skills/shared/refs/ratchet-vs-base.md` | `d6b6fae146fa7913c5257972afe443d3b3eb78bf8d1a84ea8257d0588e1f2a75` | rule | `pre-merge`; coverage, perf and API base comparisons. | `.agents/skills/shared/refs/ratchet-vs-base.md` | No translation; same like-for-like/no-base/no-fabrication contract. | `SHR-CX-009`; `shared-finding-and-report-wire-contract` |
| `.claude/skills/shared/refs/report-schema.md` | `a0d66d57547b5f3fb1a6dfcf52941e62bbba5b0df3658df3d047968becceaea4` | schema | `eng`, `pre-merge`, `merge` write; `msg --gui` parses; fix loop consumes paired JSON paths. | `.agents/skills/shared/refs/report-schema.md` | Preserve numbering, append-only behavior, flat frontmatter, fixed headings, paired stems and terminal issue-summary bytes. | `SHR-CX-002`; `shared-finding-and-report-wire-contract` |
| `.claude/skills/shared/refs/safety-floor.md` | `3631555d7daebfaac8708c9f84b1d18c91155ff7b7e74fd5b22e1aeae9c34fa5` | policy | Declares all nine skills in scope; directly operational for `eng`, `pre-merge`, `merge`, `emulate`, and inherited by the other artifact-writing skills. | `.agents/skills/shared/refs/safety-floor.md` | Codex sandbox may add approvals but may not broaden power or delete human gates; enforcement equivalence is pending `DEV-CX-007`. | `SHR-CX-001`; `shared-safety-and-human-gates` |
| `.claude/skills/shared/refs/session-cache.md` | `6f6c0a7fc61e8edfeb1340829011151905c61a92191b08f1e92e975bec40a48f` | protocol | `eng`, `plan-em`, `plan-review`, `pre-merge` verify prelude; digest/cache generators and standards payloads. | `.agents/skills/shared/refs/session-cache.md` | Codex cache root/path requires `DEV-CX-002`; hash freshness, disposable-cache and source-canonical rules remain identical. | `SHR-CX-010`; `shared-doctor-and-cache-degradation` |
| `.claude/skills/shared/refs/status-heartbeat.md` | `f66e4c5c8a5b0e4dd8d4a4c002c8bff0d95e01360fd05ae980e599f40110810b` | protocol | `eng`, `plan-em`, `pre-merge`, `merge`; long orchestrated phases and dispatch relay. | `.agents/skills/shared/refs/status-heartbeat.md` | Use same script/output; Codex collaboration supplies checkpoints. Observational/no-verdict effect is fixed. | `SHR-CX-005`; `shared-dispatch-watch-and-heartbeat` |
| `.claude/skills/shared/refs/tooling-detection.md` | `2dd8c954baa915e3b0f05544c79534763e715840ecca7d38d07ef3dea79d1aad` | reference | `pre-merge --init/--update` maintainers via component catalog and preflight scripts; not hand-walked at gate time. Its no-secret-scanner `warn` sentence conflicts with the blocker floor (`AMB-CX-003`). | `.agents/skills/shared/refs/tooling-detection.md` | Preserve the file pending canonical resolution; do not let the stale sentence weaken the authoritative security floor. | `SHR-CX-011`; `shared-policy-resolution-matrix` |
| `.claude/skills/shared/refs/verify-prelude.md` | `1e142edad1c78d0037fec1050f97d8a09b9c4bee18c9e5aacdec1a83135b62f5` | protocol | `pre-merge` only; top-of-run diff cache generation and fresh reuse. | `.agents/skills/shared/refs/verify-prelude.md` | Same diff helper and HEAD/base key; cache path translation blocked by `DEV-CX-002`. | `SHR-CX-010`; `shared-doctor-and-cache-degradation` |

## Reference graph

The principal shared edges are:

- `gate-dispatch -> agent-watch + status-heartbeat + doctor-logging`.
- `agent-watch <-> status-heartbeat` for poll checkpoints; policy thresholds come
  from `policy-schema` but scripts read them directly.
- `policy-schema -> policy-schema-pre-merge + policy-schema-merge + env-contract`.
- `component-catalog -> tooling-detection + env-contract + safety-floor + finding
  framing rules`; pre-merge protocols load component refs on demand.
- `finding-schema -> report-schema`; `report-schema -> fix-loop + closing-message`.
- `fix-loop -> eng plan/build contracts` and, for merge, follows the caller-owned
  rollback/halt offer.
- `verify-prelude -> session-cache`.

All relative edges resolve in the canonical tree. Generated copies must preserve the
same relative structure; the static compatibility checker must compare the graph.

## Shared runtime, paths, tools and authority

| Claude contract | Planned Codex mapping | Gate |
|---|---|---|
| Slash invocations in closing messages/fix loops | Active-runtime `$skill` syntax | `DEV-CX-001` pending |
| `.claude` repo/global refs and cache paths | `.agents` repo/global paths, legacy Claude location read-only last | `DEV-CX-002` pending |
| `Read`, `Write`, `Bash`, `AskUserQuestion`, `Agent`, `Skill` | Codex inspection, `apply_patch`, shell, main-thread question, collaboration and explicit skill loading | `DEV-CX-003` pending |
| Background and nested agents | Codex child threads, wait/list/steer, distinct identities and run ids | `DEV-CX-005/006` pending |
| Claude `allowed_tools`, permissions and hooks | Codex sandbox/approval and adapter constraints | `DEV-CX-007` pending |
| External `cook` and orchestrated `eng` dependencies | Verified Codex skills with unchanged packets/output | `DEV-CX-008` pending |
| Natural-language skill activation | Preserve canonical implicit triggers rather than adapter-only explicit invocation | `DEV-CX-009` pending |
| Timed heartbeat and stall watch | Preserve elapsed-time cadence, warning/escalation and no-auto-stop semantics | `DEV-CX-010` pending |
| Prompt packet prefix/cache promises | Preserve stable-head byte ordering where a consuming skill specifies it; performance equivalence is unproven | `DEV-CX-012` pending where applicable |
| Wave width, queues and scheduling | Preserve dependency order and observable cadence despite Codex concurrency mechanics | `DEV-CX-013` pending |

`DEV-CX-004` applies whenever a consumer resolves project instructions. The shared
contracts keep every mapped gate explicitly main-thread; the leaf-relay behavior tracked
by `DEV-CX-011` enters through the eng packet contract instead.

The existing `.agents/skills/shared/refs/*.md` files are pre-existing user work.
They are evidence only until the generator classifies them; this map does not approve
or overwrite their translations.

## Parity assertions

- `SHR-CX-001`: Per-skill write authority and every human/safety gate are unchanged.
- `SHR-CX-002`: Finding, check-report and run-report schemas retain exact fields,
  enums, paths, numbering, headings, dedup keys and paired-file relationships.
- `SHR-CX-003`: Every applicable run ends with the same closing protocol and semantic
  next step in active-runtime syntax.
- `SHR-CX-004`: Policy lifecycle, defaults, validation, writer ownership and
  cross-half loading are identical.
- `SHR-CX-005`: Dispatch/watch/heartbeat remain observational; phase gates stay main
  thread, run ids stay disjoint and machine emissions relay byte-identically.
- `SHR-CX-006`: Preference resolution remains local-first, flag-first and idempotent.
- `SHR-CX-007`: Failed-run recovery preserves rollback-before-fix and plan-before-build.
- `SHR-CX-008`: Every shared canonical file has one current digest row and every
  declared consumer has a dependency edge.
- `SHR-CX-009`: Ratchet and finding-framing rules never fabricate evidence or cause.
- `SHR-CX-010`: Cache, report and doctor-log failures degrade exactly as specified and
  never change the underlying verdict.
- `SHR-CX-011`: Maintainer-only tooling documentation cannot override executable
  component/security contracts.
- `SHR-CX-012`: Declared semantic consumers must be backed by an executable reference
  edge or remain a release-blocking map gap.

## Eval designs

| Eval | Assertions | Proof |
|---|---|---|
| `shared-file-digest-bijection` | `SHR-CX-008` | Discover 22 canonical files; require 22 unique rows, current hashes and generated destinations. |
| `shared-consumer-edge-closure` | `SHR-CX-008`, `SHR-CX-012` | Traverse direct and declared consumer edges; fail on missing, orphaned or unsupported edges. |
| `shared-finding-and-report-wire-contract` | `SHR-CX-002/003/009` | Golden schema/path/heading/terminal tests plus active-runtime handoff normalization. |
| `shared-policy-resolution-matrix` | `SHR-CX-004/006/011/012` | Exercise absent, malformed, bad-enum, staged/direct, CI-opt-out, selection and readiness states. |
| `shared-safety-and-human-gates` | `SHR-CX-001` | Trace every sanctioned and forbidden write plus staging/direct/production gates. |
| `shared-dispatch-watch-and-heartbeat` | `SHR-CX-005` | Stub agents/time; prove phase splits, no auto-stop, disjoint ids, cleanup and byte relay. |
| `shared-fix-loop-ordering` | `SHR-CX-007` | Fail pre-merge/merge; prove same issues file, rollback first, then plan and build offers. |
| `shared-doctor-and-cache-degradation` | `SHR-CX-010` | Missing/corrupt/cache/log/script cases never re-verdict a run. |

## Blocking gaps and deviation candidates

No difference is approved.

| ID | Evidence | Why blocked |
|---|---|---|
| `AMB-CX-002` | `env-contract.md` declares merge a reader; no file under `.claude/skills/merge/` references or executes the ENV contract. | A 1:1 adapter cannot both preserve the declared edge and avoid inventing new merge behavior. User/canonical decision required before Phase 1. |
| `AMB-CX-003` | `tooling-detection.md` says missing secret scanner emits `warn`; `pre-merge/refs/universal/protocol-security.md`, `severity-rubric.md` and `safety-floor.md` require a `blocker`. | The canonical sources disagree on a safety-floor verdict. The adapter must not pick silently. |
| `AMB-CX-006` | `closing-message.md` describes production as live, while merge submission prohibits that wording and requires monitoring handoff. | Shared closing language cannot be applied byte-for-byte to both release models until the evidence threshold is reconciled. |

Known applicable platform candidates are `DEV-CX-001/002/003/004/005/006/007/008/009/010/012/013`.
They remain pending. Gaps/deviations block adapter implementation and release; they do
not reduce the inventory denominator.
