---
name: PRD Template
description: Structured PRD format for plan-pm to populate — eight sections in four categories, with the drafting rules that bind each one
type: reference
---

# PRD Template

Populate every section. Do not delete a section — if a section does not apply, write `N/A` with a one-sentence reason. Emit each section as an **H2** heading in the exact numbered order below (`## 1. …` through `## 8. …`). Do not emit the scaffolding headings on this page (`## File header`) into the PRD — only the eight numbered sections.

The eight sections fall into four categories:

| Category | Sections | Who writes them |
|---|---|---|
| **A · Intent** — why this exists and where it stops | §1 Product objective, §2 Out-of-scope | `plan-pm` |
| **B · Contract** — what ships and what "done" means | §3 Features & acceptance criteria, §4 Error cases | `plan-pm` (the pipeline's load-bearing part) |
| **C · Unresolved** | §5 Open questions | `plan-pm` authors; others amend |
| **D · Reserved** — written downstream, never by `plan-pm` | §6 Feature execution table, §7 Plan tune findings, §8 Todos | `plan-em`, `plan-tune`, `eng --plan` |

**Undetermined facts use a `[USER: …]` placeholder.** When a value the PRD needs is genuinely not decidable from the intake row, the devkit context, or the codebase, write it inline as `[USER: what you need decided]` and raise the same question as a §5 Open questions row. Never invent the value, and never leave the slot silently blank — the placeholder is what makes the gap visible to the reader and to `plan-tune`.

## File header

```markdown
---
name: prd-[n]-[feature_slug]
feature: <short feature name>
summary: <2–3 sentence plain-prose gist on a single line — the core product objective plus the headline features. Shown under the PRD title on the /msg --gui detail page. Derive from §1 Product objective + §3 feature list; no markdown, no line breaks.>
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

**Emit these eight sections, in this order, each as an H2 `## N. Title` heading:**

## 1. Product objective

One paragraph stating the user or business goal this feature serves — the outcome that defines success. No feature list, no implementation. Answer: *who is this for, and what changes for them when it ships?*

**Worked example:**
> Users who track daily habits abandon the app when they lose a streak by accident. This feature lets them retroactively mark a missed day as complete within a 24-hour grace window, so an honest lapse does not erase weeks of progress — increasing 30-day retention among active streak-holders.

## 2. Out-of-scope

Bulleted list of features or behaviors explicitly excluded. Each item has a one-line reason.

**Worked example:**
- Social sharing of streaks — covered in PRD-4-social-sharing (separate workstream).
- Backfill of historical habits — out of scope; users start from sign-up date.

## 3. Features & acceptance criteria

Every drafted feature gets one row. Every row must have a concrete, verifiable acceptance criterion phrased as an observable **user-goal outcome** — no `supports`, `handles`, or other vague verbs. The Dependencies column lists the F-IDs, external services, or data sources this feature requires (from the Step 2 prior-PRD scan + intake grade); use `—` if none.

**F-IDs are sequential and permanent.** `F1`, `F2`, … in order, assigned once and never renumbered — `plan-em` keys its §6 execution table on them, so a renumber silently breaks the pipeline downstream.

**Exactly one acceptance criterion per feature**, and it must be *observable by the user*. "The list loads" is not one; "the habit row appears on the Home screen within 200ms of saving" is. This is the single contract every downstream stage reads — regression authoring, `plan-tune --product`, and `pre-merge`'s PRD-consistency gate all key off it.

**Keep this section free of engineering detail.** Do not name APIs, endpoints, schemas, components, or files here — those map to §6 Feature execution table. Acceptance criteria describe what the *user* observes, not how it is built. The product/engineering boundary is a msg convention: §1–§5 stay user-facing.

This table is the canonical feature list for the pipeline: `plan-em` keys its execution table (§6) on these F-IDs, and `plan-tune --product` audits the acceptance-criterion column.

| ID | Feature | Acceptance criterion | Dependencies |
|----|---------|----------------------|--------------|

**Worked example:**

| ID | Feature | Acceptance criterion | Dependencies |
|----|---------|----------------------|--------------|
| F1 | Set daily goal | When the user saves a habit with a non-empty name and a frequency, the habit row appears on the Home screen within 200ms; an empty name shows the inline error "Name required". | — |
| F2 | Track streak | A habit's streak increments by 1 the first time it is marked complete on a given user-profile-timezone day, and resets to 0 after one missed day. | F1 |

## 4. Error cases

Table form, drafted **per feature** from the §3 feature set. One row per error state. Every row requires a user-visible message or behavior.

| ID | Trigger | User-visible behavior |
|----|---------|----------------------|

**Rules:**

- Trigger is a concrete condition, not a category. "Network timeout on save" not "network error."
- User-visible behavior names the exact UI element (toast, banner, inline error) and the copy.
- Never "gracefully handle" — name the specific behavior.
- At least two rows. Drafted autonomously per feature (invalid input, network/permission failures, empty states, auth expiry, external-service failure, rate limits, race conditions, timezone/date boundaries).

**Worked example:**

| ID | Trigger | User-visible behavior |
|----|---------|----------------------|
| E1 | Network timeout on habit save | Toast: "Couldn't save. Check your connection and try again." Save button re-enabled. |
| E2 | Notification permission denied | Inline banner: "Enable notifications in Settings to get reminders." No crash. |
| E3 | Empty habit name on submit | Inline field error: "Name is required." Form not submitted. |

## 5. Open questions

Table of unresolved questions that must be answered before implementation starts. Sources: overlap with prior PRDs (Step 2), unresolved `devkit/AHA.md` entries, any ambiguity the autonomous draft could not resolve (batched back in the Step 4 open-questions pause). `Status` is derived from the `Answer` cell: `Addressed` when an answer is present, `Open` when the `Answer` cell is empty. An empty table (no open questions) is acceptable. `plan-tune` recomputes `Status` and keeps this table normalized.

| # | Question | Answer | Status |
|---|----------|--------|--------|

**Worked example:**

| # | Question | Answer | Status |
|---|----------|--------|--------|
| 1 | PRD-2-streak-tracking also handles streak resets — which PRD owns the reset logic? | | Open |
| 2 | Target OS minimum? | iOS 16.0+, confirmed with design. | Addressed |

## 6. Feature execution table

**Reserved for `plan-em`.** This is the **one home** for the execution table — `plan-em`'s skeleton renderer writes here, never under a separate `## Execution Table` heading. It maps every F-ID from §3 to its implementation detail: files touched, design-system components, integration contracts, schema changes, and phases. This is the single home for engineering detail — §1–§5 stay user-facing.

Until populated, leave exactly:

```
_To be populated by plan-em — engineering breakdown of the §3 features._
```

Skeleton the eng stage will fill:

| Feature | Execution steps | Files | Todos | Agent |
|---------|----------------|-------|-------|-------|

## 7. Plan tune findings

**Reserved for `plan-tune`.** Each tune run (`--product` or `--eng`) writes its audit findings here as one growing table — created on the first run, appended to thereafter (never a second section). Columns: `# | Date | Auditor | Severity | What is wrong | Suggested fix | Why it matters | Status`.

Until the first tune run, leave exactly:

```
_Populated by plan-tune (/plan-tune) — audit findings table._
```

## 8. Todos

**Reserved for `eng --plan`.** Holds the implementation tickets generated for this PRD, grouped by feature as `### F<n>` subsections — the anchor target for `plan-em`'s `[F<n>](#todos-f<n>)` links in §6.

Until populated, leave exactly:

```
_Populated by eng --plan — implementation tickets, grouped by feature._
```
