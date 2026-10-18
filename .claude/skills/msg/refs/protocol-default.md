---
name: msg default
description: The /msg (no args) protocol — print the next step per PRD in progress from a state script, then one AskUserQuestion — run one of them, or show the two-question skill menu
type: reference
---

# Protocol: default (no args)

Dispatched from `msg/SKILL.md` on bare `/msg`. The category/skill rows come from
the SKILL.md **Skills** table — the canonical menu; this protocol never restates it.

**Step 1 — Next steps**

Read the project state by script. The script owns the step ladder; never re-derive it:

```bash
S=.claude/scripts/script-msg-next.py; [ -f "$S" ] || S="$HOME/.claude/scripts/script-msg-next.py"
python3 "$S" --max 4
```

It reads `devkit/`, `devkit/policy.json` (release flow), the PRDs in `features/planned/`
and `features/wip/` (frontmatter `reviewed`, `staging-signoff`; `## Todos —` tickets;
eng reports), pre-merge's last check per branch (`.pre-merge/last-check.json`, the
commit and the verdict together — `script-premerge-last-check.sh`), git (branch tip, and
whether it is in staging), and `INTAKE.md` rows with no PRD.

Print one line per `NEXT=<command>|<why>|<prd>` key, in order (at most 4):

```
Next: `<command>` — <prd>: <why>
```

Leave out `<prd>: ` when it is `-`. `MORE=<n>` above 0 ⇒ add one line:
`…and <n> more — /msg --gui shows the board.`

`SETUP=no` (no `devkit/`) ⇒ the one line is `Next: /msg --init — this project is not set
up yet`.

**Step 2 — One question**

Call `AskUserQuestion` with one question:

- **Question**: `Run one of these?`
- **Header**: `Next`
- **multiSelect**: `false`
- **Options**: one per printed `NEXT` line, up to 3 (`label` = the command, `description` =
  `<prd>: <why>`), then `Show menu` (`description`: `Pick any msg skill instead`).
  With 4 `NEXT` lines, offer the first 3 plus `Show menu`.

A command picked ⇒ run it now (`Skill(<skill>, <args>)`), as if the user had typed it.
`Show menu` ⇒ Step 3.

**Step 3 — Category** (only after `Show menu`)

Call `AskUserQuestion` with one question:

- **Question**: `Which area do you need help with?`
- **Header**: `Category`
- **multiSelect**: `false`
- **Options**:
  - `label`: `Planning`, `description`: `Bootstrap, idea capture, spec writing, PRD audit, engineering planning`
  - `label`: `Build & Ship`, `description`: `Implement code and run the CI gate`
  - `label`: `Delivery`, `description`: `Task lists, commits`

**Step 4 — Skill**

`AskUserQuestion` allows 2–4 options per question.

- **Question**: `Which skill?`
- **Header**: `Skill`
- **multiSelect**: `false`
- **Options**: the rows in the selected category, in table order (`label` = Skill, `description` = Description).

**Paging (Planning has 5 rows).** When a category has more than 4 rows (Planning: msg --init · intake · plan-pm · plan-review · plan-em), present the first 4 in table order plus a final `More…` option; if the user picks `More…`, re-ask with the remaining rows. Every other category has ≤4 rows and is asked in one call.

**Step 5 — Emit**

Emit exactly:

```
/<skill> — <description>
```

Stop. Do not emit anything else.
