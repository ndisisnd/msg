---
name: msg-protocol-doctor
description: >
  Protocol for /msg --doctor — reads devkit/DOCTOR.md, the harness-incident
  ledger, tallies incident signatures with script-doctor-tally.sh, graduates any
  signature at the triage threshold into a real issue on the same file (diagnosis
  + recommended fix path), and reports. It NEVER fixes: no skill edits, no
  protocol rewrites. Fixing is a separate session the human invokes with the
  graduated issue as its brief.
type: reference
---

# Protocol: --doctor

## Usage

**Invoke**: `/msg --doctor`

- Natural language: "check the harness", "what keeps failing", "run the doctor", "triage the incident log"
- On demand only — no hook, no schedule, no auto-run at the end of another skill. Nothing
  else reads `DOCTOR.md`, and that is what makes logging to it nearly free.

**Preconditions.** `devkit/DOCTOR.md` must exist. If it is absent, stop: the repo was
bootstrapped before the ledger existed (or never bootstrapped). Direct the user to
`/msg --update`, which tops it up. Do not create the file here.

## The hard boundary — the doctor never fixes

This mode diagnoses. It does not repair.

- **Never** edit a skill, protocol, ref, script, or any project file.
- **No "while I'm here."** A finding that looks like a two-line fix is still a finding.
- The **only** file it writes is `devkit/DOCTOR.md` itself — status flips and the
  graduated-issue blocks.
- The fix happens in a **separate session the human invokes**, with the graduated issue
  as its brief. The closing message points there.

A diagnostician with write access to everything it diagnoses is a repair mode wearing a
health check's name. That is the scope creep this boundary exists to prevent.

## Inputs

| Name | Format | Source |
|------|--------|--------|
| Ledger | Markdown incident table | `<cwd>/devkit/DOCTOR.md` |
| Tally | `KEY=value` lines + `TRIAGE=` rows | `script-doctor-tally.sh` at Step 1 |

## Outputs

| Name | Format | Destination |
|------|--------|-------------|
| Status flips | `logged` → `graduated` on every row of a graduated signature | `<cwd>/devkit/DOCTOR.md` § Incidents |
| Graduated issues | One block per graduated signature — occurrences, 2–3 line diagnosis, recommended fix path | `<cwd>/devkit/DOCTOR.md` § Graduated issues |
| Triage report | Inline table | Step 4 |

## Progress emission

Emit `Step X/4 — <title>` at the start of each step, unconditionally.

**Step 1/4 — Tally the ledger**

```bash
.claude/scripts/script-doctor-tally.sh devkit/DOCTOR.md
```

Exit 3 means no ledger — stop per the precondition above. Exit 2 means the file is not a
ledger — stop and say so; do not repair it.

Read `DOCTOR_ROWS`, `DOCTOR_LOGGED`, `DOCTOR_GRADUATED`, `DOCTOR_GROUPS`,
`DOCTOR_AT_THRESHOLD`, the `CLASS_<class>=` counts, and one `TRIAGE=` row per signature at
the threshold, most recurrent first:

```
TRIAGE=<count>|<logged>|<graduated>|<skill+mode>|<signature>|<first-date>|<last-date>
```

**The script owns everything decidable** — parsing, grouping, counting, and the threshold
(3 occurrences ever, no time window). Never recount by hand and never override the
threshold.

**`DOCTOR_AT_THRESHOLD=0` ends the run.** Skip Steps 2 and 3, report the tally at Step 4
as a clean bill of health. Nothing recurring means nothing to graduate — do not go
looking for patterns the script did not flag.

**Step 2/4 — Diagnose each flagged signature**

For each `TRIAGE=` row, in order, read only that signature's rows in the ledger for their
context text, then write:

- **Diagnosis** — 2–3 lines on the underlying *harness* defect: what in the machinery makes
  this keep happening. Not what the user did; not what the code under test did.
- **Recommended fix path** — the concrete change and where it lives (script, protocol step,
  ref, template), phrased as a brief for a later session.

Anti-fabrication: diagnose from the rows in front of you. If the context lines do not
support a cause, say so — `Cause not determinable from the logged context; add detail to
future rows` is a valid diagnosis and a better one than a guess.

**Step 3/4 — Graduate on the ledger**

Two edits to `devkit/DOCTOR.md` per flagged signature, and nothing else:

1. Append a block under `## Graduated issues`:

```markdown
### [YYYY-MM-DD] <signature> — <skill+mode>
**Occurrences**: <count> (first <first-date>, latest <last-date>)
**Diagnosis**: <2–3 lines from Step 2>
**Recommended fix**: <fix path from Step 2>
```

2. Flip that signature's `logged` rows to `graduated` in the `## Incidents` table. Change
   the status cell only — never edit, merge, reorder, or delete an incident row, and never
   add a section below the Incidents table (the appender writes at end of file).

**Step 4/4 — Report**

One inline table, then the closing message:

| Signature | Skill | Occurrences | Status | Recommended fix |
|---|---|---|---|---|
| `<signature>` | `<skill+mode>` | `<count>` | graduated | `<one line>` |

Follow it with the class totals (`CLASS_<class>=`) and the ledger totals as one line of
prose — the shape of what is failing, not a metric.

**Closing message** per [`../../shared/refs/closing-message.md`](../../shared/refs/closing-message.md),
as the last chat output. Protocol: 🟢 when nothing reached the threshold · 🟡 when
signatures graduated (they need the human's judgment) · 🔴 only when the run could not
read the ledger. On 🟡, **step 1 is always: start a new session to fix the graduated
issue(s), quoting the block(s) from `devkit/DOCTOR.md`** — this mode does not offer to do
it, and does not do it if asked mid-run.

## References

- `../../shared/refs/doctor-logging.md` — the two logging channels, the signature-class enum, and the appender every skill writes rows through
- `.claude/scripts/script-doctor-tally.sh` — the tally: groups rows by skill + signature, flags every group at 3+ occurrences with at least one row still `logged`
- `.claude/scripts/script-doctor-log.sh` — the appender (write path; this mode never calls it)
- `refs/init/templates/template-DOCTOR.md` — the scaffold `/msg --init` writes to `devkit/DOCTOR.md`
- `../../shared/refs/closing-message.md` — the closing message every run ends with
