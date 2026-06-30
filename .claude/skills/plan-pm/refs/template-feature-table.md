---
name: Feature Table Template
description: Intermediate feature table used during the plan-pm interview to confirm scope before drafting the PRD
type: reference
---

# Feature Table Template

Use this table during Step 2 (Interview) to present the confirmed feature list to the user before the PRD is drafted. Populate one row per feature. Platform defaults to Q1 answer unless a feature is explicitly platform-specific.

| ID | Feature | Description | Platform |
|----|---------|-------------|----------|
| F1 | | | |

**Rules:**
- IDs are sequential: F1, F2, F3, …
- Description is one sentence max — what the feature does, not how.
- Platform column uses the Q1 value unless a specific feature applies to a subset.
- This table is presented inline (not via `AskUserQuestion`). The user reviews it before Q3 runs.
- Acceptance criteria are **not** added here — they belong in PRD §3 (Features & acceptance criteria). Keep this table lightweight.
- The F-IDs assigned here (F1, F2, …) carry forward unchanged into PRD §3. `plan-em` keys its execution table on these same IDs, so they must stay stable from interview to PRD.
