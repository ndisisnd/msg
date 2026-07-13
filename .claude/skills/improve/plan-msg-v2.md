---
name: msg-v2
status: ready-to-build
description: msg v2 — architectural restructure of the core skill harness. Consolidates review+test into pre-merge, adds post-merge (staging→production), rebuilds eng around default todos / pair-programming / small commits. Objectives — faster development through the harness, lower token cost per coding run.
---

# msg v2 — Harness restructure

**Objective:** increase development speed through the harness AND decrease token cost/usage in coding runs overall.

**Benchmark gate:** every phase is measured with `evals/bench.py` before/after (same discipline as plans 19–21). A change that regresses net tokens without a compensating speed/safety win gets cut.

## The v2 pipeline

```
v1: plan-pm → plan-tune → plan-em → eng --plan → [--todo] → eng --build
      → review → test → fix loop → pre-merge → (human merges by hand)

v2: intake                   (NEW — idea/bug capture into INTAKE.md; owns the interview: flesh
                               out, suggest, split hybrid asks, grade by complexity/token/sequence)
      → plan-pm              (AUTONOMOUS — picks an intake idea, drafts the full PRD solo;
                               pauses only for open questions + breaking/critical touches)
      → plan-tune             (CERTIFIER — auto-fixes Critical+Major w/ terminal table, asks on
                               Minors; intent-fidelity + testability checks; self-heals via AHA.md)
      → plan-em
      → eng --plan            (engineering section + todo tickets in ONE pass, todos always on)
      → eng --build           (unit+integration only · pair-programmer per ticket · plain-English
                               comments · ≤500/300-LOC commits)
      → pre-merge             (THE CI gate — absorbs /review + /test: sync → mechanical → tests →
                               regression → security/migration → PRD-consistency → preview deploy
                               [human gate] → opens PR feature→staging · platform-tolerance modes)
      → post-merge --staging  (merges PR into staging on green CI, deploys, human tests)
      → post-merge --production (double-confirm, PRs staging→main)
```

**Skill inventory delta:** `/review` — deleted (folded into pre-merge). `/test` — deleted (buckets folded into pre-merge). `/post-merge` — new. `/intake` — new (idea capture + interview + grading, Part F). `eng`, `pre-merge`, `plan-em`, `msg --init`, `msg --gui` (Part H) — rebuilt/modified. `plan-pm` — rebuilt (autonomous; interview moves to intake, Part F). `plan-tune` — rebuilt (certification authority: intent fidelity, testability, breaking-change hunt, auto-fix Critical+Major, self-healing loop — Part G).

## Decisions log (settled 2026-07-13)

| # | Decision | Choice |
|---|----------|--------|
| D1 | Fate of `/test` | **Fold into pre-merge entirely.** Bucket refs + tooling detection migrate; `/test` deleted. |
| D2 | Review's semantic modes | **Security + Migration survive** inside pre-merge. Quality/Coverage/Functional/Perf covered by pair-programmer + mechanical gates + real test execution. |
| D3 | Branch topology | **feature → staging → main.** Two long-lived branches; main = production. Pre-merge PRs feature→staging; post-merge --staging merges it; --production PRs staging→main. |
| D4 | Pair-programmer cadence | **Per todo ticket, blocking.** One revision round max, then justify-or-escalate. |
| D5 | Regression-test edits | **Edit with justification.** Merge agent may update stale prior-PRD regression tests; every edit logged as a finding in the verdict JSON citing the PRD clause that justifies it. |
| D6 | Preview-gate trigger | **Path heuristic.** Diff touches UI-surface paths (review's old a11y trigger logic) or API/schema/migration paths → gate fires. |
| D7 | Sync conflicts | **Auto-resolve trivial only.** Non-overlapping/whitespace/lockfile conflicts auto-resolved; semantic (same-hunk) conflicts pause for human. Unit+integration always re-run post-sync, catching bad auto-merges. |
| D8 | Migration order | **Phased A→B→C**, `evals/bench.py` gate between phases; harness stays working at every step. |
| D9 | Pre-merge write powers | **Split.** Pre-merge itself performs only the mechanical sync-merge commit (D7-bounded — one correct answer or pause). Regression tests are **authored by a spawned eng subagent** from the PRD + tickets; pre-merge runs and grades them. Write power stays with the gate only where the write is mechanical; judgment writes are delegated so the gate remains adversarial to what it grades. |
| D10 | Preview kind | **Per-platform** `preview_kind: url \| artifact \| screenshots` in `devkit/PLATFORMS.md`. Web=`url`, iOS/macOS/Android=`artifact` (TestFlight/simulator/.apk build), `screenshots` as an explicit opt-down only. The strictest platforms pay the human round-trip they deserve. |
| D11 | Staging sign-off record | **Hybrid.** post-merge stamps `staging-signoff: <date>` into PRD frontmatter after an explicit approval question (harness/GUI-readable), AND branch protection requires the human's GitHub approval on the staging→main PR (machine-enforced). Belt and suspenders. |
| D12 | plan-tune --eng dimension 5 | **In V2-A, narrow.** Add exactly two checks: ticket-size feasibility vs the A5 commit caps, and platform-profile bucket coverage. No other tune changes — keeps the auditor honest from day one without widening the phase. |
| D13 | INTAKE.md location & ownership | **Repo root.** Scaffolded by `/msg --init` from `TEMPLATE-INTAKE.md`; row content written by `intake`, PRD-mapping + status stamps written by `plan-pm`/`post-merge`. Not in `devkit/` — devkit files are read-only after init, INTAKE.md is a living ledger. *(Default chosen while drafting — veto-able.)* |
| D14 | Intake status lifecycle owner | `backlog` (intake, on capture) → `in-progress` (plan-pm, when the PRD is created and mapped) → `completed` (post-merge `--production`, when the mapped PRD ships). Manual edits via GUI allowed. *(Default chosen while drafting — veto-able.)* |
| D15 | plan-tune severity policy | **Auto-fix Critical + Major**; emit a compact terminal table (1–2 lines per finding: what was found → what was fixed), then ask whether to fix Minors. The step-4 human gate and the fix-selection multiSelect are deleted; the only remaining pause types are the Minor ask and product-decision findings. |
| D16 | plan-tune self-healing loop | Critical/Major findings are a **drafting-quality signal, not routine**. Each auto-fixed Critical/Major logs a compact learning to `devkit/AHA.md` (which plan-pm already reads pre-draft — the loop closes with zero new plumbing). Same finding category recurring across ≥3 runs → plan-tune flags that the drafting protocol itself needs repair, not the PRDs. |

## Safety floor v2 (rewrite of `shared/refs/flash-floor.md`)

v1's "never push / never PR / never merge" **dies** — pre-merge now opens PRs, post-merge merges them. The replacement floor:

1. **Branch protection enforces green CI** on `staging` and `main` (item 9) — no merge without a passing pre-merge verdict, machine-enforced, not convention-enforced.
2. **Human gates, never removed in any mode:** preview-deploy approval (material UI/backend changes), staging sign-off before `--production`, double-confirmation on `--production` itself.
3. **Unchanged from v1:** DB/data/prod-config pauses (`eng-db-touch.sh`), breaking-change pauses, branch isolation (`feat/prd-<n>-*`), secret scan, frontmatter stamps, F-ID stability, PRD §9 ledger.
4. **New:** nothing merges to `main` except from `staging`, and only via post-merge `--production`.

---

## Part A — Eng rebuild

### A1. Plan + todos merged into one default pass (item 1)

- `--todo` stops being a separate mode/dispatch wave. `eng --plan` writes the `## Engineering — <Agent>` section **and** its `## Todos — <Agent>` tickets in a single agent pass.
- Delete the `$TODOS` pref toggle (`plan-em/prefs.json` + `refs/prefs-bootstrap.md` + plan-em Step 0). Exec table always carries the Todos column.
- plan-em Step 4 mode detection simplifies to two modes: `plan` (section+tickets) and `build`.
- **Ticket sizing rule moves here:** each `F<n>-T<k>` ticket must be scoped so its implementation diff lands under the commit caps (A5). An agent that can't scope a ticket under the cap must split it at plan time, not at build time.
- **Token/speed impact: −1 full subagent dispatch round per platform** (the entire --todo wave), minus one PRD re-read per agent. Pure win.

### A2. Build test surface = unit + integration only (item 2)

- `eng --build`'s TDD loop and full-suite gate scope to **unit + integration tests only**. No e2e, visual, perf, a11y, coverage runs inside the build loop.
- Everything else is pre-merge's job (Part B). Build stays fast and cheap; the expensive buckets run once at the gate instead of per-fix-iteration.
- **Token/speed impact:** large — inner loop iterations no longer pay for heavy buckets.

### A3. Pair-programmer subagent (item 3)

- New build-protocol step: after each todo ticket's implementation passes green, and **before its commit gate**, the eng agent spawns one review subagent.
- **Persona:** principal engineer, N+ years in the parent agent's platform (persona template parameterised by the exec-table Agent column — e.g. `eng-ios` spawns a principal iOS engineer).
- **Single mandate: unnecessary lines of code.** Dead code, needless abstraction, duplicated logic, over-engineering, code that a stdlib/framework call replaces. It does NOT re-review correctness (tests own that), style (lint owns that), or security (pre-merge owns that) — keeps the prompt and the diff-scoped context tiny.
- **Contract:** input = the ticket's diff + the ticket's `done-when` + the compiled standards payload already in the parent's context (no separate /cook call). Output = findings list. **Blocking:** parent must resolve or justify each finding; exactly one revision round, then unresolved findings are logged to the PRD findings ledger and the commit proceeds with justification.
- **Token/speed impact: +1 small diff-scoped subagent per ticket.** Bounded by A5's commit caps (≤500-LOC input). Net-positive bet: it deletes code (smaller diffs for pre-merge, smaller codebase for every future agent read).

### A4. Plain-English comments convention (item 4)

- Build-protocol rule: every new/modified function, module, class, and exported symbol gets a comment above it stating **in plain English what it does** (not how).
- Enforced twice: the pair-programmer checks it per ticket (cheap — it's already reading the diff); pre-merge's mechanical stage greps changed files for uncommented new symbols (deterministic script, zero LLM cost).
- Secondary payoff: future agents can orient from comments instead of reading whole bodies — a compounding input-token cut.

### A5. Small-commit caps (item 10)

- Per-commit diff caps: **<500 changed LOC** general, **<300 changed LOC when the commit contains a breaking change.** Changed LOC = additions + deletions from `git diff --numstat`, excluding lockfiles/generated files (allowlist in the script).
- New helper `eng-commit-cap.sh`: run at the build commit gate; over-cap → block, agent must split the commit. Escape hatch: an over-cap commit MUST carry an `Oversize-reason:` trailer in the commit body with a concrete justification; the script logs it to the PRD ledger. To be avoided — a recurring oversize pattern is a ticket-sizing failure (A1).
- pre-merge re-checks commit sizes across the branch and grades an unjustified oversize commit as a `medium` finding.

---

## Part B — Pre-merge rebuild (absorbs /review + /test)

Pre-merge becomes **the** CI gate: one skill that takes the feature branch from "eng says done" to "PR open against staging with green checks and a human-approved preview."

### B1. What it absorbs

- **From `/test` (deleted):** all 10 bucket refs (`refs/modes/*.md`), `test-tooling-detect.sh` consumption, the aggregate-verdict script, the `--flaky`/`--changed-only` mechanics, the `msg-test/test-<n>.json` fail-ticket loop (renamed `msg-gate/gate-<n>.json`; `eng --build test-json=` becomes `gate-json=`).
- **From `/review` (deleted):** the Security stage (secret scan + SAST via `/cook --security --auth`), the Migration stage (static SQL-safety scan + semantic pass when a DB flag assembles), and the diff-resolution/fingerprint/verify-prelude machinery (pre-merge becomes the prelude's producer AND consumer). Quality/Coverage/Functional/Performance modes are **not** carried over (D2).
- The canonical finding schema, report-`[n]`.md writing, and run-dir JSON outputs stay exactly as-is — consumers (GUI, eng gate-json builds) see the same shapes.

### B2. The gate sequence (items 6, 8 — order confirmed rearrangeable)

```
0. Resolve platform mode from devkit (B3) → pick strictness profile + bucket set
1. SYNC (item 8): fetch + merge latest staging into the feature branch. Trivial conflicts
   (non-overlapping / whitespace / lockfile) auto-resolved; semantic (same-hunk) conflicts pause
   for human (D7). Steps 3–4 always re-run post-sync, so a bad auto-merge cannot pass silently
2. MECHANICAL: lint, format, typecheck, comment-coverage grep (A4), commit-cap audit (A5) — scripts, no LLM
3. UNIT + INTEGRATION: re-run post-sync (the sync may have changed behavior)
4. REGRESSION (item 6): run the accumulated regression suite; then a spawned ENG SUBAGENT authors
   new regression tests for this PRD from the PRD acceptance criteria + todo tickets (D9 —
   pre-merge never authors tests it will grade), persisted to tests/regression/prd-<n>/ so the
   suite compounds across PRDs ("doesn't break production"). Pre-merge runs and grades the result.
   When this PRD legitimately changes behavior an older regression test asserts, the eng subagent
   MAY edit that test — but each edit is emitted as a finding in the verdict JSON citing the PRD
   clause that justifies it (D5); an edit with no citable clause is a `high` finding instead
5. PLATFORM BUCKETS: e2e / visual / mobile / perf / a11y / coverage — which ones run is decided
   by the platform profile (B3), not hardcoded
6. SECURITY + MIGRATION: the two surviving review stages
7. PRD-CONSISTENCY: diff vs PRD spec — every F-ID's acceptance criteria demonstrably met, nothing
   out-of-scope shipped (replaces review's Functional mode with a single spec-match pass)
8. PREVIEW DEPLOY (human gate): fires on the D6 path heuristic — diff touches UI-surface paths
   (review's old a11y trigger logic) or API/schema/migration paths. Produces the profile's
   preview_kind (D10): url → deployed link; artifact → installable build + what-to-poke-at notes;
   screenshots → driven before/after captures. BLOCKS on human approval. No trigger match →
   step skipped and noted in the verdict
9. OPEN PR feature→staging with the verdict JSON + report linked in the PR body
```

Any red step short-circuits per severity rules; the fail-ticket (`msg-gate/gate-<n>.json`) feeds `eng --build gate-json=` exactly like the v1 test-ticket loop.

### B3. Platform-tolerance modes (item 7)

- New devkit file **`devkit/PLATFORMS.md`**, written by `/msg --init` (interview gains 1 question) — one row per shipping platform: `platform | rollback_possible | tolerance | preview_kind | preview_deploy_cmd | required_buckets`. `preview_kind` (D10) is `url` (web — deployed link), `artifact` (mobile/desktop — TestFlight/simulator/.apk build presented for install), or `screenshots` (explicit opt-down — pre-merge drives the changed flows and the human approves before/after captures).
- Baked-in defaults (overridable): **iOS/Android** — no rollback → `strict`: all buckets, full e2e + mobile matrix, coverage floor enforced, preview gate always fires. **Web** — continuous redeploy → `lenient`: e2e + smoke only, coverage advisory, preview gate only on visual diffs. **macOS** — middle: `standard`.
- Tolerance affects **bucket selection and severity thresholds**, never the safety floor (security, migration, human gates run in every profile).

### B4. Guardrail changes

- Pre-merge KEEPS: never merges, never touches `main`, evidence-quoted findings, empty-diff refusal.
- Pre-merge LOSES: `out_of_scope_action` on PR creation (it now opens the PR) and gains exactly ONE direct write carve-out: the D7-bounded sync-merge commit (mechanical — one correct answer or pause). Regression-test writes happen via the spawned eng subagent (D9), never by pre-merge's own hand; pre-merge runs and grades what came back. Source-code modification remains refused for both pre-merge and the regression eng subagent (test files only).

---

## Part C — Post-merge (new skill, items 9 + 11)

Invoked by another agent or the user after pre-merge's PR exists.

### C1. `post-merge --staging`

1. Verify the feature→staging PR has green CI (branch protection is the enforcement; this is the check).
2. Merge the PR into `staging`.
3. Deploy the staging environment (command from `devkit/PLATFORMS.md`, per-platform pipeline).
4. Emit a human test script (derived from the PRD's "how to verify" report sections) and STOP — a human tests staging. Post-merge never self-certifies staging.
5. When the human confirms staging works (explicit AskUserQuestion approval), stamp `staging-signoff: <date>` into the PRD frontmatter (D11). This stamp is the harness-readable half of the sign-off record.

### C2. `post-merge --production`

1. Preconditions: staging is green, `staging-signoff:` stamp present in PRD frontmatter (D11) — refuses without it.
2. **Double-confirmation:** two explicit, separately-asked approvals (intent + final confirm listing exactly what ships).
3. Opens the PR `staging → main` with a release-style body (PRDs included, reports linked, rollback notes per platform profile — flagged `IRREVERSIBLE` for iOS).
4. Merges only after green CI on the PR; per-platform pipeline runs its production deploy steps.

### C3. Branch protection bootstrap (item 9)

- One-time setup via `gh api` (required status checks + no-force-push on `staging` and `main`; **required human review on staging→main PRs** — the machine-enforced half of D11), offered by `/msg --init` when a GitHub remote exists, and re-verified by post-merge at Step 1 (refuses with setup instructions if protection is absent).

---

## Part D — Cross-cutting consequences

| Area | Change |
|------|--------|
| `plan-em` | Step 0 prefs deleted; Step 4 dispatches plan(+tickets) or build only; synth references new pipeline |
| `eng --build roadmap=` | Orchestrator chain becomes eng → pre-merge → post-merge --staging (stops there; --production is always human-initiated) |
| `shared/refs/flash-floor.md` | Rewritten to Safety floor v2 (above) |
| `shared/refs/verify-prelude.md` | Producer changes review→pre-merge; test/pre-merge consumer split collapses |
| `shared/refs/finding-schema.md`, `report-schema.md` | Unchanged shapes; source enum drops `review`/`test`, adds `pre-merge` stages + `post-merge` |
| `/msg --gui` | Full v2 rework — completion ladder, Intake tab, Gate Issues tab, post-merge reports, INTAKE.md write carve-out. **See Part H.** |
| `/msg --init` | +1 interview question (platform profiles) → writes `devkit/PLATFORMS.md`; scaffolds `INTAKE.md` from `TEMPLATE-INTAKE.md` (F2); offers branch-protection bootstrap |
| `/msg` menu, `--help` routing table | review/test rows removed, post-merge + intake added |
| README / ARCHITECTURE.md | Pipeline diagrams, skill inventory, run-modes section all updated |
| Flash modes | pre-merge flash = mechanical + unit/int + security only (floor intact); post-merge has NO flash (gates never collapse) |

## Part E — Install layer: manifest-driven removals

`install.sh` currently hardcodes retired-skill removal (`for retired in msg-init`, install.sh:63-70). v2 replaces that with a **removal manifest** so retiring a skill is a one-line data change, not a script edit.

- **New file `remove-manifest.txt`** at repo root, shipped with the clone. One entry per line, `#` comments allowed. Entries are exact paths relative to `~/.claude/`:
  ```
  # skills retired from the global install
  skills/msg-init      # folded into /msg --init (was hardcoded)
  skills/docu
  skills/handoff
  skills/ship
  skills/plan
  skills/design
  skills/improve       # repo-internal tracker, never should have shipped (see below)
  # scripts orphaned by retired skills
  scripts/ship-db-touch.sh
  scripts/ship-find-prd.sh
  ```
- **install.sh change:** after the install-skills loop, read the manifest from the cloned repo; for each entry, exact-match the path under `~/.claude/`, `rm -rf` it, and log `Removed retired: <entry>`. Absent target → silent skip (idempotent).
- **install.sh exclusion:** the install-skills loop skips `improve/` entirely (`[[ "$skill_name" == "improve" ]] && continue`). It's a repo-internal plan tracker — not invokable, state = folder location — and installing it snapshots a fork of the tracker that immediately drifts (the current global copy already disagrees with the repo on plan IDs 19/20). The manifest entry above cleans existing installs; the exclusion stops it recurring.
- **Guardrails:**
  - **Exact paths only, no globs/prefixes** — `skills/plan` must never touch `plan-em`/`plan-pm`/`plan-tune`.
  - Reject entries containing `..`, absolute paths, or anything not under `skills/` or `scripts/` — the manifest can never reach outside `~/.claude/skills` + `~/.claude/scripts`.
  - **Install/remove conflict check:** an entry that names something also present in this run's install source is skipped with a warning (manifest bug, not a removal).
  - `scripts/<file>` entries allowed for retired helper scripts — exact filenames only.
- **Phasing:** manifest + the six entries above land in **V2-A** (independent of the consolidation). **V2-B appends** `skills/review`, `skills/test`, and their orphaned scripts (e.g. `test-aggregate-verdict.sh`) once the pre-merge consolidation deletes them from the repo — so existing installs get cleaned on their next update.

## Part F — Intake layer + autonomous plan-pm

The planning front-door is restructured: **idea capture and the interview move to a new `intake` skill**, and plan-pm becomes an autonomous PRD writer that pauses only for open questions and safety.

### F1. New skill: `/intake`

- Captures **feature ideas and bugs** as rows in `INTAKE.md` — chronological table: `# | date | type (feature|bug) | idea | goal | grade | status | prd`.
- **Owns the interview** plan-pm used to run. Per idea, via AskUserQuestion: (1) flesh out the idea when it's thin; (2) proactively suggest adjacent/complementary feature ideas; (3) ask for the core user goal + product objective when unclear.
- **Hybrid-ask detection:** a compound ask ("streaks + notifications + rewards") is recognised and broken into multiple discrete idea rows, served back for confirmation via AskUserQuestion. This **replaces plan-pm's epic-split gate** — splitting happens at capture, not at planning.
- **Grades every idea** on a three-part rubric, stored compactly in the row's `grade` cell (e.g. `C:L T:$$ S:blocked-by-#4`). **The grade is a single-turn LLM judgment at capture time — never an analysis pass. Banded estimates and ranges only; fake-precise numbers ("~1,240 LOC") are forbidden by the template.**

  | Dimension | Scale | Bands |
  |---|---|---|
  | **Complexity** `C:` | `S / M / L / XL` | S = single module, <~200 LOC; M = one platform, several modules, no migration; L = multi-module OR a migration; XL = cross-platform AND/OR migration + breaking surface |
  | **Token cost** `T:` | `$ / $$ / $$$` | derived from complexity + platform count (more platforms → more eng agents; more tickets → more pair reviews; migrations → stricter gate). Ranges, not totals |
  | **Sequencing** `S:` | `now / next / later / blocked-by-#n` | position vs other intake rows + existing PRD `depends_on`/`affects` edges; `blocked-by` cites an intake row or PRD. Feeds `plan-pm --roadmap`, which now sequences from a graded backlog |

  - **The rubric is actionable, not just descriptive:** an `XL` complexity grade triggers the hybrid-split question at capture — "this grades XL, break it into smaller ideas?" — the same muscle as hybrid-ask detection, and the front-door defence of the A5 commit caps (an XL that stays whole will produce oversize tickets downstream).

### F2. INTAKE.md contract

- **Scaffolded by `/msg --init`** from a new `TEMPLATE-INTAKE.md` (lives with the other init templates); idempotent like every --init file. Repo root, not devkit (D13).
- Statuses: `backlog | in-progress | completed` (lifecycle owners per D14). Every planned row carries its `prd-<n>` mapping — the ledger connecting "things we want" to "PRDs that exist."
- `/msg --gui` gains an **Intake tab** (backlog board over INTAKE.md; status edits allowed, consistent with the GUI's existing write scope).

### F3. plan-pm rework — autonomous planning

- **Interview deleted.** The 5-question protocol and epic detection are gone (intake owns both). plan-pm consumes a graded, fleshed-out intake row.
- **Entry paths:** no args → read INTAKE.md → list non-`completed` ideas → AskUserQuestion which to plan. With an intake row reference (or explicit idea text) → plans it directly. Direct prose without an intake row → offers to log it through `/intake` first (one bounce, keeps the ledger complete).
- **Autonomous drafting:** edge cases, feature/acceptance table, user flows, error handling — the full PRD is written solo, no per-section gates.
- **Pauses ONLY for:**
  1. **Open questions** — everything the draft couldn't resolve is batched back via AskUserQuestion (≤4 per call) for answers/approval; answers are applied autonomously.
  2. **Breaking changes / critical cuts** — the draft would break an existing contract or cut into critical surface (overlap with a shipped PRD's features, DB/data/prod-config territory). Safety-floor pause, never relaxed.
- **Termination:** after open questions are answered and applied, one final ask — "anything to follow up on this PRD?" — then terminate, recommending (never invoking) `plan-tune --product`.
- `--sub` and `--roadmap` survive unchanged, except `--roadmap` now reads intake sequencing grades as an input, and `--sub` follow-ups may be logged as intake `bug` rows to keep the ledger complete.

### F4. Status lifecycle wiring (D14)

`intake` writes rows as `backlog` → `plan-pm` stamps `in-progress` + the `prd-<n>` mapping when the PRD file is created → `post-merge --production` stamps `completed` when the mapped PRD ships. The GUI Intake tab may hand-edit statuses (same trust level as its PRD board edits).

## Part G — plan-tune v2: the certification authority

In v2, plan-tune is the load-bearing wall of the planning layer. plan-pm drafts autonomously (F3), review is deleted (D1/D2), and the PRD's acceptance criteria became **executable** — regression tests are authored from them (D9), pre-merge's PRD-consistency check grades against them (gate step 7), and the preview gate keys off them. A vague criterion no longer just reads badly: it produces a weak regression test that then guards production forever. plan-tune is the only check between a machine-drafted PRD and all of that.

### G1. Product tune — two new checks

- **Intent fidelity (new check, scope-integrity dimension):** audit the PRD *against its intake row* — every feature traceable to the row's idea/goal (catches autonomous scope-creep), every aspect of the core user goal addressed (catches scope-loss), and grade consistency (a `C:S` idea that ballooned into a 6-feature PRD is a finding). The direct antidote to machine-drafting risk. PRDs without an intake ancestor (legacy, pre-v2) skip this check with a note.
- **Criteria testability (hardened, agent-readability dimension):** every acceptance criterion must be *assertable* — a regression test or consistency check must be mechanically derivable from it. A criterion that cannot become a test is a **Major** finding, because the D9 eng subagent will otherwise author a vacuous test from it.

### G2. Autonomy alignment + severity policy (D15)

The tune-type ask, fix-selection multiSelect, and step-4 human gate are all deleted. The v2 run:

1. Auto-select tune type (existing auto-suggest logic becomes the decision, not a suggestion).
2. Run the audit; write findings to the PRD ledger as today.
3. **Auto-fix every Critical and Major.** Then emit a compact terminal table — one row per finding, 1–2 lines: `# | Sev | Found | Fixed`. The user always *sees* what the machine changed, without being gated on it.
4. **Ask once about Minors:** "N minor findings — fix them too?" (fix / leave logged as `Open`).
5. **Product-decision pause (only hard gate):** a finding whose fix requires choosing between product behaviors (e.g. two acceptance criteria contradict — either resolution changes the product) is never auto-fixed; batch back via AskUserQuestion, same shape as plan-pm's open-questions pause.

### G3. Eng tune — D12 + breaking-change labeling

D12's two checks (ticket-size feasibility vs commit caps, platform-profile bucket coverage) plus a third: **unlabeled breaking-surface hunt**. Three v2 mechanisms key off breaking changes being *marked* in the PRD — the 300-LOC commit cap, pre-merge's breaking-change pause, plan-pm's own critical pause. An unlabeled breaking change silently disarms all three, so the eng tune actively hunts for breaking surface (API contract changes, schema migrations touching existing columns, behavior changes on shipped features) that the PRD fails to label. Unlabeled = **Critical**.

### G4. Chaining

Recommend-only, unchanged (plan-pm's termination recommends `plan-tune --product`; never invokes). The roadmap orchestrator remains the one auto-chaining path.

### G5. Self-healing loop (D16)

**Critical/Major findings in a freshly drafted PRD are a defect signal in the drafting layer, not business as usual.** The loop:

- Every auto-fixed Critical/Major appends a compact learning to `devkit/AHA.md` — category-tagged, e.g. `[tune:error-cases] PRDs keep omitting timezone-boundary error cases — draft them for any date-touching feature.`
- **The loop closes with zero new plumbing:** plan-pm already reads `devkit/AHA.md` in pre-flight, so the next autonomous draft avoids the pattern. intake reads it too for grading calibration.
- **Recurrence escalation:** the same category appearing across **≥3 runs** means the learnings aren't landing — plan-tune stops treating it as a PRD problem and emits a protocol-repair flag: "this finding category recurs; the drafting protocol/template needs the fix, not individual PRDs" — pointing at the plan-pm ref or intake rubric to amend (an improve-plan candidate).
- Success metric, benchmarkable: **Critical+Major count per fresh PRD should trend toward zero** across consecutive V2-D-era runs. A flat or rising trend = the self-heal is broken; investigate.

**Phasing:** G3 lands in V2-A alongside D12 (it's eng-tune-side and independent of intake). G1/G2/G5 land in **V2-D** with the autonomy era they serve.

## Part H — GUI v2 (`/msg --gui`)

The board must reflect the v2 world or it becomes actively misleading (showing "done" for un-staged work, reading ticket files that no longer exist). Consolidates every GUI change implied by Parts B/C/F/G:

### H1. Completion ladder v2

The most-authoritative-first inference ladder gains the ship states:

```
frontmatter completion: override
  → PR staging→main MERGED            = production (shipped)
  → staging-signoff: stamp present    = staged · human-approved
  → PR feature→staging MERGED         = staged
  → PR feature→staging OPEN           = gated (pre-merge passed)
  → branch feat/prd-<n>-* exists      = in build
  → status: eng                       = planned
  → else                              = product
```

Board columns/pills updated to match — a PRD card can now visibly sit in `gated`, `staged`, or `shipped`.

### H2. Intake tab (F2)

Backlog board over root `INTAKE.md`: one card per row, grade chips rendered from the rubric cell (`C:L` / `T:$$` / `S:next` as three small pills), status lanes backlog / in-progress / completed, each card cross-linking to its mapped PRD. Status hand-edits allowed (D14) — same trust level as board PRD edits.

### H3. Gate Issues tab (was Test Issues)

Reads `msg-gate/gate-*.json` (the B1 rename of `msg-test/test-*.json`); card layout unchanged, source-badge per issue now shows the originating gate step (mechanical / unit-int / regression / platform bucket / security). The `suggested_command` deep-link updates to `eng --build gate-json=`.

### H4. Reports tab additions

Post-merge reports join the per-PRD grouping (`skill: post-merge` frontmatter): staging reports carry the human test script; production reports render release-style (PRDs shipped, rollback notes, the iOS `IRREVERSIBLE` flag surfaced prominently).

### H5. Write scope (deliberate carve-out)

GUI writes were confined to `features/prd-*/` markdown. v2 adds exactly one path: **INTAKE.md status/mapping cells** (H2). Everything else stays read-only — the GUI still never writes gate tickets, reports, roadmap, or devkit files.

**Phasing:** H3 lands in V2-B (with the ticket rename), H1 + H4 in V2-C (they render post-merge states), H2 + H5 in V2-D (with intake). Each phase's GUI delta ships inside that phase — the board is never ahead of or behind the harness it renders.

## Token & speed accounting (net per coding run)

| Change | Direction | Mechanism |
|--------|-----------|-----------|
| A1 merge plan+todo | **−−** | one dispatch wave + one PRD re-read per platform eliminated |
| A2 build tests unit+int only | **−−−** | heavy buckets exit the fix-iteration loop entirely |
| B1 kill /review fan-out | **−−−** | 5–7 cook subagents + compiles → 2 surviving stages |
| B1 kill /test as a stage | **−−** | one full skill invocation + its gate/aggregation overhead removed |
| A5 small commits | **−** | smaller diffs everywhere downstream (pair review, pre-merge, PR) |
| A4 comments | **−** (compounding) | future agents orient from comments, not bodies |
| F3 plan-pm autonomy | **−** | interview turns + per-section gates collapse to two pause types (open questions, safety) |
| G2 plan-tune autonomy | **−** | three interactive gates collapse to one Minor ask + rare product-decision pause |
| G5 self-healing | **−** (compounding) | Critical/Major count per fresh PRD trends to zero → fewer tune-fix cycles over time |
| F1 intake interview | **+** (once per idea) | interview runs once at capture and is reused at planning; grading is cheap (single-turn rubric) |
| A3 pair-programmer | **+** (bounded) | 1 diff-scoped subagent per ticket, capped input, no cook call |
| B2 regression authoring | **+** (once per PRD) | one eng subagent (D9) writes tests once; suite reruns are runner cost, not LLM cost |
| Net | **expected −40%+ vs v1 comprehensive** | to be proven via `evals/bench.py` before/after |

## Migration plan (D8 — phased, benchmarked, working harness at every step)

**Phase V2-A — Eng rebuild.** A1–A5 + the plan-em fallout (prefs deletion, dispatch simplification) + the Part E removal manifest + the D12 narrow plan-tune update (dimension 5 gains ticket-size feasibility and platform-profile coverage checks, nothing else). v1 review/test/pre-merge still run unchanged behind it, so the pipeline stays whole. Exit gate: `evals/bench.py` before/after — expect the A1 wave-elimination + A2 loop-shrink savings to land here; A3's pair-programmer cost must be visibly bounded per ticket.

**Phase V2-B — Pre-merge consolidation.** B1–B4: migrate the test buckets and the two surviving review stages into pre-merge, wire the gate sequence, platform profiles, gate-ticket rename, then DELETE `/review` and `/test` + all doc/menu/GUI references (per the skill-removal-scope convention: README, ARCHITECTURE, `/msg` menu, `--help` table, GUI tabs). Exit gate: bench again — this is where the biggest cut should show; plus one live pipeline pass (eng → pre-merge) on a seeded PRD.

**Phase V2-C — Post-merge + branch topology.** C1–C3: new skill, `staging` branch creation, branch-protection bootstrap in `--init`, roadmap-orchestrator rewiring, Safety floor v2 ratified in `shared/refs/flash-floor.md`. Exit gate: end-to-end dry run feature→staging→main on a scratch repo (protection rules verified to actually block a red PR).

**Phase V2-D — Intake + autonomous planning.** F1–F4 + G1/G2/G5: new `intake` skill, `TEMPLATE-INTAKE.md` + `--init` scaffolding, plan-pm interview removal + autonomy rework, plan-tune certification rework (intent fidelity, testability, D15 severity policy, D16 self-healing), GUI Intake tab, D14 lifecycle wiring (post-merge's `completed` stamp lands here if V2-C shipped first, else stubbed). Independent of A–C — sequenced last so the planning front-door changes don't churn while the build/gate layers are moving. Exit gate: one full intake → plan-pm → plan-tune autonomous run producing a certified PRD with zero unresolved Criticals; interview-parity check; the G5 AHA learning verified to appear and be consumed by the next draft.

Each phase lands as its own commit series on `msg-v2`, honoring the A5 commit caps ourselves.

## Open questions

**None — all resolved.** Every question raised during drafting is settled in the Decisions log (D1–D16). D13/D14 were defaulted during Part F drafting and are veto-able. The plan is ready to build, starting with Phase V2-A.
