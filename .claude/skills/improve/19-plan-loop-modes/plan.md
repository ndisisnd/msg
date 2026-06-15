# Improvement Plan — 19-plan-loop-modes

**Skill:** plan-pm, plan-em, plan-tune, eng
**Change type:** New capability

## Problem

The planning pipeline (plan-pm → plan-tune → plan-em → plan-tune → eng --build → plan-tune --eng) currently has no built-in loop or automatic handoff between stages. After each skill completes, the user must manually decide what to run next. There is no way to run the full pipeline automatically and have it iterate until all critical/major issues are resolved.

Three related gaps:
1. **Existing prompts recommend but do not invoke** — plan-pm Step 6 and plan-em Step 5 already show next-step `AskUserQuestion` prompts, but both emit a handoff message ("Run X next") and stop. The user must manually run the recommended command. plan-em's prompt also has only two options (run eng tune / skip), missing a direct path to `eng --build`.
2. **No loop mode** — no way to invoke a self-correcting chain that iterates until all critical and major issues clear, without minor issues blocking progress.
3. **No inter-skill suppression mechanism** — each skill's final Human gate fires unconditionally; any loop orchestrator would stall waiting for a user response it shouldn't need.

## Proposed changes

| # | What | How | Why necessary | Why ignorable | Rank |
|---|------|-----|---------------|---------------|------|
| 1 | Upgrade plan-pm's existing next-step prompt from recommend to invoke | plan-pm Step 6 already has a 3-option `AskUserQuestion`; change so selecting "Tune the plan" actually invokes `plan-tune --product` on the PRD, and selecting "Plan the eng execution" actually invokes `plan-em`; suppress the prompt when `--loop` is active | Current prompt terminates after emitting a handoff message; users must copy-paste the slash command manually | Only if caller is the `--loop` orchestrator | P1 |
| 2 | Upgrade plan-em's existing Step 5 prompt from 2-option recommend to 3-option invoke | plan-em Step 5 already has a 2-option `AskUserQuestion`; add a third option "run `eng --build`"; change so each selection actually invokes the corresponding skill; suppress the prompt when `--from-loop` is set | Current prompt offers only 2 options and terminates after a handoff message; no direct path to `eng --build` exists | Only if called with `--from-loop` | P1 |
| 3 | Add `--from-loop` suppression to plan-tune's Step 5 Human gate | When plan-tune is invoked with `--from-loop`, skip Step 5 (Human gate) and emit `[LOOP: PASS]` or `[LOOP: FAIL]` as the final output line based on whether zero critical/major findings remain after Step 4 | plan-tune's Step 5 fires unconditionally; without suppression it stalls any loop orchestrator waiting for a user selection that will never come; this is the only way for an orchestrator to get a programmatic signal from plan-tune | Only in loop mode; standard plan-tune (no flag) is unchanged | P1 |
| 4 | Add `Skill` to plan-pm's `allowed_tools` | Update plan-pm's SKILL.md frontmatter `allowed_tools` list to include `Skill` | plan-pm `--loop` must invoke plan-tune and plan-em as sub-skills via the `Skill` tool; `Skill` is absent from plan-pm's current tool set, making loop orchestration unimplementable as written | N/A — required for loop | P1 |
| 5 | Add `--loop` flag to `plan-pm` that runs the full planning loop | When `plan-pm --loop` is invoked: run plan-pm → `Skill(plan-tune --product --from-loop)` → `Skill(plan-em --from-loop)` → `Skill(plan-tune --eng --from-loop)`; after each plan-tune invocation scan the conversation tail for `[LOOP: PASS]` or `[LOOP: FAIL]` on its final output line; re-run only affected steps (see Change 8) until all clear or user confirms done; if a multi-PRD epic is detected at plan-pm intake, reject `--loop` and emit: "Loop mode is not supported in multi-PRD mode — run `plan-pm` without `--loop`" | Without loop mode, multi-cycle improvement requires manual re-invocation at each step; `--from-loop` is injected into each sub-skill invocation so their Human gates are suppressed | Loop mode is opt-in; non-loop users are unaffected | P1 |
| 6 | Add `--loop` flag to `eng --build` using `plan-tune --eng` as the review step | When `eng --build --loop` is invoked: run eng → `Skill(plan-tune --eng --from-loop)` on the PRD; parse `[LOOP: PASS/FAIL]`; between cycles append plan-tune findings to `features/prd-[n]/.loop-findings.md`; pass this file path alongside the original PRD to each subsequent eng invocation | "review" = `plan-tune --eng`, not the `/review` skill (which is scoped to code/diff review); accumulated findings need a defined file so they survive across cycles — conversation context alone is insufficient across multiple Skill invocations | Loop mode is opt-in; standard `eng --build` is unchanged | P1 |
| 7 | Define loop termination contract (shared) | plan-tune emits `[LOOP: PASS]` (zero critical/major after fixes) or `[LOOP: FAIL]` (one or more remain) as its final output line when invoked with `--from-loop`; loop orchestrators scan conversation tail for these tokens; if neither found, fall back to `AskUserQuestion`; user "yes" always exits the loop even when `[LOOP: FAIL]` is present — user intent overrides the signal | Without a termination contract the loop runs forever or exits prematurely; the tie-break rule is required to avoid trapping users in a loop they want to exit | N/A — required for any loop | P1 |
| 8 | Scope targeted re-run logic for `plan-pm --loop` | After a `[LOOP: FAIL]` from plan-tune `--product`: re-run plan-pm + plan-tune `--product` only; after a `[LOOP: FAIL]` from plan-tune `--eng`: re-run plan-em + plan-tune `--eng` only; document selection logic inline | Full restart wastes cycles and risks overwriting resolved sections; the mode flag (`--product` vs `--eng`) is the artefact discriminator, not a separate detection step | Could simplify to full restart in v1 if targeted identification is ambiguous | P2 |
| 9 | Document `--loop` and `--from-loop` flags in each affected skill's SKILL.md | Add `## Loop mode` to plan-pm's SKILL.md and eng's SKILL.md; add `## Loop mode (--from-loop)` to plan-tune's SKILL.md; cover: invocation syntax, cycle steps, `--from-loop` propagation, `[LOOP: PASS/FAIL]` contract, multi-PRD restriction (plan-pm), `.loop-findings.md` path (eng), and minor-issue policy | Without documentation these flags are invisible; `--from-loop` is an internal API that sub-skills must implement correctly — undocumented flags are unimplementable by future contributors | Cannot be deferred | P2 |

---

## Exemplar

**Skill:** plan-pm
**Change type:** New capability

### Problem

plan-pm Step 6 already shows a 3-option next-step `AskUserQuestion` ("Tune the plan / Plan the eng execution / Terminate the session"), but it terminates after emitting a handoff message rather than invoking the selected skill. In loop mode there is no mechanism to chain stages, suppress sub-skill Human gates, or converge on a resolved plan automatically.

### Proposed changes

| # | What | How | Why necessary | Why ignorable | Rank |
|---|------|-----|---------------|---------------|------|
| 1 | Upgrade existing next-step prompt to invoke | Change Step 6 so that each selection triggers an actual skill invocation rather than a handoff message | Current prompt stops plan-pm; user must manually run the next command | Only in loop mode | P1 |
| 2 | `--loop` orchestration + tool expansion | Parse `--loop` flag; add `Skill` to `allowed_tools`; chain via `Skill(plan-tune --from-loop)` and `Skill(plan-em --from-loop)`; scan for `[LOOP: PASS/FAIL]`; reject in multi-PRD mode | No self-correcting pipeline exists; `Skill` is currently missing from plan-pm's tool set | Opt-in only | P1 |
