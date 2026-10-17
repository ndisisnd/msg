---
name: plan-pm
description: >
  Principal PM skill — the autonomous PRD writer. Consumes a graded, fleshed-out
  row from the INTAKE.md backlog (idea, goal, type, grade) and drafts the full PRD
  solo — feature/acceptance table, edge cases, error handling — saved to
  features/planned/prd-[n]-[feature-slug]/. The requirements interview lives in /intake now,
  not here. Treats the row as settled and picks its own few follow-up questions
  (refs/principles.md); pauses ONLY for that one batch and for breaking/critical
  touches. --update edits an existing PRD's content and syncs its intake row;
  --migrate converts old PRDs to the current template. Refuses requests that would
  skip the PRD stage entirely.
argument-hint: "[#<n> | --sub <prd-path> | --update <prd> | --migrate <prd|--all>]"
allowed_tools:
  - AskUserQuestion
  - Bash
  - Edit
  - Read
  - Skill
  - WebFetch
  - WebSearch
  - Write
---

# plan-pm

## Usage

**Invoke**: `/plan-pm`. With no args it lists the `INTAKE.md` backlog and asks which row to plan.

- Slash commands: `/plan-pm`, `/plan-pm #<n>` (plan a specific intake row), `/plan-pm --sub [parent PRD path | number]`, `/plan-pm --update [prd path | number]`, `/plan-pm --migrate [prd path | number | --all]`
- Natural language: "plan this idea", "draft a PRD", "write the PRD for the streaks feature", "turn backlog item 3 into a PRD"
- Natural language (**sub-PRD**): "create a sub-PRD", "follow-up fixes for this PRD", "spin off a sub-PRD" — route to the `--sub` mode in the § Sub-PRD mode section below.
- Natural language (**update**): "change PRD 3", "add a feature to this PRD", "drop F2 from the streaks PRD", "the PRD should also cover …" — route to § Update mode below.
- Natural language (**migrate**): "migrate this PRD to the new template", "bring PRD 3 up to date with the template", "convert the old PRDs" — route to § Migrate mode below.

**Modes:** default (autonomous top-level PRD from an intake row), `--sub` (a numbered follow-up nested under an existing parent PRD), `--update` (change what an existing PRD says), and `--migrate` (convert existing PRDs to the current template, no content change). When `--sub` is present — flag or sub-PRD natural-language trigger — read § Sub-PRD mode (`--sub`) first; all other steps run identically. `--update` and `--migrate` each replace the five-step protocol entirely. "Update" means a content change here, as it does in `/intake`.

**Every PRD comes from an `INTAKE.md` row — there is no other entry path.** Prose handed straight to plan-pm is captured into the ledger first (Step 1 calls `/intake` in capture mode), then planned from the row that comes back. Nothing is drafted against a row that does not exist.

**Hard refusal:** a request to skip the PRD and jump straight to engineering. State that `plan-em` requires a PRD and offer to draft one now (from a backlog row) or accept an existing PRD path for `plan-em`.

## Pre-run — devkit reads

Before Step 1, stat-check and read the following in parallel via `Bash`. Written to `devkit/` by `/msg --init`; `CLAUDE.md` stays at project root.

| File | How to apply |
|------|-------------|
| `devkit/AHA.md` | Surface relevant entries in the Open questions section; **apply self-healing learnings (G5) to the draft** so a category-tagged pattern (e.g. `[tune:error-cases] …`) is avoided this run |
| `CLAUDE.md` | Extract tech-stack constraints, conventions, architecture notes; validate feasibility of the drafted features and constrain the autonomous draft where the project setup already determines an answer |
| `devkit/ARCHITECTURE.md` | Load system layers and integration points; validate feasibility and note conflicts in Open questions; source the platform detection in Step 3 |
| `devkit/OPEN-QUESTIONS.md` | Scan for unresolved decisions that constrain the draft; surface relevant entries in Open questions |

`devkit/GLOSSARY.md` and `devkit/DESIGN-SYSTEM.md` are **not** read here: the PRD has no Glossary section (new terms are appended to `devkit/GLOSSARY.md` directly, where the whole pipeline sees them) and no User flow / Key user interactions sections, which were their only stated consumers.

**Absent-file rule:** If `devkit/` does not exist, emit `devkit/ not found — run /msg --init to initialise the project first.` and proceed. If an individual file is missing, emit `<filename> not found — run /msg --init to initialise the project first.` Proceed without the file; do not create it. Do not ask the user about these files. Do not block. Proceed to Step 1 immediately.

## Sub-PRD mode (`--sub`)

A sub-PRD is a numbered follow-up (`prd-<n>.<m>`) capturing extra changes/fixes to an existing parent PRD, nested inside the parent's folder, sharing the parent's branch. When `--sub` is present — flag or natural-language trigger — read `refs/protocol-sub.md` first and apply its deltas before Step 1 emits; every other step runs unchanged.

## Update mode (`--update`)

`--update` changes the content of one existing PRD — features, scope, criteria, error cases. Read `refs/protocol-update.md` and follow it end to end; **the five-step protocol below does not run in this mode.** Once a PRD exists it is the source of truth and its intake row mirrors it: the run edits the PRD on the template, re-runs the shape gate, stamps `reviewed: no` so plan-review re-certifies, syncs the changed `idea` / `goal` / `type` / `grade` cells back to the row through `script-intake-stamp.sh --set-cell` (plan-pm is the second writer of row content, for PRD-linked rows only), and prints the digest with the changed parts marked.

## Migrate mode (`--migrate`)

`--migrate` converges a PRD that already exists onto the current template — the one deliberate, user-invoked exception to the rule that nothing on disk is ever rewritten. It never changes what the PRD says. Read `refs/protocol-migrate.md` and follow it end to end; **the five-step protocol below does not run in this mode.** It takes one PRD (path or number) or `--all`.

Two things this mode is not:

- **It writes no `INTAKE.md` row and reads none.** The intake-only rule governs where a PRD's *idea* comes from, and a migration introduces no idea — this is maintenance on an existing artifact. Explicit carve-out; the hard refusal against skipping the PRD stage is untouched.
- **It changes nothing about how PRDs are read.** Every other skill still normalises the old shape in memory, and no writer emits it. The read path is exactly as it was.

The run is two layers: `.claude/scripts/script-prd-update.py` does the mechanical migration (frontmatter mapping, inline findings moved out to `reports/`, section renumbering), then the model does the style pass (§5 bullets → the four-column table, §1 back to its two bullets). It finishes on `script-prd-shape.py --checks 1,2,3,4,5,6` — check 6 is opt-in and requested only here, so fresh-draft gates keep running 1–5.

## Step-by-step protocol

Follow `refs/protocol-pm.md` end-to-end — it owns the steps, their order, and their outputs.

**PRD digest (default / `--sub`):** directly above the closing message, print the four-line digest from `script-prd-digest.py --terminal` — `Title` (PRD id + name), `Change` (who + outcome), `Builds` (feature names), `Open` (open-question count; omitted when 0). `--update` prints the same digest with the changed parts marked; `--migrate` prints no digest, only a one-line `Converted <n> PRD(s)…` count.

**Closing message (default / `--sub`, every outcome; `--update` closes per `refs/protocol-update.md` § Step U6; `--migrate` per `refs/protocol-migrate.md` § Step U5):** end the run with the closing message per `../shared/refs/closing-message.md` — the last chat output, after Step 5's termination output. Two `What happened` rows are **mandatory** on every completed run: the PRD path, written verbatim so it can be copy-pasted, and `Open questions left: <n>` counted from the drafted §5. That count drives the protocol deterministically — `0` ⇒ 🟢, `>0` ⇒ 🟡. The one-line "what this run did" slot may run to 2–3 lines here, summarising the feature drafted. Take the next step from the registry's plan-pm row; never compose it.

**Harness incidents (all modes):** log unexpected script failures, tool errors, retries, and missed writes to `devkit/DOCTOR.md` per `../shared/refs/doctor-logging.md` — logging never changes what the run does next.

## PRD status lifecycle

The lifecycle — the frontmatter field table, the status-vs-lane rule, the pre-v5.4
normalisation, and the intake ledger stamp (F4/D14: plan-pm stamps the source `INTAKE.md`
row `in-progress` + `prd` cell at Step 5 via `script-intake-stamp.sh`) — lives in
`../shared/refs/prd-lifecycle.md`, the one home. plan-pm writes a new PRD `status: backlog`
and stamps nothing else; every stamp goes through the shared writers, never improvised Bash.

## References

- `refs/protocol-pm.md` — end-to-end five-step autonomous protocol; followed from § Step-by-step protocol
- `refs/protocol-sub.md` — the `--sub` deltas layered over that protocol; read from § Sub-PRD mode when `--sub` is set
- `refs/principles.md` — plan-pm's own rules for which follow-up questions to ask (never re-ask or widen the row; send scope changes to `/intake --update`); read in Steps 1 and 4
- `refs/protocol-update.md` — the standalone `--update` protocol (resolve + lock gates → edit on the template → shape gate → `reviewed: no` → re-grade → row sync → marked digest + close); read from § Update mode when `--update` is set
- `refs/protocol-migrate.md` — the standalone `--migrate` protocol (target resolution → L1 → style pass → checks 1–6 gate → close); read from § Migrate mode when `--migrate` is set, and it replaces the five-step protocol rather than layering over it
- `.claude/scripts/script-prd-update.py` — deterministic v5 → v5.4 PRD migrator (L1); called per target in `--migrate` Step U2
- `.claude/scripts/script-prd-digest.py --terminal` — the four-line PRD digest printed above the closing message (`--mark` flags the parts an `--update` changed)
- `.claude/scripts/script-prd-scan.sh` — deterministic lane-aware PRD inventory (JSONL); call in Step 2's prior-PRD scan
- `refs/template-prd.md` — structured PRD format (seven sections) and its drafting rules, including the §3 F-ID and acceptance-criteria contract and the §4 error-and-edge-case format; used to initialize the file in Step 3
- `refs/error-checklist.md` — the standard failure types (Tier 1 always, Tier 2 when the trigger fits) every §3 feature is checked against when §4 is drafted
- `.claude/scripts/script-prd-shape.py` — deterministic PRD shape validator; call at the end of Step 3 Part 4
- `.claude/scripts/script-prd-number prd` — deterministic next-PRD-number resolver; call in Step 3
- `.claude/scripts/script-prd-number sub <parent-n>` — deterministic next sub-PRD minor resolver; call in Step 3 Part 1 when in `--sub` mode (see § Sub-PRD mode)
- `INTAKE.md` — the root backlog ledger written by `/intake`; the **only** source of a PRD's idea — read in Step 1 to resolve the row (calling `/intake` to capture one first when the user came in with raw prose), stamped in Step 5
- `devkit/` — project-level agent context directory created by `/msg --init`; contains AHA.md, GLOSSARY.md, ARCHITECTURE.md, DESIGN-SYSTEM.md, OPEN-QUESTIONS.md
