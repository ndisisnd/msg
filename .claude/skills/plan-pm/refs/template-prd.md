---
name: PRD Template
description: Structured PRD format for plan-pm to populate
type: reference
---

# PRD Template

Populate every section. Do not delete a section — if a section does not apply, write `N/A` with a one-sentence reason. Emit each section as an **H2** heading in the exact numbered order below (`## 1. …` through `## 11. …`). Do not emit the scaffolding headings on this page (`## File header`) into the PRD — only the eleven numbered sections.

## File header

```markdown
---
name: prd-[n]-[feature_slug]
feature: <short feature name>
summary: <2–3 sentence plain-prose gist on a single line — the core product objective plus the headline features. Shown under the PRD title on the /msg --gui detail page. Derive from §1 Product objective + §6 feature list; no markdown, no line breaks.>
# parent: prd-[n]-[parent_slug]   # sub-PRDs only — omit for top-level PRDs. Resolves the shared feature branch; a sub-PRD never gets its own branch.
module: <primary module or domain this PRD touches, e.g. auth | payments | notifications>
affects: []   # prd-[n]-[feature_slug] IDs whose scope this PRD overlaps or may break
depends_on: []  # prd-[n]-[feature_slug] IDs that must ship before this one
platform: <detected platform, e.g. mobile | web | backend>
status: product
product-tuned: no
eng-tuned: no
reviewed: no
created: YYYY-MM-DD
---

# PRD-[n]: <Feature Name>
```

`platform` stays in the frontmatter as routing metadata (branch, module inheritance, eng targeting). There is no "Target platform" body section.

**Emit these eleven sections, in this order, each as an H2 `## N. Title` heading:**

## 1. Product objective

One paragraph stating the user or business goal this feature serves — the outcome that defines success. No feature list, no implementation. Answer: *who is this for, and what changes for them when it ships?*

**Worked example:**
> Users who track daily habits abandon the app when they lose a streak by accident. This feature lets them retroactively mark a missed day as complete within a 24-hour grace window, so an honest lapse does not erase weeks of progress — increasing 30-day retention among active streak-holders.

## 2. Out-of-scope

Bulleted list of features or behaviors explicitly excluded. Each item has a one-line reason.

**Worked example:**
- Social sharing of streaks — covered in PRD-4-social-sharing (separate workstream).
- Backfill of historical habits — out of scope; users start from sign-up date.

## 3. User flow

At least one ASCII flow diagram per feature. Each flow must show the happy path from entry point to completion. Use boxes (`[ ]`), arrows (`-->`), and decision diamonds (`< >`). Label every step with the screen name or action. Keep this section about user-visible flow only — engineering detail (files, components, contracts) belongs in §7 Feature execution table.

**Format per feature:**

```
Feature: <feature name>

[Entry point / trigger]
        |
        v
[Screen or step]
        |
        v
< Decision? >
   yes |     | no
       v     v
  [Result A] [Result B]
```

**Worked example:**

```
Feature: Set daily goal

[Home screen — tap "+" button]
        |
        v
[New Habit screen]
  User enters name + frequency
        |
        v
< Name field empty? >
   yes |            | no
       v            v
[Inline error:   [Habit saved to list]
 "Name required"]      |
                       v
               [Home screen — habit
                row appears instantly]
```

## 4. Key user interactions

Bulleted list of the core actions a user can take within this feature. Each item is a single sentence starting with "User can …". Drafted autonomously from the intake row's `idea` + `goal`.

**Worked example:**
- User can add a new habit by entering a name and target frequency.
- User can delete an existing habit from the habit list.
- User can edit a habit's name or frequency after creation.

## 5. Error cases

Format, rules, and examples: see `refs/template-error.md`.

## 6. Features & acceptance criteria

Every drafted feature gets one row, carrying the F-ID assigned in `refs/template-feature-table.md` forward unchanged. Every row must have a concrete, verifiable acceptance criterion phrased as an observable **user-goal outcome** — no `supports`, `handles`, or other vague verbs (see `refs/principles.md`). Derive each acceptance criterion from the feature's §4 key interaction and its §5 error cases. The Dependencies column lists the F-IDs, external services, or data sources this feature requires (from the Step 2 prior-PRD scan + intake grade); use `—` if none.

**Keep this section free of engineering detail.** Do not name APIs, endpoints, schemas, components, or files here — those map to §7 Feature execution table. Acceptance criteria describe what the *user* observes, not how it is built.

This table is the canonical feature list for the pipeline: `plan-em` keys its execution table (§7) on these F-IDs, and `plan-tune --product` audits the acceptance-criterion column.

| ID | Feature | Acceptance criterion | Dependencies |
|----|---------|----------------------|--------------|

**Worked example:**

| ID | Feature | Acceptance criterion | Dependencies |
|----|---------|----------------------|--------------|
| F1 | Set daily goal | When the user saves a habit with a non-empty name and a frequency, the habit row appears on the Home screen within 200ms; an empty name shows the inline error "Name required". | — |
| F2 | Track streak | A habit's streak increments by 1 the first time it is marked complete on a given user-profile-timezone day, and resets to 0 after one missed day. | F1 |

## 7. Feature execution table

**Reserved for the engineering breakdown of each feature.** `plan-em` / `eng` populate this section (wiring not yet enabled — leave the placeholder below until it is). It maps every F-ID from §6 to its implementation detail: files touched, design-system components, integration contracts, schema changes, and phases. This is the single home for engineering detail — the product sections above stay user-facing.

Until populated, leave exactly:

```
_To be populated by plan-em — engineering breakdown of the §6 features._
```

Skeleton the eng stage will fill:

| F-ID | Files touched | Components | Contracts / schema | Phase |
|------|---------------|------------|--------------------|-------|

## 8. Open questions

Table of unresolved questions that must be answered before implementation starts. Sources: overlap with prior PRDs (Step 2), unresolved `devkit/AHA.md` entries, any ambiguity the autonomous draft could not resolve (batched back in the Step 4 open-questions pause). `Status` is derived from the `Answer` cell: `Addressed` when an answer is present, `Open` when the `Answer` cell is empty. An empty table (no open questions) is acceptable. `plan-tune` recomputes `Status` and keeps this table normalized.

| # | Question | Answer | Status |
|---|----------|--------|--------|

**Worked example:**

| # | Question | Answer | Status |
|---|----------|--------|--------|
| 1 | PRD-2-streak-tracking also handles streak resets — which PRD owns the reset logic? | | Open |
| 2 | Target OS minimum? | iOS 16.0+, confirmed with design. | Addressed |

## 9. Plan tune findings

**Reserved for `plan-tune`.** Each tune run (`--product` or `--eng`) writes its audit findings here as one growing table — created on the first run, appended to thereafter (never a second section). Columns: `# | Date | Auditor | Severity | What is wrong | Suggested fix | Why it matters | Status`.

Until the first tune run, leave exactly:

```
_Populated by plan-tune (/plan-tune) — audit findings table._
```

## 10. Glossary

Table of domain terms used in this PRD. Cross-reference `GLOSSARY.md`; include any term defined there that appears in this document. Add new terms not yet in `GLOSSARY.md`.

| Term | Definition |
|------|------------|

**Worked example:**

| Term | Definition |
|------|------------|
| Streak | Consecutive days a habit is marked complete. Resets to 0 on a missed day. |
| Habit | A user-defined recurring activity tracked by the app. |

## 11. Todos

**Reserved for `/todo`.** Will list the TODO tickets generated for this PRD, grouped by feature F-ID (wiring not yet enabled — leave the placeholder below until it is).

Until populated, leave exactly:

```
_Populated by /todo — generated implementation tickets, grouped by feature._
```
