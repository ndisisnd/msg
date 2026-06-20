---
name: plan
description: >
  Autonomous planning loop. Spins up the full PRD pipeline — plan-pm →
  plan-tune --product → plan-em → plan-tune --eng — and loops until the
  engineering tune passes, holding the session continuously and terminating
  only at the very end. Runs hands-off: inter-stage approval gates are
  suppressed; the only interactive pauses are the requirements interview and
  any breaking-change reconciliation. Invoke with /plan. Pass a product idea,
  brief, or nothing.
model: claude-opus-4-7
allowed_tools:
  - Skill
  - AskUserQuestion
  - Bash
  - Read
---

# plan

Autonomous planning loop orchestrator. One command drives the entire product-planning pipeline to a finished, eng-tuned PRD without stopping at each stage boundary.

```
/plan  →  plan-pm  →  plan-tune --product  →  plan-em  →  plan-tune --eng  →  (PASS) terminate
                ↑__________________ loop until [LOOP: PASS] __________________|
```

## Usage

**Invoke**: `/plan`. Pass an optional product idea or brief as input.

- Slash command: `/plan`
- Natural language: "plan this out end to end", "run the full planning loop", "spin up the planning pipeline", "autonomously plan this feature"

This skill is the **autonomous loop entry point** for planning. It owns no protocol of its own — it drives `plan-pm --loop`, which already encodes the four-stage cycle, the targeted re-run logic, and the `[LOOP: PASS]`/`[LOOP: FAIL]` termination contract. `plan` adds the autonomy framing, the permission policy, and a single clean entry/exit.

**Hard refusals:**
- **Multi-PRD epics:** The autonomous loop does not support multi-PRD mode. If the brief is a large epic spanning multiple standalone features, `plan-pm --loop` will reject it. In that case, emit: "This is a multi-PRD epic — run `/plan-pm` (without the loop) to break it into sequential PRDs, then `/ship` each one." Terminate.
- **Skipping the PRD:** `plan` always produces a PRD. It cannot jump straight to engineering build — that is `/ship`.

## Autonomy contract

State this contract to the user before starting, then proceed:

> Running the planning loop autonomously. I will not stop for approval between plan-pm, plan-tune, and plan-em — each runs hands-off. I will only pause to (a) ask you the requirements interview questions, and (b) reconcile any **breaking change** a feature would introduce against an already-planned PRD. I terminate only when the engineering tune reports zero critical/major issues.

## Permission policy

`plan` runs the pipeline **without inter-stage approval gates**. This is enforced by the `--loop` / `--from-loop` contract that the sub-skills already honor:

| Pause type | Suppressed? | Why |
|------------|-------------|-----|
| plan-tune "fix which severities?" gate | **Yes** — auto-selects Critical + Major | `--from-loop` |
| plan-tune / plan-em "what next?" gate | **Yes** — loop orchestrator controls flow | `--from-loop` |
| plan-pm requirements interview | **No** — runs normally | Requirement gathering, not a permission gate |
| plan-em **breaking-change** reconciliation | **No** — always fires | Breaking changes materially affect already-planned work; never auto-approve |
| plan-em roster approval | **No** — fires once | Specialist-agent activation is a material decision |

**Database files** are not written during planning (planning produces markdown PRDs only), so the database-touch guardrail is a no-op here — it lives in `/ship`, where code is written. The breaking-change pause is the one guardrail that applies to planning.

## The loop

Invoke the cycle by delegating to `plan-pm`'s loop mode, which holds the session for the full pipeline:

```
Skill("plan-pm", "<brief> --loop")
```

`plan-pm --loop` runs, per cycle:

1. **plan-pm** (Steps 1–5) — interview + write `features/prd-[n]-[slug]/prd-[n]-[slug].md`
2. **plan-tune** `--product --from-loop` — audit the product PRD; emits `[LOOP: PASS]` / `[LOOP: FAIL]`
3. **plan-em** `--from-loop` — write engineering sections + exec table, then bootstrap the development `eval_set` via `/test --prd` (only if step 2 PASSed)
4. **plan-tune** `--eng --from-loop` — audit the full PRD incl. engineering; emits `[LOOP: PASS]` / `[LOOP: FAIL]`

**Targeted re-runs** (handled inside `plan-pm --loop`):
- `[LOOP: FAIL]` from the **product** tune → re-run plan-pm Steps 1–5 + product tune; skip em + eng tune this cycle.
- `[LOOP: FAIL]` from the **eng** tune → re-run plan-em + eng tune only; do not re-run plan-pm.

The loop continues until the **eng** tune emits `[LOOP: PASS]` (zero critical and major findings remain — minor-only counts as PASS).

## Termination

`plan` terminates only when the loop exits. On exit, emit a single completion summary:

```
Planning loop complete — <cycles> cycle(s).
PRD: features/prd-[n]-[slug]/prd-[n]-[slug].md
Status: eng-tuned, zero critical/major issues remaining.
Suggested next step: /ship features/prd-[n]-[slug]/prd-[n]-[slug].md
```

If the loop exited via the fallback `AskUserQuestion` (no `[LOOP: PASS]` marker found) with unresolved issues, list those issues in the summary — never exit silently.

## References

- `.claude/skills/plan-pm/SKILL.md` — `## Loop mode`: the cycle, targeted re-run logic, `--from-loop` propagation, multi-PRD rejection. `plan` delegates here.
- `.claude/skills/plan-tune/SKILL.md` — `## Loop mode (--from-loop)`: emits `[LOOP: PASS]` / `[LOOP: FAIL]` as its final line.
- `.claude/skills/plan-em/SKILL.md` — breaking-change reconciliation gate (not suppressed) and `--from-loop` synthesis termination.
- `/ship` — the engineering counterpart: builds, reviews, and gates an eng-tuned PRD autonomously.
