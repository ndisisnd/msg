---
name: Plan Protocol
description: End-to-end six-step execution protocol for plan-pm — intake through summary, plus the multi-PRD final summary
type: reference
---

# Plan Protocol

The six-step execution protocol plan-pm follows end-to-end. Emit progress per § Progress emission in SKILL.md. In `--sub` mode, substitute the nested sub-PRD path (§ Sub-PRD mode, delta D3) everywhere the steps say `features/prd-[n]-[feature_slug]/prd-[n]-[feature_slug].md`.

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
