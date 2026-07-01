# Changelog

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
