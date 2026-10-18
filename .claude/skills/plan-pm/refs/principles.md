---
name: plan-pm Principles
description: The rules of thumb plan-pm uses to decide which follow-up questions shape and scope a PRD — keep faith with the intake row, flesh out only what the row lacks, never re-ask what intake settled. The only rule for asking in plan-pm.
type: reference
---

# plan-pm Principles

plan-pm drafts solo. These rules decide the few moments it asks the user anything. They are separate from intake's `principles.md`: intake decides *what* the idea is; plan-pm decides *how much detail* the PRD needs. Heuristics, not a checklist.

1. **The row is settled.** The row's `idea`, `goal`, `type` and `grade` hold what intake inferred and asked. Treat every one of them as answered. Never ask a question the row already answers, in any wording.
2. **Never contradict or widen the row.** Every feature, criterion and error case must serve the row's idea and goal. A draft that would change the scope — a new outcome, a new surface, a different user — stops: tell the user and send them to `/intake --update #<n>` to change the row first. The row stays the single source of truth until the PRD exists.
3. **Flesh out, do not reinvent.** The PRD adds what the row lacks: the feature split, the acceptance criteria, the error and edge cases. Fill these from the row, the devkit context and prior PRDs first.
4. **Ask only when two readings give two different PRDs.** A question is worth asking when the answer changes a feature, a criterion, or what is out of scope. A gap that changes nothing is not a question; a gap you can fill from context is not a question.
5. **Pick the questions yourself, and few of them.** Choose the 1–4 questions that most shape the PRD. Offer your best reading as the first option, marked recommended. Batch them into one `AskUserQuestion` (Step 4). Everything else stays a §5 open question or a `[USER: …]` placeholder.
6. **One problem, one PRD.** When the row turns out to hold two user problems, do not draft both. Stop and send the user to `/intake --update #<n>` to split the row.
7. **Never ask for a number you would have to invent.** A time limit, count or threshold either comes from a source or becomes a `[USER: …]` placeholder with a §5 row. Ask about it in Step 4 only when the criterion cannot be tested without it.
8. **The safety pause is not a question budget.** A breaking change, a data change or a production-config touch always pauses (Step 4), on top of these rules.
