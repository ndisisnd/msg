---
name: post-merge-human-test-script
description: post-merge --staging Step 6 — render the plain-language human test script by CONSUMING pre-merge's structured, significance-rated manual-test-plan artifact (C22/AC-MTP6, the 2nd render site — HIGH first), with a graceful fallback to deriving it from the report "How to verify" prose + acceptance criteria when the artifact is absent (older PRDs), then STOP for a human to test staging.
---

# Step 6 — Emit a human test script, then STOP

Post-merge **never self-certifies staging.** After deploying and passing the
smoke verification (Step 5, `refs/verify-deploy.md` — a smoke failure skips this
step entirely), it hands a human a concrete, plain-language script for exercising
the deployed staging environment, then stops and waits. The sign-off (Step 7)
only happens after the human returns.

## Source the list (structured artifact first, prose fallback)

Prefer the **structured, significance-rated manual-test-plan** generated **once** at
pre-merge — do **not** re-derive the list from prose when it exists. This is the same
generate-once checklist the pre-merge preview gate renders (C20/R2); post-merge renders
it as the staging human-test script (C22/AC-MTP6 — the second render site).

1. **The structured manual-test-plan (preferred).** Consume the significance-rated
   checklist produced by `manual-test-plan` (`pre-merge/refs/prd/protocol-manual-test-plan.md`),
   from **either** sink:
   - the machine artifact `.pre-merge/<ts>/manual-test-plan.json` (the most recent one for
     this PRD's shipped branch) — a list of `{ id, kind, significance, step, note }` items,
     already grouped 🔴 HIGH → 🟡 MEDIUM → 🟢 LOW; **or**
   - the shipped run report's **structured** `## How to verify` section
     (`features/prd-<n>-*/reports/report-*.md`, schema `../shared/refs/report-schema.md`) —
     the same significance-rated list rendered into the report.

   Render it **HIGH first** (🔴 → 🟡 → 🟢) so the human walks exactly what automation could
   **not** verify first. Each item is already a plain-language `do X → see Y` step; carry
   its `step` verbatim. An item flagged `step: null` (`note: "no concrete verification step
   in the PRD"`) is **surfaced as such**, never fabricated into a step. This is a **render**
   of the existing artifact, not a re-derivation.

2. **Fallback — prose derivation (artifact absent, older PRDs).** When **no** structured
   manual-test-plan exists (a PRD shipped before C22, or the artifact/structured section is
   missing), gracefully fall back to deriving the list from prose, in priority order:
   a. **The shipped PRD's run reports** — the (prose) `## How to verify` sections of
      `features/prd-<n>-*/reports/report-*.md`, already in plain step-by-step language
      ("open the app, add a task, refresh — the task is still there"). Prefer the most
      recent report; concatenate distinct steps across reports for this PRD.
   b. **The PRD's acceptance criteria** (§6 / "Features & acceptance criteria") — for any
      in-scope feature whose verification isn't already covered by a report step, turn its
      acceptance criterion into a check ("you should be able to … and see …").

Do not invent behavior the PRD didn't specify (in either path). If no source yields a
concrete step for a feature, say so plainly rather than fabricating one.

## Shape of the emitted script

- Point it at the **deployed staging target** (the URL / build from `refs/deploy.md`), not localhost.
- Numbered steps, each = an action + the expected observation, in everyday language.
- End with the sign-off prompt framing: "When you've checked these on staging, come back and tell post-merge whether it works."

## Then STOP

Emit the script as the run's visible output and **halt the autonomous flow** —
do not proceed to Step 7, do not stamp anything. The human runs the script; when
they return, Step 7's `AskUserQuestion` records their verdict.

The same script is written verbatim into the staging run report's `## How to
verify` section so the GUI Reports tab surfaces it (H4).
