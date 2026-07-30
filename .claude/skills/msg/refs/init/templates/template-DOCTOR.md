---
name: DOCTOR Template
description: Template for the harness-incident ledger (devkit/DOCTOR.md) — where the harness itself misbehaved
type: reference
---

# DOCTOR — Harness Incident Ledger

Where the **harness** misbehaved: script failures, tool errors, retries, and writes
that were supposed to happen and didn't. It is telemetry about the machinery, not
about the product.

**One meaning per file — the three devkit logs do not overlap:**

| File | Holds |
|------|-------|
| `AHA.md` | What agents **learned** — mistakes worth not repeating |
| `OPEN-QUESTIONS.md` | What agents **could not decide** |
| `DOCTOR.md` | Where the **harness itself misbehaved** |

**Write-mostly.** Nothing reads this file during a normal run — appending costs
almost nothing. It is read once, on demand, by `/msg --doctor`, which tallies
signatures, graduates recurring ones, and triages. **`/msg --doctor` never fixes
anything**; the fix is a separate session a human invokes with the graduated issue
as its brief.

**Gitignored.** Local telemetry, never committed. Ignored ≠ absent — `/msg --init`
creates it, and it stays on disk.

## Signature classes

A row is only useful if the same failure logs the same way twice, so every row
carries a stable signature: `<class>:<artifact-or-step>` — e.g.
`validator-fail:preflight-check-06`. The class comes from this fixed enum; the
free-text context is for humans and is never tallied.

| Class | Means |
|-------|-------|
| `write-miss` | A write the protocol required did not land (file, row, stamp) |
| `retry` | The same call was made again after a failure, or made more than once |
| `tool-error` | A tool or command failed unexpectedly (not a checked, expected failure) |
| `validator-fail` | A validator or checker script exited non-zero with a named failure |
| `gate-infra` | The gate's own infrastructure broke — CI, deploy, test sandbox, branch protection |

## How rows get here

Two channels, per `.claude/skills/shared/refs/doctor-logging.md`:

1. **Mechanical** — a script call exits non-zero unexpectedly; the caller appends a
   row via `.claude/scripts/script-doctor-log.sh` and then continues or halts per
   the step's own rule.
2. **Model** — the agent notices a tool error, a retry, or a missed write and
   appends a row for it.

Rows are **append-only**. Status starts at `logged`; `/msg --doctor` flips it to
`graduated` when a signature reaches the triage threshold and writes the diagnosis
under *Graduated issues*.

## Graduated issues

<!-- Written only by `/msg --doctor`. One block per graduated signature:

### [YYYY-MM-DD] <class>:<artifact-or-step> — <skill>
**Occurrences**: <n>
**Diagnosis**: 2–3 lines on the underlying harness defect.
**Recommended fix**: the fix path, for a separate human-invoked session.

-->

## Incidents

Newest rows are appended at the bottom. **Nothing may follow this table** — the
appender writes at end of file.

| date | skill+mode | signature | context | status |
|---|---|---|---|---|
