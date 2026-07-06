---
name: flash-floor
description: The never-relaxed safety floor and common semantics every msg flash mode obeys. Referenced by each skill's refs/flash/mode-flash.md so no flash path re-states or re-implements them.
---

# flash floor

Every `--flash` mode loads its own `refs/flash/mode-flash.md` **instead of** the comprehensive refs and obeys this file. Flash trades execution count (subagents, buckets, gates, interview turns) for speed — **never** correctness or safety.

## Safety floor — never relaxed, any skill, any mode

DB/data/prod-config pauses · breaking-change pauses · branch isolation (`feat/prd-<n>-*`) · never push/merge · secret scan · frontmatter stamps · F-ID stability · PRD §9 ledger · test-fail ticket · pre-merge refusals.

## Common flash semantics

- Auto-proceed at plan/confirm gates (the safety-floor pauses above still fire).
- Cap tool stdout to ~50 lines; write full logs to a file and print its path.
- Emit a summary + artifact path, not a full JSON echo.

## Reuse v2 substrate — do not re-implement

Flash consumes, never re-copies: PRD-digest slices (`scan-prd-digest.py`), the verify prelude (`verify-prelude.md`), flag-based injected cook, the session cache (`session-cache.md`).

## Mode propagation (T3.3)

An orchestrator forwards its **resolved** mode into every `Skill(...)` handoff and `Agent(...)` prompt; a leaf skill never re-reads the pref mid-pipeline.
