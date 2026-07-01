---
name: improve
description: >
  Lightweight improvement planner. Takes a target skill and a description of
  what to improve, asks follow-up questions, and writes a plan + acceptance
  criteria to improve/[n]-[feature-type]/. Invoke with /improve <description>.
allowed_tools:
  - Agent
  - AskUserQuestion
  - Bash
  - Read
  - Skill
  - Write
---

# improve

## Usage

**Invoke**: `/improve <description of what to improve>`. When invoked without a description, prompts the user to select one of three intents: improve an existing skill or workflow, create a new agent (full design flow via `/agent-plan` if available, or lightweight inline plan), or describe something that feels broken.

**`--review` flag**: `/improve --review <plan>` — runs an adversarial review against an existing plan instead of creating a new one. See **--review mode** below.

## --review mode

When invoked as `/improve --review <plan>` (or `/improve --review` with no plan), skip Steps 1–7 entirely and run the adversarial review protocol below.

**Step R1 — Resolve plan path**

`<plan>` may be:
- A plan number (`19`) — find the matching row in `_INDEX.md` and extract the link path.
- A plan slug (`19-plan-loop-modes`) — match against `_INDEX.md` by slug.
- A full path (`.claude/skills/improve/19-plan-loop-modes/`) — use directly.
- Omitted — call `AskUserQuestion`: header `"Plan"`, question `"Which plan should I review?"`, options built from the `In-progress` rows in `_INDEX.md` (up to 4); add `"Other (enter path)"` if there are more.

Read `plan.md` and `acceptance.md` from the resolved path. If either file is missing, emit an error and stop.

**Step R2 — Adversarial review**

Read `.claude/skills/improve/refs/review-protocol.md`.

Spawn an `Agent` with this prompt:

```
<protocol>
[full text of review-protocol.md]
</protocol>

<plan>
[full text of plan.md]
</plan>

<acceptance>
[full text of acceptance.md]
</acceptance>

Review the plan and acceptance criteria above following the protocol. Output your findings exactly as the protocol specifies.
```

**Step R3 — Emit findings inline**

Display the review agent's output exactly as returned. Do not paraphrase or trim it.

**Step R4 — Human gate**

Call `AskUserQuestion` with header `"Next step"`, question `"What would you like to do with these findings?"`, `multiSelect: false`, options:
- `{ label: "Revise plan", description: "Edit plan.md to address findings, then re-run the review" }`
- `{ label: "Revise acceptance", description: "Edit acceptance.md to address findings, then re-run the review" }`
- `{ label: "Revise both", description: "Edit both files, then re-run the review" }`
- `{ label: "Done", description: "No changes needed — finish here" }`

If the user selects **Revise plan**: ask what to change, read `plan.md`, apply edits in place, then return to Step R2.
If the user selects **Revise acceptance**: ask what to change, read `acceptance.md`, apply edits in place, then return to Step R2.
If the user selects **Revise both**: ask what to change for each file, apply edits to both, then return to Step R2.
If the user selects **Done**: emit `"Review complete."` and stop.

---

## Protocol

**Step 1 — Clarify intent**

If invoked without a description, call `AskUserQuestion` with a `questions` array containing one entry: `header: "Intent"`, `question: "What would you like to do?"`, `multiSelect: false`, and exactly three options:
- `{ label: "Improve existing", description: "Improve or extend an existing skill, workflow, or piece of code" }`
- `{ label: "Not sure yet", description: "Describe what feels broken or suboptimal and I'll help scope it" }`
- `{ label: "Create a new agent", description: "Design a brand-new skill/agent" }`

If "Create a new agent" is selected, proceed to **Step 1b** below. Otherwise treat the response as a description of the improvement and continue.

**Step 1b — Agent-creation routing** *(only when "Create a new agent" was chosen in Step 1)*

First, check whether `agent-plan` appears in the available-skills list in the current system-reminder (no tool call needed — it is already in context).

If it **exists**: call `AskUserQuestion`: `header: "Agent path"`, `question: "Which creation path would you like?"`, `multiSelect: false`, options:
- `{ label: "Use /agent-plan (full flow)", description: "Invoke the /agent-plan skill for the complete structured design pipeline" }`
- `{ label: "Stay in /improve (lightweight)", description: "Answer a few quick questions here and produce a plan.md + acceptance.md ready for /agent-build" }`

If the user picks **Use /agent-plan**: invoke the `agent-plan` skill via `Skill` and terminate this `/improve` flow immediately — do not proceed to Step 2.

If it **does not exist**, or if the user picks **Stay in /improve (lightweight)**: ask up to 5 clarifying questions, one `AskUserQuestion` call at a time, covering at minimum:
1. Agent name and one-sentence purpose
2. Trigger conditions and invocation pattern (when does a user call this agent, and how?)
3. Tools the agent needs (e.g. Bash, Read, Write, AskUserQuestion, external MCPs)
4. Constraints or out-of-scope items
5. Desired output format or artifact

Use the answers as the description for all subsequent steps. Set the slug to `create-<agent-name>` (lowercased, hyphenated).

**Step 2 — Improvement clarifying questions** *(only for the improvement path, not the lightweight agent-creation path)*

Call `AskUserQuestion` for each follow-up question, one at a time, up to 5. Always pass a `questions` array (never a bare `question` key). Stop earlier when the picture is clear. Each question should be guided by these principles:

- **Understand the gap** — what is broken, missing, or suboptimal and in which context does it surface?
- **Understand the stakes** — what breaks or degrades if this is left unfixed?
- **Understand constraints** — are there hard limits (line count, backward compatibility, scope)?
- **Understand the desired outcome** — what does success look like after the change?
- **Avoid redundancy** — never ask for information already given in the description or a prior answer.

**Step 3 — Derive n and slug**

`_INDEX.md` is the single source of truth for plan numbering — plans live in `./`, `done/`, `backlog/`, and `archive/`, so a plain `ls` of the improve root undercounts. Read `.claude/skills/improve/_INDEX.md`, take the **highest integer** in the `ID` column (treat `7.1`/`7.2`/`7.3` as `7`), and increment by 1 for `n`. Default to `1` if the index has no rows. If `_INDEX.md` is missing, stop and tell the user to recreate it before continuing — do not fall back to `ls`.

For the improvement path, slugify the description to ≤3 lowercase hyphenated words for `feature-type`. For the lightweight agent-creation path, use `create-<agent-name>` as the slug. New plans are created at the improve root (in-progress status); `done/`, `backlog/`, and `archive/` are moved into later by hand. Store the resolved path as `$OUT` (e.g. `.claude/skills/improve/14-refactor-step-flow/`). All subsequent steps use `$OUT`.

**Step 4 — Read and write plan**

Read `.claude/skills/improve/refs/template.md`. Create `$OUT` and write `$OUT/plan.md` populated from the template using the description and clarification answers. For the lightweight agent-creation path, the plan.md must be readable as a standalone brief passable directly to `/agent-build`.

**Step 5 — Acceptance criteria**

For every discrete change in the plan, write one or more testable assertions to `$OUT/acceptance.md`. Each assertion is one line, numbered sequentially. Every change must map to at least one criterion — no exceptions.

**Step 6 — Register in _INDEX.md**

Append a new row to the table in `.claude/skills/improve/_INDEX.md` for the plan just written. Columns: `ID` (the `n` from Step 3), `Name` (markdown link to `$OUT/plan.md` using the slug as link text), `Description` (one sentence — pull from the plan's Problem section), `Status` (`In-progress` for newly created plans).

**Step 7 — Review and terminate**

Emit `$OUT` as a markdown link.

Call `AskUserQuestion` with a `questions` array: `header: "Next step"`, `question: "What would you like to do next?"`, `multiSelect: false`, `options`:
- **Revise** — ask what to change, then read and edit `$OUT/plan.md` and `$OUT/acceptance.md` in place. Update the corresponding `_INDEX.md` row if the description changed. Re-emit Step 7.
- **Done** — emit exactly: "Plan and acceptance criteria emitted. Run `/improve --review <n>` to run an adversarial review against this plan."
