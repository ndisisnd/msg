---
name: eng --build — Debug mode
description: Lazily loaded when a build test fails or code errors during implementation. Defines the fix-attempt limit (3 per bug, every layer counted together), the escalation block, and the one AHA entry per bug. A build with no failures never loads this.
type: reference
---

# eng --build — Debug mode

Loaded on a failure: a red test at verify (build loop Step 3c), a compile or runtime error while implementing (Step 3b), a new failure at the full-suite gate (Step 4), or a re-test after review (Step 5). On the `report` source, an issue still red after its fix (`fix-build.md`).

## The limit — 3 attempts per bug

An **attempt** is one fix applied to the bug and then re-verified. **A bug gets at most 3 attempts in one run, counting every layer together**: the first fix on the `report` source, each debug round below, and each coordinator re-entry or re-spawn (`fix-build-orchestrated.md`). When a caller passes `attempts_left=<n>`, that is your budget for this bug — never reset it.

Each round, one change:

1. **Identify** — record the exact failing assertion or error message.
2. **Isolate** — read the failing test, its implementation counterpart, and any helper, fixture or module they import that the failure points at. Follow the failure, not the whole codebase.
3. **Hypothesize** — write one specific root-cause sentence.
4. **Fix** — make one targeted change inside the failing row's or issue's scope. No refactors outside it.
5. **Verify** — re-run the test or build step. Green → the bug is fixed. Red → next round, while attempts remain.

## Escalation — after the last attempt

A bug still failing after its 3rd attempt is **not retried again in this run**. Mark it unresolved and emit the escalation block:

```
Debug escalation — <Row or Issue id>
Failing check: <exact assertion or error>
Attempts: 3
Hypotheses: (1) <h1>  (2) <h2>  (3) <h3>
Fixes tried: (1) <f1>  (2) <f2>  (3) <f3>
Needed to continue: <what information or change is required>
```

- In the build summary, mark the row's Tests cell `❌ Escalated` and list it under **Blocked rows**.
- Tell the user, in the closing message, that this bug needs a **deeper investigation in a separate session**, with what was tried (the block above) and the command to start it. On the `report` source the block is also saved for that session (`fix-build.md` § Escalations).
- Log it to `devkit/OPEN-QUESTIONS.md` (build loop § Learnings and open questions).

## One AHA entry per bug

Write **one** `devkit/AHA.md` entry per bug, once it is fixed or escalated — never one per round. Use `--tag "eng:debug"`. State the outcome in the text: `--note "fixed on attempt 2: <fix>"` or `--note "escalated after 3 attempts: <needed to continue>"`. The AHA writer has no severity field; "escalated" lives in the entry text only. Writer call: build loop § Learnings and open questions.
