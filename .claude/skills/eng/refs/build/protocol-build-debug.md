---
name: eng --build — Debug mode
description: Lazily loaded when a build test fails at verify-green or code errors during implementation. Defines the bounded 3-cycle debug loop and escalation. A plain --build with no failures never loads this.
type: reference
---

# eng --build — Debug mode

Loaded on a failure (see `protocol.md` Work-step 4c/4d and Full-suite gate). Activates when: tests fail at the verify-green phase (step 4d), or code produces a compile/runtime error during implementation (step 4c).

Run the following cycle per failing issue. Apply one change per cycle. Max 3 cycles per issue.

1. **Identify** — record the exact failing assertion or error message.
2. **Isolate** — read the failing test file, its implementation counterpart, and any shared helper, fixture, or module they directly import that the failure points at. Follow the failure, not the whole codebase — do not browse unrelated files.
3. **Hypothesize** — write one specific root-cause sentence.
4. **Fix** — make one targeted change within the failing row's scope only. No refactors outside it.
5. **Verify** — re-run the test or build step.
6. **Log** — append an AHA entry regardless of outcome (see `protocol.md` § AHA.md). If this is the 3rd failed cycle (escalation), tag the entry with `severity: escalated` (see the AHA.md format).

After 3 failed cycles, stop. Emit a structured escalation:

```
Debug escalation — <Row>
Failing assertion: <exact text>
Cycles tried: 3
Hypotheses: (1) <h1>  (2) <h2>  (3) <h3>
Fixes applied: (1) <f1>  (2) <f2>  (3) <f3>
Needed to continue: <what information or change is required>
```

Mark the affected row's Tests column as `❌ Escalated` in the build summary.
