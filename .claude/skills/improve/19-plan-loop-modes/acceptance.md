# Acceptance Criteria — 19-plan-loop-modes

## Change 1 — Upgrade plan-pm next-step prompt from recommend to invoke

1. plan-pm Step 6 already contains a 3-option next-step `AskUserQuestion`; no new prompt is added — the existing prompt is upgraded so that selections trigger actual skill invocations rather than emitting a handoff message and stopping.
2. Selecting "Tune the plan" causes plan-pm to invoke `plan-tune --product` on the just-produced PRD path; plan-pm does not terminate until plan-tune completes.
3. Selecting "Plan the eng execution" causes plan-pm to invoke `plan-em` on the just-produced PRD path; plan-pm does not terminate until plan-em completes.
4. Selecting "Terminate the session" terminates plan-pm with no further action.
5. When `plan-pm` is invoked with `--loop`, Step 6's next-step prompt is skipped entirely; the loop orchestrator (within plan-pm) controls flow for the rest of the cycle.

## Change 2 — Upgrade plan-em Step 5 prompt from 2-option recommend to 3-option invoke

6. plan-em Step 5 already contains a 2-option `AskUserQuestion`; it is upgraded to exactly three options: (a) run plan-tune in eng mode, (b) run `eng --build`, (c) skip.
7. Selecting option (a) causes plan-em to invoke `plan-tune --eng` on the just-produced PRD path; plan-em does not terminate until plan-tune completes.
8. Selecting option (b) invokes `eng --build` on the just-produced PRD path.
9. Selecting option (c) terminates plan-em with no further action.
10. When plan-em is invoked with `--from-loop`, Step 5 is skipped entirely; the loop orchestrator controls flow.

## Change 3 — plan-tune --from-loop suppression

11. plan-tune accepts an optional `--from-loop` flag at invocation.
12. When `--from-loop` is set, plan-tune runs Steps 1–4 unchanged (path resolution, PRD read, audit, fixes) but skips Step 5 (Human gate) entirely.
13. In place of Step 5, plan-tune emits exactly one of the following as its final output line:
    - `[LOOP: PASS]` — zero critical and zero major findings remain after Step 4 fixes.
    - `[LOOP: FAIL]` — one or more critical or major findings remain after Step 4 fixes.
14. Minor-only findings (zero critical, zero major) result in `[LOOP: PASS]`, not `[LOOP: FAIL]`.
15. Standard plan-tune (no `--from-loop`) is unchanged; Step 5 Human gate still fires.

## Change 4 — Add Skill to plan-pm's allowed_tools

16. plan-pm's SKILL.md frontmatter `allowed_tools` list includes `Skill`.
17. No other tool permission changes are required at the plan-pm level; plan-em's tools (Agent, Edit, etc.) run in plan-em's own context when invoked via Skill.

## Change 5 — plan-pm --loop orchestration

18. `plan-pm --loop` is a valid invocation; standard `plan-pm` (no flag) is unchanged.
19. If a multi-PRD epic is detected at plan-pm intake while `--loop` is active, the loop is rejected immediately with the message: "Loop mode is not supported in multi-PRD mode — run `plan-pm` without `--loop`." No PRD is produced.
20. The loop runs in this order as a single cycle: plan-pm → `Skill(plan-tune --product --from-loop)` → `Skill(plan-em --from-loop)` → `Skill(plan-tune --eng --from-loop)`.
21. After each plan-tune invocation, the orchestrator scans the conversation tail for `[LOOP: PASS]` or `[LOOP: FAIL]` as the final output line of that invocation before proceeding.
22. If `[LOOP: PASS]` is found after plan-tune `--eng`, the loop exits cleanly and emits a completion summary.
23. If `[LOOP: FAIL]` is found, targeted re-run logic (Change 8) determines which steps to re-run for the next cycle.
24. If neither marker is found, an `AskUserQuestion` is emitted asking whether all critical/major issues are resolved; the user's "yes" exits the loop regardless of whether a PASS signal was received.
25. Minor issues are excluded from the loop termination check; `[LOOP: PASS]` is the correct signal when only minor issues remain.
26. The loop never re-runs the full chain from plan-pm unless targeted re-run logic (Change 8) identifies the pm artefact as stale.

## Change 6 — eng --build --loop orchestration

27. `eng --build --loop` is a valid invocation; `eng --build` (no flag) is unchanged.
28. The loop runs: eng `--build` → `Skill(plan-tune --eng --from-loop on the PRD)` as a single cycle.
29. "review" in this context is `plan-tune --eng`, not the `/review` skill (which is scoped to code/diff review, not PRD/plan review).
30. After each plan-tune `--eng` invocation, the orchestrator scans for `[LOOP: PASS]` or `[LOOP: FAIL]`.
31. Between cycles, plan-tune findings from each cycle are appended to `features/prd-[n]/.loop-findings.md`; each subsequent eng `--build` invocation receives both the original PRD path and the path to this findings file.
32. If `[LOOP: PASS]` is found, the loop exits cleanly.
33. If `[LOOP: FAIL]` is found or neither marker is found, an `AskUserQuestion` fallback is shown; user "yes" exits the loop.
34. Minor issues are excluded from the loop termination check.
35. The loop never exits silently — it always emits a summary of remaining open issues (if any) when it terminates.

## Change 7 — Loop termination contract

36. plan-tune emits `[LOOP: PASS]` or `[LOOP: FAIL]` as its final output line when invoked with `--from-loop` (see Change 3).
37. `[LOOP: PASS]` means zero critical and zero major findings remain after fixes; minor-only is a PASS.
38. `[LOOP: FAIL]` means one or more critical or major findings remain after fixes.
39. Loop orchestrators scan the tail of the plan-tune invocation output for exactly these tokens before falling back to `AskUserQuestion`.
40. Absence of either marker triggers the fallback prompt — no silent exit, no infinite loop.
41. If `[LOOP: FAIL]` is present AND the user selects "yes, all issues resolved" in the fallback prompt, user intent takes precedence and the loop exits. The FAIL signal does not override an explicit user exit decision.

## Change 8 — Targeted re-run in plan-pm --loop

42. The artefact discriminator is the plan-tune mode flag, not a separate detection step: `--product` FAIL → pm artefact is stale; `--eng` FAIL → em artefact is stale.
43. After a `[LOOP: FAIL]` from plan-tune `--product`: only plan-pm and `plan-tune --product` are re-run; plan-em is not re-run.
44. After a `[LOOP: FAIL]` from plan-tune `--eng`: only plan-em and `plan-tune --eng` are re-run; plan-pm is not re-run.
45. The step selection logic is documented inline in the loop orchestrator so future maintainers can adjust it without re-reading this criteria file.

## Change 9 — Documentation

46. plan-pm's SKILL.md contains a `## Loop mode` section describing: `--loop` invocation syntax, cycle steps, `--from-loop` propagation into sub-skills, `[LOOP: PASS/FAIL]` termination contract, multi-PRD restriction, and minor-issue policy.
47. eng's SKILL.md contains a `## Loop mode` section for `--build --loop` with: cycle steps, the `plan-tune --eng` (not `/review`) clarification, the `.loop-findings.md` file path and format, termination contract, and minor-issue policy.
48. plan-tune's SKILL.md contains a `## Loop mode (--from-loop)` section describing: the `--from-loop` flag, Step 5 suppression, `[LOOP: PASS/FAIL]` output contract, and the minor-only = PASS rule.
