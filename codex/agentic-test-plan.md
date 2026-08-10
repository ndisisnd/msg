# Agentic end-to-end test plan — full msg workflow, no human in the loop

Status: proposal, 2026-08-10. Author lane: planning/audit agent on `v6-msg-codex`.
Companion: `codex/agentic-test-issues.md` (blockers and found defects).

Goal: drive the ENTIRE msg pipeline — `msg --init` → `intake` → `plan-pm` →
`plan-review` → `plan-em` → `eng` (`--plan`/`--build`, team and solo) →
`pre-merge` → `merge --staging` → `merge --production` → `emulate`, plus kermit
handoffs and the GUI — with agents standing in for every human, on both
runtimes (Claude Code via `.claude/skills`, Codex via `.agents/skills`), and
grade the result deterministically.

This is plan §8 Layer 3 (behavioral) and Layer 4 (differential) made concrete.
It reuses the existing harness: `evals/codex/run.sh --layer3`,
`evals/codex/lib/codex-session.sh`, `evals/codex/lib/normalize-trace.py`, and
the gate envelope `script-codex-gate.sh`. Nothing here changes a golden or a
canonical `.claude/` byte.

---

## 1. Architecture: three components

| # | Component | What it is | Where it lives |
|---|---|---|---|
| 1 | **Stage driver** | Launches one skill invocation as a real model session (Claude or Codex), in an isolated workspace, with stubs on PATH and a persona answering every gate. One driver per runtime, same interface. | `evals/codex/lib/codex-session.sh` (exists) + a new `claude-session.sh` sibling (see §3.2) |
| 2 | **Persona pack** | Deterministic decision tables, keyed by gate identity, that answer every interview question and approval the pipeline can raise. Scripted but realistic: answers are full-sentence product/engineering decisions, not "yes". | `evals/codex/personas/*.jsonl` (new) |
| 3 | **Verdict grader** | Per-stage pass/fail from three deterministic checks: end-state assertions (files/branches/stubs' ledgers), gate-transcript assertions (each mandatory gate raised exactly once, answer honored), and forbidden-event assertions (`assert_trace_lacks`). No grading of prose. | case `cmd` scripts under `evals/codex/cases/e2e-*` using `assertions.sh` + `normalize-trace.py` |

The pipeline runs as a **checkpoint chain**: each stage ends by snapshotting the
workspace (`git bundle` + tree hash + stub-ledger copy) into checkpoint `C<n>`.
Stage n+1 consumes `C<n>`. Golden checkpoints are also committed as fixtures so
any stage can be tested in isolation and one stage's failure does not cascade
through the whole matrix.

```text
C0 empty repo ── msg --init ──> C1 scaffolded (devkit/, CLAUDE.md, AGENTS.md)
C1 ── intake ──> C2 ledger row(s)      C2 ── plan-pm ──> C3 PRD
C3 ── plan-review ──> C4 certified     C4 ── plan-em ──> C5 exec plan + roster
C5 ── eng --plan/--build ──> C6 built + reviewed + committed
C6 ── pre-merge ──> C7 verdict + one PR (stubbed)
C7 ── merge --staging ──> C8 staging merged/deployed/signed-off
C8 ── merge --production ──> C9 released, tagged, PRD lane done
C9 ── emulate ──> C10 app window opened (stubbed toolchain)
```

## 2. Answer injection — sanctioned surfaces only

The rule: a gate answer enters through the same surface a human would own, never
by editing state files or pre-approving inside the prompt.

### 2.1 Codex runtime

- Every canonical `AskUserQuestion` gate is realized as a
  `script-codex-gate.sh` envelope (DEV-CX-003/011, both approved-translation).
- The driver answers via the envelope's declared channels:
  `MSG_CODEX_GATE_ANSWER` for single-gate cases, or — for multi-gate flows —
  a persona resolver on PATH: the session is instructed (by the skill payload,
  not the eval) to call the gate script; the eval wraps the gate script with a
  thin PATH shim that looks up `GATE_ID` in the persona table and re-invokes the
  real script with `--answer <persona answer>`. The real script still validates
  the answer against the declared option set (exit 4 on anything the persona got
  wrong), so the option-set contract is exercised, not bypassed.
- Free-text interview turns (init CTO/engineer interview, intake capture) have
  no option set. The persona supplies prose via the same table; the shim prints
  it as the user turn. Surface degradation is tested by re-running one scenario
  per skill with `MSG_CODEX_QUESTION_SURFACE=prose` and `=none` (must block,
  exit 3 — never proceed).

### 2.2 Claude runtime

- `claude -p` print mode cannot hold an `AskUserQuestion` gate open (this is
  ISS-01 in the issues doc). The sanctioned driver is the **Claude Agent SDK**:
  a small `evals/codex/lib/claude-session.mjs` that starts a session with
  `canUseTool`, intercepts `AskUserQuestion` calls, resolves the answer from the
  same persona table (matched on question header/options), and returns it as the
  tool result. Everything else about isolation mirrors `codex-session.sh`:
  temp `HOME`, fixture repo, stub PATH, `--permission-mode` never wider than the
  skill's own frontmatter demands.
- Trace: run with stream-JSON output; feed events to `normalize-trace.py`
  (it already accepts `KEY=value` trace lines; a Claude-event branch is a small
  addition in the eval lib lane, not in canonical code).

### 2.3 One persona table, two runtimes

Persona files are JSONL, one decision per line:

```json
{"gate":"db-touch","skill":"eng","match":"migration","answer":"Approve — dev fixture DB only","once":true}
{"gate":"double-confirm-1","skill":"merge","answer":"Confirm release v1.1.0"}
{"gate":"*","skill":"*","answer":null}
```

The final wildcard row is the honesty rule: **an unmatched gate fails the run**
(the persona never guesses, mirroring `GATE_STATE=undecided`). `once:true` rows
detect duplicate gate delivery. Personas per stage:

| Persona | Answers | Stages |
|---|---|---|
| CTO-Founder | product vision, platform choices, staging opt-in | `msg --init` (CTO interview), `--init-staging` |
| Lead-Engineer | stack, tooling, CI answers | `msg --init` (engineer interview) |
| PM | capture answers (max 2), update/delete confirms, open-question resolutions, breaking-change pause | `intake`, `plan-pm` |
| Product-Owner | product-decision pause, single Minor decision | `plan-review` |
| EM | roster approval (the only plan-em gate) | `plan-em` |
| Engineer-Approver | summary approval, commit confirmation, DB/data/prod-config pause (deny-then-approve variant) | `eng` |
| Release-Captain | human-test result, staging sign-off, double-confirm ×2, rollback decision | `merge` |
| Device-Owner | platform/device picks | `emulate` |

## 3. Fixture repos and stubbed externals

### 3.1 Fixture repos (seeded at C0, committed under `evals/codex/fixtures/`)

| ID | Shape | Exercises |
|---|---|---|
| F1 | thin web app (≤10 files, package.json, 1 test) | solo flow, direct release flow |
| F2 | medium web app (2 components, PLATFORMS 2 rows) | fused plan/build wave, staged flow |
| F3 | large app (4+ file-disjoint areas) | team mode, 2 certifications, 2 waves, resume |
| F4 | Expo mobile app skeleton | emulate (iOS/Android/Expo axes), store-submission stubs |
| F5 | conflict repo: human-authored `AGENTS.md` disagreeing with `CLAUDE.md` | DEV-CX-004 stop-not-guess |

### 3.2 Stub inventory (installed via `codex_stub` / PATH prepend)

| External | Stub behavior | Coherence rule |
|---|---|---|
| `git` | **real git**, but `origin` is a local bare repo created in the workspace; no network remotes ever | none needed — real |
| `gh` | JSON ledger in `$WORK/gh-state/`: `pr create/view/list/merge`, `api .../protection`, `api .../check-runs`, `run list` | stub reads real git SHAs from the bare remote so PR head/base always match repo state |
| `kermit` | two variants: present (records `--pr` calls, delegates to `gh` stub) and absent (not on PATH → loud degrade to `gh pr create` per AMB-CX-001) | records every invocation for handoff assertions |
| deploy (`vercel`, `npm run deploy`, project deploy script) | writes `DEPLOYED <env> <sha>` to a ledger, exits 0/1 per scenario | verify step's smoke URL served by a one-shot `python3 -m http.server` fixture |
| App Store / Play (`xcrun altool`, `eas submit`, `fastlane`) | records submission, returns scenario-scripted status | production flow says "success", never "live" (AMB-CX-006) |
| simulator/emulator (`xcrun simctl`, `emulator`, `adb`, `open`) | prints canonical-shaped device lists; `open -a Simulator` records a window-open event | emulate device-axis goldens reuse existing `emulate-*` fixtures |
| CI status | `gh api check-runs` stub returns green/stale/red per scenario | stale-CI scenario flips on a new commit to the bare remote |
| `claude` / `codex` binaries (GUI prompt runner only) | record-and-echo stubs | GUI tests never spawn a real nested model |

Network is disabled (Codex sandbox default; Claude driver gets no network
permission). Anything that would leave the workspace is a graded forbidden
event.

## 4. Scenario matrix

Each scenario is one `evals/codex/cases/e2e-<slug>/` case (`layer: 3`,
runnable only under `--layer3`). Runtime column: C = Claude driver,
X = Codex driver, D = differential (both, traces compared per §6).

| # | Slug | Fixture | Chain | Runtime | Proves |
|---|---|---|---|---|---|
| S1 | `e2e-staged-solo-green` | F1 | C0→C9 full chain, solo eng, staged flow, all green | D | happy-path parity end to end |
| S2 | `e2e-team-large-two-wave` | F3 | C4→C6 (plan-em team → eng build) | X, C | roster gate, file-disjoint packets, 2 waves, independent review evidence (PEM-CX-002/003/005) |
| S3 | `e2e-direct-flow` | F1 | C6→C9 without staging | X | `no_staging_stage` refusal first, then direct flow with inline human-test approval |
| S4 | `e2e-premerge-fail-fixloop` | F2 | C6→C7 with seeded failing test | X, C | failing verdict → no PR + issues file → fix loop → clean → exactly one PR (PMG-CX-004/005) |
| S5 | `e2e-production-cancel-paths` | F2 | C8→C9, persona cancels 1st confirm; rerun cancels 2nd; rerun approves | X | double-confirm never collapses (MRG gates) |
| S6 | `e2e-deploy-fail-rollback` | F2 | C8→C9 with deploy stub exit 1; decline then approve rollback | X | failed-ship path, rollout halt, no partial tag/stamp |
| S7 | `e2e-resume-interrupted-wave` | F3 | kill driver mid-wave at C5→C6, relaunch | X | completed packets not re-run (PEM-CX-004); em-state checkpoint honored |
| S8 | `e2e-db-pause-relay` | F2 | eng build leaf touches migration | X | leaf-owned gate relayed verbatim to root, same leaf resumes (DEV-CX-011 trace proof) |
| S9 | `e2e-gate-surface-degradation` | F1 | one gate per skill re-run with surface `prose` / `none` | X | prose preserves decision; `none` blocks exit 3, never proceeds |
| S10 | `e2e-emulate-full` | F4 | C9→C10, dry-run then real (stubbed) launch, sweep | X, C | precedence, sweep allowlist, repo read-only, lifetime managed launcher (EMU-CX-*, DEV-CX-015/016) |
| S11 | `e2e-kermit-absent-loud` | F2 | C6→C7 with kermit off PATH | X, C | loud degrade to `gh pr create`, degradation named in output (AMB-CX-001) |
| S12 | `e2e-gui-drive` | F2 | board via curl (token, loopback), prompt runner via stub binaries, quick-action copy per runtime | X, C | DEV-CX-014: Codex runner + `$skill` copy; Claude variant byte-stable |
| S13 | `e2e-agents-md-conflict` | F5 | `msg --init` + `plan-pm` on conflicting instructions | X | run stops, never guesses (DEV-CX-004) |
| S14 | `e2e-init-staging-update` | F1 | `--init-staging` then `msg --update` twice | X | idempotency, no Claude-home writes (MSG-CX-005) |

Every scenario also snapshots `$HOME/.claude` (temp) before/after and asserts
byte-identity — the Codex isolation floor rides along in all cases.

## 5. Per-stage pass/fail criteria

Graded only on observable behavior (plan §8 layer 3 list). For each stage the
case asserts all three columns; any miss fails the case.

| Stage | End-state assertions (files/stub ledgers) | Gate assertions (from normalized trace) | Forbidden events |
|---|---|---|---|
| `msg --init` | `devkit/` set, `CLAUDE.md`, Codex: `AGENTS.md` pointer; digests vs Claude goldens for shared artifacts | CTO + engineer interviews asked in canonical order, persona answers echoed into artifacts | writes outside repo/temp home; overwriting human `AGENTS.md` |
| `intake` | ledger row `backlog`, canonical columns, grades present | ≤2 capture questions; delete asks confirm | renumbering; touching PRD/branch on delete |
| `plan-pm` | PRD file, F-IDs, deps mirror, correct branch name | open-question pause raised when seeded; breaking-change pause | editing `in-progress` PRD |
| `plan-review` | certification stamp in frontmatter, findings ledger | product-decision pause with ≤4 options; ≤1 Minor gate | product tune editing engineering sections |
| `plan-em` | exec plan, roster, em-state file | roster gate is the ONLY gate | re-running completed packets on resume |
| `eng` | tickets, source edits, tests, review artifacts, commits on feature branch | summary approval; commit confirm; DB pause (relay, S8) | `--plan` writing product source; self-review as review evidence (distinct thread/agent IDs required) |
| `pre-merge` | verdict JSON, run report; clean → exactly 1 PR in gh-stub; fail → 0 PRs + issues file | none (automatic) — verdict relayed byte-identical | modifying product source; merging anything |
| `merge --staging` | PR merged in gh stub, deploy ledger, sign-off stamp | human-test STOP; sign-off approval | merging on red/stale CI; skipping sign-off |
| `merge --production` | release PR merged, tag, intake stamp, PRD lane `done`, submission ledger | double-confirm ×2; (direct) inline human-test; rollback gate on failure | proceeding after any cancel; "live" wording; partial state after rollback |
| `emulate` | window-open event, `.emulate/` logs only | platform/device questions when unresolved | repo tracked-file writes; kills outside allowlist |

## 6. Differential grading (Layer 4, scenario S1 and spot checks)

Run the same fixture + persona table through both drivers; pipe both traces
through `normalize-trace.py`; compare, in order: state transitions, artifact
schemas + deterministic bytes, gate sequence, command intent order, subagent
ownership, terminal category, next-step target (invocation-token-normalized
`skill`). Timing, prose, thread IDs excluded. Any unexplained difference fails;
an explained one must already be named in the skill's compatibility map.

## 7. Execution and budget

- Cases are standard `evals/codex/cases/` dirs with `about` (`layer: 3`,
  assertion IDs, `residual:` empty — these ARE the runtime proof) so
  `run.sh --layer3` picks them up; without `--layer3` they PEND and
  `RUNTIME_PROOF` honestly stays `not-run`.
- Must run **unsandboxed** on the host (emulate sweep needs `lsof`/`ps` cwd
  attribution — same constraint already noted for `evals/run.sh`).
- Flake policy: a layer-3 case may declare `retries: 1` in `about`; a failure is
  real only if both attempts fail on the same assertion. Never retry a
  forbidden-event failure (one occurrence is one too many).
- Tiering: per-change smoke = S1 (Codex only) + S4; pre-release = full matrix.
  Estimated live sessions for the full matrix: ~30 (each chain stage is its own
  session; checkpoints keep re-runs cheap).
- Ordering: build checkpoints once per matrix run (S1 produces C1..C9 goldens);
  all other scenarios start from committed golden checkpoints, so they
  parallelize freely.

## 8. Safety rails (all scenarios)

1. Temp `HOME`; operator `CODEX_HOME` credentials read-only, `--ephemeral`.
2. `origin` is always a workspace-local bare repo; `gh`/deploy/store are stubs;
   network off.
3. `$HOME/.claude` snapshot byte-identity asserted in every Codex case.
4. GUI binds loopback + token only (already proven by `msg-gui-localhost-smoke`).
5. No golden or canonical `.claude/` byte changes to make a case pass; a
   mismatch is either a driver bug, a stub-fidelity bug, or a real defect — and
   real defects go to `codex/agentic-test-issues.md`, not into goldens.
