---
name: plan-pm
description: >
  Principal PM skill. Interviews the user via AskUserQuestion (5 questions),
  then produces a structured PRD saved to features/prd-[n]-[feature-slug]/prd-[n]-[feature-slug].md.
  Default entry point for the product ship workflow. Refuses requests that
  would skip the PRD stage. Automatically detects large epics and offers to
  split them into multiple sequential PRDs, completing all before terminating.
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

- Slash commands: `/plan-pm`, `/plan-pm --sub [parent PRD path | number]`
- Natural language: "start a new feature", "plan and build", "begin product workflow", "kick off the build pipeline", "draft a PRD"
- Natural language (**sub-PRD**): "create a sub-PRD", "more changes to PRD 2", "follow-up fixes for this PRD", "spin off a sub-PRD" — route to the `--sub` mode in the § Sub-PRD mode section below.

**Modes:** default (new top-level PRD) and `--sub` (a numbered follow-up nested under an existing parent PRD). When `--sub` is present — as a flag or via a sub-PRD natural-language trigger — read § Sub-PRD mode (`--sub`) first: it changes intake (Step 1), numbering (Step 4 Part 1), the folder/frontmatter written (Step 4 Part 2), and nothing else. All other steps run identically.

**Hard refusals:**
- Request lacks a target user or scope: ask one clarifying `AskUserQuestion` before proceeding.
- Request asks to skip the PRD and jump straight to engineering: refuse. State that `plan-em` requires a PRD and offer to run the interview now or accept an existing PRD path for `plan-em`.

## Persona

1. Interview before writing. Every spec item has an acceptance criterion. Open questions go in the Open questions section, never buried in prose.
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
| `devkit/AHA.md` | Surface relevant entries in the Open questions section |
| `devkit/GLOSSARY.md` | Cross-reference when populating the Glossary section in Step 5 |
| `CLAUDE.md` | Extract tech stack constraints, conventions, and architecture notes; use to validate feasibility of proposed features and to pre-fill or constrain interview answers where the answer is already determined by the project setup |
| `devkit/ARCHITECTURE.md` | Load system layers and existing integration points; validate feasibility of proposed features against existing constraints and note any conflicts in the Open questions section |
| `devkit/DESIGN-SYSTEM.md` | Load the component registry; when populating User flow and Key user interactions, identify which components the proposed feature would impact or reuse and note them inline |
| `devkit/OPEN-QUESTIONS.md` | Scan for unresolved decisions that may block or constrain proposed features; surface relevant entries in the Open questions section |

**Absent-file rule:** If `devkit/` does not exist, emit `devkit/ not found — run /msg-init to initialise the project first.` and proceed. If an individual file is missing, emit `<filename> not found — run /msg-init to initialise the project first.` Proceed without the file; do not create it.

Do not ask the user about any of these files. Do not block on these checks. Proceed to Step 1 immediately after.

## Sub-PRD mode (`--sub`)

A sub-PRD is a numbered follow-up (`prd-<n>.<m>`) that captures additional changes or fixes to an existing parent PRD without opening a new top-level feature or cutting a new branch. It runs the **identical** six-step protocol below — same interview, same population, same tune/eng handoffs — with exactly four deltas, all resolved before Step 1 emits:

**D1 — Resolve the parent PRD (priority order).** Determine the parent before anything else. Try each in turn; stop at the first that resolves:
1. **Explicit** — a PRD path or number passed with `--sub` (e.g. `/plan-pm --sub 2` or `/plan-pm --sub features/prd-2-habit-tracking/prd-2-habit-tracking.md`). Resolve it to the matching `features/prd-<parent-n>-*/` directory. If an explicit value is given but matches no such directory → hard-refuse: `Hard failure: --sub parent '<value>' does not match any features/prd-*/ PRD.` and stop.
2. **Infer from branch** — run `git branch --show-current`; if it matches `feat/prd-<n>-<slug>`, that PRD is the parent (the user is typically already on the parent's branch when asking for follow-up work). Confirm the `features/prd-<n>-<slug>/` directory exists.
3. **Pick from a list** — otherwise, `AskUserQuestion` listing open PRDs (glob `features/prd-*/prd-*.md`, exclude any that are themselves sub-PRDs — i.e. whose id contains a `.`). The user selects the parent. If no top-level PRDs exist at all, hard-refuse: `Hard failure: no parent PRD found for --sub — run /plan-pm to create a top-level PRD first.` and stop.

Store the resolved parent as `parent_id` = `prd-<parent-n>-<parent-slug>`, and read its frontmatter (`feature`, `module`, `platform`) — needed for D3/D4.

**D2 — Pre-seed intake (Step 1).** Skip the "target user or scope missing" clarifying question — the parent supplies both. Pre-seed the brief with `follow-up to prd-<parent-n>-<parent-slug>: <parent feature>` (parent `feature` from its frontmatter) and fold the user's stated follow-up changes into it. Epic detection still runs, but a sub-PRD is by definition a focused follow-up — it will almost never trip; do not force a split.

**D3 — Number and place the sub-PRD (Step 4 Part 1 + 2).** Replace the top-level number resolver with the sub resolver:

```bash
S=.claude/scripts/scan-n.prd; [ -f "$S" ] || S="$HOME/.claude/scripts/scan-n.prd"; bash "$S" sub <parent-n>
```

Store the output as `m` (the minor). Derive `sub_slug` (kebab-case, ≤6 words) from the follow-up scope. Create the sub-PRD **nested inside the parent's folder**, using the full `refs/template-prd.md` structure (not a delta doc):

```
features/prd-<parent-n>-<parent-slug>/prd-<parent-n>.<m>-<sub_slug>/prd-<parent-n>.<m>-<sub_slug>.md
```

**D4 — Frontmatter (Step 4 Part 2).** Same fields as a top-level PRD, with:
- `name`: `prd-<parent-n>.<m>-<sub_slug>`
- `parent`: `prd-<parent-n>-<parent-slug>` — **new field, sub-PRD only.** This is the field `plan-em`/`eng --build` read to resolve the shared branch (a sub-PRD never gets its own branch).
- `module` / `platform`: **default to the parent's values** (read in D1). Overridable only if the interview reveals the sub-PRD's scope genuinely differs — otherwise inherit unchanged.
- All other fields (`status: product`, `product-tuned: no`, `eng-tuned: no`, `reviewed: no`, `created`, `affects`, `depends_on`) exactly as a top-level PRD.

**Lifecycle:** unchanged. A sub-PRD runs the full pipeline with no stage skipped — `plan-pm --sub` (Steps 1–6) → `plan-tune --product` → `plan-em` → `plan-tune --eng` → `eng --build`. Step 6's next-step prompt hands off exactly as for a top-level PRD, using the nested sub-PRD path.

Everywhere the steps below say `features/prd-[n]-[feature_slug]/prd-[n]-[feature_slug].md`, substitute the nested sub-PRD path from D3 when in `--sub` mode.

## Step-by-step protocol

**Step 1/6 — Intake**

Receive the product idea or brief. Check that a target user and scope are stated or inferable. If neither is present, run one `AskUserQuestion` (3–4 options + Other) to fix the gap. Hold the clarified brief in conversation context. Produce no file in this step.

**Epic detection (end of Step 1)**

After confirming the brief, assess whether the idea is a large epic warranting multiple PRDs. An epic is indicated by any of:
- 3+ distinct user-facing capabilities that could each stand alone as a releasable feature
- Brief explicitly mentions phases, modules, or multiple standalone workstreams
- Scope spans multiple system layers that would each require a separate eng sprint

If epic detected:

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
4. Record each overlapping PRD by ID in the Open questions section of the new PRD.

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

Populate each section in `features/prd-[n]-[feature_slug]/prd-[n]-[feature_slug].md` from the interview answers, in the canonical order defined by `refs/template-prd.md`:

| Section | Source |
|---------|--------|
| 1. Product objective | One paragraph stating the user/business goal from the Q1 brief; the outcome that defines success. No feature list, no implementation |
| 2. Out-of-scope | Q2 answers; non-targeted platforms auto-added |
| 3. User flow | Q3 dependencies as flow preconditions; one ASCII flow per feature. User-visible flow only — no engineering detail |
| 4. Key user interactions | Q5 answers |
| 5. Error cases | Q4 answers; format from `refs/template-error.md` |
| 6. Features & acceptance criteria | Confirmed Q1 feature list with its F-IDs from `refs/template-feature-table.md`; one user-goal acceptance criterion per feature derived from its Q5 interaction + Q4 error cases; Dependencies column from Q3. Keep free of engineering detail (no APIs, schemas, components, files) |
| 7. Feature execution table | Leave the `_To be populated by plan-em …_` placeholder from the template — plan-em owns the engineering breakdown |
| 8. Open questions | Overlap from Step 2 + relevant `devkit/AHA.md` entries, written as `\| # \| Question \| Answer \| Status \|` rows (Status = `Open` when unanswered) |
| 9. Plan tune findings | Leave the `_Populated by plan-tune …_` placeholder from the template — plan-tune owns it |
| 10. Glossary | GLOSSARY.md cross-reference; add any new terms from this PRD |
| 11. Todos | Leave the `_Populated by /todo …_` placeholder from the template |

Q1 (confirmed feature list) informs all sections — use it as the scope anchor throughout. Carry every F-ID assigned during the interview (`refs/template-feature-table.md`) into §6 unchanged; downstream `plan-em` keys its execution table (§7) on these IDs.

Platform is captured only in the frontmatter `platform` field (set from Step 3 detection). Do not write a "Target platform" body section — it no longer exists in the template.

**Engineering detail placement:** components (from `devkit/DESIGN-SYSTEM.md`) and files touched (from `devkit/ARCHITECTURE.md`) are engineering detail and belong in §7 Feature execution table, which `plan-em` populates. Do not attach them to the User flow section. In this step, leave §7 as the template placeholder.

The populated file is the artifact of this step.

**Step 6/6 — Summary and next steps**

**AHA.md update (conditional)**

Before emitting the completion summary, identify learnings from this run worth capturing. A learning qualifies if any of:
- A feature was constrained or invalidated by a CLAUDE.md rule
- Overlap with a prior PRD was found and recorded in the Open questions section
- Intake required clarification because target user or scope was missing
- An interview answer revealed an assumption that significantly narrowed scope

For each qualifying learning, append one entry to `devkit/AHA.md` using the format:

```
### [YYYY-MM-DD] <Summary title>
**Why**: <Root cause>
**Note**: <Concrete action or warning for future runs>
```

Entries go under `## Entries`, most recent first. If `devkit/AHA.md` does not exist, create it by copying the header from `.claude/skills/msg-init/refs/template-AHA.md`. Write only when there is at least one qualifying learning — do not create an empty entry.

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
- If the user provides an answer, update the Open questions table row: write the answer into that row's `Answer` cell and set its `Status` to `Addressed`.

After all questions have been presented (answered or skipped), proceed to the next-step prompt.

**Next-step prompt — single-PRD mode only**

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

## PRD status lifecycle

Each PRD carries four status fields in its YAML frontmatter. The owning skill is responsible for updating the field via `Bash` (`sed -i` or equivalent) immediately after completing the relevant work.

| Field | Initial | Updated by | Updated to | Trigger |
|-------|---------|-----------|-----------|---------|
| `status` | `product` | `plan-em` | `eng` | eng sections written to PRD |
| `product-tuned` | `no` | `plan-tune --product` (via next-step prompt) | `yes` | user accepts tuned output |
| `eng-tuned` | `no` | `plan-tune --eng` (via next-step prompt) | `yes` | plan-tune completes |
| `reviewed` | `no` | `review` skill | `yes` | code review of PRD's changes is complete |
## References

- `refs/principles.md` — core operating principles; read this first before any other ref
- `refs/template-prd.md` — structured PRD format; used to initialize the file in Step 4
- `refs/template-error.md` — error case format, rules, and examples; used when populating §6 in Step 5
- `refs/protocol-interview.md` — structured interview questions and format for Step 3
- `.claude/scripts/scan-n.prd prd` — deterministic next-PRD-number resolver; call in Step 4
- `.claude/scripts/scan-n.prd sub <parent-n>` — deterministic next sub-PRD minor resolver; call in Step 4 Part 1 when in `--sub` mode (see § Sub-PRD mode)
- `devkit/` — project-level agent context directory created by `msg-init`; contains AHA.md, GLOSSARY.md, ARCHITECTURE.md, DESIGN-SYSTEM.md, OPEN-QUESTIONS.md
