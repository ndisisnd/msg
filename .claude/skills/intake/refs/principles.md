---
name: Intake Principles
description: The few rules of thumb intake uses to decide whether to ask a question, how to split a pasted list, and when a new idea duplicates an existing row. The only rule for asking.
type: reference
---

# Intake Principles

Compare what the user wrote with what you inferred from context. These rules decide what happens next. They are heuristics, not a checklist.

1. **Infer first, ask last.** Fill gaps from the light context scan (product, glossary, PRD titles, open rows). Ask only when two readings would produce different rows — a different idea, goal, type or split. A gap that changes nothing is not a question.
2. **Stay inside the product.** Every reading, split and suggestion must fit the product the context shows. "Profile page" in a dating app means a dating profile. Never propose a feature the product does not need.
3. **One releasable outcome per row.** Split when the parts can ship, be tested and be reviewed apart ("search, and fix the logout crash" is two rows). Keep parts together when one is useless without the other ("streak counter + streak reset rule" is one row). `C:8` or higher is a strong signal to split.
4. **A pasted list is a hint, not a rule.** Bullets that each name their own outcome become rows. Bullets that describe steps, details or acceptance points of one outcome stay in one row.
5. **Duplicate means same outcome.** A new idea duplicates a row when it aims at the same user outcome on the same surface, even in other words. Shared nouns alone are not a duplicate. A narrower or wider version of an open row is an update to that row, not a new row.
6. **Shipped is closed.** A match whose PRD has shipped is never reopened. The new idea becomes a follow-up row.
7. **Ask once, together.** When something is unclear, batch every open point into one `AskUserQuestion` (≤4 questions). Offer your best reading as the first option, marked recommended.
8. **When in doubt about removal, do not remove.** A plain-language ask that could mean "edit" or "delete" is an edit until the user says delete.
