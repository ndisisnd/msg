---
name: doctor-logging
description: Cross-skill contract for logging harness incidents to devkit/DOCTOR.md — the two channels, the signature classes, the appender
type: reference
---

# Doctor logging — where the harness records its own misbehaviour

`devkit/DOCTOR.md` is the harness-incident ledger: script failures, tool errors,
retries, and writes that were meant to happen and didn't. It is **not** `AHA.md`
(what agents learned) and **not** `OPEN-QUESTIONS.md` (what agents could not
decide). One incident, one row.

**Write-mostly.** Never read `DOCTOR.md` during a run — it carries no context any
skill needs. It is read once, on demand, by `/msg --doctor`.

**Lazy.** If `devkit/DOCTOR.md` is absent the appender exits 3 and writes nothing.
Skip silently and carry on: a missing ledger is not itself an incident, and no
skill creates the file (`/msg --init` does).

## The appender — the only writer

```
.claude/scripts/script-doctor-log.sh devkit/DOCTOR.md \
  --skill <skill> [--mode <mode>] \
  --signature <class>[:<artifact-or-step>] \
  --context "<1–2 lines of what happened>"
```

Exit 0 = row appended · 2 = usage/enum error · 3 = no ledger, skip. Never hand-write
a row into the table, and never let a log failure change the run's own outcome.

**Signature classes (fixed enum — the appender rejects anything else):**
`write-miss` · `retry` · `tool-error` · `validator-fail` · `gate-infra`.
Add the artifact or step after a colon so the same failure keys the same way twice
(`validator-fail:script-preflight-06`, `write-miss:TODOs.json`). Recurrence is what
graduates an incident into a real issue; an unstable signature never graduates.

## Channel 1 — mechanical (the reliable floor)

**Trigger, no judgment: a script this protocol ran exited non-zero, and that exit
code is not one the step's own text documents as an expected outcome.** Append a
row, then continue or halt exactly per the step's existing rule — logging changes
nothing about control flow.

- Class: `validator-fail` for a checker/validator, `write-miss` for a writer that
  did not write, `tool-error` for anything else.
- Step after the colon: the script's name or the artifact it failed on.
- **The eval runner is a caller too:** a failing case in `evals/run.sh` appends one row —
  skill `evals`, signature `validator-fail:eval-<case-slug>`, context = the case's cmd plus
  a one-line diff summary. Same appender, same exit-3 skip when the ledger is absent.
- **Blocking is not the threshold's job:** a failed eval blocks the release immediately, on
  the runner's bare exit code, without waiting for 3 occurrences. The threshold governs live
  incidents; the row exists so `/msg --doctor` sees eval regressions and live incidents in
  one tally.
- **Exempt:** documented "nothing to do" codes — e.g. the `exit 3` that the shared
  appenders (`script-aha.sh`, `script-openq.sh`, `script-doctor-log.sh`) return when
  the target file is absent. A designed skip is not an incident.

## Channel 2 — model (best-effort, accepted as lossy)

Append a row when, in your own run, you notice any of:

1. **A tool error** — a Read/Write/Edit/Bash call failed unexpectedly and you worked
   around it (`tool-error`).
2. **A retry or repeat** — you called the same thing again after a failure, or made
   the same write twice because the first didn't take (`retry`).
3. **A missed write** — a file, row, or stamp the protocol required did not land, and
   you noticed after the fact (`write-miss`).

One row per incident, at the moment you notice it. Do not batch, do not summarise a
run into a single row, and do not log ordinary decisions — those belong in `AHA.md`
or `OPEN-QUESTIONS.md`.

## What reads this

Only [`/msg --doctor`](../../msg/refs/protocol-doctor.md): it tallies signatures,
graduates any that reaches 3 occurrences, and reports. **It never fixes** — fixing
is a separate session a human invokes.
