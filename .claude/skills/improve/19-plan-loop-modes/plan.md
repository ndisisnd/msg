# Improvement Plan — 19-plan-loop-modes

**Skill:** plan-pm, plan-em, plan-tune, eng
**Change type:** New capability

## Problem

The planning pipeline (plan-pm → plan-tune → plan-em → plan-tune → eng --build → review) currently has no built-in loop or handoff between stages. After each skill completes, the user must manually decide what to run next. There is no way to run the full pipeline automatically and have it iterate until all critical/major issues are resolved. This creates friction for users who want a continuous improvement cycle and leads to dropped handoffs or forgotten plan-tune passes.

Two related gaps:
1. **No post-completion prompts** — after `plan-pm` or `plan-em` finishes, the user sees output but gets no structured nudge toward the natural next step (tune, proceed to next stage, or skip).
2. **No loop mode** — no way to invoke a self-correcting chain that iterates until all critical and major issues clear, without minor issues blocking progress.

## Proposed changes

| # | What | How | Why necessary | Why ignorable | Rank |
|---|------|-----|---------------|---------------|------|
| 1 | Add post-completion `AskUserQuestion` to `plan-pm` | After `plan-pm` emits its PRD, invoke `AskUserQuestion` offering: (a) run `plan-tune` in pm mode, (b) proceed to `plan-em`, (c) skip | Without this, users frequently forget to tune before advancing, producing lower-quality eng plans | Only if caller is the `--loop` orchestrator (skip the prompt in that case) | P1 |
| 2 | Add post-completion `AskUserQuestion` to `plan-em` | After `plan-em` emits its eng plan, invoke `AskUserQuestion` offering: (a) run `plan-tune` in em mode, (b) run `eng --build`, (c) skip | Same reason as #1 — eng plan quality degrades when tune is skipped | Only if caller is the `--loop` orchestrator | P1 |
| 3 | Add `--loop` flag to `plan-pm` that runs the full planning loop | When `plan-pm --loop` is invoked: run plan-pm → plan-tune (pm) → plan-em → plan-tune (em), then evaluate open critical/major issues; re-run only affected steps until all clear or user confirms done | Without loop mode, multi-cycle improvement requires manual re-invocation at each step | Loop mode is opt-in; non-loop users are unaffected | P1 |
| 4 | Add `--loop` flag to `eng --build` that runs the build-review loop | When `eng --build --loop` is invoked (or user indicates building from a PRD): run eng → review; parse review output for critical/major issues; re-run eng with original PRD + review findings until all critical/major clear or user confirms done | Without loop mode, users must manually re-invoke eng and review for each fix cycle | Loop mode is opt-in; standard `eng --build` is unchanged | P1 |
| 5 | Define loop termination logic (shared) | Try to parse plan-tune / review output for a structured pass/fail signal (e.g. a `[PASS]` / `[FAIL]` marker or zero critical/major findings); if signal absent, emit `AskUserQuestion` asking whether critical/major issues are resolved; only minor issues remain as user-discretion | Without a termination contract, loop runs forever or exits prematurely | N/A — termination logic is required for any loop | P1 |
| 6 | Scope targeted re-run logic for `plan-pm --loop` | After each plan-tune pass, identify which step still has open issues (pm vs em artefact); re-run only that step plus its tune pass rather than restarting from plan-pm | Full restart wastes cycles and risks overwriting resolved sections; targeted re-run converges faster | Could simplify to full restart in v1 if targeted identification is ambiguous | P2 |
| 7 | Document `--loop` flags in each skill's SKILL.md | Add a `## Loop mode` section to plan-pm's SKILL.md and eng's SKILL.md describing invocation, cycle behaviour, and how minor issues are treated | Without documentation, users don't know the flag exists | Could be deferred post-launch | P3 |

---

## Exemplar

**Skill:** plan-pm
**Change type:** New capability

### Problem

After `plan-pm` completes, there is no prompt guiding users toward the natural next step (`plan-tune` or `plan-em`). In loop mode there is no mechanism to chain stages and converge on a resolved plan automatically.

### Proposed changes

| # | What | How | Why necessary | Why ignorable | Rank |
|---|------|-----|---------------|---------------|------|
| 1 | Post-completion prompt | Emit `AskUserQuestion` at end of `plan-pm` with three options | Users skip tune, degrading quality | Only in loop mode | P1 |
| 2 | `--loop` orchestration | Parse `--loop` flag; chain plan-pm → plan-tune → plan-em → plan-tune; loop until pass signal or user confirms | No current self-correcting pipeline exists | Opt-in only | P1 |
