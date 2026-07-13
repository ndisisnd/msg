---
name: Feature Table Template
description: Feature table plan-pm builds during autonomous drafting to fix the F-ID feature set before writing the PRD's Features & acceptance criteria section
type: reference
---

# Feature Table Template

Build this table during Step 3 (Autonomous draft) to fix the feature set derived from the intake row's `idea` + `goal` before writing the PRD. Populate one row per feature. Platform defaults to the detected platform unless a feature is explicitly platform-specific.

| ID | Feature | Description | Platform |
|----|---------|-------------|----------|
| F1 | | | |

**Rules:**
- IDs are sequential: F1, F2, F3, …
- Description is one sentence max — what the feature does, not how.
- Platform column uses the detected platform unless a specific feature applies to a subset.
- Acceptance criteria are **not** added here — they belong in the PRD's Features & acceptance criteria section. Keep this table lightweight.
- The F-IDs assigned here (F1, F2, …) carry forward unchanged into the PRD's Features & acceptance criteria section. `plan-em` keys its execution table on these same IDs, so they must stay stable from the draft into §6.
