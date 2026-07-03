# eng — Mode: --todo

Reads the confirmed `## Engineering — <Agent>` section(s) and the PRD's F-ID feature table, then decomposes each owned F-ID's scope into discrete, agent-executable **tickets** (JIRA / Linear-style, minus estimation) written under a `## Todos — <Agent>` heading. **No code is written.**

`--todo` is the middle mode, positioned strictly between `--plan` (design-level document) and `--build` (implementation): design doc → **task breakdown** → build. It runs only after all `--plan` agents have written their engineering sections, and before any `--build` agent runs.

This file defines the todo-mode specifics only. The shared protocol — input validation, PRD + devkit read, summary + approval gate mechanics, codebase scan, scope enforcement, user interview — lives in `SKILL.md`. Read SKILL.md's numbered steps as the spine; the sections below slot into the points it marks as mode-specific. The todo schema itself lives in `refs/todo/template-todo.md` — read it fully before writing any item.

---

## Input contract (todo-specific)

No fields beyond the shared four (`--todo`, `prd-path`, `rows`, `agent`).

**Example invocation:**
```
/eng --todo prd-path=features/prd-4/prd-4.md rows="F2: Track streak — Schema migration; F2: Track streak — API contract" agent=eng-backend
```

**Prerequisite (hard).** This mode reads the confirmed engineering section — it does not re-derive design decisions. Before doing any work, confirm the PRD contains a `## Engineering — <agent>` section for this invocation's `agent`. If no `## Engineering —` section exists at all, this mode has nothing to decompose: emit `Hard failure: --todo requires a confirmed '## Engineering — <agent>' section; none found. Run --plan first.` and stop. No implementation files are written in this mode; `--todo` derives file paths from the engineering section and codebase scan, it does **not** accept file paths as input.

---

## Summary content (Step 3 — Pre-run 1 of 2)

The 3–4 line summary covers:

- Line 1: What is being decomposed — one sentence naming the feature(s) and the owning agent.
- Lines 2–3: How many `### F<n>` blocks will be written and roughly how many tickets across them, and the file surface they touch.
- Line 4 (optional): Any feature whose scope yields no discrete work (will get an explicitly empty block).

---

## Work steps (Step 5)

Use the PRD's `## Engineering — <Agent Name>` section and the PRD's Features & acceptance criteria F-ID table as the joint specification. Do not re-interpret the PRD features section independently of the confirmed engineering section — the engineering section is the authority on *how*; the feature table is the authority on *which F-IDs* are in scope and *why* (the user story / acceptance criteria each F-ID serves).

1. **Read the confirmed engineering section and feature table.** Read this agent's `## Engineering — <Agent Name>` section in full (its integration contracts, exact identifiers, and the Execution steps it filled into the execution table) and the PRD's Features & acceptance criteria F-ID table (each F-ID's user story and acceptance criteria). The set of F-IDs to decompose is exactly those assigned to this invocation via `rows`.

2. **Decompose each owned F-ID into tickets.** For each F-ID in scope, walk its engineering-section scope and execution-table rows and group the changes into **tickets** — each a coherent unit of work — following the `refs/todo/template-todo.md` schema. For each ticket fill every field:
   - **`id`** — `F<n>-T<k>`, numbered 1-based within the feature.
   - **`title`** — a one-line summary of the work.
   - **`objective`** — the user/product goal it serves, traced to the F-ID's §3 user story or acceptance criterion. This is the ticket's "why"; do not leave it mechanical.
   - **`type`** — `code | test | config | migration | doc`.
   - **`priority`** — `P0` (blocks the feature) / `P1` (core) / `P2` (nice-to-have). Not an estimate.
   - **`files`** — the file(s) the ticket touches, each tagged with its action (`add | edit | remove`). Every exact identifier named in the engineering section (endpoint, table, column, migration filename, test file, webhook/hook) that this agent owns must surface in some ticket's `files` + `done-when`.
   - **`depends-on`** — the ticket id(s) that must land first (e.g. an endpoint ticket depends on its migration ticket), or `none`. Reference only ids that exist in this PRD's `## Todos`; keep the graph acyclic.
   - **`done-when`** — a concrete, verifiable acceptance check. Never vague.

   Group files that must change together to deliver one objective into one ticket; split into separate tickets when objectives, dependencies, or acceptance checks differ.

3. **Write the tickets under `## Todos — <Agent>`.** Append this agent's `## Todos — <Agent Name>` sub-heading (the literal `— <Agent Name>` suffix is required; `plan-em` detects the todo phase's completeness by this heading) under the `## Todos` umbrella section (created by `plan-em` before dispatch — do **not** create the umbrella yourself; append beneath it). Under the agent heading, write one `### F<n>` block per owned feature, in F-ID order, each listing that feature's tickets. Write the section directly to the PRD file at `prd-path` — do not create a separate output file. Emit a one-line confirmation after writing (e.g. `Written to features/prd-4/prd-4.md → ## Todos — eng-backend (F2: 3 tickets)`).

4. **Self-consistency check (tickets ↔ exec table ↔ dependencies).** Before returning, cross-check that: every `### F<n>` you wrote corresponds to an execution-table F-ID this agent owns and vice versa; every id in a ticket's `depends-on` resolves to a real ticket id in this PRD's `## Todos`; and the dependency graph is acyclic. A `### F<n>` with no matching execution-table row, an owned F-ID with no `### F<n>` block, or a dangling / cyclic `depends-on` is a coverage gap — surface it as a named gap (do not silently drop it); the execution table's Todos-column anchor (`#todos-f<n>`) and the build phase's dependency ordering both rely on these holding.

---

## Edge & error handling

- **Feature with no discrete work** → write an explicitly empty `### F<n>` block (`_No discrete work for this feature._`), never a missing one, so the execution table's `#todos-f<n>` anchor still resolves.
- **Dangling or cyclic `depends-on`** → surface as a coverage gap (step 4); do not write a ticket whose dependency can't be resolved.
- **Multiple agents** → each writes its own `## Todos — <Agent>` block under the shared `## Todos` umbrella; the todo phase is complete only once every agent that has an engineering section also has a `## Todos —` block.
- **Single agent / single feature** → a single `## Todos — <Agent>` block containing a single `### F1` subsection.
- **`## Todos —` already present for this agent** → the phase is already done for this agent; do not re-derive over the existing block. (`plan-em` mode detection routes to `build` once every agent has one — this mode should not have been dispatched.)
- **Invoked before any `## Engineering —` section exists** → hard failure per the Input contract above; nothing is decomposed.
- **F-ID under `## Todos` with no matching execution-table row (or vice versa)** → surface as a coverage gap (step 4), not a silent drop.

---

## Output contract (Step 5)

- The PRD file carries a new `## Todos — <Agent Name>` block, under the `## Todos` umbrella, with one `### F<n>` block per owned feature, each ticket matching the `refs/todo/template-todo.md` schema (`id`, `title`, `objective`, `type`, `priority`, `files`, `depends-on`, `done-when`).
- Do not write any implementation files. Do not modify the `## Engineering — <Agent>` sections or any other part of the PRD outside the `## Todos` region.
- Emit the one-line confirmation from work-step 3, plus any coverage gaps from work-step 4.
