# MSG Architecture

MSG is a Claude Code skill harness — a collection of slash-command skills for structured, agent-driven software development. Skills install globally into `~/.claude/skills/` and are invoked directly from Claude Code sessions.

## Layers

### 1. Install layer — `install.sh`

Shallow-clones this repo into a temp directory, then copies:
- `skills/` → `~/.claude/skills/` (each skill as its own subdirectory; `improve/` is excluded — it's a repo-internal plan tracker, never an installed skill)
- `scripts/` → `~/.claude/scripts/` (all `.sh` files and `script-prd-number` made executable)

The installer copies but never overwrites by deletion, so a **renamed** skill or script would otherwise leave its old copy behind forever — and a stale `~/.claude/skills/<old-name>/` shadows its replacement. Two explicit sweeps run before the copy: retired skill directories (`plan-tune`, `post-merge` — both renamed in v5) are removed, and every pre-v5 script filename is deleted so nothing can resolve an old copy through a fallback path. Only names msg itself shipped are ever listed.

Pass `--with-cook` to also bootstrap the [cook](https://github.com/ndisisnd/cook) dependency, which provides the `/cook` skill MSG skills call for domain-specific coding standards.

### 2. Skill layer — `~/.claude/skills/<name>/SKILL.md`

Each skill is a directory containing a `SKILL.md` — a structured prompt consumed by Claude Code's skill system when the user invokes `/name`. Skills are self-contained: they declare their `allowed_tools`, `model`, and protocol inline.

Skills compose in two ways:
- **In-session chaining** via the `Skill` tool (e.g. `plan-pm`'s end-of-run gate can invoke `plan-review` or `plan-em` directly)
- **Subagent delegation** via the `Agent` tool (e.g. `/pre-merge` fans out `/cook` sub-agents in parallel for its security stage)

The `shared/` skill holds common prompt fragments imported by multiple skills, including
`shared/refs/component-catalog.md` — the single source of pre-merge/merge component
metadata (schema, defaults, grouping) that gate sequencing, folder placement, and
check-script naming all key off.

### 3. Script layer — `~/.claude/scripts/`

Bash and Python helpers invoked by skills at runtime. Skills resolve scripts locally first (`./claude/scripts/`), then fall back to the global install.

**Naming convention.** Every script is named `script-<slug>.<ext>` (v5). The prefix marks the shared script library at a glance, and — deliberately — the slug carries **no owning-skill prefix**, so renaming a skill never cascades into renaming its scripts. The one exception is `changelog-gate.py`, whose path is pinned inside a `PreToolUse` hook in `.claude/settings.json` that Claude Code resolves at session start; renaming it would break the hook for any session already running, so it keeps its pre-v5 name.

There are ~58 scripts. Grouped by what they own:

**PRD lifecycle**

| Script | Purpose |
|--------|---------|
| `script-prd-number` | Assigns the next available PRD (or sub-PRD) number |
| `script-prd-shape.py` | Mechanical PRD shape validator — the seven canonical sections, the §3 features table, F-ID sequencing, reserved placeholders, frontmatter keys. Auto-detects and still validates the eight-section v5 shape |
| `script-prd-digest.py` | Deterministic PRD → JSON digest with per-stage slices (`plan`/`build`/`synth`); carries `engineering_agents` for plan-em's wave-mode detection |
| `script-prd-scan.sh` | Lane-aware PRD inventory (JSONL: frontmatter graph + `full`/`missing[]` completeness + optional `--git` completion ladder, `--exclude <id>`); consumed by plan-pm Step 2 and plan-em Step 1c |
| `script-prd-stamp.sh` | Shared scalar frontmatter writer for PRD lifecycle stamps (status, reviewed, completion, staging-signoff, plus the retired v5 tune stamps); single-line edit, idempotent |
| `script-prd-deps-mirror.sh` | §3 Dependencies → frontmatter `deps` union writeback (`ADDED <id>` lines, idempotent); rewrites `depends_on` instead on a v5-shape PRD |
| `script-intake-stamp.sh` | The `INTAKE.md` ledger writer — `--append-row`, `--set-cell`, `--remove-row`, `--find-row`, `--log-append`, plus the `status`/`prd` stamps. Header-derived columns, escaped pipes, temp-file writes; never renumbers |

**Certification (plan-review)**

| Script | Purpose |
|--------|---------|
| `script-cert-preflight.sh` | Resolves and validates the PRD path, and detects which tune type the content calls for |
| `script-cert-mech.py` | The mechanical half of certification — every check verdict decidable from PRD text alone, so the model only judges what needs judgment |
| `script-cert-status.sh` | Certification gate read — `CERTIFIED`/`UNCERTIFIED <reason>` from the `reviewed:` stamp + the findings ledger; gates plan-em's plan and build waves. Falls back to the v5 tune stamps and inline §7 on a PRD that has them |
| `script-ledger.py` | Writer for the plan-review findings ledger at `<prd-dir>/reports/review-prd-<n>-<slug>.md` — pick the home, locate-or-create, dedup against prior rows, monotonic `#`, clean-marker row. Appends to a pre-v5.4 PRD's inline §7 section instead when it has one |

**Engineering (plan-em, eng)**

| Script | Purpose |
|--------|---------|
| `script-em-exec-skeleton.py` | Renders the §6 exec-table skeleton (3 columns: `Feature — concern \| Files \| Agent`) from plan-em's JSON `(fid, concern, agent)` spec; `--fill-files` then derives every Files cell from the tickets' `files` fields |
| `script-em-exec-collision.py` | Exec-table collision checker (`COLLISION`/`MISSING_FILES`) + `--waves` packet decomposition consumed by the team orchestrator; reads both the 3-column and the legacy 5-column table |
| `script-em-branch-resolve.sh` | Read-only parent-aware branch resolver — emits `BRANCH`/`ACTION`/`LANE_MOVE` for the build wave (reusing a merged branch is impossible) |
| `script-eng-plan-shape.py` | Mechanical validator for an `eng --plan` pass — the three coupled artifacts it writes must agree |
| `script-eng-comment-scan.sh` | Deterministic A4 comment scan — flags added symbol declarations with no plain-English comment above them; run at the `eng --build` commit gate |
| `script-eng-commit-cap.sh` | A5 small-commit cap — measures a staged diff against 500 changed LOC (300 with `--breaking`); pairs the cap with the prepared message and its `Oversize-reason:` trailer |
| `script-eng-db-touch.sh` | DB/data/production-config touch detector on a diff (`category<TAB>path` lines); the guardrail behind every build's sign-off pause |
| `script-eng-fix-grade.py` | The one simple/complex fix-complexity grader — the rubric lives in code, not in each protocol's prose |
| `script-eng-close-loop.py` | The single sanctioned write to an issues file when `eng --build report=` closes a fix loop |

**Gates (pre-merge, merge)**

| Script | Purpose |
|--------|---------|
| `script-preflight-*.sh` | The per-check detect+normalize family — one script per component (`01-mechanical` … `18-manual-test-plan`), each emitting a normalized check-report `detect` section. `/pre-merge --init` / `--update` run them to assemble the `components[]` manifest. **Replaced the retired monolithic `pre-merge-tooling-detect.sh`** at v3 P3 |
| `script-check-common.sh` | The probe primitives every `script-preflight-*.sh` sources. Named outside the family glob on purpose, so the ingestion loop never mistakes the library for a check |
| `script-pipeline-resolve.py` | Prunes the manifest to what this project has, topo-sorts on dependencies, and emits the parallel wave plan |
| `script-tier-resolve.sh` | Deterministic S/M/L **size-tier** resolver for minified test selection — reads the diff's `modules` + the caller-supplied `ratio`/`fan_in_pct` against `policies.test_selection.tiers`/`max_affected_ratio`, short-circuits to `L` on a `force_full_paths` hit, and resolves the **largest** tier any signal lands in (an unavailable signal always widens). Read-only |
| `script-ts-miss.py` | Test-selection miss attribution — the CI-backstop half of the minified-selection bargain |
| `script-aggregate-verdict.sh` | Merges the per-component result reports into a single severity-graded verdict |
| `script-resolve-diff.sh` | Structured diff-vs-base summary (bundled with pre-merge, not in the shared library) |
| `script-ci-status.py` | Check-state set + policy → one CI verdict, so merge's three call sites cannot drift apart |
| `script-branch-protection.sh` | Branch-protection `--bootstrap` (required status checks + no-force-push on `staging`/`main`, plus ≥1 required review on `main`) and `--verify` (`PROTECTED`/`UNPROTECTED`; `NO_GH`/`NO_REMOTE` when degraded). Run by `/merge` Step 1; offered by `/msg --init-staging` and `--init` |
| `script-signoff-coverage.sh` | Read-only staging sign-off coverage check — does the newest staging commit still fall under the signed-off sha? |
| `script-release-identity.sh` | Read-only release identity for `merge --production` — current tag, next version, build, monotonicity, provenance |
| `script-release-lock.sh` | Production release lock (`acquire`/`release`/`status`) so two concurrent `--production` runs cannot both ship |
| `script-smoke-run.sh` | Executor for the v2 smoke contract plus the config-gated macOS release checks (notarization, signing, appcast) |

**Project state**

| Script | Purpose |
|--------|---------|
| `script-policy-read.py` | The reader for `devkit/policy.json` — fail-safe defaults when the file is absent |
| `script-policy-set.py` | The writer for `devkit/policy.json` — seeds, merges, preserves siblings, stamps `generated`/`generated_by` |
| `script-platforms-parse.py` | The one parser for `devkit/PLATFORMS.md` |
| `script-branch-topology.sh` | Read-only git branch topology — the single place msg answers "which branches exist and which is prod" |
| `script-doctor-detect.sh` | Read-only probe of repo visibility, branch-protection availability (Free-plan 403 sniff), and staging/prod branch topology → JSON. Seeds `devkit/policy.json`'s `repo` block + `release_flow` |
| `script-project-findings.py` | The one finding → issue-ticket projection, and the single home of the legacy wire-value map every finding reader inherits |

**File-owned writers** — a file, not a skill, owns each of these; any skill that records something writes through the file's writer rather than editing it freehand.

| Script | Purpose |
|--------|---------|
| `script-aha.sh` | Writer for `devkit/AHA.md` |
| `script-openq.sh` | Writer for `devkit/OPEN-QUESTIONS.md` |
| `script-doctor-log.sh` | Writer for `devkit/DOCTOR.md`, the harness-incident ledger |
| `script-doctor-tally.sh` | Reader for `devkit/DOCTOR.md` — everything decidable about the ledger, including which incidents have recurred enough to graduate |
| `changelog-gate.py` | Validates `CHANGELOG.md` format at the commit gate (hook-pinned name — see above) |

### 4. Devkit layer (scaffolded projects)

`/msg --init` generates a `devkit/` directory in the target project. The read-only docs are consumed by all other skills before doing any work and are never created by anything except `/msg --init`; the one writable exception, `devkit/policy.json`, is noted below the table.

| File | Role |
|------|------|
| `devkit/AHA.md` | Institutional knowledge log — past learnings agents must not repeat |
| `devkit/DOCTOR.md` | Harness-incident ledger — one row per time the harness itself misbehaved (a script that failed, a write that did not land, a validator that misfired). Written by every skill via `script-doctor-log.sh`, read by `/msg --doctor`. **Gitignored**: it describes this machine, not the product |
| `devkit/ENV.md` | The project's environment contract — the commands, tools, and variables a run may assume, so a skill never guesses how to build or test |
| `devkit/GLOSSARY.md` | Canonical domain terms — consistent naming across all agents |
| `devkit/ARCHITECTURE.md` | System constraints, layers, integration points — scopes what agents may touch |
| `devkit/DESIGN-SYSTEM.md` | Component registry — which UI components exist and what needs data ingestion |
| `devkit/OPEN-QUESTIONS.md` | Unresolved decisions — build agents write here when they hit ambiguity |
| `devkit/PLATFORMS.md` | Per-platform tolerance profiles + release pipeline — read by `/pre-merge` and `/merge`. Each platform row declares its `release_model` (`deploy` \| `submission` — inferred with a warn when absent), deploy/smoke cmds (smoke as one-shot, watch-window, or poll), staging config, rollback/rollout-halt cmds, a version probe for provenance, and the config-gated macOS surfaces (notarization status, signing smoke, appcast) |
| `devkit/policy.json` | Committed, shared gate policy — release-flow shape (`staged`/`direct`), branch-protection stance, whether GitHub Actions CI is wanted at all (`github_actions.enabled` — off ⇒ the gates stop expecting PR checks and stop offering a workflow scaffold), whether pre-merge should minify its `unit`/`integration`/`regression` runs to *affected(diff) ∪ critical-floor* (`test_selection.enabled` — opt-in, absent ⇒ full suites exactly as before), staging-readiness stance (`staging_readiness` mode + the per-platform `staging_ready` record `--init` resolves), and per-step tooling decisions. Read by both gates at run time; **decisions only** (never per-machine tool presence). Schema: `shared/refs/policy-schema.md` |

`devkit/policy.json` is the one **co-written** devkit file: `/msg --init` seeds it (`version`, `init:false`, `release_flow`, plus `github_actions` when it asked the CI question), `--init` completes it (tooling + branch-protection, flips `init:true`), `/msg --init-staging` flips the flow to `staged`, and `/msg --update` revisits the `github_actions` decision and is the single-run complete off switch for `test_selection` (enabling that key is deferred entirely to pre-merge's own interview — the two keys `/msg --update` writes). It gates the pipeline: a gate run with `init:false` auto-runs `--init` first; with `init:true` it runs the protocol; with no file at all it falls back to today's behavior (unmanaged repo). See the `--init` protocol refs (`{pre,post}-merge/refs/protocol-init.md`).

The root `INTAKE.md` backlog ledger is **not** a devkit file — it is scaffolded by `/msg --init` at the repo root (D13) but, unlike the read-only devkit docs, it is a living ledger written by `intake` (rows), `plan-pm` (status/prd mapping), and `merge --production` (completed status). Both it and its sibling `INTAKE-UPDATE.md` — the append-only edit history `intake --update`/`--delete` write, lazy-created on first edit — are **gitignored** (the shared table was a standing merge-conflict source), so the ledger and the completed stamp are local-only.

## Skill pipelines

```
Planning:   intake → plan-pm → plan-review --product → plan-em → plan-review --eng
Execution:  eng --plan → eng --build → pre-merge → merge --staging → (human) → merge --production
```

`roadmap/roadmap.md` still exists as a place to sequence PRDs into phases, and the `/msg --gui` Roadmap tab still renders it — but it is **hand-authored by a person** against `roadmap/TEMPLATE-roadmap.md`. No skill generates or executes it.

The planning pipeline starts at `intake`, the graded backlog front door: it captures every feature idea and bug as a row in the root `INTAKE.md` ledger (chronological table `# | date | type | idea | goal | grade | status | prd`), owning the requirements interview (flesh-out, adjacent-idea suggestion, hybrid/XL splitting) and grading each idea in a single-turn banded judgment (complexity / token-cost / sequencing — bands only). `plan-pm` then consumes a graded row and drafts the PRD autonomously; the row's `status` walks `backlog` (intake) → `in-progress` (plan-pm, which also fills the `prd` mapping) → `completed` (`merge --production`), giving the harness a living ledger connecting "things we want" to "PRDs that shipped."

Every skill is invoked directly and standalone; a skill's end-of-run gate recommends a next step but never invokes it automatically. The one deliberate exception is `plan-em`'s **certification preconditions**: `plan-em` auto-runs `plan-review --product` before it plans and, on a large PRD, `plan-review --eng` before it builds (D18), so a build can never start on an uncertified plan. `plan-review` itself is a **contract certifier** — it runs a fixed seven-check certification, each check bound to a named downstream consumer that executes a PRD field blindly (regression authoring, pre-merge's PRD-consistency gate, the safety pauses, `eng --build`'s row/ticket reads); "no check without a consumer" is its governing rule. It auto-fixes every Critical + Major and writes a category-tagged learning to `devkit/AHA.md`, which `plan-pm` reads on its next draft — a self-healing loop that trends fresh-PRD defect counts toward zero. `eng --plan` writes the per-feature todo tickets in the same pass as the engineering section, so execution is `eng --plan → eng --build` with no separate todo phase.

**How many invocations a PRD costs is sized to the PRD**, from the intake complexity grade `plan-em` resolves once at Step 1e. A **medium** PRD (`C:` < 8, and the default whenever the grade cannot be resolved) runs a single **fused** wave: one `/plan-em <prd>` certifies the product side, plans the tickets, derives the `Files` column, runs a mechanical plan-shape check in place of the eng certification, cuts the branch and builds — one invocation, one certification. A **large** PRD (`C:` ≥ 8) keeps the two-wave path: the first `/plan-em <prd>` certifies the product side and plans, the second certifies the eng side and builds. Either way the closing message says which wave just finished and therefore what to run next — re-run `/plan-em`, or move on to `/pre-merge`. An interrupted fused run needs no special handling: re-invoking `/plan-em` finds the engineering sections already written and completes the build half.

Parallelism lives *inside* a wave, not across skills. In `--team` mode (the default) an Opus orchestrator engineer decomposes the wave into file-disjoint, model-tiered packets and fans them out to leaf `eng` subagents; `--solo` runs one leaf subagent per roster stack. Either way the guardrails hold: all work on `feat/prd-<n>-*` branches, a sign-off pause on any database/data/production-config touch (`script-eng-db-touch.sh`), no skill merges with its own hands, and production is always a human release.

## Self-healing loop

The harness watches itself, and every fix it earns leaves a permanent check behind.

- **Detect** — two sources feed it: live incidents a skill hits mid-run, and failing cases in the regression-eval runner `evals/run.sh`.
- **Log** — one ledger, `devkit/DOCTOR.md`, appended through `script-doctor-log.sh`. A dumb append of a fixed signature; nothing reads it at run time, which is what keeps logging nearly free (`shared/refs/doctor-logging.md`).
- **Diagnose** — diagnosis is deferred: no skill diagnoses its own incident mid-run. `/msg --doctor` is invoked on demand and triages the whole ledger in one batch, graduating any signature that reaches 3 occurrences into an issue with a diagnosis, a fix path, and a named regression eval (`msg/refs/protocol-doctor.md`). It never fixes.
- **Fix** — a separate session the human starts with the graduated issue as its brief, done only once the named `evals/cases/<slug>` lands red → green.
- **Gate** — `evals/run.sh` before each release; the exit code is the whole gate.

Grading is mechanistic: a case passes when its command's output matches the committed golden files, so no LLM judges an eval and a pass means the same thing on every run.

## Releasing

Run `bash evals/run.sh` before tagging a release. Any FAIL blocks the release on the runner's exit code — no threshold, no judgment call. A failing case also appends a `validator-fail:eval-<slug>` row to `devkit/DOCTOR.md`, so the regression lands in the next `/msg --doctor` tally next to the live incidents.

## Skill inventory

| Skill | Standalone |
|-------|------------|
| `intake` | Yes (idea/bug capture + interview + grading into the root `INTAKE.md` backlog — the planning front door) |
| `plan-pm` | Yes (autonomous PRD writer — consumes a graded intake row; interview lives in `intake`) |
| `plan-review` | Yes (contract certifier — seven consumer-bound checks; `--product` runs 1/2/3/6, `--eng` runs 2/4/5/6/7; auto-run by `plan-em` before each wave) |
| `plan-em` | Yes |
| `eng` | Yes (`--plan` / `--build` / `--review` — `--build` spawns the reviewer by default before the commit confirm) |
| `pre-merge` | Yes (the CI gate — absorbs the retired `/review` + `/test`; runs a **preflight-driven pipeline executor** over the `components[]` manifest in `devkit/policy.json` — no manifest → refuses `no_manifest` naming `--init`; `--init`/`--update` detect the pipeline and write the manifest. Pre-merge holds **no human gate** — the human look at a running build is merge's (staging sign-off, or the direct-flow attestation). **`smoke`** is the machine stand-in: a default-liveness floor + critical-path golden flows, run first inside the ephemeral test sandbox so a dead build short-circuits the expensive checks. Opt-in **minified test selection** (`policies.test_selection`, `executor.md` §3c) narrows `unit`/`integration`/`regression` to *affected(diff) ∪ critical-floor*, sized by a deterministic S/M/L tier rubric computed from the diff's blast radius alone — never critical-only, always fail-open to the full suite on any resolution failure, with `--minified`/`--full` as per-run overrides and `--update-criticality` reconciling tag drift) |
| `merge` | Yes (the ship gate — `--staging` / `--production`; the only skill that merges; verifies each deploy per platform `release_model` — `deploy` platforms (web, macOS) smoke the live target under the v2 contract (one-shot / watch-window / poll), plus config-gated macOS notarization/signing/appcast checks; `submission` platforms (iOS, Android) never report live — a deploy is `submitted` + track, verified as submission-accepted + backend/build-health smoke, with an explicit monitor-handoff; any deploy/smoke failure offers an executable rollback or rollout-halt before the fix loop; `--production` additionally resolves read-only release identity (version/build off the last `v*` tag, provenance checked against the signed-off sha) and holds a release lock against a concurrent release; `--init` sets up protection/deploy tooling + release-flow policy and verifies per-platform staging readiness) |
| `msg` | Yes (interactive skill browser; `--init` runs the one-time project bootstrap + seeds `devkit/policy.json`; `--init-staging` adds a staging branch and flips the release flow to `staged`; `--gui` serves the local interactive PRD board — Kanban/table, PRD editing, todo toggling, prompt console, project-doc viewer, run-report reader — via `refs/gui/server.py`, bound to 127.0.0.1) |
| `shared` | Internal only |

## Run reports

`eng --build`, `pre-merge`, and `merge` end every completed run by writing a `report-[n].md` (schema: `shared/refs/report-schema.md`) to the PRD's `features/prd-<n>-<slug>/reports/` folder, or `features/reports/` when no PRD is resolvable — `[n]` is the standard `max+1` counter per directory. The report carries GUI-parseable frontmatter (skill, PRD, branch, verdict, features, diff/test stats) and fixed sections covering work done, code changes, test results, **what the user can expect**, and **how to verify** the work — written for a human, derived from the PRD's acceptance criteria and the tests that ran. Merge's staging report carries the human test script in `## How to verify`; its production report renders release-style — the resolved version/tag and per-platform release-model outcomes (`live` for deploy platforms, `submitted` + track + monitor-handoff for store apps), any rollback/halt offer and its outcome, and any no-rollback platform (iOS) flagged `IRREVERSIBLE`. Writes are best-effort (a failed write never fails, blocks, or re-verdicts a run) and supplement — never replace — each skill's existing output contract (eng's build summary, pre-merge's final JSON emission, merge's merge/deploy summary). The `/msg --gui` **Reports** tab groups them by PRD and renders them read-only.

## Closing message

Every pipeline skill run ends with a standardised chat closing message (`shared/refs/closing-message.md`, alongside `report-schema.md` and `fix-loop.md` in the shared contract layer): a 🟢/🟡/🔴 protocol headline mapped deterministically from the run's verdict, a one-line plain-language summary, a what-happened table (max 1–2 lines per row), and a **Next steps** section whose entries come from a fixed skill × mode × protocol registry — never composed ad hoc, byte-consistent with `fix-loop.md` on fail paths. It is the last chat output of a run and supplements each skill's existing output contract (pre-merge's verdict JSON stays the final machine emission). Chat-only: the GUI never renders it; the run report remains the GUI's source. Out of scope: `improve` and msg's pure-emission modes (default picker, `--gui`, `--help`).

## Run visibility

The long phases — `eng --build`, `pre-merge`, `merge`, and `plan-em`'s waves — can
run for tens of minutes with nothing shown on screen. A short status line appears
roughly every five minutes so a person watching always knows what phase is
running, what just finished since the last update, and whether anything is
blocking.

This is a **cadence-checked checkpoint, not a timer**: the run can only speak
when it naturally regains control — between steps, waves, or checks — never by
interrupting a running command just to post an update. That is also why it is
purely observational: it reports what is already true and never changes a
verdict, a refusal, or a gate. `--quiet` and `--status <n>m` tune it per run;
`policies.status_cadence` tunes it per project. Contract:
`shared/refs/status-heartbeat.md`.

## Review evidence

Every build that produces a diff is reviewed by an agent that did not write the
code. That was already the rule; what v5.3 adds is that it is now **provable**.
The reviewer writes one artifact per packet —
`features/prd-<n>-<slug>/reports/review-prd-<N>-<K>.json`, its whole return object
plus `reviewed_by` and `built_by` — and every orchestrator that spawns builds asks
`script-eng-review-check.sh` whether each packet has one **before** it consolidates.
A missing artifact is repaired by spawning a reviewer over that packet's diff, never
by re-running the builder; a second miss escalates to the user and logs a DOCTOR row.
`pre-merge` backstops the whole thing by reporting coverage for the branch it grades.

The reason for the artifact is that a skipped review and a clean review look
identical from the outside: both return silence. Presence therefore has to be a
filesystem fact rather than a claim in a summary — anything that must happen needs a
check that can fail, not a sentence that must be obeyed. Review's **authority** is
unchanged and deliberately narrow: nothing below `high` blocks, nothing here blocks a
merge, and coverage is reported rather than enforced. `pre-merge`'s green run remains
the safety floor. Contracts: `eng/refs/review/protocol.md` § Artifact and
`shared/refs/finding-schema.md`.

## Safety floor

Write powers are scoped per skill rather than blanket-forbidden: eng commits to `feat/prd-<n>-*` feature branches only; pre-merge opens exactly one feature→staging PR (+ the D7 sync-merge commit) and never merges; **merge is the only merger** — staging via a green-CI PR merge, production via the double-confirmed staging→main release — and nothing reaches `main` any other way. Merge's two release tags — the `v<x.y.z>+<build>` version tag and the in-flight release lock — are commit **metadata**, not source writes, and are its only writes beyond the merges, stamps, and reports. DB/data/prod-config pauses, breaking-change pauses, branch isolation, secret scan, frontmatter stamps, F-ID stability, PRD §7 ledger, gate-fail ticket, pre-merge refusals, and the human gates (staging sign-off — pinned to the tested commit, the direct-flow inline human-test, the always-ask rollback offer, production double-confirm) are **never relaxed** (`shared/refs/safety-floor.md`).

## Cook integration

`cook` is an optional but recommended dependency. MSG skills load project-specific coding standards from cook before generating code. Standalone skill runs call cook directly (`eng`/`plan-em` pass explicit `--<domain>` flags, e.g. `--flutter --dart`, for a cacheable, P0-guaranteed compile). On orchestrated paths, the orchestrator (`plan-em --team`, `eng --build`'s review spawn) compiles cook **once per stack** and injects the compiled standards payload into each subagent prompt, so leaf agents never re-invoke cook. Without cook, skills still work — they just skip the standards-loading step.
