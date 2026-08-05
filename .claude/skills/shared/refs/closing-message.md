---
name: closing-message
description: Cross-skill contract for the closing message that ends EVERY skill run — 🟢/🟡/🔴 protocol, one template, deterministic next steps from the registry
type: reference
---

# Closing message — the last thing every run says

Every skill run — every mode, every verdict, including early refusals and mid-run stops — ends its chat output with the closing message below. It **supplements** each skill's existing output contract (build summary, findings JSON, report writes, terminal emissions) — it never replaces or reorders it. It is the **last chat output** of the run: after the skill's body output, after report/artifact writes, and after any machine emission (pre-merge's verdict JSON stays the final machine emission; this message follows as chat prose). Chat-only: the `/msg --gui` never renders it — the run report remains the GUI's sole source.

## Template

```markdown
🟢 Success! | 🟡 Warning! | 🔴 Fail!

<one line: what this run did and how it ended, plain language>

| What happened | Detail |
|---|---|
| <event/change/check> | <max 1–2 lines> |

**Next steps**
1. <imperative, concrete, copy-pasteable>
```

Emoji are the circle set only — 🟢/🟡/🔴. Never ✅/⚠️/❌ or other variants.

## Protocol rulesets

| Protocol | Fires when | Next-steps ruleset |
|---|---|---|
| 🟢 Success! | Run completed; nothing needs the user's judgment | Exactly 1 step: the registry's next command, or `Nothing to do — you're done.` Never more than 2 steps on green. |
| 🟡 Warning! | Run completed but something needs a human decision: warnings, skipped checks, open questions asked, flagged non-blocking issues | Steps ordered by priority; each step is one decision or one action. Every warning row in the table maps to a numbered step — no orphan warnings. |
| 🔴 Fail! | Verdict fail/block, mid-run stop on a blocker, refusal, deploy error | Step 1 is the exact recovery command with real paths filled in. If the blocker needs the user first (missing credential, dirty tree), step 1 says exactly what to provide or do and the recovery command becomes step 2. |

**Verdict → protocol (deterministic):** `pass` → 🟢 · `pass_with_warnings` / `warn` / `n/a` / early refusal with nothing broken → 🟡 · `fail` / `block` / deploy error / mid-run stop → 🔴. Skills without a formal verdict (plan-pm, plan-em, plan-review, intake, msg): clean completion → 🟢; completed with open questions or skipped inputs → 🟡; could not produce the artifact → 🔴.

## Language rules (all protocols)

- Speak to a product manager first: plain words, no internal jargon in the summary or next steps ("the checks that make sure nothing broke", not "the unit-int bucket"). Technical terms only where the user must type them — commands and paths given verbatim to copy-paste.
- Next steps are imperative and self-contained: action AND object ("Run `/pre-merge` now", "Run a migration to Supabase") — never "see above", "address the issues", or "consider re-running".
- Table rows max 1–2 lines each; beyond ~8 rows, collapse the rest into `…and N more (details above)`. The table summarises — full detail stays in the body output above.
- Anti-fabrication: only events that actually happened this run; unmeasured = omitted, never invented.

## Next-steps registry

Look the step up — never compose it. Fill `<path>`/`<prd>` placeholders from THIS run's actual artifacts. Fail-path commands must match `fix-loop.md` byte-for-byte.

`plan-em` has three rows, one per `$MODE` at Step 4 — pick the row for the wave that just finished. A **large** PRD runs one wave per invocation (`plan`, then `build` on a second call); a **medium** PRD runs the `fused` wave, which plans *and* builds in one invocation and therefore lands on the same next step a build wave does.

| Skill / mode | 🟢 | 🟡 | 🔴 |
|---|---|---|---|
| intake (all modes) | Run `/plan-pm` when ready to turn the backlog into a PRD | Answer the open question(s), then re-run `/intake` | Fix the stated blocker, then re-run `/intake` |
| plan-pm (default / --sub) | Run `/plan-em` now | Resolve each flagged decision in `<prd>`, then run `/plan-em` | Provide the missing input named above, then re-run `/plan-pm` |
| plan-pm --update | Nothing to do — you're done. | Resolve each skipped or placeholder target named above, then re-run `/plan-pm --update <prd>` | Fix the gate failure in `<prd>`, then re-run `/plan-pm --update <prd>` |
| plan-em — plan wave | Run `/plan-em <prd>` again to start the build wave | Approve or edit the flagged rows in `<prd>`, then run `/plan-em <prd>` again for the build wave | Provide the missing input named above, then re-run `/plan-em <prd>` |
| plan-em — fused wave | Run `/pre-merge` now | Decide on each flagged item, then run `/pre-merge` | Provide the missing input named above, then re-run `/plan-em <prd>` (it resumes at the build half) |
| plan-em — build wave | Run `/pre-merge` now | Decide on each flagged item, then run `/pre-merge` | Provide the missing input named above, then re-run `/plan-em <prd>` |
| plan-review (Product / Eng) | Nothing to do — you're done. | Review the flagged tune items, then re-run `/plan-review` if you change them | Fix the stated blocker, then re-run `/plan-review` |
| eng --plan | Run `/eng --build` now | Review the plan's open questions in `<fix-plan path>`, then run `/eng --build` | Fix the stated blocker, then re-run `/eng --plan report=<path>` |
| eng --build | Run `/pre-merge` now | Decide on each flagged item, then run `/pre-merge` | Run `/eng --plan report=<report .json path>` (or `/eng --build report=<path>` to fix directly, per fix-loop.md) |
| pre-merge | Run `/merge --staging` now | Review the warnings in the report, then run `/merge --staging` | Run `/eng --build report=<report .json path>` (or `/eng --plan report=<path>` first, per fix-loop.md) |
| merge --staging | Work through the test checklist above on staging, then reply **approved** | Resolve each flagged item, then re-run `/merge --staging` | Fix the stated blocker, then re-run `/merge --staging` |
| merge --production | Nothing to do — you're done. The release is live. | Watch the flagged platform(s) per the rollback notes above | Follow the failed-ship loop step named above, then re-run `/merge --production` |
| msg (--init / --update / --init-staging) | Run the stage command the pipeline table above points at | Answer the open question(s), then re-run the same `/msg` command | Fix the stated blocker, then re-run the same `/msg` command |
| emulate | Test the build in the window that just opened — stop it with `kill <pid>` when you're done | Test the build anyway, then resolve the flagged item named above before the next run | Fix the stated blocker (the fix line names it), then re-run `/emulate` |
| msg --doctor | Nothing to do — the harness is healthy. | Start a new session to fix the graduated issue(s) in `devkit/DOCTOR.md` — this mode never fixes | Fix the stated blocker, then re-run `/msg --doctor` |

Out of scope: `improve` (local tooling, not part of the pipeline), and msg's pure-emission modes — default picker, `--gui`, `--help` — whose strict output contracts ("Stop. Do not emit anything else." / board render) stay untouched.

## Worked examples

**🟢 — eng --build, pass:**

> 🟢 Success!
>
> Built all 4 features from the task-CRUD plan; every test passes.
>
> | What happened | Detail |
> |---|---|
> | F1–F4 built | Add, edit, delete, and list tasks now work end to end |
> | Tests | 24 of 24 pass |
> | Report | `features/prd-101-task-crud/reports/report-prd-101-3.md` |
>
> **Next steps**
> 1. Run `/pre-merge` now

**🟡 — pre-merge, pass_with_warnings:**

> 🟡 Warning!
>
> All checks that make sure nothing broke came back clean, but 2 items need your call before merging.
>
> | What happened | Detail |
> |---|---|
> | Checks | 6 of 6 buckets ran; all pass |
> | Warning: new dependency | `date-fns` was added — confirm you want it |
> | Warning: no test for F3 | Filtering works by hand but has no automated test |
>
> **Next steps**
> 1. Reply **keep** or **drop** for the `date-fns` dependency
> 2. Reply **accept** to proceed without the F3 test, or **add test** to have it written first
> 3. Then run `/merge --staging`

**🔴 — pre-merge, fail:**

> 🔴 Fail!
>
> 2 checks failed — the login flow breaks when the password field is empty; nothing was merged.
>
> | What happened | Detail |
> |---|---|
> | Checks | 4 of 6 buckets pass; 2 fail on the login form |
> | Issues file | `features/prd-102-auth/reports/report-prd-102-2.json` (2 issues, 1 blocker) |
>
> **Next steps**
> 1. Run `/eng --build report=features/prd-102-auth/reports/report-prd-102-2.json`
