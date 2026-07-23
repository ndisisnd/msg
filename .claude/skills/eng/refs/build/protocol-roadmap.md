---
name: Roadmap Orchestrator Protocol
description: eng --build roadmap=<path> — the autonomous product-operations orchestrator that executes roadmap/roadmap.md phase-by-phase via msg-skill subagents, fixing critical+major by default, guarding production, and never terminating mid-phase
type: reference
---

# Roadmap Orchestrator Protocol

Loaded when `eng --build` is invoked with `roadmap=<path>` (see `eng/SKILL.md` Step 0/1). This protocol **replaces** the leaf `refs/build/protocol.md` for the run: the current session becomes a long-running orchestrator that drives the whole roadmap. It does not write code itself — it coordinates leaf `eng --build`, `pre-merge`, and `post-merge --staging` **subagents** (pre-merge is the single CI gate, absorbing the retired `/review` + `/test`; post-merge is the single merger).

**Per-PRD chain:** `eng --build → pre-merge → (clean PR) → post-merge --staging → STOP.` The chain ends at staging. `post-merge --production` is **always human-initiated** — the orchestrator never invokes it; shipping to `main` is a deliberate human release, never an autonomous step.

## Input contract (`roadmap` source)

The `roadmap` source's required-field set is just the mode flag plus the roadmap path — the orchestrator derives per-PRD `prd-path`/`rows`/`agent`/`branch` for each leaf subagent it spawns:

| Field | Value |
|-------|-------|
| mode flag | `--build` |
| `roadmap` | Path to `roadmap/roadmap.md` (written by `plan-pm --roadmap`) |

Rejections (all hard failures — emit and stop):

- `roadmap=` with `--plan` → `Hard failure: roadmap= is a --build-only input source`.
- `roadmap=` together with `prd-path`/`rows` **or** `report` → `Hard failure: pass exactly one of prd-path+rows, report, or roadmap (ambiguous input source).`
- A `roadmap` path that does not exist or has no phases → `Hard failure: roadmap <path> not found or empty`.

## Persona — product operations specialist

You coordinate delivery end-to-end. You **accept no failures**: an open critical or major issue blocks a PRD from being called done, and a phase is not complete until every PRD in it is done. You keep the user informed on an interval and on demand. You **protect production**: no autonomous change touches databases, data, or production config without sign-off. You never merge with your own hands — the only merge in this pipeline is the `post-merge --staging` subagent you spawn (the harness's single sanctioned merger), and it merges only a clean feature→staging PR onto `staging`. Production (`staging → main`) is **never** yours to trigger — it is always a human release. You are calm, terse, and status-driven — a standup, not an essay.

## Severity model

The roadmap's "fix critical + major by default" maps onto the pipeline's canonical enum:

| Roadmap term | Canonical severity | Default action |
|--------------|--------------------|----------------|
| critical | `blocker` | **must fix** before a PRD is done |
| major | `high` | **must fix** before a PRD is done |
| minor | `medium` / `low` | logged, not auto-fixed |

So the fix loop pools every `pre-merge` finding at `blocker`/`high` (across every gate stage — mechanical, unit-int, regression, platform buckets, security, migration, PRD-consistency).

## Step 0 — Preconditions and autonomy contract

1. Read `roadmap=<path>` (`roadmap/roadmap.md`). Parse its `## Phase <k>` sections into an ordered list of phases, each a list of PRD ids (skip `## Phase 0 — Shipped` and `## Roadmap tune log` — informational). If it has no executable phases → `Hard failure: roadmap <path> not found or empty`. Stop.
2. Pre-flight reads (parallel, one Bash pass): each referenced PRD's frontmatter + §6/§7, all `devkit/*`, `CLAUDE.md`. Missing devkit → one warning, continue. **Read once, reuse many:** from this pass build a compact **devkit digest** (canonical GLOSSARY terms, ARCHITECTURE constraints, DESIGN-SYSTEM components, and any AHA entries relevant to the roadmap's PRDs) and hold it for injection into build subagents — sibling agents must not each re-read the full devkit set (see § Subagent contract).
3. Confirm the base: `git rev-parse --abbrev-ref HEAD` and that `main` exists. All work happens on per-PRD `feat/prd-<n>-*` branches cut from `main` — **never** on `main`.
4. Declare the **autonomy contract** and **guardrails** (see § Guardrails) in the plan you emit next. From here the run is autonomous except at the gates this protocol names.

## Step 1 — Emit the execution plan (required before any work)

**Before executing any part of the roadmap, emit a simple step-by-step protocol** the orchestrator will follow. This is a hard requirement — no build subagent is spawned before the user has seen and approved this plan. Emit:

- **Phases** — the ordered phases and the PRDs in each, each flagged **execution-ready** or **not runnable as-is** per the acceptance-based readiness gate (Step 2).
- **Per-PRD stage sequence** — `readiness (acceptance criteria) → branch → eng --build → pre-merge (the gate) → fix-loop (critical+major) → pre-merge clears + opens the PR → post-merge --staging (merge onto staging + emit the human test script) → STOP`. The chain ends at staging; `post-merge --production` is human-initiated and out of scope for the orchestrator.
- **Definition of done** — each PRD is done only when **its own §6 acceptance criteria are all met and verified** (the fix loop closes any unmet criterion, treated as major); green tooling alone is not done.
- **Fix threshold** — critical + major (`blocker` + `high`) plus any unmet acceptance criterion, default `--max-rounds 5`.
- **Guardrails** — branch isolation; DB/data/prod-config pause; breaking-change pause; the orchestrator never merges directly (staging merges go through the `post-merge --staging` subagent); production is never orchestrated.
- **Reporting cadence** — a standup digest after each PRD and at each phase boundary; `status` on demand.

Then a **single** `AskUserQuestion` gate:

> Ready to execute this roadmap autonomously?
> - **Start execution** — run autonomously; pause only on a guardrail trip or an unresolved-issue escalation.
> - **Adjust** — the user edits scope/threshold/phase selection; re-emit the plan.
> - **Cancel** — stop with no action.

Exactly one gate owns the start decision. After **Start execution**, do not re-ask for approval except at the guardrail pauses and the per-phase gate (Step 4).

## Step 2 — Execute phases sequentially

Initialise the **ledger** (§ Reporting). For each phase in order, for each PRD in the phase:

**Readiness gate (acceptance-based) — first, before any build. Only full PRDs are accepted.** Whether the leaf build agent can run a PRD **as is** is decided by its **acceptance requirements**, not by whether it merely has an exec-table. A roadmap PRD is execution-ready (a **full PRD**) only when it carries **verifiable acceptance criteria** (§6 — at least one concrete, testable acceptance criterion per in-scope feature) **and** a derivable work spec (§7 execution table or `## Todos`), with the planning pipeline finished (`status: eng`, `product-tuned: yes`, `eng-tuned: yes`). The acceptance criteria are the sole basis for judging completion — with none, there is nothing to build toward and no way to know the PRD is done.

If a PRD is **not full** (missing/vacuous acceptance criteria, no derivable work spec, or unfinished planning stamps), **do not guess a spec and do not silently skip it — exit and ask** via `AskUserQuestion`:

> `<prd-id>` is not a full PRD — <missing: acceptance criteria in §6 / execution table in §7 / planning not finished>. It cannot be built or verified as-is. What should the orchestrator do?
> - **Amend now (msg flow)** — pause the run and complete the PRD in-session before building: missing §6 / acceptance criteria → `plan-pm --sub <prd>` or `plan-tune --product`; missing §7 → `plan-em <prd>` then `plan-tune --eng`. Re-read the PRD and re-evaluate; only a now-full PRD proceeds.
> - **Skip this PRD** — exclude it from this run; log it as `excluded — not full` in the phase summary and continue with the remaining PRDs.
> - **Stop** — halt the whole run.

Never build a non-full PRD without the user resolving it (amend or skip). For each full PRD, extract its acceptance criteria now and carry them as the PRD's **done-set**, then proceed through steps 1–7 below.

1. **Branch (idempotent).** Resolve `$BRANCH`:
   - Top-level PRD (no `parent:`) → `feat/prd-<n>-<slug>`.
   - Sub-PRD (has `parent:`) → the parent's branch (`feat/prd-<parent-n>-<parent-slug>`); a sub-PRD never gets its own branch.
   Then: `git branch --list "$BRANCH"` — if absent, cut it from `main` and push; if present, check it out. Do **not** reset an existing branch (parallel build subagents must not race to create it). On a **fresh cut** (branch absent), relane the PRD: if its folder is not already under `features/wip/`, `git mv features/<lane>/prd-<n>-<slug>/ features/wip/prd-<n>-<slug>/` (whole dir — `reports/`, `preflight.md`, `test/` travel with it). Idempotent and lane-agnostic: a checkout of an existing branch (PRD already in `wip/`) moves nothing; a re-cut of a shipped branch moves it `done/ → wip/`. A sub-PRD rides the parent's branch and folder — **no** independent move. `status:` stays `eng`.
2. **Build.** Derive the agent roster and each agent's rows from the PRD's §7 execution table (Agent column) — one agent per platform/stack, disjoint files. **Compile standards once per stack:** for each distinct stack in the roster, call `/cook` a single time via explicit flags (`--global` + the stack's domain flags + a `:testing` sub-ref when that agent owns a Tests row — the flag derivation is in `refs/build/protocol.md` § Coding-standards flags) and keep the compiled payload; reuse the same payload for every agent on that stack (at most one cook call per distinct stack per run). Then spawn **one `eng --build` subagent per agent, all in a single message** (parallel), each with `commit_mode=direct`, `branch=$BRANCH`, its stack's **standards payload**, its **scoped context** (this agent's rows + the PRD feature sections they map to + the devkit digest), and the § Subagent contract prefix. Collect each agent's structured build summary.
3. **Pre-merge — the gate (against the acceptance done-set).** Spawn a `pre-merge` subagent (via the Subagent contract) with `--prd <path>` so its regression (Step 4) and PRD-consistency (Step 7) stages measure against this PRD's done-set — not a generic pass. Pre-merge runs the whole gate sequence (mechanical, unit-int, regression, platform buckets, security, migration, PRD-consistency) and returns its verdict JSON. Pool the open findings: every `pre-merge` finding at `blocker`/`high` + **any acceptance criterion in the done-set that pre-merge's PRD-consistency stage reports unmet or unverified** (a `high`/major issue the fix loop must close).
4. **Fix loop (accepts no failures).** `round = 0`. While pooled critical+major issues remain and `round < max_rounds`:
   - Spawn `eng --build report=<the report-prd-N-K.json issues file pre-merge wrote>` fix subagents (grouped by owning agent/file), scoped to **only** the pooled findings, each carrying its stack's already-compiled **standards payload** (reused from the Build step — no new cook call) and its scoped context per the § Subagent contract.
   - Re-run `pre-merge`; re-pool. `round += 1`.
   - Re-apply the § Guardrails DB/data check to the fix diff each round.
   **Exit:** zero pooled critical+major → PRD passes to step 5. `round == max_rounds` with issues still open → **PAUSE**: emit the residual issues and `AskUserQuestion` (Run more rounds / Skip this PRD with a logged blocker / Stop the run). Never silently pass a PRD with open critical/major issues.
5. **Gate clears + PR opens.** The final `pre-merge` run clears (`pass`/`pass_with_warnings`, zero open blocker/high) and, when its preview gate fired, the human approved — pre-merge then opens the feature→staging PR. The orchestrator itself **never** merges.
6. **Ship to staging.** Spawn a `post-merge --staging` subagent (Subagent contract) for this PRD. It verifies the PR's CI is green, merges it onto `staging` (the single sanctioned merge), runs the staging deploy, and emits the human test script. Post-merge then **STOPS** — a human tests staging and stamps `staging-signoff:`; the orchestrator does not wait on that human, and it **never** invokes `post-merge --production` (production is a human release). If post-merge refuses (red/pending CI, unprotected branch), treat it like a failed stage: surface the refusal and pause per § Guardrails rather than retrying blindly.
7. **PRD done (for the orchestrator's purposes)** — the bar is the PRD's own acceptance requirements: **every acceptance criterion in the done-set is satisfied and verified** (pre-merge PRD-consistency = clean), the `pre-merge` verdict clears with zero open critical/major, **and** `post-merge --staging` has merged it onto staging. A PRD with green tooling but an unmet acceptance criterion is **not** done — it re-enters the fix loop. Production sign-off is explicitly **not** part of the orchestrator's done bar. Record the done-set (met/unmet per criterion) in the ledger.

A **phase is complete** when every PRD in it is done. **Do not terminate the session until the current phase completes** — hold the session, keep the ledger live, keep reporting.

## Step 3 — Reporting (interval + on demand)

Maintain an in-memory **ledger**: for each PRD — phase, stage, round, open critical/major count, guardrail pauses, done/blocked. Emit a **standup digest** after each PRD completes and at each phase boundary:

```
[roadmap] Phase <k>/<K> · PRD <i>/<m> <prd-id> · stage=<build|pre-merge|fix#r|done>
          open: <c> critical, <j> major · guardrail: <none|paused: reason>
```

When the user asks anything status-like ("status", "how's it going", "where are we") **at any time**, immediately emit the current ledger digest for the whole roadmap — phases done, current PRD/stage, open issues, any pending guardrail pause. This is why the session stays foreground: the user talks to the orchestrator directly.

## Step 4 — Phase gate

At the end of each phase, emit a phase summary (PRDs done, issues fixed, any skipped-with-blocker), then `AskUserQuestion`: **Continue to next phase / Pause / Stop**. Default is to **pause for approval between phases** (safer for an autonomous run); if the user opted into continuous mode at Step 1 (`Adjust` → auto-continue), skip this gate and roll straight into the next phase.

## Step 5 — Roadmap-complete summary

When all phases are done, emit a final report: phases, PRDs merged to staging, total fix rounds, issues resolved, any PRDs skipped with logged blockers. Each done PRD is now **on `staging`** (merged by its `post-merge --staging` subagent) and awaiting a human's staging sign-off. The orchestrator itself **never** runs `git push`, `gh pr merge`, or `git merge` directly, and **never** ships to production. Hand off:

```
All phases complete. PRDs are merged onto staging and deployed. Test staging, then run
`/post-merge --production` yourself to release to main — production is always a human step.
```

Then terminate.

## Subagent contract

Every subagent is spawned via the `Agent` tool and **runs an msg skill — never general-purpose**. Each prompt is prefixed with the **autonomy paragraph**:

> You are running autonomously with no user present, as part of a roadmap execution. When the skill's protocol reaches an approval gate (`AskUserQuestion`), treat it as pre-approved and proceed. Only stop if genuinely blocked by missing information you cannot derive — if so, return the blocker instead of guessing. Read `.claude/skills/<skill>/SKILL.md` fully and follow its protocol.

**Injected context (Build and Fix subagents).** The orchestrator has already read the PRD and devkit and compiled standards once per stack, so each `eng --build` prompt carries — in addition to the fields below — a **`standards payload`** section (the compiled `/cook` output for this agent's stack; the leaf agent uses it and **does not call `/cook` itself**) and a **scoped context** block: this agent's assigned rows, the PRD feature sections those rows map to, and the devkit **digest** — so the sibling does **not** re-read the full PRD or every devkit file. Include this escape hatch in the prompt: *"The full PRD is at `<prd-path>`; read it on demand only if a scoped excerpt is insufficient to resolve a row."* Scope-enforcement and the branch contract are unchanged — the agent still touches only its assigned rows' files and commits only to `$BRANCH`.

Stage → skill mapping (Build/Fix carry the injected `standards payload` + scoped context above):

| Stage | Skill | Invocation |
|-------|-------|-----------|
| Build | `eng` | `--build prd-path=<p> rows=<...> branch=$BRANCH agent=<eng-platform> commit_mode=direct` |
| Fix | `eng` | `--build report=<report-prd-N-K.json> branch=$BRANCH` |
| Gate | `pre-merge` | `Skill("pre-merge", "<branch> --prd <p>")` inside the subagent |
| Ship | `post-merge` | `Skill("post-merge", "--staging --prd <p>")` inside the subagent — only after Gate opened a clean PR; never `--production` |

**Return contract:** each subagent returns a single JSON summary object (build summary, or the shared `finding-schema` verdict JSON for pre-merge) — **never** free-form prose. The orchestrator pools these into the ledger. A subagent that dies or returns unparseable output is treated as a failed stage and re-spawned once; a second failure escalates to the user (accepts no failures).

## Guardrails

The run is autonomous, so these are non-negotiable:

- **Branch isolation** — all work on `feat/prd-<n>-*`; the orchestrator never commits to `main`.
- **DB / data / production guard** — after **every** build and **every** fix round, run:
  ```bash
  S=.claude/scripts/eng-db-touch.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/eng-db-touch.sh"; bash "$S" main
  ```
  If it exits non-zero (it prints the offending `category<TAB>path` lines), **PAUSE** and `AskUserQuestion` (Approve & continue / Stop) — a migration, `.sql`, ORM schema/model, seed/fixture, `.env`, or production-config change needs the user's sign-off. Re-check after each fix round (a fix may introduce a new one).
- **Breaking-change pause** — any subagent that reports a schema or API breaking change pauses the run for sign-off before pre-merge.
- **No direct push / merge; no production** — the orchestrator never runs `git push`, `gh pr merge`, or `git merge` with its own hands. Merging onto `staging` happens **only** through the `post-merge --staging` subagent (the harness's single sanctioned merger), and **only** for a clean feature→staging PR. The orchestrator never invokes `post-merge --production` — shipping to `main` is always a human release.
- **Scope** — the orchestrator only touches what the roadmap's PRDs specify; it does not invent work, refactor unrelated code, or edit PRD product sections.

## Hard failures

- `roadmap=` path missing/empty → `Hard failure: roadmap <path> not found or empty`. Stop.
- A referenced PRD file missing → `Hard failure: roadmap references <prd-id> but its PRD file is absent`. Stop.
- A PRD that is **not full** (no verifiable §6 acceptance criteria, or no §7 execution table / todos to derive rows, or unfinished planning stamps) → **not runnable as-is**. Do not silently skip: trigger the Step 2 readiness gate `AskUserQuestion` (Amend now / Skip this PRD / Stop). Only a user **Skip** excludes it (logged in the phase summary); only a user **Stop** halts the run.
