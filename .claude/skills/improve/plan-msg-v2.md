---
name: msg-v2
status: shipped
shipped: 2026-07-14  # P1–P7 all landed on msg-v2; CHANGELOG is the per-phase ledger
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
      → plan-em               (ONE human gate: roster approval — certification auto-run inline,
                               relationship questions replaced by the certified graph)
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
| D8 | Execution model | **7 phases (P1–P7), one commit each, AC-gated.** A Fable session orchestrates (dispatch, AC verification, commit); Opus subagents execute the edits. No phase commits until its full acceptance checklist is green; harness stays working at every step. *(Amended from the original A→B→C grouping — mapping in § Execution phases.)* |
| D9 | Pre-merge write powers | **Split.** Pre-merge itself performs only the mechanical sync-merge commit (D7-bounded — one correct answer or pause). Regression tests are **authored by a spawned eng subagent** from the PRD + tickets; pre-merge runs and grades them. Write power stays with the gate only where the write is mechanical; judgment writes are delegated so the gate remains adversarial to what it grades. |
| D10 | Preview kind | **Per-platform** `preview_kind: url \| artifact \| screenshots` in `devkit/PLATFORMS.md`. Web=`url`, iOS/macOS/Android=`artifact` (TestFlight/simulator/.apk build), `screenshots` as an explicit opt-down only. The strictest platforms pay the human round-trip they deserve. |
| D11 | Staging sign-off record | **Hybrid.** post-merge stamps `staging-signoff: <date>` into PRD frontmatter after an explicit approval question (harness/GUI-readable), AND branch protection requires the human's GitHub approval on the staging→main PR (machine-enforced). Belt and suspenders. |
| D12 | plan-tune --eng additions | **Narrow: exactly two checks** — ticket-size feasibility vs the A5 commit caps, and platform-profile bucket coverage. Absorbed into the G1 checklist (checks 5–6); lands in **P7** with the rest of the certifier. |
| D13 | INTAKE.md location & ownership | **Repo root.** Scaffolded by `/msg --init` from `TEMPLATE-INTAKE.md`; row content written by `intake`, PRD-mapping + status stamps written by `plan-pm`/`post-merge`. Not in `devkit/` — devkit files are read-only after init, INTAKE.md is a living ledger. *(Default chosen while drafting — veto-able.)* |
| D14 | Intake status lifecycle owner | `backlog` (intake, on capture) → `in-progress` (plan-pm, when the PRD is created and mapped) → `completed` (post-merge `--production`, when the mapped PRD ships). Manual edits via GUI allowed. *(Default chosen while drafting — veto-able.)* |
| D15 | plan-tune severity policy | **Auto-fix Critical + Major**; emit a compact terminal table (1–2 lines per finding: what was found → what was fixed), then ask whether to fix Minors. The step-4 human gate and the fix-selection multiSelect are deleted; the only remaining pause types are the Minor ask and product-decision findings. Severity source: the G1 checklist's per-check severities. |
| D16 | plan-tune self-healing loop | Critical/Major findings are a **drafting-quality signal, not routine**. Each auto-fixed Critical/Major logs a compact learning to `devkit/AHA.md` (which plan-pm already reads pre-draft — the loop closes with zero new plumbing). Same finding category recurring across ≥3 runs → plan-tune flags that the drafting protocol itself needs repair, not the PRDs. |
| D17 | plan-tune scope | **Contract certifier, not adversarial reviewer.** The v1 "assume broken, audit everything" posture is retired; plan-tune runs a fixed six-check certification (G1), each check tied to a named downstream consumer. Governing rule: **no check without a consumer.** Prose-quality/completeness/consistency sweeps are cut — product judgment belongs to the human touchpoints (intake, preview, staging). |
| D18 | plan-em certification preconditions | **Auto-run, no ask — both sides.** plan-em runs the matching certifier inline before each dispatch wave: `plan-tune --product` before the **plan** wave (missing `product-tuned: yes` or unresolved Criticals), `plan-tune --eng` before the **build** wave (missing `eng-tuned: yes` or unresolved Criticals). Certification is a precondition, not a choice; the only stop is the certifier's own product-decision pause. Without the eng half, checks 4/5/7 would be advisory — an unenforced gate decays into documentation. |
| D19 | plan-em human gates | **Roster approval is the single human gate.** It's a spend + scope decision (how many parallel agents, which platforms), one cheap question, and the natural "write eng sections" confirmation. Every other v1 pause (tune ask, relationship questions, Critical-findings gate) is deleted or absorbed into batched pauses. |

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

- **From `/test` (deleted):** all 10 bucket refs (`refs/modes/*.md`), `test-tooling-detect.sh` consumption, the aggregate-verdict script, the `--flaky`/`--changed-only` mechanics, the `msg-test/test-<n>.json` fail-ticket loop (renamed to the issues file `report-prd-<n>-<k>.json`; `eng --build test-json=` becomes `report=`).
- **From `/review` (deleted):** the Security stage (secret scan + SAST via `/cook --security --auth`), the Migration stage (static SQL-safety scan + semantic pass when a DB flag assembles), and the diff-resolution/fingerprint/verify-prelude machinery (pre-merge becomes the prelude's producer AND consumer). Quality/Coverage/Functional/Performance modes are **not** carried over (D2).
- The canonical finding schema, report-prd-`<n>`-`<k>`.md writing, and run-dir JSON outputs stay exactly as-is — consumers (GUI, eng `report=` builds) see the same shapes.

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

Any red step short-circuits per severity rules; the fail-ticket (the issues file `report-prd-<n>-<k>.json`) feeds `eng --build report=` exactly like the v1 test-ticket loop.

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
| `plan-em` | Full v2 rework — one human gate (roster), inline certification, silent graph consumption. **See Part I.** |
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
- **Phasing:** manifest + the six entries above land in **P3** (independent of the consolidation). **P4 appends** `skills/review`, `skills/test`, and their orphaned scripts (e.g. `test-aggregate-verdict.sh`) once the pre-merge consolidation deletes them from the repo — so existing installs get cleaned on their next update.

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

## Part G — plan-tune v2: contract certifier, not adversarial reviewer

**The v1 adversarial posture ("assume the PRD is broken, audit everything") is retired.** It fit v1, where the PRD was a human-communication document. In v2 the PRD is a **machine contract**: specific fields are executed against by specific consumers — regression authoring (D9), pre-merge's PRD-consistency gate, the safety pauses, `eng --build`'s row/ticket reads. "Wrong product, correctly built" is caught by the human touchpoints that remain (intake interview, preview gate, staging test) — plan-tune's job is protecting the contracts machines execute blindly.

**The governing rule — no check without a consumer:** plan-tune checks a property *if and only if* a named downstream mechanism consumes it. Any future check proposal must name its consumer or it doesn't get added. This is what stops tune from re-bloating.

### G1. The certification checklist (replaces all five v1 dimensions)

| # | Check | Tune | Consumer | Unchecked failure mode |
|---|-------|------|----------|------------------------|
| 1 | **Criteria testability** — every acceptance criterion mechanically derivable into an assertion | product | D9 regression authoring; pre-merge PRD-consistency (step 7) | vague criterion → vacuous regression test guards production forever (**Major**) |
| 2 | **Breaking/DB surface labeled** | product + eng | 300-LOC cap; pre-merge breaking pause; plan-pm critical pause; `eng-db-touch.sh` | all safety pauses silently disarmed (**Critical**) |
| 3 | **Intent fidelity vs intake row** — features traceable to idea/goal; goal fully addressed; grade consistency | product | the pipeline's purpose (only check on autonomous drift) | plan-pm builds the wrong thing *fluently*; no-intake-ancestor PRDs skip with a note |
| 4 | **Exec-table / eng-section integrity** — F-ID coverage, exact identifiers, Files column populated | eng | `eng --build` mechanical reads; `plan-em-exec-collision.py` | agents block mid-build or guess; parallel builds collide |
| 5 | **Ticket sizing + graph validity** — sizes vs commit caps (D12); `depends-on` acyclic, every referenced id exists, every ticket has `done-when` | eng | A5 commit gate; `eng --build` ordering logic (which hard-stops on cycles/unknown ids) | unbuildable tickets and build-time hard-stops discovered at build time, not plan time |
| 6 | **Frontmatter graph** — `depends_on`/`affects` correctness (+ platform-profile bucket coverage, D12) | product + eng | roadmap sequencing; plan-em preflight; pre-merge bucket selection | wrong build order; missed cross-PRD breakage; wrong gate strictness |
| 7 | **Cross-agent integration-contract coherence** — every identifier declared in one agent's integration contract resolves against every other agent's section/tickets that reference it | eng | parallel `eng --build` agents (row-scoped — they build against each other's contracts blindly, and structurally cannot see across sections) | two internally-consistent, mutually-wrong sections; mismatch surfaces at pre-merge integration tests — the most expensive place (**Critical**) |

**Explicitly cut (no consumer):** blanket completeness sweeps (template + a structural grep cover it), prose quality of narrative sections (user flows/background — eng's Step 6 scope enforcement already blocks-and-asks on unresolvable rows), whole-document consistency sweeps (the valuable subset is checks 1/4), glossary cross-checks (demoted to Minor at most). Certification runs on **digest slices** — one short pass, not five dimension sweeps.

**Known trade (accepted):** contradictions that never touch an executable field are no longer caught here — they're caught by the human at intake or staging. Contract violations produce concrete AHA learnings ("PRDs keep leaving breaking changes unlabeled"), which is exactly what makes G5 self-healing actionable.

### G2. Autonomy alignment + severity policy (D15)

The tune-type ask, fix-selection multiSelect, and step-4 human gate are all deleted. The v2 run:

1. Auto-select tune type (existing auto-suggest logic becomes the decision, not a suggestion).
2. Run the six-check certification; write findings to the PRD ledger as today.
3. **Auto-fix every Critical and Major.** Then emit a compact terminal table — one row per finding, 1–2 lines: `# | Sev | Found | Fixed`. The user always *sees* what the machine changed, without being gated on it.
4. **Ask once about Minors:** "N minor findings — fix them too?" (fix / leave logged as `Open`).
5. **Product-decision pause (only hard gate):** a finding whose fix requires choosing between product behaviors (e.g. two acceptance criteria contradict — either resolution changes the product) is never auto-fixed; batch back via AskUserQuestion, same shape as plan-pm's open-questions pause.

### G4. Chaining

Recommend-only, unchanged (plan-pm's termination recommends `plan-tune --product`; never invokes). The roadmap orchestrator remains the one auto-chaining path.

### G5. Self-healing loop (D16)

**Critical/Major findings in a freshly drafted PRD are a defect signal in the drafting layer, not business as usual.** The loop:

- Every auto-fixed Critical/Major appends a compact learning to `devkit/AHA.md` — category-tagged, e.g. `[tune:error-cases] PRDs keep omitting timezone-boundary error cases — draft them for any date-touching feature.`
- **The loop closes with zero new plumbing:** plan-pm already reads `devkit/AHA.md` in pre-flight, so the next autonomous draft avoids the pattern. intake reads it too for grading calibration.
- **Recurrence escalation:** the same category appearing across **≥3 runs** means the learnings aren't landing — plan-tune stops treating it as a PRD problem and emits a protocol-repair flag: "this finding category recurs; the drafting protocol/template needs the fix, not individual PRDs" — pointing at the plan-pm ref or intake rubric to amend (an improve-plan candidate).
- Success metric, benchmarkable: **Critical+Major count per fresh PRD should trend toward zero** across consecutive post-P7 runs. A flat or rising trend = the self-heal is broken; investigate.

**Phasing:** G1's eng-side checks (4–7) land in **P7** with the rest of the certifier (plan-tune stays v1 until then; D12's narrow additions ride P7 too). The product-side checks (1–3), G2's autonomy, and G5 also land in **P7** — one coherent certifier commit.

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

Reads the issues files `report-prd-*-*.json` under each `features/prd-*/reports/` dir (the B1 rename of `msg-test/test-*.json`); card layout unchanged, source-badge per issue now shows the originating gate step (mechanical / unit-int / regression / platform bucket / security). The `suggested_command` deep-link updates to `eng --build report=`.

### H4. Reports tab additions

Post-merge reports join the per-PRD grouping (`skill: post-merge` frontmatter): staging reports carry the human test script; production reports render release-style (PRDs shipped, rollback notes, the iOS `IRREVERSIBLE` flag surfaced prominently).

### H5. Write scope (deliberate carve-out)

GUI writes were confined to `features/prd-*/` markdown. v2 adds exactly one path: **INTAKE.md status/mapping cells** (H2). Everything else stays read-only — the GUI still never writes gate tickets, reports, roadmap, or devkit files.

**Phasing:** H3 lands in P4 (with the ticket rename), H1 + H4 in P5 (they render post-merge states), H2 + H5 in P6 (with intake). Each phase's GUI delta ships inside that phase — the board is never ahead of or behind the harness it renders.

## Part I — plan-em v2: one gate, certified inputs

plan-em drops from ~4 interactive pauses to **1** (roster). Its v1 steps against the v2 world:

### I1. Step 0 deleted; dispatch simplified (rides A1)

The todos-pref resolution (`prefs.json` + bootstrap scan) is gone. Step 4's mode table shrinks to two modes: `plan` (section + tickets in one wave) and `build`. The `todo` dispatch wave no longer exists.

### I2. Certification preconditions — both waves (D18)

The interactive tune gate is replaced by mechanical checks, one per dispatch wave:

- **Before the plan wave:** `product-tuned: yes` + zero unresolved Criticals. Uncertified → run `plan-tune --product` inline, proceed on green.
- **Before the build wave:** `eng-tuned: yes` + zero unresolved Criticals. Uncertified → run `plan-tune --eng` inline (the six-check eng side: 2, 4, 5, 6, 7), proceed on green. This closes the v1 hole where synth merely *recommended* the eng tune — the build wave can no longer start on an uncertified eng plan.

No asks in either direction — the certifier is autonomous and cheap; its own product-decision pause is the only stop.

### I3. Step 1 — consume the certified graph, ask only on conflict

The per-relationship AskUserQuestions (Dependency / Breaking / Overlap) are deleted. By the time plan-em runs, intake graded sequencing (`S:blocked-by-#n`) and the certifier verified the frontmatter graph (G1 check 6) — plan-em consumes both silently. It asks **only on a genuine conflict**: the certified graph contradicts what its codebase scan implies (e.g. `depends_on` names a PRD whose surface the diff plainly doesn't touch, or an undeclared overlap is detected). Expected: zero relationship questions on a clean run. `preflight.md` still written (cheap, GUI-readable).

### I4. Step 3 — roster approval, the single human gate (D19)

Unchanged mechanically (cook compile-once, scoped flags, exec-table skeleton — all v2-shaped from the token-cut waves). Elevated in status: this is plan-em's **only** human gate — a spend + scope decision (parallel-agent count, platform set) that doubles as the "write eng sections" confirmation. The Todos column is always present (A1).

### I5. Steps 4–5 — dispatch + synth cleanup

- The end-of-plan `/test --prd` eval-set preview dies with `/test` (pre-merge owns eval derivation).
- Synth's next-step menu becomes the v2 chain: proceed to `eng --build` (the eng certification is no longer a menu item — I2 auto-runs it as the build-wave precondition). The "run todo breakdown" option is deleted.
- Critical synth findings stop being a blocking gate — batched back via AskUserQuestion, same pause shape as everywhere else in v2.
- Mode forwarding, injected standards payloads, and build-mode branch resolution are unchanged.

**Phasing:** I1 + the synth todo-option deletion ride **P1** (A1 fallout). I5's `/test` call removal rides **P4** (test deletion). I2 + I3 ride **P7** (they depend on the certifier's autonomy and intake's grades).

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
| I plan-em rework | **−** | ~4 pauses → 1 (roster); relationship questions pre-answered by certified graph |
| G5 self-healing | **−** (compounding) | Critical/Major count per fresh PRD trends to zero → fewer tune-fix cycles over time |
| F1 intake interview | **+** (once per idea) | interview runs once at capture and is reused at planning; grading is cheap (single-turn rubric) |
| A3 pair-programmer | **+** (bounded) | 1 diff-scoped subagent per ticket, capped input, no cook call |
| B2 regression authoring | **+** (once per PRD) | one eng subagent (D9) writes tests once; suite reruns are runner cost, not LLM cost |
| Net | **expected −40%+ vs v1 comprehensive** | to be proven via `evals/bench.py` before/after |

## Execution phases (D8 — 7 phases, 1 commit each, AC-gated)

**Execution model:** a **Fable** session orchestrates — reads this plan, dispatches work, verifies acceptance criteria, commits. **Opus subagents execute** each phase's edits. Every phase lands as **exactly one commit** on `msg-v2`, and a phase may not commit until **every acceptance criterion is checked green** — a failed AC is fixed within the phase, never deferred. `evals/bench.py` runs where an AC names it.

*(Supersedes the V2-A…D grouping. Mapping for part-level phasing notes: V2-A → P1–P3 · V2-B → P4 · V2-C → P5 · V2-D → P6–P7.)*

### P1 — Eng core: one plan wave, lean build loop *(A1, A2, I1)*
**Objective:** merge plan+tickets into a single dispatch wave; shrink the build loop to unit+integration.
- [ ] `eng --plan` writes `## Engineering — <Agent>` + `## Todos — <Agent>` in a single pass; `--todo` invocation hard-fails with a pointer to `--plan`
- [ ] plan-em: Step 0 + `prefs.json` + bootstrap ref deleted; dispatch modes = `plan` | `build` only; exec table always carries the Todos column
- [ ] Tickets sized at plan time to fit commit caps (rule present in the plan protocol)
- [ ] `eng --build` TDD loop + full-suite gate run unit+integration only
- [ ] v1 review/test/pre-merge still pass one smoke pipeline run (harness whole)
- [ ] `bench.py`: planning-phase tokens drop vs baseline (wave elimination visible)

### P2 — Build discipline *(A3, A4, A5)*
**Objective:** per-ticket pair review, plain-English comments, small commits.
- [ ] Pair-programmer spawns per completed ticket: platform-parameterised principal-engineer persona, unnecessary-code mandate only, blocking with exactly one revision round, unresolved findings ledger-logged
- [ ] Pair contract: diff + `done-when` + parent's standards payload; no cook call; cost visibly bounded per ticket
- [ ] Comment convention in the build protocol; mechanical grep flags uncommented new/modified symbols
- [ ] `eng-commit-cap.sh` blocks >500 LOC (>300 breaking); `Oversize-reason:` trailer escape hatch, logged to the PRD ledger

### P3 — Install layer: removal manifest *(Part E)*
**Objective:** retiring a skill becomes a data change; improve/ never ships.
- [ ] `remove-manifest.txt` ships 9 entries (msg-init, docu, handoff, ship, plan, design, improve + 2 ship scripts)
- [ ] install.sh: exact-match only; rejects globs/`..`/absolute/outside `skills/`+`scripts/`; install-conflict skip with warning; absent target = silent idempotent skip
- [ ] `improve/` excluded from the copy loop
- [ ] Dry-run against a scratch `$HOME`: all retired items removed; `plan-em`/`plan-pm`/`plan-tune` untouched

### P4 — Pre-merge: the CI gate *(Part B, H3, I5-partial)*
**Objective:** one gate from "eng done" to "PR open against staging"; /review and /test die.
- [ ] Gate sequence 0–9 implemented; bucket set + severity thresholds resolved from `devkit/PLATFORMS.md` (strict / standard / lenient)
- [ ] `/msg --init` writes `PLATFORMS.md` (+1 interview question, `preview_kind` column)
- [ ] Regression: spawned eng subagent authors to `tests/regression/prd-<n>/` (D9); edits to prior tests emit PRD-clause-cited findings (D5)
- [ ] Sync step: trivial conflicts auto-resolved, semantic conflicts pause; unit+int re-run post-sync (D7)
- [ ] Fail-ticket loop: the issues file `report-prd-<n>-<k>.json` → `eng --build report=` works end-to-end
- [ ] Preview gate fires on the D6 path heuristic, presents the profile's `preview_kind`, blocks on approval
- [ ] Opens PR feature→staging with verdict JSON + report linked
- [ ] `/review` + `/test` deleted; README / ARCHITECTURE / `/msg` menu / `--help` / GUI references scrubbed; manifest += `review`, `test` + orphaned scripts
- [ ] GUI Gate Issues tab reads the issues files under `features/prd-*/reports/` with per-step source badges (H3)
- [ ] `bench.py`: largest single cut lands; one live eng → pre-merge run on a seeded PRD is clean

### P5 — Ship layer: staging → main *(Part C, H1, H4)*
**Objective:** post-merge exists; nothing reaches main except staging via double-confirmed PR.
- [ ] `--staging`: green-CI check → merge → deploy (per platform pipeline) → emit human test script → stamp `staging-signoff:` on explicit approval (D11)
- [ ] `--production`: refuses without the stamp; double-confirmation; PRs staging→main release-style; merges only on green CI + required human review
- [ ] Branch-protection bootstrap via `gh api` (offered by `--init`, re-verified by post-merge); **verified to block a red PR on a scratch repo**
- [ ] `shared/refs/flash-floor.md` rewritten to Safety floor v2; roadmap orchestrator rewired (chain ends at `--staging`; `--production` always human-initiated)
- [ ] GUI ladder renders gated / staged / shipped (H1); post-merge reports render, iOS `IRREVERSIBLE` surfaced (H4)

### P6 — Intake + autonomous plan-pm *(Part F, H2, H5)*
**Objective:** ideas enter through a graded ledger; plan-pm drafts solo.
- [ ] `/intake` captures rows (`# | date | type | idea | goal | grade | status | prd`); C/T/S rubric is a single-turn banded judgment (no fake precision — enforced in `TEMPLATE-INTAKE.md`); XL triggers the split question; hybrid asks split into discrete rows
- [ ] `TEMPLATE-INTAKE.md` added; `/msg --init` scaffolds `INTAKE.md` idempotently
- [ ] plan-pm: interview + epic gate deleted; no-args lists non-completed ideas; drafts the full PRD solo; pauses only for batched open questions + breaking/critical touches; terminates with the follow-up ask
- [ ] Interview parity: everything the old 5-question interview captured is either in the intake row or autonomously drafted
- [ ] Lifecycle stamps wired: `backlog` → `in-progress` (plan-pm); `completed` (post-merge, live from P5)
- [ ] GUI Intake tab with grade chips (H2); INTAKE.md status cells are the only new write path (H5)

### P7 — Certification layer *(Part G, I2, I3)* — ✅ shipped 2026-07-14
**Objective:** plan-tune is the seven-check contract certifier; plan-em enforces it on both waves.
- [x] plan-tune runs the 7-check certification on digest slices; adversarial dimensions removed; "no check without a consumer" rule documented in the skill itself — SKILL.md + `refs/certification.md`; `tune-product.md`/`tune-eng.md` deleted
- [x] D15: Critical+Major auto-fixed; `# | Sev | Found | Fixed` terminal table emitted; single Minor ask; product-decision pause is the only hard gate — Step 3/3 (4-step → 3-step flow; tune-type ask + fix multiSelect + step-4 gate deleted)
- [x] D16: each auto-fix writes a category-tagged AHA learning; ≥3-run recurrence emits the protocol-repair flag — Step 3/3 self-healing block. **Consumption wired** (not live-verified): plan-pm's pre-run already reads `devkit/AHA.md` and applies `[tune:*]` learnings (SKILL.md line 55); intake reads it for grading calibration
- [x] plan-em: matching certifier auto-runs inline before each wave (product → plan wave Step 2, eng → build wave Step 4, D18); relationship questions replaced by certified-graph consumption — zero questions on a clean run (I3, Step 1c); synth eng-tune menu option deleted (I5)
- [ ] Full autonomous dry run: intake → plan-pm → certify → plan-em → build → pre-merge on a scratch PRD, zero unresolved Criticals — **residual** (needs a live multi-session LLM pipeline; `bench.py` is a token model, not an executor). Mechanically verified: seeded PRDs carry all certifier inputs + precondition stamps → clean-run path coherent (see `evals/token-baseline.md` P7 residual note)
- [x] `bench.py` final: net cut vs v1 comprehensive ≥ 40% — **−56.9%** (380,704 → 163,904); P7 cut ~14.2k on top of P6

## Open questions

**None — all resolved.** Every question raised during drafting is settled in the Decisions log (D1–D16). D13/D14 were defaulted during Part F drafting and are veto-able. The plan is ready to build, starting with P1.
