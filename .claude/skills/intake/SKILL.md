---
name: intake
description: >
  The planning front-door. Captures feature ideas and bugs as graded rows in
  the root INTAKE.md ledger. Use it when the user says "log an idea", "capture
  a bug", "add to the backlog", "note this down", "track this feature", or
  invokes `/intake`. Opens with one prompt ("What are you trying to build?"),
  infers the rest from a light scan of the project's docs, PRDs and ledger, and
  asks only when something is unclear. Splits pasted lists and oversize ideas
  into discrete in-scope rows, flags duplicates, and grades every idea in a
  single-turn banded judgment (complexity / sequencing). Feeds `plan-pm`, which
  drafts the PRD.
  Also edits the ledger: use it when the user says "update that idea", "change
  the goal on #4", "drop the search idea", "remove row #4", or "I logged that by
  mistake" (`--update` / `--delete`, or plain language — deletes always warn and
  confirm first). `--health`: use it when the user says "check the backlog",
  "find stale ideas", or "which rows already shipped". `--brainstorm on|off`
  turns related-idea suggestions on or off for the project.
argument-hint: "[--update | --delete | --health | --brainstorm [on|off]] <idea text | #n change>"
allowed_tools:
  - AskUserQuestion
  - Read
  - Edit
  - Write
  - Bash
---

# intake

The front-door of the msg planning pipeline. Ideas and bugs enter here and become graded rows in the root `INTAKE.md` ledger. `plan-pm` reads those rows and drafts the PRD.

```
intake (capture + grade → INTAKE.md rows) → plan-pm (drafts the PRD, stamps in-progress + prd) → … → merge --production (stamps completed)
```

## Usage

- `/intake [<idea text>]` — capture one or more ideas or bugs. No text → intake asks "What are you trying to build?".
- `/intake --update [<text>]` — edit a `backlog` row's `idea` / `goal` / `type`. NL: "change the goal on #4".
- `/intake --delete [<#n | text>]` — remove a row after a warning pass and a confirm. NL: "drop the search idea".
- `/intake --health` — list stale, errant, shipped-but-open and duplicate rows; offer to fix wrong statuses.
- `/intake --brainstorm` — suggest related ideas for this run only. `--brainstorm on` / `--brainstorm off` (or "turn brainstorm off") — save the setting for the project.

## Mode dispatch

Resolve the mode once, at entry, then read exactly one protocol. No `devkit/` ⇒ setup runs by itself first (`/msg --init`, then this command — `../shared/refs/setup-first.md`).

1. **Flag.** `--update` or `--delete` → edit; `--health` → health. `--sub-row <n>.<m>` (sent only by `plan-pm --sub`) → capture of one sub-PRD row at that id (`protocol-intake.md` § Sub-PRD rows). Strip the flag from the text. Two mode flags at once → ask which.
2. **Plain language with no flag.** Text that asks to change or remove an existing row (a `#n`, or "change / drop / remove / rename … the <idea> idea") → edit, with the action it names. A remove always gets delete's warning pass and confirm. A "change or remove?" doubt is an edit (`principles.md` 8). Anything else → capture.
3. **Brainstorm.** `--brainstorm on|off` or a plain-language toggle → write the switch, report it, and stop (unless idea text follows, which is then captured):

   ```bash
   .claude/scripts/script-policy-set.py --file devkit/policy.json --set policies.intake.brainstorm=<true|false>
   ```

   No `devkit/policy.json` (a project set up before the file existed) → say `/msg --update` adds it, and use the value for this run only. Bare `--brainstorm` → on for this run, nothing written.

| Mode | Protocol |
|------|----------|
| capture (default) | `refs/protocol-intake.md` — context scan, one prompt, inference, splits, duplicates, suggestions, grade, write |
| update · delete | `refs/protocol-edit.md` — find the row, lock gates, update or delete, the update log, the three edit surfaces |
| `--health` | `refs/protocol-health.md` — stale / errant / shipped / duplicate scan, one-confirm status fix |

## Brainstorm

Suggestions run only when brainstorm is on: the bare `--brainstorm` flag for one run, or `policies.intake.brainstorm: true` in `devkit/policy.json`. `/msg --init` seeds `true`. A project with no key reads as off. Suggestions always stay in scope (`principles.md` 2).

## Hard rules

- Never drafts a PRD and never runs a codebase analysis. Reading for context (`protocol-intake.md` § Pre-run) is allowed; planning is `plan-pm`'s.
- Grades are bands only — never a fake-precise estimate (`refs/rubric.md`).
- Asks only what `refs/principles.md` flags as unclear. Capture has no fixed questions.
- Never reads `INTAKE.md` in full — always through `script-intake-stamp.sh --list-rows` filters.
- Never writes `prd`. Writes `status` only in `--health` (behind one confirm) and when a duplicate's PRD has shipped (`completed`).
- Edit and health never scaffold a missing `INTAKE.md`. Capture creates it without asking.
- Delete never renumbers and never proceeds without an explicit confirm.

**Closing message (every mode, every outcome):** end per `../shared/refs/closing-message.md`.

**Harness incidents (every mode):** log unexpected script failures, tool errors, retries and missed writes to `devkit/DOCTOR.md` per `../shared/refs/doctor-logging.md`.

## References

- `refs/protocol-intake.md` · `refs/protocol-edit.md` · `refs/protocol-health.md` — the mode protocols
- `refs/principles.md` — when to ask, how to split, what is a duplicate
- `refs/rubric.md` — the `C:` / `S:` bands, their plain-English labels, the split threshold
- `.claude/scripts/script-intake-stamp.sh` — the one ledger reader and writer: `--list-rows` (filtered read), `--append-row`, `--set-cell`, `--remove-row`, `--status` (health and shipped-duplicate fixes only), `--migrate-log`, `--log-append`
- `.claude/skills/msg/refs/init/templates/TEMPLATE-INTAKE.md` — the ledger template
- `../shared/refs/prd-lifecycle.md` § *INTAKE.md row lifecycle* · `../shared/refs/policy-schema.md` § `policies.intake`
