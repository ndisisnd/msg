# Acceptance Criteria — 19-plan-loop-modes

## Change 1 — Post-completion prompt in plan-pm (non-loop mode)

1. After `plan-pm` finishes and emits its PRD artifact, an `AskUserQuestion` is always emitted with exactly three options: (a) run plan-tune in pm mode, (b) proceed to plan-em, (c) skip.
2. The prompt is not shown when `plan-pm` is invoked with `--loop`; the loop orchestrator takes over flow control instead.
3. Selecting option (a) causes plan-tune to be invoked with pm mode, targeting the just-produced PRD.
4. Selecting option (b) invokes plan-em on the just-produced PRD without running plan-tune first.
5. Selecting option (c) terminates plan-pm with no further action.

## Change 2 — Post-completion prompt in plan-em (non-loop mode)

6. After `plan-em` finishes and emits its eng plan artifact, an `AskUserQuestion` is always emitted with exactly three options: (a) run plan-tune in em mode, (b) run eng --build, (c) skip.
7. The prompt is not shown when plan-em is called from within the `plan-pm --loop` orchestrator.
8. Selecting option (a) invokes plan-tune in em mode on the just-produced eng plan.
9. Selecting option (b) invokes `eng --build` on the just-produced eng plan.
10. Selecting option (c) terminates plan-em with no further action.

## Change 3 — plan-pm --loop orchestration

11. `plan-pm --loop` is a valid invocation; standard `plan-pm` (no flag) is unchanged.
12. The loop runs: plan-pm → plan-tune (pm) → plan-em → plan-tune (em) as a single cycle.
13. After plan-tune (em) completes, the loop attempts to parse a structured pass/fail signal from the plan-tune output.
14. If the signal indicates zero critical/major issues, the loop exits cleanly and reports completion.
15. If the signal is absent or ambiguous, an `AskUserQuestion` is emitted asking whether all critical/major issues are resolved; the user's "yes" exits the loop.
16. If issues remain (signal or user says no), only the steps that still have open issues are re-run (targeted re-run), not the full cycle from plan-pm.
17. Minor issues are explicitly excluded from the loop termination check; the loop exits even when minor issues remain open.
18. The loop never re-runs the full chain from plan-pm unless the user's targeted-re-run decision indicates the pm artifact itself is stale.

## Change 4 — eng --build --loop orchestration

19. `eng --build --loop` is a valid invocation; `eng --build` (no flag) is unchanged.
20. The loop runs: eng → review as a single cycle.
21. Each eng invocation after the first receives both the original PRD and the accumulated review findings from previous cycles.
22. After review completes, the loop attempts to parse a structured pass/fail signal (zero critical/major findings).
23. If the signal indicates zero critical/major issues, the loop exits cleanly.
24. If the signal is absent or ambiguous, an `AskUserQuestion` is emitted asking whether all critical/major issues are resolved.
25. Minor issues are excluded from the loop termination check; the loop exits even when minor issues remain.
26. The loop never exits silently — it always emits a summary of remaining open issues (if any) when it terminates.

## Change 5 — Loop termination logic

27. Plan-tune and review skills emit a detectable pass marker (e.g. `[LOOP: PASS]`) when zero critical/major issues are found, and a fail marker (e.g. `[LOOP: FAIL]`) otherwise.
28. The loop orchestrators check for these markers before falling back to `AskUserQuestion`.
29. Absence of either marker causes the fallback prompt — no silent exit, no infinite loop.

## Change 6 — Targeted re-run in plan-pm --loop

30. After a failed plan-tune (pm) pass, only plan-pm and plan-tune (pm) are re-run; plan-em is not re-run unless plan-em's artifact also has open issues.
31. After a failed plan-tune (em) pass, only plan-em and plan-tune (em) are re-run; plan-pm is not re-run.
32. The step selection logic is documented inline in the loop orchestrator so future maintainers can adjust it.

## Change 7 — Documentation

33. plan-pm's SKILL.md contains a `## Loop mode` section describing: invocation syntax, cycle steps, termination contract, and minor-issue policy.
34. eng's SKILL.md contains a `## Loop mode` section for `--build --loop` with equivalent documentation.
