# review — Cook-backed mode: shared Execution contract

The cook-backed semantic modes (Quality, Security, Performance, Migration) share
this contract. Each mode file states only its flags, Stage 0, and mode-specific
inputs; the common semantic-stage mechanics live here.

## Semantic stage — one subagent per mode

Spawn **exactly one** Agent for the whole mode — **not** one per flag. It receives:

- The resolved diff, and the changed files touching the mode's domains.
- **All** of the mode's assembled flags in a single set.
- **Standards payload** — the compiled `/cook` standards for those flags,
  injected by the orchestrator (`SKILL.md` Step 6), which compiles `/cook`
  **once per distinct stack per run** and slices this mode's flags into the
  prompt. The subagent does **not** call `/cook` itself. The payload names each
  rule's source flag, so findings keep per-rule attribution (`source` = the flag).
- Any mode-specific inputs the mode file names (e.g. Quality's rubric amendment
  and `uncovered_changes[]`).

**Standalone fallback:** if the mode runs with no precompiled payload, it compiles
`/cook` **once** for its own flag set — never once per flag.

## Collect

Collect a single `{ verdict, findings[] }` (sub-skill contract: `../schema.md`).
Mode verdict = worst of the subagent's verdict AND any Stage 0 findings.
