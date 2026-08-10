---
skill: msg
canonical: .claude/skills/msg/SKILL.md
canonical_digest: 0cb6f1ad476685556a3455fde7af8a3d5866626885a32487e29ce42749f3f21c
status: phase-0-audited-blocked-on-deviations
assertions:
  - MSG-CX-001
  - MSG-CX-002
  - MSG-CX-003
  - MSG-CX-004
  - MSG-CX-005
  - MSG-CX-006
  - MSG-CX-007
  - MSG-CX-008
evals:
  - msg-file-integrity
  - msg-routing-default
  - msg-routing-help
  - msg-routing-negative
  - msg-init-cto
  - msg-init-eng
  - msg-init-top-up
  - msg-init-staging-direct-project
  - msg-update-idempotent
  - msg-update-policy-decisions
  - msg-doctor-read-only
  - msg-aha-ledger-only
  - msg-version-codex-stamp
  - msg-gui-localhost-smoke
  - msg-gui-runtime-translation
  - msg-helper-differential
---

# msg compatibility map

## Audit status

All **29 tracked canonical files** and the transitive runtime closure are inventoried.
No Codex deviation or mechanical translation is approved by this map. Implementation
is blocked on `DEV-CX-001`, `DEV-CX-002`, `DEV-CX-003`, `DEV-CX-004`,
`DEV-CX-007`, `DEV-CX-008`, `DEV-CX-009`, `DEV-CX-010`, and `DEV-CX-014`.

Aggregate digest: `0cb6f1ad476685556a3455fde7af8a3d5866626885a32487e29ce42749f3f21c`
(sorted SHA-256 stream of `git ls-files .claude/skills/msg`). Inventory proof:
**29 discovered, 29 rows, 29 unique paths, 0 duplicates, 0 omissions**. Untracked
runtime by-products such as `__pycache__` are not canonical files.

## Canonical file coverage

All generated-copy rows require a current per-file digest and byte-copy proof. Runtime
syntax/path/tool changes live in the adapter or an explicitly approved Codex-only
variant; they never mutate these Claude files.

| Canonical path | SHA-256 | Kind | Consumer/load condition | Codex disposition/path | Translation and proof |
|---|---|---|---|---|---|
| `.claude/skills/msg/SKILL.md` | `e08bf3af827a43d7d35a71b60966fe19663c2f0f50e1d10bffc0a428c66003c1` | entry/router | Every msg invocation; dispatches first matching flag/intent or default picker. | generated copy → `.agents/skills/msg/CLAUDE-SKILL.md`; adapter blocked | Eight flags + default and exact pure-emission exceptions; `MSG-CX-001/002/006`, routing/file evals. |
| `.claude/skills/msg/refs/protocol-init.md` | `1beb95d8e5f56497b69823f20e654baea7cefedfc6f0ea3d8577868680753b35` | protocol | `--init` and bootstrap intent; owns Steps 1/3/4/5 and delegates interview Step 2. | generated copy → corresponding Codex refs path | Codex path/guidance differences blocked; `MSG-CX-003/006/007`, init evals. |
| `.claude/skills/msg/refs/protocol-cto.md` | `da1eb7f947d1790fe878cecf7b46e2c4a986eaa978d0e2ed5ea31edb6a4849e5` | protocol | `--init --cto` or mode-gate recommendation choice; Step 2 only. | generated copy | Preserve five objectives, recommendation rules, <=4-call budget and full env handback; `MSG-CX-003/007`. |
| `.claude/skills/msg/refs/protocol-eng.md` | `310a6083178cd2783e378782eb1c0a2bc63bc9313c9be9e33d14e4d707b071b6` | protocol | `--init --eng` or direct mode-gate choice; Step 2 only; top-up asks subset. | generated copy | Preserve call budget, derived branches/UI predicate and every init variable; `MSG-CX-003/007`. |
| `.claude/skills/msg/refs/protocol-init-staging.md` | `f601736752d468888c52ee92c31d84d993553f1e6a351517da8bcd9edabdc11c` | protocol | `--init-staging`/staging setup intent. | generated copy | Same branch/protection/policy sequence and merge-init handoff; `MSG-CX-006/007`. |
| `.claude/skills/msg/refs/protocol-update.md` | `20f4fc10e28f5b12cc79463aa59b309a829322a20f6e5e8f983f23604577c75b` | protocol | `--update`/resync intent on initialized repo. | generated copy | Preserve scan, additive/full paths, policy decisions, optional untracking and lane classification; `MSG-CX-003/007`. |
| `.claude/skills/msg/refs/protocol-gui.md` | `8f82c669a8b7a1d92f0647360cfdbb8982115c7164006d74013886c6886c03aa` | protocol | `--gui`, gui/board/kanban/visualise intent; no picker/question. | generated copy; Codex GUI variant blocked | Localhost/security/data/write contract exact; natural-language discovery, long-job status and runner/syntax require pending `DEV-CX-009/010/014`; `MSG-CX-006/008`, GUI evals. |
| `.claude/skills/msg/refs/protocol-doctor.md` | `b483d6a92f469cf4a8458a8691bedf9739d193781a549604739234b34b161101` | protocol | `--doctor`/harness triage intent. | generated copy | Diagnose and graduate only, never fix; sole target DOCTOR; `MSG-CX-004/006`, doctor eval. |
| `.claude/skills/msg/refs/protocol-aha.md` | `b92aa30f3a826aa27a6caccb27d1346b4744ace3f11b0498c69fd69d9fbcdf6b` | protocol | `--aha`/learning-ledger sweep intent. | generated copy | One report+gate, sole target AHA; promotions recommendations only; `MSG-CX-004/006`, aha eval. |
| `.claude/skills/msg/refs/init/init-setup.sh` | `d202bbf5e2e72ae0f7552a785dcd0ea6169a99205890e62833a58518f4627e82` | script | Init/update Step 1; detects targets, stack/language, row gaps and flat PRDs. | byte-identical generated copy → Codex skill refs | Same nine key lines plus `ALL_COMPLETE`; stdout/exit differential; `MSG-CX-003/007`. |
| `.claude/skills/msg/refs/init/init.sh` | `13a2686b3a59e9b4bfa04f64e7f1786f98be94cf9ea8265e08457538c9a4235d` | script | Init/update after interview; template extraction, idempotent writes, lanes/migration/manifest. | byte-identical generated copy → Codex skill refs | Shared artifact bytes exact; Codex-only guidance/pref changes may not be hidden in this script; `MSG-CX-003/006/007`. |
| `.claude/skills/msg/refs/gui/server.py` | `e2d451aea89892e04980211ca6018cbe6264e00aa792f6a7fc700acbd19de642` | script/server | Interactive GUI default; serves data/API, bounded writes and background prompt jobs with polled status/output. | byte copy retained as Claude payload; Codex-specific generated variant blocked | Claude runner is pending `DEV-CX-014`; job-status equivalence is pending `DEV-CX-010`; localhost/API/write security byte-tested; `MSG-CX-008`. |
| `.claude/skills/msg/refs/gui/fill-static.py` | `30025effb5f9047aa91c6c8d16d0bd0daf5cc9cf8fba0a03217415f7c6d90c81` | script | Static GUI fallback only; validates/embeds data, CSS, empty token and optional view. | byte-identical generated copy | Runtime-neutral; identical HTML for same inputs; `MSG-CX-008`, GUI/file evals. |
| `.claude/skills/msg/refs/gui/index.html` | `48c47978646a2583320568f5d116f45370945160a6d0893535872cda910dfb36` | asset/application | Both GUI modes; all board/detail/intake/roadmap/reports/files/prompt client behavior. | canonical byte copy plus blocked Codex variant | Hardcoded Claude wording/slash quick actions require pending `DEV-CX-001/014`; all other rendering/API semantics preserved; `MSG-CX-008`. |
| `.claude/skills/msg/refs/gui/styles.css` | `c380b5228ab374305244051818adf8cd50c55827bc5088f46a7e149ab929390e` | asset | Both GUI modes, embedded once into index. | byte-identical generated copy | No runtime semantic translation; digest/static-output proof; `MSG-CX-008`. |
| `.claude/skills/msg/refs/init/templates/TEMPLATE-INTAKE.md` | `e3389ea5bb69505178a66a5355e24c49be7f52b3377954d982d4efd26ce4098c` | template | Init creates root ledger; intake may independently scaffold same body. | generated copy | Shared ledger bytes and ownership text exact; runtime syntax in displayed docs blocked on `DEV-CX-001`; `MSG-CX-003/006`. |
| `.claude/skills/msg/refs/init/templates/TEMPLATE-roadmap.md` | `1eb023407a9eed60e47e640ca36089a470cb766a79af8913023ff1c832e095f3` | template | Init creates format guide; GUI reads human-authored `roadmap.md`. | generated copy | Same phase grammar; no skill writes roadmap; `MSG-CX-003/006`. |
| `.claude/skills/msg/refs/init/templates/template-AHA.md` | `4e2c6e8768452fed142fa629010dce6c70e9156e3fbfb8770732bcdc25255d2b` | template | Init creates AHA; plan-pm may scaffold same canonical file. | generated copy | Same terse ledger/writer contract; `MSG-CX-003/004`. |
| `.claude/skills/msg/refs/init/templates/template-ARCHITECTURE.md` | `04360119925ff23bc74783c35a929a68c71ad10d090b94a575b1c6373982941e` | template | Init interpolates architecture interview. | generated copy | Shared artifact exact after variable normalization; `MSG-CX-003`. |
| `.claude/skills/msg/refs/init/templates/template-CHANGELOG.md` | `23990a1a4341654a5312ffa80aac283d8b38afd3ff266ab781ecf5eefc0a7c5a` | template | Init creates changelog; external kermit/hook consumes it. | generated copy | External Codex kermit compatibility blocked on `DEV-CX-008`; `MSG-CX-003/006`. |
| `.claude/skills/msg/refs/init/templates/template-CLAUDE.md` | `d865ecaf9c36a1bf93b9bd0ebfb4f75b5ae76d7c0a000275f0d4e475ad620a67` | template | Init creates root Claude instructions. | byte-identical generated copy; Codex `AGENTS.md` variant blocked | Canonical `CLAUDE.md` output must remain; automatic Codex guidance is pending `DEV-CX-004`; `MSG-CX-003`. |
| `.claude/skills/msg/refs/init/templates/template-DESIGN-SYSTEM.md` | `707dc24547936ae220f790b7b8c28aff271905456ea81c45c65a137a24fc1a39` | template | Init interpolates design-system answers or no-UI values. | generated copy | Shared artifact exact; `MSG-CX-003`. |
| `.claude/skills/msg/refs/init/templates/template-DOCTOR.md` | `7a184255a3af6aed42ba1389efd2c06fba21bc752911f7ce3b98346a512a21b8` | template | Init creates local incident ledger; doctor/shared logger consume. | generated copy | Same table/threshold contract; stays gitignored; `MSG-CX-003/004`. |
| `.claude/skills/msg/refs/init/templates/template-ENV.md` | `5de00555a9e82faa6fd9fce528ef5918e412917d25d99adbe48c0aaddb9d04f5` | template | Init creates committed environment contract; gates fill/read it. | generated copy | Exact fenced JSON and placeholder semantics; `MSG-CX-003/006`. |
| `.claude/skills/msg/refs/init/templates/template-GLOSSARY.md` | `c736d5620b4d9022852fd805ad1046f2ba4b566d02be512f433a31e200b1b375` | template | Init creates glossary. | generated copy | Same canonical-term shape; `MSG-CX-003`. |
| `.claude/skills/msg/refs/init/templates/template-OPEN-QUESTIONS.md` | `03001811cf9a530d839feed53b8fda5d84bb4a5b50eb46dcfe927c5a705fb505` | template | Init creates ambiguity log; plan-review/build agents append. | generated copy | Same severity/status sections; `MSG-CX-003/006`. |
| `.claude/skills/msg/refs/init/templates/template-PLATFORMS.md` | `59a918385f74fa27a1c1af716e325e47114845b8e98488d8bbd97abfb14f4375` | template/schema | Init selects platform rows; update adds `emulate_cmd` column; pre-merge/merge/emulate consume. | generated copy | All columns/defaults/placeholders exact; `MSG-CX-003/006/007`. |
| `.claude/skills/msg/refs/init/templates/template-README.md` | `8141a3b0887c8cd0e9a3d772f68633d8a6ba7ab6b9458d343b6750e93cbdf3f9` | template | Init interpolates project landing page. | generated copy | Shared artifact exact after runtime-command normalization; `MSG-CX-003`. |
| `.claude/skills/msg/refs/init/templates/template-gitignore.md` | `897ec9193f4331325105e141f009a8801d5a0bde206b56d71673eb22bcbc488f` | template | Init emits Universal plus one language/platform section; update tops up fixed rows. | generated copy | Same ignore state, including local msg artifacts; `MSG-CX-003/006`. |

## Reference graph and mode dispatch

```text
SKILL.md
  --init -> protocol-init -> protocol-cto | protocol-eng -> init-setup/init/templates
  --init-staging -> protocol-init-staging
  --update -> protocol-update -> protocol-init + cto/eng + init scripts/templates
  --gui -> protocol-gui -> server.py | fill-static.py -> index.html + styles.css
  --doctor -> protocol-doctor -> DOCTOR template contract
  --aha -> protocol-aha -> AHA template contract
  --version -> installed VERSION stamp
  --help -> three-question router
  no args -> category then skill router
```

Closing-message and doctor-logging apply to init, init-staging, update, doctor and aha.
Default, help, version and GUI are pure-emission/launch modes and retain their explicit
stop contracts.

## Trigger, flag and human-gate inventory

There are eight explicit mode flags (`--init`, `--init-staging`, `--update`, `--gui`,
`--doctor`, `--aha`, `--version`, `--help`) plus the no-argument default picker.
`--init` alone has `--cto` and `--eng`; unknown init subflags fall into the setup-mode
gate, never get ignored. First match wins. Codex exposes the same intents using `$msg`
pending `DEV-CX-001`.

Mandatory gates/asks remain: default category then paged skill; help's three questions
in one call; init setup-mode choice when not pinned; CTO/eng interview budgets; repo
confirmation when not a git repository; additive row top-up approval; two independent
GitHub choices when available; update-mode choice, policy revisits, optional untrack and
ambiguous lane classification; init-staging protection offer; doctor has no fix gate;
AHA has one apply/report-only gate. GUI never asks before launch.

## Tool and path mapping

Claude `Read/Edit/Write/Bash/AskUserQuestion` map to equivalent Codex operations only
after `DEV-CX-003/007`. Repository writes retain identical target bounds. Claude
`.claude/scripts`/`$HOME/.claude/scripts`, `.claude/msg/pref.json`, installed
`~/.claude/skills/msg/VERSION`, and `CLAUDE.md` have distinct Codex path/discovery
questions under `DEV-CX-002/004`. The Codex version mode must read only the Codex stamp
and never mutate or report the Claude install.

## Writes, refusals, outputs and handoffs

- Init is additive/idempotent: only missing root/devkit/template/lane/pref artifacts,
  approved row top-ups and explicit policy answers. Existing files remain byte-exact.
- Init-staging may create/push `staging`, bootstrap protection when approved and
  surgically flip release-flow policy. It never merges/deploys/opens a PR.
- Update refuses absent devkit, may add only missing artifacts/rows, classify flat PRDs,
  revise exactly two named policy areas, and untrack `features/` only after explicit
  confirmation; it never commits staged deletions.
- GUI writes only PRD markdown fields/body/todo done markers and root `INTAKE.md` status
  through its allowlisted authenticated localhost API. Static mode writes only a temp
  directory. It never writes reports, roadmap, intake content cells or source templates.
- Doctor writes only DOCTOR status/graduated blocks and never fixes. AHA writes only AHA
  after approval and never applies promoted fixes.
- Version/default/help emit only their specified line and stop.

Handoffs remain semantically identical: init -> plan-pm; init-staging -> merge init;
update may hand enabling to pre-merge init; GUI quick actions target plan-pm/eng/
plan-review; doctor/AHA recommend a separate repair session. Runtime syntax is blocked
on `DEV-CX-001/009/014`, and no handoff is silently invoked.

## Complete transitive runtime closure

### Shared contracts

| Dependency | Consumers/load condition |
|---|---|
| `.claude/skills/shared/refs/closing-message.md` | init, init-staging, update, doctor, aha terminals only. |
| `.claude/skills/shared/refs/doctor-logging.md` | unexpected incidents in those five modes; doctor itself reads but does not log ordinary findings. |
| `.claude/skills/shared/refs/policy-schema.md` | init seed/actions answer, update actions revision, init-staging flow flip. |
| `.claude/skills/shared/refs/policy-schema-pre-merge.md` | update test-selection read/disable/handoff. |
| `.claude/skills/shared/refs/env-contract.md` | ENV template emitted for both gates. |
| `.claude/skills/shared/refs/exec-mode-pref.md` | init creates team/solo preference scaffold. |
| `.claude/skills/shared/refs/report-schema.md` and `finding-schema.md` | GUI report/issue projection read model only. |

### Deterministic helpers

| Helper | Consumers/role |
|---|---|
| `script-branch-topology.sh` | CTO, eng, init, update, init-staging: prod/staging/remote/GitHub facts. |
| `script-branch-protection.sh` | Init/init-staging approved bootstrap; downstream verify contract. |
| `script-policy-set.py` | Only policy writer for init, update and init-staging; surgical merge/reparse/rollback. |
| `script-aha.sh` | AHA `--list`/recurrence parsing and canonical writers used elsewhere. |
| `script-doctor-tally.sh` | Doctor grouping, threshold and TRIAGE output. |
| `script-doctor-log.sh` | Shared unexpected-incident appender. |
| `script-project-findings.py` | GUI's single finding-to-ticket projection and legacy source normalization. |
| `changelog-gate.py` | External hook consuming the emitted CHANGELOG contract; msg never calls it. |

### Cross-skill and downstream contract edges

`intake` owns TEMPLATE-INTAKE row semantics; `eng` owns todo schema rendered by GUI;
`pre-merge` owns test-selection enablement and report producers; `merge` owns staging
readiness, deploy semantics and production completion; `emulate` owns `emulate_cmd`;
`kermit` owns changelog updates. These are dependencies, not permissions for msg to do
their work. Codex-compatible kermit availability remains pending `DEV-CX-008`.

### External commands and environment

Required/conditional commands include `bash`, `python3` 3.9+, `git`, `gh`, standard
POSIX utilities (`sed`, `awk`, `grep`, `mv`, `wc`, `mkdir`, `date`), a localhost HTTP
port, browser opener, and process lifecycle operations. GUI interactive additionally
spawns a prompt-runner CLI; canonical default is Claude and is the `DEV-CX-009` blocker.
Security invariants: bind only `127.0.0.1`, per-run token/Host checks, confined paths,
extension/size read limits, allowlisted writes, argv-safe prompt runner and temp-only
static output.

## Pending deviation candidates

- `DEV-CX-001`: slash menu, handoffs and GUI quick actions versus dollar invocation.
- `DEV-CX-002`: `.claude` installation/pref/version paths versus isolated Codex paths.
- `DEV-CX-003`: questions, file/shell operations, browser opening and skill calls.
- `DEV-CX-004`: canonical `CLAUDE.md` creation versus automatic Codex `AGENTS.md` use.
- `DEV-CX-007`: Claude allowed-tools/hooks versus Codex sandbox/approval controls.
- `DEV-CX-008`: external kermit menu/hook compatibility.
- `DEV-CX-009`: the central proposal disables implicit/natural-language invocation;
  canonical msg requires all natural-language triggers in its dispatch table, so this
  is a semantic deviation and cannot be adopted silently.
- `DEV-CX-010`: interactive GUI jobs expose running/done/error state and output tails
  through `/api/jobs`; a Codex long-running runner must preserve this visible liveness
  contract. This is mapped separately from chat-level heartbeat behavior.
- `DEV-CX-014`: interactive GUI uses `claude -p --permission-mode acceptEdits`, Claude
  wording and slash quick actions; Codex requires an approved runner/quick-action
  translation without weakening token, argv or write controls.

No difference is accepted.

## Parity assertions

| ID | Assertion |
|---|---|
| `MSG-CX-001` | Eight explicit modes, two init submodes and default picker remain reachable with first-match dispatch. |
| `MSG-CX-002` | Default/help choose the same semantic skill and pure-emission modes output nothing extra. |
| `MSG-CX-003` | Shared bootstrap/update artifacts are byte-identical after approved runtime normalization; only declared Codex guidance is additive. |
| `MSG-CX-004` | Doctor never fixes and AHA writes only its ledger after its single gate. |
| `MSG-CX-005` | Codex version/install behavior never reads as or mutates `$HOME/.claude`. |
| `MSG-CX-006` | All 29 canonical files and every direct/transitive reference edge load under the canonical conditions. |
| `MSG-CX-007` | Every mode preserves exact writes, refusals, gates, helper exits, state transitions, outputs and handoffs. |
| `MSG-CX-008` | GUI preserves data model, local-only security, read/write allowlists, static fallback and runtime-appropriate prompt semantics. |

## Concrete eval inventory

| Eval | Scenario/oracle | Assertions |
|---|---|---|
| `msg-file-integrity` | Discover exactly 29 tracked paths/rows/current digests; resolve all refs/dependencies; generate twice; assert Claude baseline unchanged. | `MSG-CX-006` |
| `msg-routing-default` | Exercise every category, Planning pagination and exact one-line semantic handoff. | `MSG-CX-001`, `002` |
| `msg-routing-help` | Exhaust routing matrix and exact pure emission. | `MSG-CX-001`, `002` |
| `msg-routing-negative` | Unknown top-level/init subflags; assert no silent fallback or unauthorized mode. | `MSG-CX-001`, `007` |
| `msg-init-cto` | Fresh repo, recommendation branches and ceiling; compare all shared artifacts/manifests. | `MSG-CX-003`, `007` |
| `msg-init-eng` | Fresh detected/ambiguous stacks, direct choices and no-UI path; compare artifacts. | `MSG-CX-003`, `007` |
| `msg-init-top-up` | Missing files/row gaps, approve/decline; assert existing bytes and idempotency. | `MSG-CX-003`, `007` |
| `msg-init-staging-direct-project` | Direct policy; create/push stubs, protection approve/skip, surgical flow flip, merge-init handoff. | `MSG-CX-007` |
| `msg-update-idempotent` | Missing/flat fixtures; classify, rerun, assert no second diff. | `MSG-CX-003`, `007` |
| `msg-update-policy-decisions` | Actions/test-selection keep/on/off and tracked-features approve/decline; assert only allowed state. | `MSG-CX-007` |
| `msg-doctor-read-only` | Below/at threshold and malformed ledger; assert only canonical ledger graduation, no repair. | `MSG-CX-004`, `007` |
| `msg-aha-ledger-only` | Keep/merge/prune/promote with apply/report-only; snapshot all non-AHA files. | `MSG-CX-004`, `007` |
| `msg-version-codex-stamp` | Stamped/unstamped Codex homes with sentinel Claude home; exact one-line output and no mutation. | `MSG-CX-002`, `005` |
| `msg-gui-localhost-smoke` | Stub git/gh/browser; assert bind/token/path/write controls, live/static data parity and cleanup. | `MSG-CX-008` |
| `msg-gui-runtime-translation` | Submit each quick action/prompt; trace must invoke Codex runner and dollar skill without Claude CLI/permission dependency, while `/api/jobs` retains equivalent liveness. Blocked pending `DEV-CX-010/014`. | `MSG-CX-001`, `008` |
| `msg-helper-differential` | Existing init/doctor/AHA/policy/topology/projector fixtures; compare helper stdout, exits and bytes across packages. | `MSG-CX-003`, `006`, `007` |

## Coverage result

Phase-0 mapping ratios are `file=29/29=1.0000`, `reference=all discovered edges/all
discovered edges=1.0000`, `behavior=all inventoried behaviors/asserted=1.0000`,
`eval-specification=all assertions linked to specified evals/all assertions=1.0000`,
and `dependency=all discovered closure items/all discovered closure items=1.0000`.
Runtime proof is **not-run**. These mapping ratios do not approve deviations or claim
the future adapters pass; implementation and release remain blocked.
