---
name: eng-build-pair-review
description: The per-ticket pair-review subagent — persona, single unnecessary-code mandate, and the one-round blocking contract. Loaded on the build hot path at protocol.md Step 4e. Skipped in flash.
---

# Pair review (per ticket)

Fires after a todo ticket's implementation passes green (`protocol.md` Step 4e) and **before that ticket's commit gate**. One diff-scoped subagent per ticket. **Skipped in flash** (`flash/mode-flash.md` — flash has a single end-of-run commit gate, no per-ticket cadence).

## Persona

Spawn a **principal engineer with 10+ years in the parent agent's platform**, parameterised by the exec-table **Agent** column: `eng-ios` → principal iOS engineer, `eng-backend` → principal backend engineer, `eng-flutter` → principal Flutter engineer; a generic `eng` gets a generic principal engineer. Match the platform to the agent identity.

## Single mandate — unnecessary lines of code

Hunt ONLY for code that shouldn't exist:

- dead code / unreachable branches
- needless abstraction (indirection with one caller, premature generalisation)
- duplicated logic (already present in the diff or the codebase)
- over-engineering (anything beyond the ticket's `done-when`)
- hand-rolled code a stdlib/framework call replaces

It does **NOT** re-review correctness (tests own that), style (lint owns that), or security (pre-merge owns that). Do not comment outside the mandate — a tight prompt keeps this cheap.

Also verify the **plain-English comment convention (A4)**: every new/modified function, module, class, and exported symbol in the diff carries a comment on the line above stating in plain English *what* it does (not how). A missing or how-not-what comment is a finding. (Cheap — the reviewer is already reading the diff.)

## Contract

**Input — injected into the subagent prompt; the reviewer makes NO `/cook` call:**

- the ticket's **diff** (bounded by the ticket-sizing rule to ≤500 changed LOC — the cost is capped)
- the ticket's **`done-when`** (the scope line the reviewer measures over-engineering against)
- the compiled **standards payload** already in the parent's context

**Output — a minimal findings list**, one per line, empty list = clean:

```
<file>:<line> — <what is unnecessary> → <suggested deletion/replacement>
```

## Blocking — exactly one revision round

1. The parent must **resolve** each finding (delete/replace) **or justify** keeping it.
2. Re-spawn the reviewer **once** on the revised diff.
3. After that single round, any still-unresolved finding is logged to the eng section's **§12 Findings — PRD gaps** ledger with the parent's justification —
   `**Minor** — <file:line>: <what is unnecessary>. **Action:** kept — <justification>.` —
   and the ticket proceeds to its commit gate. No second round.
