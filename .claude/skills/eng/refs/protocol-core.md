---
name: eng shared spine
description: The eng mode spine — Step 0 hard-fail messages, input validation, the one-pass pre-flight, the --plan summary gate, coding standards, mode dispatch, and continuous scope enforcement
type: reference
---

# eng — the shared spine (Steps 0–6)

Loaded from `../SKILL.md`. The numbered steps run for every mode and point to the active mode file where the path diverges.

## Step 0 — Mode flag checks

The routing table (which flag reads which file) lives in `../SKILL.md` only.

Exactly one mode flag must be present (`--plan` | `--build` | `--review` | `--bug`). Zero or more than one:

```
Hard failure: exactly one mode flag required (--plan | --build | --review | --bug). Got: <list>.
```

`--todo` is not a mode — `eng --plan` writes the todos in the same pass:

```
Hard failure: --todo is no longer a mode — todos are written by `eng --plan` in the same pass. Re-run with --plan.
```

Stop on either. Otherwise read the active mode file **fully** first — it defines the mode's input rules, work steps and output contract.

---

## Step 1 — Input validation

Two input sources. The **PRD/exec-table source** is the default for `--plan` and `--build`; **`report`** is the alternate on both.

**`--bug` skips Steps 1–4** until it hands off: `build/bug-report.md` writes the report, then the run continues as `--build report=<that file>`.

**`--review` skips Steps 1–4.** Its input is the working diff — no `prd-path`, `rows`, `agent` or `report`, and no preceding build. It resolves its own change set (`review/protocol.md` Step 1) and goes straight to Step 5. An optional `prd-path` and injected ticket context are used when supplied.

### PRD/exec-table source

Hard-refuse if any field is missing:

| Field | Value |
|-------|-------|
| mode flag | `--plan` or `--build` |
| `prd-path` | Path to the PRD `.md` file containing the execution table |
| `rows` | Semicolon-separated exec-table Feature identifiers — each the exact `<ID>: <name> — <concern>` text of a Feature cell (e.g. `F2: Track streak — Schema migration`) |
| `agent` | This invocation's agent identity (e.g. `eng-backend`) — the exec-table **Agent** column value; names the `## Engineering — <agent>` heading and confirms row ownership |

```
Hard failure: missing required field(s): <list>. Provide the mode flag, prd-path, rows, and agent to continue.
```

Stop. The active mode file may add mode-specific input rules — apply those too.

### Alternate source

**`report=<path>`** — work from a failed run's issues file (`report-prd-<N>-<K>.json`) instead of an exec-table. `--build` → `build/fix-build.md`; `--plan` → `plan/fix-plan.md`. Each owns its required fields, rejections and output. Passing more than one input source is a hard failure (ambiguous source).

---

## Step 2 — Pre-flight: read everything in one pass

Read the spec, devkit and relevant codebase files in one consolidated scan, before any output.

**Orchestrated fast path (scoped context injected).** When an orchestrator injected **scoped excerpts** — the assigned rows, the relevant PRD feature sections, a devkit **digest** — work from those. Do **not** re-read the full PRD or every devkit file. The PRD path is the escape hatch: read it (or one devkit file) only when an excerpt cannot resolve a row.

**Standalone path.** `--build` reads the PRD through the digest (`build/protocol.md` step 2). `--plan` reads the full PRD at `prd-path` and selects the rows whose **Feature** text matches the assigned `rows`. Either way, **verify ownership mechanically** — never by eye:

```bash
G=.claude/scripts/script-prd-digest.py; [ -f "$G" ] || G="$HOME/.claude/scripts/script-prd-digest.py"; python3 "$G" "<prd-path>" --verify-rows "<rows>" --agent <agent>
```

`ROWS_OK` (exit 0) means every named row exists and this agent owns it. Exit 1 prints one `Hard failure:` line per offending row — emit them verbatim and stop. The `report` source has no exec-table and no ownership to confirm.

**Devkit files** (in parallel, unless a digest was injected): `devkit/AHA.md` (carry forward at most ~5 entries matching the assigned rows, never the whole ledger), `devkit/GLOSSARY.md` (canonical terms; flag PRD deviations), `CLAUDE.md` (tech-stack constraints on every path and approach), `devkit/ARCHITECTURE.md` (validate scope against system layers; flag conflicts as gaps), `devkit/DESIGN-SYSTEM.md` (reusable components). No `devkit/` → one warning, continue; a missing single file → a per-file warning, continue.

**Codebase scan** (in parallel): read the files relevant to the assigned rows, matched by concern (schema migration → migrations/schema; API contract → handlers, routes, OpenAPI; client → screens/pages, components, services; tests → existing test files; webhook → emitters, queue handlers). For each, note **Modify** (exists) or **Create**, plus naming conventions, patterns and constraints. All implementation paths derive from this scan and the spec; a `report`'s `issues[].file` marks where a *symptom* was seen, not a path to edit blindly.

Emit no output during pre-flight.

---

## Step 3 — Summary + approval gate (`--plan` only)

`--build` has no opening question — it checks its tickets and starts (`build/protocol.md`). `--review` has none either.

On `--plan`, emit a **short summary** (3–4 lines; content per `plan/protocol.md`), then ask:

```
AskUserQuestion:
  "Does this summary look right?"
  Options:
    - Yes, proceed
    - No, needs correction
    - I have a follow-up question
```

- **Yes, proceed:** continue to Step 4.
- **No, needs correction:** rewrite the summary once with the correction and re-ask; still rejected → stop and ask the user to clarify scope.
- **I have a follow-up question:** run the interview (Step 3a), then re-present the summary.

Never proceed without an explicit "Yes, proceed". Under an autonomy contract (an orchestrator running hands-off) the gate is pre-approved.

### Step 3a — User interview (on demand)

Ask up to 3 focused questions, one at a time — each naming the row or PRD section it concerns, with 3–4 concrete `AskUserQuestion` options (never open-ended). More than 3 ambiguities → list them and ask which to prioritise. Then resume where the protocol paused.

---

## Step 4 — Coding standards (`--build` only)

`--plan` does not call `/cook`; its plan and tickets rest on the `CLAUDE.md` + `devkit/ARCHITECTURE.md` stack constraints. On `--build`, an injected `standards payload` wins and `/cook` is never called. A manual build without one resolves its flags with `script-eng-cook-flags.py` and the standards cache (`build/protocol.md` step 3).

---

## Step 5 — Run the active mode's work

- `--plan` → in one pass, append `## Engineering — <Agent>` and write the `## Todos — <Agent>` tickets for each owned F-ID. No exec-table cell is filled by hand — `script-em-exec-skeleton.py --fill-files` derives the Files column from the tickets. No implementation code.
- `--build` → run the build loop (`build/protocol-packet.md`) and emit the build summary.
- `--review` → resolve the change set, review it adversarially, fix what is unambiguous, return the findings payload (`review/protocol.md` § Return contract).

**Closing message (every mode, every verdict):** end the run with the closing message per `../../shared/refs/closing-message.md` — the last chat output.

**Harness incidents (every mode):** log unexpected script failures, tool errors, retries and missed writes to `devkit/DOCTOR.md` per `../../shared/refs/doctor-logging.md` — logging never changes what the run does next.

---

## Step 6 — Scope enforcement (continuous)

Act only on what the assigned rows specify: no extra refactors, unrelated file touches or out-of-scope changes. A row that the PRD, exec-table or codebase scan cannot resolve:

- `--plan` / `--review` → surface it as a named gap.
- `--build` → `build/protocol-packet.md` § Unclear requirements (ask when a user is present; assume, state and log when the run is automatic).
