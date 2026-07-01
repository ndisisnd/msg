---
name: plan
description: >
  One-shot planning orchestrator. Runs the full PRD pipeline once —
  plan-pm → plan-tune --product → plan-em → plan-tune --eng — invoking each
  stage in sequence and stopping at the end. No iteration, no loop. The only
  interactive pauses are the ones each sub-skill owns: the requirements
  interview, roster approval, breaking-change reconciliation, and each stage's
  end-of-run gate — plus, on a clean finish (zero unresolved Critical/Major
  findings), one final approval prompt offering to chain into /ship. Invoke
  with /plan. Pass a product idea, brief, an existing PRD path to resume
  mid-pipeline, or nothing.
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

**Invoke**: `/plan`. Pass an optional product idea or brief as input — or an existing PRD path to resume mid-pipeline (see Resume mode).

- Slash command: `/plan`
- Natural language: "plan this out end to end", "run the full planning pipeline", "take this idea through to an eng-tuned PRD", "finish planning this PRD"

**Hard refusals:**
- **Skipping the PRD:** `plan` always produces a PRD. It cannot jump straight to engineering build — that is `/ship`.

## What `plan` does and does not do

It does not re-run a stage on findings or converge on a "zero issues" signal — if a tune leaves findings you want resolved, re-run that stage yourself, or run `/ship` (which has its own review→fix loop) when you build. It also does not suppress the sub-skills' interactive gates; every pause below is owned by a sub-skill and reaches you normally.

## Stage sequence

Run these four invocations in order. After each returns: read its output, run the Between-stage guard below, emit `Stage N/4 — <name> complete`, derive the values the next stage needs, and proceed.

1. **plan-pm** — `Skill("plan-pm", "<brief>")`. Runs the requirements interview and writes `features/prd-[n]-[slug]/prd-[n]-[slug].md`. **Capture the resolved PRD path** from plan-pm's output; every later stage takes it as input.
2. **plan-tune --product** — `Skill("plan-tune", "<prd-path> --product")`. Adversarial product audit (completeness, consistency, agent-readability, scope integrity); fixes applied to the PRD in place.
3. **plan-em** — `Skill("plan-em", "<prd-path>")`. Pre-flight, roster approval, writes `## Engineering —` sections + the execution table, and **bootstraps the development `eval_set`** via `/test --prd`. **Capture the eval_set assertion count** from its output for the final summary.
4. **plan-tune --eng** — `Skill("plan-tune", "<prd-path> --eng")`. Eng-plan audit (the four product dimensions + eng plan integrity); fixes applied in place.

After stage 4 returns, emit the completion summary (below) and terminate.

## Resume mode

If the input to `/plan` resolves to an existing PRD path rather than a new product idea or brief, do not start at stage 1. Read the PRD's frontmatter and start at the first stage it hasn't passed:

- `product-tuned: no` → start at stage 2 (plan-tune --product)
- `product-tuned: yes`, `status: product` → start at stage 3 (plan-em)
- `status: eng`, `eng-tuned: no` → start at stage 4 (plan-tune --eng)
- `eng-tuned: yes` → nothing left to run; report the PRD is already fully tuned and suggest `/ship <prd-path>`

Run the remaining stages exactly as described above, including the Between-stage guard, breadcrumbs, and frontmatter writeback.

## Between-stage guard

Before invoking each next stage, confirm the prior stage actually met its contract:

- Before stage 2 or stage 4: the PRD file must still exist at the captured path.
- Before stage 4: the PRD must carry `## Engineering —` sections (written by stage 3).
- After stage 3 returns: verify those `## Engineering —` sections are actually present — plan-em can return without writing them if it failed partway.

If the expected artifact from the prior stage is missing, STOP. Do not invoke the next stage. Follow Failure handling below.

## Failure handling

If a stage refuses or aborts instead of completing — e.g. plan-em refuses when `devkit/` is missing (plan-em/SKILL.md:87), or plan-tune refuses on an unresolvable PRD path — do not advance to the next stage. Emit a partial-completion summary naming:

- the last stage that completed successfully
- the stage that failed, and the refusal message it gave
- the suggested manual recovery command (e.g. "resolve `devkit/`, then run `/plan-em <prd-path>` followed by `/plan-tune <prd-path> --eng`")

Never advance past a refusal silently.

## Frontmatter status writeback

Because `plan` picks the **terminal** option at every stage gate (see below), it bypasses the sub-skill branches that would otherwise stamp some status fields. Two of the four fields are now self-stamped by their owning stage regardless of the gate choice — `plan-tune --product` writes `product-tuned: <date>` and `plan-tune --eng` writes `eng-tuned: <date>` inside their own Step 4, before their terminal gate — so `plan` must NOT write those itself.

The one field still wired only to a non-terminal branch is `status: eng` (plan-pm writes it only when its gate invokes plan-em, which `plan` suppresses). So after **stage 3 (plan-em)** returns, `plan` patches the PRD frontmatter itself:

```bash
sed -i '' 's/^status: .*/status: eng/' "<prd-path>"
```

This keeps the completion summary's `Status: eng-tuned` claim true at the frontmatter level and lets a downstream `/ship` or plan-em re-entry read accurate state.

## Stage-gate handling (important)

Because `plan` drives the sequence itself, each sub-skill still runs its **own end-of-run prompt** after finishing. Every one of those prompts offers a "continue to next stage" option alongside a terminal option (worded as Stop / Skip / Terminate depending on the skill). **Always pick the terminal option** — `plan` invokes the next stage itself, so picking "continue" would run that stage a second time.

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
Eval-set: N assertions bootstrapped by plan-em.
Suggested next step: /ship features/prd-[n]-[slug]/prd-[n]-[slug].md
```

If a tune left critical or major findings unresolved (you chose not to fix them), list them in the summary — never exit silently. If the pipeline was entered via Resume mode, list only the stages actually executed under "Stages run."

## End-of-run handoff to `/ship`

After the Termination summary, if the pipeline reached stage 4 (plan-tune --eng) and it left **zero unresolved Critical/Major findings**, ask before chaining into `/ship` — never invoke it unasked:

> `AskUserQuestion`: "PRD is eng-tuned with no unresolved Critical/Major findings. Run `/ship <prd-path>` now?" — **Yes, run /ship** / **No, stop here**.

- **Yes** → `Skill("ship", "<prd-path>")`.
- **No** → terminate as normal.

Skip this prompt entirely (just terminate per Termination above) if: any unresolved Critical/Major findings remain, Failure handling triggered, or Resume mode's `eng-tuned: yes` branch fired (nothing was run this pass).

## References

- `.claude/skills/plan-pm/SKILL.md` — Stage 1: requirements interview + PRD authoring. `plan` invokes it first.
- `.claude/skills/plan-tune/SKILL.md` — Stages 2 & 4: adversarial product / eng audit. Recommend-only at its Step 5 gate — it never invokes the next skill, which is why `plan` drives sequencing itself.
- `.claude/skills/plan-em/SKILL.md` — Stage 3: engineering sections, execution table, and eval_set bootstrap.
- `/ship` — the engineering counterpart that builds, reviews, and gates the eng-tuned PRD `plan` produces.
