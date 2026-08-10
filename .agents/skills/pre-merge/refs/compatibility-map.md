---
skill: pre-merge
canonical: .claude/skills/pre-merge/
canonical_digest: f45aba7a277c47b30fc85df672b35edd73ab67ea3ffa3ed525160063cd51e817
status: phase-0-audited-blocked-on-deviations
assertions: [PMG-CX-001, PMG-CX-002, PMG-CX-003, PMG-CX-004, PMG-CX-005, PMG-CX-006, PMG-CX-007, PMG-CX-008, PMG-CX-009, PMG-CX-010, PMG-CX-011, PMG-CX-012]
evals: [premerge-file-digest-bijection, premerge-trigger-mode-matrix, premerge-manifest-dag, premerge-component-contracts, premerge-selection-safety-floor, premerge-refusal-and-write-boundary, premerge-verdict-output-pr, premerge-init-update-gates, premerge-runtime-closure]
---

# pre-merge compatibility map

This Phase 0 map covers the complete 39-file canonical tree, its shared contracts,
helper scripts, commands, hooks, settings, environment, cross-skill calls, state
transitions and artifacts. It approves no Codex deviation and implements no adapter.

## Coverage evidence

| Measure | Evidence | Result |
|---|---|---|
| Canonical files | `git ls-files '.claude/skills/pre-merge/**'` | 39 |
| Exact rows below | canonical path compared with first column | `39/39 = 1.0000` |
| Aggregate digest | SHA-256 over sorted per-file SHA-256 stream | `f45aba7a277c47b30fc85df672b35edd73ab67ea3ffa3ed525160063cd51e817` |
| Destination bijection | one generated destination per source | `39/39 = 1.0000` |

### Standardized Phase 0 accounting

| Dimension | Mapped / canonical | Ratio | Runtime proof |
|---|---:|---:|---|
| Files | 39 / 39 | `1.0000` | not-run |
| References/templates/scripts | 38 / 38 non-entry files | `1.0000` | not-run |
| Behavior domains | 12 / 12 assertions | `1.0000` | not-run |
| Eval specifications | 9 / 9 | `1.0000` | not-run |
| Dependency assignments | 30 / 30 transitive helpers | `1.0000` | not-run |

The runtime inventory contains **16 direct helper-to-pre-merge-file edges** across
12 helpers. The semantic audit expands that to 30 assigned helpers: the scoped diff
resolver, shared orchestration/policy/report helpers, 16 dynamically selected preflight
scripts and the uninvoked doctor detector retained under `AMB-CX-004`.

All rows are `generated-copy`. Phase 1 must preserve the canonical payload and put
Codex-only routing in a thin adapter. `SKILL.md` becomes `CLAUDE-SKILL.md` so it
cannot compete with the adapter entry point. No pending DEV item is normalized here.

## Canonical file coverage

| Canonical path | SHA-256 | Load/consumer contract | Codex path | Proof |
|---|---|---|---|---|
| `.claude/skills/pre-merge/SKILL.md` | `777735ee989c17ef47faec1578466ce4f07a19389dc91946bdf06bfdda7cd54b` | Entry point; all invocations, modes, dispatch, terminals and shared loads. | `.agents/skills/pre-merge/CLAUDE-SKILL.md` | PMG-CX-001/002/003/006 |
| `.claude/skills/pre-merge/refs/_common.md` | `e89c3a1f1b2ee7c8f252e5ffe93a16954711acdbdf8ed55fc57ef00c5d9ace4e` | Every component agent; common result/finding, diff and command rules. | `.agents/skills/pre-merge/refs/_common.md` | PMG-CX-004 |
| `.claude/skills/pre-merge/refs/executor.md` | `dd11999163cd8ede0e0db2ce18435f7b3ff69a4a2541f4339863543c25b0b3fe` | Gate subagent; manifest join, resolver DAG, waves, aggregation and terminal node. | `.agents/skills/pre-merge/refs/executor.md` | PMG-CX-003/005 |
| `.claude/skills/pre-merge/refs/finding-schema.md` | `607d6de2967a2352a294e56a4fd6f21ca004fd38dbd092f0e052996ca11dd88a` | Every emitted pre-merge finding; narrows shared schema. | `.agents/skills/pre-merge/refs/finding-schema.md` | PMG-CX-004/006 |
| `.claude/skills/pre-merge/refs/output-schema.md` | `62b3d6c79db60ea5027b071320e88280088bf26f2c44751037ea015b33325877` | Every refusal, clean, failing and skipped terminal. | `.agents/skills/pre-merge/refs/output-schema.md` | PMG-CX-006 |
| `.claude/skills/pre-merge/refs/platform-profiles.md` | `371e8bf1729f8a22cef710cd573f10515526d1e3d56596b181696389a22399db` | Init/update detection and platform-component enablement. | `.agents/skills/pre-merge/refs/platform-profiles.md` | PMG-CX-007 |
| `.claude/skills/pre-merge/refs/platform/protocol-a11y.md` | `6c86fc2b4a8a2b333c5140e636914e757430b4b3cea9afc46b61701d0cd41b55` | `a11y` manifest component when enabled. | `.agents/skills/pre-merge/refs/platform/protocol-a11y.md` | PMG-CX-004 |
| `.claude/skills/pre-merge/refs/platform/protocol-api.md` | `fd6b5f030326c466a48bdd587725922c9397e686f1fd65ca2a9b25ccc86bb01c` | `api` component; loads ratchet/cause rules. | `.agents/skills/pre-merge/refs/platform/protocol-api.md` | PMG-CX-004 |
| `.claude/skills/pre-merge/refs/platform/protocol-e2e.md` | `4bff947e8e67b79040cb58af5ab04e28a65142998be2dfaf80b327453800951e` | `e2e` component after required environment/smoke dependencies. | `.agents/skills/pre-merge/refs/platform/protocol-e2e.md` | PMG-CX-004 |
| `.claude/skills/pre-merge/refs/platform/protocol-load.md` | `37867b20c39f8cfb5bd783d428fbb26c3a05cdfaefd5b3d18541688463d0fe59` | `load` component; isolated execution and causal attribution. | `.agents/skills/pre-merge/refs/platform/protocol-load.md` | PMG-CX-004 |
| `.claude/skills/pre-merge/refs/platform/protocol-migration.md` | `9af502deb9104d13f68b28af4cedeab9636c5eab0f8c83acfb6688f4289ccf20` | Critical `migration` component when enabled. | `.agents/skills/pre-merge/refs/platform/protocol-migration.md` | PMG-CX-004/005 |
| `.claude/skills/pre-merge/refs/platform/protocol-mobile.md` | `655d42918e4ab7fe1a3ed6e4ae89d2a5a078817998fa7f4269a2184d1508d7f7` | `mobile` component; platform/emulator evidence and user impact. | `.agents/skills/pre-merge/refs/platform/protocol-mobile.md` | PMG-CX-004 |
| `.claude/skills/pre-merge/refs/platform/protocol-perf.md` | `6eab36d549b253e5195f46681700de5b75edbf88057b5c47be26dc502884893e` | `perf` component; isolated run plus ratchet/cause rules. | `.agents/skills/pre-merge/refs/platform/protocol-perf.md` | PMG-CX-004 |
| `.claude/skills/pre-merge/refs/platform/protocol-smoke.md` | `79f2ff8f7a313e58cc0ff393568dfb3fa6fd42a464734e490695db19df52f89e` | `smoke` component; first environment-dependent wave. | `.agents/skills/pre-merge/refs/platform/protocol-smoke.md` | PMG-CX-003/004 |
| `.claude/skills/pre-merge/refs/prd/protocol-manual-test-plan.md` | `572e7e7668c0dcaa545c8601d2ab5b388a3da1326d1b20b58c9196a8892a86db` | PRD `manual_test_plan` component for each selected PRD. | `.agents/skills/pre-merge/refs/prd/protocol-manual-test-plan.md` | PMG-CX-004 |
| `.claude/skills/pre-merge/refs/prd/protocol-prd-consistency.md` | `2ace599b0abf62d805048f19edaa1ef201366c485e0de9d57186a60383ad4e43` | PRD `prd_consistency` component for each selected PRD. | `.agents/skills/pre-merge/refs/prd/protocol-prd-consistency.md` | PMG-CX-004 |
| `.claude/skills/pre-merge/refs/protocol-init.md` | `4d726e99cf13d672159e1539cb652d35c17001ff8061cb8d6de29fc0f3962508` | `--init` and `--update`; detect, approval and policy/config writes. | `.agents/skills/pre-merge/refs/protocol-init.md` | PMG-CX-007/008 |
| `.claude/skills/pre-merge/refs/protocol-update-criticality.md` | `2ca5afda7dd84361888db5f41e1dba5ca6a54bc51dfad7fbaa9221aa3a7242e7` | `--update-criticality`; one table approval, tests, reviewed commit and stamp. | `.agents/skills/pre-merge/refs/protocol-update-criticality.md` | PMG-CX-008 |
| `.claude/skills/pre-merge/refs/refusal-patterns.md` | `b42e43e57a776bf7454f0dd4ce4b736c6a1ca3ebe502de17ef5d0fcb5882ab9a` | Cheap main-thread refusal probe and write/action boundaries; contains `AMB-CX-001`. | `.agents/skills/pre-merge/refs/refusal-patterns.md` | PMG-CX-002/009 |
| `.claude/skills/pre-merge/refs/severity-rubric.md` | `50743c92f775d4820d86ceb1bf102eb44722f431c23859d12d789ef9b38a36e0` | All finding severity decisions. | `.agents/skills/pre-merge/refs/severity-rubric.md` | PMG-CX-004 |
| `.claude/skills/pre-merge/refs/stubs/.prettierrc.json` | `d5f90f76c5b68ce7be5ba077813f97e1983511b8c314764537345a538c1261f4` | Approved init/update install for detected formatter gap. | `.agents/skills/pre-merge/refs/stubs/.prettierrc.json` | PMG-CX-007 |
| `.claude/skills/pre-merge/refs/stubs/.size-limit.json` | `6d4ef945f2f20110eee33ff7cb0d10925501af2c7c03809690a65e91c6acc582` | Approved size-limit config gap. | `.agents/skills/pre-merge/refs/stubs/.size-limit.json` | PMG-CX-007 |
| `.claude/skills/pre-merge/refs/stubs/README.md` | `07a6a472771ecb6756785998f827f2dcb790d9660d59e003440c7cffb0a0a6a6` | Maintainer instructions for all stubs; never copied as product README. | `.agents/skills/pre-merge/refs/stubs/README.md` | PMG-CX-007 |
| `.claude/skills/pre-merge/refs/stubs/biome.json` | `9d62e65f947701a1807c00753eb2c05948d05cc06a3a4f4066a92dc4b6c4687e` | Approved Biome config gap. | `.agents/skills/pre-merge/refs/stubs/biome.json` | PMG-CX-007 |
| `.claude/skills/pre-merge/refs/stubs/docker-compose.test.yml` | `5ca9bccdd2ce200df8b48cfe92a06ee24f106a65306aa8dbac33ab669837166d` | Approved composite test-environment gap. | `.agents/skills/pre-merge/refs/stubs/docker-compose.test.yml` | PMG-CX-007 |
| `.claude/skills/pre-merge/refs/stubs/eslint.config.js` | `29dca511f4e092a3af9bca8b0bfd307461761cac40fa472d6dd0b0cae716d2d0` | Approved ESLint config gap. | `.agents/skills/pre-merge/refs/stubs/eslint.config.js` | PMG-CX-007 |
| `.claude/skills/pre-merge/refs/stubs/playwright.config.ts` | `6459862cee17f413dad2ad18a266be1e464f77af5cfc16af4ee4bb66acf7748a` | Approved Playwright config gap. | `.agents/skills/pre-merge/refs/stubs/playwright.config.ts` | PMG-CX-007 |
| `.claude/skills/pre-merge/refs/stubs/pre-merge.yml` | `1baef436230c3aab3c9ff23f450f9c16a3a07bbfd4e5da3bbf822287549c7c75` | Approved CI workflow gap. | `.agents/skills/pre-merge/refs/stubs/pre-merge.yml` | PMG-CX-007 |
| `.claude/skills/pre-merge/refs/stubs/ruff.toml` | `20975d9f5f75df31c01bd8c8323ac4822ef6069875394a16fa15b11b3306b5d6` | Approved Ruff config gap. | `.agents/skills/pre-merge/refs/stubs/ruff.toml` | PMG-CX-007 |
| `.claude/skills/pre-merge/refs/stubs/seed-test.ts` | `0df8ae1695d177252fd7e4688afb8e74307298e14c929111b4047bf0755e3899` | Approved seed-test gap. | `.agents/skills/pre-merge/refs/stubs/seed-test.ts` | PMG-CX-007 |
| `.claude/skills/pre-merge/refs/stubs/vitest.config.ts` | `a82961d0d70304603db045376b4fdf00289589182524abe8de29088e39dbaeee` | Approved Vitest config gap. | `.agents/skills/pre-merge/refs/stubs/vitest.config.ts` | PMG-CX-007 |
| `.claude/skills/pre-merge/refs/sync.md` | `100e5b52ee57222a8b2f9d944fabb899d13eb9f36d00fac9bb6155c27f88578d` | Mandatory DAG root; main performs merge, semantic conflict becomes human gate. | `.agents/skills/pre-merge/refs/sync.md` | PMG-CX-003/008 |
| `.claude/skills/pre-merge/refs/universal/protocol-coverage.md` | `6eaa683888da346fa18bea77259fc28ee62cc0eed8c34f7ec7fb5555885a31e7` | Enabled `coverage` component. | `.agents/skills/pre-merge/refs/universal/protocol-coverage.md` | PMG-CX-004 |
| `.claude/skills/pre-merge/refs/universal/protocol-integration.md` | `35791dfd1d031a5dc04146fcff2555858660a94118421a281ada8af4a6956f59` | Enabled `integration` component. | `.agents/skills/pre-merge/refs/universal/protocol-integration.md` | PMG-CX-004 |
| `.claude/skills/pre-merge/refs/universal/protocol-mechanical.md` | `67bdb6ada4211080cd2252cdf521e648b4e9f8513a43ab1fec11fa03a9ec38fd` | Critical `mechanical` component. | `.agents/skills/pre-merge/refs/universal/protocol-mechanical.md` | PMG-CX-004/005 |
| `.claude/skills/pre-merge/refs/universal/protocol-regression.md` | `c828e8e845b5be76374945af9c02791f7576ce88caf97366a78aa300aa9e2bf8` | Regression component; may invoke eng to add missing tests and commit. | `.agents/skills/pre-merge/refs/universal/protocol-regression.md` | PMG-CX-004/008 |
| `.claude/skills/pre-merge/refs/universal/protocol-security.md` | `c23afae88652a762e15e9bb1aac0314e862c5bcc06bad29cd67845c72109bdeb` | Critical `security` component and mandatory safety floor. | `.agents/skills/pre-merge/refs/universal/protocol-security.md` | PMG-CX-004/005 |
| `.claude/skills/pre-merge/refs/universal/protocol-unit.md` | `2018853d3c68d811de74257e140be7e69fa5499ce0deade8c3ecc5fa60d07d81` | Enabled `unit` component. | `.agents/skills/pre-merge/refs/universal/protocol-unit.md` | PMG-CX-004 |
| `.claude/skills/pre-merge/scripts/script-resolve-diff.sh` | `2d84fa06c37be4b5bb2adb4ab9bea58e049840e5203083b13a5cae27e2192f80` | Gate preflight; resolves base/head and changed paths before manifest execution. | `.agents/skills/pre-merge/scripts/script-resolve-diff.sh` | PMG-CX-002/010 |

## Behavioral, reference and state map

- Trigger/modes: default gate, `--init`, `--update`, `--update-criticality`; repeatable
  `--prd` plus prior-issues, full-secret-scan, flaky count, changed-only, minified,
  full and quiet/status flags. Selection precedence is `full > minified > policy`.
- Refusal probe: main resolves diff and manifest before spawning. It returns closed
  refusal codes for no manifest, no diff, schema mismatch and out-of-scope operations.
- DAG: executor joins the manifest to the shared component catalog, runs the resolver,
  places SYNC at the root and PR/open-issues at terminal nodes, prunes disabled nodes,
  topologically schedules waves, and reports every component including skipped ones.
- Concurrency: load/perf are isolated; smoke is the first environment wave. A blocker
  skips dependants only; independent nodes finish. Critical mechanical/security/
  migration failures abort according to the canonical contract.
- Test selection: full/minified/policy decisions and changed-path evidence are durable.
  Mandatory safety-floor checks cannot be removed by selection or platform profile.
- Terminals: clean creates exactly one feature-to-staging (main fallback) PR, without
  merging or pushing. Failure creates paired issue/report artifacts and offers the fix
  loop. Machine JSON is byte-identical to the verdict file and follows the issue summary.
- Cross-skill calls: `/cook` supplies standards; regression and fix-loop invoke `eng`.
  Codex `$skill` syntax and collaboration APIs remain pending
  `DEV-CX-001/003/005/006/008/009/010/013`.

## Writes, gates and forbidden effects

- A normal gate is read-only over product source except the canonical SYNC merge. It
  may write gate artifacts, reports/issues and PR metadata. It never merges the release.
- Regression writes are performed by the spawned eng workflow, not the checker.
- Init/update may write approved policy, ENV, CI/config/test stubs and install tooling;
  each real gap/per-item install has its named approval. Update-criticality has one table
  approval and one reviewed commit/stamp. SYNC semantic conflict is a main-thread gate.
- No adapter may weaken human approvals, branch/write boundaries, safety checks, schema
  closure, command exit semantics or the no-source-edit checker rule.

## Complete runtime closure

- Shared refs: component catalog, policy core/pre-merge/merge, ENV, gate dispatch,
  agent-watch, status heartbeat, safety floor, session cache, verify prelude, tooling
  detection, check/finding/report schemas, fix loop, closing message, ratchet, causal and
  user-impact rules, doctor logging.
- Helpers: scoped `script-resolve-diff.sh`; shared `script-agent-watch.sh`,
  `script-status-tick.sh`, `script-aggregate-verdict.sh`, `script-pipeline-resolve.py`,
  `script-check-common.sh`, `script-preflight-01-mechanical.sh`,
  `script-preflight-02-unit.sh`, `script-preflight-03-integration.sh`,
  `script-preflight-04-regression.sh`, `script-preflight-05-security.sh`,
  `script-preflight-06-coverage.sh`, `script-preflight-07-prd-consistency.sh`,
  `script-preflight-08-e2e.sh`, `script-preflight-09-a11y.sh`,
  `script-preflight-10-perf.sh`, `script-preflight-11-api.sh`,
  `script-preflight-12-load.sh`, `script-preflight-13-migration.sh`,
  `script-preflight-14-mobile.sh`, `script-preflight-17-smoke.sh`,
  `script-preflight-18-manual-test-plan.sh`,
  `script-policy-set.py`, `script-prd-digest.py`, `script-tier-resolve.sh`,
  `script-eng-comment-scan.sh`, `script-eng-commit-cap.sh`, `script-eng-review-check.sh`
  and `script-doctor-log.sh`. `script-doctor-detect.sh` is claimed by its header but has
  no canonical call edge (`AMB-CX-004`).
- Commands/environment: git/gh, detected package/test/build/lint/security/a11y/load and
  platform CLIs, Docker/emulators and project ENV commands. `HOME`, policy/status/watch
  variables and resolved environment placeholders retain their canonical meanings.
- Settings/hooks: `.claude/settings.json` permissions, changelog pre-tool hook and stage
  post-tool hook are contextual dependencies, not implicit product behavior. Codex
  permission/hook equivalence is pending DEV-CX-007. Project-instruction discovery is
  pending `DEV-CX-004`; paths are pending `DEV-CX-002`. Canonical `rtk` spelling requires an
  approved runtime translation because Codex applies RTK through its hook.
- Blast radius: implicit natural-language activation is `DEV-CX-009`; timed heartbeat/
  watch is `DEV-CX-010`; wave width/queueing is `DEV-CX-013`. These canonical packets
  do not specify the stable-head prompt-cache behavior in `DEV-CX-012`, and their human
  gates remain main-thread rather than taking the leaf-relay path in `DEV-CX-011`.

## Parity assertions and evals

| Assertion | Must remain true | Eval |
|---|---|---|
| PMG-CX-001 | Exact 39-file source/destination digest bijection. | premerge-file-digest-bijection |
| PMG-CX-002 | Trigger, flags, refusal probe and diff semantics match. | premerge-trigger-mode-matrix |
| PMG-CX-003 | Manifest join, prune/toposort, wave and terminal DAG match. | premerge-manifest-dag |
| PMG-CX-004 | Every component receives the same inputs and emits the same closed result/finding schemas. | premerge-component-contracts |
| PMG-CX-005 | Critical abort, dependency skip, isolation and mandatory floor match. | premerge-selection-safety-floor |
| PMG-CX-006 | Verdict, report/issues, JSON ordering/bytes, closing and PR terminal match. | premerge-verdict-output-pr |
| PMG-CX-007 | Init/update detection, stubs, platform profiles and per-gap approvals match. | premerge-init-update-gates |
| PMG-CX-008 | Human gates, sanctioned writes, commits and cross-skill ownership match. | premerge-refusal-and-write-boundary |
| PMG-CX-009 | Closed refusal codes and forbidden operations match. | premerge-refusal-and-write-boundary |
| PMG-CX-010 | Every helper/command/env/settings/hook edge is exercised or proven unreachable. | premerge-runtime-closure |
| PMG-CX-011 | Claude tree and behavior remain unchanged by Codex artifacts. | premerge-file-digest-bijection |
| PMG-CX-012 | Zero unapproved deviation; exact-output cases compare byte-for-byte. | all evals |

Eval fixtures must include clean, refusal, advisory failure, blocker, critical abort,
dependency skip, isolated perf/load, PR-open, init/update/update-criticality, semantic
conflict, missing tool/environment and helper failure. Each eval compares stdout/stderr,
exit code, writes, git/PR side effects, reports, findings and subagent trace.

## Blocking gaps / pending deviations

- `AMB-CX-001`: refusal-patterns says “create the PR” is out-of-scope and says the
  skill does not create PRs, while SKILL/executor require exactly one clean-run PR.
- `AMB-CX-004`: `script-doctor-detect.sh` claims pre-merge `--init` consumption,
  but neither the entry point nor init protocol invokes it; they spell probes directly.
- `AMB-CX-003`: shared tooling detection calls a missing secret scanner `warn`,
  while security and safety-floor contracts make it a blocker.

No gap is resolved here. Phase 1 must stop until the canonical owner approves a rule.

Applicable pending platform candidates: `DEV-CX-001/002/003/004/005/006/007/008/009/010/013`.
