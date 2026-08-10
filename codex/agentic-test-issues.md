# Agentic end-to-end testing — issues, blockers and found defects

Status: audit log, 2026-08-10, planning/audit agent on `v6-msg-codex`.
Companion: `codex/agentic-test-plan.md`. Nothing in this file was fixed in the
repo by the audit agent — byte-frozen `.claude/` and the build agent's
`codex/`/`.agents/`/`evals/codex/` surfaces are log-only lanes for this audit.

## A. Blockers and gaps for driving the pipeline agentically

| ID | Severity | Gap | Evidence | Proposed resolution | Lane |
|---|---|---|---|---|---|
| ISS-01 | blocker | **Claude runtime has no headless gate-answer surface.** `claude -p` print mode cannot hold an `AskUserQuestion` open for an injected answer, so no Claude-side stage with a human gate can currently run agent-driven. The GUI runner has the same shape (`claude -p --permission-mode acceptEdits` in `msg/refs/gui/server.py`). | Every Claude skill gate is `AskUserQuestion` (all nine `SKILL.md`s); no equivalent of `MSG_CODEX_GATE_ANSWER` exists on the Claude side. | Build `evals/codex/lib/claude-session.mjs` on the Claude Agent SDK: `canUseTool` intercepts `AskUserQuestion` and returns the persona answer as the tool result. Verify the SDK contract before relying on it (spike first). | new eval-lib work |
| ISS-02 | blocker | **Zero layer-3 cases exist.** `evals/codex/run.sh` fully supports `--layer3` and `codex-session.sh` is ready, but `grep 'layer: 3' evals/codex/cases/*/about` matches nothing — `RUNTIME_PROOF` is permanently `not-run` and plan §12 requires runtime proof `1.0000` at release. | probe 2026-08-10; `evals/codex/run.sh` lines 81–84, 129–133 | The scenario matrix in `codex/agentic-test-plan.md` §4 is the fill; S1 + S4 first. | build agent / next phase |
| ISS-03 | blocker | **Layer 3 requires operator Codex credentials.** `codex_session_available` hard-requires `codex login status` success; an unattended CI runner or clean agent host cannot execute the suite, and every run bills real model usage. | `evals/codex/lib/codex-session.sh:24-29` | Accept as an operator-run suite for v6 (document it), or add a recorded-trace replay mode for CI (traces from a credentialed run replayed through the graders). | decision needed |
| ISS-04 | major | **Stale-answer and duplicate-delivery gate tests cannot be expressed.** DEV-CX-011's compensating controls promise tests for "stale answer and duplicate delivery", but `script-codex-gate.sh` is stateless — no nonce, epoch, or delivery record. Answering the same gate twice yields `GATE_STATE=answered` twice; a stale answer against a re-issued gate is indistinguishable from a fresh one. | `codex/gate-template.sh` (whole file: no state, no nonce field in the envelope) | Either add an optional `--epoch`/nonce echoed in the envelope and validated on answer (build-agent lane), or downgrade the DEV-CX-011 compensating-control claim with user approval. Until then the plan's persona `once:true` rows detect duplicates only at the driver layer, not at the contract layer. | build agent + user decision |
| ISS-05 | major | **Post-turn emulator lifetime (DEV-CX-016) is unprovable in one `codex exec` turn.** The approved translation demands proof the dev server survives skill completion; a single `--ephemeral` exec turn ends the session with the process tree. | `codex-session.sh` runs one `codex exec` per call; DEV-CX-016 record in `codex/deviations.md` | S10 needs an out-of-band observer: driver records the launched PID/port, then after the session exits, the *eval script* (not the model) probes the port/PID for liveness and performs cleanup assertions. | eval-lib design |
| ISS-06 | major | **gh-stub fidelity has no pinned contract.** `script-branch-protection.sh`, `script-ci-status.py`, `script-signoff-coverage.sh` and pre-merge/merge protocols consume specific `gh api` response shapes; a stub that drifts from real GitHub silently makes E2E green while production behavior differs. | helpers in `.agents/scripts/` (mirrored from `.claude/scripts/`); existing `a02-*`/`a23-*` cases pin some shapes already | Derive the stub's response fixtures from the shapes the existing deterministic cases (`a02-branch-protection-*`, `a03-signoff-*`, `a23-ci-status-*`) already encode — one shared `gh-stub` library, not per-case ad-hoc stubs. | eval-lib design |
| ISS-07 | major | **Sandboxed hosts cannot run the emulate leg.** Known and user-adjudicated: `emulate-dry-run` and `emulate-sweep-scope` need `lsof`/`ps` cwd attribution the sandbox blocks (plan §0). The agentic suite inherits this for S10 and for any full-chain run. | `plan-msg-codex-v6.md` §0 "Rerun … unsandboxed"; sandboxed run was 123/125 | Declare layer 3 an unsandboxed-host suite; runner should preflight `lsof`/`ps` and PEND (not FAIL) emulate scenarios when blocked. | runner behavior |
| ISS-08 | minor | **Kermit-present path is not hermetically testable.** kermit is an external skill, not part of the nine or the repo tree; a clean temp-HOME session only exercises the loud-degrade `gh pr create` fallback (AMB-CX-001). | `grep kermit .claude/skills` → only msg/pre-merge references; no kermit source in repo | Ship a minimal kermit *fixture* skill (records `--pr` args, delegates to gh stub) installed into the temp home for S11's present-variant; label it a contract fixture, not the real kermit. | eval fixture |
| ISS-09 | minor | **Model nondeterminism vs. exact-once gate assertions.** A live model may re-ask or rephrase; grading "gate asked exactly once" on raw traces will flake. | inherent to layer 3; `normalize-trace.py` drops prose but not event counts | Grade gate identity + order + answer honored; allow benign re-prompt collapse in the normalizer only for *unanswered* repeats of the same `GATE_ID`; never collapse across different gates. Retry policy: plan §7 (never retry forbidden-event failures). | eval-lib design |
| ISS-10 | minor | **Codex thread-cap control for team waves is unverified.** S2 asserts declared wave width (DEV-CX-013 preserves DAG + declared width), but whether `codex exec` exposes a controllable child-thread cap per session is unconfirmed. | DEV-CX-013 record; no cap flag in `codex-session.sh` | Spike: inspect `codex exec` config surface; if uncontrollable, grade DAG + max-width-not-exceeded only and disclose width as host-scheduled (already covered by the approved deviation). | spike |
| ISS-11 | minor | **Full-matrix cost.** ~30 live sessions per full run across two runtimes; per-PR use would be slow and expensive. | plan §7 estimate | Tiered execution (smoke vs. release) as in plan §7; checkpoints C1..C9 committed as goldens so isolated stages skip upstream sessions. | process |
| ISS-12 | minor | **Differential S1 requires both drivers to exist first.** Layer 4 on the full chain depends on ISS-01's Claude driver; until then only Codex-side layer 3 can run and parity claims must stay one-sided. | plan §6 | Sequence: Codex driver scenarios first, Claude driver spike in parallel, differential last. | sequencing |

## B. External hard dependencies — agentic coverage map

Every point where the pipeline touches a system that cannot be real in a test,
and what the plan does about it. "Not exercisable" rows are the honest residue
that no agentic run can prove; they stay in release notes as residuals.

| Dependency | Where it bites | Agentic coverage | Not exercisable agentically |
|---|---|---|---|
| GitHub branch protection | merge `--staging`/`--production` preconditions (`script-branch-protection.sh`) | gh-stub protection payloads: protected, unprotected, missing contexts (reusing `a02-*` shapes) | real org/repo protection semantics, required-reviewer enforcement by GitHub itself |
| GitHub PRs | pre-merge OPEN-PR (kermit `--pr` → `gh pr create`), merge locate/merge PR | gh-stub PR ledger coherent with local bare-remote SHAs | real merge-queue/auto-merge behavior, webhooks |
| CI (checks API) | merge green-CI gate, stale-CI refusal | gh-stub check-runs: green / red / stale-after-new-commit | real CI latency/flake behavior |
| Deploy targets | merge deploy + verify steps | deploy stub ledger + one-shot local HTTP server for smoke verify | real hosting, DNS, CDN rollout |
| App/Play Store submission | merge `--production` submission step | submission stub records + scripted statuses; wording assertion "success" never "live" (AMB-CX-006) | real review/processing states |
| macOS GUI / simulators | emulate launch (`open -a Simulator`, `xcrun simctl`, `emulator`, `adb`) | toolchain stubs + window-open event ledger; host-approval pause disclosed (DEV-CX-015) | real window focus, real device boot |
| Anthropic prefix cache | plan-em/eng team prompt heads (DEV-CX-012) | stable-head digest checks only | actual cache hit-rate/billing equivalence (disclosed non-functional deviation) |
| Codex/Claude model quality | every layer-3 session | semantic-event grading; Terra/Luna tier map recorded in reports (DEV-CX-006) | absolute output-quality equivalence |

## C. Found defects (log-only; not fixed here)

Frozen or out-of-lane surfaces. Each entry names the smallest repro.

| ID | Where | Defect | Repro / evidence | Lane |
|---|---|---|---|---|
| DEF-01 | `codex/invoke-template.sh` (and its generated copy `.agents/scripts/script-codex-invoke.sh`) | **Adjacent invocation tokens: second token not translated.** The sed boundary consumes the trailing character, so back-to-back tokens miss. | `printf 'run /eng /merge now' \| bash codex/invoke-template.sh translate` → `run $eng /merge now` (confirmed 2026-08-10). Menus/handoffs that list two commands on one line separated by a single space would ship a mixed-syntax line. | build agent (template is in the concurrent build's do-not-touch set for this audit) |
| DEF-02 | `codex/gate-template.sh` | Stateless envelope cannot support the stale-answer/duplicate-delivery tests DEV-CX-011 promises (see ISS-04 for the full record). | static read: no nonce/epoch/state anywhere in the contract | build agent + user decision |
| DEF-03 | `evals/codex/run.sh` | `--layer <n>` filtering interacts with the `--only` empty-match error path: filtering all cases out by layer yields `CODEX_EVALS 0/0 — no cases matched` exit 1 even when cases exist at other layers — a plumbing-correct but confusing signal once layer-3 cases land and someone runs `--layer 3` without `--layer3`. Minor UX: a layer-3 case selected by `--layer 3` still PENDs rather than running. | `run.sh` lines 76, 81–84, 119–122 | build agent, cosmetic |
| DEF-04 | `msg/refs/gui/server.py` (canonical, byte-frozen) | Prompt runner hardcodes `claude -p --permission-mode acceptEdits`; a gate raised inside a GUI-launched prompt cannot be held/answered (same root cause as ISS-01), on either runtime. Already disclosed as DEV-CX-014 for the Codex copy, but the *gate-holding* limitation is runtime-wide and unlisted. | `server.py` `/api/prompt` handler; DEV-CX-014 record | canonical — needs a separately-proposed cross-runtime product fix per plan §3.1; log only |
| DEF-05 | `evals/run.sh` known-adjudicated | `emulate-dry-run` + `emulate-sweep-scope` fail sandboxed (needs `lsof`/`ps`); inherited constraint for the agentic suite (ISS-07). Not a new defect — recorded so the E2E runner's preflight requirement is traceable. | plan §0 | none — documented behavior |

## D. What this audit changed

- Created: `codex/agentic-test-plan.md`, `codex/agentic-test-issues.md` (this
  file). Nothing else. No `.claude/`, `.agents/`, `codex/` templates,
  `evals/` files, goldens, or git state were modified.
- Probes run (scratchpad/read-only): invoke-translator adjacency repro
  (DEF-01), layer-3 case census (ISS-02), gate-template static review
  (ISS-04/DEF-02), GUI smoke-case and session-lib reads.
