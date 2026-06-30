# msg Skills — Update Plan

15 skills under `.claude/skills/` were audited, one per skill, judged on output quality, with proposed changes to improve, remove, or introduce. Cross-cutting findings come first, then per-skill analysis.

**Date:** 2026-06-30 · **Skills:** docu, eng, handoff, improve, msg-init, msg, plan-em, plan-pm, plan-tune, plan, pre-merge, review, ship, test, todo

---

## Summary

Most skills are sound on their own: clear protocols, gating, lazy ref loading, working shell scripts. The risk is between them. msg is a pipeline (`msg-init → plan-pm → plan-tune → plan-em → plan-tune → eng → review → test → pre-merge → ship`), and the contracts connecting the stages have drifted. Skills read fields, paths, and schemas their upstream producers never write. Several headline features run, report success, and do nothing.

| Skill | Status | Worst issue |
|---|---|---|
| eng | OK | Menu advertises a `--review` mode that does not exist; agent-naming collision with plan-em |
| review | OK | Finding schema differs from test/pre-merge; `full_tree_command` field never emitted |
| pre-merge | OK | Dedup/regression keys on a `rule` field absent from the schema; P1 feature dead |
| test | OK | "Compatible with pre-merge schema" claim is false; eval_set contract undocumented on producer side |
| improve | OK | Local-write constraint holds only by cwd, no guard |
| handoff | OK | Output derived from committed history only; drops in-flight session work |
| msg-init | OK | Generated CLAUDE.md/README point to bare-root docs but files are written to `devkit/` |
| ship | Mixed | Branch contract bug; feature branch ends empty, loop reviews nothing |
| plan | Mixed | Terminal-option-at-every-gate bypasses every frontmatter status writeback |
| msg | Mixed | Router omits `ship` and `kermit`; cannot route to them |
| docu | Mixed | Discovery targets bare-root docs, not `devkit/`; falsely reports "up to date" |
| todo | Mixed | Both file-input parsers key on columns/formats the real artifacts lack |
| plan-em | Mixed | Reads `tuned:` (never written) and unslugged paths; roster premise false |
| plan-pm | Broken | PRD output lacks the feature-ID table and acceptance criteria both consumers require |
| plan-tune | Broken | Audits a PRD schema plan-pm does not produce; flags Critical on every clean PRD |

### Cross-cutting findings (fix first — each spans multiple skills)

> All cross-cutting findings X1–X7 are **FIXED** — see the `# Done` heading at the bottom of this file. (X5's pre-merge dedup half was gated on X1 and is now unblocked by the shared finding-schema.)

### Sequencing

1. Contract repairs (X2, X3, X4, X7) — unblock the pipeline.
2. Schema unification (X1, X5).
3. Router and per-skill items (X6 and the Improve lists below).
4. New capabilities (Introduce items), after the contracts hold.

---

# Per-Skill Analyses

# Skill: msg-init

## Summary

`msg-init` is the one-time bootstrap and contract root for the msg ecosystem. It scans the repo, runs a 3-phase interview (basics, architecture, design system), and writes `devkit/` (AHA, GLOSSARY, ARCHITECTURE, DESIGN-SYSTEM, OPEN-QUESTIONS) plus root README/.gitignore/CLAUDE.md/CHANGELOG.md/features/ via an idempotent shell writer. Main problem: contract leaks. Two created files (OPEN-QUESTIONS.md, CHANGELOG.md) are never written by any downstream skill, and the two navigation files it generates (CLAUDE.md, README.md) point to root paths instead of `devkit/`.

---

## Quality Assessment

### Strengths

**Idempotency is correctly layered.** `init.sh` checks `[[ -e "$dest" ]]` before every write (`init.sh:99`) and the `devkit/`/`features/` directories guard on `[[ -d ... ]]` (`init.sh:115`, `init.sh:219`). Nothing is overwritten; existing files land in `SKIPPED`. `init-setup.sh` independently computes `ALL_COMPLETE` (`init-setup.sh:39-40`) and the SKILL short-circuits the interview when everything exists (`SKILL.md:91`). Two-layer design: scan gate up front, per-file gate at write time.

**Shell script handles partial state.** `set -eo pipefail` (`init.sh:25`); `SCRIPT_DIR` resolved via `BASH_SOURCE` so it works regardless of cwd (`init.sh:27`); every env var has a fallback (`init.sh:32-45`) so a partial interview still produces valid files; the `write_file` helper uses a content variable rather than stdin "so array writes happen in the main shell" (`init.sh:85-86`), avoiding a subshell pitfall. Manifest arithmetic and the non-zero exit on failure (`init.sh:245`) are correct.

**Two template-extraction mechanisms.** `extract_body` for fenced `## Template body` blocks with `{{placeholder}}` substitution (`init.sh:70-77`), and `strip_frontmatter` for flat templates with no placeholders (`init.sh:80-82`). This separates customised files (README, CLAUDE, ARCHITECTURE, DESIGN-SYSTEM) from static ones (AHA, GLOSSARY, OPEN-QUESTIONS, CHANGELOG).

**The 3-phase interview is scoped.** Phase 2 (basics) skips Q2 when platform is unambiguous (`SKILL.md:95`); Phase 3 (architecture) maps onto the ARCHITECTURE template's pre-populated sections; Phase 4 (design system) early-exits — "if no UI layer, set all DS vars to Not applicable and skip D2-D4" (`SKILL.md:123`). The split between interview-filled fields and `[USER: …]` gaps (`template-ARCHITECTURE.md:61`, `template-DESIGN-SYSTEM.md:39`) leaves unknowns (Component map, observability) as explicit todos rather than hallucinating them.

**Gitignore selection.** Language-specific (`Flutter/Dart`) takes priority over platform (`init.sh:184-196`), `LANGUAGE` is lowercased for case-insensitive matching, and the universal section is always concatenated. Falls back to universal-only on "Other" (`template-gitignore.md:144-146`).

**Output templates ship an exemplar entry.** AHA, OPEN-QUESTIONS, GLOSSARY all include a commented exemplar showing the required format (`template-AHA.md:20-26`, `template-OPEN-QUESTIONS.md:14-23`), which keeps downstream appends consistent. OPEN-QUESTIONS also ships a severity rubric (`template-OPEN-QUESTIONS.md:25-29`) and an Open/Resolved split.

### Weaknesses

**[CRITICAL — contract leak] Generated README.md and CLAUDE.md point to the wrong paths.** msg-init writes ARCHITECTURE/GLOSSARY/AHA into `devkit/`, but the two navigation docs reference them at root:
- `template-CLAUDE.md:33-35` — File map lists ``ARCHITECTURE.md``, ``GLOSSARY.md``, ``AHA.md`` (bare).
- `template-CLAUDE.md:40` — "check `GLOSSARY.md`" (bare).
- `template-README.md:20,28-30` — "See `ARCHITECTURE.md`", and a doc list of bare `ARCHITECTURE.md`/`GLOSSARY.md`/`AHA.md`.

CLAUDE.md is read by Claude Code on every session start (`template-CLAUDE.md:15`), so this misdirects the agent to non-existent root paths every session. Highest-impact defect.

**[CRITICAL — orphaned output] OPEN-QUESTIONS.md is created but no skill writes it.** Both `SKILL.md:44` and `template-OPEN-QUESTIONS.md:8` assert "build subagents write here when they hit ambiguity." A repo-wide grep shows the eng build protocol escalates ambiguity to AHA.md and the build summary (`eng/refs/build/protocol.md:90-98`), not OPEN-QUESTIONS.md. Only `handoff` and `plan-pm`/`plan-em` read it. The stated writer does not exist — the file is born empty and stays empty.

**[CRITICAL — orphaned output] CHANGELOG.md is created but no msg skill writes it.** `template-CHANGELOG.md:11` says "written and maintained by subagents — do not edit manually," but no skill in `.claude/skills/` writes CHANGELOG. The only changelog writer is the global `kermit` skill (managed via hooks, per global CLAUDE.md), which is outside the msg ecosystem and is never referenced by any msg skill. Within the msg contract, CHANGELOG is dead weight.

**[MAJOR] plan-pm's AHA.md writeback path is inconsistent with msg-init's output.** plan-pm reads `devkit/AHA.md` (`plan-pm/SKILL.md:50`) but its writeback instructions say append to ``AHA.md`` (bare) and "If `AHA.md` does not exist, create it" (`plan-pm/SKILL.md:182,190`). eng appends to `devkit/AHA.md` (`eng/refs/build/protocol.md:96`). So plan-pm risks creating a second, root-level AHA.md that diverges from the one it reads. The bug is downstream, but msg-init is the contract root and should make the path unambiguous.

**[MINOR] STACK_DEFAULT is computed but never used by the protocol.** `init-setup.sh:28-37` derives a `STACK_DEFAULT` (e.g. `package.json` → "Web (frontend)"), but Step 2 (`SKILL.md:95-104`) never references it — Q2 lists four static options. The scanner output is discarded. Either wire STACK_DEFAULT in as the Q2 default, or stop computing it.

**[MINOR] Step 1 holds STACK_DEFAULT but the Q2-skip rule needs STACK_HINTS.** `SKILL.md:89` instructs holding `PRESENT`, `MISSING`, `STACK_DEFAULT` — but the Step 2 skip rule "skip Q2 when exactly one stack hint is present" (`SKILL.md:95`) depends on `STACK_HINTS`, which line 89 does not list. The agent evaluates a condition on a variable it wasn't told to keep.

**[MINOR] PRD directory naming drifts.** msg-init's templates use bare `prd-[n]/` (`template-README.md:20`, `template-CLAUDE.md:32`), but the convention plan-pm enforces is `prd-[n]-[feature-slug]/` (`plan-pm/SKILL.md:5`). The generated docs teach the wrong path shape.

**[MINOR] `.gitignore` "Mobile" and "Dart/Flutter" sections overlap and Flutter duplicates `.dart_tool/`.** `template-gitignore.md:71` lists `.dart_tool/` twice in the Dart/Flutter block. Cosmetic but it's a shipped artifact.

---

## Improve (prioritized)

1. **Fix the path references in template-README.md and template-CLAUDE.md to use `devkit/`.**
   *Why:* CLAUDE.md is read every session and currently sends the agent to non-existent root paths. Highest impact, lowest effort.
   *How:* In `template-CLAUDE.md:33-35,40` and `template-README.md:20,28-30`, prefix `ARCHITECTURE.md`, `GLOSSARY.md`, `AHA.md`, `DESIGN-SYSTEM.md`, `OPEN-QUESTIONS.md` with `devkit/`. Also correct `prd-[n]/` → `prd-[n]-[feature-slug]/` to match plan-pm.

2. **Make OPEN-QUESTIONS.md a real output: wire eng to write it, or stop creating it.**
   *Why:* A file the contract promises but never writes is worse than no file — handoff/plan-pm scan an always-empty file. *How (preferred):* Add to `eng/refs/build/protocol.md` (alongside the AHA.md escalation block at ~L90) an instruction to append unresolved ambiguities to `devkit/OPEN-QUESTIONS.md` using the template's entry format. *Alternative:* if escalation-to-AHA is the intended design, remove OPEN-QUESTIONS from msg-init's outputs and from the handoff/plan read lists.

3. **Resolve CHANGELOG.md ownership.**
   *Why:* Within msg, CHANGELOG is created and immediately abandoned. *How:* Either (a) document in msg-init that CHANGELOG is owned by the external `kermit` skill and reference `/kermit --init`, or (b) drop CHANGELOG.md from msg-init's outputs. Don't ship an orphan with a "do not edit manually" banner and no maintainer.

4. **Fix plan-pm's AHA.md writeback path to `devkit/AHA.md`.**
   *Why:* Prevents a divergent root-level AHA.md. *How:* In `plan-pm/SKILL.md:182,190`, change `AHA.md` → `devkit/AHA.md` (matching eng). msg-init can't enforce this directly, so also add one line to msg-init's `## What is devkit` Convention block stating all reads AND writes are `devkit/`-relative.

5. **Either consume STACK_DEFAULT or remove it.**
   *Why:* Dead computation in `init-setup.sh`. *How (preferred):* In `SKILL.md` Step 2, when `STACK_HINTS` is non-empty pre-select Q2's option to `STACK_DEFAULT` (and keep the existing skip-Q2-when-unambiguous rule). Add `STACK_HINTS` to the Step 1 "hold in context" list (`SKILL.md:89`).

6. **De-duplicate the Flutter `.dart_tool/` line** in `template-gitignore.md:65-96`.

---

## Remove

- **CHANGELOG.md output + template** (`template-CHANGELOG.md`, the writer loop in `init.sh:160-166`, the manifest/output rows) — if msg keeps changelog management in kermit. No msg skill writes it, and its banner forbids manual edits, so it sits empty. Cutting it removes a template file and a loop.
- **OPEN-QUESTIONS.md** — only if Improve #2's "write it" option is rejected. Don't keep a promised-but-unwritten file.
- **STACK_DEFAULT derivation** (`init-setup.sh:28-37`) — only if Improve #5's "consume it" option is rejected. Removing it deletes 10 lines of unused case logic.
- **Nothing else.** The script has no dead code — every helper (`apply_subs`, `extract_body`, `strip_frontmatter`, `write_file`) is exercised, and the manifest logic is live.

---

## Introduce

1. **A `--dry-run` / preview mode.** *Why:* This skill writes ~10 files into the user's repo root on the first run. A flag that prints the manifest (created/skipped) without writing aids debugging. *How:* `init.sh` already computes everything; gate the `> "$dest"` writes behind a `DRY_RUN` env var and still emit the manifest.

2. **A devkit-completeness check sub-mode (`/msg-init --check`).** *Why:* Every downstream skill re-implements the "if devkit/ missing, halt and tell user to run msg-init" check (`plan-em/SKILL.md:84`, plan-pm, eng, handoff). A canonical `init-setup.sh`-backed check the others could call would DRY up the contract and let users diagnose a half-initialised repo. *How:* `init-setup.sh` already emits `MISSING` — expose a SKILL path that runs the scan and prints PRESENT/MISSING without interviewing.

3. **Persist interview answers to a `devkit/.msg-init.json` cache.** *Why:* PLATFORM/LANGUAGE/team/conventions are gathered once and then only live inside generated prose. Other skills (test --init, plan-pm platform defaults) re-derive the stack from scratch. A structured cache would let them read it directly. *How:* Add a final `init.sh` step writing the env vars as JSON (idempotent, skip-if-exists).

4. **Auto-fill `ARCH_DATA_STORES` / `DS_LIBRARY` tables from the multiSelect answers.** *Why:* A3 (data stores) and D2 (component library) are multiSelect/option questions but are substituted as a single free-text blob (`init.sh:40,43`). The ARCHITECTURE "Data stores" and DESIGN-SYSTEM "Component library" sections would be better as the table rows the templates already scaffold. *How:* Have the SKILL format the multiSelect answers into markdown list/table rows before passing them as the env var.

---

## Priority Ranking

| Recommendation | Impact | Effort |
|---|---|---|
| Fix README/CLAUDE template paths to `devkit/` (Improve #1) | High | Low |
| Wire eng to write OPEN-QUESTIONS.md, or remove it (Improve #2 / Remove) | High | Low |
| Resolve CHANGELOG ownership (Improve #3 / Remove) | Med | Low |
| Fix plan-pm AHA.md writeback path + tighten devkit convention (Improve #4) | Med | Low |
| Consume or remove STACK_DEFAULT (Improve #5 / Remove) | Med | Low |
| Persist interview answers to devkit/.msg-init.json (Introduce #3) | Med | Med |
| Devkit "doctor" / --check sub-mode (Introduce #2) | Med | Med |
| Auto-fill multiSelect answers into tables (Introduce #4) | Low | Med |
| `--dry-run` preview mode (Introduce #1) | Low | Low |
| De-dup Flutter `.dart_tool/` (Improve #6) | Low | Low |
| Add STACK_HINTS to Step 1 hold list (Improve #5b) | Low | Low |
| Fix prd-[n] → prd-[n]-[feature-slug] in templates (Improve #1b) | Low | Low |


---

# Skill: plan-pm

## Summary

`plan-pm` is the Principal PM entry point of the PRD pipeline. It reads `devkit/` context, runs a 5-question `AskUserQuestion` interview, and writes a structured PRD to `features/prd-[n]-[feature-slug]/`, with optional epic-splitting into multiple sequential PRDs. The output is misaligned with both downstream consumers: the PRD has no feature-spec table, no feature IDs, and no acceptance criteria, while `plan-tune --product` and `plan-em` both depend on those. This is contract drift, not prose quality, and it is fixable with targeted template and section-number edits.

---

## Quality Assessment

### Strengths

- **Deterministic protocol.** Six numbered steps, unconditional `Step X/6` emission (SKILL.md:40), and a multi-PRD prefix convention (`[PRD N/K] Step X/6`, SKILL.md:42). Numbering is resolved by a script (`scan-n.prd`, SKILL.md:117-119) with a `$HOME` fallback, not by guessing.
- **Graceful degradation.** The absent-file rule (SKILL.md:57) is explicit and non-blocking, and refuses to create devkit files (ownership stays with `msg-init`). This matches `plan-em`'s identical rule.
- **Principles ref.** `refs/principles.md` covers exact-values-over-approximations, no-weasel-words, one-requirement-one-buildable-unit, resolve-contradictions-before-output. These are the rules for an agent-readable PRD.
- **Multi-PRD sequencing.** Epic detection criteria are concrete (SKILL.md:69-72), the breakdown table uses `?` placeholders resolved per-PRD at Step 4 (SKILL.md:83), and the loop suppresses the per-PRD open-questions loop and next-step prompt, emitting a single final summary (SKILL.md:91, 198-202).
- **Interview.** Platform is auto-detected, not asked (protocol-interview.md:11-21); Q4 error-case generation is systematic and per-feature (protocol-interview.md:72-78); `multiSelect` + "Other" everywhere.

### Weaknesses (with evidence)

**W1 — CRITICAL: the PRD has no feature-spec table, no feature IDs, and no acceptance criteria.**
The final `template-prd.md` sections are: §1 Out-of-scope, §2 Target platform, §3 User flows, §4 Key user interactions, §5 Error cases, §6 Open questions, §7 Glossary. There is no Requirements / feature-spec section and no F1/F2 IDs in the template (confirmed: `grep F1|acceptance template-prd.md` → 0 matches). Features exist only as an interview-time intermediate (`template-feature-table.md`) that is not written to the PRD ("This table is presented inline … not written" intent; final template omits it).
- `plan-tune --product` treats "any feature row without an acceptance criterion" as Critical and "missing target user" as Critical. A clean plan-pm PRD trips both by construction.
- `plan-em` builds its Execution Table keyed on `<ID>: <name> — <concern>` Feature cells (plan-em SKILL.md:202) and needs stable F-IDs. The delivered PRD provides none, so the exec-table skeleton has no reliable enumeration source. plan-em falls back to "the feature list" but the PRD has no canonical feature list section.

**W2 — CRITICAL: §3 section-number mismatch with plan-em.**
plan-em Step 3a derives the `/cook` roster from "PRD §3 (Platform)" (plan-em SKILL.md:144). In plan-pm's template, §3 is "User flows" and platform is §2 ("Target platform"). plan-em reads ASCII flow diagrams where it expects a platform spec, degrading roster derivation.

**W3 — CRITICAL: frontmatter field-name mismatch with plan-em.**
plan-em's tune gate reads a field named `tuned:` (plan-em Step 2). plan-pm's `template-prd.md:23-24` writes `product-tuned: no` and `eng-tuned: no` — there is no `tuned:` field. plan-em's gate always reports the tune as "absent" and never recognizes a completed product tune.

**W4 — MAJOR: internal §6 vs §8 contradiction for Open questions.**
SKILL.md:33 (Persona) says "Open questions go in §8." Everywhere else — the Step 5 mapping table (SKILL.md:157), AHA references (SKILL.md:178), the loop (SKILL.md:210), and the template (template-prd.md:120) — says §6. `protocol-interview.md:19` also says "record it as an open question in §8." The §8 references are stale (the template has only 7 sections).

**W5 — MAJOR: AHA.md / ARCHITECTURE.md path drift (root vs devkit/).**
The pre-run table reads `devkit/AHA.md` and `devkit/ARCHITECTURE.md` (SKILL.md:50-55), but:
- Step 6 AHA update writes to bare `AHA.md` at root (SKILL.md:182, 190) and copies the header template from `.claude/skills/msg-init/refs/template-AHA.md` — so learnings land at root while everything else reads `devkit/AHA.md`. The notes are written where nobody reads them. (This class of bug was already fixed in `eng`, per `evals/eng-fix-plan.md:27-28`.)
- `protocol-interview.md:13-16` reads `ARCHITECTURE.md` at root (`[[ -f ARCHITECTURE.md ]]`) for platform detection, contradicting the skill's own `devkit/ARCHITECTURE.md` convention. On a real `msg-init` project, platform detection returns empty and defaults to `TBD`.

**W6 — MAJOR: dangling §4 acceptance-criteria claim.**
`template-feature-table.md:20` states acceptance criteria "belong in the PRD (§4)." But §4 in `template-prd.md` is "Key user interactions," which contains no acceptance criteria. The claim points at the wrong section and at content the PRD never produces.

**W7 — MAJOR: rtk leakage in a shipped ref.**
`protocol-interview.md:16` hard-codes `rtk bash -c '…'`. `rtk` is the user's personal global tool (CLAUDE.md), not a project dependency. A shipped skill invoking `rtk` will fail on any machine without it. Should be plain `bash -c` or inline shell.

**W8 — MINOR: Q3 dependencies never reach `depends_on` frontmatter.**
Q3 captures dependencies (protocol-interview.md:62-69, e.g. "auth feature → OAuth provider"), but Step 4's `depends_on` is populated only from Step 2 prior-PRD overlap (SKILL.md:134). External/service dependencies from Q3 have no home in the PRD — they aren't a section and aren't frontmatter. The interview gathers data the output discards.

**W9 — MINOR: no success metrics anywhere.**
plan-tune --product checks Metric↔Feature and Metric↔Acceptance-criterion consistency (Dimension 2). plan-pm produces no metrics section and the interview never asks for one. A guaranteed downstream gap.

**W10 — MINOR: §2 is single-platform, plan-tune wants a priorities table.**
§2 "Target platform" records one detected platform. plan-tune --product expects a platform-priorities table (priority + reason per platform) — Major finding when absent.

---

## Improve (prioritized)

1. **Add a §X "Features & acceptance criteria" table to `template-prd.md`** *(fixes W1, W6, W8 partially)*
   - *What:* Insert a required section (suggest new §1 or §3) with columns `| ID | Feature | Acceptance criterion | Dependencies |`, populated from the confirmed Q1 feature list (carry the F1/F2 IDs forward from `template-feature-table.md`) and Q3 dependencies.
   - *Why:* Highest-leverage fix. It is the feature/ID source plan-em needs, the acceptance-criteria column plan-tune marks Critical when absent, and a home for Q3 dependencies. Without it the PRD is structurally incomplete for the pipeline.
   - *How:* Promote the interview feature table into the PRD (stop discarding it). Add one interview micro-step or derive acceptance criteria from Q5 interactions + Q4 error cases. Renumber sections and update every §-reference in SKILL.md and refs.

2. **Fix the §3-vs-§2 platform reference** *(fixes W2)* — Coordinate with plan-em: either renumber plan-pm so Platform is §3, or patch plan-em SKILL.md:144 to read `§2 (Target platform)`. Since this audit owns plan-pm, document the required plan-em edit and align the template so the platform section number is unambiguous.

3. **Reconcile the `tuned:` / `product-tuned:` frontmatter** *(fixes W3)* — Either add a `tuned:` alias or update plan-em's Step 2 gate to read `product-tuned`. Standardize on `product-tuned`/`eng-tuned` (already used by the lifecycle table SKILL.md:256-261) and fix plan-em. Flag this cross-skill.

4. **Purge all stale §8 references** *(fixes W4)* — Edit SKILL.md:33 ("§8" → "§6") and protocol-interview.md:19 ("§8" → "§6", or the new open-questions number after renumber). Grep the whole skill for `§8` before closing.

5. **Fix AHA.md and ARCHITECTURE.md paths to `devkit/`** *(fixes W5)* — SKILL.md:182, 190 → `devkit/AHA.md`. protocol-interview.md:13-16 → `devkit/ARCHITECTURE.md` (`[[ -f devkit/ARCHITECTURE.md ]]`). Mirrors the already-applied `eng` fix.

6. **Remove `rtk` from the shipped ref** *(fixes W7)* — protocol-interview.md:16 `rtk bash -c` → `bash -c`. Shipped skills must not depend on a user's personal tooling.

7. **Add a Target-user + Success-metrics capture** *(fixes W9, W10, plan-tune Criticals)* — Add a §0/§1 "Goal & target user" line (Intake already clarifies target user at Step 1 — persist it) and optionally a metrics question or a derived metrics stub. A minimal "Target user: X" line clears a plan-tune Critical.

---

## Remove

- **The stale §8 references** (SKILL.md:33, protocol-interview.md:19) — wrong, no §8 exists.
- **The dangling "(§4)" claim** in `template-feature-table.md:20` — either delete it or repoint it once a real acceptance-criteria section exists.
- **The `rtk` prefix** in protocol-interview.md:16 — environment leak, remove.
- **Consider folding `template-feature-table.md` into the PRD template.** Today it is a 20-line standalone ref describing an intermediate artifact that is thrown away. If Improve #1 promotes the feature table into the PRD, this ref's content moves into `template-prd.md` and the standalone file can be deleted — fewer tokens and one fewer disconnected artifact.
- **The PostToolUse "Hook note"** (SKILL.md:263) describes an alternative implementation that isn't wired up. Move to a design doc or cut.

**Token verdict:** 14.8K is not bloated — the worked examples in `template-prd.md` (habit-tracker flows) work as few-shot anchors. The waste is redundancy of broken references, not length. After the renumber + path fixes, the skill is appropriately sized.

---

## Introduce

1. **A "downstream contract" self-check at end of Step 5.** Before Step 6, have plan-pm verify its output against the two consumers: does §2/§3 platform align with what plan-em reads? Does every feature row have an acceptance criterion (plan-tune Critical)? Are there 0 §8 references? A 5-line checklist emitted as `Contract check: PASS/FAIL` would have surfaced W1–W4 automatically. High value, low effort.

2. **Persist Q3 dependencies as a real §.** Introduce a "Dependencies" subsection (external services, feature flags, data sources by identifier) — principles.md:51 already mandates "dependencies listed explicitly," but no section captures it. The interview gathers it; the output should keep it.

3. **Acceptance-criteria derivation pass.** Add a rule: for each confirmed feature, derive one verifiable acceptance criterion from its Q5 interaction + Q4 error case. principles.md:49 already says "every requirement has an acceptance criterion" — but the template gives them nowhere to live. Close the loop between the principle and the artifact.

4. **A platform-priorities mini-table in §2** when multiple platforms are detected — matches plan-tune's expectation and is cheap (the pre-flight script already emits multiple platform labels; today only one is used).

---

## Priority Ranking

| Recommendation | Impact | Effort |
|---|---|---|
| #1 Add Features & acceptance-criteria table to PRD template | High | Med |
| #2 Fix §3→§2 platform reference (coordinate w/ plan-em) | High | Low |
| #3 Reconcile `tuned:` vs `product-tuned:` frontmatter | High | Low |
| #5 Fix AHA.md / ARCHITECTURE.md paths to `devkit/` | High | Low |
| #4 Purge stale §8 references | Med | Low |
| #7 Capture target-user + success metrics | Med | Med |
| Introduce #1 Downstream contract self-check | Med | Low |
| #6 Remove `rtk` from shipped ref | Med | Low |
| Introduce #2 Persist Q3 dependencies as a section | Med | Low |
| Introduce #3 Acceptance-criteria derivation pass | Med | Med |
| Remove template-feature-table.md (fold into PRD) | Low | Low |
| Remove PostToolUse hook note | Low | Low |
| Introduce #4 Platform-priorities table | Low | Low |


---

# Skill: plan-tune

## Summary

`plan-tune` is the Staff PM adversarial auditor in the planning pipeline. It reads an existing PRD, runs a numbered, severity-tagged audit across 4 dimensions (`--product`) or 5 (`--eng`, adding eng-plan integrity), appends a dated `## Audit` section, and applies selected fixes in place. The audit content is calibrated against a PRD schema that plan-pm does not produce — multiple Dimension 1–4 fail-conditions reference sections (Target user, acceptance-criteria column, Platform priorities table, success metrics) that do not exist in `template-prd.md`. As shipped, the product tune emits false-positive Critical/Major findings on every real PRD, and the eng tune points at a `template-eng-plan.md` path that does not exist in this skill. The fixes are mostly re-calibration, not redesign.

## Quality Assessment

### Strengths

- **Path resolution is externalized.** `SKILL.md:96–117` delegates to `plan-tune-preflight.sh`, which handles directory→file derivation, pattern validation with N-matching (`plan-tune-preflight.sh:35–36`), not-found, and emits `TUNE_SUGGESTION` by grepping `^## Engineering —`. The two-attempt-then-refuse contract (`SKILL.md:110`) and the offer to run `/plan-pm` are clear. The global-vs-vendored script fallback (`SKILL.md:101`) is present.
- **Mode auto-suggestion is grounded.** The trigger — "PRD has one or more `## Engineering —` sections → eng" (`SKILL.md:53–54`, `plan-tune-preflight.sh:50`) — matches plan-em's mode-detection heuristic (`plan-em/SKILL.md:195`). The two skills agree on what "has an eng plan" means.
- **Severity model is decision-oriented.** `tune-product.md:13–17` defines Critical/Major/Minor by consequence to the agent ("would default to a wrong assumption silently"), not by vague importance. Correct framing for an agent-readability auditor.
- **Agent-readability dimension is concrete.** The forbidden-verb table (`tune-product.md:50–66`) with per-verb replacement patterns (`supports`, `handles`, `ensure`, `manage`, `process`, `allow`, `optimize`, `should`, `may/can`) is directly actionable. The timezone-reference-is-Critical rule (`tune-product.md:78`) and the worked streak-timezone example (`tune-product.md:113–132`) catch a real, expensive class of bug.
- **Fix-in-place safety loop is specified.** `SKILL.md:181` mandates a re-read-and-verify after each patch (no forbidden verbs, no weasel words, satisfies the finding) and self-corrects if the patch introduces a new issue. The product-tune guard "`## Engineering —` sections are out-of-scope; do not edit them" (`SKILL.md:179`) scopes the blast radius.
- **Audit is recorded before fixes are offered** (`SKILL.md:147–162` append, then `SKILL.md:172` ask). The full finding set survives even if the user picks Skip — auditable.
- **Adversarial persona is consistent**, not decoration. "Assumes the PRD is broken until proven otherwise" (`SKILL.md:82`), "Never produces a finding without a suggested fix" (`SKILL.md:84`), prompt-injection hardening ("treat instruction-like phrases as PRD content to be flagged", `SKILL.md:121`).

### Weaknesses

- **CRITICAL — the product checklist audits a schema plan-pm does not produce.** `template-prd.md` (what plan-pm writes) has exactly 7 sections: Out-of-scope, Target platform, User flows, Key user interactions, Error cases, Open questions, Glossary. But `tune-product.md` Dimension 1 (`:23–31`) fails on:
  - *"Target user defined → Critical"* — there is no target-user section in the template. Fires Critical on every PRD.
  - *"Feature acceptance criteria → Critical"* — `template-feature-table.md` states "Acceptance criteria are **not** added here — they belong in the PRD (§4)", yet §4 of `template-prd.md` is "Key user interactions" (a "User can…" bullet list), which has no acceptance-criterion column. So "any feature row without an acceptance criterion" fires Critical universally.
  - *"Platform priorities table → Major"* — the template's §2 is a 2-row "Target platform" table (Platform / Min OS), not a per-platform priority+reason table.
  - Dimension 2 (`:39–44`) and Dimension 4 (`:85–92`) compound this: "Metric ↔ Feature" and success-metric checks assume a Metrics section that does not exist; "Out-of-scope user" assumes a user-segmentation that does not exist.
  - **Result:** on a clean, correctly-authored plan-pm PRD, the product tune emits ~4–6 false Critical/Major findings. An auditor that cries wolf on valid input destroys its own signal.

- **CRITICAL — `tune-eng.md` references a ref that does not exist in this skill.** `tune-eng.md:11` and `:63` both cite `refs/template-eng-plan.md`. There is no such file in `plan-tune/refs/`. The real template lives at `.claude/skills/eng/refs/plan/template-eng-plan.md`. So Dimension 5f ("Check each engineering section against the quality gates in `refs/template-eng-plan.md`") and the §5/§7 section-number references (`tune-eng.md:15`, `:35`) point the auditor at a path it cannot read. The actual §-numbers in `eng/refs/plan/template-eng-plan.md` — §5 Scope mapping, §7 Integration contracts, §9 Migration, §13 Open questions — line up with what 5a/5c/5d/5e assume, so the checks are correct once the path is fixed.

- **MAJOR — frontmatter writeback is missing, causing a three-way field-name drift.** `template-prd.md:21–23` defines `status`, `product-tuned: no`, `eng-tuned: no`. plan-em reads a field called `tuned:` (`plan-em/SKILL.md:129`) — which matches neither. And plan-tune never updates any tuned flag after a successful run (grep of SKILL.md + refs finds zero writeback). So after plan-tune completes, the PRD still says `product-tuned: no`, plan-em's gate keeps asking the user to run a tune that already ran, and `/plan`'s sequencing can't trust the frontmatter. The auditor that exists to certify the PRD does not stamp its own certification.

- **MAJOR — Dimension 5f leans on a `refs/principles.md` that is mis-scoped for an auditor.** `plan-tune/refs/principles.md:3` opens "Five categories of rules for producing a PRD." This is the authoring principles file (it differs by md5 from plan-pm's and plan-em's copies — they have drifted). An auditor needs detection heuristics, not authoring rules; the overlap with Dimension 3's verb table is partial and the framing ("when drafting…", "before output…") is wrong-voice for a read-only audit pass.

- **MINOR — "Confirm read posture" is a no-op step.** Step 2/5 (`SKILL.md:135–137`) exists only to say "the PRD is already in context; no read needed unless truncated." It consumes a numbered step and a progress emission for nothing. Could fold into Step 1.

- **MINOR — summary-table column header collision.** The output table header is `What's the fix | How to fix | Why it matters` (`SKILL.md:167`), but the canonical finding format (`tune-product.md:98–108`) uses `What is wrong | Why it matters | Suggested fix`. "What's the fix" vs "What is wrong" are opposite meanings; an agent populating the table can put the problem in the fix column.

## Improve (prioritized)

1. **Re-calibrate Dimension 1–4 against the actual `template-prd.md` schema.** *Why:* this determines whether the audit is signal or noise. *How:* Rewrite `tune-product.md` checks to key off the 7 real sections. Replace "Target user defined" with a check on §1 Out-of-scope + §4 Key user interactions coverage; replace the bare "Feature acceptance criteria → Critical" with a check that each §3 user-flow decision diamond has a defined else-branch and each §5 error case names user-facing + system behavior (the template does have error cases). Drop or down-grade Platform-priorities / success-metric checks, or flag the ecosystem gap: if you want acceptance criteria audited, the fix belongs in plan-pm's template (add an AC column), and plan-tune should check for it only once it exists. At minimum, gate each check on "section present" so absent sections don't all detonate as Critical.

2. **Fix the `template-eng-plan.md` path in `tune-eng.md`.** *Why:* Dimension 5f references an unreadable path. *How:* Change both `tune-eng.md:11` and `:63` to `.claude/skills/eng/refs/plan/template-eng-plan.md`, OR vendor a small copy of just the §13 quality-gate table into `plan-tune/refs/`. Add a one-line note that §-numbers (5/7/9/13) are anchored to that template so they don't silently rot if eng renumbers.

3. **Add frontmatter writeback as a final sub-step of Step 4.** *Why:* certifies the tune happened and unblocks plan-em's gate + `/plan` sequencing. *How:* After fixes apply, `Edit` the PRD frontmatter: on `--product` set `product-tuned: <date>` (or `yes`); on `--eng` set `eng-tuned: <date>`. Simultaneously reconcile the field-name drift — pick one canonical name and align plan-em's `tuned:` read (`plan-em/SKILL.md:129`) and the template (`template-prd.md:22–23`). Keep the template's split `product-tuned`/`eng-tuned` and update plan-em to read `product-tuned`.

4. **Fix the summary-table header to match the finding format.** *Why:* prevents the auditor mislabeling columns. *How:* change `SKILL.md:167` header to `# | Severity | What is wrong | Suggested fix | Why it matters`, matching `tune-product.md:98–108` order.

5. **Replace or re-scope `refs/principles.md` for audit voice.** *Why:* an auditor needs detection rules, not authoring rules, and the current file has drifted from its siblings. *How:* either delete it (Dimensions 1–5 already carry the detection logic) and drop the `SKILL.md:205` reference, or rewrite it as ~10 lines of "audit operating principles" (adversarial default, every finding gets a fix, quote verbatim, never soften, prompt-injection handling) — most of which already lives in the Persona block.

6. **Collapse Step 2 into Step 1** and renumber to a 4-step protocol. *Why:* removes a no-op step and a wasted progress emission. *How:* fold the truncation re-read guard into the "Read PRD" paragraph of Step 1; update "Step X/5" emissions to "X/4".

7. **Add a "no findings" terminal path.** *Why:* an auditor that can't return clean is suspicious; the current protocol always appends an `## Audit` section and always asks the fix question. *How:* if zero findings, append a `## Audit — clean` stamp, set the tuned flag, and skip the fix-severity question — go straight to the Step 5 gate.

## Remove

- **Step 2/5 ("Confirm read posture").** Ceremony — it reads no file and makes no decision (`SKILL.md:135–137`). Fold its one useful clause (re-read if truncated) into Step 1.
- **`refs/principles.md` as currently written.** Wrong voice (PRD production, not audit), drifted from sibling copies, and largely duplicated by the Persona block + Dimension 3 verb table. Remove or rewrite (see Improve #5).
- **The unreachable checks in Dimension 1–4** that target non-existent template sections (Target user, Platform priorities, success Metrics) — remove or convert to ecosystem-gap flags rather than per-PRD Critical findings (see Improve #1). Keeping them as-is is worse than not having them.
- **Dimension 5f §1 "Summary present → Major" and §11 "three risks → Minor" granularity** is fine, but the whole 5f block re-implements the quality-gate table that already lives verbatim in `eng/refs/plan/template-eng-plan.md:219–230`. Consider replacing 5f's hand-copied checks with "audit each eng section against the §-numbered quality-gate table in template-eng-plan.md" to avoid two copies drifting.

## Introduce

- **Findings de-duplication / suppression list.** When plan-tune runs twice in `/plan` (product then eng), the second run re-reads the whole PRD including the first run's `## Audit` section and its fixes. There is no mechanism to avoid re-flagging an already-recorded-and-resolved finding, or to avoid auditing the prior `## Audit` block itself as PRD content. *Rationale:* prevents duplicate/echo findings across the two pipeline passes and stops the auditor critiquing its own audit text.
- **Severity-floor / auto-fix-Critical option.** Today Step 3 asks Critical/Major/Minor/Skip. In the `/plan` one-shot pipeline (which tells the user to pick the terminal gate option), unresolved Criticals can slip through. *Rationale:* offer a "fix all Critical automatically, ask about the rest" default so the pipeline can't ship a PRD with a known silent-wrong-default.
- **Cross-PRD consistency check (eng tune).** plan-em maintains `affects`/`depends_on` frontmatter and reconciles breaking changes. plan-tune's Dimension 5 audits only the single PRD in isolation. *Rationale:* a Dimension 5g could verify that any breaking change named in an eng section is reflected in the frontmatter `affects` list — catching the case where eng introduces a contract break that plan-em's reconciliation missed.
- **Glossary/GLOSSARY.md cross-check.** Dimension 1 checks for an in-PRD glossary entry (`tune-product.md:30`) but never validates against the project-level `devkit/GLOSSARY.md` that plan-em loads. *Rationale:* a term defined differently in the PRD vs the canonical glossary is the silent-divergence class this auditor exists to catch.
- **Machine-readable findings sidecar (optional).** The audit is markdown-in-PRD only. A small `features/prd-[n]/audit-[date].json` (or appended frontmatter counts) would let `/plan` and `/ship` gate on `unresolved_critical > 0` programmatically rather than parsing prose. *Rationale:* the pipeline currently relies on the human reading the summary table; a structured count makes the gate enforceable. (Counter-note: SKILL.md markets "No separate report file" — weigh this against that design stance; appending counts to frontmatter is the lighter-touch option.)

## Priority Ranking

| Recommendation | Impact | Effort |
|---|---|---|
| #1 Re-calibrate Dim 1–4 to real `template-prd.md` schema | High | Med |
| #2 Fix `template-eng-plan.md` path in tune-eng.md | High | Low |
| #3 Frontmatter writeback + reconcile `tuned` field-name drift | High | Low |
| #4 Fix summary-table column-header collision | Med | Low |
| Auto-fix-Critical / severity-floor option (Introduce) | Med | Low |
| #7 "No findings" clean terminal path | Med | Low |
| #6 Collapse no-op Step 2 → 4-step protocol | Med | Low |
| Findings de-dup across the two pipeline passes (Introduce) | Med | Med |
| GLOSSARY.md cross-check (Introduce) | Med | Med |
| #5 Re-scope/remove `refs/principles.md` | Low | Low |
| Cross-PRD `affects` consistency check, Dim 5g (Introduce) | Low | Med |
| Machine-readable findings sidecar (Introduce) | Low | Med |

### Token-efficiency note

SKILL.md is ~13.0K (12,996 bytes); refs total ~15.3K. Most of SKILL.md is justified — the verbose parts are the error-handling protocol (Step 1) and the two end-gate option sets (Step 5), both of which carry branching logic. The trim wins are Step 2 (no-op, Improve #6) and `refs/principles.md` (3.5K of mis-scoped, duplicated, drifted content, Remove). Estimated ~4K of fat against ~28K total. The bigger cost is not bytes but wasted-finding tokens at runtime: every false-positive Critical from the mis-calibrated Dimension 1 costs the worked-format ~150-token finding plus a fix-loop, so Improve #1 is also the largest runtime token saver.


---

# Skill: plan-em

## Summary

`plan-em` is the Engineering Manager stage of the PRD pipeline (`plan-pm → plan-tune --product → plan-em → plan-tune --eng`). It validates an approved PRD, runs a devkit pre-flight, reconciles multi-PRD breaking changes, proposes a language-targeted specialist roster behind an approval gate, dispatches `eng` subagents that write `## Engineering —` sections plus an execution table into the PRD, bootstraps the dev `eval_set`, and synthesises a severity-tagged findings report. It ships with three contract bugs that break the run at runtime: a frontmatter field name mismatch, a PRD-path glob mismatch, and a false premise about what `/cook` returns. SKILL.md also carries bloat that should move to refs.

---

## Quality Assessment

### Strengths

- **Output contract is buildable.** The execution table (`refs/template-exec-table.md`) decomposes every feature into `(feature, concern)` rows with a Feature/Agent/Execution-steps schema, and the downstream `eng` skill consumes that shape — `eng/SKILL.md:48-50` requires `rows` as "the exact `<ID>: <name> — <concern>` text of a Feature cell", which matches `template-exec-table.md:17` and plan-em `SKILL.md:202`. The handoff identifiers line up. This is the central contract in the pipeline and it is correct.
- **Engineering sections are deep.** The plan-mode output template (`eng/refs/plan/template-eng-plan.md`) that plan-em's agents fill has 13 mandatory sections with worked examples and a quality-gate table (§215-231) — alternatives-considered, design decisions with pros/cons, integration contracts (API/schema/auth/webhooks all mandatory), migration + rollback, risks (≥3), and an "exact identifiers verified against codebase scan, no guessed names" gate.
- **Pre-flight is comprehensive** (`SKILL.md:77-94`): seven ordered reads (AHA/GLOSSARY/ARCHITECTURE/CLAUDE/DESIGN-SYSTEM/OPEN-QUESTIONS/PRD) each with a stated "how to apply", plus a multi-PRD cross-reference with a frontmatter-fast-scan / full-read-only-when-flagged optimization (`SKILL.md:89-94`).
- **Approval gates are placed correctly.** Roster approval (`SKILL.md:157-161`), breaking-change reconciliation via per-relationship `AskUserQuestion` (`SKILL.md:96-99`), and a Critical-findings resolution gate before completion (`SKILL.md:242`). The persona anti-pattern "Never activates agents without human approval" (`SKILL.md:59`) is enforced.
- **Frontmatter writeback** (`SKILL.md:101-106`) closes the loop — confirmed dependencies/overlaps are written back to both the input PRD and prior PRDs.
- **Token-aware** at runtime: "Do not hold the full report in context… emit inline only the actionable findings" (`SKILL.md:117`). The SKILL.md file itself is bloated (see below).
- **Mode auto-detection** (`SKILL.md:195`): scanning for `## Engineering —` to pick plan vs build is the same signal plan-tune uses (`plan-tune/SKILL.md:53-54`), so the ecosystem is consistent on that point.

### Weaknesses (with evidence)

- **CRITICAL — BUG 1 — frontmatter field name mismatch (Step 2 gate is dead code).** `SKILL.md:129` reads: *"Check the PRD's `tuned:` frontmatter field."* No such field exists. `plan-pm` writes `product-tuned: no` and `eng-tuned: no` (`plan-pm/SKILL.md:137-138`, lifecycle table `:259-260`). The `tuned:` field is always absent, so the gate's "if the field is absent, note it" branch fires every time and the product-tune state is never read. The gate checks a field that does not exist in the contract.
- **CRITICAL — BUG 2 — PRD path/glob mismatch (validation can reject valid PRDs).** plan-em validates against `features/prd-*/prd-*.md` (`SKILL.md:24,32,75`) and derives `n` from "the parent directory name." But `plan-pm` writes to `features/prd-[n]-[feature_slug]/prd-[n]-[feature_slug].md` (`plan-pm/SKILL.md:127-129`) — the directory carries a slug. The glob `features/prd-*/` still matches (the `*` absorbs `-slug`), but every literal path plan-em emits is wrong: `features/prd-[n]/preflight.md` (`:45,108`), the handoff string `/plan-tune features/prd-[n]/prd-[n].md` (`:133`), and the eval_set destination `features/prd-[n]/` (`:47,207`). The real directory is `features/prd-[n]-[slug]/`. Deriving `n` "from the parent directory name" is under-specified — the dir is `prd-3-habit-tracking`, so `n` extraction must strip the slug, which the SKILL never states. `plan` uses `features/prd-[n]-[slug]/` (`plan/SKILL.md:48,84,87`), so plan-em is the odd one out.
- **CRITICAL — BUG 3 — `/cook` does not return what Step 3a claims.** `SKILL.md:144` asserts: *"The platforms `/cook` returns coverage for are the canonical agent identifiers — use them to name agents (`eng-<platform>`)… `/cook` is the authority on what platforms are supported."* This is false. `/cook` (`~/.claude/skills/cook/SKILL.md:3,55,268-309`) is a coding-standards orchestrator: it takes a task summary, matches keywords to concern/domain rule libraries, and returns *"a single compiled standards payload"* — a JSON envelope of rules bucketed Universal→Domain→Concern with a `degraded` flag. It does not enumerate "platform coverage", does not return agent identifiers, and has no platform mode flags (`cook/SKILL.md:55`). The downstream `eng` skill calls `/cook` for its true purpose (`eng/SKILL.md:136-145`: "keyword-driven… build a task summary… sole source of coding standards"). So plan-em mis-describes `/cook` and duplicates the call `eng` already makes — Step 3a fetches standards plan-em never uses (it only needs platform names), then each `eng` subagent fetches them again. Derive the roster from PRD §2/§3 (platform) and the feature list, not from `/cook`.
- **MAJOR — Roster heuristic is thin.** Step 3b (`SKILL.md:148-161`) says "one agent per language/platform stack" and "don't merge `eng-ios`/`eng-android`", but gives no guidance for the cases that drive roster size: when does backend split from a BFF? Is there ever a dedicated `eng-infra`/`eng-data`/`eng-qa`? The roster depends on Step 3a's `/cook` call, which (per BUG 3) produces no platform list. With `/cook` removed, the SKILL has no method for deriving the platform set from the PRD.
- **MAJOR — Build-mode branch creation is duplicated.** `SKILL.md:209` creates the feature branch in build mode, but the branch name convention is defined three times (`:220-224` plan-mode suggestion, `:244-250` synthesis suggestion, and referenced from `eng/refs/plan/template-eng-plan.md` §10). Three sources of truth for one string (`feat/prd-[n]-<short-name>`) invite drift, and the slug bug (BUG 2) means `[n]` derivation is already shaky.
- **MAJOR — Step 5 "Run eng --build" re-invokes plan-em, not eng.** `SKILL.md:263`: selecting "Run eng --build" calls `Skill("plan-em", "<prd-path>")` again, relying on mode auto-detect. The option is labelled "Run eng --build" but invokes plan-em. A reader auditing the flow must know the mode-detection trick to see it doesn't recurse forever. It works, but the contract is implicit.
- **MAJOR — `preflight.md` is an undeclared pipeline artifact.** plan-em writes `features/prd-[n]/preflight.md` (`:108`) but no downstream skill reads it. `plan-tune --eng` audits the PRD's engineering sections, not preflight.md. It's a write-only file, listed as a first-class Output (`:45`) with no consumer, and the overwrite behavior means a prior run's findings vanish silently.
- **MINOR — `DESIGN-SYSTEM.md` double-listed in References** (`SKILL.md:271-272`) — once inside the `devkit/` bullet and again as its own bullet with a path that drops the `devkit/` prefix (`DESIGN-SYSTEM.md` vs `devkit/DESIGN-SYSTEM.md`). The bare path is wrong post-`msg-init` (everything lives under `devkit/`).

---

## Improve (prioritized)

1. **Fix the frontmatter gate (BUG 1).** *What:* Replace `tuned:` at `SKILL.md:129` with `product-tuned:`. *Why:* the Step 2 gate currently never reads real state. *How:* `Check the PRD's product-tuned: frontmatter field (read in Step 1). If product-tuned: no or absent, note it in the question context.` Optionally auto-skip the gate when `product-tuned: yes` rather than always asking.

2. **Fix all PRD paths to carry the slug (BUG 2).** *What:* Change every `features/prd-[n]/…` literal to `features/prd-[n]-[slug]/…` (`:45,47,108,133,207` and the Inputs glob `:24,32,75`). *Why:* plan-pm writes slugged dirs; plan-em's emitted paths are wrong. *How:* Validate against `features/prd-*/prd-*.md` (keep), but resolve and store the *actual* matched directory once at Step 1 as `$PRD_DIR`, and write every artifact relative to `$PRD_DIR` instead of reconstructing `features/prd-[n]/`. Add an explicit `n` extraction rule: "`n` is the first numeric segment of the parent dir name (`prd-3-habit-tracking` → `n=3`)."

3. **Rewrite Step 3a — stop using `/cook` to derive the roster (BUG 3).** *What:* Remove the claim that `/cook` returns platform coverage / agent identifiers (`:142-146`). *Why:* wrong about `/cook`'s contract and duplicates the standards fetch `eng` already does. *How:* Derive the platform set from PRD §2 (Target platform) and §3, plus the `Files touched`/`Components` hints plan-pm writes into §3 (`plan-pm/SKILL.md:162-168`). Name agents `eng-<platform>` from that set. Keep one sentence: "Coding standards are fetched per-stack by each `eng` subagent at its Step 4, not here." Delete the "uncovered platform" gate or re-anchor it on "PRD targets a platform with no known `eng` support."

4. **Add a roster-sizing rubric.** *What:* a decision table for splitting agents. *Why:* with `/cook` removed, the SKILL needs a method. *How:* in `refs/principles.md` (it has a "Team and organization" section citing Conway's Law, `:55-63`) add: platform stacks always split (ios/android/web/backend); a 4th agent (`eng-infra`/`eng-data`) only when the PRD introduces new infra or a data pipeline; never a `tests` agent (tests are owned per-stack, matching `template-exec-table.md:33`).

5. **Single-source the branch-name convention.** *What:* define `feat/prd-[n]-<short-name>` once. *Why:* it appears 3× (`:220-224`, `:244-250`, plus eng template §10). *How:* state it once in Step 3 (when `n` and short-name are first derived), then reference it in Steps 4 and 5 as "the branch derived in Step 3."

6. **Clarify the Step 5 "Run eng --build" option.** *What:* relabel to "Begin build (re-runs plan-em in build mode)" or add a one-line note. *Why:* the label/behavior mismatch at `:263` misleads maintainers.

---

## Remove

- **The entire `/cook` call in Step 3a** (`SKILL.md:142-146`) — it fetches coding standards plan-em never consumes and that every `eng` subagent re-fetches anyway (`eng/SKILL.md:136-145`). Duplicated work plus a false premise. Replace with PRD-driven platform derivation (Improve #3).
- **Move ~40% of SKILL.md prose to refs.** At ~276 lines / 18.7K the file is large, and much of it is protocol body that belongs in a ref, not the always-loaded SKILL.md spine:
  - The full multi-PRD cross-reference protocol (`:88-106`, ~19 lines of dependency/breaking/overlap classification + writeback rules) → `refs/protocol-multi-prd.md`. Step 1 references it.
  - The two near-identical agent-dispatch prompt blocks (`:197-218`, plan mode and build mode each enumerate the same 5-6 numbered prompt fields) → collapse to one parameterized block; the only deltas are `--plan`/`--build` and the `branch` field. This removes ~12 redundant lines.
  - The pre-flight "how to apply" per-file detail (`:77-87`) stays inline. But the AHA.md-update conditional block (`:174-189`) is duplicated almost verbatim in `plan-pm/SKILL.md:174-190` — extract the AHA-append format to a shared ref both reference.
- **`DESIGN-SYSTEM.md` duplicate References bullet** (`:272`) — collapse into the `devkit/` line; fix the missing `devkit/` prefix.
- **The "Plan-mode branch suggestion" block** (`:220-226`) duplicates the Step 5 synthesis branch block (`:244-250`) — keep the Step 5 one and drop the Step 4 duplicate, or vice versa.

---

## Introduce

- **A roster→exec-table coverage assertion.** After the skeleton is built (`SKILL.md:163-172`), add a gate: "every PRD feature ID appears in ≥1 exec-table row, and every row's Agent is in the approved roster." This catches a feature with no owner before agents spin up. The eng plan template asserts the inverse (`template-eng-plan.md:223` "Every assigned PRD feature ID appears in §5") but plan-em never checks its own skeleton for completeness.
- **Make `preflight.md` a consumed artifact or demote it.** Either (a) have the synthesis step (Step 5) read `preflight.md` back and fold unresolved blocking findings into the numbered findings list, so pre-flight warnings can't be dropped, or (b) demote it from "Output" to "scratch artifact" and stop overwriting prior runs (append with a run timestamp).
- **Eval_set bootstrap guard.** Step 4 invokes `/test --prd` (`:207`), which exists and is correctly contracted (`test/SKILL.md:37,196,199`). Add: skip the bootstrap in build mode (it's gated "plan mode only" in prose but the mode boundary at `:207` is easy to misread), and assert the PRD has acceptance criteria before calling — the SKILL notes "zero executable assertions… is a planner signal," so surface that as a Minor finding in the synthesis rather than a one-line note.
- **A `model:` note.** plan-em pins `model: claude-opus-4-7` (`:9`) while `eng` runs `claude-sonnet-4-6` (`eng/SKILL.md:5`). That's a manager(opus)/worker(sonnet) split, but it's undocumented — add a one-line note in Persona so a maintainer doesn't drop plan-em down to sonnet and lose synthesis quality.

---

## Priority Ranking

| Recommendation | Impact | Effort |
|----------------|--------|--------|
| Fix `tuned:` → `product-tuned:` frontmatter gate (BUG 1) | High | Low |
| Fix slugged PRD paths + `n` derivation (BUG 2) | High | Low |
| Rewrite Step 3a — drop `/cook` roster premise, derive from PRD §2/§3 (BUG 3) | High | Med |
| Add roster→exec-table feature-coverage gate | High | Low |
| Add roster-sizing rubric to principles.md | Med | Low |
| Move multi-PRD protocol + dedupe dispatch blocks to refs (bloat) | Med | Med |
| Single-source the branch-name convention | Med | Low |
| Clarify Step 5 "Run eng --build" label | Med | Low |
| Make preflight.md consumed (fold into synthesis) or demote it | Med | Med |
| Document opus/sonnet model split in Persona | Low | Low |
| Fix duplicate/mis-pathed DESIGN-SYSTEM.md References bullet | Low | Low |


---

# Skill: plan

## Summary

`plan` is a one-shot orchestrator that drives the full PRD pipeline (`plan-pm → plan-tune --product → plan-em → plan-tune --eng`) in a single linear pass with no loop. It identifies which sub-skill gates to terminate at and which intrinsic pauses to honour. It carries one critical defect: by instructing the user to pick the terminal option at every stage gate, it bypasses every frontmatter status-update hook (those live only in the non-terminal "continue" branches), so a completed `/plan` run leaves all PRD status fields (`status`, `product-tuned`, `eng-tuned`) stale. It also has no failure or partial-run handling.

---

## Quality Assessment

### Strengths

1. **Lean orchestrator.** SKILL.md is 98 lines and owns no audit/authoring protocol of its own (plan/SKILL.md:26). It threads the resolved PRD path forward and delegates everything. No duplication of sub-skill logic.

2. **Identifies the double-drive hazard.** Each sub-skill runs its own end-of-run prompt, and several of those prompts invoke the next skill rather than recommend it. The Stage-gate table (plan/SKILL.md:59-64) tells the orchestrator to pick the terminal option so the next stage isn't run twice. Verified against the sub-skills:
   - plan-pm next-step prompt invokes `Skill("plan-tune"...)` / `Skill("plan-em"...)` on non-terminal choices (plan-pm/SKILL.md:226-227). Picking "Terminate" is correct.
   - plan-em Step 5 invokes `Skill("plan-tune"..."--eng")` and re-invokes plan-em for build (plan-em/SKILL.md:262-264). Picking "Skip" is correct.
   - plan-tune Step 5 is recommend-only — "Output the recommendation as the final message. Do not invoke another skill." (plan-tune/SKILL.md:201). So plan-tune does not double-drive, and plan drives sequencing itself (plan/SKILL.md:95).

3. **Intrinsic vs. chaining pauses are separated** (plan/SKILL.md:68-72). The four interactive pauses (requirements interview, roster approval, breaking-change reconciliation, fix-severity selection) are real and map to sub-skill behaviour (plan-pm Step 3; plan-em 3b line 157-160; plan-em breaking-change line 96-99; plan-tune Step 3 line 172).

4. **Multi-PRD epic handling is explicit** (plan/SKILL.md:74-76). plan-pm has a multi-PRD mode that completes all PRDs then terminates (plan-pm/SKILL.md:89-91, 200-202). plan stops after plan-pm and tells the user to run `/plan` per-PRD; the alternative (looping tune/em over N PRDs in one driver) would be more fragile.

5. **States its own limitation.** Lines 38-42 and 83-90 are direct: "It runs each stage exactly once and then stops" and "If a tune left critical or major findings unresolved... list them in the summary — never exit silently." It does not over-promise convergence.

### Weaknesses

1. **CRITICAL — completed runs leave PRD status frontmatter stale.** The PRD lifecycle (plan-pm/SKILL.md:252-263) defines four status fields that downstream skills (`/ship`, `/review`, plan-em's own Step 2 tune-gate) read. Every update to those fields is wired into the non-terminal branch of a stage gate:
   - `product-tuned: yes` — only written when plan-pm's next-step prompt invokes plan-tune (plan-pm/SKILL.md:226), the branch plan tells the user to avoid.
   - `status: eng` — per the lifecycle table "Updated by plan-em" (plan-pm/SKILL.md:257), but the only write instruction is in plan-pm line 227's invoke-plan-em branch. plan-em's protocol never writes `status: eng` (grep confirms no such write in plan-em/SKILL.md).
   - `eng-tuned: yes` — "Updated by plan-tune --eng (via next-step prompt)" (plan-pm/SKILL.md:260), but plan-tune Step 5 is recommend-only and writes no frontmatter (plan-tune/SKILL.md:187-201).

   Result: when `plan` drives the pipeline and picks every terminal option, none of these fields update. The PRD ends eng-tuned in substance but reads `status: product, product-tuned: no, eng-tuned: no`. plan's completion summary claims `Status: eng-tuned.` (plan/SKILL.md:86), which is false at the frontmatter level. A subsequent `/ship` or a re-run of plan-em (whose Step 2 gate reads `tuned:`) mis-detects the PRD as un-tuned. plan does not write these fields itself, and the sub-skill code paths that would write them are the ones plan suppresses.

2. **No failure handling.** There is no instruction for what happens if a stage errors mid-pipeline. If plan-em refuses (missing devkit → plan-em/SKILL.md:87 "stop. Do not proceed"), or `/cook` returns no coverage and the user can't resolve it, or a subagent fails to write its section — plan has no defined behaviour. It will advance into stage 4 (`plan-tune --eng`) on an incomplete PRD. There is no "stop the pipeline if a prior stage did not complete its contract" check.

3. **No resume / partial-run capability.** plan re-derives nothing from PRD state, so there is no way to run `/plan` and pick up from stage 3 on a PRD that already has a product tune. It always starts at plan-pm (interview included). A user who already has a PRD cannot use `/plan` to finish the pipeline — they must invoke plan-em + plan-tune manually. The skill acknowledges plan-em/plan-tune can be invoked directly (plan/SKILL.md:97) but offers no entry point for a mid-pipeline PRD.

4. **Stage-gate table is brittle to wording drift.** The table (plan/SKILL.md:59-64) hard-codes the option labels of each sub-skill's gate ("Continue to plan-em / Re-run plan-pm / Stop here" etc.). These are verbatim copies of sub-skill UI (plan-tune/SKILL.md:192-194, plan-em/SKILL.md:257-259). If a sub-skill renames a gate option, plan's guidance points at a label that no longer exists, and the orchestrator may pick the wrong one. The instruction "Always pick the terminal option" (line 66) is the rule; the table is a restatement that can rot.

5. **`/test --prd` eval_set bootstrap is owned by plan-em, but plan claims it.** plan/SKILL.md:50 says stage 3 "bootstraps the development `eval_set` via `/test --prd`." That's accurate (plan-em/SKILL.md:207 does this in plan mode), but it's a sub-skill internal — plan cannot verify it happened and its summary never reports the assertion count. The completion summary (lines 82-88) is silent on eval_set status, the most build-relevant artifact plan produces.

6. **No status reporting between stages.** plan emits one summary at the end (lines 82-88) but nothing as each stage completes. For a 4-stage, multi-pause pipeline, the user gets no "Stage 2/4 complete — product tune applied, 3 findings fixed" breadcrumbs. plan-pm/plan-em/plan-tune emit `Step X/N` internally, but plan never frames which pipeline stage is running.

---

## Improve (prioritized)

1. **Make plan responsible for frontmatter status writes.** plan bypasses the gate branches that update status, so plan must do the writes itself. After each stage returns, patch the PRD frontmatter via `Bash`/sed:
   - After stage 2 (plan-tune --product) → `product-tuned: yes`
   - After stage 3 (plan-em) → `status: eng`
   - After stage 4 (plan-tune --eng) → `eng-tuned: yes`
   **Why:** without this, a `/plan` run produces a PRD whose status fields lie, breaking `/ship`, `/review`, and plan-em re-entry. **How:** add a one-line `sed -i` after each stage in the Stage-sequence section (plan/SKILL.md:48-51), referencing the resolved PRD path. (Also flag the upstream `tuned:` vs `product-tuned:` field-name mismatch — plan-em/SKILL.md:129 reads `tuned:` while plan-pm writes `product-tuned:` — but that is a sub-skill bug, not plan's to fix.)

2. **Add a between-stage completion check + abort rule.** Before invoking each next stage, verify the prior stage met its contract: stage 2/4 require the PRD file still exists and (for stage 4) carries `## Engineering —` sections; stage 3 requires those sections were written. **Why:** prevents running an eng tune on a PRD plan-em failed to populate. **How:** add a "Between-stage guard" subsection: "If the expected artifact from the prior stage is absent (e.g. plan-em wrote no `## Engineering —` section), STOP, emit which stage failed and what's missing, and do not invoke the next stage."

3. **Add explicit failure-handling guidance.** Document what plan does when a sub-skill refuses or errors: e.g. plan-em refuses on missing devkit (plan-em/SKILL.md:87), plan-tune refuses on bad path. **Why:** currently undefined. **How:** one subsection — "If a stage refuses or aborts, do not advance. Emit a partial-completion summary naming the last successful stage and the suggested manual recovery command."

4. **Add a partial-pipeline / resume entry mode.** Let `/plan <prd-path>` skip to the first stage that PRD hasn't passed (read `product-tuned` / `status` / `eng-tuned` from frontmatter and resume). **Why:** lets users finish a half-planned PRD without re-interviewing. **How:** at intake, if input resolves to an existing PRD path, branch: read frontmatter, determine the first incomplete stage, start there. (Depends on Improve #1 making those fields trustworthy.)

5. **Replace the verbatim gate-label table with the rule plus a one-line example.** Keep "Always pick the terminal option at each gate" (line 66) as the instruction; demote the per-stage label table to one example or drop it. **Why:** the verbatim labels rot when sub-skills change wording. **How:** collapse lines 59-64 to: "Each gate offers a 'continue/invoke' option and a terminal option (Stop/Skip/Terminate). Always choose the terminal one — plan drives the next stage itself."

6. **Emit per-stage progress breadcrumbs and surface eval_set count.** Emit `Stage N/4 — <name> complete` after each return, and capture plan-em's eval-set assertion count into the final summary. **Why:** observability over a long interactive run; eval_set readiness is the signal for whether `/ship` can proceed. **How:** add a progress line to each numbered item in the Stage-sequence section, and add an `Eval-set: N assertions` line to the Termination summary block (lines 82-88).

---

## Remove

1. **The verbatim per-stage gate-option table (plan/SKILL.md:59-64).** Duplicates sub-skill UI strings and rots on wording drift. The rule "always pick the terminal option" (line 66) is sufficient. (See Improve #5 — replace the concept, but cut the four hard-coded label rows.)

2. **The parenthetical meta-commentary "(This double-drive is the cost of removing loop mode...)" (line 66) and "There is no `--from-loop` contract anymore" (line 42).** Changelog notes about a removed feature. No operational value to an agent executing the skill today. Keep the behavioural rule; drop the historical justification.

3. **The restated "What plan does and does not do" section (lines 38-42) duplicates the description and the intro (lines 20, 26).** The "no loop, single pass" point is made in the frontmatter description, the H1 intro, the ASCII diagram, and this section. Consolidate to one statement.

---

## Introduce

1. **Frontmatter status reconciliation (also Improve #1) as a first-class plan responsibility**, with a closing "Status fields written: status=eng, product-tuned=yes, eng-tuned=yes" line in the summary so the user can confirm the PRD is tagged. This is the most valuable capability to add — it makes plan's output consumable by `/ship`.

2. **A `--dry-run` / plan-preview mode** that lists the four stages, the PRD path it would create or use, and the pauses to expect, without running anything. Low effort, useful for a 4-stage interactive pipeline.

3. **Resume-from-PRD mode** (also Improve #4): `/plan <existing-prd-path>` resumes at the first incomplete stage. Turns plan from interview-only entry into a pipeline-completion tool.

4. **An end-of-run handoff to `/ship`** conditional on zero unresolved Critical/Major tune findings — offer (via AskUserQuestion) to chain into `/ship` when the PRD is clean, since plan's suggested next step is already `/ship` (line 87). Optional; keeps plan as planning-only by default but smooths the planning→build seam.

---

## Priority Ranking

| Recommendation | Impact | Effort |
|---|---|---|
| #1 plan writes frontmatter status fields itself after each stage | High | Low |
| #2 Between-stage completion check + abort | High | Low |
| #3 Explicit failure-handling guidance | High | Low |
| #6 Per-stage progress + eval_set count in summary | Med | Low |
| #5 / Remove#1 Replace verbatim gate-label table with the rule | Med | Low |
| #4 / Introduce#3 Resume-from-PRD partial-pipeline mode | Med | Med |
| Remove#2/#3 Cut historical meta-commentary & duplicated "does/does not" prose | Low | Low |
| Introduce#2 `--dry-run` preview | Low | Low |
| Introduce#4 Conditional `/ship` handoff | Low | Med |


---

# Skill: eng

## Summary

`eng` is the platform-agnostic engineering worker in the msg build pipeline. It has two mode protocols — `--plan` (write an engineering section into the PRD, no code) and `--build` (TDD-implement exec-table rows on a sub-branch, open a PR). It is invoked as a parallel subagent by `plan-em` and `ship`, and is not run standalone in the normal flow. It uses a shared-spine/mode-fork structure with lazy ref loading. Three problems: (1) a description/menu mismatch claiming a third "review" mode that does not exist, (2) an agent-naming convention collision with `plan-em`, and (3) silent contradictions between `eng --build`'s full-suite gate and how `ship` drives it.

---

## Quality Assessment

### What artifact does it produce?

- **`--plan`**: A 13-section engineering section appended to the PRD under `## Engineering — <Agent>`, plus filled-in **Execution steps** cells for every owned exec-table row. This is the primary output — it becomes the sole specification for the build phase (`build/protocol.md:38`).
- **`--build`**: Implementation code written TDD-style on a sub-branch, a conventional commit, a PR targeting the feature branch, and a build summary table.

### Strengths (with evidence)

1. **Shared-spine architecture.** `SKILL.md:18` declares the spine/fork contract and `SKILL.md:22-37` (Step 0 routing table) enforces it with a hard failure for zero-or-multiple mode flags. Mode-specific files state "the spine lives in SKILL.md; these sections slot into the marked points" (`plan/protocol.md:5`, `build/protocol.md:5`). Only one mode file loads per run.

2. **The plan template forces depth.** `plan/template-eng-plan.md` requires *Alternatives considered* (§3) with an anti-`None.` rule (`template-eng-plan.md:36`), trade-off tables per design decision (§4), four mandatory integration-contract subsections (§7), and a quality-gate table (§215-231). The worked examples (Wasp auth injection at lines 44-50, 71-78) are concrete, not filler.

3. **Exact-identifier discipline.** `plan/protocol.md:40-51` requires every function/table/column/migration/endpoint to be verified against the codebase scan, with a precision table, and forbids guessing — unconfirmable names become §12 gaps, not placeholders (`plan/protocol.md:51`). Build agents execute against these names.

4. **Concurrency hazard handled.** `build/protocol.md:40` refuses to create the feature branch (delegated to `plan-em`/`ship`), derives a per-row sub-branch, and explains why ("parallel build agents racing to create the same branch from main corrupts the tree"). This matches `plan-em` Step 4 (`plan-em/SKILL.md:209`) and `ship` Step 3 (`ship/SKILL.md:123`).

5. **TDD loop with gates.** `build/protocol.md:51-61` enforces red-before-green (`Verify red`, step 4b — requires a real assertion failure, not a compile/import error), per-group green, then a separate full-suite gate. Debug mode (`build/protocol.md:68-92`) caps at 3 cycles with a structured escalation block. The "no Tests row → visible warning + AHA log, don't silently ship" rule (`build/protocol.md:53`) handles that edge case.

6. **AHA.md feedback loop.** `build/protocol.md:96-115` appends learnings to the same `devkit/AHA.md` that pre-flight reads (`SKILL.md:73`), closing a learning loop across plan/build runs. Append-only is stated explicitly.

7. **`/cook` as sole standards source.** `SKILL.md:136-145` builds a stack+concern summary, forbids substituting another stack's standards, and surfaces uncovered stacks as named gaps. No hardcoded standards in the skill itself.

### Weaknesses (with evidence)

1. **Description claims two modes; the root menu claims three.** `SKILL.md:4` description says "two modes: --plan ... --build". But `msg/SKILL.md:26` lists eng as "**Plan, build, or review** engineering work from exec-table rows," and the `agent-evaluate`/system description for eng repeats "two modes." A `--review` mode does not exist anywhere in the skill — there is a separate `review` skill. The menu is wrong (or eng is missing a mode). A user routed by `/msg` to "eng for review" hits a dead end.

2. **Agent-naming convention collision.** Eng's examples and template use `backend-eng` / `mobile-eng` (`SKILL.md:50`, `plan/protocol.md:14`, `template-eng-plan.md:89`, `protocol-exec.md:97`). But `plan-em` Step 3a mandates the opposite order: "The platforms `/cook` returns coverage for are the canonical agent identifiers — use them to name agents (`eng-<platform>`)" and uses `eng-ios`/`eng-android` (`plan-em/SKILL.md:144,150`). Since `plan-em` produces the `agent` field and the exec-table Agent column, and eng's Step 1 confirms `rows` ownership by exact match on that column (`SKILL.md:50,68`), the eng-side examples teach a format that will never match real input. This undermines the exact-match validation the skill relies on.

3. **The `--build` full-suite gate is contradicted by every real caller.** `build/protocol.md:61` (Step 5) makes eng run the project's full test suite + lint/typecheck itself. But both orchestrators tell build agents to skip it: `ship/SKILL.md:34,137` ("build agents skip eng --build's raw-runner full-suite gate") and the ship pipeline replaces it with the `/test` stage. So eng's protocol Step 5 is dead weight in the ship path and only live when a human runs `eng --build` directly (rare). The skill never acknowledges this — a reader of `build/protocol.md` has no idea Step 5 is overridden. Document the override in eng (a "callers may suppress this gate" note), or make Step 5 conditional on a flag.

4. **The human approval gate is also silently auto-resolved.** `build/protocol.md:62` ("Confirm before commit ... single human gate") and `SKILL.md:103-124` (Step 3 summary gate) are presented as never-skip gates ("Never proceed to Step 4 without an explicit 'Yes, proceed.'" — `SKILL.md:124`). But `ship` injects an autonomy paragraph that auto-approves all `AskUserQuestion` gates (`ship/SKILL.md:76-78`). eng's protocol gives no hint that its "single human gate between writing code and publishing it" is bypassed in the autonomous path. A reader auditing eng would conclude code can't be committed without human sign-off, which is false under `ship`.

5. **Plan mode writes to the PRD but build mode reads it — no staleness check.** Plan mode appends `## Engineering — <Agent>` (`plan/protocol.md:53`) and build mode treats that section as the "sole specification" (`build/protocol.md:38`). Nothing verifies the engineering section corresponds to the current exec-table rows (e.g., if `plan-tune --eng` edited the table after the section was written). Drift between the §Engineering prose and the exec-table Execution steps is undetected.

6. **`devkit/` vs root-level path inconsistency in pre-flight.** `SKILL.md:72-79` lists `devkit/AHA.md`, `devkit/GLOSSARY.md`, `devkit/ARCHITECTURE.md`, `devkit/DESIGN-SYSTEM.md` — but `CLAUDE.md` with no `devkit/` prefix. That's correct (CLAUDE.md is root), but the table doesn't say so; `plan-em` spells it out ("`CLAUDE.md` is at project root" — `plan-em/SKILL.md:77`). eng readers may look for `devkit/CLAUDE.md`.

7. **`model:` mismatch with planner.** eng runs `claude-sonnet-4-6` (`SKILL.md:5`); `plan-em` runs `claude-opus-4-7` (`plan-em/SKILL.md:9`). Defensible (eng is a worker, planner is the brain) but worth a note — the highest-leverage output (the plan section + exact identifiers, which gate all downstream rework) is produced by the cheaper model.

8. **The `## Engineering —` heading match across skills is unverified.** `plan/protocol.md:53` says "`plan-em` detects build mode by this heading" and `plan-em/SKILL.md:195` confirms it scans for `## Engineering —`. This coupling is correct but undocumented as a shared contract — an implicit interface spread across two files with no single source of truth.

### Token efficiency & refs

- Only one mode file loads per invocation (Step 0 fork).
- `protocol-exec.md` (the Execution-steps how-to) is referenced by both plan-mode output (`plan/protocol.md:38`) and build-mode reading (`build/protocol.md:41`) — shared, not duplicated.
- The plan template is large (~230 lines) but only loads in plan mode, and all of it is used.
- No dead refs; all four refs are reachable from `SKILL.md:168-174`.

---

## Improve (prioritized)

1. **Fix the mode-count contradiction.** *What:* Reconcile "two modes" everywhere. *Why:* `msg/SKILL.md:26` says "Plan, build, or review"; eng only does plan+build. *How:* Edit `msg/SKILL.md:26` to "Plan or build engineering work from exec-table rows" (review is a separate skill). Confirm no `--review` flag is implied anywhere.

2. **Resolve the agent-naming collision.** *What:* Make eng's examples use `plan-em`'s `eng-<platform>` order. *Why:* `plan-em/SKILL.md:144` mandates `eng-ios`/`eng-backend`; eng's `backend-eng`/`mobile-eng` examples (`SKILL.md:50`, `plan/protocol.md:14`, `template-eng-plan.md:89`, `protocol-exec.md:97-103`) teach a format that won't exact-match the real Agent column. *How:* Replace `backend-eng`→`eng-backend`, `mobile-eng`→`eng-ios` across the four files. Or add one line to `SKILL.md` Step 1: "agent identity format is owned by plan-em (`eng-<platform>`); these examples are illustrative only."

3. **Document the suppressible gates.** *What:* Add a "Caller overrides" note to `build/protocol.md`. *Why:* `ship` skips the Step 5 full-suite gate (`ship/SKILL.md:137`) and auto-approves the Step 6 commit gate (`ship/SKILL.md:76-78`), but eng's protocol presents both as inviolable, misleading an auditor. *How:* Add to `build/protocol.md` after Step 5: "Orchestrators (ship) may suppress this full-suite gate and run `/test` as a dedicated stage instead; when invoked with an autonomy contract, the commit gate (step 6) is treated as approved." This makes the contract legible without changing behavior.

4. **Add a plan↔exec-table staleness check to build mode.** *What:* Before treating `## Engineering — <Agent>` as the spec, confirm every assigned row still appears in the current exec-table with a non-blank Execution steps cell. *Why:* `plan-tune --eng` can edit the table after the section was written (`build/protocol.md:38` trusts the section). *How:* Add a step 0 to `build/protocol.md` work steps: "Cross-check: each assigned row's Execution steps cell is non-blank and the §Engineering section references it. Mismatch → surface as a blocking gap, do not guess."

5. **State the CLAUDE.md location.** *What:* Note in `SKILL.md:76` that `CLAUDE.md` is project-root, not under `devkit/`. *Why:* The table mixes `devkit/`-prefixed and root paths; `plan-em` spells this out and eng should match. *How:* Change the row to `CLAUDE.md (project root)`.

6. **Name the `## Engineering —` heading as a shared contract.** *What:* A one-line "Shared contracts" note. *Why:* The heading is the build-mode trigger across eng+plan-em with no single source. *How:* Add to `SKILL.md` References: "Contract: the `## Engineering — <Agent>` heading is how plan-em detects build mode and how build mode locates its spec — do not rename."

## Remove

1. **Nothing structural to remove** — no dead ref, no duplicated block, no orphaned file.

2. **Trim the redundant input-contract restatement.** `SKILL.md:41-61` (Step 1 input validation) and `plan/protocol.md:9-18` / `build/protocol.md:9-22` each restate the field set. Plan mode says "no fields beyond the shared three" but SKILL.md Step 1 lists four fields including `agent` (`SKILL.md:43-51`) — so "shared three" (`plan/protocol.md:11`) is wrong; it's four (mode, prd-path, rows, agent). *Action:* Fix "shared three" → "shared four" in both mode files, or remove the count and say "the shared fields in SKILL.md Step 1." This is a correctness bug, not bloat.

3. **The "platform-agnostic" framing in §1 of the plan template fights the "single platform" rule.** `template-eng-plan.md:18` says "the single target platform (from PRD §3)" and §5 says "Domains must stay within the single platform" (`template-eng-plan.md:84`) — but the skill is invoked per-agent, and a single agent (e.g. `eng-backend`) is one stack, not one platform. The single-platform constraint is a leftover from a whole-PRD planner. *Action:* reword §1/§5 to "the agent's owned stack" rather than "the single target platform," since multiple eng agents (ios + backend) run on one PRD.

## Introduce

1. **A `--dry-run` / preview for `--build`.** *What:* Emit the planned file touches + sub-branch name without writing. *Why:* Build mode's only preview is the 3-4 line summary (`build/protocol.md:26-33`); a human running eng directly would see the derived file list before code lands. *Rationale:* low effort for direct (non-ship) use.

2. **A self-consistency lint between plan output and exec-table.** *What:* After writing the §Engineering section, plan mode verifies every exact identifier in §7 (API/schema tables) also appears in at least one Execution steps cell. *Why:* The two are written in the same run (`plan/protocol.md:34,38`) but can diverge; build agents execute the Execution steps, so an identifier present only in §7 prose is invisible to them. *Rationale:* raises build-phase fidelity.

3. **Capture build telemetry for AHA promotion.** *What:* On debug escalation (`build/protocol.md:81-90`), tag the AHA entry as `severity: escalated` so future plan runs can surface "this concern type repeatedly escalates." *Why:* AHA is the feedback channel (`build/protocol.md:96`); escalations are the highest-signal learnings and currently blend in with routine notes.

4. **A standards-cache handshake with `/cook`.** *What:* Let eng accept a pre-fetched `/cook` result from the orchestrator instead of re-invoking. *Why:* `plan-em` Step 3a (`plan-em/SKILL.md:144`) already calls `/cook` to derive the roster, then each eng subagent calls `/cook` again (`SKILL.md:143`). For N parallel agents that's N+1 `/cook` invocations on overlapping stacks. *Rationale:* token savings at scale; medium effort (requires a new optional input field).

## Priority Ranking

| Recommendation | Impact | Effort |
|---|---|---|
| Fix "two vs three modes" menu/description mismatch (Improve #1) | High | Low |
| Document suppressible full-suite + commit gates (Improve #3) | High | Low |
| Fix "shared three" → four field-count bug (Remove #2) | Med | Low |
| Resolve agent-naming collision `backend-eng` vs `eng-backend` (Improve #2) | Med | Low |
| Plan↔exec-table staleness check in build mode (Improve #4) | Med | Med |
| Plan-output self-consistency lint, §7 ↔ Execution steps (Introduce #2) | Med | Med |
| `/cook` standards-cache handshake to cut N+1 calls (Introduce #4) | Med | Med |
| Reword single-platform → single-stack in template (Remove #3) | Med | Low |
| Name `## Engineering —` as a shared contract (Improve #6) | Low | Low |
| State CLAUDE.md is project-root (Improve #5) | Low | Low |
| `--build --dry-run` preview (Introduce #1) | Low | Med |
| Tag escalated AHA entries (Introduce #3) | Low | Low |


---

# Skill: review

## Summary

`/review` is a code-review orchestrator that runs after `eng --build`. It resolves a diff, fingerprints the codebase, bootstraps an `eval_set` from the PRD/tests/schemas, confirms a review surface through one `AskUserQuestion` gate, then runs five ordered modes (Quality → Coverage → Functional → Security → Performance) with mechanical gates (lint/format/typecheck, secret scan) ahead of `/cook` semantic sub-agents, and aggregates everything into one structured JSON. The main problem: review, test, and pre-merge each define an incompatible finding shape despite the descriptions claiming compatibility, and two internal shape mismatches between `schema.md` and the shared tooling ref break the secret-scanner path at runtime.

---

## Quality Assessment

### Strengths

**Eval-set bootstrap.** `SKILL.md:70-95` defines a five-source discovery cascade (PRD sections → in-diff test files → co-located tests → `schemas.json` from a prior agent-audit run → conventional test dirs), merged and deduped by assertion text, with a diff-derived fallback. It tracks provenance via `eval_set_source` (`prd`/`tests`/`schemas`/`diff`/`mixed`). Functional mode reads that provenance and caps its verdict at `warn` when the source is `"diff"`, because diff-derived assertions are circular by construction (`functional.md:14-22`, `schema.md:91`). The `Eval-set: <N> assertions (prd/tests/schemas/diff)` emission (`SKILL.md:95`) makes the provenance visible to the user.

**Mechanical-before-semantic ordering.** Quality Stage 0 runs lint/format/typecheck first, and a typecheck failure or non-executable runner (`env:`) short-circuits the entire mode — no `/cook` Agent spawns on broken code (`quality.md:65`, "Saves tokens on broken code"). Security Stage 0 does not short-circuit (`security.md:44`) because secret leaks and semantic security issues are independent signals. Cheap deterministic checks gate expensive LLM fan-out.

**Functional mode evidence discipline.** `functional.md:99-105` and `schema.md:102-104` mandate that every `pass`/`block` finding populate `file`+`line`, with a self-check sweep that downgrades any evidence-less `pass`/`block` to `warn`. The "read the file in full, not the diff hunk" rule (`functional.md:52-60`) has an explicit widening rule for cross-file assertions, since guards and validators sit outside hunk windows. Executables are deferred to `/test` (not run as ephemeral scripts) per the executable/intent/negative assertion taxonomy (`functional.md:24-36`): review reasons, test executes.

**Dedup.** `SKILL.md:130` + `schema.md:44-49`: collapse findings sharing `(file, line, category)`, keep highest severity (`block` > `warn` > `info`), concatenate distinct `source` values. The example `"--api-design,--architecture"` makes the cross-agent merge concrete.

**Single-gate discipline.** "makes exactly ONE `AskUserQuestion` call (Step 5)" (`SKILL.md:34`) with Adjust updating surface + `eval_set[]` without re-asking (`SKILL.md:112`). Refusals are explicit: does NOT modify source, does NOT check docs (`/docu`'s job).

**Flag validation.** `flag_inventory` is parsed once in Step 2 and every assembled flag is validated against it in Step 4 — "any flag absent from the inventory is silently dropped" (`SKILL.md:99`). This prevents a stale FLAG-LIST snapshot from passing a non-existent flag to `/cook`.

### Weaknesses

**W1 — `secret_scanner` shape mismatch breaks the Security Stage 0 path (bug).** `schema.md:123-129` defines the fingerprint's `secret_scanner` object with fields `command` and `full_tree_command`. The shared source-of-truth ref `tooling-detection.md:66-75` defines secret scanners with `command_diff` and `command_full`. `security.md:34-35` instructs "Run the scanner's diff-mode command" / "full-tree command" without naming the field. An implementer following `schema.md` looks for `full_tree_command`; one following `tooling-detection.md` produces `command_full`. These never reconcile — the `--full-secret-scan` path references a field the detection ref never emits.

**W2 — Source-of-truth contradiction for mechanical/secret runners.** `SKILL.md:66-67` says mechanical-runner and secret-scanner shapes live in `refs/../shared/refs/tooling-detection.md`. But `FLAG-LIST.md:5` says "*That file* [tooling-detection.md] is the single source of truth for `test_runner`, `mechanical_runners[]`, and `security_scanners[]`/`secret_scanner`" — while `SKILL.md:138` and `schema.md:137` both call `FLAG-LIST.md` the "single source of truth for Step 2 fingerprint." Two files each claim to be the single source of truth for the same fingerprint outputs. The intent is "FLAG-LIST owns domain+cook flags, tooling-detection owns runners," but the prose doesn't say that. `FLAG-LIST.md:3` adds to the confusion by claiming to be "Generated from `vocab/tag-vocabulary.json`" at runtime — it's a hand-maintained snapshot.

**W3 — Cross-skill finding schema is fragmented, contradicting the descriptions.** Three skills in this pipeline claim interoperability but use three incompatible finding shapes:
- `/review` finding (`schema.md:11-25`): `{source, file, line, rule, severity: block|warn|info, category, message, suggestion}`
- `/test` finding (`test/refs/schema.md:42-53`): `{id, severity: fail|warn, file, line, rule, message, suggestion, repro, evidence}` — no `category`, no `source`; different severity enum
- `/pre-merge` finding (`pre-merge/SKILL.md:194-205`): `{id, severity: blocker|high|medium|low, category, title, evidence{file,line,tool,snippet}, repro, regression_of}` — nested evidence object, four-level severity, `title` not `message`

The `/test` description says "Emits structured JSON findings compatible with the pre-merge finding schema" — but test uses `fail|warn` severity and pre-merge uses `blocker|high|medium|low`; test puts `file`/`line` at top level while pre-merge nests them in `evidence{}`. They are not drop-in compatible. `preflight`/`ship` consume all three. There is no shared `finding-schema.md` the way `tooling-detection.md` is shared for fingerprinting. This is the largest ecosystem-consistency gap.

**W4 — Verdict-enum divergence across the three gates.** review uses `pass|warn|block`; test uses `pass|pass_with_warnings|fail|refused`; pre-merge uses `pass|pass_with_warnings|fail|refused|skipped`. A caller (`ship`, `preflight`) aggregating across all three must hand-map `block`↔`fail` and `warn`↔`pass_with_warnings`. Nothing documents that mapping. `ship`'s "loop /review → /test → fix until both report no issues" depends on a caller normalizing two different verdict vocabularies.

**W5 — Coverage mode's assertion-reference matching is fuzzy and will mis-fire.** `coverage.md:28-30`: match if "a significant substring of ≥ 5 consecutive words appears in a test description string" or "the assertion's key domain terms (nouns + verbs) appear as a cluster in the test file body." This is brittle: PRD assertions ("POST /users with empty email returns 400") rarely share 5 consecutive words with test descriptions ("rejects blank email"), so it will under-match and produce false `warn` assertion-gaps. There's no escape hatch (e.g. "if assertion is `executable` and a `/test` run will cover it, suppress the gap").

**W6 — `prd_rows_covered` is referenced but never defined.** `SKILL.md:98` Step 4 produces `prd_rows_covered` and it appears in the surface schema (`schema.md:67`), but nothing explains what a "row-id" is, where it comes from (presumably the PRD execution table), or how rows match to diff files. Compare `uncovered_changes[]`, which has a clear definition and a downstream consumer (Quality rubric scope-creep findings). `prd_rows_covered` is dead weight in the output unless defined.

**W7 — Performance and Security domain-flag selection can produce empty fan-out silently.** If `active_domains[]` is empty (e.g. a pure-Python repo where domain detection in `FLAG-LIST.md:13-24` only recognizes JS/TS/Flutter/SQL signals — there is no Python domain detection at all), Quality/Security/Performance fall back to only their global flags (`--api-design`, `--security`, `--performance` etc.). A Python/Go/Rust/Java codebase gets a degraded review with no language-specific standards and no warning that the domain went undetected. The fingerprint silently under-covers whole ecosystems.

---

## Improve (prioritized)

1. **Fix the `secret_scanner` field-name mismatch (W1).** *What:* Reconcile `schema.md:123-129` with `tooling-detection.md:66-75`. *Why:* The `--full-secret-scan` path references `full_tree_command`, a field the shared detector never emits — the full-tree scan silently no-ops. *How:* Change `schema.md` to use `command_diff` / `command_full` (match the shared ref), or add an alias note in `security.md` Stage 0 mapping `secret_scanner.command_diff` → diff mode and `.command_full` → `--full-secret-scan` mode. Pick the shared ref's names as canonical.

2. **Introduce a shared `finding-schema.md` and unify the three finding shapes (W3).** *What:* Create `.claude/skills/shared/refs/finding-schema.md` defining one canonical finding object, and have review/test/pre-merge reference it (the way they already share `tooling-detection.md`). *Why:* The descriptions promise compatibility the schemas don't deliver; `ship`/`preflight` must hand-translate. *How:* Define a superset finding (`id, source, severity, category, file, line, rule, message, suggestion, evidence, repro`) with a documented severity enum and a mapping table for each skill's local verdict vocabulary. Minimum version: a verdict-normalization table (`block≡fail≡blocker/high`, `warn≡pass_with_warnings≡medium/low`) that all three link to.

3. **Resolve the dual "single source of truth" contradiction (W2).** *What:* Rewrite `SKILL.md:138`, `schema.md:137`, and `FLAG-LIST.md:5` so one file owns each fingerprint output. *Why:* Two files both claim sole authority over `mechanical_runners[]`/`secret_scanner`. *How:* State plainly: "FLAG-LIST.md owns `active_domains[]` detection + the `/cook` flag inventory; tooling-detection.md owns `mechanical_runners[]` + `secret_scanner`." Drop FLAG-LIST.md's claim over the runner tables. Fix `FLAG-LIST.md:3`'s false "generated at runtime" claim — it's a static snapshot.

4. **Add Python (and ideally Go/Rust) domain detection (W7).** *What:* Extend `FLAG-LIST.md:13-24` domain-detection table with Python signals (`pyproject.toml`, `requirements*.txt`, `*.py`). *Why:* The mechanical Python runners (ruff/black/mypy) already exist in `tooling-detection.md:186-194`, so Quality Stage 0 can gate Python — but the semantic stage has no Python domain flag, so Python code gets lint/typecheck only and zero standards review. *How:* If `/cook` has no Python standards shelf, at minimum emit a `warn`-severity surface note when changed files include extensions with no matching `active_domain` ("N changed files in .py/.go/.rs have no domain-specific review").

5. **Tighten Coverage assertion-matching, or defer to /test (W5).** *What:* Replace the "≥5 consecutive words" heuristic in `coverage.md:28` with class-aware suppression. *Why:* It will under-match and spam false assertion-gaps. *How:* If an assertion is classed `executable` (Functional mode already classifies these), suppress the Coverage assertion-gap for it — `/test --eval-set` will verify it. Keep the gap only for `intent`/`negative` assertions where static reference is the only signal. (Coverage runs before Functional in the pipeline, so the class would need to move earlier or Coverage would consult the same classifier.)

6. **Define `prd_rows_covered` or remove it (W6).** *What:* Specify what a "row-id" is and how diff files map to PRD execution-table rows, or drop the field. *Why:* It's emitted but undefined — a consumer can't use it. *How:* If the PRD execution table has stable row IDs (it does in the plan-em output), define matching as "a diff file path appearing in a row's file list." Otherwise delete it from `SKILL.md:98` and `schema.md:67`.

7. **Document the verdict-normalization contract for `ship` (W4).** *What:* Add a mapping table (review `block|warn|pass` ↔ test/pre-merge `fail|pass_with_warnings|pass`) to `schema.md` verdict-semantics section. *Why:* `ship` loops review→test and aggregates; the mapping is currently implicit. *How:* One table; reference it from `ship`.

---

## Remove

- **`prd_rows_covered` (if not defined per Improve #6).** Undefined output — cut it rather than ship a field no consumer can interpret.
- **FLAG-LIST.md's runner-table source-of-truth claim (`FLAG-LIST.md:5`) and "generated at runtime" claim (`FLAG-LIST.md:3`).** Both are false/contradictory — remove to leave a single ownership story (Improve #3).
- **No mode should be removed.** Despite the surface overlap with `/test` and `/pre-merge`, the five review modes are scoped as static/semantic analysis, and the skill is explicit that execution is deferred elsewhere (`schema.md:136` "test execution belongs to `/test`"; Functional defers executables to `/test`). Coverage is static-only, Functional reasons rather than runs. Do not fold review's Security mode into pre-merge's "deep security" bucket: review's is diff-time semantic + secret-scan (fast, pre-PR), pre-merge's is heavyweight SAST/dependency audit (pre-push). Different stages, different cost profiles.
- **Redundancy to watch (not yet present):** review Quality mode's `--performance`-adjacent checks vs. the dedicated Performance mode. They're separated today (Quality = structure/complexity; Performance = N+1/loops/indexes), so no action — just don't let Quality's rubric grow into perf territory.

---

## Introduce

1. **Shared finding schema + verdict-normalization ref (highest value).** See Improve #2/#7. Turns three almost-compatible shapes into a contract and unblocks `ship`/`preflight` aggregation. The most impactful addition.

2. **A `--changed-only` / severity-floor flag.** Let callers (especially `ship`'s autonomous loop) request `/review --min-severity block` to skip emitting `info`/`warn` findings, shrinking the JSON the loop parses each iteration. The dedup pass already computes severity — gating output by it is cheap.

3. **Accessibility / i18n as a review dimension (gap).** The five modes cover quality, coverage, functional, security, performance — but no accessibility or internationalization semantic review, despite `/test` having `--a11y` and the `/cook` shelves having `--flutter:localization`, `--nextjs:i18n`. For a product suite shipping UI, a static a11y/i18n review mode (e.g. missing aria labels, hardcoded strings) closes a gap. Could be a sixth mode or folded into Quality with a rubric amendment.

4. **Migration / data-safety mode (gap).** `ship`'s only forced approval gate is "a change touches database files (migrations, schema, ORM models)" — yet `/review` has no dedicated migration-safety mode (irreversible migrations, missing down-migrations, non-concurrent index creation, data-loss columns). The Supabase/Database `/cook` flags exist but are only pulled into Security/Performance. A focused migration review aligned with ship's DB gate would be high-value.

5. **Persist the surface/fingerprint for re-runs.** The workflow is `/review → fix → /review (repeat)`. Each run re-fingerprints and re-bootstraps the eval-set from scratch (`SKILL.md:21` "Each run is independent — no state carried"). A cached `review/.surface.json` (invalidated on diff change) would let repeat runs skip Steps 2-3, mirroring `/cook`'s cache-first design. Trade-off: state management complexity vs. token savings on the iterate loop.

6. **Emit a finding count summary line before the JSON.** Like pre-merge's "severity counts before the issue list" (`pre-merge/SKILL.md:68`), review would benefit from a `Findings: 2 block, 5 warn, 11 info across 4 modes` preamble for the human-reading path (`SKILL.md:42` says stdout is read directly by a human).

---

## Priority Ranking

| Recommendation | Impact | Effort |
|---|---|---|
| Fix `secret_scanner` field-name mismatch (Improve #1) | High | Low |
| Shared finding schema + verdict normalization (Improve #2/#7, Introduce #1) | High | Med |
| Resolve dual source-of-truth contradiction (Improve #3) | Med | Low |
| Add Python/Go domain detection + undetected-domain warning (Improve #4) | High | Med |
| Tighten/defer Coverage assertion-matching (Improve #5) | Med | Low |
| Define or remove `prd_rows_covered` (Improve #6 / Remove) | Med | Low |
| Migration / data-safety review mode (Introduce #4) | High | Med |
| Accessibility / i18n review dimension (Introduce #3) | Med | Med |
| Severity-floor `--min-severity` flag (Introduce #2) | Med | Low |
| Surface/fingerprint cache for the iterate loop (Introduce #5) | Med | High |
| Findings-count preamble line (Introduce #6) | Low | Low |


---

# Skill: test

## Summary

`test` is an execution-focused test orchestrator. It detects installed runners via a deterministic Bash fingerprint script, runs up to ten test buckets (unit/integration, e2e, functional, QA/visual, load, a11y, perf, API/contract, mobile, coverage) sequentially or in parallel (`--fast`), and aggregates per-bucket JSON into one verdict via a second deterministic script. The SKILL.md delegates detection and aggregation to shielded scripts, the bucket refs are consistent, and `--init` advisory mode is useful. The main problem: the headline claim that its findings are "compatible with the pre-merge finding schema" is false (the two schemas materially differ), and the cross-skill `eval_set.json` contract is documented on the consumer side only.

---

## Quality Assessment

### Strengths

- **Detection is delegated.** SKILL.md Step 1 (`SKILL.md:161-189`) invokes `test-tooling-detect.sh` and forbids hand-walking priority tables. The script (`.claude/scripts/test-tooling-detect.sh`) emits every documented key (`package_manager`, `test_runner`, `e2e_runner`, `qa_runner`, `load_runner`, `a11y_runner`, `perf_runner`, `api_runner`, `mobile_runner`, `coverage_runner`) via a single `jq -n` object (lines 260-278). The script-vs-doc contract holds.
- **CI-override carve-out divides labour correctly.** `SKILL.md:185` leaves CI script extraction (`npm run test:e2e` in `.github/workflows`) to the LLM because it is "intent-matching, not file-existence," while keeping file/dep detection in the script.
- **Aggregation is shielded and validated.** `test-aggregate-verdict.sh` validates each bucket's `verdict` enum and refuses (exit 1) on malformed JSON rather than hand-merging (`SKILL.md:264-272`). The "do NOT hand-aggregate / re-run on exit 1" rule (`SKILL.md:272`) prevents the common LLM failure mode in aggregation.
- **The bucket-level error rule is consistent.** Every mode ref maps environment failures (missing binary, crash, unreachable target, auth) to `pass_with_warnings`, never `fail` (`SKILL.md:247`; reinforced in `a11y.md:70-85`, `perf.md:96-111`, `api.md:82-95`, `mobile.md:112-124`). A broken CI box never falsely blocks a merge. Applied uniformly.
- **`--init` profile quality.** The shape→buckets table (`init.md:24-34`) and bucket→tool table (`init.md:47-61`) are concrete, prefer already-installed tools, respect CLI-vs-npm placement (`init.md:63-64`), and the `test.json` schema (`init.md:74-108`) is well-formed with clear `status` semantics (`configured`/`partial`/`missing`). The Step I-0 cache-reconciliation flow (Analyse+update / Replace / Cancel, `SKILL.md:81-103`) is complete.
- **Functional bucket evidence discipline.** `functional.md:39-41` mandates that every `pass`/`fail` populate `file`+`line` and downgrades to `warn` with `"no evidence located"` otherwise — this prevents hallucinated passes. The "read each related file in full, not diff hunks" rule (`functional.md:13-20`) is correct.
- **Coverage bucket handles real-world cases.** Generated-file exclusion (`coverage.md:78-82` — `*.g.dart`, `*.freezed.dart`, etc.), the "fresh report < 10 min → don't re-run" optimisation (`coverage.md:38`), and Go's branch-coverage-unavailable fallback (`coverage.md:120`).

### Weaknesses

- **CRITICAL — false schema-compatibility claim (the headline bug).** The description (`SKILL.md:12-13`) and intro assert findings are "compatible with the pre-merge finding schema." They are not. Compare:
  - **test finding** (`refs/schema.md:42-52`): `severity: "fail" | "warn"`, flat `file`/`line`/`rule`/`message`/`suggestion`/`repro`/`evidence`.
  - **pre-merge finding** (`pre-merge/refs/finding-schema.md:15-28`): `severity: "blocker" | "high" | "medium" | "low"`, `category` (required enum), `title` (required, ≤80 chars), a nested `evidence: { tool, file, line, snippet }` object, and `regression_of`.

  These are not interchangeable: severity enums are disjoint (`fail`/`warn` vs `blocker`/`high`/`medium`/`low`), pre-merge requires `category`/`title`/`evidence.tool` that test never emits, and test's `evidence` is a flat string path whereas pre-merge's is an object. Anything that consumed a `/test` finding expecting the pre-merge shape would break. The claim misleads.

- **MAJOR — the `eval_set.json` contract is documented only on the consumer (test) side.** `test/refs/schema.md:74-83` defines the `class: "executable" | "intent" | "negative"` field that `/test` reads. But the producer, `/review`, never documents this shape: `review/refs/schema.md` documents `eval_set` (a flat array of strings) and `eval_set_path`, and `review/SKILL.md:86` only says Functional mode "writes eval_set.json after classifying assertions" — the `class` enum that test depends on lives nowhere in review's docs. The cross-skill contract exists only in one half of the pair, so a change to review's classifier would silently desync from test with nothing to catch it.

- **MAJOR — `--base` file-filter substitution is under-specified and runner-fragile.** `unit.md:17` says replace `<files>` in `test_runner.command` with changed source paths — but the detect script emits commands like `npx vitest run` / `npx jest`, which have no `<files>` placeholder, and passing bare file paths to Jest vs Vitest vs pytest vs `flutter test` requires different syntaxes (Jest treats args as testPathPattern regex; pytest needs `::`-qualified nodeids). The skill says "replace `<files>`" without defining where the placeholder comes from or how per-runner path semantics differ. E2E's spec-mapping (`e2e.md:18-20`, `auth.ts → e2e/auth.spec.ts`) is a name-convention guess presented as protocol.

- **MINOR — Mobile/perf/api/a11y output shapes drift from the canonical finding shape.** `refs/schema.md:42-52` declares one finding shape, but mobile adds `platform`/`device` (`mobile.md:148-159`), functional renames `rule`→`assertion` and adds a `pass` severity not in the canonical enum (`functional.md:54-55` — canonical is only `fail`/`warn`), and perf/api/a11y add top-level `errors[]` and `runners[]` arrays. These are per-bucket extensions, but the schema ref never says "buckets MAY extend the finding shape with the following documented fields," so a strict consumer can't know what's allowed.

- **MINOR — Dangling reference.** `SKILL.md:291` lists `refs/../../shared/refs/tooling-detection.md` as a reference, but `.claude/shared/refs/tooling-detection.md` does not exist (no `shared/` dir anywhere). Dead pointer.

- **MINOR — Functional `severity: "pass"` is internally inconsistent.** `functional.md:54` allows `"severity": "fail" | "warn" | "pass"`, but the canonical finding shape (`schema.md:43`) only permits `fail`/`warn`, and findings are by definition things that went wrong. A `pass` "finding" is a contradiction — pass results belong in `totals`/`evaluated`, not `findings[]`.

---

## Improve (prioritized)

1. **Fix or qualify the pre-merge schema claim (correctness, do first).** Either (a) drop the false "compatible with the pre-merge finding schema" wording from `SKILL.md:12-13` and the intro and replace with an accurate statement ("emits structured per-bucket JSON; see `refs/schema.md`"), OR (b) add a mapping table in `refs/schema.md` showing how a test finding projects to a pre-merge finding (`fail`→`blocker`/`high`, `warn`→`medium`/`low`; `rule`+`message`→`title`; flat `file`/`line`+`repro`→`evidence.{file,line}`+`evidence.tool`+`repro`). Option (a) is cheap; (b) is better if a consumer needs the projection. Today the claim is wrong.

2. **Centralise the `eval_set.json` contract and reference it from both skills.** Move the `eval_set.json` shape (`test/refs/schema.md:74-83`, including the `class` enum) into a single shared doc OR have `review/refs/schema.md` document the written `class` field explicitly, and have `test/refs/schema.md` say "shape owned by /review — see <path>." This closes the producer/consumer desync gap. It is the only inter-skill data contract test depends on for the functional bucket, and right now only the reader documents it.

3. **Specify `--base` scoping per-runner, or narrow the claim.** Add a table in `unit.md`/`e2e.md`: how each runner accepts changed-file filters (Jest: `--findRelatedTests <files>`; Vitest: `related <files>`; pytest: pass nodeids or rely on `--lf`; `flutter test <paths>`; "no safe filter → run full suite"). The current `<files>` placeholder doesn't exist in the detected commands. For E2E, downgrade the `auth.ts→auth.spec.ts` convention from protocol to "best-effort; fall back to full suite" (it's already hedged at `e2e.md:20`, but the mapping itself is presented too confidently).

4. **Add an explicit "buckets may extend the finding shape" clause to `refs/schema.md`.** List the sanctioned extensions per bucket (mobile: `platform`,`device`; perf/api/a11y: top-level `errors[]`,`runners[]`/`commands[]`; coverage: `report_source`). Makes the schema a contract instead of a baseline that four buckets violate.

5. **Remove `severity: "pass"` from the functional finding shape.** Change `functional.md:54` to `"fail" | "warn"` to match canonical; route passing assertions to `evaluated`/`totals` only. Keeps the finding model coherent.

6. **Delete the dead `shared/refs/tooling-detection.md` reference** at `SKILL.md:291` (or create the file if it was intended). It points at nothing.

7. **Document parallel write-isolation for `--fast`.** `SKILL.md:251` says each bucket writes `/tmp/test-<runid>/<bucket>.json`, and `--fast` runs buckets concurrently (`SKILL.md:245`). Functional uses `/tmp/test-functional-<runid>/` (`functional.md:25`). The SKILL should state explicitly that under `--fast` each parallel bucket gets its own subdir/file and they never share scratch paths, so two concurrent buckets can't clobber each other's artifacts. Currently implied, not guaranteed.

---

## Remove

- **The false/overstated schema-compatibility sentence** (`SKILL.md:12-13` + intro) — covered in Improve #1. If not reworked into an accurate mapping, cut it.
- **`severity: "pass"` in functional** (`functional.md:54`) — Improve #5.
- **The dead shared-ref line** (`SKILL.md:291`) — Improve #6.
- **The over-confident E2E spec name-mapping example** (`e2e.md:19`, `auth.ts → e2e/auth.spec.ts`) — keep the fallback-to-full-suite behaviour, but remove the implication that the rename heuristic is reliable. It will mis-map more often than it hits in real repos.
- **No whole bucket or ref file should be removed** — the 11 refs are each distinct and pull bucket detail out of SKILL.md (the right call). There is no redundant bucket. The 16.7K SKILL.md is not bloated for what it coordinates; bucket detail already lives in refs. Token budget is well-spent.

## Introduce

- **A `mutation`/`flaky-detection` capability is the most valuable gap.** The skill runs tests but never re-runs to detect flakes. Pre-merge already has a flaky-retry finding (`pre-merge/refs/bucket-runners.md:58`). A `--flaky <N>` flag that re-runs failing e2e/unit specs N times and emits a `warn` finding for non-deterministic results would raise output quality and align with pre-merge.
- **A `--changed-only` smart-skip for `--init`-cached projects.** When `test.json` exists and `--base` is set, the skill could skip whole buckets whose surface the diff doesn't touch (e.g. no UI files changed → skip qa/a11y/perf). Currently every applicable bucket runs regardless of diff content. A direct latency/cost win.
- **Language coverage gaps in runner detection.** No Rust (`cargo test`, `cargo-tarpaulin`), no Ruby (RSpec/minitest, simplecov), no Java/Kotlin (JUnit/Gradle, jacoco), no C#/.NET (`dotnet test`, coverlet), no PHP (PHPUnit). The unit and coverage buckets only recognise JS/TS, Python, Dart, Go (`unit.md` via detect script; `coverage.md:17-24`). Adding `cargo test` + tarpaulin and `dotnet test` + coverlet covers the two most-requested missing stacks with small, deterministic additions to `test-tooling-detect.sh`.
- **A "security/SAST" bucket is intentionally absent — keep it that way** but document the boundary. Pre-merge owns deep security (`pre-merge/refs/bucket-runners.md:112-133`). One line in SKILL.md ("security/SAST is owned by /pre-merge, not /test") would prevent future scope creep and clarify the ecosystem split.
- **Contract-test record/playback note for API bucket.** `api.md` runs Pact `verify` but never addresses the consumer-side `pact` generation step or provider-state setup beyond a suggestion string. A note on when `/test` can vs cannot run provider verification (needs a running provider) would prevent confusing `pass_with_warnings` results.

---

## Priority Ranking

| Recommendation | Impact | Effort |
|---|---|---|
| Fix false pre-merge schema-compatibility claim (Improve #1) | High | Low |
| Centralise/cross-reference the `eval_set.json` contract (Improve #2) | High | Low |
| Specify `--base` per-runner file filtering; soften E2E spec mapping (Improve #3) | High | Med |
| Add "buckets may extend finding shape" clause to schema.md (Improve #4) | Med | Low |
| Add Rust + .NET (and ideally Ruby/Java) runner + coverage detection (Introduce) | Med | Med |
| Remove `severity: "pass"` from functional (Improve #5) | Med | Low |
| Add `--flaky <N>` re-run / flake-detection capability (Introduce) | Med | Med |
| Document `--fast` parallel write-isolation guarantee (Improve #7) | Med | Low |
| Delete dead `shared/refs/tooling-detection.md` reference (Improve #6) | Low | Low |
| Add `--changed-only` diff-aware bucket skip (Introduce) | Low | Med |
| Document security/SAST boundary vs /pre-merge (Introduce) | Low | Low |


---

# Skill: pre-merge

## Summary

`pre-merge` is a pre-push gate. It resolves a diff vs base, fingerprints tooling, builds a five-bucket check matrix (integration / e2e / build / security / bundle), gates on a single human approval, fans out one subagent per bucket in parallel, then aggregates severity-graded findings into one JSON verdict (`pass` / `pass_with_warnings` / `fail` / `refused` / `skipped`). The protocol is disciplined — refusal posture, evidence-mandatory rubric, clear ordering. The JSON output contract has three correctness bugs (missing `rule` field, dead `prd_criteria` input, leaked `eval_set_path`) and diverges from `/test` and `/review`, undermining the "shared finding schema" claim. The 14.9K `pre-merge-plan.md` is stale build cruft that contradicts the shipped SKILL.md.

---

## Quality Assessment

### Strengths

- **Refusal-as-a-feature is well executed.** Four refusal reasons (`no_diff`, `schema_mismatch`, `out_of_scope_modify`, `out_of_scope_action`) each have a canonical JSON shape in `refs/refusal-patterns.md`, a fire-point, and an exit code, plus a "refusal vs verdict fail" disambiguation table (`refusal-patterns.md:104-115`). The `no_diff` path forbids falling through into expensive work (`SKILL.md:79`, `refusal-patterns.md:33`). The highest-quality part of the skill.

- **Evidence is mandatory and enforced at the rubric level.** `severity-rubric.md:94-96` states a subagent must drop a finding rather than emit an evidence-free claim ("The code looks suspicious is not evidence"). Combined with `repro` being a required field (`finding-schema.md:50`), every finding is reproducible. Correct for a gate whose output blocks a merge.

- **Severity rubric is context-aware, not CVSS passthrough.** The downgrade rules (`severity-rubric.md:27-71`) weight in-diff vs out-of-diff, dev-only scope, and unreachability, with defensible exceptions — a secret in a test file stays `blocker` because "test files are committed and secrets in them are just as public" (`severity-rubric.md:45`), and secret hits are never downgraded for unreachability (`severity-rubric.md:56`). Per-bucket severity floors (`severity-rubric.md:73-82`) prevent over-downgrading hard-fail signals.

- **Verdict logic is consistent across three files.** `SKILL.md:167-171`, `output-schema.md:33-41`, and `severity-rubric.md:84-92` all agree: any blocker/high → `fail`; medium/low only → `pass_with_warnings`; zero → `pass`. Exit codes are defined and consistent.

- **Mechanical-before-semantic ordering inside the build bucket.** `bucket-runners.md:85-94` runs lint/format/typecheck first and short-circuits the build tool if a typecheck/lint block already proves the build is broken — saves the expensive `next build` when a cheap `tsc --noEmit` already failed.

- **Snippet redaction is baked into the schema**, not left to the model (`finding-schema.md:44`, `bucket-runners.md:112`). The happy-path example shows a redacted Stripe key (`pre-merge-plan.md:195`).

### Weaknesses (with evidence)

1. **The `rule` field that dedup and regression matching depend on does not exist in the finding schema.**
   - `SKILL.md:156` dedups by `(category, file, line, rule)`.
   - `SKILL.md:161` marks regressions by matching a prior `(category, file, rule)` triple.
   - But `finding-schema.md` and `output-schema.md` define no `rule` field anywhere on a finding (the only `rule` mentions are inside `evidence.snippet` prose). The dedup and regression keys reference a phantom field. Dedup will fall back to `(category, file, line)` and regression matching has no stable key — two different gitleaks rules on the same line are treated as the same finding, and a regression of a specific rule cannot be detected. The most important bug: it silently breaks the P1 "regression detection" headline differentiator.

2. **`--prd` / `prd_criteria[]` is loaded and threaded but never consumed — dead input.** `SKILL.md:98` extracts acceptance criteria into `prd_criteria[]`, `SKILL.md:122` announces the count, and `SKILL.md:151` passes it to every subagent. But no bucket in `bucket-runners.md` does anything with `prd_criteria[]` — there is no acceptance-criteria check. The PRD is collected, displayed, forwarded, and ignored. Either wire it into a check (e.g. fail if a PRD acceptance criterion maps to a missing/failing e2e spec) or stop claiming to use it.

3. **`eval_set_path` leaked into the output schema from `/test`'s vocabulary.** `output-schema.md:29` and `:129` define a top-level `eval_set_path` field, but the pre-merge protocol never reads, writes, or sets it (zero references in SKILL.md or any bucket). It's `null` forever. A copy-paste artifact from the `/test` schema (`test/refs/schema.md:33`) and noise in the contract.

4. **The "shared finding schema" does not exist across the three consumers.** The pipeline (`ship`) chains `/review` → `/test` → `/pre-merge`, but the three emit structurally incompatible findings:
   - `/review` (`review/refs/schema.md:5-26`): `severity: block|warn|info`, flat `file`/`line`/`rule`/`category`/`source`/`message`/`suggestion`.
   - `/test` (`test/refs/schema.md:41-53`): `severity: fail|warn`, flat `file`/`line`/`rule`/`message`/`suggestion`/`repro`/`evidence` (string path).
   - `/pre-merge` (`finding-schema.md`): `severity: blocker|high|medium|low`, nested `evidence{}` object, `title` (not `message`), `repro`, `regression_of`, no `rule`, no `suggestion`.

   The `/test` description claims it emits "structured JSON findings compatible with the pre-merge finding schema" — that is false. They share neither the severity enum, the evidence representation (string vs object), nor the title/message field name. A consumer cannot mechanically merge a `/test` finding into a pre-merge `issues[]` array. Either pre-merge should accept the shared flat finding (`file`/`line`/`rule`/`severity`/`message`/`suggestion`) and add its `evidence`/`repro`/`regression_of` as optional extensions, or the docs across all three should stop claiming compatibility.

5. **`detect-tooling.sh` hardcodes `"mechanical_runners": []` (line 106), but the build bucket's logic depends on it.** `bucket-runners.md:85-94` runs `detected.mechanical_runners[]` (lint/format/typecheck) and reads a `severity_on_fail` field per runner — but the detector script never populates that array. The lint/format/typecheck short-circuit is unreachable through the script path. The SKILL.md says to run the shared `tooling-detection.md` fingerprint (`SKILL.md:83`) which does populate mechanical_runners, so the script is a strictly-worse duplicate that will mislead anyone who runs it.

6. **`detect-tooling.sh` is missing detection breadth the runner refs assume.** `bucket-runners.md` lists Mocha/pytest/Flutter test runners, Flutter-integration & CI-override e2e, Rollup/tsup/Flutter build, trufflehog secret, trivy/snyk/yarn dependency, container scanners, and `source-map-explorer`/`bundlesize`/`vite-bundle-visualizer` analyzers. The script only detects vitest/jest, playwright/cypress, next/vite/tsup/tsc, gitleaks/semgrep/pnpm-audit/npm-audit, and two analyzers. A Flutter or Python or Cypress-less Mocha project gets a half-empty matrix. (The shared `tooling-detection.md` is the authoritative path — see Remove.)

7. **`resolve-diff.sh` insertion/deletion parse is fragile.** `resolve-diff.sh:25-26` uses `grep -oE '[0-9]+ insertion'` against the `--stat` summary line. If the summary line is absent (only mode changes, or binary files) `ADDED`/`REMOVED` silently become `0`, and `git fetch` failures are swallowed (`:12`), so a stale `origin/main` can produce a misleading "no_diff" or wrong scope without warning. The `set -euo pipefail` (`:7`) combined with `grep || echo 0` in a pipeline is correct here, but the `FILES_JSON` awk one-liner produces `[]` for a single empty line — fine — yet there's no guard for filenames containing `"` (would emit invalid JSON). Low likelihood, but the gate's first step should be bulletproof.

8. **`skipped[]` shape disagreement.** `output-schema.md:64-73` defines `skipped[]` entries as `{bucket, reason}` with reasons `no_tooling|user_removed`, but `bucket-runners.md:175-182` calls the array `skipped_buckets[]` and uses reason `no_tooling`, while SKILL.md Step 7's `skipped` semantics are never tied back to either. Three names/reasons for the same concept.

9. **No `package_manager` propagation to the `repro` field.** Bucket commands in `bucket-runners.md` are written with `npx`/`pnpm` interchangeably (integration uses `npx vitest` at `:22` but the SKILL.md example matrix at `SKILL.md:114` uses `pnpm vitest`). The `repro` field is required to be copy-paste runnable (`finding-schema.md:50`) but nothing guarantees it uses the project's detected package manager. Minor, but the exact inconsistency that makes a `repro` fail when pasted.

---

## Improve (prioritized)

1. **Add a `rule` field to the finding schema (or fix the keys).** *What:* Either add `rule: "<tool rule-id or assertion>"` as a required finding field in `finding-schema.md`/`output-schema.md`, or rewrite the dedup key to `(category, file, line, title)` and the regression key to `(category, file, evidence.tool, title)`. *Why:* Dedup and regression matching (`SKILL.md:156,161`) reference a non-existent field, silently breaking the P1 regression-detection differentiator. *How:* Adding `rule` is cleaner and aligns pre-merge with `/review` and `/test`, which both carry `rule`. Populate it from the tool (`gitleaks` rule id, semgrep check id, failing test name, `bundlesize` route).

2. **Either wire `prd_criteria[]` into a real check or delete it.** *What:* Add an acceptance-criteria cross-check — e.g. in the e2e bucket, flag any PRD acceptance criterion that has no covering passing spec, as a `medium` finding (`category: e2e`, title `"PRD criterion <X> has no covering e2e"`). *Why:* `--prd` is loaded, counted, displayed, and forwarded to subagents (`SKILL.md:98,122,151`) with zero downstream effect. *How:* Pass `prd_criteria[]` to the e2e/integration subagents with an instruction to map criteria → test names; emit findings for uncovered criteria. If that's out of scope for a gate, remove the flag and all three references instead.

3. **Reconcile the finding schema with `/test` and `/review`, or correct the "compatible" claims.** *What:* Define one canonical flat finding `{id, source/category, severity, file, line, rule, message/title, suggestion, repro, evidence}` and make pre-merge accept it, treating `evidence{}`-object + `regression_of` as optional pre-merge extensions; OR edit the `/test` description to drop "compatible with the pre-merge finding schema". *Why:* `ship` chains all three; the compatibility claim is false today (different severity enums, evidence as string vs object, `title` vs `message`). *How:* Cheapest fix: a "Cross-skill mapping" table in `finding-schema.md` showing how `/test` (`fail|warn`) and `/review` (`block|warn|info`) severities map onto pre-merge's four-level scale, plus the field renames. Best fix: converge the schemas.

4. **Delete `detect-tooling.sh` and rely on the shared fingerprint.** *What:* Remove `scripts/detect-tooling.sh`; keep `SKILL.md:83`'s instruction to run `../shared/refs/tooling-detection.md` (which has a deterministic detector at `.claude/scripts/test-tooling-detect...` per `tooling-detection.md:10`). *Why:* The script hardcodes `mechanical_runners: []` (breaking the build short-circuit), detects a narrow subset of tools, and duplicates the authoritative shared protocol. A strictly-worse second source of truth. *How:* See Remove §1.

5. **Harden `resolve-diff.sh`.** *What:* (a) Make a `git fetch` failure visible (warn to stderr, set a `base_stale` flag) instead of silently `|| true` (`:12`); (b) build `files_changed` JSON with a `jq -R -s` or `--name-only -z` + proper escaping rather than the raw awk one-liner (`:29`) to survive filenames with quotes/spaces; (c) handle binary-only / mode-only diffs where the insertion/deletion line is absent. *Why:* This is the gate's Step 1; a wrong "no_diff" or malformed JSON here aborts or corrupts every downstream step. *How:* Pipe `git diff --name-only -z` through `jq -Rs 'split(" ") | map(select(length>0))'`.

6. **Collapse the `skipped[]` naming/reason inconsistency.** *What:* Pick one — `skipped[]` with `{bucket, reason: "no_tooling"|"user_removed"}` — and make `bucket-runners.md:175` (`skipped_buckets[]`) and SKILL.md Step 3/7 use it verbatim. *Why:* Three spellings of one concept across `output-schema.md:64`, `bucket-runners.md:175`, and the SKILL invite a malformed output. *How:* Rename in `bucket-runners.md`; add a one-line cross-ref.

7. **Pin `repro` and matrix commands to the detected package manager.** *What:* Replace literal `npx`/`pnpm` in `bucket-runners.md` with `<run_prefix>`/`<pkg>` placeholders resolved from `detected.package_manager`. *Why:* The SKILL matrix example uses `pnpm` while bucket-runners uses `npx` for the same vitest call (`SKILL.md:114` vs `bucket-runners.md:22`); a `repro` that says `npx` in a Yarn-PnP repo won't run. *How:* Single placeholder pass, same pattern `/review` and `/test` already use for runner commands.

8. **Remove `eval_set_path` from the output schema** (see Remove §2).

---

## Remove

1. **`scripts/detect-tooling.sh`** — duplicates the shared `tooling-detection.md` fingerprint that SKILL.md invokes (`SKILL.md:83`), hardcodes `mechanical_runners: []` (breaking the build-bucket short-circuit at `bucket-runners.md:85`), and detects a narrow subset (no Flutter/pytest/Mocha/Cypress-Flutter/trivy/snyk/trufflehog/source-map-explorer). A stale, strictly-worse second source of truth. The SKILL.md "References" still lists it (`SKILL.md:222`) but the protocol never calls it. Delete the file and the reference.

2. **`eval_set_path` field in `output-schema.md`** (`:29`, `:129`) — a leaked `/test` concept the pre-merge protocol never sets. Always `null`. Noise in the contract.

3. **`pre-merge-plan.md` (14.9K) — demote or delete; it is stale build cruft, not live guidance.** A 265-line superset of the shipped SKILL.md that contradicts it in several places:
   - It tells the model to use a "`Workflow` tool with `parallel()` if available" (`pre-merge-plan.md:147`) — the shipped skill uses parallel `Agent` calls (`SKILL.md:143`); no `Workflow` tool exists.
   - It specifies the human gate as a plain `<HUMAN: approve check matrix?> [yes/no]` print (`pre-merge-plan.md:145`), whereas the shipped skill uses a three-option `AskUserQuestion` (Run/Skip/Adjust) (`SKILL.md:124-139`). The Adjust path doesn't exist in the plan.
   - It omits the `schema_mismatch` refusal that the shipped skill and refs added (`refusal-patterns.md:36`).
   - It carries P2 "future" priorities (MCP hosted scanners, cached check-plan reuse) as if pending, with no link to whether they shipped.

   *Rationale:* a 14.9K planning doc that diverges from the implementation is a maintenance trap — a reader can't tell which is canonical, and `detect-tooling.sh` is "supported" only by this plan (`pre-merge-plan.md:169,249`). Either delete it (the SKILL + refs are self-sufficient) or move it to a `plan/` archive marked "historical — see SKILL.md for current behavior." Do not treat it as live guidance.

4. **The `out_of_scope_modify` subagent-self-modification clause is near-redundant with the global anti-pattern but harmless** — keep it; it's cheap and the redundancy is intentional defense-in-depth (called out in three places: `SKILL.md:34,66,149`). Not a removal, just noting it was reviewed.

---

## Introduce

1. **License + dependency-provenance check (gap).** *What:* A `license` sub-check inside the `security` bucket (or a sixth bucket): scan `files_changed` for new/changed `package.json`/`pnpm-lock.yaml` deltas and flag added dependencies with copyleft or unknown licenses (`license-checker`, `pnpm licenses list`). *Why:* The skill claims "deep security" but covers only secrets/SAST/CVE/container — a newly-added GPL dependency in a proprietary product is a merge blocker the gate is positioned to catch and currently misses. *Severity:* map GPL/AGPL into proprietary → `high`; unknown license → `medium`.

2. **New-dependency diff awareness in the security bucket.** *What:* When the lockfile is in `files_changed`, audit only the newly-added transitive deps at higher weight (in-diff), and existing CVEs at `low`. *Why:* Today `pnpm audit --json` (`bucket-runners.md:127`) reports the whole tree at full weight; the rubric's in-diff weighting (`severity-rubric.md:31`) can't apply because audit findings have no `file` in the diff. A "newly introduced by this PR" flag is the regression signal the skill prizes.

3. **Secret-scan coverage of the full diff history, not just working files.** *What:* In addition to `gitleaks detect --no-git --source=<files>`, run `gitleaks detect` (git-history mode, `:73` `command_full`) across `<base>..HEAD` so a secret that was committed-then-deleted in an earlier commit of the branch is still caught. *Why:* The gate runs before push; a secret living in branch history (not the working tree) is what leaks to the remote. The current diff-scoped scan (`bucket-runners.md:109`) would miss it.

4. **Baseline persistence + auto-discovery for bundle (P2 in plan, worth doing).** *What:* Implement the `baseline_path` auto-discovery from `.pre-merge/` that `tooling-detection.md:266` describes but no bucket wires (`bucket-runners.md:160` treats null baseline as "first run" every time). *Why:* Without persistence every run is "first run" and bundle regression detection never fires after run #1 — the bundle bucket is informational-only today.

5. **Machine-readable exit-code emission.** *What:* Have the skill (or a wrapper) exit non-zero on `fail`/`refused` per the documented exit-code tables (`output-schema.md:35`, `refusal-patterns.md:104`). *Why:* The exit codes are documented but the skill emits JSON to stdout with no actual process exit semantics — `ship` Step 6 (`ship/SKILL.md:179`) reads the `verdict` string, which works, but any non-`ship` caller (CI, a git pre-push hook) can't gate on exit code. A pre-push gate that can't be wired into a `pre-push` hook is leaving its namesake on the table.

---

## Priority Ranking

| Recommendation | Impact | Effort |
|---|---|---|
| Fix the phantom `rule` field in dedup/regression keys (Improve 1) | High | Low |
| Wire or delete `prd_criteria[]` dead input (Improve 2) | High | Med |
| Reconcile finding schema vs /test & /review; fix false "compatible" claim (Improve 3) | High | Med |
| Delete stale `detect-tooling.sh` (Remove 1) | Med | Low |
| Demote/delete divergent `pre-merge-plan.md` (Remove 3) | Med | Low |
| Add license / new-dependency provenance check (Introduce 1–2) | High | Med |
| Full-history secret scan over `base..HEAD` (Introduce 3) | High | Low |
| Persist bundle baseline so regression actually fires (Introduce 4) | Med | Med |
| Remove leaked `eval_set_path` (Remove 2) | Low | Low |
| Harden `resolve-diff.sh` (fetch failures, JSON escaping, binary diffs) (Improve 5) | Med | Low |
| Collapse `skipped[]`/`skipped_buckets[]` naming (Improve 6) | Low | Low |
| Pin commands/repro to detected package manager (Improve 7) | Med | Low |
| Real process exit codes for hook/CI use (Introduce 5) | Med | Med |


---

# Skill: ship

## Summary

`ship` resolves a PRD (by path or prose), spins up parallel `eng --build` subagents from the execution table, then loops `/review` → `/test` → fix until both report clean, and runs `/pre-merge`. It runs hands-off except for two forced pauses: database-touching changes and breaking changes. The branch contract between `ship` and `eng --build` is mismatched, so code the build agents write may never land on the branch `ship` reviews and tests. It also lacks a commit/PR/rollback step and per-round context controls.

## Quality Assessment

### Strengths

- **Termination condition exists.** `ship` has an explicit cap: `--max-rounds` (default 5, SKILL.md:59), enforced at Step 5 exit condition 2 (SKILL.md:170) with a user gate offering "Run more rounds" / "Stop and report." The most important property for a non-converging loop is present and correct.
- **Pool/exit semantics are defined.** Step 5.4 (SKILL.md:167) defines "open issues" as review `block`+`warn` (not `info`) plus every `/test` finding contributing to a `fail`, and excludes `pass_with_warnings` buckets that came from a broken environment, cross-referencing `/test`'s bucket-level error rule. This matches `/test` SKILL.md:247 (a runner crash → `pass_with_warnings`, never `fail`). The contract is internally consistent.
- **Guardrail detection is mechanical, not LLM-judged.** Database-touch detection is delegated to `scripts/ship-db-touch.sh`, a `git diff --name-only | grep -E` over a concrete pattern set (migrations/seeds/fixtures/entities/models, `.sql`, `schema.prisma`, `.entity.*`, `supabase/migrations/`). The SKILL.md glob list (SKILL.md:90-93) matches the script's regex. Re-checking the guardrail after each fix round (SKILL.md:172, Step 5.7) is correct — a fix can introduce a DB touch the initial build didn't.
- **Breaking-change signal is explicit and structured.** Build agents return `BREAKING: <desc>` or `BREAKING: none` (SKILL.md:138), and the guardrail trips on any non-`none` value (SKILL.md:151). This is a contract rather than inferring breakage from a diff.
- **Hands-off contract is propagated.** Every subagent prompt carries the autonomy paragraph (SKILL.md:76-78) instructing it to auto-approve `AskUserQuestion` gates. This is necessary because `eng --build` (Step 3 summary gate, Step 6 commit gate), `/review` (Step 5), `/test` (Step 3), and `/pre-merge` (Step 4) all have their own `AskUserQuestion` gates. Without this paragraph the subagents would hang.
- **Clear non-goals.** "Never pushes or merges" is stated at SKILL.md:66, 72, 194; the final summary hands off to `gh pr create` / `/handoff`. The boundary is unambiguous.
- **Frugal model choice and delegation.** Runs on `claude-sonnet-4-6` (SKILL.md:12) and pushes heavy reading into subagents; the orchestrator reads only the PRD and small findings JSONs.

### Weaknesses

- **CRITICAL — branch contract mismatch with `eng --build`.** `ship` Step 3 creates `feat/prd-<n>-<slug>` and passes it to each build agent as `branch` (SKILL.md:123-136). But `eng --build`'s protocol (refs/build/protocol.md, Work step 1) treats `branch` as the PR target: each agent cuts a sub-branch `{branch}/{row-slug}`, does all work there, commits there (step 7), and opens a PR from the sub-branch to `{branch}` (step 8) — it says "Do not open a PR against main" but never merges into `{branch}`. Result: after the parallel build stage, the implemented code sits on N sub-branches behind N open PRs; `feat/prd-<n>-<slug>` has no commits. Then `ship` Step 5 runs `/review`, `/test`, and `/pre-merge` diffing `feat/prd-<n>-<slug>` vs base (SKILL.md:165-166, 177) — an empty diff. `/review` exits `Nothing to review — diff is empty.` (review SKILL.md:57); `/pre-merge` refuses with `no_diff` (pre-merge SKILL.md:79). The loop reviews and tests nothing. `ship` has no step that merges the sub-branch PRs into the feature branch, and the subagents can't (autonomy contract forbids merge). The happy path does not converge to shipped, reviewed code.
- **MAJOR — No commit/PR/rollback ownership, ambiguous commit responsibility.** Because of the branch issue above, what is committed where is unclear. `ship` never commits, and the fix-stage agents (Step 5.6) are told to "Fix exactly these findings… Return touched files" but not to commit — yet the next round's `/review`/`/test` diff against base only sees committed changes (or working-tree, depending on review's `git diff HEAD`). If fix agents leave changes uncommitted on the feature branch but build agents committed to sub-branches, the diff surfaces are inconsistent round-to-round. There is no rollback path if a fix round makes things worse (a fix that breaks a previously-passing bucket) — the loop only moves forward.
- **MAJOR — No per-round context/cost controls on a long-running loop.** The loop can run up to `max_rounds` (5+) iterations, each spawning a `/review` agent, a `/test` agent, and ≥1 fix agent. `ship` re-reads "both findings JSONs" every round (Step 5.4) but there is no instruction to prune, summarize, or cap the orchestrator's accumulating context, no per-subagent token budget, and no guard against a `/review` that returns hundreds of `warn` findings flooding the fix scope. For a long-running hands-off loop, context-window management is absent.
- **MINOR — Stuck-loop detection is cap-only, not progress-based.** The only non-convergence handling is the round cap. There is no detection of a cycling loop — round N fixes finding A but reintroduces finding B, round N+1 fixes B but reintroduces A. `ship` burns all 5 rounds on an oscillation and then asks the user, with no signal it detected thrash. A "no net reduction in open-issue count across 2 rounds → pause early" heuristic would catch this sooner.
- **MINOR — `--base` default inconsistency.** `ship` documents `--base` default as `origin/main` (SKILL.md:59) and `ship-db-touch.sh` also defaults to `origin/main`. But the db-touch script diffs `"$base"...HEAD` (three-dot, merge-base), while `/review`'s diff resolution (review SKILL.md:50-57) uses `git diff <branch>` (two-dot) and falls back to `HEAD~1 HEAD` on `main`. These produce different surfaces when base has advanced. The guardrail and the review may disagree on what "changed," so a DB touch can be flagged by the guardrail but invisible to review, or vice versa.
- **MINOR — PRD-path derivation is brittle.** Step 1 (SKILL.md:113) derives `n`, `slug`, and `branch` by pattern-matching `features/prd-[n]-[slug]/prd-[n]-[slug].md`. The convention in this repo (per `plan-pm`) is `features/prd-[n]-[feature-slug]/prd-[n]-[feature-slug].md`, and `ship-find-prd.sh` globs `features/prd-*/prd-*.md`. A PRD whose directory/file doesn't match the exact `prd-[n]-[slug]` shape will fail derivation silently — there is no validation that derivation succeeded before the branch name is built.
- **MINOR — `/test` invocation passes `--eval-set` that may be `null`.** Step 5.3 (SKILL.md:166) passes `--eval-set <eval_set_path>` where `eval_set_path` may be `null` (review returns `null` when PRD is unknown). The prose says "if `eval_set_path` is `null`, bootstraps the eval_set from the PRD" via `--prd`, correct per `/test` Step 2 — but the literal instruction renders `--eval-set null` as a flag. Pass `--eval-set` only when non-null, else rely on `--prd`. As written it risks `/test` reading a file named `null`.

## Improve (prioritized)

1. **Fix the branch contract (CRITICAL).** Codify how build-agent output reaches `feat/prd-<n>-<slug>`. Two options:
   - **(a) Have build agents work directly on the feature branch** (no sub-branch, no PR). Pass a per-agent flag that suppresses `eng`'s sub-branch+PR behavior, or instruct each build agent in its prompt: "Commit directly to `feat/prd-<n>-<slug>`; do NOT cut a sub-branch and do NOT open a PR (Step 8 is skipped, as the full-suite gate Step 5 already is)." Parallel agents committing to one branch race — so serialize commits or assign disjoint file sets per agent (the exec-table already groups by agent, so file disjointness is plausible). Document the race mitigation.
   - **(b) Add an explicit merge step** after Build: `ship` fast-forward/merges each sub-branch into `feat/prd-<n>-<slug>` (a local merge, not a push, so it doesn't violate "never merges to main" — clarify the no-merge rule means no merge to the integration/main branch). Then review/test/pre-merge see a real diff.
   Whichever is chosen, add a post-build assertion: `git diff --quiet <base>...feat/prd-<n>-<slug>` must be non-empty, else hard-fail with a diagnostic ("build produced no commits on the feature branch — check eng sub-branch/PR contract"). This assertion would have caught the bug.

2. **Define commit ownership for the fix stage.** State that fix agents commit their changes to `feat/prd-<n>-<slug>` before returning (or that `ship` commits after collecting them), so each round's `/review`/`/test` diff is well-defined. Add the same non-empty-diff sanity check after each fix round.

3. **Add progress-based stuck detection.** Track `open_issue_count` per round. If two consecutive rounds show no net decrease (or the same finding IDs reappear), pause early with a "loop is not converging — N issues persisting: <list>" message rather than consuming the full cap. One counter to add.

4. **Add context/cost controls.** Cap fix scope per round ("fix at most the top K `block`/`warn` findings by severity, defer the rest to the next round") to bound fix-agent context. Instruct the orchestrator to retain only the latest review/test findings JSON, not accumulate prior rounds. Optionally add a `--max-findings-per-round` knob.

5. **Branch the `/test` eval-set flag.** In Step 5.3, pass `--eval-set <path>` only when `eval_set_path != null`; otherwise pass only `--prd <prd_path>`. Prevents `--eval-set null`.

6. **Validate path derivation.** After Step 1 derivation, assert `n` and `slug` are non-empty and that `branch` is well-formed; hard-refuse if a passed PRD path doesn't match the `prd-[n]-[slug]` shape, rather than building a malformed branch name.

7. **Reconcile diff-base semantics.** Make the guardrail script and `/review`/`/pre-merge` agree on two-dot vs three-dot semantics for `--base`, or document why they differ. Have `ship` resolve the merge-base once and pass an explicit SHA to all three.

## Remove

- **Redundant restatement of the autonomy contract.** The autonomy/permission narrative appears three times: § Autonomy contract (SKILL.md:68-72), § Permission policy intro (SKILL.md:74-78), and inline in every subagent-prompt list (Steps 3, 5, 6). The subagent-prompt copy goes into the agent and must stay, but the § Autonomy contract block and § Permission policy intro overlap. Collapse to one canonical statement plus one "state this to the user" pointer.
- **The "never pushes or merges" triple statement.** Stated at SKILL.md:66, :72, and :194. Keep one occurrence (the Hard refusals bullet) and drop the other two to a cross-reference.
- **The Pipeline-stages prose at SKILL.md:30-34 and :36-48** duplicates the stage table. The table (SKILL.md:40-46) is the artifact; the surrounding "ship is the engineering counterpart to /plan… owns no build/review/test protocol of its own" prose can be trimmed to 2-3 lines without losing protocol content. Lower priority — cut only if tightening for token budget.

## Introduce

- **Post-build diff sanity gate (see Improve #1).** Assert the feature branch contains the build output before entering the loop. Turns the silent-empty-diff failure into a diagnosable one.
- **Resume / idempotency.** A long run can be interrupted (crash, user stop at a guardrail, `max_rounds` pause). Add a `--resume` that detects the existing `feat/prd-<n>-<slug>` branch and the latest `features/prd-<n>/review/*` + `test/*` JSONs and re-enters the loop at the right round instead of rebuilding. Pairs with the round/guardrail pauses the skill already has.
- **Dry-run / plan-only mode (`--dry-run`).** Resolve the PRD, parse the exec table, show the agent groups and which rows are pre-flagged as DB-concern (Step 2 already computes this), and stop before spawning anything. Lets a user check the orchestration plan before an autonomous run.
- **A run ledger.** Append a one-line-per-stage record (build agents spawned, files touched, each round's verdict + open-issue count, guardrail trips) to `features/prd-<n>/ship/run-<ts>.md`. Gives an auditable trace of a hands-off run and feeds `/handoff`.
- **Optional auto-`/docu` and `/handoff` chaining.** The final summary points to `gh pr create` / `/handoff`. Since `/docu` (stale-reference check) sits between pre-merge and PR in the pipeline (review SKILL.md:24 shows `/docu` in the chain), add an opt-in `--docu` that runs it as a final subagent so the merge-ready branch has docs reconciled.

## Priority Ranking

| Recommendation | Impact | Effort |
|---|---|---|
| Fix branch contract w/ eng --build (Improve #1) | High | Med |
| Post-build non-empty-diff sanity gate (Introduce / #1) | High | Low |
| Define fix-stage commit ownership (#2) | High | Low |
| Progress-based stuck/thrash detection (#3) | Med | Low |
| Branch the `/test` eval-set flag (#5) | Med | Low |
| Validate PRD-path derivation (#6) | Med | Low |
| Context/cost controls on the loop (#4) | Med | Med |
| Reconcile diff-base semantics (#7) | Med | Med |
| Resume / idempotency mode | Med | Med |
| Remove redundant autonomy/no-push restatements | Low | Low |
| Dry-run mode | Low | Low |
| Run ledger artifact | Low | Low |
| Optional --docu chaining | Low | Low |


---

# Skill: todo

## Summary

`todo` parses one of three input shapes (a `plan-em` PRD execution table, an open-questions file, or free-form prose) and appends structured task objects to `TODOs.json`, asking clarifying MCQs for prose and gating on user approval before every write. Its two file-based input contracts are broken against the real artifacts they read: the exec-table parser keys on columns the actual `plan-em` table does not have, and the open-questions detector cannot recognize the real `OPEN-QUESTIONS.md` format. Tasks carry no traceability to source and there is no dedup.

## Quality Assessment

### Strengths

- **Append script.** `scripts/append-tasks.sh` validates input is a non-empty array (line 43), checks each task has required fields (line 49), bootstraps `TODOs.json` as `[]` if missing (line 56), validates the existing file is an array (line 60), assigns ids by reading the current max via `jq capture` (lines 66–69), and writes atomically through `mktemp` + `mv` with an `EXIT` trap (lines 72–83). Verified: empty-file → `todo-1`, and id continues from max on subsequent runs.
- **Schema is precise and self-consistent.** `refs/schema.json` sets `additionalProperties: false`, an `id` pattern `^todo-[0-9]+$`, a `status` enum, `agents` as `string|null`, and `minLength: 10` on description. It matches the shape documented in SKILL.md (lines 39–46) and the field the script assigns.
- **Approval gate is unconditional.** Step 5 (SKILL.md:72–77) renders a preview table, lists dropped items with reasons, and offers approve/abort before any write. The script only concatenates (`$existing + .`, line 80), never overwrites.
- **Prose-clarification flow.** `refs/clarify-questions.md` organizes questions into three pillars (system / outcome / constraint), gives stop rules (line 60–63: stop at 4, stop early when all pillars covered, never repeat a category), and a worked example. Step 3 (SKILL.md:61–62) provides a refusal path when scope stays ambiguous.
- **Task-filter heuristic is concrete.** `refs/task-filter.md` has a keep/drop decision table with eight worked verdicts (lines 33–42) and edge-case rulings for docs, research spikes, hiring, and mixed items, rather than a vague "drop non-technical" instruction.

### Weaknesses

- **CRITICAL — Exec-table parser does not match the real `plan-em` table.** `parsing-rules.md:15` detects `prd` by a header row including `Feature`, `Phase`, or `Execution`, and the worked example (lines 34–41) parses a fabricated `| Feature | Phase | Owner | Status |` table. The table `plan-em` writes (`plan-em/refs/template-exec-table.md:13`) has three columns: `Feature | Execution steps | Agent`. There is no `Phase`, no `Owner`, no `Status` column. Consequences:
  - Detection fires because the word `Execution` appears in the `Execution steps` header, by luck not design.
  - The parsing recipe (`parsing-rules.md:29`) tells the model to read a "primary descriptor column (commonly `Feature`, `Task`, or `Deliverable`)" and "combine it with any phase or scope columns" — none of which exist; the real descriptor is `Feature` = `<ID>: <name> — <concern>` (e.g. `F1: Set daily goal — API contract`).
  - The drop rule (`parsing-rules.md:31`: "Drop rows where status indicates the work is already complete (`done`, `shipped`, `merged`)") can never fire, because the real table has no Status column. Dead logic.
  - The example derived task `"Implement user profile avatar upload (backend, P1)"` is shaped for a phase/owner table that does not exist.
- **CRITICAL — Open-questions detector cannot recognize the real `OPEN-QUESTIONS.md`.** `parsing-rules.md:16` classifies `open-questions` as "a numbered or bulleted list where ≥3 items end with `?`". The real file (`msg-init/refs/template-OPEN-QUESTIONS.md`) is not a question list — it is a structured entry log with `### [YYYY-MM-DD] Short question title` headers and field lines (`**Question**:`, `**Severity**:`, `**Status**:`, `**Context**:`, `**Decision**:`, `**Raised by**:`). The `?`-ending bullets the detector looks for do not exist in that template. The real file falls through to detection rule 3 (`parsing-rules.md:17`: "refuse — unrecognized file shape") and the skill refuses to parse the artifact the ecosystem produces.
  - The parsing recipe (`parsing-rules.md:44–56`) assumes bare questions and has no handling for the `Severity`/`Status` fields — it ignores `critical`/`high` severity that should map to task priority, and ignores `Status: resolved` entries that should be skipped.
- **MAJOR — No source traceability in the task object.** The task shape (`schema.json`, SKILL.md:39–46) has only `id`, `status`, `agents`, `description`. There is no `source` field linking a task to its originating PRD path, exec-table feature ID (e.g. `F1`), or open-question title. A reader of `TODOs.json` cannot tell which PRD or feature a task came from.
- **MAJOR — No dedup.** Neither the protocol nor the script checks for existing tasks. Verified: running the same task array twice yields 2 entries with 1 unique description. Re-running `/todo` on the same PRD (normal after a PRD is re-tuned) doubles every task.
- **MINOR — No completion / update / status-transition flow.** The schema supports `in-progress`/`done` and the example shows a `done` task (`schema.json:44–47`), but the skill is append-only — there is no path to mark a task done, change status, or reconcile against shipped work. The lifecycle the schema promises is unreachable through the skill.
- **MINOR — Missing task fields.** No `priority` (despite open-questions carrying `Severity`), no `deps` / cross-task dependency (despite exec tables carrying cross-agent dependencies per `plan-em/refs/protocol-exec.md`), no `created` timestamp, no `feature_id`. The `agents` field is a free-text hint with no link to the exec-table `Agent` column it could be populated from.
- **MINOR — One row → one task loses exec-table fan-out semantics.** The real exec table has multiple rows per feature, one per concern (API contract, schema migration, Tests, etc.) — see `template-exec-table.md:53–61` where F1 spans 5 rows. "One row → one task" (SKILL.md:66, parsing-rules.md:26) is correct granularity, but the skill never captures the `Agent` column into the task's `agents` field, even though that mapping is free and useful.
- **MINOR — No downstream consumer of `TODOs.json`.** In the skill tree, only `msg/SKILL.md:32` (menu description) and `msg/SKILL.md:135` (handoff label hint) reference `TODOs.json`; `handoff` greps inline `TODO/FIXME` and reads `OPEN-QUESTIONS.md` but does not read `TODOs.json`. The file is write-only in the ecosystem — nothing consumes the structured output.
- **MINOR — Progress emission says `Step X/6`** (SKILL.md:50) but Step 2 and Step 3 are no-ops for `prd`/`open-questions` inputs; emitting "Step 2/6" then skipping reads oddly for the file-based path.

## Improve (prioritized)

1. **Fix exec-table detection and parsing to match the real `plan-em` table.** *Why:* the primary input contract is broken against the actual artifact. *How:* In `parsing-rules.md`, change the detection example and recipe to the 3-column shape `Feature | Execution steps | Agent`. Parse `Feature` as `<ID>: <name> — <concern>`; map the `Agent` column into the task's `agents` field; capture the feature ID (e.g. `F1`) into a new `source`/`feature_id` field. Delete the dead "drop rows where status is done" rule (no Status column exists) or replace it with "skip rows whose Execution steps are blank" if filtering is wanted.

2. **Fix open-questions detection and parsing to match the real `OPEN-QUESTIONS.md`.** *Why:* the skill refuses the file `msg-init` produces. *How:* In `parsing-rules.md`, detect by the structured-entry markers (`### [date]` headers plus `**Question**:`/`**Severity**:`/`**Status**:` field lines) rather than "≥3 lines ending in `?`". Skip entries with `Status: resolved`. Map `Severity` (critical/high/medium/low) to a task `priority`. Carry the question title into a `source` field.

3. **Add source traceability to the task object.** *How:* Add a `source` field to `schema.json` (e.g. `{"file": "...prd-3.md", "ref": "F1: API contract"}` or a string like `prd-3#F1`), set `additionalProperties` accordingly, populate it in the parsing recipes, and pass it through `append-tasks.sh` (the script already preserves arbitrary fields via `.value + {id: ...}`, so only the required-field check at line 49 and the schema need updating).

4. **Add dedup before append.** *Why:* re-running `/todo` doubles tasks (verified). *How:* In `append-tasks.sh`, before concatenating, drop incoming tasks whose `description` (or `source` ref, once added) already exists in `TODOs.json`; report skipped duplicates in the final count line. Or gate dedup in Step 5 preview so the user sees "N new, M already present."

5. **Add priority and dependency fields.** *Why:* both source formats carry this signal (open-questions `Severity`, exec-table cross-agent deps) and it is dropped today. *How:* Add optional `priority` (enum) and `deps` (array of `todo-N`) to `schema.json`; populate `priority` from open-questions severity; leave `deps` derivable later.

6. **Tighten progress emission for skipped steps.** *Why:* emitting "Step 2/6" then skipping is noise on the common path. *How:* Either collapse Steps 2–3 into "Step 2/5 — Clarify (prose only, else skip silently)" or note in SKILL.md:50 that skipped steps emit a one-line "skipped (input is prd)".

## Remove

- **The dead "drop rows where status is `done/shipped/merged`" rule** (`parsing-rules.md:31`) — the real exec table has no Status column, so this never executes. Remove or repurpose to "skip rows with blank Execution steps."
- **The fabricated `| Feature | Phase | Owner | Status |` example** (`parsing-rules.md:34–41`) — it teaches a table shape that does not exist in the ecosystem and misleads parsing. Replace with the real 3-column example.
- **The "primary descriptor column (commonly `Feature`, `Task`, or `Deliverable`)" optionality** (`parsing-rules.md:29`) — the real column is always `Feature`; the optionality invites the model to hunt for columns that aren't there.
- Nothing else is bloat — the refs are tight and the script has no redundant logic. This is a correctness cleanup, not a size cleanup.

## Introduce

- **A `--list` / status view.** Read `TODOs.json` and render the current tasks grouped by status. *Why:* the file is write-only with no in-ecosystem reader; a list view makes the structured output usable.
- **A `--done todo-N` / status-transition command.** *Why:* the schema promises a `todo → in-progress → done` lifecycle (`schema.json:14–18`) that is unreachable today. A small `update-task.sh` mirroring `append-tasks.sh` would close the loop.
- **`handoff` integration.** `handoff` surfaces open items from `OPEN-QUESTIONS.md` and inline `TODO/FIXME` (`handoff/SKILL.md:120–121`) but ignores `TODOs.json`. *Why:* the structured task list is the most authoritative open-work source in the repo; feeding incomplete `TODOs.json` entries into the handoff "Open items / Next steps" sections would give the skill a consumer.
- **Source-back-link on parse.** When parsing a PRD, optionally annotate the exec-table rows (or write a `tasks:` block) so the PRD knows which tasks were generated — closes the traceability loop in both directions.

## Priority Ranking

| Recommendation | Impact | Effort |
|---|---|---|
| Fix exec-table detection/parsing to real `plan-em` shape | High | Med |
| Fix open-questions detection/parsing to real `OPEN-QUESTIONS.md` shape | High | Med |
| Add `source` traceability field | High | Low |
| Add dedup before append | High | Low |
| Remove dead status-drop rule + fabricated table example | Med | Low |
| Add `priority` (from severity) and `deps` fields | Med | Med |
| Introduce `--list` and `--done` status flow | Med | Med |
| Wire `TODOs.json` into `handoff` as an open-items source | Med | Low |
| Tighten progress emission on skipped steps | Low | Low |


---

# Skill: docu

## Summary

`docu` is a post-change documentation drift checker: it resolves a diff (HEAD, a branch, or a PR number), discovers a set of doc files, flags stale references (endpoints, versions, identifiers, config keys, module paths), and offers per-finding inline fixes through an `AskUserQuestion` gate. The file-discovery step (Step 2) hunts for `AHA.md`, `ARCHITECTURE.md`, and `PRD*.md` at root/`docs/`, but the msg framework stores those files under `devkit/` and PRDs under `features/prd-*/prd-*.md`. In a real msg project, docu finds zero target docs and reports "up to date" — a false negative on its primary job.

## Quality Assessment

### Strengths

- **Trigger surface.** `description` (`SKILL.md:3-6`) names the four target doc types and the three invocation modes (HEAD / branch / PR#). The natural-language triggers (`SKILL.md:24`) are concrete ("check docs for stale references", "sync docs with the diff"). It fires when intended.
- **Negative scoping.** The "Hard refusals" (`SKILL.md:26-29`) and "Out of scope" (`SKILL.md:42-48`) blocks are explicit and non-overlapping: docs-only, no source edits, no new doc generation, no quality/coverage auditing. This delineates it from `/review`, which disclaims docs (`review/SKILL.md:34` — "does NOT check documentation (`/docu`'s job)"). The review → docu handoff contract is consistent.
- **Ordered, gated protocol.** Five numbered steps with early exits at each failure point: empty diff (`SKILL.md:60-66`), no doc files (`SKILL.md:88-94`), zero findings (`SKILL.md:117-123`). The per-finding `AskUserQuestion` with Apply / Skip / Stop all (`SKILL.md:136-148`) is the right granularity — the user keeps control and can bail mid-stream.
- **Idempotent, side-effect-honest.** Output is terminal-only, no report file (`SKILL.md:40`). Edits are exact `stale_text → suggested_text` replacements (`SKILL.md:152-154`), so re-running on an already-fixed doc produces zero findings. The final tally includes "not reviewed (stopped)" (`SKILL.md:165-169`).
- **Token-efficient.** No refs directory, no scripts — the skill is one file. Diff and docs are read lazily and only as needed. The `find` is capped at 20 files / `head -20` (`SKILL.md:85,88`) and `node_modules`/`dist`/`.lock` are excluded.
- **False-positive guard.** Step 3.5 (`SKILL.md:115`) instructs skipping incidental matches and flagging only lines that "clearly refer to the changed entity."

### Weaknesses

- **CRITICAL — discovery paths contradict the ecosystem (`SKILL.md:70-88`).** Step 2 searches for `AHA.md`, `ARCHITECTURE.md` (bare, at root/subdirs ≤3 deep) and `PRD*.md`. But `msg-init` — the only skill allowed to create these — writes them to `devkit/AHA.md` and `devkit/ARCHITECTURE.md` (`msg-init/SKILL.md:62-67`: "`devkit/` is a directory ... that lives at the root"). PRDs live at `features/prd-[n]-[slug]/prd-[n]-[slug].md` (`plan-pm/SKILL.md:5,129`; `plan-em/SKILL.md:32` refuses anything not matching `features/prd-*/prd-*.md`). The `find` glob in `SKILL.md:81-85` recurses 3 levels deep, so `devkit/AHA.md` (1 level) is found by recursion. The PRD pattern is uppercase `PRD*.md` and real files are lowercase `prd-*.md`, so it does not match. The skill's description and References advertise root-level files. Result: in a canonical msg project, AHA/ARCHITECTURE are found only incidentally via recursion, not by design, and PRDs are missed entirely due to the `PRD*.md` vs `prd-*.md` case gap. This is a silent false negative on the skill's headline purpose.
- **Description lists files the framework doesn't put where docu looks.** The `description` and `## References` (`SKILL.md:173-175`) speak of `ARCHITECTURE.md` and `AHA.md` as root-level, reinforcing the wrong location model. `GLOSSARY.md`, `DESIGN-SYSTEM.md`, and `OPEN-QUESTIONS.md` — also part of `devkit/` (`msg-init/SKILL.md:40-44`) and prone to drift (glossary terms, component names, config) — are not in docu's target set at all.
- **`reason` derivation is under-specified (`SKILL.md:114`).** The example reason references "in commit," but a branch/PR diff may have many commits. There is no instruction to attribute the change to a specific hunk, so `reason` quality varies.
- **No multi-occurrence handling.** Step 5 uses `Edit` with `stale_text → suggested_text` (`SKILL.md:152-154`). If the stale string appears multiple times in a doc (common for an endpoint or version string), `Edit` requires uniqueness and will fail or under-replace. The protocol never mentions `replace_all` or disambiguation by line number, despite collecting `line_number` in the finding (`SKILL.md:109`).
- **Findings cap is implicit.** `## Outputs` says output "fits in a single scrollable view for ≤5 findings" (`SKILL.md:40`) but the protocol never enforces or prioritizes a cap. A large diff against many docs could produce 30 findings and 30 sequential `AskUserQuestion` prompts, inconsistent with the stated design target.
- **No diff-size / binary guard at resolution.** Step 1 resolves the diff but doesn't truncate or summarize a huge diff before per-file comparison (Step 3 reads "the diff" wholesale per doc file, `SKILL.md:101`). On a large PR this re-reads a large diff once per doc — wasteful and potentially context-blowing.

## Improve (prioritized)

1. **Fix discovery to match ecosystem conventions (CRITICAL).**
   *What:* Rewrite Step 2's target set and `find` to include `devkit/*.md` and `features/prd-*/prd-*.md`, and lowercase the PRD glob.
   *Why:* As written, docu finds none of its canonical targets in a real msg project (evidence above), defeating the skill's purpose.
   *How:* Replace the patterns (`SKILL.md:70-85`) with priority order: `README.md` (root), `devkit/ARCHITECTURE.md`, `devkit/AHA.md`, `devkit/GLOSSARY.md`, `devkit/DESIGN-SYSTEM.md`, `features/prd-*/prd-*.md`, then `docs/**/*.md` as a fallback for non-msg repos. Use a glob like:
   ```bash
   rtk find . -maxdepth 3 -type f \( -name "README.md" -o -path "*/devkit/*.md" \
     -o -path "*/features/prd-*/prd-*.md" -o -path "*/docs/*.md" \) \
     ! -path "*/node_modules/*" ! -path "*/dist/*" ! -name "*.lock" 2>/dev/null | head -20
   ```
   Keep a fallback branch for bare-root `ARCHITECTURE.md`/`AHA.md` so non-msg repos work. Update the `description` (`SKILL.md:3-6`) and `## References` (`SKILL.md:171-175`) to say `devkit/` paths.

2. **Handle multi-occurrence edits.**
   *What:* Make Step 5 edit-safe when `stale_text` is non-unique.
   *Why:* Endpoint/version strings recur; a plain `Edit` fails on non-unique matches, leaving some references stale (`SKILL.md:152-154`).
   *How:* Use the `line_number` already captured to scope the edit, or instruct: "if `stale_text` occurs more than once and all occurrences are stale, use `Edit` with `replace_all: true`; otherwise anchor the match with surrounding context to make it unique."

3. **Enforce a findings cap with prioritization.**
   *What:* Cap at the stated 5 findings (`SKILL.md:40`) or batch the `AskUserQuestion` gate.
   *Why:* The "single scrollable view ≤5" design target is asserted but never enforced; large diffs produce a wall of sequential prompts.
   *How:* In Step 3, after collecting findings, sort by confidence (exact identifier rename > heuristic match) and either (a) cap at top N with a "+K more not shown" note, or (b) present findings as a single multiSelect `AskUserQuestion` ("Which fixes to apply?") instead of one prompt per finding.

4. **Add GLOSSARY/DESIGN-SYSTEM/OPEN-QUESTIONS as drift targets.**
   *What:* Extend the target set (see #1) to the rest of `devkit/`.
   *Why:* Renamed domain terms (GLOSSARY) and changed component/config names (DESIGN-SYSTEM) are the drift docu is built to catch; today they are invisible to it.
   *How:* Included in the glob in #1; add a line to Step 3's "Look for" list for "domain terms (GLOSSARY)" and "component names (DESIGN-SYSTEM)."

5. **Tighten `reason` attribution and large-diff handling.**
   *What:* (a) Require `reason` to cite the specific diff hunk/file, not "the commit." (b) For multi-commit branch/PR diffs, note the change source per finding.
   *Why:* Improves the actionability of each finding; `SKILL.md:114` is vague for branch/PR mode.
   *How:* Reword the `reason` example to "endpoint renamed `/v1`→`/v2` in `src/router.ts`." Optionally pre-summarize the diff to a changed-identifier list once, then match docs against that list (also reduces the per-doc re-read cost noted in weaknesses).

## Remove

- **Stale `## References` lines (`SKILL.md:173-175`).** The "ARCHITECTURE.md — may be a doc target" / "AHA.md — may contain version strings" notes describe root-level files and add no operational value beyond what Step 2/3 already say. Delete them or fold the corrected, `devkit/`-qualified paths into Step 2. As-is they reinforce the wrong location model.
- **The redundant `PRD*.md` priority item in the prose list (`SKILL.md:73-77`) vs the `find` command (`SKILL.md:81-85`).** The numbered priority list (1–5) and the `find` glob diverge: the prose lists ARCHITECTURE/AHA/PRD explicitly; the glob is the source of truth. Keep one. The duplicated, inconsistent specification is a maintenance trap — collapse to a single target list.

(No files/scripts to remove — the skill is minimal.)

## Introduce

- **Dry-run / summary mode (`/docu --dry`).** Print all findings and the tally without prompting per finding. Useful inside autonomous loops (`/ship`) where docu can't run unattended because every finding blocks on `AskUserQuestion`. *Rationale:* docu sits in the happy path (`msg/SKILL.md:46`) between `/test` and `/pre-merge`; an interactive-only gate is friction for hands-off pipelines. A non-interactive report mode lets it participate in `/ship` without a human.
- **CHANGELOG.md as a target (and optional auto-append).** `msg-init` creates `CHANGELOG.md` (`msg-init/SKILL.md:71`) maintained by `kermit`. docu has the diff in hand; flagging missing/stale changelog entries is an in-scope extension of "doc drift." *Rationale:* closes a gap — version-string drift in a changelog is the canonical doc-staleness case.
- **Confidence tier on each finding.** Tag findings High (exact identifier rename present verbatim in both diff and doc) vs Heuristic (fuzzy/semantic match). *Rationale:* lets the user (and a `--dry` consumer) trust High auto-apply and scrutinize Heuristic, and feeds the prioritization cap in Improve #3.
- **`devkit/` absence handling consistent with the ecosystem.** Other msg skills "halt and direct the user back to `msg-init`" when `devkit/` is missing (`msg-init/SKILL.md:46`). docu should note in its "no doc files" exit (`SKILL.md:88-94`) whether `devkit/` exists, so a user who ran docu in an uninitialised repo gets pointed to `msg-init` rather than a bare "nothing to check." *Rationale:* ecosystem consistency; avoids the false "up to date" signal.

## Priority Ranking

| Recommendation | Impact | Effort |
|----------------|--------|--------|
| Fix discovery to match `devkit/` + `features/prd-*` conventions (Improve #1) | High | Low |
| Lowercase/realign PRD glob (part of #1) | High | Low |
| Multi-occurrence edit safety (Improve #2) | High | Low |
| Add GLOSSARY/DESIGN-SYSTEM/OPEN-QUESTIONS targets (Improve #4) | Med | Low |
| Enforce findings cap / batch the gate (Improve #3) | Med | Med |
| `--dry` non-interactive mode for `/ship` (Introduce) | Med | Med |
| Remove stale `## References` + dedupe target list (Remove) | Med | Low |
| Confidence tiers (Introduce) | Med | Med |
| `devkit/` absence → point to msg-init (Introduce) | Low | Low |
| CHANGELOG.md target + auto-append (Introduce) | Low | Med |
| Tighten `reason` attribution / large-diff pre-summary (Improve #5) | Low | Med |


---

# Skill: handoff

## Summary

`handoff` is a zero-input skill that derives a numbered handoff artifact at `handoff/<n>.md` from git state plus optional project files (`CLAUDE.md`, `devkit/ARCHITECTURE.md`, `devkit/OPEN-QUESTIONS.md`). It is a single self-contained `SKILL.md` (150 lines, no refs). The main problem: the artifact omits session intent (the uncommitted, in-progress work and the "why"), and it has a path-vs-numbering edge case plus a redaction step that cannot be enforced as written.

---

## Quality Assessment

### Strengths

- **Deterministic protocol.** Five numbered steps (`SKILL.md:79–143`), each with `rtk` commands and explicit empty-state fallbacks (`- none`, `- none identified`).
- **Empty/clean-tree handling.** `SKILL.md:89` ("If all three return empty/nothing, the working tree is clean — sections will be empty or say 'none'") and `Hard refusals: None` (`SKILL.md:25`) mean the skill never errors on a clean repo.
- **Numbering is defined.** `SKILL.md:103–107` handles absent/empty dir (`next number is 1`) and `max + 1` otherwise, with `2>/dev/null || echo "EMPTY"` guarding the missing-dir case. Matches the sibling convention (`improve/[n]-...`).
- **No-duplication content rule** (`SKILL.md:73`) forces pointers over copy-paste, which keeps a handoff readable and ≤50 lines.
- **Token efficiency.** Single file, no refs, all commands `rtk`-prefixed per the global instruction.
- **Format contract is fixed and parseable** (`SKILL.md:50–67`) — a downstream agent can grep `## Next Steps`.

### Weaknesses

- **The output omits session intent / the "why".** The artifact derives purely from git state and static files. The next agent needs what the previous agent was trying to do and where it got stuck — which lives in the conversation, not in git. "Worked On" is synthesised from `git log -5 --oneline` (`SKILL.md:115`), i.e. already-committed work. For a mid-session handoff (the stated trigger: "any point in a session", `SKILL.md:22`), the relevant work is uncommitted and unexplained. The artifact will describe stale committed history while the in-progress reasoning is dropped. This is the biggest gap.

- **"Worked On" double-counts and can mislead.** It blends `git log -5 --oneline` with `git diff --stat HEAD` (`SKILL.md:115`). The last 5 commits may predate this session (other authors, prior work), so "Worked On" can attribute unrelated commits to the current session. There is no session-boundary heuristic (e.g. "commits since branch diverged from main", or "commits today").

- **Redaction step is unenforceable as specified.** `SKILL.md:75` instructs the model to "scan each derived bullet for secrets… replace with `[REDACTED]`." But every derived field is a filename, status code, commit subject, or module name — none carry secret values. The one place a secret could leak is the `grep TODO/FIXME` inline-text capture (`SKILL.md:122`), where a TODO line could embed a token. The redaction rule is written as a blanket scan but the risk surface is narrow; as written it is ceremony, not an enforced control, and gives false confidence.

- **Path inconsistency: `handoff/` at repo root vs the `devkit/` convention.** The skill writes to `handoff/<n>.md` at the repo root (`SKILL.md:45, 109`), while every other artifact-producing sibling and every input file lives under `devkit/` (`devkit/ARCHITECTURE.md`, `devkit/OPEN-QUESTIONS.md`) or `features/`. A root-level `handoff/` dir is an outlier and will surprise users who expect generated artifacts under `devkit/`. (Confirmed: this repo has no `devkit/`, no root `CLAUDE.md`, and no `handoff/` dir yet — so all three optional inputs are absent and the skill degrades to git-only.)

- **No branch / PR / base-ref context in the artifact.** The Format contract (`SKILL.md:50–67`) has no field for current branch, upstream, ahead/behind, or an open PR. A next agent has to re-discover "what branch am I on and is there a PR?" — orientation the skill has the git access to capture cheaply.

- **"Affected" vs "Not Affected Yet" framing is ambiguous.** "Not Affected Yet" (`SKILL.md:62`, `119–124`) is sourced from a grab-bag: OPEN-QUESTIONS unchecked items, TODO/FIXME greps, and untracked `??` files. Untracked files are new work, not "not affected yet" — lumping them under a "not touched" heading is backwards and could mislead the next agent into ignoring new files.

- **Line-trim heuristic can corrupt the most important section.** Step 4.3 (`SKILL.md:132`) trims "the longest section (usually File Refs or Not Affected Yet)" to fit ≤50 lines. On a large changeset, File Refs gets truncated — but File Refs is the map of what changed. Truncating it to 5 + "(n more)" defeats the artifact's purpose on the sessions where a handoff matters most (big changes). Section budgets should be per-section, not "trim whatever's longest."

- **No de-dup / overwrite guard beyond numbering.** If two handoffs are written in one session (agent writes one, does more work, writes another), there is no link from `<n>.md` back to `<n-1>.md`, so the next agent reading `3.md` has no breadcrumb to the prior two. A "Previous: handoff/2.md" pointer would chain them.

---

## Improve (prioritized)

1. **Capture session intent, not just git history.** *What:* Add a "Session Goal / In Progress" section to the Format contract derived from the live conversation, plus prioritize uncommitted changes (`git diff` working tree, not just `HEAD`/`log`). *Why:* The current artifact describes committed past work; the next agent needs the in-flight goal and the half-done thing. *How:* In Step 1 add `rtk git diff --stat` (unstaged) alongside `--stat HEAD`; add a `## In Progress` section the agent fills from the current task context. Keep it ≤3 bullets.

2. **Add branch / PR orientation.** *What:* A `## Branch` line: current branch, upstream, ahead/behind, and open PR if any. *Why:* First question any next agent asks. *How:* Step 1 add `rtk git branch --show-current`, `rtk git rev-list --count --left-right @{u}...HEAD 2>/dev/null`, and `rtk gh pr view --json number,url,state 2>/dev/null` (degrade silently if no upstream/PR).

3. **Scope "Worked On" to the session, not the last 5 commits.** *What:* Replace `git log -5 --oneline` with commits since branch base. *Why:* Avoids attributing unrelated/older commits to this session. *How:* `rtk git log --oneline $(rtk git merge-base HEAD main)..HEAD` with a fallback to `-5` when no merge-base (detached/empty repo). Document the empty-repo fallback explicitly (currently undocumented).

4. **Fix the path to live under `devkit/` (or document the deliberate exception).** *What:* Move output to `devkit/handoff/<n>.md` to match the ecosystem, OR add one sentence justifying root placement. *Why:* Consistency with all sibling inputs/outputs; reduces user surprise. *How:* Change `SKILL.md:45, 109, 140` paths; update the `## References` note.

5. **Replace the blanket redaction step with a targeted one.** *What:* Narrow redaction to the only real risk surface — TODO/FIXME captured text and any URL/path bullets. *Why:* The current blanket scan is unenforceable over fields that cannot carry secrets. *How:* Rewrite `SKILL.md:75` to: "When emitting TODO/FIXME text, redact any substring matching common secret patterns (`sk-`, `ghp_`, `AKIA`, `Bearer `, key=value with high-entropy value). Other derived fields (filenames, status codes, module names) need no redaction."

6. **Per-section line budgets instead of "trim the longest."** *What:* Give each section a cap (e.g. File Refs ≤15, Worked On ≤5, Affected ≤8, Next Steps ≤5) and overflow each independently. *Why:* Protects File Refs — the map of what changed — from being truncated first. *How:* Replace `SKILL.md:132` with explicit caps + per-section "(n more)".

7. **Reclassify untracked files.** *What:* Move `??` untracked files out of "Not Affected Yet" into "File Refs" (or a "New / Untracked" sub-bullet under Affected). *Why:* New files are work-in-progress, not untouched. *How:* Edit `SKILL.md:122–123` and the File Refs derivation at `113`.

8. **Chain handoffs.** *What:* If `<n-1>.md` exists, add `## Previous\n- handoff/<n-1>.md`. *Why:* Lets a next agent walk the trail of a multi-handoff session. *How:* In Step 2 after resolving `n`, if `n>1` emit the pointer line.

## Remove

- **The blanket redaction sentence as currently phrased** (`SKILL.md:75`) — replaced, not removed entirely (see Improve #5). As written it asserts a control over fields that cannot contain secrets.
- **`git diff --name-only HEAD` as a separate command** (`SKILL.md:93–95`). Redundant with `git status --short` (File Refs) and `git diff --stat HEAD` (which already lists names). Three near-identical git reads in Step 1 collapse to two.
- **The `## Inputs` and `## Outputs` tables' overlap with the protocol.** The Inputs table (`SKILL.md:31–39`) restates every command already in Step 1, and Outputs (`43–46`) restates Step 4/5 — the same information three times in a 150-line file. Collapse Inputs/Outputs into one short reference block.

## Introduce

- **`## In Progress` / session-goal section** (covered in Improve #1) — the highest-value addition; turns the artifact from a git-state dump into a handoff.
- **Open-PR / CI awareness** — surface `gh pr checks` status so the next agent knows if the branch is red.
- **`--append` / continuation mode** — instead of always a new `<n>.md`, allow updating the latest handoff in place when the session continues, to avoid a pile of near-duplicate files.
- **Optional `--brief` vs `--full` flag** — `--brief` for the ≤50-line default, `--full` lifting the cap for large changesets where truncation loses File Refs (pairs with Improve #6).
- **A `refs/template.md`** mirroring the sibling `improve` skill's `refs/template.md`, so the format contract lives in a stable template the Write step fills rather than being reconstructed inline each run.

## Priority Ranking

| Recommendation | Impact | Effort |
|---|---|---|
| #1 Capture session intent + uncommitted diff (`## In Progress`) | High | Med |
| #3 Scope "Worked On" to session (merge-base, not -5) | High | Low |
| #2 Add branch / PR orientation | High | Low |
| #6 Per-section line budgets (protect File Refs) | Med | Low |
| #4 Move output under `devkit/` for consistency | Med | Low |
| #7 Reclassify untracked files | Med | Low |
| #5 Targeted redaction (replace blanket scan) | Med | Low |
| #8 Chain to previous handoff | Low | Low |
| Remove: drop redundant `diff --name-only` command | Low | Low |
| Remove: collapse Inputs/Outputs duplication | Low | Low |
| Introduce: `--append` continuation mode | Med | Med |
| Introduce: open-PR / CI awareness | Med | Med |
| Introduce: `refs/template.md` | Low | Low |


---

# Skill: improve

## Summary

`improve` is an improvement-planner skill: given a target skill and a description of what to fix, it asks up to 5 follow-up questions, then writes `plan.md` + `acceptance.md` to `improve/[n]-[feature-type]/`, registers the plan in `_INDEX.md`, and offers an adversarial Opus `--review` mode against any existing plan. The main weaknesses are an implicit (unenforced) local-vs-global path constraint, structural drift in the template, and accumulating archival folders that bloat the skill directory.

---

## Quality Assessment

### Strengths

**1. The output format.** The proposed-changes table at `refs/template.md:11` forces six fields per change:

```
| # | What | How | Why necessary | Why ignorable | Rank |
```

The "Why ignorable" column forces the planner to state when a change can be skipped, which prevents over-scoping and makes prioritization defensible. The exemplar at `refs/template.md:28-31` is concrete (a real plan-em data-ingestion gap), not a placeholder, so the model has a few-shot anchor.

**2. Acceptance criteria are testable gates.** In the produced output `19-plan-loop-modes/acceptance.md`, every assertion is observable: e.g. line 19 — "If a multi-PRD epic is detected... the loop is rejected immediately with the message: 'Loop mode is not supported in multi-PRD mode...'. No PRD is produced." These are pass/fail-checkable, map 1:1 to plan changes (the file is organized by `## Change N` headers mirroring the plan table), and avoid the "the feature works" tautology. SKILL.md Step 5 (`SKILL.md:132`) enforces the mapping: "Every change must map to at least one criterion — no exceptions."

**3. The `--review` adversarial protocol.** `refs/review-protocol.md` is a rubric: it checks acceptance-criteria realism ("Could it pass even if the change was never made?" line 16), plan-quality honesty ("Is this a real reason, or just a restatement of the change?" line 24), feasibility against `allowed_tools` (line 34), and coverage gaps. The 4-field output format (`review-protocol.md:58-63`) with CRITICAL/MAJOR/MINOR severities and a forced summary line is machine-gradeable. It spawns as a separate Opus agent (`SKILL.md:43`) while the main skill runs on Sonnet — a cost/quality split.

**4. Numbering handles a real failure mode.** Step 3 (`SKILL.md:122`) recognizes that plans are scattered across `./`, `done/`, `backlog/`, `archive/`, so a plain `ls` undercounts. It mandates `_INDEX.md` as the source of truth, handles the `7.1/7.2/7.3 → 7` sub-numbering case, and refuses to fall back to ls if the index is missing.

**5. Ecosystem-consistent.** The `[n]-[slug]/` directory convention, the `_INDEX.md` registry, and the severity-tagged adversarial review mirror sibling skills (`plan-tune`'s adversarial posture, `review`'s JSON findings, `plan-pm`'s `features/prd-[n]-[slug]/` layout). It registers in the `msg` root menu under "Meta" (`msg/SKILL.md:33`).

### Weaknesses

**1. The local-vs-global constraint is implicit, not enforced (the user's stated requirement).** The user constraint: improve plans must be written locally to `.claude/skills/improve/`, never to `~/.claude/skills/improve/`. The skill writes to the relative path `.claude/skills/improve/...` everywhere (`SKILL.md:124`, `:128`, `:136`), which resolves correctly only when cwd is the repo root. There is:
   - No statement anywhere that the global path is forbidden.
   - No guard that the resolved `$OUT` is under the repo working dir (the project memory file `feedback_improve_local_plans.md` shows this has been a past mistake).
   - Risk: if the skill is invoked from a subdirectory, or if a future edit absolutizes the path to `~/.claude/...`, the constraint silently breaks. The relative path is correct by accident of cwd, not by design.

**2. Template structure has drifted from what the skill produces.** `refs/template.md` has a `## Problem` + `## Proposed changes` skeleton followed by an `## Exemplar` section. The produced plans don't follow it uniformly:
   - `19-plan-loop-modes/plan.md` keeps the `## Exemplar` (lines 31-46) — the exemplar, which is teaching scaffolding for the model, gets copied into the final artifact as dead weight.
   - `done/17-review-preflight-rigor/plan.md` instead has an `## Out of scope` section (lines 23-28) and no exemplar.
   - `archive/7.3-eng-review/plan.md` adds `## Severity scale`, `## Build notes`, and `## Parked` sections.
   - `backlog/4-msg-health/plan.md` has `## Design notes` and a `**Depends on:**` header field.
   The template under-specifies. Sections that recur in practice (Out of scope, Depends on, Design notes, Parked/deferred) are not in the template, and the Exemplar that is in the template should not be persisted into output. Step 4 (`SKILL.md:126-128`) says "populated from the template" but gives no guidance on these extensions.

**3. Step 7 "Revise" loop doesn't re-validate.** When the user picks "Revise" (`SKILL.md:143`), the skill edits `plan.md`/`acceptance.md` in place and re-emits Step 7 — but never re-checks the Step 5 invariant (every change maps to ≥1 criterion). A revision that adds a plan change without a matching criterion passes silently. The `--review` mode catches this, but only if the user runs it; the inline revise loop has no guard.

**4. `--review` revise loop can desync the index.** R4 (`SKILL.md:73-75`) lets the user revise `plan.md`/`acceptance.md` in place during review, but unlike Step 7's revise branch (`SKILL.md:143`, "Update the corresponding `_INDEX.md` row if the description changed"), the `--review` revise branches never mention updating `_INDEX.md`. If a review-driven revision changes the plan's Problem statement, the index Description silently drifts.

**5. No status-transition mechanic.** `_INDEX.md:3-8` defines status purely by folder (`./` = In-progress, `done/`, `backlog/`, `archive/`), and `SKILL.md:124` says these "are moved into later by hand." The entire lifecycle after plan creation — marking done, archiving, moving the `_INDEX.md` link path to match the new folder — is manual and error-prone. The index link path and the folder must be kept in sync by hand on every move; nothing enforces it. (E.g. moving `18-` to `done/` requires editing both the folder location and the `_INDEX.md` link `(18-complexity-detection/plan.md)` → `(done/18-complexity-detection/plan.md)`.)

**6. Description could be sharper on trigger.** The description (`SKILL.md:3-6`) buries the `--review` mode and the three-intent fork (improve / not-sure / create-agent). A reader scanning the menu wouldn't know `improve` can route to `/agent-plan` or run an adversarial review.

---

## Improve (prioritized)

1. **Enforce the local-write constraint explicitly (highest priority — direct user requirement).**
   - **What:** Add a hard rule in Step 3/Step 4 that `$OUT` must resolve under the project working directory, and that writing to `~/.claude/skills/improve/` (or any absolute path outside the repo) is forbidden.
   - **Why:** The constraint is currently satisfied only by cwd luck; the project memory shows it has already been violated once. An implicit guard is not a guard.
   - **How:** In Step 4, before `Write`, add: "Resolve `$OUT` relative to the repo root (the dir containing `.claude/`). If the resolved path is outside the working directory or under `~/.claude/`, stop and emit an error — never write improve plans globally." Optionally add a one-line Bash guard: `rtk realpath "$OUT"` and assert it is a prefix of the repo root.

2. **Re-validate the change→criterion invariant after every revise.**
   - **What:** After Step 7 "Revise" edits, re-run the Step 5 check (every plan change has ≥1 acceptance criterion; no orphan criteria).
   - **Why:** The inline revise loop is the easiest way to introduce an untested change; nothing catches it until a separate `--review` run.
   - **How:** Add to the Step 7 Revise branch: "After editing, verify every row in the plan's proposed-changes table maps to at least one acceptance criterion and vice-versa; if not, fix before re-emitting."

3. **Fix the template/output drift.**
   - **What:** (a) Decide whether the `## Exemplar` is teaching scaffolding (kept in template, stripped from output) or a persisted section — currently it is inconsistently copied. (b) Add the recurring optional sections to the template as commented-out stubs: `## Out of scope`, `**Depends on:**`, `## Design notes`, `## Parked / deferred`.
   - **Why:** `refs/template.md` no longer reflects what good plans look like (`17-`, `7.3-`, `4-` all extend it differently); the model has no guidance on when to add these sections, and the Exemplar leaks into final artifacts.
   - **How:** Move the Exemplar into a `<!-- EXEMPLAR — do not copy into output -->` block, and add the four optional sections as `<!-- optional: ... -->` stubs with one-line usage notes.

4. **Make `--review` revise update `_INDEX.md` too.**
   - **What:** Mirror Step 7's index-sync note into the R4 revise branches.
   - **Why:** Prevents the index Description from drifting when a review-driven edit changes the Problem statement.
   - **How:** Append to `SKILL.md:73-75`: "If the revision changes the plan's Problem section, update the corresponding `_INDEX.md` Description row."

5. **Add a lifecycle/status helper.**
   - **What:** A documented procedure (or a `--done <n>` / `--archive <n>` flag) that moves a plan folder into `done/`|`backlog/`|`archive/` and rewrites its `_INDEX.md` link path + Status column atomically.
   - **Why:** The folder↔index sync is currently 100% manual and the most likely source of index rot.
   - **How:** Add a "Status transitions" section: `rtk mv` the folder, then edit the `_INDEX.md` row's link path and Status in the same step.

6. **Tighten the description to surface modes.**
   - **What:** Mention `--review` and the create-agent routing in the description.
   - **Why:** Improves trigger precision; users won't know the adversarial review exists.
   - **How:** Append "Also runs an adversarial Opus review (`--review`) and can route new-agent requests to `/agent-plan`."

---

## Remove

1. **Persisted `## Exemplar` blocks inside produced plans (e.g. `19-plan-loop-modes/plan.md:31-46`, `done/1-split-protocol-refs/plan.md:23-42`).** These are few-shot scaffolding that belongs in the template, not in every final artifact. They roughly double the plan length with content that restates the table above them. Strip on write (see Improve #3).

2. **`archive/` folder as a long-term store — reconsider, don't blindly delete.** `archive/7.3-eng-review/` is "Superseded by /review" (`_INDEX.md:22`). Archived plans still consume index rows and directory entries but carry near-zero forward value. Keep the `_INDEX.md` row (it documents the supersession), but the full `plan.md`/`acceptance.md` under `archive/` can be pruned once the superseding work is done. At minimum, document an archive-pruning policy so the folder doesn't grow unbounded.

3. **Redundancy between Step 7 and `--review` R4 revise logic.** Both implement near-identical "ask what to change → edit in place → re-loop" flows (`SKILL.md:143` vs `:73-76`) with different rules (one syncs the index, one doesn't). Factor the shared revise behavior into one referenced sub-protocol to eliminate the divergence that caused weakness #4.

**Nothing else is dead weight** — `refs/template.md`, `refs/review-protocol.md`, and `_INDEX.md` are all used. There is no `19-plan-loop-modes/`-style "loop-modes ref" bloat; that folder is an in-progress plan, not a stray ref.

---

## Introduce

1. **A local-path self-check (Step 0).** Before doing anything, confirm cwd is at/under the repo root containing `.claude/skills/improve/`. This enforces the local constraint (Improve #1) and prevents the numbering logic from reading the wrong `_INDEX.md`. Low effort, serves the user's stated requirement.

2. **Optional auto-invoke of `--review` after creation.** Step 7 already recommends running `/improve --review <n>`. Add a fourth option to the Step 7 prompt — "Review now" — that chains directly into the R2 Opus review without the user re-invoking. Closes the quality loop in one session.

3. **A "Depends on" field promoted to a first-class template element.** `backlog/4-msg-health/plan.md:5` already uses `**Depends on:** plan 3-msg-root-skill`. Formalizing this in the template (and optionally validating that referenced plan IDs exist in `_INDEX.md`) makes cross-plan dependencies explicit and catches broken references. The adversarial review already checks for this (`review-protocol.md:33`) but the template doesn't invite it.

4. **Acceptance-criteria count / coverage echo in Step 5.** After writing `acceptance.md`, emit a one-line summary: "N changes, M criteria, all changes covered." Gives the user immediate confidence the Step 5 invariant held, and surfaces a violation before they need `--review`.

---

## Priority Ranking

| Recommendation | Impact | Effort |
|---|---|---|
| #1 Enforce local-write constraint explicitly (Step 0 + Step 4 guard) | High | Low |
| Improve #2 Re-validate change→criterion invariant after revise | High | Low |
| Improve #3 Fix template/output drift (strip Exemplar, add optional sections) | High | Med |
| Introduce #2 Optional "Review now" chain in Step 7 | Med | Low |
| Improve #4 `--review` revise updates `_INDEX.md` | Med | Low |
| Improve #5 Lifecycle/status-transition helper | Med | Med |
| Remove #3 Factor shared revise sub-protocol (Step 7 ↔ R4) | Med | Med |
| Introduce #4 Acceptance coverage echo in Step 5 | Med | Low |
| Improve #6 Tighten description to surface `--review`/agent routing | Low | Low |
| Introduce #3 First-class "Depends on" field + validation | Low | Low |
| Remove #2 Archive-pruning policy | Low | Low |


---

# Skill: msg

## Summary

`msg` is the root menu/router for the msg skill family. It is a two-mode dispatcher: `/msg` runs a category → skill picker via two sequential `AskUserQuestion` calls, while `/msg --help` runs a three-question stage/artifact/output interview and routes to a single skill via a lookup table. The mechanics work, but the menu has ecosystem drift: it lists 14 skills that all exist on disk and are accurately described, but several workflow skills that ship alongside it (`kermit`, `cook`, `ship`, the `agent-*` family) are handled inconsistently. `ship` appears in the happy-path narrative but is missing from the Skills table and both routing protocols, and `kermit`/`cook` are absent entirely despite being part of the documented flow.

## Quality Assessment

### Strengths

- **Output contract is deterministic.** Both protocols end with the same emit format (`SKILL.md:118-122` and `SKILL.md:227-231`): `` /<skill> — <description> `` then "Stop. Do not emit anything else." The router hands control back without improvising a wall of text.
- **The Skills table is accurate against disk.** Every one of the 14 rows (`SKILL.md:18-31`) maps to a real directory under `.claude/skills/`, and the one-line descriptions match each skill's own `description:` frontmatter (verified: docu, eng, improve, handoff, todo, plan*, pre-merge, review, test, msg-init). No phantom entries, no stale rows.
- **The end-to-end happy path (`SKILL.md:35-56`) is useful.** An ASCII pipeline from `/msg-init` through `gh pr create / /handoff`, plus a callout that `/plan` and `/ship` are autonomous shortcuts that "collapse the stages above." A new user gets the mental model in one screen.
- **Two-tier categorisation is sound.** The five categories (Planning, Build & Ship, Review, Delivery, Meta) are coherent groupings and the Step-1 category descriptions (`SKILL.md:65-70`) are clear.
- **`--help` decision table.** The 13-row table (`SKILL.md:201-215`) with an explicit "first row where all conditions hold" + "any = wildcard" + "closest fit" fallback (`SKILL.md:199`) is unambiguous and cheap to execute.
- **Low token cost.** `allowed_tools` is restricted to `AskUserQuestion` only (`SKILL.md:5-6`) and `model: claude-sonnet-4-6` — correct for a thin router. No unnecessary file reads.

### Weaknesses

- **`ship` is missing from the Skills table and both routing protocols.** It is described in the happy-path narrative (`SKILL.md:53`) as a headline autonomous loop, but a user who picks "Build & Ship" in the default protocol (`SKILL.md:18-23` table → Step 2 sources from this table) will never be offered `ship`, and `--help` cannot route to it either. This is the most serious accuracy defect: the menu hides one of the two flagship commands.
- **`kermit` (commit) and `cook` (standards) are absent.** Both exist on disk (global `~/.claude/skills/`) and `kermit` is the successor to `/pre-merge` in the delivery flow (`gh pr create` is named in the happy path at `SKILL.md:54` where `/kermit` belongs). `cook` is consumed by `review`. A router that omits the commit step leaves a hole where users finish a feature.
- **The `agent-*` authoring family and `improve` are inconsistently scoped.** The "Meta" category description (`SKILL.md:70`) promises "Improvement planning, agent design, and skill-level tooling," but the only Meta skill in the table is `improve` (`SKILL.md:31`). "Agent design" points at `agent-plan`/`agent-build`/`agent-audit`/`agent-evaluate`/`agent-fix`, none of which are listed. The category copy writes a check the table doesn't cash.
- **`--help` table has overlapping/unreachable rows and a confusing `improve` placement.** Row `Reviewing | Code or a diff | An engineering plan → improve` (`SKILL.md:211`) routes a code-review-stage user to a skill-improvement planner — `improve` improves skills/workflows, not code, so this is a semantic mismatch. Also, `Reviewing | A PRD or spec | A project spec → plan-tune` (`SKILL.md:210`) duplicates the Planning-stage plan-tune row (`SKILL.md:206`) with no added value.
- **No `--help` row can reach `plan`, `ship`, `test`, `eng`, `msg-init` beyond the first wildcard, or `pre-merge` in the Reviewing stage.** Several real skills are unreachable through the interview. `eng` is reachable only via `Building | A PRD or spec | Working code` (`SKILL.md:208`) but `test` shares the adjacent row; `plan` (the autonomous loop) has no row at all — a user "Planning" from "Nothing yet" wanting "An engineering plan" falls through to closest-fit rather than the `/plan` loop.
- **Default protocol Step 2 is under-specified for category→skill filtering.** It says "sourcing options from the Skills table filtered to the selected category" (`SKILL.md:107`). `AskUserQuestion` options cap at 4; the "Planning" category has 5 skills (msg-init, plan, plan-pm, plan-tune, plan-em) (`SKILL.md:19-23`). The protocol gives no guidance on how to present 5 options in a 4-option widget — a latent runtime failure.
- **Category-name vs. Step-1-label mismatch risk.** Step-1 options are `Planning / Build & Ship / Review / Delivery / Meta` (`SKILL.md:65-70`), which match the table's Category column exactly, but the model must do an exact-string join between the answer and the Category column with no instruction to normalise. Minor, but worth an explicit "match on exact Category string" note.

## Improve (prioritized)

1. **Add `ship` to the Skills table and Build & Ship category.**
   - *Why:* It is a flagship autonomous command named in the happy path but unreachable through either protocol — the menu hides it.
   - *How:* Insert row `| Build & Ship | ship | Autonomous build-and-ship loop — eng build → review loop → pre-merge |` into the table (`SKILL.md:24` area). This makes Build & Ship a 5-skill category, so also add the overflow handling (see item 5). Add a `--help` row `Building | A PRD or spec | Working code or test results → ship` as the autonomous alternative to `eng`, or add a 4th Q to disambiguate "hands-off vs. step-by-step."

2. **Add `kermit` (and decide on `cook`).**
   - *Why:* The delivery flow ends at `gh pr create` (`SKILL.md:54`) with no commit skill, yet `/kermit` is the project's commit tool. Omitting it breaks the end-to-end flow.
   - *How:* Add `| Delivery | kermit | Conventional-commit + CHANGELOG formatter |` to the table and replace the bare `gh pr create` node in the happy path with `/kermit → gh pr create`. For `cook`: it is an internal orchestrator consumed by `review`, not a user-facing entry point — note it as "internal, invoked by review" rather than listing it as a menu option, OR exclude it and add a one-line "Internal skills not shown: cook (standards), shared/refs" footnote so the drift is intentional and documented.

3. **Resolve the "agent design" Meta promise.**
   - *Why:* Category copy (`SKILL.md:70`) advertises agent design but the table offers none, so users selecting Meta get only `improve`.
   - *How:* Either (a) add the agent-authoring entry points (`agent-plan`, `agent-evaluate`, `agent-fix`) as Meta rows if they are meant to be part of this project's surface, or (b) trim the category description to "Improvement planning and skill-level tooling" so it matches the single `improve` row. Pick based on whether `agent-*` are project skills or global tooling.

4. **Fix the two bad `--help` rows.**
   - *Why:* `Reviewing | Code or a diff | An engineering plan → improve` (`SKILL.md:211`) mis-routes code work to a skill-improvement planner; the duplicate plan-tune row (`SKILL.md:210`) is dead weight.
   - *How:* Re-point `SKILL.md:211` to `eng` (revise an engineering plan) or delete it. Remove the duplicate plan-tune row at `SKILL.md:210`. Add a `Planning | Nothing yet/rough idea | An engineering plan → plan` row so the autonomous loop is reachable.

5. **Specify >4-option handling in default Step 2.**
   - *Why:* Planning has 5 skills; `AskUserQuestion` allows max 4 options — current spec (`SKILL.md:107`) will fail at runtime for that category.
   - *How:* Add: "If a category has more than 4 skills, split into a 'core vs. autonomous' sub-question, or present the 4 most-used and add a 5th 'Other (show all)' option." For Planning: group `plan` (autonomous) separately from the 4 staged skills.

6. **Add an explicit exact-match instruction for category join.**
   - *Why:* Step-2 filtering relies on an implicit string join (`SKILL.md:107`).
   - *How:* One line: "Match the user's Step-1 answer against the Category column verbatim."

## Remove

- **Duplicate `--help` plan-tune row (`SKILL.md:210`).** `Reviewing | A PRD or spec | A project spec → plan-tune` is identical to the Planning-stage row at `SKILL.md:206`; it adds no routing value and pads the table.
- **The `improve`-as-code-fixer row (`SKILL.md:211`)** if not re-pointed — it actively mis-routes.
- **Nothing else.** The file is already lean; the happy-path ASCII and both protocols earn their place. Do not cut the happy path.

## Introduce

- **A one-line "What's NOT here" footnote.** List internal/excluded skills (`cook`, `shared/refs`, possibly `wdym`, `agent-*` if global-only) so future drift is visible and intentional rather than an accidental omission. This is the highest-leverage anti-drift mechanism for a router.
- **A `--list` flat mode.** A non-interactive `/msg --list` that prints the Skills table verbatim (no AskUserQuestion). Useful for users/agents that know the menu and want zero-round-trip reference; cheap to add given the table exists.
- **Self-consistency note tying the menu to disk.** A maintenance comment at the bottom: "This table must list every user-facing skill under `.claude/skills/`. When adding a skill, add a row here." Makes the menu's completeness contract explicit and reviewable — targets the `ship`/`kermit` class of drift found here.
- **Workflow-aware routing in `--help`.** A final emitted line that suggests the next skill in the happy path (e.g., after routing to `eng`, append "next: /test → /review"). Turns the router into a workflow guide. Low effort given the happy path already encodes the ordering.

## Priority Ranking

| Recommendation | Impact | Effort |
|----------------|--------|--------|
| Add `ship` to Skills table + both protocols | High | Low |
| Add `kermit`; decide/document `cook` | High | Low |
| Specify >4-option handling in default Step 2 | High | Low |
| Add "What's NOT here" / self-consistency footnote | Med | Low |
| Resolve Meta "agent design" promise vs. table | Med | Low |
| Fix/remove the two bad `--help` rows (210, 211) | Med | Low |
| Make `/plan` reachable in `--help` | Med | Low |
| Introduce `/msg --list` flat mode | Low | Low |
| Workflow-aware "next:" hint after routing | Low | Med |
| Explicit exact-match instruction for category join | Low | Low |


---

# Done

Completed cross-cutting fixes, moved here from the list above.

**X6 — Router drift (msg).** *(done 2026-06-30)* The `/msg` menu omitted `ship` and `kermit` from its table and routing. **Fixed:** added `kermit` to the Skills table under Delivery (`ship` was already present); updated the Delivery category description to mention commits; added a `kermit` row to the `--help` routing table; added a footnote requiring the table to list every user-facing skill. Files: `.claude/skills/msg/SKILL.md`.

**X5 — Dedup gaps (todo).** *(done 2026-06-30)* Re-running `/todo` on the same PRD doubled every task. **Fixed:** added a stable `source` field (`<origin>:<stable-key>`) to every task; `append-tasks.sh` now drops incoming tasks whose `source` already exists and de-duplicates within the batch, reporting the skipped count. Files: `.claude/skills/todo/SKILL.md`, `refs/schema.json`, `refs/parsing-rules.md`, `scripts/append-tasks.sh`. Note: pre-merge's dedup half of the original X5 is gated on the shared finding-schema fix (X1) and is left for that item.

**X1 — Finding schema differs across review / test / pre-merge.** *(done 2026-06-30)* The three skills each defined a different finding shape while claiming compatibility, breaking pre-merge's regression dedup (keyed on an absent `rule` field). **Fixed:** created the canonical `.claude/skills/shared/refs/finding-schema.md` (severity `blocker`/`high`/`medium`/`low` with a legacy-scale mapping table, unified field set, nested evidence, `rule` declared the dedup key); conformed review, test, and pre-merge to it; added the missing `rule`/`category` fields so pre-merge's `(category,file,line,rule)` dedup and `(category,file,rule)` regression keys are satisfiable; removed the false "compatible" claims. Files: `shared/refs/finding-schema.md` (new); `pre-merge/{SKILL.md,refs/finding-schema.md,refs/output-schema.md}`; `test/{SKILL.md,refs/schema.md,refs/modes/functional.md}`; `review/{SKILL.md,refs/schema.md,refs/modes/functional.md}`.

**X2 — PRD frontmatter field-name drift.** *(done 2026-06-30)* plan-em/plan-tune read `tuned:` while plan-pm wrote `product-tuned:`/`eng-tuned:`, and `plan` wrote no status. **Fixed:** standardized on `product-tuned:`/`eng-tuned:`; plan-em's Step 2 gate now reads `product-tuned:` (auto-skips when `yes`); plan-tune stamps `product-tuned`/`eng-tuned` with the date as a Step 4 writeback (runs even with no fixes, forbids re-introducing `tuned:`); `plan` self-writes `status: eng` after stage 3. Files: `plan-em/SKILL.md`, `plan-tune/SKILL.md`, `plan/SKILL.md`.

**X3 — File-location drift, bare-root vs `devkit/`.** *(done 2026-06-30)* Several skills read/wrote bare-root docs and unslugged PRD paths. **Fixed:** msg-init's `template-CLAUDE.md`/`template-README.md` now point at `devkit/` docs and slugged `prd-[n]-[feature-slug]/`; docu's discovery globs target `devkit/*.md` + slugged PRDs (bare-root kept only as an explicit non-msg-repo fallback); plan-pm AHA/ARCHITECTURE reads+writes → `devkit/` (and `rtk` leak removed); plan-em PRD-path literals → resolved `$PRD_DIR` with `n`/`slug` derivation. Files: `msg-init/refs/{template-CLAUDE.md,template-README.md}`; `docu/SKILL.md`; `plan-pm/{SKILL.md,refs/protocol-interview.md,refs/template-prd.md}`; `plan-em/SKILL.md`; `plan-tune/{SKILL.md,refs/tune-product.md}`.

**X4 — PRD content schema mismatch.** *(done 2026-06-30)* plan-pm's PRD had no feature table / IDs / acceptance criteria that plan-tune and plan-em depend on. **Fixed:** added a required §3 "Features & acceptance criteria" table (`| ID | Feature | Acceptance criterion | Dependencies |`) carrying F1/F2 IDs from the interview, renumbered to an 8-section template with all §-refs updated (platform stays §2, now consistent with plan-em); re-calibrated plan-tune Dimensions 1–4 to the real sections, gated every check on "section present" (no more cascading false Criticals), keyed AC checks on §3, and dropped phantom Target-user/Platform-priorities/Metrics checks; fixed the `template-eng-plan.md` path and the summary-table header collision; plan-em's exec table now enumerates from §3's F-IDs. Files: `plan-pm/refs/{template-prd.md,template-feature-table.md}`, `plan-pm/SKILL.md`; `plan-tune/refs/{tune-product.md,tune-eng.md}`, `plan-tune/SKILL.md`; `plan-em/SKILL.md`.

**X7 — ship branch contract (ship ↔ eng).** *(done 2026-06-30)* ship's feature branch got no commits because eng treated `branch` as a PR target and cut its own sub-branches; downstream stages diffed an empty branch. **Fixed:** defined an explicit shared contract — `branch` = the feature branch / commit destination, with a new `commit_mode` field (`direct`, ship's default: build/fix agents commit straight to the feature branch, no sub-branch/PR; `sub-branch`: preserves standalone-human flow); added a post-build non-empty-diff gate in ship that hard-fails before review/test if the branch has no commits. Files: `eng/{SKILL.md,refs/build/protocol.md,refs/plan/template-eng-plan.md}`, `ship/SKILL.md`.
