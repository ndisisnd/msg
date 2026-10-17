---
name: PRD Template
description: Structured PRD format for plan-pm to populate — seven sections in four categories, with the drafting rules that bind each one
type: reference
---

# PRD Template

Populate every section. Do not delete a section — if a section does not apply, write `N/A` with a one-sentence reason. Emit each section as an **H2** heading in the exact numbered order below (`## 1. …` through `## 7. …`). Do not emit the scaffolding headings on this page (`## File header`) into the PRD — only the seven numbered sections.

The seven sections fall into four categories:

| Category | Sections | Who writes them |
|---|---|---|
| **A · Intent** — why this exists and where it stops | §1 Product objective, §2 Out-of-scope | `plan-pm` |
| **B · Contract** — what ships and what "done" means | §3 Features & acceptance criteria, §4 Error and edge cases | `plan-pm` (the pipeline's load-bearing part) |
| **C · Unresolved** | §5 Open questions | `plan-pm` authors; others amend |
| **D · Reserved** — written downstream, never by `plan-pm` | §6 Feature execution table, §7 Todos | `plan-em`, `eng --plan` |

**Certification findings do not live in the PRD.** `plan-review` writes its audit ledger to `<prd-dir>/reports/review-prd-[n]-[slug].md` and stamps `reviewed: yes` in the frontmatter — the stamp is the gate signal the pipeline reads, the report is the evidence trail. PRDs written before v5.4 carry the findings inline as a `## 7. Plan review findings` section; that stays where it is and is still read, but nothing new is written there.

**Undetermined facts use a `[USER: …]` placeholder.** When a value the PRD needs is genuinely not decidable from the intake row, the devkit context, or the codebase, write it inline as `[USER: what you need decided]` and raise the same question as a §5 Open questions row. Never invent the value, and never leave the slot silently blank — the placeholder is what makes the gap visible to the reader and to `plan-review`.

**Numbers come from a source, or not at all.** A precise value (a time limit, a count, a percentage, a version) may appear only when it cites its source inline — the intake row, the user's answer, or a named file (for example "per devkit/ARCHITECTURE.md"). Otherwise write the observable outcome without a number, or a `[USER: …]` placeholder when the number matters. The worked examples below follow this rule; copy their shape, not their values.

## File header

```markdown
---
name: prd-[n]-[feature_slug]
feature: <short feature name>
summary: <2–3 sentence plain-prose gist on a single line — the core product objective plus the headline features. Shown under the PRD title on the /msg --gui detail page. Derive from §1 Product objective + §3 feature list; no markdown, no line breaks.>
# parent: prd-[n]-[parent_slug]   # sub-PRDs only — omit for top-level PRDs. Resolves the shared feature branch; a sub-PRD never gets its own branch.
deps: []        # prd-[n]-[feature_slug] IDs that must ship before this one
status: backlog # backlog → specced → wip → complete
reviewed: no
created: YYYY-MM-DD
intake: #<n>
---

# PRD-[n]: <Feature Name>
```

**`status` is the lifecycle truth; the lane directory is the location truth.** They answer different questions and neither derives from the other:

| `status` | Meaning | Stamped by |
|---|---|---|
| `backlog` | Drafted, no execution table yet | `plan-pm` at draft time |
| `specced` | Execution table + todos written | `plan-em` once the eng sections land |
| `wip` | Feature branch cut, build under way | `plan-em` at branch cut |
| `complete` | Shipped to production | `merge --production` |

`reviewed: no|yes` is the single certification stamp — `plan-review` sets it to `yes` on a successful run. It replaced the separate `product-tuned` / `eng-tuned` pair when the tune waves fused.

**Platform is not a frontmatter field.** Downstream stages that need it detect it from `devkit/ARCHITECTURE.md` at run time. There is no "Target platform" body section either.

**Overlap between PRDs is read from `deps` + the §3 Dependencies column** — those two are the whole dependency graph. There is no `module` or `affects` field.

**Emit these seven sections, in this order, each as an H2 `## N. Title` heading:**

## 1. Product objective

**Terse bullets — two of them, one line each.** This is the product spec, not an essay and not engineering:

- **Who** — the user or segment this serves.
- **What changes** — what they can do after this ships that they could not before.

No feature list, no implementation, no prose paragraph, no success metric.

**Worked example:**
> - **Who** — active streak-holders who lose a streak to an accidental miss.
> - **What changes** — they can mark yesterday's missed day complete, and their streak continues.

## 2. Out-of-scope

Bulleted list of features or behaviors explicitly excluded. Each item has a one-line reason.

**Worked example:**
- Social sharing of streaks — covered in PRD-4-social-sharing (separate workstream).
- Backfill of historical habits — out of scope; users start from sign-up date.

## 3. Features & acceptance criteria

Every drafted feature gets one row. Every row must have at least one concrete, verifiable acceptance criterion phrased as an observable **user-goal outcome** — no `supports`, `handles`, or other vague verbs. The Dependencies column lists the F-IDs, external services, or data sources this feature requires (from the Step 2 prior-PRD scan + intake grade); use `—` if none.

**F-IDs are sequential and permanent.** `F1`, `F2`, … in order, assigned once and never renumbered — `plan-em` keys its §6 execution table on them, so a renumber silently breaks the pipeline downstream.

**One or more acceptance criteria per feature**, and each one is a single outcome *observable by the user*. "The list loads" is not one; "the new habit row appears on the Home screen as soon as the user saves it" is. A simple feature has one criterion, written as plain text. A complex feature lists each behaviour as its own criterion, never joined with semicolons: label them `AC1`, `AC2`, … in order and put each on its own line inside the one cell, separated by `<br>` (`AC1 … <br>AC2 …`). The F-ID stays one row — never split a feature into `F1.1` sub-rows. These criteria are the contract every downstream stage reads — regression authoring, `plan-review`, and `pre-merge`'s PRD-consistency gate check each one.

**Keep this section free of engineering detail.** Do not name APIs, endpoints, schemas, components, or files here — those map to §6 Feature execution table. Acceptance criteria describe what the *user* observes, not how it is built. The product/engineering boundary is a msg convention: §1–§5 stay user-facing.

This table is the canonical feature list for the pipeline: `plan-em` keys its execution table (§6) on these F-IDs, and `plan-review` audits the acceptance-criterion column. The PRD-id entries in this column are also the source `script-prd-deps-mirror.sh` unions into the frontmatter `deps` array.

| ID | Feature | Acceptance criterion | Dependencies |
|----|---------|----------------------|--------------|

**Worked example:**

| ID | Feature | Acceptance criterion | Dependencies |
|----|---------|----------------------|--------------|
| F1 | Set daily goal | When the user saves a habit with a non-empty name and a frequency, the new habit row appears on the Home screen. | — |
| F2 | Track streak | AC1 The streak goes up by 1 the first time the habit is marked complete on a day, in the user's profile timezone.<br>AC2 The streak resets to 0 after one missed day.<br>AC3 Marking the habit complete a second time on the same day leaves the streak unchanged. | F1 |

## 4. Error and edge cases

Table form, drafted **per feature** from the §3 feature set. One row per user-visible behaviour. Every row requires a user-visible message or behavior.

| ID | Trigger | User-visible behavior |
|----|---------|----------------------|

**How to draft it:** check every §3 feature against `refs/error-checklist.md` — the Tier 1 types always, the Tier 2 types only when their trigger fits the feature. Write a row only for a type that can actually happen in that feature.

**Rules:**

- **This PRD's features only.** Every row traces to a §3 feature. No generic padding: a type that cannot happen in this feature is skipped silently, not written as `N/A`.
- **Likely and user-visible only.** Skip an error the user would never see or that is not likely.
- **One row per behaviour.** When several triggers lead to the same user-visible behaviour, merge them into one row and name every trigger in it.
- **Type label in the ID cell.** Write `E<n> · <Type>`, with the type name from `refs/error-checklist.md` (for example `E1 · Network`). `plan-review` reads the labels to confirm the checklist ran.
- Trigger is a concrete condition, not a category. "Network timeout on save" not "network error."
- User-visible behavior names the exact UI element (toast, banner, inline error) and the copy.
- Never "gracefully handle" — name the specific behavior.
- There is no row quota. Expect about 2–5 rows per feature; a feature with a single real failure mode gets one row, and padding it to hit a count is worse than the short table.

**Worked example:**

| ID | Trigger | User-visible behavior |
|----|---------|----------------------|
| E1 · Network | Network timeout or server error on habit save (F1) | Toast: "Couldn't save. Check your connection and try again." Save button re-enabled. |
| E2 · Permission | Notification permission denied (F1 reminders) | Inline banner: "Enable notifications in Settings to get reminders." No crash. |
| E3 · Invalid input | Empty habit name on submit (F1) | Inline field error: "Name is required." Form not submitted. |
| E4 · Time and date | A completion saved just before midnight syncs after midnight (F2) | The streak counts the day the user tapped, not the day it synced. |

## 5. Open questions

Table of unresolved questions that must be answered before implementation starts. Sources: overlap with prior PRDs (Step 2), unresolved `devkit/AHA.md` entries, any ambiguity the autonomous draft could not resolve (batched back in the Step 4 open-questions pause). `Status` is derived from the `Answer` cell: `Addressed` when an answer is present, `Open` when the `Answer` cell is empty. An empty table (no open questions) is acceptable. `plan-review` recomputes `Status` and keeps this table normalized.

| # | Question | Answer | Status |
|---|----------|--------|--------|

**Worked example:**

| # | Question | Answer | Status |
|---|----------|--------|--------|
| 1 | PRD-2-streak-tracking also handles streak resets — which PRD owns the reset logic? | | Open |
| 2 | Target OS minimum? | Same minimum as the app today, per devkit/ARCHITECTURE.md. | Addressed |

## 6. Feature execution table

**Reserved for `plan-em`.** This is the **one home** for the execution table — `plan-em`'s skeleton renderer writes here, never under a separate `## Execution Table` heading. It maps every F-ID from §3 to its implementation detail: files touched, design-system components, integration contracts, schema changes, and phases. This is the single home for engineering detail — §1–§5 stay user-facing.

Until populated, leave exactly:

```
_To be populated by plan-em — engineering breakdown of the §3 features._
```

Skeleton the eng stage will fill:

| Feature — concern | Files | Agent |
|---------|----------------|-------|-------|-------|

## 7. Todos

**Reserved for `eng --plan`.** Holds the implementation tickets generated for this PRD, grouped by feature as `### F<n>` subsections under one `## Todos — <Agent>` block per agent. These blocks are the build spec **and** the only index to it: a build agent finds its tickets by F-ID here, and §6's Files column is derived from their `files` fields.

Until populated, leave exactly:

```
_Populated by eng --plan — implementation tickets, grouped by feature._
```
