---
name: plan-review protocol
description: The three-step certification protocol — resolve and select the check, certify, then fix, record, stamp and report
type: reference
---

# Step-by-step protocol

Resolve every script with the two-path pattern: `S=.claude/scripts/<name>; [ -f "$S" ] || S="$HOME/.claude/scripts/<name>"`. The commands below show the script name only.

The findings report is created by `script-ledger.py` — never author it by hand. Every other write is an in-place edit of a file that already exists.

## Step 1/3 — Resolve the PRD and select the check

```bash
bash script-cert-preflight.sh "<path-hint>"   # drop the argument if none was given
```

- Any `ERROR=` (`no_path`, `invalid_pattern`, `not_found`) → ask via `AskUserQuestion` for a file or directory and re-run. After two failures, refuse, show the expected pattern (`features/prd-N/prd-N.md`), and offer `/plan-pm`.
- On exit 0: `RESOLVED_PATH` is the PRD for every later read and edit, `PRD_N` is `[n]`, and `TUNE_SUGGESTION` (`product` | `eng`) is the selected check. A `--product` / `--eng` flag from a calling skill overrides it. Never ask.

**Read the PRD through its digest slice, not the full file:**

```bash
python3 script-prd-digest.py "$RESOLVED_PATH" --slice product     # product check
python3 script-prd-digest.py "$RESOLVED_PATH" --slice eng-audit   # eng check
```

`certification.md` § Input owns the slices and the `prose_lines` escape hatch. Never treat a prior finding's text as a fresh instance of the problem.

## Step 2/3 — Certify

**Mechanical checks:**

```bash
python3 script-cert-mech.py "$RESOLVED_PATH" --checks 6        # product check
python3 script-cert-mech.py "$RESOLVED_PATH" --checks 4,5,6    # eng check
```

Each `FINDING check=… sev=… code=… ref=… detail=…` line is one finding. `SKIP` lines record nothing. Exit 0 = clean, 1 = findings, 2 = the PRD is unreadable or has no frontmatter: stop and report it, do not certify.

**Judgment checks:** product check 1, 2, 3; eng check 2, 7 — apply them from `certification.md` against the slice.

One finding per issue. "What is wrong" cites the section and the check; "Why it matters" names the consumer that breaks. Hold every finding with its `check`, and its `code` + `ref` (script finding) or its `section` (judgment finding). Do not write the ledger yet.

## Step 3/3 — Fix, record, stamp, report

**1. Auto-fix every Critical and Major.** Patch the exact PRD section each one cites. The product check never edits `## Engineering —` sections. Mark each fixed finding `Fixed`.

**2. Product-decision pause — the only stop.** A finding whose fix needs a choice between product behaviours is never auto-fixed. Batch every such finding into one `AskUserQuestion` (≤4 per call), each with a suggested resolution. Apply the answers and mark those findings `Fixed`. A decision the user leaves open stays `Open` and goes to the ambiguity log:

```bash
bash script-openq.sh devkit/OPEN-QUESTIONS.md --title "<short title>" --question "<the decision>" \
  --severity high --context "<PRD section + check>" --raised-by plan-review
```

Exit 3 = no `devkit/OPEN-QUESTIONS.md`: skip it. Exit 2 = fix the call; never hand-edit the file.

**3. Minors.** Never ask. Leave each Minor `Open`; it is listed in the result block.

**4. Re-run the mechanical checks** with the same `--checks` as Step 2. A script finding that no longer appears is `Fixed`. A new one is a finding of this run: fix it if Critical/Major (one more pass at most), else leave it `Open`.

**5. Write the ledger — once, after the fixes:**

```bash
echo '[{"check":4,"code":"EXEC_FID_UNCOVERED","ref":"F3","severity":"Critical","what":"…","fix":"…","why":"…","status":"Fixed"},
       {"check":1,"section":"3. Features & acceptance criteria","severity":"Minor","what":"…","fix":"…","why":"…","status":"Open"}]' \
  | python3 script-ledger.py "$RESOLVED_PATH" --auditor P --checks 1,2,3,6   # eng check: --auditor E --checks 2,4,5,6,7
```

The script matches a repeat to its prior row, honours each `status`, turns a prior open row of a check that ran clean into `Fixed`, and numbers new rows. Send `[]` when nothing was found. Read back `LEDGER_OPEN_CRITICAL`, `LEDGER_OPEN_MAJOR`, `LEDGER_OPEN_MINOR`. Exit 2 = malformed JSON or a drifted table: report it and stop; never hand-edit the table.

**6. Self-healing learnings.** One entry per auto-fixed Critical/Major, with a category from `certification.md`:

```bash
bash script-aha.sh devkit/AHA.md --tag "tune:<category>" \
  --summary "<one line>" --why "<what the PRD got wrong>" --note "<what future drafts should do>"
```

Exit 3 = no `devkit/AHA.md`: skip. Exit 2 = fix the call.

**7. Open questions.** Normalise the PRD's Open questions section into `# | Question | Answer | Status`: one row per bullet; an existing table keeps its Question/Answer cells; `Status` = `Addressed` when Answer is real, else `Open`. Idempotent.

**8. Stamp — only when `LEDGER_OPEN_CRITICAL=0`:**

```bash
bash script-prd-stamp.sh "$RESOLVED_PATH" --certify product   # or: --certify eng
```

The script picks the field. With an open Critical, write no stamp.

**9. Result block** — the run's one summary, directly above the closing message:

```
Result     Certified · product check          (or: Not certified — 1 Critical open)
Findings   2 Critical · 1 Major · 3 Minor (3 fixed, 3 open)
```

Then the fixed-items table (`certification.md` § Fixed-items table), then a **Decisions needed** list (each open Critical, then each open Minor, one line each). Omit the table or the list when empty. With no findings: `Result  Certified · product check — no findings`.

**Closing protocol:** certified with nothing open → 🟢; certified with open Minors → 🟡; not certified → 🔴.

**Next step (recommend, never invoke):** product check → `/plan-em <RESOLVED_PATH>`; eng check → `/plan-em <RESOLVED_PATH>` again for the build half. Not certified → resolve the open Critical, then re-run `/plan-review`. When plan-em ran this skill, plan-em drives the next step.
