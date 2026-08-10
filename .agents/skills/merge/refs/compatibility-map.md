---
skill: merge
canonical: .claude/skills/merge/
canonical_digest: 3839f7fb26b0225df54ea9b11658ec6b78ea878fb6f0a3878021b12be30e78aa
status: phase-0-audited-blocked-on-deviations
assertions: [MRG-CX-001, MRG-CX-002, MRG-CX-003, MRG-CX-004, MRG-CX-005, MRG-CX-006, MRG-CX-007, MRG-CX-008, MRG-CX-009, MRG-CX-010, MRG-CX-011, MRG-CX-012]
evals: [merge-file-digest-bijection, merge-trigger-policy-matrix, merge-staging-sequence, merge-production-sequence, merge-release-model-matrix, merge-human-gates-lock-rollback, merge-refusal-write-boundary, merge-output-artifact-contract, merge-runtime-closure]
---

# merge compatibility map

This Phase 0 map covers the full 12-file canonical tree and every discovered shared
contract, helper, command, setting, environment, cross-skill call, state transition and
artifact edge. It approves no deviation and implements no adapter.

## Coverage evidence

| Measure | Evidence | Result |
|---|---|---|
| Canonical files | `git ls-files '.claude/skills/merge/**'` | 12 |
| Exact rows below | canonical path compared with first column | `12/12 = 1.0000` |
| Aggregate digest | SHA-256 over sorted per-file SHA-256 stream | `3839f7fb26b0225df54ea9b11658ec6b78ea878fb6f0a3878021b12be30e78aa` |
| Destination bijection | one generated destination per source | `12/12 = 1.0000` |

### Standardized Phase 0 accounting

| Dimension | Mapped / canonical | Ratio | Runtime proof |
|---|---:|---:|---|
| Files | 12 / 12 | `1.0000` | not-run |
| References | 11 / 11 non-entry files | `1.0000` | not-run |
| Behavior domains | 12 / 12 assertions | `1.0000` | not-run |
| Eval specifications | 9 / 9 | `1.0000` | not-run |
| Dependency assignments | 16 / 16 transitive helpers | `1.0000` | not-run |

The runtime inventory contains **36 direct helper-to-merge-file edges** across 13
helpers. The semantic audit expands that to 16 assigned helpers through dispatch,
doctor logging and the uninvoked doctor detector retained under `AMB-CX-004`.

All rows are `generated-copy`. Phase 1 must preserve canonical payload bytes and use a
thin Codex adapter. `SKILL.md` maps to `CLAUDE-SKILL.md`; no candidate difference is
silently accepted.

## Canonical file coverage

| Canonical path | SHA-256 | Complete load/consumer contract | Codex path | Proof |
|---|---|---|---|---|
| `.claude/skills/merge/SKILL.md` | `66081fedb686bd9edb5e436f514b74da56ee07d2fc1aa75eb7e2df039f667d4f` | Entry point; mode parsing, policy, dispatch, human gates, terminals and shared loads. | `.agents/skills/merge/CLAUDE-SKILL.md` | MRG-CX-001/002/003/004 |
| `.claude/skills/merge/refs/deploy.md` | `d555273d7033c28e1add560df3d9256fac00189c9dfd6d5132676f63ff80bac6` | Production deploy release model; command discovery, deploy, verify, provenance and rollback. | `.agents/skills/merge/refs/deploy.md` | MRG-CX-005/007 |
| `.claude/skills/merge/refs/human-test-script.md` | `8c0e5f457ca5e73d033fa19db96e25e8d47049b823d614964744710db777c81d` | Staging terminal derives script; staged/direct production validates signoff coverage. | `.agents/skills/merge/refs/human-test-script.md` | MRG-CX-003/006 |
| `.claude/skills/merge/refs/output-schema.md` | `2b8cac73bf474e46cdff06c7675fcf43656ae2056c71f9069d63dd880f66dbc3` | Every clean, refusal, failure and skipped terminal plus paired artifacts. | `.agents/skills/merge/refs/output-schema.md` | MRG-CX-008 |
| `.claude/skills/merge/refs/production.md` | `62c1203e72296b77f2ca9d369c5769e7ec1dc2190731a8cf375bb06e88e9e13c` | `--production`; staged/direct preconditions, confirms, lock, PR/CI/review, ship and terminal. | `.agents/skills/merge/refs/production.md` | MRG-CX-004/006 |
| `.claude/skills/merge/refs/protection.md` | `70e5b3225286f9886a75d91ae93028a16b940380277f97c064180538e2185f81` | Staging and production branch protection checks and refusal/fallback policy. | `.agents/skills/merge/refs/protection.md` | MRG-CX-003/004/009 |
| `.claude/skills/merge/refs/protocol-init.md` | `21124d2e9eae99422d7c14d6acc3388939984636eac9bc228c2620645d7c2eb4` | `--init` or missing-policy bootstrap; probes, approvals, installs, branch bootstrap and policy write. | `.agents/skills/merge/refs/protocol-init.md` | MRG-CX-002/006/007 |
| `.claude/skills/merge/refs/refusal-patterns.md` | `8d008b7dde10d83925baab403f7e532b34b2cae421b459a61adaafd19ec8316a` | Closed refusal codes across init/staging/production, release models and forbidden writes. | `.agents/skills/merge/refs/refusal-patterns.md` | MRG-CX-009 |
| `.claude/skills/merge/refs/release-identity.md` | `c2bb245b25f5f65c72ab127af6f52ae2ed98dd128614e62945f2602c6e2eede8` | Production version/bump resolution, commit binding, tag and release provenance. | `.agents/skills/merge/refs/release-identity.md` | MRG-CX-004/005 |
| `.claude/skills/merge/refs/staging.md` | `8c903ee5619ede6c645b85927d822fa6e316484b65f0d489d0f3274178c7ae9d` | `--staging`; protection/readiness/PR/CI/merge/deploy verify and main-thread signoff stop. | `.agents/skills/merge/refs/staging.md` | MRG-CX-003/006 |
| `.claude/skills/merge/refs/submission.md` | `3a7ffe36e72d7bb477d4b909fae08ab1aff2fc28b2f2cd46a79b0d7d0f5e22a4` | Production submission release model; submit, receipt/status and monitoring handoff; never “live”. | `.agents/skills/merge/refs/submission.md` | MRG-CX-005/008 |
| `.claude/skills/merge/refs/verify-deploy.md` | `932f562484aae91dab6dd082df8a49e52caa53ed8e6fc514a88e28a853c89e05` | Staging and production deployment verification, smoke v2 and macOS checks. | `.agents/skills/merge/refs/verify-deploy.md` | MRG-CX-003/004/005 |

## Modes, policy and state transitions

- Exactly one shipping mode is selected: `--staging` or `--production`; `--init` is
  bootstrap only. Flags include repeatable `--prd`, production PRD, bump/version and
  quiet/status. Natural-language triggers must resolve to the same mode.
- Policy is resolved once. Missing policy uses defaults and nudges; `init:false`
  auto-runs init, while `init:true` proceeds. Direct staging is refused. Direct
  production requires two separate confirmations plus inline human-test attestation.
- Staging phase 1 subagent checks protection/readiness, PR and CI, merges feature to
  staging, verifies deployment and derives a manual test script. Main stops for a human
  decision and records inline signoff evidence.
- Production phase 1 subagent resolves identity and preconditions. Main owns all human
  gates. Phase 2 acquires the release lock, revalidates signoff, opens/checks the PR,
  requires green CI and human review, merges, fetches, rebinds identity, ships, verifies,
  stamps artifacts/tag/lane and releases the lock.
- Deploy and submission are orthogonal to staged/direct mode. Submission records receipt
  and status and hands off monitoring; it must never claim the release is live.
- A failed ship offers rollback/halt before the fix loop. No nested agent may ask a human
  question or infer approval. CI with an empty check set follows the canonical policy.

## Writes, human gates and forbidden effects

- Preserve the exact sanctioned-write list: policy initialization, feature-to-staging
  merge, signoff evidence, staging-to-production merge, release/tag metadata, intake/PRD
  stamps, lane/lock state and paired issue/report artifacts. Every other product/source
  edit is forbidden; fixes route through eng.
- Preserve gates for staging approval, unpinned signoff, two production confirmations,
  direct human testing, missing deploy command, failed-ship rollback/halt and fix loop.
- Init installs or creates only approved gaps and may bootstrap remote branches under
  approval; it does not write PLATFORMS. Lock ownership, stale-lock recovery and release
  on every terminal path are invariant.

## Complete runtime closure

- Shared refs: policy core/merge plus pre-merge selection evidence, gate-dispatch,
  agent-watch, heartbeat, safety floor, finding/report schemas, fix loop, closing and
  doctor logging. ENV declares merge consumption but no merge file loads it
  (`AMB-CX-002`).
- Helpers: `script-agent-watch.sh`, `script-status-tick.sh`,
  `script-branch-protection.sh`, `script-ci-status.py`, `script-platforms-parse.py`,
  `script-policy-read.py`, `script-policy-set.py`, `script-release-identity.sh`,
  `script-release-lock.sh`, `script-signoff-coverage.sh`, `script-smoke-run.sh`,
  `script-intake-stamp.sh`, `script-prd-stamp.sh`, `script-ts-miss.py` and
  `script-doctor-log.sh`. `script-ci-status.py` transitively reads policy.
  `script-doctor-detect.sh` claims merge init but has no canonical call edge.
- Commands/environment: git/gh, curl, brew and jq, detected deployment/store/submission
  CLIs, configured deploy/smoke/rollback commands, `HOME`, policy/status/watch variables,
  credentials supplied by those CLIs and all documented command exit codes.
- Settings/hooks: `.claude/settings.json` permissions, changelog pre-tool and stage
  post-tool hooks are contextual, not permission to change behavior. Codex hook/tool/path
  translations are pending `DEV-CX-001/002/003/004/005/006/007/008`.
- Blast radius: implicit natural-language activation is `DEV-CX-009`; timed heartbeat/
  watch is `DEV-CX-010`; wave width/queueing is `DEV-CX-013`. `DEV-CX-012` is not
  applicable because merge has no stable-head prompt-cache contract. `DEV-CX-011` is
  not applicable because every human gate is explicitly main-thread.

## Parity assertions and evals

| Assertion | Must remain true | Eval |
|---|---|---|
| MRG-CX-001 | Exact 12-file source/destination digest bijection. | merge-file-digest-bijection |
| MRG-CX-002 | Trigger, exclusive mode, flags and one-time policy resolution match. | merge-trigger-policy-matrix |
| MRG-CX-003 | Staging checks, PR/CI/merge/verify/script/stop order match. | merge-staging-sequence |
| MRG-CX-004 | Staged/direct production preconditions and ship sequence match. | merge-production-sequence |
| MRG-CX-005 | Deploy/submission matrix, identity, provenance and verification match. | merge-release-model-matrix |
| MRG-CX-006 | Main-thread human gates, lock lifecycle and rollback-before-fix match. | merge-human-gates-lock-rollback |
| MRG-CX-007 | Sanctioned writes, init approvals and rollback boundary match. | merge-refusal-write-boundary |
| MRG-CX-008 | Verdict/report/findings/closing bytes and submission wording match. | merge-output-artifact-contract |
| MRG-CX-009 | Closed refusals and no unauthorized merge/push/edit behavior match. | merge-refusal-write-boundary |
| MRG-CX-010 | Every helper/command/env/settings/hook edge is exercised or proven unreachable. | merge-runtime-closure |
| MRG-CX-011 | Claude tree and behavior remain unchanged by Codex artifacts. | merge-file-digest-bijection |
| MRG-CX-012 | Zero unapproved deviations; exact cases compare byte-for-byte. | all evals |

Fixtures must cover init, missing policy, staged/direct routes, both release models,
protected/unprotected branches, empty/nonempty CI, stale/owned lock, unpinned signoff,
human rejection, deploy/smoke failure, rollback/halt, submission pending, every refusal
and helper/tool failure. Compare stdout/stderr, exit code, questions, writes, git/PR/
release side effects, reports/findings and subagent trace.

## Blocking gaps / pending deviations

- `AMB-CX-004`: `script-doctor-detect.sh` claims merge `--init` consumption, but
  neither merge entry point nor init protocol invokes it; they spell probes directly.
- `AMB-CX-002`: shared ENV declares merge a read-only consumer, but no merge-scoped
  canonical file loads or uses ENV.
- `AMB-CX-005`: the SKILL dispatch summary assigns “lock read” to production phase
  1, while production protocol checks/acquires the lock only in phase 2 after human gates.
- `AMB-CX-006`: shared closing language says a production release is “live”, while
  submission explicitly prohibits saying “live” and requires a monitoring handoff.

No gap is resolved here. Phase 1 must stop until the canonical owner approves a rule.

Applicable pending platform candidates: `DEV-CX-001/002/003/004/005/006/007/008/009/010/013`.
