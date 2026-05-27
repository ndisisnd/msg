# eng — Mode: --plan

Reads the assigned PRD exec-table rows and produces a structured engineering section. **No code is written.**

This file defines the plan-mode specifics only. The shared protocol — input validation, PRD + devkit read, summary + approval gate mechanics, codebase scan, platform + coding standards, scope enforcement, user interview — lives in `SKILL.md`. Read SKILL.md's numbered steps as the spine; the sections below slot into the points it marks as mode-specific.

---

## Input contract (plan-specific)

No fields beyond the shared three (`--plan`, `prd-path`, `rows`).

**Example invocation:**
```
/eng --plan prd-path=features/prd-4/prd-4.md rows="Streaks:Schema-migration Streaks:API-contract"
```

No code is written in this mode. Eng derives all file paths from the codebase scan and exec-table; it does **not** accept file paths as input.

---

## Summary content (Step 3 — Pre-run 1 of 2)

The 3–4 line summary covers:

- Line 1: What is being built — one sentence naming the feature and its user-facing purpose.
- Lines 2–3: How to achieve it in code — the main layers touched and the primary structural change.
- Line 4 (optional): Scope of the assigned rows relative to the full feature.

---

## Output contract (Step 5)

Produce a structured engineering section following `refs/plan/template-eng-plan.md`. **No code is written.** Descriptions only.

Cover only the features implied by the assigned rows. Every section of the template is required — write `None.` only when a subsection genuinely does not apply.

Also fill in the **Execution steps** column for every row in the PRD's Execution Table where the Agent column matches this invocation, following `refs/build/protocol-exec.md` for format, granularity, and dependency notation. A row with a blank Execution steps cell is a hard failure.

**Return contract:** Return the complete engineering section as markdown output. Do not write to the PRD or any other file — the orchestrator (plan-em) appends it to the PRD under `## Engineering — <Agent Name>`. If invoked directly by a user (no orchestrator), emit it inline.

Ambiguity that cannot be resolved from the PRD, exec-table, or codebase scan is surfaced as a named gap in §12 (Findings) — never resolved by assumption.
