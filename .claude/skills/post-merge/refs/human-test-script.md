---
name: post-merge-human-test-script
description: post-merge --staging Step 5 — derive a plain-language human test script from the shipped PRD's report "How to verify" sections + acceptance criteria, then STOP for a human to test staging.
---

# Step 5 — Emit a human test script, then STOP

Post-merge **never self-certifies staging.** After deploying, it hands a human a
concrete, plain-language script for exercising the deployed staging environment,
then stops and waits. The sign-off (Step 6) only happens after the human returns.

## Derive it from (in priority order)

1. **The shipped PRD's run reports** — the `## How to verify` sections of
   `features/prd-<n>-*/reports/report-*.md` (schema: `../shared/refs/report-schema.md`).
   These are already written in plain, non-technical, step-by-step language
   ("open the app, add a task, refresh — the task is still there"). Prefer the
   most recent report; concatenate distinct steps across reports for this PRD.
2. **The PRD's acceptance criteria** (§6 / "Features & acceptance criteria") —
   for any in-scope feature whose verification isn't already covered by a report
   step, turn its acceptance criterion into a check ("you should be able to …
   and see …").

Do not invent behavior the PRD didn't specify. If neither source yields a
concrete step for a feature, say so plainly rather than fabricating one.

## Shape of the emitted script

- Point it at the **deployed staging target** (the URL / build from `refs/deploy.md`), not localhost.
- Numbered steps, each = an action + the expected observation, in everyday language.
- End with the sign-off prompt framing: "When you've checked these on staging, come back and tell post-merge whether it works."

## Then STOP

Emit the script as the run's visible output and **halt the autonomous flow** —
do not proceed to Step 6, do not stamp anything. The human runs the script; when
they return, Step 6's `AskUserQuestion` records their verdict.

The same script is written verbatim into the staging run report's `## How to
verify` section so the GUI Reports tab surfaces it (H4).
