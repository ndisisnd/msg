# Changelog

## 2026-07-16

### [5] — Document the `--doctor` mode and `policy.json` in the project docs

- `ARCHITECTURE.md`: added `doctor-detect-repo.sh` to the scripts table; added `devkit/policy.json` to the devkit layer — the one co-written devkit file (seeded by `--init`, completed by `--doctor`, flipped by `--init-staging`) — with its init-gated pipeline behavior; noted `--doctor`/`--init-staging` on the skill surface
- `README.md`: the `/pre-merge` and `/post-merge` rows now describe `--doctor`; new `/msg --init-staging` row; `/msg --init` notes the release-flow interview + `policy.json` seed; post-merge branch protection flagged policy-conditional (enforced/optional/skip)

### [4] — One-time `--doctor` setup for the gates: detect tooling, record release + protection policy

- `.claude/skills/shared/refs/policy-schema.md`: new — canonical `devkit/policy.json` schema, fail-safe validation rules, and the gate read-contract (init lifecycle, release_flow, branch_protection, per-step decisions) both gates consult
- `.claude/skills/pre-merge/refs/protocol-doctor.md`: new — `/pre-merge --doctor` spec: detector-null→gap mapping, the three-flavor gap taxonomy, the OSS-first (free-only) install catalog, gated interview, and stub scaffolding
- `.claude/skills/post-merge/refs/protocol-doctor.md`: new — `/post-merge --doctor` spec: branch-topology + branch-protection (Free-plan-403 auto-detect) + deploy/smoke CLI detection, PLATFORMS.md gaps delegated to `/msg --init`
- `.claude/scripts/doctor-detect-repo.sh`: new — read-only probe of repo visibility, branch-protection availability, and staging/prod topology → JSON for the doctor to consume
- `.claude/skills/pre-merge/refs/stubs/`: new — minimal runnable config templates (eslint, biome, prettier, ruff, vitest, playwright, size-limit) the doctor scaffolds for config-missing tools
- `.claude/skills/pre-merge/SKILL.md`: `--doctor` usage, an `init` pre-flight that auto-runs the doctor until setup completes, `release_flow`-based PR base, and a Steps 2/3/5/6 policy consult — an absent `policy.json` keeps today's behavior
- `.claude/skills/post-merge/SKILL.md`: `--doctor` usage, the `init` pre-flight, policy-conditional branch protection (enforced/optional/skip), and release-flow handling incl. the direct-mode single ship
- `.claude/skills/post-merge/refs/protection.md`: branch-protection precondition is now policy-conditional — only `enforced` refuses on unprotected; `optional` warns and proceeds, `skip` skips
- `.claude/skills/post-merge/refs/refusal-patterns.md`: `unprotected` refusal made conditional; new `no_staging_stage` refusal for direct-mode `--staging`
- `.claude/skills/msg/SKILL.md`: `--init` now captures the release flow and seeds `policy.json`; new `--init-staging` mode adds a staging branch and flips the flow to staged
- `.claude/skills/msg/refs/protocol-init.md`: the `--init` interview gains the release-flow call and the idempotent `policy.json` seed write

### [3] — Add the failure→fix→re-gate loop and unify run reports into one artifact per run

- `.claude/skills/shared/refs/fix-loop.md`: new — after a failed pre-merge/post-merge run, a two-offer sequence walks the user from "issues found" to "fixes planned + built": Offer #1 runs `eng --plan report=` (writes a fix plan), Offer #2 runs the orchestrated `eng --build report=`. Autonomy-aware (both offers pre-approved under a roadmap orchestrator)
- `.claude/skills/eng/refs/plan/report-fix.md`: new — the `eng --plan report=` source; projects the issues file's findings into a fix plan (exec-table + fix tickets), one ticket per issue, each tagged `complexity: simple|complex`
- `.claude/skills/eng/refs/build/report-fix-orchestrated.md`: new — the default `eng --build report=` route; an Opus orchestrator grades each issue's complexity and fans the fixes out to per-issue subagents (`model: sonnet` simple / `model: opus` complex), one commit per issue, re-verifies each ticket, then writes `followUp.status`
- `.claude/skills/eng/refs/build/report-fix.md`: renamed from `protocol-build-gatejson.md`; routes the fix build to the orchestrated ref by default (`orchestrate=off` escape hatch to the flat flow)
- `.claude/skills/eng/SKILL.md`, `refs/build/protocol.md`, `refs/build/protocol-roadmap.md`, `refs/plan/template-todo.md`: the eng fix flag `gate-json=` is now `report=`; `--plan report=` is now accepted (was a hard failure)
- `.claude/skills/pre-merge/SKILL.md`, `.claude/skills/post-merge/SKILL.md`: on a failed run write the colocated machine issues file and hand off to `fix-loop.md`; post-merge now enters the loop on a deploy/smoke failure (both modes) instead of dead-ending; terminal issue-count block printed on every report write
- `.claude/skills/shared/refs/report-schema.md`: unified run report — the three forms of a run share one stem in `features/prd-<N>-<slug>/reports/`: `report-prd-<N>-<K>.md` (human), `report-prd-<N>-<K>.json` (machine issues, on failure), `report-prd-<N>-<K>-fix-plan.md`; per-PRD `K` numbering; new `## Issue summary` body section
- `.claude/skills/shared/refs/finding-schema.md`, `.claude/skills/pre-merge/refs/output-schema.md`, `refs/mechanical.md`, `refs/regression.md`, `.claude/skills/post-merge/refs/staging.md`, `refs/production.md`: retired the `msg-gate/gate-<n>.json` / `gate-json` vocabulary in favour of the issues file
- `.claude/skills/msg/refs/gui/server.py`, `index.html`, `.claude/skills/msg/refs/protocol-gui.md`: the GUI reads the issues `.json` from the reports folders (not `msg-gate/`), skips `-fix-plan.md` when collecting reports, and deep-links `report=`
- `.claude/scripts/pre-merge-aggregate-verdict.sh`, `.claude/skills/improve/plan-msg-v2.md`: stale-token cleanup

## 2026-07-14

### [2] — /pre-merge now works in repos with no staging branch instead of refusing

- `.claude/skills/pre-merge/SKILL.md`: staging→main fallback threaded through the constraints, the Inputs/Outputs base row, the Step 1 sync + Step 9 PR-base rows, and the `followUp.suggested_command` PR base — a missing `staging` is no longer a blocker
- `.claude/skills/pre-merge/refs/sync.md`: precondition 2 now resolves the sync target (`staging`, else `main`) instead of refusing; merge command and sync-merge commit message parameterised on the resolved target
- `.claude/skills/pre-merge/refs/refusal-patterns.md`: Removed — deleted the retired `no_staging` refusal section and its outcomes-table row
- `.claude/skills/pre-merge/refs/output-schema.md`: dropped `no_staging` from the refusal `reason` enum

### [1] — Drop the one-time install manifest now that its purge has run

- `remove-manifest.txt`: deleted — the removal list it shipped has already been scrubbed from every global install
- `install.sh`: removed the manifest-driven removal block (parser, guardrails, `rm -rf` loop)
- `ARCHITECTURE.md`: dropped the removal-manifest paragraph from the install-layer description

- **post-merge now verifies its deploys — a smoke check runs after every staging and production deploy.** "The deploy command exited 0" is no longer treated as "the app works": both modes gain a verification step that runs each shipping platform's new `smoke_cmd` (a `devkit/PLATFORMS.md` column — e.g. `curl -f <health url>`) against the **deployed** target. Exit 0 → verified; non-zero → a `high` `smoke-failed` finding and verdict `fail` — in `--staging` (new Step 5) the human test script + sign-off are skipped (never hand a human a script for a broken environment; fix forward via `/pre-merge`), in `--production` (new Step 7) the intake `completed` stamp is skipped (an unverifiably-live release doesn't close its PRD) and the per-platform rollback notes are surfaced prominently. Unconfigured / `[USER: …]` smoke cells skip verification with a visible note — never invented, never a failure — so existing PLATFORMS.md files stay valid. The clean-run summary gains a `verify: { ran, passed, skipped }` block and the run report a per-platform verified/smoke-failed/skipped line; new hard refusal: post-merge never reports a deploy as shipped without running (or explicitly noting the absence of) the smoke check.
  - `.claude/skills/post-merge/refs/verify-deploy.md` — new: the verification contract (resolve, run, finding shape, per-mode consequences, summary block)
  - `.claude/skills/post-merge/refs/staging.md` + `refs/production.md` — verify steps inserted; human-script/sign-off and intake-stamp steps renumbered + gated on a verified deploy
  - `.claude/skills/post-merge/SKILL.md` — mode tables now Steps 1–7 (staging) / 1–8 (production); smoke-check hard refusal; verify-deploy ref listed
  - `.claude/skills/post-merge/refs/output-schema.md`, `refs/deploy.md`, `refs/human-test-script.md` — `verify` block, verdict rules, and step cross-references aligned
  - `.claude/skills/msg/refs/init/templates/template-PLATFORMS.md` — new `smoke_cmd` column (contract row, header, all four platform default rows)
  - `README.md`, `ARCHITECTURE.md` — post-merge descriptions gain the smoke-verify step
  - `.claude/kermit/pref.json`, `.gitignore` — kermit pref/state split migration (volatile state moved to git-ignored `state.json`)

- **Remove flash mode from the msg harness — comprehensive is now the only run mode.** The two-mode system (comprehensive vs flash) is retired: flash traded execution count for speed, and every skill now always runs its full comprehensive protocol. Deleted the shared mode machinery — `shared/refs/mode-resolution.md` (precedence resolver) is gone, and `shared/refs/flash-floor.md` is replaced by mode-neutral `shared/refs/safety-floor.md` (the never-relaxed write-power/human-gate/pause floor, with all flash framing removed). Every per-skill `refs/flash/mode-flash.md` deleted, every `--flash` flag and Step-0 mode-resolution pointer stripped from SKILL.md files and protocols, the `/msg --set-mode` command and flash-only quick paths (`/msg --init --flash`, `/msg --flash`, `/intake --flash`) removed. The safety floor, all human gates, and every pause are preserved unchanged (they were never mode-dependent). Stale `--flash` flags on any skill are silently ignored. Done in phased commits (P1 shared core → P7 root docs); skill-internal ref integrity verified clean before and after.
  - P1 — shared core: `safety-floor.md` replaces `flash-floor.md`; `mode-resolution.md` deleted; three surviving safety-floor references repointed.
  - P2 — deleted the six per-skill `refs/flash/` directories (eng plan+build, plan-tune, plan-em, plan-pm, pre-merge — 7 files).
  - P3 — eng skill: dropped the `--flash` routing rows and the Step-0 mode-resolution sentence from SKILL.md; removed the roadmap "Mode propagation" paragraph; stripped every "skipped in flash" note from pair-review and build protocol.
  - P4 — plan-tune / plan-em / plan-pm: removed `[--flash]` from invoke lines, deleted each Flash-mode paragraph and refs bullet, and dropped plan-em's forwarded-mode dispatch bullet and the protocol-em flash parenthetical.
  - P5 — pre-merge / intake / post-merge: deleted the `/pre-merge --flash` flag and intake's Flash-mode paragraph, collapsed post-merge's "No flash mode — ever" note to a mode-neutral "ship gates never collapse", and dropped the "or flash" clause in pre-merge sync.
  - P6 — msg skill: removed `--set-mode` from the description and the entire `## Protocol: --set-mode` section, deleted the `/msg --flash` and `/msg --set-mode` invoke lines and the default-protocol "Show active mode" step, dropped `--init --flash` / `--flash` mentions, and renumbered the dispatch list.
  - P7 — root docs: retitled the ARCHITECTURE and README "Run modes" sections to "Safety floor" (mode framing removed) and dropped every "no flash mode" note; retired the obsolete root `msg-minor.md` flash-residuals doc. (Local, gitignored `evals/bench.py` also de-flashed so it keeps running; comprehensive footprint 162,962 tok.)

- **msg v2 P7 — certification layer: plan-tune is a 7-check contract certifier; plan-em enforces it on both waves (Part G, I2, I3).** plan-tune is rebuilt from a 5-dimension adversarial auditor into a **contract certifier** (D17): the v1 "assume the PRD is broken, audit everything" posture is retired for a fixed **seven-check certification**, each check bound to a named downstream consumer that executes a PRD field *blindly* — **governing rule: no check without a consumer.** Checks: (1) criteria testability → regression authoring + pre-merge PRD-consistency; (2) breaking/DB surface labeled → the 300-LOC cap, pre-merge breaking pause, plan-pm critical pause, `eng-db-touch.sh`; (3) intent fidelity vs the intake row → the only guard on autonomous plan-pm drift; (4) exec-table/eng-section integrity → `eng --build` reads + `plan-em-exec-collision.py`; (5) ticket sizing + graph validity → the A5 cap + `eng --build` ordering (hard-stops on cycles/unknown ids); (6) frontmatter graph (+ platform-profile bucket coverage, D12) → roadmap sequencing, plan-em preflight, pre-merge bucket selection; (7) cross-agent integration-contract coherence → parallel build agents that build against each other's contracts blindly. Product tune runs 1/2/3/6 on the `product` slice; eng tune runs 2/4/5/6/7 on the `eng-audit` slice **only** (the v1 eng tune's redundant second product-slice read is gone). **Autonomy (D15):** the 4-step flow collapses to 3 — tune-type is auto-selected (no ask), every Critical+Major is auto-fixed and emitted as a `# | Sev | Found | Fixed` terminal table, one Minor ask remains, and a product-decision finding is the only hard pause (the v1 tune-type ask, fix-selection multiSelect, and step-4 human gate are all deleted). **Self-healing (D16):** each auto-fixed Critical/Major appends a `[tune:<category>]` learning to `devkit/AHA.md` — which plan-pm already reads pre-draft and intake reads for grading calibration, closing the loop with zero new plumbing; a category recurring across ≥3 runs emits a protocol-repair flag (fix the drafting protocol, not the PRDs). **plan-em (I2/I3/I5):** the certifier now auto-runs inline as a **precondition** before each wave — `plan-tune --product` before the plan wave (Step 2), `plan-tune --eng` before the build wave (Step 4, D18) — no ask, closing the v1 hole where the eng tune was merely *recommended*; Step 1c's three per-relationship AskUserQuestions are **deleted** (plan-em consumes the intake-graded + certifier-verified graph silently and asks only on a genuine graph-vs-scan conflict — zero relationship questions on a clean run); the synth eng-tune menu option is deleted (I5), and Critical synth findings are batched, not a blocking terminal gate. The §9 findings-table schema is preserved verbatim — the GUI parser and plan-pm's template-prd §9 are untouched. Bench: pipeline **178,141 → 163,904 tok** (P7 cut ~14.2k; the eng tune's dropped second-slice read + `tune-product.md`+`tune-eng.md` → one `certification.md`); **cumulative vs the original v1 baseline: −56.9%** (380,704 → 163,904), clearing the ≥40% gate. *Residual: the full live intake→…→pre-merge autonomous dry run needs a multi-session LLM pipeline (bench.py is a token model, not an executor) — mechanically verified instead via the seeded PRDs' certifier inputs + precondition stamps (clean-run path coherent).*

- `.claude/skills/plan-tune/` — SKILL.md rebuilt (certifier persona, 3-step flow, auto-select/auto-fix/self-heal); new `refs/certification.md` (the 7 checks + consumers + severity rubric + §9 schema + terminal table + AHA loop); `refs/tune-product.md` + `refs/tune-eng.md` deleted; `refs/flash/mode-flash.md` re-cut to the critical subset of the 7 checks
- `.claude/skills/plan-em/` — `refs/protocol-em.md` Step 2 = product certification precondition (auto-run, was an ask), Step 4 build branch = eng certification precondition, Step 1c = certified-graph consumption (relationship AUQs deleted), Step 5 eng-tune menu option removed + synth Criticals batched; SKILL.md + `refs/flash/mode-flash.md` aligned (roster is the single gate)
- `.claude/scripts/scan-prd-digest.py` — `eng-audit` slice gains `exec_table` + `todos` (checks 4/5 inputs)
- `README.md`, `ARCHITECTURE.md`, `.claude/skills/msg/SKILL.md`, `.claude/skills/msg/refs/init/templates/template-CLAUDE.md` — plan-tune re-advertised as contract certifier; plan-em's inline certification documented as a deliberate autonomous exception
- `evals/bench.py` — plan-tune stages repointed at `certification.md`, eng tune drops the second product-slice read; `evals/token-baseline.md` — P7 milestone (−56.9% vs v1)
- `.claude/skills/improve/plan-msg-v2.md` + `_INDEX.md` — plan marked shipped (P1–P7 complete)

- **msg v2 P6 — intake layer + autonomous plan-pm (Part F, H2, H5).** New `/intake` skill is the planning front-door: captures feature ideas and bugs as rows in a root `INTAKE.md` ledger (`# | date | type | idea | goal | grade | status | prd`, D13 — repo root, not devkit) and **owns the requirements interview** that used to live in plan-pm (flesh out thin ideas, proactively suggest adjacent ideas, ask for the core goal — batched, ≤2 AskUserQuestion calls for a well-formed idea). Hybrid asks ("streaks + notifications + rewards") split into discrete rows at capture — this replaces plan-pm's epic-split gate. Every idea gets a **single-turn banded grade** (`C: S/M/L/XL` complexity, `T: $/$$/$$$` token cost, `S: now/next/later/blocked-by-#n` sequencing) — never an analysis pass, fake-precise numbers forbidden by the template; an `XL` grade fires the split question (front-door defence of the commit caps). **plan-pm is now an autonomous PRD writer** (F3): the 5-question interview and epic gate are deleted (interview-parity audited — every old capture now comes from the intake row, autonomous drafting, or a batched open question); no-args lists non-completed intake rows; the full PRD (edge cases, features/acceptance, flows, error handling) is drafted solo; it pauses ONLY for batched open questions and breaking/critical touches, then terminates with one follow-up ask, recommending plan-tune --product. Lifecycle stamps wired (D14): intake writes `backlog` → plan-pm stamps `in-progress` + the `prd-<n>` mapping → post-merge --production stamps `completed`. GUI gains the **Intake tab** (H2): lanes backlog/in-progress/completed, three grade chips per card, PRD cross-links; INTAKE.md **status cells are the only new GUI write path** (H5 — the `prd` mapping stays plan-pm-owned, read-only). `/msg --init` scaffolds INTAKE.md from new `TEMPLATE-INTAKE.md`, idempotent. Bench: intake costs 3.7k tok once per idea; plan-pm main drops 11.5k → 10.0k.

- `.claude/skills/intake/` — new: SKILL.md, refs/protocol-intake.md (capture flow), refs/rubric.md (C/T/S bands + single-turn constraint)
- `.claude/skills/msg/refs/init/templates/TEMPLATE-INTAKE.md` — new; init.sh scaffolds root INTAKE.md
- `.claude/skills/plan-pm/` — protocol-pm.md rewritten (5-step autonomous flow), protocol-interview.md deleted, SKILL/flash/sub/roadmap/template refs aligned; --roadmap reads intake `S:` grades
- `.claude/skills/post-merge/refs/production.md` — stamps shipped PRDs' intake rows `completed`
- `.claude/skills/msg/` — GUI Intake tab (server.py build_intake + status endpoint, index.html lanes/chips, styles, protocol-gui.md); menu/--help/README/ARCHITECTURE start the pipeline at intake
- `evals/bench.py` — intake stage added; plan-pm interview ref pruned

- **msg v2 P5 — ship layer: post-merge takes staging → main (Part C, H1, H4).** New `/post-merge` skill — the harness's ONLY merger, with NO flash mode (ship gates never collapse). `--staging` (C1): verify the feature→staging PR's CI is green (branch protection enforces; this is the check) → merge → run the platform's `staging_deploy_cmd` from devkit/PLATFORMS.md (template extended with `staging_deploy_cmd` + `production_deploy_cmd` columns) → emit a human test script derived from the report's "How to verify" + acceptance criteria → STOP (post-merge never self-certifies staging) → on explicit approval stamp `staging-signoff: <date>` into the PRD frontmatter (D11's harness-readable half). `--production` (C2): refuses without the stamp + green staging; double-confirmation (intent, then a final confirm listing exactly what ships); opens a release-style staging→main PR (PRDs, reports, per-platform rollback notes, iOS flagged IRREVERSIBLE); merges only on green CI + the required human GitHub review. New `.claude/scripts/post-merge-protection.sh` (C3): `--bootstrap` sets required status checks (+ optional `--contexts "ci/pre-merge"` so a named red check hard-blocks a PR), no-force-push on staging+main, and ≥1 required review on main (D11's machine half) via `gh api`; `--verify` emits `PROTECTED`/`UNPROTECTED <missing>` machine lines (validated live against this repo) and post-merge Step 1 refuses when unprotected; `/msg --init` offers the bootstrap when a GitHub remote exists. **`shared/refs/flash-floor.md` rewritten to Safety floor v2:** per-skill write powers replace the blanket "never push/PR/merge" (eng → feature branches only; pre-merge → one PR + sync-merge, never merges; post-merge → the only merger; nothing reaches main except the double-confirmed release), human gates never removed (preview approval, staging sign-off, production double-confirm), v1 items unchanged. Roadmap orchestrator rewired: per-PRD chain `eng --build → pre-merge → post-merge --staging → STOP` — `--production` is always human-initiated, never orchestrated. GUI: completion ladder v2 (H1 — override → shipped → staged·human-approved → staged → gated → building → planned → product, PR rungs via gh with silent degrade), board pills/columns for the new states, post-merge reports in the per-PRD grouping with the staging human-test script and a prominent IRREVERSIBLE callout (H4). *Deferred AC: the live "protection blocks a red PR" test needs a user-named scratch GitHub repo (autonomous repo creation is permission-gated) — script payloads JSON-validated and `--verify` exercised live instead.*

- `.claude/skills/post-merge/` — new: SKILL.md + refs (staging, production, protection, deploy, human-test-script, refusal-patterns, output-schema)
- `.claude/scripts/post-merge-protection.sh` — new: bootstrap/verify branch protection (+`--contexts`)
- `.claude/skills/shared/refs/flash-floor.md` — Safety floor v2 rewrite; `report-schema.md`/`finding-schema.md` gain post-merge
- `.claude/skills/eng/refs/build/protocol-roadmap.md` — chain ends at `post-merge --staging`; production never orchestrated
- `.claude/skills/msg/` — GUI ladder v2 + IRREVERSIBLE rendering (server.py, index.html, styles.css, protocol-gui.md); menu/--help post-merge row; --init protection-bootstrap offer; PLATFORMS template deploy columns
- `README.md`, `ARCHITECTURE.md` — pipeline through post-merge; scoped write powers; script table

- **msg v2 P4 — pre-merge is THE CI gate; /review and /test are retired (Part B, H3, I5-partial).** The rebuilt `/pre-merge` takes a feature branch from "eng says done" to "PR open against `staging` with green checks and a human-approved preview" through gate sequence 0–9: platform-mode resolution from new `devkit/PLATFORMS.md` (strict/standard/lenient tolerance profiles; scaffolded by `/msg --init`, whose interview gains exactly one platforms question) → SYNC (D7: trivial conflicts auto-resolved, semantic same-hunk pauses; the sync-merge commit is pre-merge's only direct write) → MECHANICAL (lint/format/typecheck + comment-scan + per-commit cap audit, scripts not LLM) → UNIT+INT re-run post-sync → REGRESSION (D9: a spawned eng subagent authors this PRD's tests to `tests/regression/prd-<n>/` and commits them once graded green — pre-merge never authors what it grades; D5: prior-test edits require a PRD-clause citation or grade `high`) → PLATFORM BUCKETS (e2e/qa/mobile/perf/a11y/coverage/api/load per profile, migrated from /test with `--flaky`/`--changed-only`) → SECURITY+MIGRATION (the two surviving review stages, safety floor in every profile) → PRD-CONSISTENCY (one spec-match pass replacing review's Functional mode, with a vacuous-pass guard) → PREVIEW DEPLOY (D6 path heuristic; D10 `preview_kind` url/artifact/screenshots; blocks on human approval) → OPEN PR feature→staging. Fail loop renamed: `msg-gate/gate-<n>.json` → `eng --build gate-json=` (was msg-test/test-json); GUI's Test Issues tab becomes **Gate Issues** with per-gate-step source badges. Scripts renamed `pre-merge-tooling-detect.sh`/`pre-merge-aggregate-verdict.sh`; `test-init-profile.sh` retired; manifest += review, test + 3 old script names. A live smoke run on a seeded PRD came back clean (`pass_with_warnings`, 1 justified low) and its six robustness findings were fixed in-phase (Step-3 null-runner guard + bare-pytest detection, resolve-diff.sh de-rtk'd, local-staging merge fallback, vacuous-pass guard, `/cook`-missing degrade paths, regression-test commit ownership, `followUp` casing aligned). Bench: pipeline 185.4k → **159.9k tok** (review 25.2k + test 19.1k out; pre-merge 9.6k → 21.4k absorbing them); static surface 137.9k → **100.9k** (−26.8%).

- `.claude/skills/pre-merge/` — SKILL.md rebuilt as the gate spine; new refs: platform-profiles, sync, mechanical, regression, buckets/{_common,e2e,qa,mobile,perf,a11y,coverage,api,load}, security, migration, prd-consistency, preview; flash = mechanical+unit/int+security only; bucket-runners.md superseded
- `.claude/skills/review/`, `.claude/skills/test/` — deleted (27 files); useful content migrated into pre-merge refs
- `.claude/skills/msg/refs/init/templates/template-PLATFORMS.md` — new; `protocol-init.md`/`init.sh` scaffold devkit/PLATFORMS.md from the P1 interview answer
- `.claude/skills/eng/` — `test-json=` → `gate-json=` (file renamed protocol-build-gatejson.md), msg-gate/gate-<n>.json paths, roadmap chain repointed to pre-merge
- `.claude/skills/plan-em/` — `/test --prd` eval-set preview deleted (I5); references scrubbed
- `.claude/skills/msg/` — GUI Gate Issues tab (gateIssues key, srcBadge per gate step, gate-json deep-links); menu/--help rows for review/test removed
- `.claude/skills/shared/refs/` — finding/report schema source enums re-cut to pre-merge stages; verify-prelude producer = pre-merge; session-cache/tooling-detection consumers updated
- `.claude/scripts/` — pre-merge-tooling-detect.sh (+ bare-pytest signal), pre-merge-aggregate-verdict.sh renamed in; test-init-profile.sh deleted
- `remove-manifest.txt` — += skills/review, skills/test, scripts/test-{tooling-detect,aggregate-verdict,init-profile}.sh
- `evals/bench.py` — manifest models the v2 pipeline (review/test stages removed; pre-merge gate stages + pair-review/template-todo fan refs)
- `README.md`, `ARCHITECTURE.md`, `.claude/settings.json` — pipeline/inventory/scripts scrubbed; stale test permissions dropped

- **msg v2 P3 — install layer: manifest-driven removals (Part E).** Retiring a skill is now a one-line data change, not a script edit: new `remove-manifest.txt` at repo root ships 9 entries (`skills/msg-init` — previously hardcoded — plus `docu`, `handoff`, `ship`, `plan`, `design`, `improve`, and the orphaned `scripts/ship-db-touch.sh` + `ship-find-prd.sh`); install.sh reads it from the cloned repo after the install-skills loop and `rm -rf`s each entry under `~/.claude/`, logging `Removed retired: <entry>` (absent target = silent idempotent skip). Guardrails in the parser: exact paths only (globs `*?[` rejected), no `..`/absolute/backslash paths, entries must be exactly `skills/<name>` or `scripts/<file>` with one segment after the prefix (so `skills/plan` can structurally never touch `plan-em`/`plan-pm`/`plan-tune`), and an entry the current run also installs is skipped as a manifest bug — with `skills/improve` exempted from that conflict check because it lives in the source tree but is now **excluded from the copy loop entirely** (repo-internal plan tracker; the stale global copy gets scrubbed, and it never ships again). `MSG_REPO` became env-overridable (dry-run/pin hook). Verified against a scratch `$HOME`: all 9 retired artifacts removed, `plan-em`/`plan-pm`/`plan-tune`/`eng`/`msg` untouched, second run fully silent, all seven malicious-entry probes rejected.

- `remove-manifest.txt` — new: 9 retirement entries + format doc
- `install.sh` — manifest reader + guardrails replace the hardcoded `msg-init` loop; `improve/` copy exclusion; `MSG_REPO` overridable
- `ARCHITECTURE.md` — install-layer notes: copy exclusion + manifest mechanism

- **msg v2 P2 — build discipline: per-ticket pair review, plain-English comments, small-commit caps (A3, A4, A5).** `eng --build` gains a blocking **pair-review subagent** per todo ticket (new `eng/refs/build/pair-review.md`, protocol Step 4e): a principal-engineer persona parameterised by the exec-table Agent column, with a single mandate — **unnecessary lines of code** (dead code, needless abstraction, duplicated logic, over-engineering, hand-rolled stdlib replacements) — plus the A4 comment check; it does not re-review correctness/style/security. Contract: the ticket's diff (cost-capped at ≤500 LOC by the P1 sizing rule) + its `done-when` + the parent's already-compiled standards payload, no `/cook` call; exactly one revision round, then unresolved findings are logged to the §12 Findings ledger with justification and the commit proceeds. The **plain-English comment convention** (A4) lands in the build protocol — every new/modified function/module/class/exported symbol gets a what-not-how comment — enforced by the pair reviewer per ticket and mechanically by new `.claude/scripts/eng-comment-scan.sh` (heuristic diff grep across js/ts/py/go/rs/swift/kt/dart/rb/java; `UNCOMMENTED <file>:<line>` machine lines, exit 1 on flags). **Small-commit caps** (A5) land as new `.claude/scripts/eng-commit-cap.sh` on the staged diff: >500 changed LOC blocks (>300 with `--breaking`), lockfiles/generated excluded; the `--oversize-reason` escape hatch exits 0 but requires an `Oversize-reason:` trailer in the commit body and a §12 ledger entry, with recurring oversize flagged as a plan-time ticket-sizing failure. Commits are now **per ticket** after Step 6's single human confirmation (no new prompts). Flash: pair review explicitly skipped (single end-of-run gate, no per-ticket cadence); both mechanical gates ride flash's one commit gate.

- `.claude/skills/eng/refs/build/pair-review.md` — new: persona, mandate, contract, one-round blocking rule
- `.claude/scripts/eng-comment-scan.sh` — new: deterministic A4 comment scan (tested: flags uncommented, passes commented, excludes fixtures)
- `.claude/scripts/eng-commit-cap.sh` — new: A5 cap gate (tested: 40/500 OK, 640/500 blocked, 390/300 blocked w/ --breaking, oversize-reason escape, lockfile excluded)
- `.claude/skills/eng/refs/build/protocol.md` — A4 rule (4c), pair-review step (4e), per-ticket commit gate running both scripts (Step 7)
- `.claude/skills/eng/refs/build/flash/mode-flash.md` — cap + comment scan on the single flash gate; pair review skipped by decision
- `.claude/skills/eng/SKILL.md`, `ARCHITECTURE.md` — references + script table updated

- **msg v2 P1 — eng core: one plan wave, lean build loop (A1, A2, I1).** The separate `eng --todo` mode and dispatch wave are gone: `eng --plan` now writes the `## Engineering — <Agent>` section, fills the Execution steps + Files columns, **and** writes the `## Todos — <Agent>` tickets in a single pass — one full subagent dispatch round per platform eliminated, plus one PRD re-read per agent. The ticket schema moved to `eng/refs/plan/template-todo.md` unchanged (`F<n>-T<k>` ids, eight fields, empty-block sentinel — `eng --build` reads the same shape), and gains the **ticket-sizing rule**: every ticket must be scoped at plan time to fit the per-commit caps (<500 changed LOC, <300 when breaking), split at plan time never at build time. The finding→issue-ticket projection + `kind` discriminator moved to `eng/refs/build/protocol-build-testjson.md` (its actual consumers' side); `/test` and the GUI repoint there. `eng --build`'s TDD loop and full-suite gate rescope to **unit + integration only** — e2e/visual/perf/a11y/coverage exit the fix-iteration loop and become pre-merge's job (A2). plan-em loses Step 0 entirely: `prefs.json` + `refs/prefs-bootstrap.md` deleted, `$TODOS` toggle gone, the exec table always carries the Todos column, mode detection collapses to `plan` | `build`, the synth "Run todo breakdown" option is deleted, and plan-em creates the `## Todos` umbrella once before dispatching the plan wave (race-safe). An invocation carrying `--todo` hard-fails with a pointer to `--plan`. Bench: plan-em main −775 tok modeled, static skill surface −2,153 tok, plus the unmodeled todo wave itself (~7.3k input tok per agent per run) eliminated.

- `.claude/skills/eng/SKILL.md` — two-mode routing, `--todo` hard-fail block, single-pass `--plan` contract, references repointed
- `.claude/skills/eng/refs/plan/protocol.md` — "Todo tickets — written in the same pass" spec: schema by reference, sizing caps, self-consistency checks, extended write confirmation
- `.claude/skills/eng/refs/plan/template-todo.md` — new: ticket schema migrated from `refs/todo/template-todo.md` + ticket-sizing rule (rule 2)
- `.claude/skills/eng/refs/plan/flash/mode-flash.md` — flash plan writes tickets in the same pass, same schema/caps
- `.claude/skills/eng/refs/todo/` — deleted (both `protocol-todo.md` and `template-todo.md`)
- `.claude/skills/eng/refs/build/protocol.md` — spec source: todos always written by `--plan` (exec-table = degraded fallback); TDD loop + full-suite gate scoped to unit + integration
- `.claude/skills/eng/refs/build/protocol-build-testjson.md` — received the finding→issue-ticket projection + `kind` discriminator
- `.claude/skills/eng/refs/build/flash/mode-flash.md`, `.claude/skills/eng/refs/build/protocol-roadmap.md` — suite scope + rejection lines aligned
- `.claude/skills/plan-em/SKILL.md` — Step 0 deleted, references scrubbed
- `.claude/skills/plan-em/prefs.json`, `.claude/skills/plan-em/refs/prefs-bootstrap.md` — deleted
- `.claude/skills/plan-em/refs/protocol-em.md` — two-mode detection, todo wave deleted, umbrella created before the plan wave, synth menu trimmed
- `.claude/skills/plan-em/refs/template-exec-table.md` — Todos column unconditional
- `.claude/skills/plan-em/refs/flash/mode-flash.md` — always-on Todos column + same-pass tickets
- `.claude/skills/test/SKILL.md`, `.claude/skills/msg/refs/protocol-gui.md`, `.claude/skills/msg/refs/gui/server.py`, `.claude/skills/msg/refs/gui/index.html` — projection/schema references repointed off removed concepts
- `README.md`, `ARCHITECTURE.md` — eng described as two-mode; execution chain `eng --plan → eng --build`

- **msg v2 plan — contract certifier, plan-em rework, and the 7-phase execution model.** plan-tune's adversarial posture is retired (D17): it becomes a **contract certifier** running a fixed seven-check certification on digest slices, every check tied to a named downstream consumer under the governing rule *no check without a consumer* — criteria testability, breaking/DB labeling, intent fidelity vs the intake row, exec-table integrity, ticket sizing + graph validity, frontmatter graph/platform coverage, and cross-agent integration-contract coherence (the one check only the certifier can perform, since row-scoped eng agents are structurally blind across sections). Blanket completeness/consistency/prose sweeps are cut; product judgment stays with the human touchpoints (intake, preview, staging). plan-em drops from ~4 interactive pauses to one (D19: roster approval): certifiers auto-run inline as preconditions before *both* dispatch waves (D18 — product before plan, eng before build; an unenforced gate decays into documentation), and relationship questions are replaced by silent consumption of the certified dependency graph. Execution is re-cut into **7 phases (P1–P7), one commit each** (D8 amended): a Fable session orchestrates — dispatch, acceptance-criteria verification, commit — while Opus subagents execute; no phase commits until its full AC checklist is green. P1 eng core → P2 build discipline → P3 install manifest → P4 pre-merge CI gate → P5 ship layer → P6 intake + autonomous plan-pm → P7 certification layer, exiting on a full autonomous dry run and a ≥40% net token cut vs the v1 baseline.

- `.claude/skills/improve/plan-msg-v2.md` — Part G rewrite (7-check table, cuts, trade note), Part I (I1–I5), D8/D12 amendments, D17–D19, § Execution phases with per-phase AC checklists

- **msg v2 plan addendum — plan-tune as certification authority (Part G) + GUI v2 (Part H).** With plan-pm autonomous and review deleted, the PRD's acceptance criteria became executable (regression tests, PRD-consistency gate, preview gate all run off them) — so plan-tune is rebuilt as the planning layer's certification authority: intent-fidelity audit against the intake row (scope-creep/scope-loss/grade consistency), hardened criteria-testability (an unassertable criterion is a Major — it would otherwise become a vacuous regression test), and an unlabeled-breaking-surface hunt on the eng tune (unlabeled = Critical, since the 300-LOC cap, pre-merge pause, and plan-pm pause all key off the label). Severity policy (D15): auto-fix Critical+Major, emit a compact found→fixed terminal table, ask once about Minors — the fix-selection and step-4 gates are deleted. Self-healing (D16): every auto-fixed Critical/Major logs a category-tagged learning to `devkit/AHA.md`, which plan-pm already reads pre-draft (zero new plumbing); a category recurring ≥3 runs escalates to a protocol-repair flag, and the benchmarkable metric is Critical+Major per fresh PRD trending to zero. Part H consolidates the GUI v2 rework: completion ladder gains gated/staged/shipped states, an Intake tab with rubric grade chips, the Gate Issues tab (renamed from Test Issues, reading `msg-gate/gate-*.json`), post-merge reports rendered release-style with the iOS IRREVERSIBLE flag surfaced, and exactly one new write carve-out (INTAKE.md status cells). Decisions log now D1–D16.

- `.claude/skills/improve/plan-msg-v2.md` — Part G (G1–G5, D15/D16), Part H (H1–H5), inventory/pipeline/token-accounting/migration updates

- **msg v2 — harness restructure plan (improve ID 23).** The full architectural blueprint for v2, developed and settled across 14 logged decisions (D1–D14), targeting faster development through the harness and lower token cost per coding run (−40%+ expected, to be proven via `evals/bench.py`). Headlines: `/review` and `/test` fold into a rebuilt `pre-merge` — the single CI gate (sync → mechanical → unit/int → compounding regression suite → platform buckets → security/migration → PRD-consistency → preview-deploy human gate → opens PR feature→staging) with per-platform failure tolerances from a new `devkit/PLATFORMS.md`; a new `post-merge` skill ships staging→main behind sign-off stamps, double-confirmation, and branch protection; `eng` is rebuilt around a merged plan+todo pass, unit+integration-only builds, a blocking per-ticket pair-programmer persona, plain-English comment convention, and <500/<300-LOC commit caps; a new `intake` skill owns idea capture + the interview into a graded `INTAKE.md` ledger while `plan-pm` goes autonomous (pauses only for open questions and breaking/critical touches); `install.sh` gains manifest-driven removals (`remove-manifest.txt`) and stops shipping `improve/`. Migration is phased V2-A→D, benchmark-gated, harness working at every step. Plan force-added past the `improve/` gitignore by explicit decision — the v2 blueprint travels with the branch.

- `.claude/skills/improve/plan-msg-v2.md` — new: the full v2 plan (Parts A–F, decisions log, safety floor v2, token accounting, migration phases)
- `.claude/skills/improve/_INDEX.md` — plan registered as ID 23 (in-progress)

- **Token-cut Wave 2a — exec-table `files:` column + diff-scoped standards flags.** Second execution wave of the Phase-4 token-efficiency plan, all assertion-gated and independently re-verified. The execution table gains a `Files` column (both `$TODOS` forms), populated by the eng agent alongside its Execution steps and carried through `scan-prd-digest.py` (legacy tables degrade to an empty `files` value, no regression); a new `plan-em-exec-collision.py` helper turns parallel-safety into a mechanical set-intersection over row Files (`COLLISION`/`MISSING_FILES` machine lines, non-zero exit on any overlap). On top of that, `eng --build` and `plan-em` now derive **diff-scoped sub-ref flags** for `/cook` instead of bare domain flags — dropping only refs the PRD/devkit provably excludes, and falling back to the full shelf on any uncertainty (never under-loads). Realizing that win required a companion change in the cook source repo so a bare domain flag paired with its own sub-refs resolves to the SKILL.md floor + only those named refs (previously the full shelf, making the scoped flags a no-op). Source-verified: the macOS shelf compiles from 8 sections to 3 with `degraded: []`. Two candidate defects the wave surfaced were fixed by the orchestrator, not the workers: a collision helper shipped as `.sh` with a python shebang (renamed `.py`), and the scoped-flag no-op traced through cook's resolver.

- `.claude/skills/plan-em/refs/template-exec-table.md` — `Files` column added to both table forms, column definition, worked examples, quality gate
- `.claude/skills/eng/refs/build/protocol-exec.md` — instruction to populate `Files` alongside Execution steps
- `.claude/scripts/scan-prd-digest.py` — `files` carried through the exec-table digest (legacy → `""`)
- `.claude/scripts/plan-em-exec-collision.py` — new: mechanical row-Files collision / parallel-safety checker
- `.claude/skills/eng/refs/build/protocol.md`, `.claude/skills/plan-em/refs/protocol-em.md` — diff-scoped sub-ref flag derivation with never-under-load fallback (companion cook resolver change lives in the cook source repo)

- **Token-cut Wave 1 — six cross-skill contract fixes.** First execution wave of the Phase-4 token-efficiency plan, drawn from two live token/latency analyses. Each fix was assertion-gated and independently re-verified before landing; two further candidate fixes were retired as already-repaired upstream (commit `7466791`), a plan-drift finding surfaced by the wave itself. `scan-prd-digest.py` now preserves `parent:` through the digest so a sub-PRD's branch resolution isn't misread as top-level. The `eng --build` standards flag table gains the missing `--swift`/`--macos`/`--css` shelf rows (plus `--swift:testing`), and its `report-[n].md` step is reframed as optional/best-effort with the inline build summary as the sanctioned report-of-record. `plan-em` branch resolution gates parent-branch reuse on `git branch --merged main`, cutting a fresh branch when the parent has already shipped, and no longer implies `/test --prd` persists `eval_set.json` (only `/review` does). `/review` Coverage mode gains a `sub-verdict` (`convention` | `behavior`) so a missing-dedicated-test `block` reads as "add a test file," not "something is broken."

- `.claude/scripts/scan-prd-digest.py` — `parent` added to the digest frontmatter allow-list (1.4)
- `.claude/skills/eng/refs/build/protocol.md` — `--swift`/`--macos`/`--css` + `--swift:testing` flag rows (1.3); report file made optional with inline report-of-record fallback (1.6)
- `.claude/skills/plan-em/refs/protocol-em.md` — `git branch --merged main` gate on parent-branch reuse (1.5); `/test --prd` no longer implies a persisted `eval_set.json` (1.7)
- `.claude/skills/review/refs/modes/coverage.md`, `.claude/skills/review/refs/schema.md` — `sub-verdict` on Coverage's block verdict (1.8)

- **Run reports — every build/review/gate run now tells you what you got and how to check it.** `eng --build`, `/review`, and `/pre-merge` end each completed run by writing `report-[n].md` into the PRD's `features/prd-<n>-<slug>/reports/` folder (`features/reports/` when no PRD applies; `[n]` = per-directory max+1). The report is a plain-language record for a human: work done, code changes with lines added/deleted, tests passed/failed, **what you can expect**, and **how to verify** it works — verification steps written in simple, everyday language (what to do, what you should see; commands only when unavoidable, copy-pasteable with the expected outcome in plain words). One canonical contract in `shared/refs/report-schema.md` (GUI-parseable frontmatter + fixed `##` sections) keeps all three producers and the board in agreement; writes are best-effort and never fail, block, or re-verdict a run, and each skill's existing output contract (build summary, findings JSON, final JSON emission) is unchanged. The `/msg --gui` board gains a dedicated **Reports** tab — cards grouped by PRD with skill/verdict/stat pills, a detail page rendering the report markdown, and a ↗ cross-link to the mapped PRD — verified end-to-end against a fixture project (server parse, PRD mapping, live serve, JS syntax).

- `.claude/skills/shared/refs/report-schema.md` — new: canonical `report-[n].md` contract (path resolution, numbering, frontmatter, section contract, per-skill field mapping, rules)
- `.claude/skills/eng/refs/build/protocol.md` — Run report step in the Output contract; `**Report:**` line in the build summary; run-artifact exemption in Constraints
- `.claude/skills/review/SKILL.md` — Step 7 report write (full unfiltered finding set), Outputs row, References entry
- `.claude/skills/review/refs/flash/mode-flash.md` — flash Emit step writes the report too
- `.claude/skills/pre-merge/SKILL.md` — Step 7 report written before the final JSON emission (skipped on refused/skipped); `Write` added to allowed_tools; hard-refusal scope + Outputs table extended
- `.claude/skills/pre-merge/refs/flash/mode-flash.md` — flash Emit step writes the report too
- `.claude/skills/msg/refs/gui/server.py` — `parse_report_file()`/`collect_reports()` (nested sub-PRD dirs included, unparseable → `skipped[]`), `reports[]` in `build_data()`
- `.claude/skills/msg/refs/gui/index.html` — `REPORTS` global, Reports nav tab, `#/reports` + `#/reports/<file>` routes, PRD-grouped card list, markdown detail view with PRD cross-link
- `.claude/skills/msg/refs/protocol-gui.md` — reports in the read model, data-contract example, Reports-tab rendering rules
- `README.md` — run-reports blurb; Reports tab in the `--gui` line
- `ARCHITECTURE.md` — new Run reports section; msg inventory row mentions the run-report reader

- **Fold `msg-init` into `/msg --init`.** The standalone bootstrap skill is retired; project bootstrap is now a mode of the `/msg` root menu, consolidating all harness-meta operations (`--init`, `--gui`, `--set-mode`, `--help`) under one skill. The protocol moved verbatim to `msg/refs/protocol-init.md` (git-mv, history preserved); `init.sh`, `init-setup.sh`, and the nine templates moved to `msg/refs/init/{,templates/}` with a one-line `REFS` repoint. msg's frontmatter description now carries the bootstrap trigger phrases ("initialise project", "bootstrap repo", "set up the framework", "start a new project") so natural-language triggering is preserved, and the Dispatch table gained an `--init` branch. Every reference site was swept to `/msg --init`: README, ARCHITECTURE (skill-inventory row removed, msg row extended), install.sh's next-steps echo, plan-pm/plan-em devkit hints, plan-em's msg-skill-set list, the three hard-coded template paths (plan-pm AHA header, eng OPEN-QUESTIONS entry template, `bench.py`'s devkit proxy), both self-referencing templates, and the tracked PRD-fixture hint strings. `install.sh` now deletes a stale `~/.claude/skills/msg-init/` on install so old copies can't shadow the new mode. Integrity verified identical to pre-fold: fresh-dir bootstrap creates all 11 outputs with clean substitution and stack-specific .gitignore, second run fully idempotent (0 created / 11 skipped), `ALL_COMPLETE=true` on rescan, stack-hint detection intact; `bench.py` resolves all new paths (pipeline +21 tok = noise; static +413 tok for the `--init` routing in the always-loaded msg SKILL.md).

- `.claude/skills/msg/refs/protocol-init.md` — moved from `msg-init/SKILL.md`; paths/usage rewritten for the mode form
- `.claude/skills/msg/refs/init/{init.sh,init-setup.sh,templates/}` — moved from `msg-init/`; `REFS` → `templates/`
- `.claude/skills/msg/SKILL.md` — trigger-bearing description, `--init` usage + dispatch + protocol section, menu/happy-path/--help updates
- `install.sh` — retired-skill cleanup (`msg-init`), next-steps echo
- `README.md`, `ARCHITECTURE.md` — `/msg --init` docs; inventory row folded into msg
- `.claude/skills/plan-pm/{SKILL.md,refs/protocol-pm.md}`, `.claude/skills/plan-em/{SKILL.md,refs/protocol-em.md,refs/prefs-bootstrap.md}`, `.claude/skills/eng/refs/build/protocol.md` — hint strings + template paths repointed
- `evals/bench.py` — devkit-proxy template paths repointed
- `features/prd-10x/*` — fixture hint strings updated

- **Harness audit Tier 1 — repair nine cross-skill contract breaks.** A deep audit of the skill suite surfaced nine places where one skill writes what another can't read; all fixed without redesign. `plan-tune` now stamps `product-tuned:`/`eng-tuned:` with the literal `yes` (a date never matched the consumers' `yes` gates, so tuned PRDs re-fired the tune gate and never passed roadmap readiness). The `/test` aggregate stamps a top-level `head` sha and `pre-merge --test-json` reads it — the ship-time integration/e2e skip could previously never fire — with integration coverage now keyed off the merged `unit` bucket. `install.sh` implements the README-advertised `--with-cook` instead of dying on it. The flash PRD template is digest-parseable again (canonical frontmatter, §6 features table, `## 9. Plan tune findings` instead of "Ledger"). Standalone `eng --build` gains the DB-touch/breaking-change pause the flash floor always promised — never waived by autonomy contracts. eng build refs write `followUp.status` (the key the `--gui` board actually reads, so resolved test issues no longer render forever-open). `review` emits `eval_set_path` only when Functional actually wrote the file. `resolve-diff.sh` distinguishes a `bad_base` setup error from a clean-tree `no_diff`. And `/test`'s user-cancel verdict is now `skipped`, matching `/pre-merge` (`refused` reserved for error paths; both defined in the shared schema).

- `.claude/skills/plan-tune/SKILL.md` — frontmatter writeback stamps `yes`, not a date
- `.claude/scripts/test-aggregate-verdict.sh`, `.claude/skills/test/refs/schema.md` — top-level `head` sha; user-cancel verdict `refused` → `skipped`
- `.claude/skills/test/SKILL.md`, `.claude/skills/shared/refs/finding-schema.md` — `skipped` (user cancel) vs `refused` (error path) defined once, shared
- `.claude/skills/pre-merge/SKILL.md`, `scripts/resolve-diff.sh` — `head`-based freshness, `unit`-bucket coverage key, `bad_base` refusal, `rtk git fetch`
- `install.sh` — `--with-cook` implemented (cook bootstrap, warn-on-failure)
- `.claude/skills/plan-pm/refs/flash/{template-flash,mode-flash}.md` — digest-parseable flash PRD shape
- `.claude/skills/eng/refs/build/{protocol,protocol-build-testjson}.md` — leaf-build production guardrail; `followUp.status` key
- `.claude/skills/review/SKILL.md` — `eval_set_path` never points at an unwritten file

- **Housekeeping: add `LICENSE` + `msg-minor.md`, drop superseded planning docs.** Added the project `LICENSE` and `msg-minor.md` — a plain-English tracker for the three open flash-mode residuals (live end-to-end verification, the +0.45% comprehensive-mode regression, and re-basing the per-stage flash targets from token-% to execution-count). Removed the superseded `msg-v1.md` / `msg-v2.md` planning docs (their content shipped as the delivered token-efficiency phases).

- **Retire the `improve` skill.** Removed the repo-local improvement-planner skill from the installed surface: deleted its `SKILL.md` + `refs/`, untracked `_INDEX.md`, and gitignored the whole `.claude/skills/improve/` folder (its plan docs persist on disk as local scratch). Cleaned up every reference — dropped the now-unused `LOCAL_ONLY_SKILLS` skip mechanism from `install.sh`, the stale `Edit(/.claude/skills/improve/**)` permission from `.claude/settings.json`, the improve-exclusion note from `ARCHITECTURE.md`, and the `improve` entry from plan-em's msg-skill-set list. `/msg` and `msg-init` never referenced it.

- **Consolidate flash protocols under a uniform `flash/mode-flash.md` path.** Renamed every skill's flash protocol from `flash.md` / `protocol-flash.md` to `<skill>/refs/[…/]flash/mode-flash.md`, so the layout is identical across review/test/pre-merge/eng/plan-pm/plan-tune/plan-em. Repointed all routing references (SKILL.md route lines, `mode-resolution.md`, `flash-floor.md`, ARCHITECTURE) and re-depthed the moved files' relative `../shared/refs/` links for the deeper nesting — also fixing two pre-existing broken links in review's flash rubric. Empty skill folders (`pre-merge/archive`, `plan-em/refs/{plan,build}`) removed. Behavior-neutral; the flash/comprehensive benchmark is unchanged.

- **msg-v1 Phase 3 — opt-in flash mode + harness-wide mode toggle.** Every user-facing skill now runs in one of two modes: **comprehensive** (default, unchanged) or **flash**, an opt-in fast pass that trades *execution count* (subagents, buckets, gates, interview turns) — **not** correctness or safety — for speed. Flash reuses the msg-v2 substrate rather than re-implementing it: PRD-digest slices, the shared verify prelude, flag-based injected cook, and the session cache. Each skill loads a small `refs/flash.md` **instead of** its comprehensive refs — `review` runs mechanical gates + **1** combined semantic agent (vs ≤4) and produces the verify prelude; `test` runs unit+functional **in-process** (0 subagents) consuming the prelude; `pre-merge` runs build+security only (integration/e2e emit the `--test-json` skip shape); `eng --build` uses **1** agent (no per-platform fan-out) off the `build` digest slice; `plan-pm` collapses the interview to **2** `AskUserQuestion` calls; `plan-tune` runs critical-severity checks only with 0 gates; `plan-em` uses **1** generalist agent (≤2 platforms) + one merged gate. A harness-wide toggle (`shared/refs/mode-resolution.md`, precedence *flag > forwarded > local pref > global pref > comprehensive*) resolves the mode at each skill's Step 0; `/msg --set-mode --flash|--comprehensive` persists it to `.claude/msg/pref.json` (not gitignored; `install.sh` never writes it), and in-repo orchestrators (`plan-em`, roadmap `eng --build`, `review`) forward the resolved mode into every subagent so a run never drifts. The **safety floor is never relaxed in either mode** (`shared/refs/flash-floor.md`): DB/breaking-change pauses, branch isolation, never push/merge, secret scan, frontmatter stamps, F-ID stability, §9 ledger, test-fail ticket, pre-merge refusals. Measured via a new `BENCH_MODE=flash` manifest in `evals/bench.py`: flash pipeline **84,987–85,198 tok = 47.7% of post-v2 comprehensive**, run-wide subagents ~75% fewer; comprehensive stays within +0.45% (the flash-flag/Step-0 routing docs now in each always-loaded entry file). Structural verification green (11/11 flash refs, 9/9 routes, floor + v2-reuse + digest-slice checks); the live end-to-end functional verification (build-green / seeded-blocker / clean pre-merge) is a tracked follow-up a static benchmark cannot execute.

- `.claude/skills/shared/refs/flash-floor.md` — new: never-relaxed safety floor + common flash semantics (auto-proceed, capped stdout, v2-substrate reuse, mode-propagation sentence)
- `.claude/skills/shared/refs/mode-resolution.md` — new: mode precedence + `pref.json` format (flag > forwarded > local > global > comprehensive; corrupt/missing → comprehensive)
- `.claude/skills/review/{SKILL.md,refs/flash.md}` — new flash path (Step 0 mode route, 1 combined semantic agent, verify-prelude producer, top-10 @ min-severity high); Step 6 mode-propagation note
- `.claude/skills/test/{SKILL.md,refs/flash.md}` — new flash path (unit+functional in-process, consumes verify prelude, fail ticket intact)
- `.claude/skills/pre-merge/{SKILL.md,refs/flash.md}` — new flash path (build+security, integration/e2e `--test-json` skip shape, no gate)
- `.claude/skills/eng/{SKILL.md,refs/plan/flash.md,refs/build/flash.md}` — `--plan`/`--build` flash variants (compressed 5-section plan; 1 build agent off the `build` slice, 1 injected cook, single commit gate)
- `.claude/skills/eng/refs/build/protocol-roadmap.md` — mode propagation into roadmap `eng`/`review`/`test`/`pre-merge` subagents
- `.claude/skills/plan-pm/{SKILL.md,refs/flash/protocol-flash.md,refs/flash/template-flash.md}` — flash path (2-call interview, GLOSSARY+ARCHITECTURE only, digest-parseable slim template)
- `.claude/skills/plan-tune/{SKILL.md,refs/flash.md}` — flash path (critical-severity checks only, 0 gates, auto-fix to canonical PRD)
- `.claude/skills/plan-em/{SKILL.md,refs/flash.md,refs/protocol-em.md}` — flash path (1 generalist agent ≤2 platforms, merged gate, synth from agent returns); resolved-mode forwarding in the subagent-injection block
- `.claude/skills/msg/SKILL.md` — `--flash` menu resolution + `/msg --set-mode` (scope-asking, merge-safe pref write) + active-mode line
- `.claude/skills/msg-init/SKILL.md` — `--flash` zero-interview bootstrap (≤1 confirm)
- `README.md`, `ARCHITECTURE.md` — Run modes section (pref, precedence, propagation, v2-substrate reuse, never-relaxed floor)

- **msg-v2 — input digestion + protocol slimming (−53% modeled input footprint).** Aggressive, breaking-allowed token cuts on top of msg-v1 Phase 1, driven by a measured benchmark rather than estimates. The dominant lever is a **PRD digest**: `scan-prd-digest.py` deterministically parses a PRD (no LLM) into a sliceable JSON — `--slice product|plan|eng-audit|build|eval|synth` — so each pipeline stage reads only its ~2–8k-token slice instead of re-reading the full ~20k-token PRD prose (it was re-read ~8× across the pipeline, ≈57% of the footprint). Contractual fields (F-IDs, acceptance criteria, integration contracts, glossary, exec rows) are copied verbatim; narrative prose is dropped but every entry keeps a `prose_lines` escape-hatch pointer; the parser is number-agnostic + fuzzy-column and flags unknown sections in `unparsed_sections` (validated across prd-100…103). Wired into all six PRD consumers (plan-tune ×2, plan-em pre-flight + synthesis, eng --build, review + test eval bootstrap). A hash-keyed **session cache** (`shared/refs/session-cache.md`, `.claude/msg/cache/`, gitignored) governs it and the new **verify prelude** (`shared/refs/verify-prelude.md`) — review produces one shared diff+tooling+eval_set artifact that test and pre-merge consume instead of each re-resolving/re-detecting/re-deriving (standalone runs self-setup unchanged). Protocol slimming (hot/cold split of `eng/refs/build/protocol.md`, prose→tables on `protocol-em.md`, checklist-tighten on `tune-product.md`) contributed a marginal ~2 points — these protocols are dense with load-bearing instructions, not bloat. A reproducible harness `evals/bench.py` measured every step (380,704 → 177,663 tok; `BENCH_PRD=full` recomputes the pre-digest baseline). No behavior/finding change: every invariant (verdict enums, refusal patterns, branch/commit/scope/DB-pause guards, `--global` P0 floor, frontmatter stamps, §9 ledger, `--test-json` handoff, secret scan) grep-verified intact.

- `.claude/scripts/scan-prd-digest.py` — new: deterministic PRD → sliceable digest generator (verbatim contractual fields, prose_lines pointers, source_hash cache key, fuzzy/number-agnostic parsing)
- `.claude/skills/shared/refs/session-cache.md` — new: hash-keyed session-cache contract (source canonical, cache derived/disposable, generate-if-stale, never-hard-fail)
- `.claude/skills/shared/refs/verify-prelude.md` — new: shared diff+tooling+eval_set prelude spec for the review→test→pre-merge triad
- `.claude/skills/plan-tune/SKILL.md`, `refs/tune-product.md`, `refs/tune-eng.md` — read `product`/`eng-audit` digest slices; tune-product checklist tightened
- `.claude/skills/plan-em/refs/protocol-em.md` — `plan` slice at pre-flight, `synth` slice at synthesis (was full-PRD re-read); prose→tables/checklists
- `.claude/skills/eng/refs/build/protocol.md` — `build --feature` slice read; hot/cold split (test-json + debug paths → new `protocol-build-testjson.md` / `protocol-build-debug.md`, lazily loaded); OPEN-QUESTIONS dedup; example trim
- `.claude/skills/eng/refs/build/{protocol-build-testjson.md,protocol-build-debug.md}` — new: lazily-loaded cold paths
- `.claude/skills/review/SKILL.md` — `eval` slice bootstrap; producer of the verify prelude
- `.claude/skills/test/SKILL.md`, `.claude/skills/pre-merge/SKILL.md` — consume the verify prelude when fresh (tooling/diff/eval_set), self-setup otherwise
- `.gitignore` — add `.claude/msg/cache/`
- `msg-v2.md` — the aggressive-cuts plan (delivered; tiering dropped per decision)

- **msg-v1 Phase 1 — token-efficiency structural fixes (no behavior change).** Cut the pipeline's dominant token costs without altering any artifact, safety, scope, or branch guarantee. `review` now spawns **one `/cook` sub-agent per mode instead of per flag** (~12–13 → ≤4 semantic agents) and the orchestrator **compiles `/cook` once per stack and injects the compiled standards payload** into each sub-agent prompt rather than every leaf re-invoking cook; `eng`/`plan-em` call cook via **explicit `--<domain>` flags** (cacheable, P0-guaranteed) instead of the uncacheable prose path, and drop cook from `--todo`/`--plan` entirely. Build sub-agents receive **row-scoped context** (exec rows + relevant PRD feature sections + a devkit digest) instead of re-reading the full PRD and all devkit. The finding object is now defined **once** in `shared/refs/finding-schema.md` — the ~17 inlined copies across `test`/`review`/`pre-merge` collapse to path references. `test`'s 10 mode files share a new `_common.md` (guard + error rule + output envelope + schema pointer) and drop all 7 redundant runner-detection tables (the detect script is authoritative); `review`'s cook-backed modes share a `_common.md` Execution contract, conditional-mode triggers are hoisted into `SKILL.md` Step 6 (mode files loaded only on match), and `performance.md` is folded in and deleted. Tooling detection moves out of hot paths into `test-tooling-detect.sh` JSON (now also emitting mechanical runners, secret scanners, build tool, bundle analyzer), and the GUI static fallback is a `fill-static.py` call instead of a ~35k-token manual splice. `pre-merge` accepts `--test-json` to skip integration/e2e buckets already covered by a fresh, clean `/test` run. Hot `SKILL.md` files slim down (`eng` 2222→1492w, `plan-pm` 1909→1274w) by moving rare-mode content to refs; `msg-init`'s interview batches into ≤4 `AskUserQuestion` calls; and `review`'s dedup key is fixed to the canonical `(category, file, line, rule)`. Net −459 lines. Cook-internal tasks (T1.12 budget, cook `_INDEX` archives, cook `--flash`) are deferred — cook is a separate repo.

- `.claude/skills/review/SKILL.md` — Step 6 rewrite: compile-once/inject, one sub-agent per mode, inline conditional triggers, folded performance mode, dedup key → `(category, file, line, rule)`; Step 2 consumes detect-script JSON
- `.claude/skills/review/refs/modes/_common.md` — new: shared cook-backed Execution contract
- `.claude/skills/review/refs/modes/{quality,security,migration}.md` — Execution block → `_common.md`; `performance.md` deleted; `schema.md` → pointer at shared
- `.claude/skills/test/refs/modes/_common.md` — new: guard + error rule + output envelope + schema pointer
- `.claude/skills/test/refs/modes/*.md`, `test/refs/schema.md` — inlined finding schema → pointer; runner tables removed; boilerplate factored to `_common.md`
- `.claude/skills/eng/SKILL.md`, `eng/refs/build/protocol.md`, `protocol-roadmap.md` — flag-based cook, compile-once/inject, row-scoped sub-agent context, slimmed hot file (test-json/roadmap docs → build refs)
- `.claude/skills/plan-em/{SKILL.md,refs/protocol-em.md,refs/prefs-bootstrap.md}` — flag-based cook, payload injection, row-scoped context, Step 0 prefs prose → ref
- `.claude/skills/plan-pm/{SKILL.md,refs/protocol-pm.md,refs/protocol-sub.md}` — sub-PRD/roadmap sections → refs; open-questions batched
- `.claude/skills/plan-tune/SKILL.md` — persona/outputs de-duplicated; `refs/principles.md` deleted (stale copy)
- `.claude/skills/msg-init/SKILL.md` — 14-question interview → 4 batched `AskUserQuestion` calls
- `.claude/skills/pre-merge/{SKILL.md,refs/finding-schema.md,refs/output-schema.md}` — schema → pointer; `--test-json` bucket-skip; Step 2 detect-script JSON; `pre-merge-plan.md` deleted
- `.claude/scripts/test-tooling-detect.sh` — emit build tool, mechanical runners, secret scanners, bundle analyzer as JSON
- `.claude/skills/msg/refs/gui/fill-static.py` — new: GUI static-fill substitution; `protocol-gui.md` Step 4 invokes it
- `.claude/skills/shared/refs/tooling-detection.md` — demoted to maintainer documentation
- `README.md`, `ARCHITECTURE.md` — docu: msg-init step count, detect-script scope, cook-integration paragraph
- `msg-v1.md` — the four-phase plan (Phase 1 marked done)

- Gitignore the generated `roadmap/` directory. `roadmap/roadmap.md` is per-project output of `plan-pm --roadmap` (same generated-content class as the already-ignored `features/` and `plans/`), so it is local-only and no longer tracked.

- `.gitignore` — add `roadmap/` under the working-dirs section

- Teach `plan-pm` to author the PRD `summary` frontmatter field that the `/msg --gui` detail page renders. The PRD template grows a `summary:` field (a single-line 2–3 sentence gist of the core objective + headline features); Step 4 initializes it from the Q1 brief and Step 5 reconciles it against the finalized §1 Product objective and §6 feature list. Sub-PRDs author their own `summary` (not inherited from the parent), and the `protocol-gui.md` data-shape doc records the new field. New PRDs now ship a summary out of the box; older PRDs without one still fall back to the GUI's feature-title list.

- `.claude/skills/plan-pm/refs/template-prd.md` — add `summary:` to the file-header frontmatter with authoring guidance
- `.claude/skills/plan-pm/refs/protocol-pm.md` — Step 4 frontmatter bullet for `summary`; Step 5 reconciliation note
- `.claude/skills/plan-pm/SKILL.md` — sub-PRD D4 authors a fresh `summary` rather than inheriting the parent's
- `.claude/skills/msg/refs/protocol-gui.md` — document `summary` in the PRD data payload shape

- Polish the `/msg --gui` **Roadmap tab** and add a PRD summary to the detail page. Roadmap PRD cards that have **shipped** now render in a greyed-out `done` state with a ✓ (kept visible, not hidden), and a roadmap phase whose PRDs have *all* shipped gets a ✓ on its lane header. The phase **goal** line is inset to sit within the lane padding instead of hugging the edges, and the **roadmap tune log** is no longer rendered on the board (it stays in `roadmap/roadmap.md` for rerun-stability). The **PRD detail page** now shows a 2–3 sentence summary below the title, sourced from a new frontmatter `summary` field with a feature-title-list fallback when absent. Verified: `server.py` change exercised via `/api/data`, `index.html` passes node --check, and the live roadmap/summary payloads were confirmed end-to-end.

- `.claude/skills/msg/refs/gui/index.html` — detail-page `summary` render (`detailSummary` w/ feature-title fallback); roadmap card `done`/✓ state for shipped PRDs; `phase-done` ✓ on fully-shipped lanes; drop tune-log render
- `.claude/skills/msg/refs/gui/server.py` — surface frontmatter `summary` in the PRD data payload
- `.claude/skills/msg/refs/gui/styles.css` — inset `.roadmap-goal` within lane padding; add `.card.done`, `.phase-done`, `.done-check`, `.phase-check`, `.detail-summary` rules

- Add an end-to-end **roadmap capability** that takes the project from a pile of PRDs to sequenced, autonomously-executed phases. `plan-pm` gains a `--roadmap` mode that inventories every PRD (new `plan-pm-roadmap-scan.sh` JSONL scanner with a derived `complete` flag), **accepts only full PRDs** — an incomplete one (missing §6 acceptance criteria, §7 exec rows, or unfinished tune stamps) exits and asks Amend-now-via-msg-flow / Skip / Stop — then analyses the survivors for bloat and overlap, proposes approval-gated `SPLIT`/`MERGE`/`FOLD`/`TRIM` reshaping (retire, never delete), sequences them into stable roadmap phases by the `depends_on`/`affects` DAG (reruns preserve existing phases), and writes `roadmap/roadmap.md`. The `/msg --gui` board gains a **Roadmap tab** (phases as lanes, PRD cards with live completion pills, tune-log accordion; `/api/roadmap` + `--view roadmap`; read-only v1). `eng --build` gains a `roadmap=` input source that turns the session into a **product-operations orchestrator**: it emits a step-by-step execution plan and asks once, then runs each phase autonomously — per PRD: acceptance-based readiness gate (same only-full-PRDs exit-and-ask), branch, parallel `eng --build` subagents (msg skills only, JSON returns), `review --min-severity high` + `test` measured against the PRD's **acceptance done-set**, a fix loop that must close every critical/major finding *and* every unmet acceptance criterion (max 5 rounds, then pause-and-escalate), `pre-merge` — with guardrails throughout (new `eng-db-touch.sh` pauses on any DB/data/prod-config touch; branch isolation; never push/merge; branches left merge-ready). Interval standup digests plus on-demand `status`; the session stays alive until the phase completes. Verified: scan + guard scripts tested against the live repo, `server.py` py_compile and `index.html` node --check pass, and the roadmap endpoint was exercised end-to-end against a sample `roadmap/roadmap.md` (including an id-separator parser fix caught in testing).

- `.claude/skills/plan-pm/SKILL.md` — declare `--roadmap` (Usage triggers, Modes line, § Roadmap mode, References)
- `.claude/skills/plan-pm/refs/protocol-roadmap.md` — new: 6-step roadmap protocol (inventory → completeness gate → analyse → gated reshaping → stable sequencing → write + GUI/exec handoff)
- `.claude/scripts/plan-pm-roadmap-scan.sh` — new: deterministic JSONL PRD inventory incl. `complete` flag
- `.claude/skills/eng/SKILL.md` — `roadmap=` third `--build` input source, Step 0 orchestrator routing, hard-failure strings, References
- `.claude/skills/eng/refs/build/protocol-roadmap.md` — new: product-operations orchestrator protocol (readiness gate, plan-first approval, phase loop, subagent contract, guardrails, reporting)
- `.claude/scripts/eng-db-touch.sh` — new: DB/data/production-config diff guardrail
- `.claude/skills/msg/refs/gui/server.py` — `build_roadmap()` parser, `/api/roadmap`, roadmap folded into `/api/data`, `--view` arg
- `.claude/skills/msg/refs/gui/index.html` — Roadmap tab (lanes, cards, tune-log accordion), router + boot default-view
- `.claude/skills/msg/refs/gui/styles.css` — roadmap lane/goal/rationale/tune-log rules on existing tokens
- `.claude/skills/msg/refs/protocol-gui.md` — document the Roadmap view, endpoint, and `--view`
- `.claude/skills/msg/SKILL.md` — `--help` gains "A roadmap" output + routing rows to `plan-pm --roadmap` / `eng --build roadmap=`
- `README.md` — plan-pm `--roadmap` + eng `roadmap=` descriptions
- `ARCHITECTURE.md` — Roadmap pipeline lane + autonomy caveat

- Slim the `plan-pm` and `plan-em` skills by extracting their step-by-step protocols into dedicated ref files, leaving each `SKILL.md` as a thin overview that points to the protocol. No behaviour change — the extracted protocols are the originals verbatim, plus a cleanup pass on `plan-em` that removes dead `refs/$MODE/` path references and repairs a broken Step 1 read-list. `plan-pm/SKILL.md` drops 307→122 lines and `plan-em/SKILL.md` 350→106; the full protocols now live in `refs/protocol-pm.md` and `refs/protocol-em.md`. A stale `plan-em/SKILL.md:88–106` line citation in `plan-tune` was repointed to the new ref.

- `.claude/skills/plan-pm/SKILL.md` — replace inline six-step protocol + multi-PRD summary with a pointer to `refs/protocol-pm.md`; add ref entry; retarget Sub-PRD "steps below" wording to the ref
- `.claude/skills/plan-pm/refs/protocol-pm.md` — new: full six-step execution protocol + multi-PRD final summary
- `.claude/skills/plan-em/SKILL.md` — replace inline five-step protocol with a pointer to `refs/protocol-em.md`; add ref entry (Step 0 todo-preference stays in `SKILL.md`)
- `.claude/skills/plan-em/refs/protocol-em.md` — new: full five-step execution protocol; drop dead `refs/$MODE/` path claims, fix Step 1 read-list numbering
- `.claude/skills/plan-tune/refs/tune-eng.md` — repoint stale `plan-em/SKILL.md:88–106` citation to `plan-em/refs/protocol-em.md`, Step 1

- Simplify the installer by dropping the `--with-cook` install option. `install.sh` no longer accepts `--with-cook`/`--cook`, drops the interactive `[1] msg / [2] msg + cook` prompt, and removes the inline cook install step — installing msg now always installs the msg skills only. In its place the completion footer prints a note pointing at the cook repo with its one-line install command, plus a dedication to JC.

- `install.sh` — remove `--with-cook`/`--cook` flag, interactive install prompt, and inline cook install; add footer note linking the cook repo + install command and a dedication

- Restructure the PRD template into a single canonical section order and separate user-goal content from engineering detail. The template (`plan-pm`) now emits eleven H2 sections in a fixed order — **Product objective** (new), Out-of-scope, User flow, Key user interactions, Error cases, Features & acceptance criteria (reframed to user goals, no eng detail), **Feature execution table** (reserved placeholder), Open questions, **Plan tune findings** (reserved), Glossary, **Todos** (reserved placeholder) — with **Target platform** removed as a body section (it survives only as frontmatter metadata). `plan-tune` now writes its audit findings as one **growing table** (create-once, append rows; `# | Date | Auditor | Severity | What is wrong | Suggested fix | Why it matters | Status`) into the reserved Plan tune findings slot instead of appending dated `## Audit` prose blocks, normalizes Open questions into a `# | Question | Answer | Status` table, and rebinds every audit dimension from brittle `§N` numbers to **section titles** (dropping the Target-platform checks). The `--gui` board parsers were made number-tolerant and taught to render the new findings table (legacy formats still parse). Stale `PRD §N` reads across `plan-em`, `eng`, and the todo/feature-table refs were repointed to section titles so the downstream pipeline still resolves. Verified: 32/32 acceptance criteria passed independent review, `server.py` py_compile + `index.html` node --check pass, and the server parsers were exercised against new, legacy, and exec-table-fallback PRDs. Feature-execution-table population (plan-em) and Todos population (`/todo`) are reserved placeholders — wiring deferred.

- `.claude/skills/plan-pm/refs/template-prd.md` — 11-section H2 canonical order; add Product objective, remove Target platform, reserve Feature execution table / Plan tune findings / Todos; Open questions + findings as tables
- `.claude/skills/plan-pm/SKILL.md` — Step 5 population map, devkit table, persona, and open-questions loop repointed to titles; drop Target platform prompt
- `.claude/skills/plan-pm/refs/template-feature-table.md` — F-IDs reference the Features & acceptance criteria section by title
- `.claude/skills/plan-tune/SKILL.md` — findings write into the reserved Plan tune findings section (create-once, append rows, status lifecycle); Open questions normalization; scan-exclusion + outputs repointed
- `.claude/skills/plan-tune/refs/tune-product.md` — single findings-table schema; title-bound Dimensions 1–4; Target-platform checks removed; eng-detail-in-criterion check added
- `.claude/skills/plan-tune/refs/tune-eng.md` — title-bind eng-plan subsections and the platform check
- `.claude/skills/msg/refs/gui/server.py`, `index.html`, `../protocol-gui.md` — number-tolerant Features/Todos/findings section matching; findings-table parse + 8-column render; legacy prose fallback
- `.claude/skills/plan-em/SKILL.md`, `eng/SKILL.md`, `eng/refs/todo/protocol-todo.md`, `eng/refs/todo/template-todo.md`, `eng/refs/plan/template-eng-plan.md` — repoint stale PRD `§N` reads to section titles
- `.claude/skills/msg-init/refs/template-DESIGN-SYSTEM.md` — component detail now recorded in the Feature execution table, not the user-flow section

- Turn `/msg --gui` from a read-only static board into a fully interactive PRD workspace. The default path now launches a local `refs/gui/server.py` bound to `127.0.0.1` that parses `features/prd-*/` (frontmatter + F-IDs + `## Todos`), infers completion, and exposes token-guarded `/api/*` endpoints so the browser board can **edit PRD bodies, change status (dropdown or drag-and-drop between columns), toggle todos, browse project docs (README, CLAUDE.md, `devkit/`), and run Claude prompts from a console** — with all writes confined to `features/prd-*/` markdown. The client gained an offline, injection-safe markdown→HTML renderer (headings, fenced code, blockquotes, tables, nested/checkbox lists, inline formatting), `## `-split section accordions, a plan-tune findings table (product `## Audit` + eng `### 12. Findings`), a light/dark theme toggle, toasts, and modals. When `python3` is unavailable or a read-only snapshot is wanted, the same file falls back to the static template + data-fill path — identical board, editing UI hidden, nothing ever written.

- `.claude/skills/msg/refs/gui/server.py` — new local `127.0.0.1` API server exposing `/api/*` for PRD edits, status changes, todo toggles, the prompt console, and the file viewer; writes confined to `features/prd-*/`
- `.claude/skills/msg/refs/gui/index.html` — live-mode client plumbing (token/ping, fetch API, data refresh), markdown renderer, section accordions, findings parsing, drag-and-drop status, theme toggle, toasts, modals
- `.claude/skills/msg/refs/gui/styles.css` — interactive-board styling, light/dark themes, modal scrim + dialog, toast, drag-over/drop states
- `.claude/skills/msg/refs/protocol-gui.md` — rewrite for interactive-default mode (server launch, API contract) with the static snapshot as fallback
- `.claude/skills/msg/SKILL.md` — describe the interactive board surface (editing, todos, prompt console, project docs)
- `.claude/skills/plan-em/prefs.json` — pref tweak
- `.gitignore` — ignore gui runtime artifacts
- `ARCHITECTURE.md`, `README.md` — reflect the interactive `--gui` board

- Add a persistent test-issue tracker (Feature 6) that closes the loop from a non-clean `/test` run to the thing that fixes it. `/test` gains a new **Step 6**: when the aggregated verdict is `fail`/`pass_with_warnings` (a clean `pass`/`refused` writes nothing and asks nothing), it creates `msg-test/` at the repo root on demand, numbers the next ticket `max(numeric suffix of test-*.json) + 1` (or `1`), and writes `msg-test/test-<n>.json` — a self-contained ticket carrying `context` (prd/branch/base, reused from Step 2), `source_run`, `summary`, the Step 5 `findings[]` copied **verbatim as canonical findings**, and a `follow_up` pointer. A second, conditional `AskUserQuestion` (scoped to this step, reconciled against the "exactly ONE gate" hard-refusal) offers **Fix now** / **Investigate first** / **Not now**. `eng --build` gains a **`test-json` input path** (build-only; both `prd-path` and `test-json` is a hard failure; `agent` defaults to `eng-fix`; `branch` defaults to the file's `context.branch`) that projects each finding into an issue-ticket standing in for an exec-table row, then runs a three-phase fix flow — **(a) reproduce → (b) fix via `/cook` → (c) verify green** (Item 0 skipped, flaky issues fixed only on a reproducible root cause) — and writes `follow_up.status` `open → resolved`/`partially_resolved` on completion. A single read-time **finding→ticket projection** (with a `kind` discriminator, `todo` vs `issue`) is defined once in `template-todo.md` and consumed by both `eng --build` and `--gui`; the on-disk file stays canonical findings. The `/msg --gui` board renders a distinct **🐞 Test Issues** grouping (one card per file with `runId`, verdict pill, `summary` counts, `followUp.status`), an issue-detail page, issue-ticket cards with a kind tag + `severity` pill, a `repro`+`evidence.snippet` side panel, honest `open`/`resolved`/`partially_resolved` done-state read from the file (never invented), and a PRD cross-link surfacing an issue file's tickets on a matching PRD's detail page tagged `kind:"issue"`. Verified: the GUI app JS passed `node --check`, a jsdom harness rendered the real filled template against a dummy `msg-test/test-1.json` for 41/41 assertions with zero render errors, and the Step 6 numbering + template shape were unit-tested.

- `.claude/skills/test/SKILL.md` — new Step 6 (conditional ticket write + follow-up gate); `msg-test/` numbering + template; reconciled the single-gate hard-refusal; Inputs/Outputs + References
- `.claude/skills/eng/SKILL.md` — Step 1 `test-json` alternate input (build-only, ambiguous-source + missing/unparseable hard-refusals); Step 2 finding-projection pre-flight branch
- `.claude/skills/eng/refs/build/protocol.md` — `test-json` input contract + `context.branch` default; three-phase fix flow; flaky handling; `Issue`-keyed summary; `follow_up.status` writeback
- `.claude/skills/eng/refs/todo/template-todo.md` — new: shared finding→issue-ticket projection, `kind` discriminator, field mapping, preserved diagnostic fields
- `.claude/skills/msg/refs/protocol-gui.md` — new Step 1b (`msg-test/` glob); `testIssues[]` data contract; Test Issues surface, done-state, PRD cross-link notes
- `.claude/skills/msg/refs/gui/index.html` — `testIssues` load + projection helpers; Test Issues surface + issue-detail route; kind/severity rendering; repro/snippet panel; PRD cross-link
- `.claude/skills/msg/refs/gui/styles.css` — 🐞 kind tag, severity pills, verdict pills, issue-card accent, Test Issues grid, cross-link style

- Document the `eng --todo` mode in the human-facing docs (follow-up to the feature commit): README's `/eng` row now lists all three modes and notes `--build` is todos-first (falling back to exec-table rows); ARCHITECTURE's execution pipeline shows `eng --plan → eng --todo → eng --build` with a note that the todo phase runs only when `plan-em`'s `prefs.json` `todos` toggle is on, and the skill-inventory row for `eng` adds `--todo`. `install.sh` is unchanged — it installs skill files and never enumerated eng modes.

- `README.md` — `/eng` row: add `--todo`, reword `--build` as todos-first
- `ARCHITECTURE.md` — execution pipeline + `eng` inventory row note the `--todo` phase and its `prefs.json` gate

- Add `eng --todo`, a third eng mode between `--plan` and `--build` (design doc → task breakdown → build). It reads the confirmed `## Engineering — <Agent>` section(s) plus the PRD's F-ID feature table and decomposes each F-ID into agent-executable **tickets** under a `## Todos — <Agent>` sub-heading (one `### F<n>` block per feature; empty features get an explicit `_No discrete work_` block so the anchor still resolves). Each ticket is modelled on a JIRA/Linear ticket minus estimation: `id` (`F<n>-T<k>`), `title`, `objective` (the product/user goal it serves), `type` (`code|test|config|migration|doc`), `priority` (`P0|P1|P2` — a build-order signal, not story points), `files` (each tagged `add|edit|remove`), `depends-on` (ticket ids, kept acyclic), and `done-when` (a verifiable acceptance check). `plan-em` owns the layer: a new Step 0 resolves a persisted `todos` boolean in `.claude/skills/plan-em/prefs.json` (set on first run by scanning for a pre-existing user task-breakdown skill — found → defer/off, none → on), which gates a new **Todos** column in the Step 3 execution table (`[F<n>](#todos-f<n>)` anchors), a three-state Step 4 mode detection (plan → todo → build), a todo-phase dispatch branch, and a Step 5 "Run todo breakdown" handoff. `eng --build` now prefers a feature's tickets and walks them in dependency order (higher priority first among the unblocked), falling back to exec-table rows when no todos exist and hard-stopping when neither exists. The already-shipped `/msg --gui` board was migrated to consume the ticket shape — parser, data contract, and the card/table/side-panel renderer now surface id, objective, priority, files, and depends-on (no stored `done` state; `done-when` is the check, not a status).

- `.claude/skills/eng/SKILL.md` — add `--todo` to Step 0 routing (between `--plan`/`--build`), input validation, mode divergence, references; frontmatter now three modes
- `.claude/skills/eng/refs/todo/protocol-todo.md` — new: `--todo` work steps — read engineering section + F-ID table, decompose into tickets, validate ids/dependencies
- `.claude/skills/eng/refs/todo/template-todo.md` — new: JIRA/Linear ticket schema, `## Todos` structure, per-`### F<n>` block rules
- `.claude/skills/eng/refs/build/protocol.md` — prefer tickets over exec-table rows; dependency-ordered build; hard-stop when neither exists
- `.claude/skills/plan-em/SKILL.md` — Step 0 `prefs.json` todo-preference; Todos column; three-state mode detection; todo-phase branch; Step 5 handoff
- `.claude/skills/plan-em/refs/template-exec-table.md` — optional Todos column with `#todos-f<n>` anchors
- `.claude/skills/msg/refs/protocol-gui.md` — parse tickets (id/objective/priority/files/depends-on) into the data contract, keep legacy single-file compat
- `.claude/skills/msg/refs/gui/index.html` — render ticket fields in card, table, and side panel
- `.claude/skills/msg/refs/gui/styles.css` — priority pills, multi-line panel field values

- Add `/msg --gui`: a local-only, read-only static-HTML board over `features/prd-*/`. The bare word `/msg gui` and natural-language triggers ("show me the PRD board", "open kanban", "visualize my PRDs") route straight to rendering — via a new `## Dispatch` block and `Protocol: --gui` section in `msg/SKILL.md`, with no picker and no `AskUserQuestion`. The new `refs/protocol-gui.md` enumerates PRDs (including nested sub-PRDs), parses frontmatter, F-ID rows (`## 3. Features & acceptance criteria` → `## Execution Table` fallback) and any `## Todos`, infers each PRD's completion bucket (branch → open PR → last `pre-merge` → frontmatter `status`), fills the `refs/gui/` templates with the collected data as inline JSON, and serves the result GET-only via `python3 -m http.server --bind 127.0.0.1`, opening the default browser. The board is a pure read model: a list page (Kanban ↔ Table toggle, cards grouped into `product/eng/building/review/shipped` columns with tuned/reviewed pills and a todo progress fraction) → a per-PRD detail page (collapsible full PRD body + a TODOs section with its own Kanban ↔ Table toggle and a per-todo side panel showing type/file/action/done-when). Nothing is editable and no PRD file is ever written. The Notion/Legora/Manus look is hardcoded in `refs/gui/styles.css`, identical across every project. With Feature 2's persisted todo `done` field not yet shipped, the GUI degrades gracefully — PRDs with no todos show no fraction (never `0/0`), and where todos exist every item renders Open.

- `.claude/skills/msg/SKILL.md` — add `--gui` dispatch + `Protocol: --gui`; widen `allowed_tools` to add Read/Write/Bash
- `.claude/skills/msg/refs/protocol-gui.md` — new: enumerate PRDs, parse frontmatter/F-IDs/todos, infer completion, fill templates, serve GET-only via `python3 -m http.server`
- `.claude/skills/msg/refs/gui/index.html` — new: self-contained SPA template (kanban/table list, per-PRD detail, todo side panel, hash router)
- `.claude/skills/msg/refs/gui/styles.css` — new: hardcoded Notion/Legora/Manus design system
- `.claude/kermit/pref.json` — bump last_logged_commit pointer

- Add sub-PRD follow-up scope: `/plan-pm --sub [parent path|number]` (plus natural-language triggers like "create a sub-PRD" / "more changes to PRD N") spins off a numbered follow-up PRD (`prd-<n>.<m>`) nested under an existing parent and built on the parent's existing feature branch rather than a new one. Parent is resolved by explicit arg → current-branch inference (`feat/prd-<n>-<slug>`) → an `AskUserQuestion` picker; intake is pre-seeded with the parent title; the sub-PRD gets a new `parent:` frontmatter field and inherits the parent's `module`/`platform`. `scan-n.prd` gains a `sub <parent-n>` mode returning the next nested minor (`.1` if none, numeric-boundary safe); `plan-em`'s build-mode branch step becomes parent-aware and idempotent (reads `parent:`, resolves the parent branch, `git branch --list` → checkout-or-create) and accepts the nested sub-PRD path form; `eng --build` gains the same parent-aware `branch` default for direct invocations; `review` Step 7 prints a sub-PRD next-step offer (no new question). The design named `ship` as the branch owner, but `ship` is no longer in the repo, so that logic landed in `plan-em`, the extant orchestrator. Also bundles an unrelated README credits note and a kermit pointer bump.

- `.claude/scripts/scan-n.prd` — new `sub <parent-n>` next-minor resolver
- `.claude/skills/plan-pm/SKILL.md` — `--sub` mode: triggers, parent resolution, pre-seeded intake, nested path, `parent:` frontmatter
- `.claude/skills/plan-pm/refs/template-prd.md` — document optional `parent:` frontmatter field
- `.claude/skills/plan-em/SKILL.md` — parent-aware + idempotent branch create/checkout; accept nested sub-PRD paths
- `.claude/skills/eng/refs/build/protocol.md` — parent-aware `branch` default for direct sub-PRD builds
- `.claude/skills/review/SKILL.md` — Step 7 prints a sub-PRD next-step offer
- `README.md` — add credits note
- `.claude/kermit/pref.json` — bump last_logged_commit pointer

- Make `/test` run buckets in parallel by default: dispatch each selected, non-skipped bucket as its own `Agent` subagent (replacing the old sequential 1→10 default), carve `load` and `perf` out of the concurrent batch to run isolated so contention can't skew their numbers, and stream each bucket's verdict as its subagent returns before a single final aggregation pass. **Breaking:** the `--fast` flag is removed (ignored with a printed note if passed, not a hard error) and a new `--sequential` flag restores the old in-order in-process run. Propagated through the frontmatter description, Step 3 plan-header tags, the Step 5 aggregator `--parallel` note, `refs/schema.md`'s `parallel` field semantics, and the seven `refs/modes/*` "When it runs" lines that referenced `--fast` (`load`/`perf` reworded to note isolation).

- Remove `plan` and `ship` autonomous orchestrator skills: delete `.claude/skills/plan/SKILL.md` and `.claude/skills/ship/SKILL.md` along with their supporting scripts (`ship-find-prd.sh`, `ship-db-touch.sh`) and settings.json permissions; drop `plan`/`ship` rows and the autonomous-loop-shortcuts section from msg's skill menu and routing tables; remove `/plan` and `/ship` entries from README.md; update ARCHITECTURE.md's pipeline diagram and skill inventory for standalone-only invocation; remove the completed `19-plan-loop-modes` improvement plan/acceptance docs and its `_INDEX.md` entry.

- Sync `kermit`'s `last_logged_commit` pointer in `.claude/kermit/pref.json` to the latest changelog-synced commit.

- Fix msg-init stack detection: carry `STACK_HINTS` through from `init-setup.sh` alongside `PRESENT`/`MISSING`/`STACK_DEFAULT`, skip the platform question only when `STACK_HINTS` has exactly one entry (assigning `PLATFORM` directly) and otherwise pre-select `STACK_DEFAULT` as the question's default; remove a stray `.dart_tool/` duplicate line from the gitignore template.

- Sync `kermit`'s `last_logged_commit` pointer in `.claude/kermit/pref.json` to the latest changelog-synced commit.

- Fix msg skill routing: split hands-off/step-by-step disambiguation for categories with more than 4 rows in Step 2 of the dispatch protocol; add missing `plan` and `ship` rows to the routing table for rough-idea inputs; correct the Reviewing/engineering-plan routing target from `improve` to `eng`.

- Sync `kermit`'s `last_logged_commit` pointer in `.claude/kermit/pref.json` to the latest changelog-synced commit.

- Add `/test --flaky <N>` and `--changed-only` modes: retry failing unit/e2e tests up to N times before counting them as real failures (reclassified with `evidence.flaky`/`evidence.retries` and a `totals.flaky` count); skip whole buckets whose surface a diff doesn't touch when `--changed-only` is paired with `--base`, failing open on ambiguous classification. Restructure `/plan-tune` from 5 to 4 steps, add a `devkit/GLOSSARY.md` §8 cross-check, dedup findings against prior `## Audit` sections with a no-findings clean path, and add Dimension 5g cross-PRD breaking-change consistency to the eng tune. Add an eng-plan self-consistency check (§7 identifiers must appear in Execution steps) and unpin eng's model (warns on Haiku sessions instead).

- Fix 8 pre-merge correctness bugs and cleanup: remove leaked eval_set_path from output schema, delete dead prd_criteria[] input threading, harden resolve-diff.sh with visible git-fetch errors and proper JSON escaping, collapse inconsistent skipped[]/skipped_buckets[] naming, align package-manager examples (npx vs pnpm) and add substitution guidance, delete duplicate detect-tooling.sh script (use shared tooling-detection.md instead), and archive stale pre-merge-plan.md with deprecation notice

- Align /test and /review finding output to the canonical shared finding schema: switch severity from fail/warn to high/medium and nest evidence as an object (tool/file/line/snippet, plus bucket-owned extension keys like mobile's platform/device) across all nine /test mode refs; move assertion classification into /review Step 3 so Coverage and Functional modes share one classification instead of duplicating it, and add an undetected_domain_note surface warning for changed files with no /cook standards shelf; scope FLAG-LIST.md to domain detection only; fix stale §6→§7 and §2→§1 section cross-references in plan-pm; add a multi-platform priority table format to the PRD template

- Remove docu and todo skills: delete SKILL.md, refs/, and scripts/ for both; strip docu and todo from the msg dispatch table, pipeline diagram, and routing table; remove /docu step and hard-refusal note from review pipeline; drop skill references from ARCHITECTURE.md and README.md

- Add pre-flight cross-check step to build protocol: before reading any file, verify the §Engineering section is consistent with the exec-table (every assigned row present, non-blank Execution steps, referenced in §Engineering); surface missing/blank rows as a blocking gap via AskUserQuestion. Tag AHA entries with `severity: escalated` when written at the 3rd failed debug cycle.

- Fix undocumented hidden behaviour and naming convention collision in eng skill: add "Caller override" notes to build/protocol.md Step 5 (full-suite gate) and Step 6 (commit gate) so auditors know ship suppresses both; add a shared-contract warning for the `## Engineering — <Agent>` heading in SKILL.md References; replace `backend-eng`/`mobile-eng` with the correct `eng-backend`/`eng-ios` format across SKILL.md, template-eng-plan.md, and protocol-exec.md so worked examples match the agent naming format plan-em actually produces

- Fix four factual errors in eng skill docs: remove non-existent `--review` mode from the msg router menu entry; fix field count from "shared three" to "shared four" (adds `agent`) in both plan and build mode protocols; replace "single target platform" with "agent's owned stack" in template §1 and §5 (multi-agent PRDs run one eng per stack, not one per platform); label `CLAUDE.md` as project root in the eng pre-flight ref table to distinguish it from `devkit/`-prefixed entries

- Remove completed skills audit plan (update-plan.md) and add update/, update-plan.md, update-plan-done.md to .gitignore

- Align skills pipeline to devkit/ layout, slugged PRD paths (prd-[n]-[slug]), and eng commit-mode contract: migrate all ARCHITECTURE.md/AHA.md/GLOSSARY.md references to devkit/ prefix; add §3 Features & acceptance criteria table to plan-pm PRD template with stable F-IDs carried through to plan-em; add commit_mode direct/sub-branch branch contract to eng --build with direct as default under ship; stamp product-tuned/eng-tuned frontmatter on plan-tune runs; extract shared finding schema to shared/refs/finding-schema.md; align pre-merge, review, test schemas; rewrite plan-tune product-tune dimension checks against new section numbering

- Add source-keyed deduplication to /todo: tasks now carry a `source` field (`<origin>:<stable-key>`) derived deterministically from the source item; append-tasks.sh drops any incoming task whose source already exists in TODOs.json and de-duplicates within the batch, so re-running /todo on the same PRD never doubles tasks; update schema.json to require source, parsing-rules.md with slug rules per input type, and SKILL.md with the assignment step; wire kermit into the msg router skill table and routing table; add update-plan.md with a comprehensive audit of 15 msg skills covering cross-cutting contract failures and per-skill findings

- Add ARCHITECTURE.md documenting MSG layers, scripts, devkit, skill inventory, pipelines, and cook integration; update README skill table with expanded msg-init description and new /plan and /ship entries

- Expand msg-init bootstrap from 5 to 7 steps: add architecture interview (Step 3, five questions covering components, external services, data stores, auth, deployment) and design system interview (Step 4, four questions covering UI layer, component library, tokens, conventions); pass ARCH_* and DS_* env vars to init.sh; replace [USER:] stubs in template-ARCHITECTURE.md and template-DESIGN-SYSTEM.md with {{arch_*}} and {{ds_*}} placeholders; update plan-tune to write full audit section to PRD file and emit a terse per-finding summary table inline; update kermit pref.json with auto_approve/auto_commit/auto_merge flags

- Update kermit pref.json with automation preference flags (auto_approve, auto_commit, auto_merge) and refreshed init_commit SHA

- Ensure installed scripts are executable: chmod +x .sh files and scan-n.prd after copy, and chmod +x any .sh files bundled inside skill directories

- Wire the `/test` skill into the `/ship` pipeline as a dedicated Test stage: restructure the review→fix loop into review → test → fix (loops until both `/review` and `/test` report no issues); route full-suite verification through `/test`, consuming the eval_set via `--eval-set` (falling back to `--prd`), instead of raw runner commands; instruct build agents to skip eng's raw-runner full-suite gate while keeping their per-feature TDD red/green checks; update the pipeline diagram, five-stage table, autonomy contract, permission gates, fix prompt, final summary, and references

- Remove the `design` skill and its `creativity-levels.md` / `ux-laws.md` refs; drop design from the msg menu, routing table, and pipeline diagram, and from the README skill list; rewrite `/plan` from an autonomous loop into a single-pass sequential driver (plan-pm → plan-tune --product → plan-em → plan-tune --eng, each run once with its own gates intact); document ship's four-stage pipeline and align its step titles to the Build / Review → Fix / Pre-merge stages

- Add `/test --init` setup mode: profiles codebase shape, computes the gap against installed runners, gates on a plan, optionally installs tools, and writes a `.claude/test/test.json` cache the execution path reads; add deterministic `test-init-profile.sh` shape profiler and `refs/modes/init.md` decision tables + schema; bootstrap the development eval_set via `/test --prd` in plan-em plan mode and note it in the /plan loop; allow profiler script, test scaffold paths, and test-skill edits in settings.json

- Extract autonomous loop orchestration into new /plan and /ship skills; remove inline --loop / --from-loop modes from eng, plan-pm, plan-tune, and plan-em; add ship-find-prd.sh and ship-db-touch.sh helpers; wire plan/ship into the msg menu; add skill Edit permissions, ship script allowances, and a $CLAUDE_PROJECT_DIR-resolved changelog gate path to settings.json

- Add PRD status lifecycle table to plan-pm (split `tuned` into `product-tuned`, `eng-tuned`, `reviewed`); add §3 per-feature supplement for design-system components and files-touched; update next-step and loop handlers to patch frontmatter after each skill run; update template-prd.md to match

- Add loop mode to plan-pm, plan-em, plan-tune, and eng --build; upgrade next-step prompts from recommend to invoke; add --from-loop flag to plan-tune with [LOOP: PASS/FAIL] signal; add --review flag and adversarial Opus review to improve skill; add review-protocol.md reference

- Add feature-slug suffix to PRD directory and file names (prd-N → prd-N-[slug]); update plan-tune-preflight and scan-n.prd scripts for slugged paths; add improve plan #19 for --loop orchestration; extend .gitignore with al-*.jsonl, evals/, improve subdirs, scheduled tasks lock
- Resolve helper script paths in plan-tune/test/plan-pm independent of cwd, with $HOME/.claude/scripts fallback (fixes exit 127); untrack improve plans, evals, and pre-merge planning artifacts
- Apply eval fixes to eng skill: row matching, agent field, branch locking, test gates
- Remove handoff tracking files and add to .gitignore
- Integrate design skill into msg routing, menu, and handoff; add Figma MCP preflight validation and post-merge evaluation plan
- Add ux-design skill with UX design planning, creativity tiers, and UX laws reference
- Force reinstall of skills and scripts instead of skipping existing ones
- Remove install-standards script and related setup documentation
- Enhance installation script with next steps and GitHub repository update link
- Add deterministic test tooling detection and verdict aggregation scripts to replace manual priority-table walking in /test skill

- Expand tooling-detection rules for bun, biome, oxlint, pip-audit, osv-scanner, webpack, astro, svelte, size-limit

- Add installation script and instructions to README

- Add coverage and mobile test modes to /test skill; update skill suite (eng, handoff, msg-init, msg, plan-em, plan-pm, plan-tune, review, todo)

- Add `/pre-merge` skill with integration, e2e, build, security, and bundle gates
- Reorder improve/_INDEX.md rows to restore monotonic ID sequence
- Add `/test` skill for execution-focused testing (unit, e2e, functional assertions) with eval_set handoff from `/review`
- Refactor `/review` to split test execution: Coverage is now static-only (sibling-test + assertion-reference checks); Functional defers executable assertions to `/test`
- Archive completed 15-review-test-split improvement to done/ subdirectory
- Add review-test-split skill, pre-merge skill, shared tooling-detection refs, and reorganize improve registry numbering
- Add mechanical gates to Quality and Security modes in /review
- Add plan registry (_INDEX.md) to improve skill for centralized plan tracking
- Archive completed improve skills (preflight-rigor, quality-mode-rigor) to done/ subdirectory
- Add Quality-mode rubric, scope-creep wiring via `uncovered_changes[]`, and `(file, line, category)` dedup pass to `/review`
- Add `/review` skill with preflight rigor: eval-set discovery from tests/schemas, FLAG-LIST.md consolidation, main-branch support, flag inventory validation

### Add handoff skill; refactor eng skill to modular protocols

- `.claude/skills/eng/SKILL.md`
- `.claude/skills/eng/refs/build/protocol.md`
- `.claude/skills/eng/refs/plan/protocol.md`
- `.claude/skills/eng/refs/review/protocol.md`
- `.claude/skills/handoff/SKILL.md`
- `.claude/skills/improve/7.1-eng-build/acceptance.md`
- `.claude/skills/improve/7.1-eng-build/plan.md`
- `.claude/skills/improve/7.3-eng-review/acceptance.md`
- `.claude/skills/improve/7.3-eng-review/plan.md`
- `.claude/skills/improve/done/7.2-eng-plan/acceptance.md`
- `.claude/skills/improve/done/7.2-eng-plan/plan.md`
- `.claude/skills/improve/done/8-handoff/acceptance.md`
- `.claude/skills/improve/done/8-handoff/plan.md`
- `handoff/1.md`

---

### `a009b15` — Add CHANGELOG gate hook and `eng` engineering skill

- `.claude/scripts/changelog-gate.py`
- `.claude/settings.json`
- `.claude/skills/eng/SKILL.md`
- `CHANGELOG.md`

---

### `124cfec` — Add agent-creation routing to `/improve`; reorganize devkit

- `.claude/skills/improve/SKILL.md`
- `.claude/skills/improve/done/9-agent-creation-option/acceptance.md`
- `.claude/skills/improve/done/9-agent-creation-option/plan.md`
- `.claude/skills/msg-init/SKILL.md`
- `.claude/skills/msg-init/init-setup.sh`
- `.claude/skills/msg-init/init.sh`
- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-em/refs/build/protocol-eng-agent.md`
- `.claude/skills/plan-em/refs/plan/protocol-eng-agent.md`
- `.claude/skills/plan-pm/SKILL.md`

---

### `d8e4b00` — Add session-handoff plan to `/improve`; fix `AskUserQuestion` usage

- `.claude/skills/improve/8-handoff/acceptance.md`
- `.claude/skills/improve/8-handoff/plan.md`
- `.claude/skills/improve/SKILL.md`

---

### `8e56788` — Split `7-dev-agent` into three focused sub-skill plans

- `.claude/skills/improve/7-dev-agent/acceptance.md`
- `.claude/skills/improve/7-dev-agent/plan.md`
- `.claude/skills/improve/7.1-eng-build/acceptance.md`
- `.claude/skills/improve/7.1-eng-build/plan.md`
- `.claude/skills/improve/7.2-eng-plan/acceptance.md`
- `.claude/skills/improve/7.2-eng-plan/plan.md`
- `.claude/skills/improve/7.3-eng-review/acceptance.md`
- `.claude/skills/improve/7.3-eng-review/plan.md`
- `.claude/skills/improve/2-plan-major-enhancement/acceptance.md`
- `.claude/skills/improve/2-plan-major-enhancement/plan.md`
- `.claude/skills/improve/done/2-plan-major-enhancement/acceptance.md`
- `.claude/skills/improve/done/2-plan-major-enhancement/plan.md`

---

### `cba7b8a` — Add dev-agent improve plan; triage backlog; streamline `plan-em`

- `.claude/skills/improve/7-dev-agent/acceptance.md`
- `.claude/skills/improve/7-dev-agent/plan.md`
- `.claude/skills/improve/backlog/4-msg-health/acceptance.md`
- `.claude/skills/improve/backlog/4-msg-health/plan.md`
- `.claude/skills/improve/backlog/5-msg-insights/acceptance.md`
- `.claude/skills/improve/backlog/5-msg-insights/plan.md`
- `.claude/skills/improve/backlog/6-msg-learnings/acceptance.md`
- `.claude/skills/improve/backlog/6-msg-learnings/plan.md`
- `.claude/skills/improve/done/3-msg-root-skill/acceptance.md`
- `.claude/skills/improve/done/3-msg-root-skill/plan.md`
- `.claude/skills/plan-em/SKILL.md`

---

### `9f44471` — Add `/msg` root menu skill for discovery

- `.claude/skills/msg/SKILL.md`
- `.gitignore`

---

### `4d234a2` — Add `/improve` skill; restructure `plan-em` refs into build/plan subdirs

- `.claude/settings.json`
- `.claude/skills/improve/SKILL.md`
- `.claude/skills/improve/refs/template.md`
- `.claude/skills/improve/done/1-split-protocol-refs/acceptance.md`
- `.claude/skills/improve/done/1-split-protocol-refs/plan.md`
- `.claude/skills/improve/2-plan-major-enhancement/acceptance.md`
- `.claude/skills/improve/2-plan-major-enhancement/plan.md`
- `.claude/skills/improve/3-msg-root-skill/acceptance.md`
- `.claude/skills/improve/3-msg-root-skill/plan.md`
- `.claude/skills/improve/4-msg-health/acceptance.md`
- `.claude/skills/improve/4-msg-health/plan.md`
- `.claude/skills/improve/5-msg-insights/acceptance.md`
- `.claude/skills/improve/5-msg-insights/plan.md`
- `.claude/skills/improve/6-msg-learnings/acceptance.md`
- `.claude/skills/improve/6-msg-learnings/plan.md`
- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-em/refs/build/protocol-eng-agent.md`
- `.claude/skills/plan-em/refs/build/protocol-exec.md`
- `.claude/skills/plan-em/refs/plan/protocol-eng-agent.md`
- `.claude/skills/plan-em/refs/plan/template-eng-plan.md`
- `README.md`

---

### `de51e9a` — Remove standalone scripts; consolidate logic inline into skills

- `.claude/scripts/check-staged.sh`
- `.claude/scripts/detect-platform.sh`
- `.claude/scripts/plan-em-eng-scan.sh`
- `.claude/scripts/validate-prd.sh`
- `.claude/skills/msg-commit/SKILL.md`
- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-pm/refs/protocol-interview.md`
- `.gitignore`
- `README.md`

---

### `0e7a4d8` — Remove `eng-web` skills and scripts after consolidation

- `.claude/scripts/eng-web-build-preflight.sh`
- `.claude/scripts/eng-web-plan-check-prd.sh`
- `.claude/scripts/eng-web-plan-extract-rows.sh`
- `.claude/settings.json`
- `.claude/skills/eng-web-build/SKILL.md`
- `.claude/skills/eng-web-build/refs/performance.md`
- `.claude/skills/eng-web-build/refs/testing.md`
- `.claude/skills/eng-web-plan/SKILL.md`

---

### `9012b50` — Harden `plan-tune` preflight into script; split `tune.md` by mode

- `.claude/scripts/plan-tune-preflight.sh`
- `.claude/skills/plan-tune/SKILL.md`
- `.claude/skills/plan-tune/refs/tune-eng.md`
- `.claude/skills/plan-tune/refs/tune-product.md`
- `.claude/skills/plan-tune/refs/tune.md`

---

### `2be7b06` — Add two tune modes to `plan-tune` with dimension 5 eng audit

- `.claude/skills/plan-tune/SKILL.md`
- `.claude/skills/plan-tune/refs/tune.md`

---

### `38af510` — Move `msg-commit` protocol rules inline; add auto-trigger hook

- `.claude/settings.json`
- `.claude/skills/msg-commit/SKILL.md`
- `.claude/skills/msg-commit/refs/protocol.md`

---

### `3d3e4af` — Add on-demand performance and testing refs for `eng-web`

- `.claude/scripts/eng-web-build-preflight.sh`
- `.claude/skills/eng-web-build/SKILL.md`
- `.claude/skills/eng-web-build/refs/performance.md`
- `.claude/skills/eng-web-build/refs/testing.md`
- `.claude/skills/eng-web-plan/SKILL.md`

---

### `d3e6a02` — Add preflight and extraction scripts to `eng-web` skills

- `.claude/scripts/eng-web-build-preflight.sh`
- `.claude/scripts/eng-web-plan-check-prd.sh`
- `.claude/scripts/eng-web-plan-extract-rows.sh`
- `.claude/skills/eng-web-build/SKILL.md`
- `.claude/skills/eng-web-plan/SKILL.md`

---

### `c46c303` — Add `CHANGELOG.md` and `OPEN-QUESTIONS.md` templates to `msg-init`

- `.claude/skills/msg-init/SKILL.md`
- `.claude/skills/msg-init/init-setup.sh`
- `.claude/skills/msg-init/init.sh`
- `.claude/skills/msg-init/refs/template-CHANGELOG.md`
- `.claude/skills/msg-init/refs/template-OPEN-QUESTIONS.md`
- `.claude/skills/eng-web-build/SKILL.md`
- `.claude/skills/eng-web-build/refs/protocol-build.md`
- `.claude/skills/eng-web-plan/SKILL.md`
- `.claude/skills/plan-em/SKILL.md`

---

### `c438a5a` — Split `eng-web` into separate plan and build skills

- `.claude/skills/eng-web-build/SKILL.md`
- `.claude/skills/eng-web-build/refs/protocol-build.md`
- `.claude/skills/eng-web-plan/SKILL.md`
- `.claude/skills/eng-web/SKILL.md`

---

### `ce1ca7f` — Add `eng-web` SKILL.md definition

- `.claude/skills/eng-web/SKILL.md`

---

### `b6e3905` — Add `DESIGN-SYSTEM.md` template to `msg-init` for component registry tracking

- `.claude/skills/msg-init/SKILL.md`
- `.claude/skills/msg-init/init-setup.sh`
- `.claude/skills/msg-init/init.sh`
- `.claude/skills/msg-init/refs/template-DESIGN-SYSTEM.md`
- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-pm/SKILL.md`

---

### `60e845b` — Clarify `plan-em` two-mode protocol; suggest branch names at synthesis

- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-em/refs/protocol-eng-agent.md`
- `.claude/skills/plan-em/refs/template-eng-plan.md`
- `.claude/skills/msg-init/refs/template-CLAUDE.md`
- `.claude/skills/msg-init/refs/template-GLOSSARY.md`

---

### `bc7f8a3` — Add `plan-em-eng-scan.sh` for deterministic codebase search

- `.claude/scripts/plan-em-eng-scan.sh`
- `.claude/skills/plan-em/SKILL.md`

---

### `00f0f19` — Add multi-PRD dependency and conflict tracking via frontmatter

- `.claude/scripts/plan-em-eng-scan.sh`
- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-pm/SKILL.md`
- `.claude/skills/plan-pm/refs/template-prd.md`

---

### `8cf629b` — Rename `plan-pm` interview protocol ref to `protocol-interview`

- `.claude/skills/plan-pm/SKILL.md`
- `.claude/skills/plan-pm/refs/interview-protocol.md`
- `.claude/skills/plan-pm/refs/protocol-interview.md`

---

### `0657d92` — Add multi-PRD mode and execution step protocol to `plan-em`

- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-em/refs/protocol-exec.md`
- `.claude/skills/plan-em/refs/template-exec-table.md`
- `.claude/skills/plan-pm/SKILL.md`

---

### `b97ceb1` — Defer execution step format to per-agent specs in `plan-em`

- `.claude/skills/plan-em/refs/template-exec-table.md`

---

### `d511067` — Rename RFC template to `eng-plan`; add execution table template

- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-em/refs/principles.md`
- `.claude/skills/plan-em/refs/template-eng-plan.md`
- `.claude/skills/plan-em/refs/template-exec-table.md`
- `.claude/skills/plan-em/refs/template-rfc.md`

---

### `0e9fd9c` — Remove problem statement; add open questions loop and expand integration contracts

- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-em/refs/template-rfc.md`
- `.claude/skills/plan-pm/SKILL.md`
- `.claude/skills/plan-pm/refs/template-prd.md`

---

### `a51f474` — Consolidate `plan-em` refs; redesign agent orchestration

- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-em/refs/emit-protocol.md`
- `.claude/skills/plan-em/refs/scope-matrix.md`

---

### `488658b` — Add `platform`, `status`, and `tuned` fields to `plan-pm` PRD template

- `.claude/skills/plan-pm/SKILL.md`
- `.claude/skills/plan-pm/refs/template-prd.md`

---

### `efb475f` — Consolidate `plan-tune` spec audit details into `refs/tune.md`

- `.claude/skills/plan-tune/SKILL.md`
- `.claude/skills/plan-tune/refs/tune.md`

---

### `dabf369` — Add Flutter, Expo, Desktop, and Backend to `detect-platform`

- `.claude/scripts/detect-platform.sh`

---

### `29c3529` — Conditionally capture `AHA.md` in `plan-pm` and `plan-em`

- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-pm/SKILL.md`

---

### `60c2764` — Include `CLAUDE.md` in `plan-pm` foundational files check

- `.claude/skills/plan-pm/SKILL.md`

---

### `1c8f42d` — Clarify `plan-pm` PRD steps; extract error template ref

- `.claude/skills/plan-pm/SKILL.md`
- `.claude/skills/plan-pm/refs/template-error.md`
- `.claude/skills/plan-pm/refs/template-prd.md`
- `.claude/skills/plan-tune/SKILL.md`
- `.claude/skills/plan-tune/refs/tune-checklist.md`
- `.claude/skills/plan-tune/refs/tune.md`

---

### `3560da2` — Fix `plan-tune` audit findings for specificity and consistency

- `.claude/skills/plan-tune/SKILL.md`
- `.claude/skills/plan-tune/refs/tune-checklist.md`

---

### `fc4cbbd` — Simplify `plan-pm` interview; auto-detect platform; always recommend features

- `.claude/scripts/detect-platform.sh`
- `.claude/skills/plan-pm/SKILL.md`
- `.claude/skills/plan-pm/refs/interview-protocol.md`

---

### `a4be5b5` — Clarify `msg-commit` protocol steps; extract subject line rules

- `.claude/skills/msg-commit/SKILL.md`
- `.claude/skills/msg-commit/refs/protocol.md`

---

### `d821302` — Simplify `plan-pm` PRD template

- `.claude/skills/plan-pm/refs/template-prd.md`

---

### `d06df46` — Extract `plan-em` emit protocol to separate reference file

- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-em/refs/emit-protocol.md`

---

### `20a8bb8` — Remove redundant inputs and outputs sections from `msg-commit`

- `.claude/skills/msg-commit/SKILL.md`

---

### `e379209` — Simplify `msg-init` language selection to free text with normalization

- `.claude/skills/msg-commit/SKILL.md`
- `.claude/skills/msg-init/SKILL.md`
- `.claude/skills/msg-init/init.sh`
- `.claude/skills/msg-init/install-standards.sh`

---

### `411cb4a` — Add commit & push option; extract examples to `protocol.md`

- `.claude/skills/msg-commit/SKILL.md`
- `.claude/skills/msg-commit/refs/protocol.md`

---

### `2040008` — Add language selection and coding standards installation to `msg-init`

- `.claude/skills/msg-init/SKILL.md`
- `.claude/skills/msg-init/init-setup.sh`
- `.claude/skills/msg-init/init.sh`
- `.claude/skills/msg-init/install-standards.sh`
- `.claude/skills/msg-init/refs/template-gitignore.md`
- `.claude/skills/plan-pm/SKILL.md`
- `.claude/skills/plan-pm/refs/interview-protocol.md`

---

### `1d035e2` — Harden `msg-init` Step 3 with deterministic `init.sh` script

- `.claude/skills/msg-init/SKILL.md`
- `.claude/skills/msg-init/init.sh`
- `.claude/skills/msg-init/refs/substitution-rules.md`

---

### `60908e4` — Add output rules to `msg-commit` to suppress step progress messages

- `.claude/skills/msg-commit/SKILL.md`

---

### `55e2f54` — Add `check-staged.sh` to gate `msg-commit` on non-empty diffs

- `.claude/scripts/check-staged.sh`
- `.claude/skills/msg-commit/SKILL.md`

---

### `bbd9b6a` — Add `msg-init` project bootstrap skill with template files

- `.claude/skills/msg-init/SKILL.md`
- `.claude/skills/msg-init/refs/substitution-rules.md`
- `.claude/skills/msg-init/refs/template-AHA.md`
- `.claude/skills/msg-init/refs/template-ARCHITECTURE.md`
- `.claude/skills/msg-init/refs/template-CLAUDE.md`
- `.claude/skills/msg-init/refs/template-GLOSSARY.md`
- `.claude/skills/msg-init/refs/template-README.md`
- `.claude/skills/msg-init/refs/template-gitignore.md`
- `.claude/skills/plan-em/SKILL.md`
- `.claude/skills/plan-pm/SKILL.md`
- `.claude/skills/plan-pm/refs/interview-protocol.md`

---

### `a0a1113` — Improve `msg-commit` empty-diff message

- `.claude/skills/msg-commit/SKILL.md`

---

### `96c8952` — Restrict `msg-commit` to staged diff only; switch model to Haiku

- `.claude/skills/msg-commit/SKILL.md`
- `.claude/skills/plan-pm/SKILL.md`

---

### `ff9e32b` — `plan-tune` applies audit findings inline instead of writing a report file

- `.claude/skills/plan-tune/SKILL.md`

---

### `fd1ddf9` — Add copy/commit prompt after message generation in `msg-commit`

- `.claude/skills/msg-commit/SKILL.md`

- Document OPEN-QUESTIONS.md logging protocol in eng build/protocol.md for unresolved ambiguities during build; clarify CHANGELOG.md is now maintained by the kermit commit-gate hook (not written by subagents) in msg-init SKILL.md and its template; add /plan resume mode (start mid-pipeline from an existing PRD path via frontmatter status), a between-stage guard verifying prior-stage artifacts exist, explicit failure handling on sub-skill refusal, and an end-of-run prompt to chain into /ship on a clean eng-tune.

- Sync `kermit`'s `last_logged_commit` pointer in `.claude/kermit/pref.json` to the latest changelog-synced commit.

- Exclude `handoff` and `improve` from the installed skill set — `handoff` is deleted from the repo entirely (no longer part of the msg suite), and `improve` is now explicitly kept repo-local via a `LOCAL_ONLY_SKILLS` list in `install.sh` so it never ships to `~/.claude/skills`; `msg/SKILL.md`, `README.md`, and `ARCHITECTURE.md` menus/inventories updated to match.

- `.claude/skills/handoff/SKILL.md` — deleted
- `.claude/skills/msg/SKILL.md` — dropped handoff row, routing entry, and pipeline branch; reworded Delivery/Wrapping-up copy
- `ARCHITECTURE.md` — removed handoff from skill inventory; documented improve's install exclusion
- `README.md` — removed handoff and improve rows from skills table
- `install.sh` — added `LOCAL_ONLY_SKILLS` exclusion list

- Remove per-skill `model:` frontmatter pins so skills run on whichever model the invoking session is already using, instead of forcing a specific one; also drop a stale model-upgrade note from `eng` and Opus-specific wording from `improve`'s `--review` mode.

- `.claude/skills/eng/SKILL.md` — drop stale model-upgrade note
- `.claude/skills/improve/SKILL.md` — remove `model:` pin; drop Opus-specific wording in `--review` mode
- `.claude/skills/msg/SKILL.md` — remove `model:` pin
- `.claude/skills/msg-init/SKILL.md` — remove `model:` pin
- `.claude/skills/plan-em/SKILL.md` — remove `model:` pin
- `.claude/skills/plan-pm/SKILL.md` — remove `model:` pin
- `.claude/skills/plan-tune/SKILL.md` — remove `model:` pin
- `.claude/skills/pre-merge/SKILL.md` — remove `model:` pin
- `.claude/skills/review/SKILL.md` — remove `model:` pin
- `.claude/skills/test/SKILL.md` — remove `model:` pin
