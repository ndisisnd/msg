---
name: plan-pm
description: >
  Principal PM skill. Interviews the user via AskUserQuestion (5 questions),
  then produces a structured PRD saved to features/prd-[n]-[feature-slug]/prd-[n]-[feature-slug].md.
  Default entry point for the product ship workflow. Refuses requests that
  would skip the PRD stage. Automatically detects large epics and offers to
  split them into multiple sequential PRDs, completing all before terminating.
allowed_tools:
  - AskUserQuestion
  - Bash
  - Read
  - Skill
  - Write
---

# plan-pm

## Usage

**Invoke**: `/plan-pm`. Pass an optional product idea or brief as input.

- Slash commands: `/plan-pm`, `/plan-pm --sub [parent PRD path | number]`
- Natural language: "start a new feature", "plan and build", "begin product workflow", "kick off the build pipeline", "draft a PRD"
- Natural language (**sub-PRD**): "create a sub-PRD", "more changes to PRD 2", "follow-up fixes for this PRD", "spin off a sub-PRD" — route to the `--sub` mode in the § Sub-PRD mode section below.

**Modes:** default (new top-level PRD) and `--sub` (a numbered follow-up nested under an existing parent PRD). When `--sub` is present — as a flag or via a sub-PRD natural-language trigger — read § Sub-PRD mode (`--sub`) first: it changes intake (Step 1), numbering (Step 4 Part 1), the folder/frontmatter written (Step 4 Part 2), and nothing else. All other steps run identically.

**Hard refusals:**
- Request lacks a target user or scope: ask one clarifying `AskUserQuestion` before proceeding.
- Request asks to skip the PRD and jump straight to engineering: refuse. State that `plan-em` requires a PRD and offer to run the interview now or accept an existing PRD path for `plan-em`.

## Persona

1. Interview before writing. Every spec item has an acceptance criterion. Open questions go in the Open questions section, never buried in prose.
2. Never write a requirement an engineer could interpret two ways. Quote ambiguous text verbatim and ask for the precise definition.
3. Output is numbered, dense, and engineer-readable. Tables for feature specs. No hedging or weasel words.
4. All interview questions use `AskUserQuestion` — one at a time, with options plus "Other".

## Progress emission

Emit `Step X/6 — <title>` at the start of each step, unconditionally.

In multi-PRD mode, prefix each step emission with `[PRD N/K] ` (e.g., `[PRD 2/4] Step 3/6 — Interview`).

## Pre-run — devkit reads

Before emitting any step, stat-check and read the following files in parallel via `Bash`. These files are written to `devkit/` by `msg-init`; `CLAUDE.md` stays at project root.

| File | How to apply |
|------|-------------|
| `devkit/AHA.md` | Surface relevant entries in the Open questions section |
| `devkit/GLOSSARY.md` | Cross-reference when populating the Glossary section in Step 5 |
| `CLAUDE.md` | Extract tech stack constraints, conventions, and architecture notes; use to validate feasibility of proposed features and to pre-fill or constrain interview answers where the answer is already determined by the project setup |
| `devkit/ARCHITECTURE.md` | Load system layers and existing integration points; validate feasibility of proposed features against existing constraints and note any conflicts in the Open questions section |
| `devkit/DESIGN-SYSTEM.md` | Load the component registry; when populating User flow and Key user interactions, identify which components the proposed feature would impact or reuse and note them inline |
| `devkit/OPEN-QUESTIONS.md` | Scan for unresolved decisions that may block or constrain proposed features; surface relevant entries in the Open questions section |

**Absent-file rule:** If `devkit/` does not exist, emit `devkit/ not found — run /msg-init to initialise the project first.` and proceed. If an individual file is missing, emit `<filename> not found — run /msg-init to initialise the project first.` Proceed without the file; do not create it.

Do not ask the user about any of these files. Do not block on these checks. Proceed to Step 1 immediately after.

## Sub-PRD mode (`--sub`)

A sub-PRD is a numbered follow-up (`prd-<n>.<m>`) that captures additional changes or fixes to an existing parent PRD without opening a new top-level feature or cutting a new branch. It runs the **identical** six-step protocol in `refs/protocol-pm.md` — same interview, same population, same tune/eng handoffs — with exactly four deltas, all resolved before Step 1 emits:

**D1 — Resolve the parent PRD (priority order).** Determine the parent before anything else. Try each in turn; stop at the first that resolves:
1. **Explicit** — a PRD path or number passed with `--sub` (e.g. `/plan-pm --sub 2` or `/plan-pm --sub features/prd-2-habit-tracking/prd-2-habit-tracking.md`). Resolve it to the matching `features/prd-<parent-n>-*/` directory. If an explicit value is given but matches no such directory → hard-refuse: `Hard failure: --sub parent '<value>' does not match any features/prd-*/ PRD.` and stop.
2. **Infer from branch** — run `git branch --show-current`; if it matches `feat/prd-<n>-<slug>`, that PRD is the parent (the user is typically already on the parent's branch when asking for follow-up work). Confirm the `features/prd-<n>-<slug>/` directory exists.
3. **Pick from a list** — otherwise, `AskUserQuestion` listing open PRDs (glob `features/prd-*/prd-*.md`, exclude any that are themselves sub-PRDs — i.e. whose id contains a `.`). The user selects the parent. If no top-level PRDs exist at all, hard-refuse: `Hard failure: no parent PRD found for --sub — run /plan-pm to create a top-level PRD first.` and stop.

Store the resolved parent as `parent_id` = `prd-<parent-n>-<parent-slug>`, and read its frontmatter (`feature`, `module`, `platform`) — needed for D3/D4.

**D2 — Pre-seed intake (Step 1).** Skip the "target user or scope missing" clarifying question — the parent supplies both. Pre-seed the brief with `follow-up to prd-<parent-n>-<parent-slug>: <parent feature>` (parent `feature` from its frontmatter) and fold the user's stated follow-up changes into it. Epic detection still runs, but a sub-PRD is by definition a focused follow-up — it will almost never trip; do not force a split.

**D3 — Number and place the sub-PRD (Step 4 Part 1 + 2).** Replace the top-level number resolver with the sub resolver:

```bash
S=.claude/scripts/scan-n.prd; [ -f "$S" ] || S="$HOME/.claude/scripts/scan-n.prd"; bash "$S" sub <parent-n>
```

Store the output as `m` (the minor). Derive `sub_slug` (kebab-case, ≤6 words) from the follow-up scope. Create the sub-PRD **nested inside the parent's folder**, using the full `refs/template-prd.md` structure (not a delta doc):

```
features/prd-<parent-n>-<parent-slug>/prd-<parent-n>.<m>-<sub_slug>/prd-<parent-n>.<m>-<sub_slug>.md
```

**D4 — Frontmatter (Step 4 Part 2).** Same fields as a top-level PRD, with:
- `name`: `prd-<parent-n>.<m>-<sub_slug>`
- `parent`: `prd-<parent-n>-<parent-slug>` — **new field, sub-PRD only.** This is the field `plan-em`/`eng --build` read to resolve the shared branch (a sub-PRD never gets its own branch).
- `module` / `platform`: **default to the parent's values** (read in D1). Overridable only if the interview reveals the sub-PRD's scope genuinely differs — otherwise inherit unchanged.
- All other fields (`status: product`, `product-tuned: no`, `eng-tuned: no`, `reviewed: no`, `created`, `affects`, `depends_on`) exactly as a top-level PRD.

**Lifecycle:** unchanged. A sub-PRD runs the full pipeline with no stage skipped — `plan-pm --sub` (Steps 1–6) → `plan-tune --product` → `plan-em` → `plan-tune --eng` → `eng --build`. Step 6's next-step prompt hands off exactly as for a top-level PRD, using the nested sub-PRD path.

Everywhere the steps in `refs/protocol-pm.md` say `features/prd-[n]-[feature_slug]/prd-[n]-[feature_slug].md`, substitute the nested sub-PRD path from D3 when in `--sub` mode.

## Step-by-step protocol

Follow `refs/protocol-pm.md` end-to-end. It defines the full six-step flow — Step 1 Intake (with epic detection), Step 2 Scan prior PRDs for overlap, Step 3 Interview, Step 4 Pre-flight run and initialize template, Step 5 Populate sections, Step 6 Summary and next steps — plus the multi-PRD final summary emitted when multi-PRD mode completes.

## PRD status lifecycle

Each PRD carries four status fields in its YAML frontmatter. The owning skill is responsible for updating the field via `Bash` (`sed -i` or equivalent) immediately after completing the relevant work.

| Field | Initial | Updated by | Updated to | Trigger |
|-------|---------|-----------|-----------|---------|
| `status` | `product` | `plan-em` | `eng` | eng sections written to PRD |
| `product-tuned` | `no` | `plan-tune --product` (via next-step prompt) | `yes` | user accepts tuned output |
| `eng-tuned` | `no` | `plan-tune --eng` (via next-step prompt) | `yes` | plan-tune completes |
| `reviewed` | `no` | `review` skill | `yes` | code review of PRD's changes is complete |

## References

- `refs/protocol-pm.md` — end-to-end six-step execution protocol + multi-PRD final summary; followed from § Step-by-step protocol
- `refs/principles.md` — core operating principles; read this first before any other ref
- `refs/template-prd.md` — structured PRD format; used to initialize the file in Step 4
- `refs/template-error.md` — error case format, rules, and examples; used when populating §6 in Step 5
- `refs/protocol-interview.md` — structured interview questions and format for Step 3
- `.claude/scripts/scan-n.prd prd` — deterministic next-PRD-number resolver; call in Step 4
- `.claude/scripts/scan-n.prd sub <parent-n>` — deterministic next sub-PRD minor resolver; call in Step 4 Part 1 when in `--sub` mode (see § Sub-PRD mode)
- `devkit/` — project-level agent context directory created by `msg-init`; contains AHA.md, GLOSSARY.md, ARCHITECTURE.md, DESIGN-SYSTEM.md, OPEN-QUESTIONS.md
