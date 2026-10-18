---
name: eng --bug — a bug found by hand
description: Loaded by /eng --bug "<what is wrong>". Files the bug as a new numbered report pair in the PRD's reports/ folder (the same format pre-merge writes), then runs the normal fix flow on it.
type: reference
---

# eng --bug — a bug found by hand

`/eng --bug "<what is wrong>"` turns a bug the user describes in plain words into its own report, then fixes it with the normal fix flow. Each bug is a **new** report; existing reports are never edited.

## Step 1 — Gather the bug

The quoted text is the description. When it is missing or empty, ask once: "What is wrong? Describe what you did and what you saw." Optional details, used when the user gave them (never asked for one by one): the file where it shows (`file=`), a command that shows it (`repro=`), how serious it is (`severity=`, default `high`), and the PRD (`prd=`).

## Step 2 — Write the report

```bash
B=.claude/scripts/script-eng-bug-report.py; [ -f "$B" ] || B="$HOME/.claude/scripts/script-eng-bug-report.py"
python3 "$B" --description "<what is wrong>" [--prd <path> | --no-prd] [--file <path>] [--repro "<cmd>"] [--severity <level>]
```

The script owns the format (`../../../shared/refs/report-schema.md`): `report-prd-<N>-<K>.json` (the issues file, one finding with `source: eng:bug`) and `report-prd-<N>-<K>.md`, with `<K>` the next free number. Without `--prd`, the PRD comes from the current branch (`feat/prd-<N>-<slug>`).

- Exit 0 → `REPORT_JSON=<path>`. Tell the user in one line: `Filed as <REPORT_MD path>.`
- Exit 1 `PRD_UNRESOLVED` or `PRD_AMBIGUOUS` → ask once via `AskUserQuestion`: the matching PRDs (or the PRDs under `features/`), plus **"No PRD"**. Call again with `--prd <choice>` or `--no-prd`. With no user present, a single match is never in doubt; no match → `--no-prd`; several matches → stop and name them.
- Exit 2 → emit the stderr line and stop.

## Step 3 — Fix it

Run the normal fix flow on the new issues file: `eng --build report=<REPORT_JSON>` (`fix-build.md`). The limit of 3 fix attempts per bug applies (`protocol-build-debug.md`). Only a run with `orchestrate=off` asks the one "Commit?" question at the end; the orchestrated default commits without asking. The db-touch pause stays separate.
