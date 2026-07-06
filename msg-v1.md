# msg-v1 — Token Efficiency & Flash Mode

**Goal:** cut msg's token spend ~30–40% with no behavior change (Phase 1), then provide an opt-in flash mode delivering ~80% of each skill's value at ~20% of its cost (Phases 2–3), verified end-to-end (Phase 4).

**Baseline (from audit):** full pipeline ≈ 700k–1.2M tokens/PRD. Dominant costs: subagent fan-out re-briefing (each sibling re-reads PRD + devkit + cook), cook invoked via its uncacheable prose path (~12–17k/call, 8–10 calls per ship loop), ~17 inlined copies of the finding schema, and interview turn count (plan-pm 7–12 rounds, msg-init 10–14).

**Sequencing rule:** Phase 1 before Phase 2 (flash must not be designed around waste being deleted). Phase 3 last — it is only a router over the per-skill flash paths built in Phase 2. Work stops cleanly at any phase boundary: Phase 1 alone is a ~30–40% win; Phase 2 skills work standalone via `--flash` without the toggle.

---

## Phase 0 — Baseline benchmark

### T0.1 Capture comprehensive-mode baselines

**What:** Run one small fixture feature through `plan-pm → plan-tune --product → plan-em → plan-tune --eng → eng --build → review → test → pre-merge` and record per-stage token usage (subagent counts, cook calls, total tokens) into `evals/token-baseline.md`.

**Acceptance criteria:**
1. `evals/token-baseline.md` exists with one row per pipeline stage: stage, subagents spawned, cook invocations, approx tokens.
2. The same fixture feature (PRD path recorded in the doc) is reusable for the Phase 4 comparison run.

---

## Phase 1 — Structural fixes (no behavior change)

> ✅ **DONE (2026-07-06)** — all tasks executed except cook-internal T1.12 (skipped, separate repo) and the cook-`_INDEX` part of T1.9 (deferred). One partial: T1.6 AC3 (test mode reduction 12.1% vs ≥35% target — behavior-neutral max). Evidence + open items: `update/done/msg-v1-phase1.md`.

### T1.1 One cook call per review mode, not per flag

**What:** Review's cook-backed modes spawn one `/cook --<flag>` agent per flag (~12–13 agents/run). Change quality.md, security.md, performance.md, migration.md to spawn **one agent per mode** with all of that mode's flags in a single `/cook` call.

**Files:** `review/refs/modes/{quality,security,performance,migration}.md`, `review/SKILL.md` Step 6.

**Acceptance criteria:**
1. No mode ref contains "one Agent per flag"; each specifies a single subagent receiving all mode flags in one `/cook` invocation.
2. A typical multi-domain run spawns ≤4 semantic subagents (quality, security, performance, + conditional), down from ~12–13.
3. Aggregated findings still carry per-rule attribution (the compiled payload names each rule's source).

### T1.2 Compile-once, share-many cook payloads

**What:** Orchestrators (plan-em, review, eng roadmap/ship path) call cook once per stack, then inject the compiled standards payload into subagent prompts instead of each subagent re-invoking `Skill("cook", …)`.

**Files:** `plan-em/refs/protocol-em.md`, `review/SKILL.md`, `eng/refs/build/protocol-roadmap.md`, subagent prompt specs.

**Acceptance criteria:**
1. Subagent prompt templates contain a `standards payload` section populated by the orchestrator; no leaf-agent instruction to call `/cook` remains on orchestrated paths.
2. Direct/standalone skill invocations (e.g. user runs `eng --build` directly) still call cook themselves — the fallback is stated explicitly.
3. Cook is invoked at most once per distinct stack per orchestrated run.

### T1.3 eng → cook via flags, not prose

**What:** eng's Step 4 builds a prose summary for cook — cook's uncacheable path that scans all 10 indexes and skips P0. Derive explicit flags from eng's existing concern-keyword table instead.

**Files:** `eng/SKILL.md` (Step 4, lines ~185–194), `plan-em/refs/protocol-em.md` (its cook call).

**Acceptance criteria:**
1. eng's cook invocations pass explicit flags (e.g. `--flutter --dart --flutter:testing`); no prose-summary invocation remains in eng or plan-em.
2. The P0 global floor is loaded on every eng-initiated cook call (flag path guarantees it).
3. A repeated identical invocation hits cook's cache (script-only run, no index scan).
4. `/cook` is no longer called in `--todo` mode, and `--plan` mode's call is dropped or reduced to stack constraints only.

### T1.4 Row-scoped context for build subagents

**What:** Orchestrators read PRD + devkit once and pass each build subagent only its exec-table rows, the relevant PRD feature sections, and a devkit digest — instead of instructing every sibling to re-read everything.

**Files:** `plan-em/refs/protocol-em.md` (agent-prompt spec), `eng/refs/build/protocol-roadmap.md`.

**Acceptance criteria:**
1. Subagent prompts contain scoped excerpts (rows + feature sections + digest), not "read the full PRD and all devkit files".
2. Subagents retain the PRD path for on-demand lookup when an excerpt is insufficient (escape hatch stated).
3. Scope-enforcement and branch-contract instructions survive unchanged.

### T1.5 Single canonical finding schema

**What:** The finding object is inlined ~13× in test's mode files, plus review's schema.md and pre-merge's finding-schema.md. Collapse all copies to references to `shared/refs/finding-schema.md` (test/refs/schema.md already models the correct pattern).

**Files:** all 10 `test/refs/modes/*.md`, `review/refs/schema.md`, `pre-merge/refs/finding-schema.md`, `pre-merge/SKILL.md` inline contract.

**Acceptance criteria:**
1. Exactly one full JSON definition of the finding object exists in the repo (`shared/refs/finding-schema.md`).
2. Every consumer file points at it by path; no file re-lists the full field set.
3. The duplicated sec-001 Stripe example exists only in shared.
4. Emitted findings from test/review/pre-merge are byte-shape-identical to pre-change output on the fixture run.

### T1.6 Factor mode-file boilerplate

**What:** Test's 10 mode files repeat the runner guard, bucket-error rule, output envelope, and 7 redundant runner-detection tables (~40% of their weight); review's 4 cook-backed modes repeat the same "Execution" block. Extract to `test/refs/modes/_common.md` and review's existing sub-skill contract.

**Acceptance criteria:**
1. `test/refs/modes/_common.md` exists (≤300 words) holding guard + error rule + output envelope + schema pointer; every mode file references it.
2. No test mode file contains a "Recognised runners" table (the detect script is authoritative, as SKILL.md already states).
3. Average test mode-file length drops ≥35%.
4. Review's four cook-backed mode files no longer carry the duplicated Execution block.

### T1.7 Hoist conditional-mode triggers

**What:** Review loads migration.md + a11y-i18n.md every run just to read their trigger conditions. Move the 3-line glob triggers into SKILL.md Step 6; load the mode files only on trigger match.

**Acceptance criteria:**
1. Both trigger conditions appear in `review/SKILL.md` Step 6.
2. Neither mode file is read on a run whose diff doesn't match its trigger.
3. `performance.md` (107 words) is folded into the Step 6 table and deleted.

### T1.8 Script prose detection + GUI static fill

**What:** (a) Extend `test-tooling-detect.sh` (or a sibling script) to emit mechanical runners, secret scanners, build tool, and bundle analyzer, removing `shared/refs/tooling-detection.md` from review's and pre-merge's hot paths. (b) Add `msg/refs/gui/fill-static.py` so the GUI static fallback is a script call, not a ~35k-token manual Read/splice/Write.

**Acceptance criteria:**
1. Review Step 2 and pre-merge Step 2 consume script JSON; neither reads tooling-detection.md at runtime.
2. tooling-detection.md is retained only as maintainer documentation (or deleted if fully superseded).
3. `fill-static.py` performs the `__STYLES__`/`__PRD_DATA__`/`__API_TOKEN__` substitution; protocol-gui.md Step 4 invokes it via Bash and no longer instructs Reading index.html/styles.css.
4. Static fallback output opens and renders identically to the pre-change path.

### T1.9 Delete dead weight

**What:** Remove `pre-merge/pre-merge-plan.md` (2,045-word deprecated plan doc), cook's archived-provenance tables from runtime `_INDEX.md` files (→ `ARCHIVE.md`), and plan-tune's `refs/principles.md` (stale copy of plan-pm's; its checks already live in tune-product.md).

**Acceptance criteria:**
1. `pre-merge/pre-merge-plan.md` no longer exists in the skill dir.
2. No `_INDEX.md` under cook contains an archived/provenance table; content preserved in per-domain `ARCHIVE.md`.
3. plan-tune has no `refs/principles.md` and no mandatory-read instruction for it; plan-pm's copy (or a shared one) remains the single source.
4. No remaining file references the deleted paths.

### T1.10 Slim always-loaded SKILL.md files

**What:** Move rare-mode content out of hot SKILL.md files into lazily-read refs: eng's test-json + roadmap input-source sections (~800 w) → build refs; plan-pm's sub-PRD section → `refs/protocol-sub.md`; plan-pm's roadmap blurb → 2 lines; plan-em's Step 0 prefs-bootstrap prose → 2 sentences + ref; plan-tune's Outputs-table/persona duplication trimmed.

**Acceptance criteria:**
1. `eng/SKILL.md` ≤1,500 words; `--plan`/`--todo` runs load no test-json/roadmap source documentation.
2. `plan-pm/SKILL.md` contains ≤5 lines each on sub-PRD and roadmap modes, pointing at refs.
3. Every mode still functions: sub-PRD, roadmap, and test-json paths load their moved content from refs (spot-check each).

### T1.11 pre-merge `--test-json` handoff

**What:** pre-merge re-runs integration/e2e suites `/test` just passed. Accept `--test-json <path>` (the /test aggregate) and skip covered buckets with an explicit skip record.

**Acceptance criteria:**
1. pre-merge accepts `--test-json`; when the referenced run is clean and fresh (same HEAD), integration and e2e buckets emit `skipped: {reason: "covered_by_test_run"}` instead of executing.
2. `/ship` passes the flag automatically after a clean `/test`.
3. Without the flag (or on stale/dirty test JSON), behavior is unchanged.

### T1.12 Enforce cook's payload budget

**What:** `cook_compile.py` hardcodes `dropped_for_budget: []`. Implement a real `--budget-words` cap (default 4,000), dropping refs lowest-priority-first (concern refs → domain refs → never domain/global SKILL.mds).

**Acceptance criteria:**
1. A compile exceeding the budget drops refs in the specified order and lists them in `dropped_for_budget`.
2. Domain SKILL.mds and P0 are never dropped regardless of budget.
3. Default behavior on typical payloads (≤4,000 words) is unchanged.

### T1.13 Batch interview questions

**What:** msg-init asks 10–14 questions serially; plan-pm's open-questions loop asks one per question. Batch 3–4 per AskUserQuestion call (msg `--help` already does this).

**Acceptance criteria:**
1. msg-init completes its full interview in ≤4 AskUserQuestion calls with no question dropped.
2. plan-pm's open-questions loop batches up to 4 per call.
3. Answer handling (fallbacks, `[USER: …]` placeholders) is unchanged.

### T1.14 Fix review dedup-key bug

**What:** `review/SKILL.md` Step dedup key is `(file, line, category)` while schema.md and shared define `(category, file, line, rule)` — findings differing only by rule are wrongly merged.

**Acceptance criteria:**
1. SKILL.md's dedup key includes `rule`, matching schema.md and shared/finding-schema.md verbatim.
2. Two findings at the same file:line with different rules survive dedup (fixture check).

### Phase 1 exit gate

1. Fixture pipeline re-run produces functionally identical artifacts (PRD, exec table, findings, verdicts) to the T0.1 baseline.
2. Measured total spend ≥30% below baseline.
3. `docu` pass: README/ARCHITECTURE updated for deleted/moved files.

---

## Phase 2 — Per-skill flash modes

**Design rules (apply to every task below):**
- Flash loads a small `refs/flash.md` **instead of** the comprehensive refs — never both.
- `--flash` flag works standalone in this phase; pref-file wiring comes in Phase 3.
- The safety floor is never relaxed: DB-touch/breaking-change pauses, branch isolation, no push/merge, secret scan, frontmatter stamps, F-ID stability, PRD §9 ledger, test fail ticket, pre-merge refusals.

### T2.1 `shared/refs/flash-floor.md`

**What:** One ~150-word file stating the invariants above plus the common flash semantics: auto-proceed at plan gates, capped tool stdout (~50 lines, full logs to file), summary + file path instead of full JSON echo.

**Acceptance criteria:**
1. File exists, ≤200 words, and every Phase 2 flash.md references it.
2. Every safety-floor item is listed and marked never-relaxed.

### T2.2 `review --flash`

**What:** Mechanical gates + **one** combined semantic agent (~300-word distilled rubric: quality concerns + security checklist + perf patterns; no cook shelves), fingerprint-lite via script, skip eval-set bootstrap + confirm gate + cache, conditional modes as static greps only, top-10 findings in compact schema `{severity, category, rule, message, file, line, suggestion}`, `--min-severity high` default.

**Acceptance criteria:**
1. `review/refs/flash.md` exists; a flash run reads it plus zero comprehensive mode files.
2. Flash run spawns exactly 1 semantic subagent and 0 cook invocations.
3. Lint/typecheck/secret gates and their short-circuit behavior are identical to comprehensive.
4. Output is capped at 10 findings, compact schema, single stdout transit + one file write.
5. No AskUserQuestion is issued; the surface summary prints as one line.
6. On the fixture diff with a seeded blocker bug, flash reports it.
7. Measured cost ≤25% of the comprehensive review baseline.

### T2.3 `test --flash`

**What:** Unit + functional buckets only, `--changed-only` implied against merge base, in-process (no subagents), no plan gate, runner stdout capped ~50 lines/bucket, summary + JSON file path emitted (no full JSON echo). Fail ticket still written.

**Acceptance criteria:**
1. `test/refs/flash.md` exists; flash reads only it + unit.md + functional.md.
2. 0 subagents spawned; 0 AskUserQuestion calls.
3. A seeded failing unit test yields verdict `fail` and the Step 6 ticket, identical shape to comprehensive.
4. Measured cost ≤20% of the 10-bucket baseline.

### T2.4 `pre-merge --flash`

**What:** Build + security buckets only; bundle bucket runs only when a baseline exists; no gate (matrix printed, auto-run); stdout capped, logs to file.

**Acceptance criteria:**
1. Flash runs exactly build + security (+ bundle iff baseline present); integration/e2e emit `skipped` records.
2. Refusal patterns and verdict enum unchanged.
3. Measured cost ≤25% of pre-merge baseline.

### T2.5 `cook --flash` (flag-capped path)

**What:** Flag-only invocation loading domain SKILL.md(s) + P0 only — no refs, no index scan; budget 1,500 words; fully cacheable.

**Acceptance criteria:**
1. `cook --flash --<domain>` compiles domain SKILL.md(s) + P0 and nothing else.
2. Payload ≤1,500 words; repeat invocation is a cache hit.
3. Comprehensive cook behavior unchanged.

### T2.6 `eng --plan --flash`

**What:** Skip cook (keep CLAUDE.md stack constraints); compressed template (Summary, Scope mapping, Integration contracts, Execution-steps column, Findings); no approval gate (summary printed, proceed).

**Acceptance criteria:**
1. `eng/refs/plan/flash.md` (or flash template) exists; flash loads it instead of template-eng-plan.md.
2. Exact-identifier rule and integration-contract section survive verbatim.
3. 0 cook calls; 0 gates; plan doc contains the 5 compressed sections.
4. Measured cost ≤40% of a comprehensive --plan agent.

### T2.7 `eng --build --flash`

**What:** One agent for all exec-table rows (no per-platform fan-out); spec direct from exec table (skip todo tickets); one `cook --flash` call per run; impl + tests written together, suite run once (skip verify-red); single commit gate; debug capped at 2 cycles.

**Acceptance criteria:**
1. Flash build spawns ≤1 build agent regardless of platform count (orchestrators respect this when mode is forwarded).
2. Exactly 1 cook invocation, flash-capped.
3. Branch contract, scope enforcement, and AHA/OPEN-QUESTIONS logging unchanged.
4. Full suite runs at least once before commit; commit gate fires once.
5. Fixture feature builds green; measured cost ≤30% of comprehensive --build.

### T2.8 `plan-pm --flash`

**What:** Interview collapsed to 2 combined multiSelect calls (PM-derived feature table + PM-derived error/interaction/dependency checklist); devkit reads = GLOSSARY + ARCHITECTURE only; frontmatter-only prior-PRD scan; one-line `entry → step → outcome` flows; skip epic-ask, open-questions loop, AHA writeback, next-step ask.

**Acceptance criteria:**
1. `plan-pm/refs/flash/` protocol + slim template exist; flash loads them instead of protocol-pm/interview/templates.
2. Exactly 2 AskUserQuestion calls on the happy path.
3. Output PRD retains: frontmatter stamps, F-IDs, acceptance criteria per feature, scope table, §9 ledger section.
4. Measured cost ≤35% of comprehensive plan-pm.

### T2.9 `plan-tune --flash`

**What:** Critical-severity checks only (product: placeholder/vague ACs, feature↔out-of-scope contradiction, conflicting ACs, timezone basis, glossary conflicts; eng adds coverage/contracts/migration); auto-fix all; zero gates when flag + path supplied; verify once at end; no external template-eng-plan read.

**Acceptance criteria:**
1. `plan-tune/refs/flash.md` checklist (≤400 words) replaces tune-product/tune-eng in flash.
2. 0 AskUserQuestion calls when tune type + path are provided.
3. Findings still appended to PRD §9 with severity tags; frontmatter stamp still written.
4. Seeded placeholder-AC fixture is caught and fixed; measured cost ≤35% of comprehensive tune.

### T2.10 `plan-em --flash`

**What:** One generalist eng agent when PRD spans ≤2 platforms; one merged gate (tune-gate + roster + relationship flags); preflight-lite (ARCHITECTURE + GLOSSARY + PRD, ≤10-line preflight.md); frontmatter-only multi-PRD scan; skip `/test --prd`, AHA writeback, full-PRD synthesis re-read (synthesize from agent returns).

**Acceptance criteria:**
1. `plan-em/refs/flash.md` exists; flash reads it instead of protocol-em.md.
2. ≤1 AskUserQuestion on the happy path; tune gate auto-skipped when `product-tuned: yes`.
3. ≤2 platforms → exactly 1 subagent; >2 platforms → per-platform roster preserved.
4. Exec table, branch convention, and breaking-change pause unchanged.
5. Measured cost ≤30% of comprehensive plan-em.

### T2.11 `msg-init --flash` + `msg --flash`

**What:** msg-init: zero-interview bootstrap — run `init-setup.sh`, call `init.sh` with detected `PROJECT_NAME`/`PLATFORM`, script fallbacks fill the rest; one confirm question max. msg: single grouped skill question (or direct routing from prose args); `--gui` flash is interactive-only (never the static build).

**Acceptance criteria:**
1. msg-init flash issues ≤1 AskUserQuestion and produces the full devkit scaffold with `[USER: …]` placeholders.
2. Idempotency preserved (no overwrites).
3. msg flash menu resolves in ≤1 question; `--gui --flash` with missing python3 prints an instruction instead of the static build.

### T2.12 `ship` flash loop

**What:** When flash is active: `max_rounds=1`; spawn review/test/pre-merge subagents in their flash modes (`review --flash --min-severity blocker`, `test --flash`, pre-merge flash); all guardrails intact.

**Acceptance criteria:**
1. Ship in flash forwards `--flash` into every spawned skill invocation (verifiable in subagent prompts).
2. Fix loop runs at most 1 round; DB-touch pause, branch isolation, and no-push/merge behavior unchanged.
3. Fixture PRD ships green at ≤25% of the ship baseline.

### Phase 2 exit gate

1. Every skill's `--flash` runs standalone without the Phase 3 pref file.
2. Per-skill measured costs meet the targets above.
3. Comprehensive mode on every skill is regression-free vs the Phase 1 exit run.

---

## Phase 3 — Harness-wide flash toggle

### T3.1 Pref file + resolution

**What:** `.claude/msg/pref.json` → `{"mode": "comprehensive" | "flash"}`; local path first, global (`~/.claude/msg/pref.json`) fallback; missing/corrupt → comprehensive. Every msg SKILL.md gets a 2-line Step 0: resolve mode, honor per-run `--flash`/`--comprehensive` override (flag > pref > default).

**Acceptance criteria:**
1. All 9 user-facing skills resolve the mode in Step 0 with identical precedence rules.
2. Corrupt/missing pref silently yields comprehensive.
3. An inline `--comprehensive` on a flash-pref session runs comprehensive (and vice versa) without persisting.

### T3.2 `/msg --set-mode`

**What:** `/msg --set-mode --flash|--comprehensive` writes the pref (asking local vs global scope, wdym-style), confirms, and terminates. `/msg` menu displays the current mode.

**Acceptance criteria:**
1. Command persists the mode at the chosen scope and never duplicates or clobbers unrelated keys.
2. `/msg` header line shows the active mode and its source (local/global/default).

### T3.3 Propagation contract

**What:** Orchestrators (plan, plan-em, ship, eng roadmap, review) forward the **resolved** mode into every `Skill(...)` handoff and every `Agent(...)` prompt they issue. Add one canonical sentence to each orchestrator's agent-prompt spec and a line item in `shared/refs/flash-floor.md`.

**Acceptance criteria:**
1. Every orchestrator's subagent-prompt template includes the mode flag explicitly.
2. Fixture flash ship run: zero spawned subagents execute a comprehensive path (verify via subagent prompts / cook call counts).
3. A leaf skill invoked by an orchestrator never re-reads the pref file (mode arrives via flag), preventing local/global drift mid-pipeline.

### T3.4 Docs

**What:** README skills table gains a mode column note; ARCHITECTURE.md gains a "Run modes" section (pref file, precedence, propagation, safety floor); install.sh untouched (pref is user-created, never installed).

**Acceptance criteria:**
1. README and ARCHITECTURE describe the toggle, precedence, and the never-relaxed floor.
2. `install.sh` does not create or overwrite any pref.json.

### Phase 3 exit gate

1. Toggling the pref flips the entire pipeline end-to-end with no per-command flags.
2. Flag overrides beat the pref in both directions on every skill.

---

## Phase 4 — Verification benchmark

### T4.1 Dual-mode fixture run

**What:** Run the T0.1 fixture feature end-to-end twice — comprehensive and flash — and record both in `evals/token-baseline.md`.

**Acceptance criteria:**
1. Flash total ≤25% of the (post-Phase-1) comprehensive total.
2. Flash produces: a working build passing its unit tests, a review that catches the seeded blocker bug, a clean pre-merge build+security verdict.
3. Comprehensive run output is functionally identical to the Phase 1 exit run (no flash contamination).
4. Deltas and any target misses are logged in the doc with a follow-up list.

---

## Explicitly out of scope for v1

- Prose-fingerprint caching inside cook (superseded by T1.3 flag switch; revisit only if prose callers remain).
- Flash for the roadmap orchestrator beyond mode propagation (T2.12/T3.3 cover its subagents; per-phase digest tuning deferred).
- Any relaxation of DB/breaking-change pauses, branch isolation, or push/merge rules — in any mode, ever.
