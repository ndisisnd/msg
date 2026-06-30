---
name: plan
description: >
  One-shot planning orchestrator. Runs the full PRD pipeline once —
  plan-pm → plan-tune --product → plan-em → plan-tune --eng — invoking each
  stage in sequence and stopping at the end. No iteration, no loop. The only
  interactive pauses are the ones each sub-skill owns: the requirements
  interview, roster approval, breaking-change reconciliation, and each stage's
  end-of-run gate. Invoke with /plan. Pass a product idea, brief, or nothing.
model: claude-opus-4-7
allowed_tools:
  - Skill
  - AskUserQuestion
  - Bash
  - Read
---

# plan

One-shot planning orchestrator. One command drives the product-planning pipeline through a finished, eng-tuned PRD in a single linear pass — no loop, no convergence cycle.

```
/plan  →  plan-pm  →  plan-tune --product  →  plan-em  →  plan-tune --eng  →  done
```

`plan` is the planning counterpart to `/ship`. It owns no audit or authoring protocol of its own — it invokes each of the four sub-skills once, in order, via the `Skill` tool, threading the resolved PRD path forward. Each sub-skill runs its own full, unmodified protocol.

## Usage

**Invoke**: `/plan`. Pass an optional product idea or brief as input.

- Slash command: `/plan`
- Natural language: "plan this out end to end", "run the full planning pipeline", "take this idea through to an eng-tuned PRD"

**Hard refusals:**
- **Skipping the PRD:** `plan` always produces a PRD. It cannot jump straight to engineering build — that is `/ship`.

## What `plan` does and does not do

`plan` is a **sequential driver**, not a loop. It runs each stage exactly once and then stops — it does not re-run a stage on findings, and it does not converge on a "zero issues" signal. If a tune surfaces issues you want resolved before building, re-run that stage yourself, or run `/ship` (which has its own review→fix loop) when you build.

It does **not** suppress the sub-skills' interactive gates. There is no `--from-loop` contract anymore. Every pause below is owned by a sub-skill and reaches you normally.

## Stage sequence

Run these four invocations in order. After each returns, read its output, derive the values the next stage needs, and proceed.

1. **plan-pm** — `Skill("plan-pm", "<brief>")`. Runs the requirements interview and writes `features/prd-[n]-[slug]/prd-[n]-[slug].md`. **Capture the resolved PRD path** from plan-pm's output; every later stage takes it as input.
2. **plan-tune --product** — `Skill("plan-tune", "<prd-path> --product")`. Adversarial product audit (completeness, consistency, agent-readability, scope integrity); fixes applied to the PRD in place.
3. **plan-em** — `Skill("plan-em", "<prd-path>")`. Pre-flight, roster approval, writes `## Engineering —` sections + the execution table, and **bootstraps the development `eval_set`** via `/test --prd`.
4. **plan-tune --eng** — `Skill("plan-tune", "<prd-path> --eng")`. Eng-plan audit (the four product dimensions + eng plan integrity); fixes applied in place.

After stage 4 returns, emit the completion summary (below) and terminate.

## Frontmatter status writeback

Because `plan` picks the **terminal** option at every stage gate (see below), it bypasses the sub-skill branches that would otherwise stamp some status fields. Two of the four fields are now self-stamped by their owning stage regardless of the gate choice — `plan-tune --product` writes `product-tuned: <date>` and `plan-tune --eng` writes `eng-tuned: <date>` inside their own Step 4, before their terminal gate — so `plan` must NOT write those itself.

The one field still wired only to a non-terminal branch is `status: eng` (plan-pm writes it only when its gate invokes plan-em, which `plan` suppresses). So after **stage 3 (plan-em)** returns, `plan` patches the PRD frontmatter itself:

```bash
sed -i '' 's/^status: .*/status: eng/' "<prd-path>"
```

This keeps the completion summary's `Status: eng-tuned` claim true at the frontmatter level and lets a downstream `/ship` or plan-em re-entry read accurate state.

## Stage-gate handling (important)

Because `plan` drives the sequence itself and there is no suppression contract, each sub-skill still runs its **own end-of-run prompt**:

| Stage | Its end-of-run prompt | Choose |
|-------|-----------------------|--------|
| plan-pm | "What would you like to do next?" (Tune / Plan eng / Terminate) | **Terminate the session** |
| plan-tune --product | "Continue to plan-em / Re-run plan-pm / Stop here" | **Stop here** |
| plan-em | "Run plan-tune (eng mode) / Run eng --build / Skip" | **Skip** |
| plan-tune --eng | "Proceed to build / Re-run plan-em / Stop here" | **Stop here** |

**Always pick the terminal option** at each gate — `plan` invokes the next stage itself. Picking the "continue/invoke" option would make `plan` run that next stage a second time. (This double-drive is the cost of removing loop mode; the gate is the only place it shows up.)

The genuinely interactive pauses you should answer normally are the ones intrinsic to the work, not the chaining gates:
- **plan-pm requirements interview** — answer the questions.
- **plan-em roster approval** — approve or revise the specialist agents.
- **plan-em breaking-change reconciliation** — fires if a feature collides with an already-planned PRD; never auto-approve.
- **plan-tune fix-severity selection** — pick which severities to fix.

## Multi-PRD epics

`plan` is single-PRD. If plan-pm detects a large epic and enters **multi-PRD mode**, let plan-pm complete all its PRDs, then **stop** — do not run the tune/em stages here. Emit: "plan-pm produced N PRDs. Run `/plan` (or `/plan-em` / `/ship`) on each one individually." `plan` only carries a single PRD through all four stages.

## Termination

On completion, emit a single summary:

```
Planning complete — single pass (no loop).
PRD: features/prd-[n]-[slug]/prd-[n]-[slug].md
Stages run: plan-pm → plan-tune --product → plan-em → plan-tune --eng.
Status: eng-tuned. Unresolved tune findings (if any) are listed above and in the PRD.
Suggested next step: /ship features/prd-[n]-[slug]/prd-[n]-[slug].md
```

If a tune left critical or major findings unresolved (you chose not to fix them), list them in the summary — never exit silently.

## References

- `.claude/skills/plan-pm/SKILL.md` — Stage 1: requirements interview + PRD authoring. `plan` invokes it first.
- `.claude/skills/plan-tune/SKILL.md` — Stages 2 & 4: adversarial product / eng audit. Recommend-only at its Step 5 gate — it never invokes the next skill, which is why `plan` drives sequencing itself.
- `.claude/skills/plan-em/SKILL.md` — Stage 3: engineering sections, execution table, and eval_set bootstrap.
- `/ship` — the engineering counterpart that builds, reviews, and gates the eng-tuned PRD `plan` produces.
