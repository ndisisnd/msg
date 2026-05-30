# eng — Mode: --plan

Reads the assigned PRD exec-table rows and produces a structured engineering section. **No code is written.**

This file defines the plan-mode specifics only. The shared protocol — input validation, PRD + devkit read, summary + approval gate mechanics, codebase scan, platform + coding standards, scope enforcement, user interview — lives in `SKILL.md`. Read SKILL.md's numbered steps as the spine; the sections below slot into the points it marks as mode-specific.

---

## Input contract (plan-specific)

No fields beyond the shared three (`--plan`, `prd-path`, `rows`).

**Example invocation:**
```
/eng --plan prd-path=features/prd-4/prd-4.md rows="F2: Track streak — Schema migration; F2: Track streak — API contract"
```

No implementation files are written in this mode. Inline code snippets and pseudocode are permitted — and encouraged — to illustrate proposed changes within the plan document itself. Eng derives all file paths from the codebase scan and exec-table; it does **not** accept file paths as input.

---

## Summary content (Step 3 — Pre-run 1 of 2)

The 3–4 line summary covers:

- Line 1: What is being built — one sentence naming the feature and its user-facing purpose.
- Lines 2–3: How to achieve it in code — the main layers touched and the primary structural change.
- Line 4 (optional): Scope of the assigned rows relative to the full feature.

---

## Output contract (Step 5)

Produce a structured engineering section following `refs/plan/template-eng-plan.md`. No implementation files are written. Inline code snippets and pseudocode are permitted to illustrate proposed changes within the plan document.

Cover only the features implied by the assigned rows. Every section of the template is required — write `None.` only when a subsection genuinely does not apply.

Also fill in the **Execution steps** column for every row in the PRD's Execution Table where the Agent column matches this invocation, following `refs/build/protocol-exec.md` for format, granularity, and dependency notation. A row with a blank Execution steps cell is a hard failure.

**Exact identifier requirement (hard):** Every proposed change must name the precise artifact to be modified or created, verified against the codebase scan:

| Artifact | Required precision |
|----------|--------------------|
| Functions / methods | Exact name as it appears in source (e.g. `createStreak`, not "the streak creation function") |
| DB tables | Exact table name (e.g. `streaks`, not "a streaks table") |
| DB columns | Exact column names and types (e.g. `user_id UUID NOT NULL`) |
| Migration file | Exact filename following repo convention (e.g. `0043_add_streaks.sql`) |
| API endpoints | Exact HTTP method + path matching existing route conventions (e.g. `POST /api/v1/streaks`) |
| API / RPC operation names | Exact operation name as defined in OpenAPI spec or router |

Getting any identifier wrong is a hard failure — build agents execute against them directly and wrong names cause expensive rework. If the exact name cannot be confirmed from the codebase scan, mark it as a named gap in §12 (Findings), not a guess.

**Return contract:** Write the complete engineering section directly to the PRD file at `prd-path`, appended under `## Engineering — <Agent Name>` (the agent identity for this invocation — the literal `— <Agent Name>` suffix is required; `plan-em` detects build mode by this heading). Do not create a separate output file. Emit a one-line confirmation after writing (e.g. `Written to features/prd-4/prd-4.md → ## Engineering — backend-eng`).

Ambiguity that cannot be resolved from the PRD, exec-table, or codebase scan is surfaced as a named gap in §12 (Findings) — never resolved by assumption.
