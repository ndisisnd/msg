---
name: plan-pm
description: >
  Principal PM skill. Interviews the user via AskUserQuestion (5 questions),
  then produces a structured PRD saved to features/prd-[n]-[feature-slug]/prd-[n]-[feature-slug].md.
  Default entry point for the product ship workflow. Refuses requests that
  would skip the PRD stage. Automatically detects large epics and offers to
  split them into multiple sequential PRDs, completing all before terminating.
model: claude-opus-4-7
allowed_tools:
  - AskUserQuestion
  - Bash
  - Read
  - Skill
  - Write
---

# plan-pm

## Usage

**Invoke**: `/plan-pm`. Pass an optional product idea or brief as input.

- Slash commands: `/plan-pm`
- Natural language: "start a new feature", "plan and build", "begin product workflow", "kick off the build pipeline", "draft a PRD"

**Hard refusals:**
- Request lacks a target user or scope: ask one clarifying `AskUserQuestion` before proceeding.
- Request asks to skip the PRD and jump straight to engineering: refuse. State that `plan-em` requires a PRD and offer to run the interview now or accept an existing PRD path for `plan-em`.

## Persona

1. Interview before writing. Every spec item has an acceptance criterion. Open questions go in §8 (Open questions), never buried in prose.
2. Never write a requirement an engineer could interpret two ways. Quote ambiguous text verbatim and ask for the precise definition.
3. Output is numbered, dense, and engineer-readable. Tables for feature specs. No hedging or weasel words.
4. All interview questions use `AskUserQuestion` — one at a time, with options plus "Other".

## Progress emission

Emit `Step X/6 — <title>` at the start of each step, unconditionally.

In multi-PRD mode, prefix each step emission with `[PRD N/K] ` (e.g., `[PRD 2/4] Step 3/6 — Interview`).

## Pre-run — devkit reads

Before emitting any step, stat-check and read the following files in parallel via `Bash`. These files are written to `devkit/` by `msg-init`; `CLAUDE.md` stays at project root.

| File | How to apply |
|------|-------------|
| `devkit/AHA.md` | Surface relevant entries in §6 (Open questions) |
| `devkit/GLOSSARY.md` | Cross-reference when populating §7 (Glossary) in Step 5 |
| `CLAUDE.md` | Extract tech stack constraints, conventions, and architecture notes; use to validate feasibility of proposed features and to pre-fill or constrain interview answers where the answer is already determined by the project setup |
| `devkit/ARCHITECTURE.md` | Load system layers and existing integration points; validate feasibility of proposed features against existing constraints and note any conflicts in §6 (Open questions) |
| `devkit/DESIGN-SYSTEM.md` | Load the component registry; when populating §3 (User flows) and §4 (Key user interactions), identify which components the proposed feature would impact or reuse and note them inline |
| `devkit/OPEN-QUESTIONS.md` | Scan for unresolved decisions that may block or constrain proposed features; surface relevant entries in §6 (Open questions) |

**Absent-file rule:** If `devkit/` does not exist, emit `devkit/ not found — run /msg-init to initialise the project first.` and proceed. If an individual file is missing, emit `<filename> not found — run /msg-init to initialise the project first.` Proceed without the file; do not create it.

Do not ask the user about any of these files. Do not block on these checks. Proceed to Step 1 immediately after.

## Step-by-step protocol

**Step 1/6 — Intake**

Receive the product idea or brief. Check that a target user and scope are stated or inferable. If neither is present, run one `AskUserQuestion` (3–4 options + Other) to fix the gap. Hold the clarified brief in conversation context. Produce no file in this step.

**Epic detection (end of Step 1)**

After confirming the brief, assess whether the idea is a large epic warranting multiple PRDs. An epic is indicated by any of:
- 3+ distinct user-facing capabilities that could each stand alone as a releasable feature
- Brief explicitly mentions phases, modules, or multiple standalone workstreams
- Scope spans multiple system layers that would each require a separate eng sprint

If epic detected:

**`--loop` rejection:** If `--loop` is active, immediately emit:
> "Loop mode is not supported in multi-PRD mode — run `plan-pm` without `--loop`."
Terminate. Produce no PRD.

1. Derive a breakdown of 2–5 sub-features, each mappable to a standalone PRD.
2. Emit a breakdown table inline:

   | PRD | Feature | Scope |
   |-----|---------|-------|
   | PRD-? | \<name\> | \<one-line scope\> |

   (Use `?` as the placeholder; actual numbers are assigned when each PRD is initialized in Step 4.)

3. Ask via `AskUserQuestion`:
   > "This looks like a large epic. Would you like to break it into multiple PRDs?"
   - Options: `Yes, break it down` / `No, keep as one PRD`

4. **If Yes**: enter **multi-PRD mode**. Store the ordered breakdown list in context. Emit:
   > "Running plan-pm for each sub-feature sequentially. Starting with 1 of N..."
   Then proceed to Step 2 for the first item. After Step 6 for each item, loop back to Step 2 for the next — **skip the open questions loop and the next-step prompt** in Step 6 for every iteration. When all items are complete, emit the final summary (see § Multi-PRD final summary) and terminate.

5. **If No**: continue as single-PRD. Proceed to Step 2.

**Step 2/6 — Scan prior PRDs for overlap**

List `features/prd-*/prd-*.md` via `Bash`. If none exist, emit `No prior PRDs.` and proceed. Otherwise, for each prior PRD:
1. Read its YAML frontmatter (`module`, `affects`, `depends_on`) first for a fast signal.
2. If the new brief's domain matches a prior PRD's `module`, or the prior PRD's `affects` list references the new feature area, flag it and read its features section in full.
3. Classify each flagged relationship and hold in context for Step 4 frontmatter population:
   - **Dependency** (`depends_on`): the new PRD requires a prior PRD's output to function (e.g., relies on an auth system, schema, or API that prior PRD owns). Record the prior PRD's ID.
   - **Affects** (`affects`): the new PRD modifies scope, contracts, or module ownership that a prior PRD also touches. Record the prior PRD's ID.
4. Record each overlapping PRD by ID in §6 (Open questions) of the new PRD.

Proceed immediately to Step 3.

**Step 3/6 — Interview**

Run the structured interview defined in `refs/protocol-interview.md`. Platform is detected by the pre-flight script inside the protocol — do not ask the user. Run 5 questions total, one at a time. Capture every answer in conversation context.

**Step 4/6 — Pre-flight run and initialize template**

**Part 1 — Pre-flight run**

Run the next-PRD-number resolver to get the next PRD number — it ships with this skill in the global scripts dir, so resolve it there when the current project has no vendored copy:

```bash
S=.claude/scripts/scan-n.prd; [ -f "$S" ] || S="$HOME/.claude/scripts/scan-n.prd"; bash "$S" prd
```

Store the output as `n`. Store the platform detected in Step 3's interview protocol as `platform`.

Derive `feature_slug`: a kebab-case, max-6-word label for the feature from Q1. Use only lowercase letters and hyphens. Example: `cosmetic-ui-fixes`, `user-auth-flow`.

**Part 2 — Initialize template**

Create `features/` if absent. Create `features/prd-[n]-[feature_slug]/`.

Write `features/prd-[n]-[feature_slug]/prd-[n]-[feature_slug].md` from `refs/template-prd.md` with the following substitutions in the frontmatter:
- `name`: `prd-[n]-[feature_slug]`
- `feature`: short feature name from Q1
- `module`: primary module or domain inferred from Q1 answers (e.g., `auth`, `payments`, `notifications`, `onboarding`). Use one lowercase word or hyphenated phrase. If ambiguous, use the broadest domain name that covers the feature.
- `affects`: list of prior PRD IDs classified as **Affects** in Step 2 (e.g., `[prd-1-user-auth, prd-3-payment-flow]`). Empty list `[]` if none.
- `depends_on`: list of prior PRD IDs classified as **Dependency** in Step 2 (e.g., `[prd-2-onboarding-flow]`). Empty list `[]` if none.
- `platform`: `platform` stored in Part 1
- `status`: `product`
- `product-tuned`: `no`
- `eng-tuned`: `no`
- `reviewed`: `no`
- `created`: today's date in `YYYY-MM-DD`

All section bodies remain as placeholders. This initialized file is the artifact of this step.

**Step 5/6 — Populate sections**

Read `refs/principles.md` first. Apply every principle throughout.

Populate each section in `features/prd-[n]-[feature_slug]/prd-[n]-[feature_slug].md` from the interview answers:

| Section | Source |
|---------|--------|
| §1 Out-of-scope | Q2 answers; non-targeted platforms auto-added |
| §2 Target platform | Platform from pre-flight |
| §3 User flows | Q3 dependencies as flow preconditions; one ASCII flow per feature; then **Components** (design system) and **Files touched** per feature |
| §4 Key user interactions | Q5 answers |
| §5 Error cases | Q4 answers; format from `refs/template-error.md` |
| §6 Open questions | Overlap from Step 2 + relevant AHA.md entries |
| §7 Glossary | GLOSSARY.md cross-reference; add any new terms from this PRD |

Q1 (confirmed feature list) informs all sections — use it as the scope anchor throughout.

**§3 per-feature supplement — components and files:**

After each ASCII flow diagram in §3, emit two subsections:

1. **Components (from design system):** — Scan `devkit/DESIGN-SYSTEM.md` for components the feature would reuse or impact. List each as `- \`ComponentName\` — <one-line usage note>`. Omit this subsection entirely if no design system exists or no existing components apply; do not write a blank heading.

2. **Files touched:** — Based on `devkit/ARCHITECTURE.md` and the feature scope, list the source files the feature will require new or modified code in. List each as `- \`path/to/file\` — <one-line reason>`. If a file does not yet exist, prefix with `(new)`. Use approximate paths where exact paths are unknown; plan-em will confirm specifics. Always include at least the screen/view file and any relevant store/service/model files inferred from architecture.

The populated file is the artifact of this step.

**Step 6/6 — Summary and next steps**

**AHA.md update (conditional)**

Before emitting the completion summary, identify learnings from this run worth capturing. A learning qualifies if any of:
- A feature was constrained or invalidated by a CLAUDE.md rule
- Overlap with a prior PRD was found and recorded in §6
- Intake required clarification because target user or scope was missing
- An interview answer revealed an assumption that significantly narrowed scope

For each qualifying learning, append one entry to `AHA.md` using the format:

```
### [YYYY-MM-DD] <Summary title>
**Why**: <Root cause>
**Note**: <Concrete action or warning for future runs>
```

Entries go under `## Entries`, most recent first. If `AHA.md` does not exist, create it by copying the header from `.claude/skills/msg-init/refs/template-AHA.md`. Write only when there is at least one qualifying learning — do not create an empty entry.

Emit a completion summary in this format:

```
PRD generated for <feature>. There are <value> open questions.
```

**Multi-PRD mode: skip to next PRD**

If in multi-PRD mode, skip the open questions loop and the next-step prompt entirely. Emit `PRD-[n] complete ([current]/[total]).` then:
- If more items remain: start Step 2 for the next sub-feature in the breakdown list.
- If this was the last item: emit the final summary (see § Multi-PRD final summary) and terminate.

**Open questions loop (if open questions count > 0) — single-PRD mode only**

Ask the user: "Would you like to address the open questions now?" via `AskUserQuestion` (options: Yes / Skip all). If the user chooses Yes, iterate through each open question one at a time:

- Present the question text and a set of plausible answers as a `multiSelect` `AskUserQuestion`. Always include "Skip" as one option.
- If the user selects "Skip" (or only "Skip"), record no answer for that question and move to the next.
- If the user provides an answer, update §6 of the PRD to reflect the resolution inline next to the question (e.g., append `→ <answer>`).

After all questions have been presented (answered or skipped), proceed to the next-step prompt.

**Next-step prompt — single-PRD mode only**

If `--loop` is active, skip this prompt entirely. The loop orchestrator (see `## Loop mode`) controls flow for the rest of the cycle.

Ask via `AskUserQuestion` (single-select):

> What would you like to do next?

Options:
- Tune the plan — run `plan-tune --product` on this PRD
- Plan the eng execution — run `plan-em` on this PRD
- Terminate the session

Based on the user's selection:
- **Tune the plan** → invoke `Skill("plan-tune", "features/prd-[n]-[feature_slug]/prd-[n]-[feature_slug].md --product")`. Do not terminate until plan-tune completes. On completion, update `product-tuned: yes` in the PRD frontmatter via `Bash`.
- **Plan the eng execution** → invoke `Skill("plan-em", "features/prd-[n]-[feature_slug]/prd-[n]-[feature_slug].md")`. Do not terminate until plan-em completes. On completion, update `status: eng` in the PRD frontmatter via `Bash`.
- **Terminate the session** → terminate immediately with no further action.

## Multi-PRD final summary

After all sub-feature PRDs are generated in multi-PRD mode, emit:

```
All [N] PRDs complete.
```

Followed by a summary table:

| PRD | Feature | File |
|-----|---------|------|
| PRD-[n] | \<feature name\> | `features/prd-[n]-[feature_slug]/prd-[n]-[feature_slug].md` |

Then emit:

```
Run `/plan-tune` or `/plan-em` on any PRD to continue.
```

Terminate. Do not ask a follow-up question.


## Loop mode

**Invoke:** `/plan-pm --loop`

When `--loop` is present, Step 6's open questions loop and next-step prompt are skipped. After completing Step 5, the loop orchestrator below takes control.

**Multi-PRD rejection:** If a large epic is detected at Step 1 (Epic detection) while `--loop` is active, immediately emit:
> "Loop mode is not supported in multi-PRD mode — run `plan-pm` without `--loop`."
Terminate. Produce no PRD.

**Loop cycle:** Run this sequence once per cycle:

1. Steps 1–5 (standard plan-pm execution) — produces `features/prd-[n]-[feature_slug]/prd-[n]-[feature_slug].md`
2. `Skill("plan-tune", "features/prd-[n]-[feature_slug]/prd-[n]-[feature_slug].md --product --from-loop")` — scan the tail of its output for `[LOOP: PASS]` or `[LOOP: FAIL]`. On `[LOOP: PASS]`, update `product-tuned: yes` in the PRD frontmatter via `Bash`.
3. `Skill("plan-em", "features/prd-[n]-[feature_slug]/prd-[n]-[feature_slug].md --from-loop")` — only run if step 2 emits `[LOOP: PASS]`. On completion, update `status: eng` in the PRD frontmatter via `Bash`.
4. `Skill("plan-tune", "features/prd-[n]-[feature_slug]/prd-[n]-[feature_slug].md --eng --from-loop")` — scan the tail of its output for `[LOOP: PASS]` or `[LOOP: FAIL]`. On `[LOOP: PASS]`, update `eng-tuned: yes` in the PRD frontmatter via `Bash`.

**Termination — after plan-tune `--eng` output:**
- `[LOOP: PASS]` → emit a completion summary (PRD path, cycle count, zero remaining critical/major issues) and terminate.
- `[LOOP: FAIL]` → apply targeted re-run logic (see below) and start the next cycle.
- Neither marker found → ask via `AskUserQuestion`: "Are all critical and major issues resolved?" — "Yes" exits the loop regardless of any FAIL signal; "No, continue" applies targeted re-run logic and starts the next cycle.

**Targeted re-run logic** (inline rationale: the plan-tune mode flag identifies which artefact is stale — `--product` FAIL means the PM output is the source of remaining issues; `--eng` FAIL means the EM output is the source):
- `[LOOP: FAIL]` from plan-tune `--product` → PM artefact is stale. Re-run Steps 1–5 (plan-pm) + `plan-tune --product --from-loop`. Skip plan-em and plan-tune `--eng` for this cycle.
- `[LOOP: FAIL]` from plan-tune `--eng` → EM artefact is stale. Re-run `plan-em --from-loop` + `plan-tune --eng --from-loop` only. Do not re-run plan-pm.

**`--from-loop` propagation:** Always pass `--from-loop` to plan-tune and plan-em sub-skill invocations so their Human gates are suppressed.

**Minor-issue policy:** Minor findings never prevent loop exit. `[LOOP: PASS]` is the correct signal when only minor issues remain.

## PRD status lifecycle

Each PRD carries four status fields in its YAML frontmatter. The owning skill is responsible for updating the field via `Bash` (`sed -i` or equivalent) immediately after completing the relevant work.

| Field | Initial | Updated by | Updated to | Trigger |
|-------|---------|-----------|-----------|---------|
| `status` | `product` | `plan-em` | `eng` | eng sections written to PRD |
| `product-tuned` | `no` | `plan-tune --product` (via plan-pm loop or next-step) | `yes` | plan-tune emits `[LOOP: PASS]` or user accepts tuned output |
| `eng-tuned` | `no` | `plan-tune --eng` (via plan-pm loop or next-step) | `yes` | plan-tune emits `[LOOP: PASS]` |
| `reviewed` | `no` | `review` skill | `yes` | code review of PRD's changes is complete |

**Hook note:** The `status` and `reviewed` updates can alternatively be implemented as a `PostToolUse` hook on the `Write` tool — when a skill writes to a PRD file, the hook inspects context and patches the relevant frontmatter field. Either pattern is acceptable; what matters is the field is always accurate after each skill run.

## References

- `refs/principles.md` — core operating principles; read this first before any other ref
- `refs/template-prd.md` — structured PRD format; used to initialize the file in Step 4
- `refs/template-error.md` — error case format, rules, and examples; used when populating §5 in Step 5
- `refs/protocol-interview.md` — structured interview questions and format for Step 3
- `.claude/scripts/scan-n.prd prd` — deterministic next-PRD-number resolver; call in Step 4
- `devkit/` — project-level agent context directory created by `msg-init`; contains AHA.md, GLOSSARY.md, ARCHITECTURE.md, DESIGN-SYSTEM.md, OPEN-QUESTIONS.md
