---
name: plan-tune
description: >
  Staff PM contract certifier. Reads an existing PRD and runs a fixed
  seven-check certification — each check tied to a named downstream
  consumer (regression authoring, pre-merge's PRD-consistency gate, the safety
  pauses, eng --build's row/ticket reads). Product tune (--product) runs checks
  1/2/3/6; eng tune (--eng) runs 2/4/5/6/7. Auto-selects the tune type from PRD
  content (no ask), auto-fixes every Critical and Major with a compact terminal
  table, asks once about Minors, and pauses only for a product-decision finding.
  Each auto-fixed Critical/Major writes a category-tagged learning to
  devkit/AHA.md so the next plan-pm draft self-heals. Applies all fixes directly
  to the PRD file. No separate report file.
argument-hint: "[<prd-path>] [--product | --eng]"
allowed_tools:
  - AskUserQuestion
  - Bash
  - Read
  - Edit
---

# plan-tune

## Usage

**Invoke**: `/plan-tune [prd-path] [--product | --eng]`

- Slash command: `/plan-tune`
- Natural language: "tune the PRD", "certify the PRD", "run the contract certifier", "check the PRD before plan-em"
- Context: a path to an existing PRD `.md` file, or invocation immediately after `plan-pm` or `plan-em` saved one

**Flags:** `--product` (product tune) · `--eng` (eng tune) · neither → auto-selected in Step 1.
`refs/certification.md` owns the checks, which tune runs which, the severity rubric, and the findings-table schema.

Path resolution and validation belong to `plan-tune-preflight.sh` (Step 1) — this skill never re-derives them.

## Posture

A certifier, not an adversarial reviewer: run the tune's check subset and nothing else — no check without a consumer.
Never interview the user; a fix that needs a product decision is escalated as one batched pause, never a conversation.

## Inputs

| Name | Format | Required | Source |
|------|--------|----------|--------|
| PRD file path | `.md` file path matching `features/prd-*/prd-*.md` | Yes (asked if missing) | User message, directory path, or description |
| Tune type flag | `--product` or `--eng` | No — **auto-selected** if missing (never asked) | User message at invocation, or forwarded by `plan-em` |
| `devkit/AHA.md` | Project learning log | No — self-healing writeback skipped if absent | Read + appended in Steps 1/3 if present |
| `devkit/OPEN-QUESTIONS.md` | Ambiguity log | No — deferred-decision log skipped if absent | Appended in Step 3 if present |
| `devkit/PLATFORMS.md` | Per-platform tolerance profiles | No — check 6's bucket-coverage facet is skipped if absent | Read by `script-cert-mech.py` (eng tune) |

## Outputs

| Name | Format | Destination |
|------|--------|-------------|
| Selected tune type | `Tune type: Product` or `Tune type: Eng` emitted inline | Emitted at end of Step 1 |
| Certification findings | Rows in the findings-table schema (`refs/certification.md`) | Written into the PRD's **§7 Plan tune findings** section (created once, appended thereafter) |
| Auto-fix terminal table | `# \| Sev \| Found \| Fixed` (`refs/certification.md`) | Emitted inline after fixes (Step 3) |
| Self-healing learnings | Category-tagged `[tune:<category>]` entries | Appended to `devkit/AHA.md` (Step 3), one per auto-fixed Critical/Major |
| Recurrence protocol-repair flag | Inline warning when a category recurs across ≥3 runs | Emitted inline (Step 3) |
| Open questions table | Normalized to `# \| Question \| Answer \| Status` | `RESOLVED_PATH` Open questions section (edited in place) |
| Revised PRD | Updated `.md` file with all Critical/Major (and selected Minor) fixes applied | `RESOLVED_PATH` (edited in place) |
| Frontmatter stamp | `product-tuned: yes` / `eng-tuned: yes` after a successful run | `RESOLVED_PATH` frontmatter |

`[n]` is derived from the parent directory name of the input PRD (e.g., `features/prd-3/prd-3.md` → `n=3`).

**No new files or folders are created at any step.**

## Run output

**Closing message (both tune types, every outcome):** end the run with the closing message per `../shared/refs/closing-message.md` — the last chat output, after the certification verdict / auto-fix table.

**Harness incidents (both tune types):** log unexpected script failures, tool errors, retries, and missed writes to `devkit/DOCTOR.md` per `../shared/refs/doctor-logging.md` — logging never changes what the run does next.

## Step-by-step protocol

**Step 1/3 — Resolve path, read PRD, auto-select tune type**

**Run pre-flight:**

Run the pre-flight script via Bash, passing any path hint supplied at invocation as the first argument (omit the argument if no path was given). The script ships with this skill in the global scripts dir, so resolve it there when the current project has no vendored copy — never assume the CWD contains it:

```bash
S=.claude/scripts/plan-tune-preflight.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/plan-tune-preflight.sh"; "$S" "<path-hint>"   # drop the "<path-hint>" argument if none was given
```

Parse the `KEY=VALUE` output lines.

- Any `ERROR=` value (`no_path`, `invalid_pattern`, `not_found`) — ask via `AskUserQuestion` for a file path or a directory, then re-run the script with the answer. After two failed attempts, refuse, emit the expected pattern (`features/prd-N/prd-N.md`), and offer to run `/plan-pm` to create a new PRD.

On `exit 0`, read the output:
- `RESOLVED_PATH` — the canonical PRD file path; use it for all subsequent reads and edits.
- `PRD_N` — the numeric `n`; use it wherever `[n]` appears in this skill.
- `TUNE_SUGGESTION` — `product` or `eng`; this is the **auto-selection decision** below (not a suggestion the user confirms).

**Auto-select the tune type (no ask):**

- `--product` provided → **Product** (checks 1, 2, 3, 6). Emit `Tune type: Product (--product flag set)`.
- `--eng` provided → **Eng** (checks 2, 4, 5, 6, 7). Emit `Tune type: Eng (--eng flag set)`.
- Neither flag → **use `TUNE_SUGGESTION` as the decision**. Emit `Tune type: [Product / Eng] (auto-selected)`. **Do not ask the user.**

**Read PRD (via digest slice, not full prose):**

Do **not** read the full PRD file. Run the digest generator for the tune's slice and consume the JSON it prints; hold it as `<prd>`:

```bash
G=.claude/scripts/scan-prd-digest.py; [ -f "$G" ] || G="$HOME/.claude/scripts/scan-prd-digest.py"; python3 "$G" "$RESOLVED_PATH" --slice product     # product tune
# or, for an eng tune:
python3 "$G" "$RESOLVED_PATH" --slice eng-audit
```

`refs/certification.md` owns which slice each tune reads, what it contains, and the `prose_lines` escape hatch for details the slice omits. The generator re-parses the current PRD on every call, so the slice is never stale (`../shared/refs/session-cache.md`).

**Exclude the §7 ledger from every check.** The **Plan tune findings** section (this skill's own reserved output, and any legacy `## Audit — YYYY-MM-DD` section) is historical record, not certifiable content — the digest slice naturally omits it. Never treat a prior finding's "What is wrong" cell as a fresh instance of the problem it describes; the dedup rule in Step 2 governs how prior findings interact with this run.

**Read `devkit/AHA.md` if present** — for the recurrence count in Step 3 and to note any `[tune:*]` learning already recorded. Absent → the self-healing writeback is skipped in Step 3.

**Step 2/3 — Run the certification**

**Run the mechanical checks first.** `script-cert-mech.py` owns every check whose verdict is decidable from the PRD text: check 4 (F-ID coverage, empty Files, execution-table collisions), check 5 (ticket-graph cycles, unknown ticket ids, missing `done-when`) and check 6's structure (frontmatter-graph acyclicity, edge-target existence, platform bucket coverage).

```bash
S=.claude/scripts/script-cert-mech.py; [ -f "$S" ] || S="$HOME/.claude/scripts/script-cert-mech.py"
python3 "$S" "$RESOLVED_PATH" --checks 6        # product tune
python3 "$S" "$RESOLVED_PATH" --checks 4,5,6    # eng tune
```

Each `FINDING check=… sev=… code=… ref=… detail=…` line becomes one ledger row, with `Severity` taken from `sev` and the category taken from `code`. `SKIP` lines mean a facet had no input — record nothing. **Exit 0** = clean, **exit 1** = findings emitted, **exit 2** = the PRD is unreadable or has no frontmatter: stop and report it, do not certify.

**Adjudicate the rest yourself.** The tune's remaining checks are judgment, not parsing — **Product:** 1, 2, 3. **Eng:** 2, 7. Apply them from `refs/certification.md` against the slice read in Step 1.

One finding per issue, from either source. Every "What is wrong" cites the section + which check fired; every "Why it matters" names the consumer that would break. `#`, `Date`, `Auditor` and `Status` are the script's to set, not yours.

**Write the §7 ledger.** Hand this run's findings to `script-ledger.py` as JSON. It owns locating or creating the **Plan tune findings** section, deduping against prior rows, the monotonic `#`, and the `Clean` marker row:

```bash
S=.claude/scripts/script-ledger.py; [ -f "$S" ] || S="$HOME/.claude/scripts/script-ledger.py"
echo '[{"severity":"Critical","what":"<section + which check fired>","fix":"<concrete action>","why":"<the consumer that breaks>"}]' \
  | python3 "$S" "$RESOLVED_PATH" --auditor P     # --auditor E for an eng tune
```

Report a finding on every run it is still present: the script recognises a repeat by its "What is wrong" text and updates that row in place (`Status` → `Still open`, `Date` → today) rather than duplicating it. Omitting a finding leaves its row untouched — that is how a row you already marked `Fixed` stays `Fixed`.

Read back each `LEDGER_ROW=<#> <added|carried> <severity>` line for the row numbers Step 3 needs. **Exit 2** = malformed findings JSON, or a §7 table whose header is missing a canonical column: report it and stop — never hand-edit the table into shape.

**No-findings path:** send `[]`. The script writes the `Clean` marker row; skip straight to Step 3's open-questions normalization + frontmatter stamp.

**Step 3/3 — Auto-fix, self-heal, stamp, recommend**

**Auto-fix every Critical and Major.** For each Critical/Major finding, patch the exact PRD section(s) it cites — product sections in a product tune; engineering sections (add a missing API-contract row, cover an uncovered F-ID, break a dependency cycle, resolve an OPEN decision with a stated path) in an eng tune. In a Product tune, `## Engineering —` sections are out of scope; do not edit them. Set each fixed finding's ledger `Status` → `Fixed`.

**Product-decision pause (the only hard gate).** A finding whose fix requires choosing between product behaviors — e.g. two acceptance criteria genuinely contradict and either resolution changes the product — is **never** auto-fixed. Batch every such finding into one `AskUserQuestion` (≤4 per call, same shape as plan-pm's open-questions pause), each with a suggested resolution. Apply the chosen resolutions, then mark those rows `Fixed`. This is the only place the run stops.

Any product-decision finding the user leaves undecided is logged to the project's ambiguity log rather than silently dropped:

```bash
S=.claude/scripts/script-openq.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-openq.sh"
bash "$S" devkit/OPEN-QUESTIONS.md --title "<short title>" --question "<the decision>" \
  --severity high --context "<PRD section + which check fired>" --raised-by plan-tune
```

The script appends into the open section only and never touches `## Resolved`. **Exit 3** = no `devkit/OPEN-QUESTIONS.md`: skip the log, note it inline. **Exit 2** = malformed input or a file with no open section: fix the call, do not hand-edit the file.

**Emit the auto-fix terminal table.** After the fixes land, emit the `# | Sev | Found | Fixed` table (`refs/certification.md`) — one row per auto-fixed Critical/Major, 1–2 lines per cell. The user always *sees* what the machine changed without being gated on it.

**Self-healing writeback.** `script-aha.sh` owns the recurrence count and the append; you author the entry text.

1. **Recurrence count first.** For each category this run touched:

   ```bash
   S=.claude/scripts/script-aha.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-aha.sh"
   bash "$S" devkit/AHA.md --count "tune:<category>"
   ```

   If `AHA_COUNT` plus this run's pending entries reaches **≥3**, emit a **protocol-repair flag** inline: `[tune:<category>] recurs across ≥3 runs — fix the drafting protocol, not the PRDs:` naming the specific `plan-pm` ref (or the intake rubric) to amend. This is an improve-plan candidate, not a PRD edit.

2. **Write one learning per auto-fixed Critical/Major**, using the canonical categories in `refs/certification.md`:

   ```bash
   bash "$S" devkit/AHA.md --tag "tune:<category>" \
     --summary "<one line>" --why "<what the PRD kept getting wrong>" --note "<what future drafts should do>"
   ```

   **Exit 3** = no `devkit/AHA.md`: skip the whole writeback, note it inline. **Exit 2** = a missing leg or a file with no `## Entries` heading: fix the call, do not hand-edit the file.

**Ask once about Minors.** If any Minor findings remain, ask via one `AskUserQuestion`: **Fix minors** (apply and mark `Fixed`) / **Leave logged** (keep `Status = Open`). One question, no multiSelect per-severity. If there are zero Minors, skip the ask.

**Open questions normalization (always run, even on the no-findings path):** Normalize the PRD's **Open questions** section into `# | Question | Answer | Status`:
- Bullet list → one row per item (question text → `Question`; inline answer → `Answer`).
- Already a table → leave `Question`/`Answer`, only recompute `Status`.
- `Status` = `Addressed` when `Answer` is non-empty and non-placeholder, else `Open`. Idempotent.

**Frontmatter stamp (always run, including the no-findings path):** Stamp the tune onto the PRD frontmatter via the shared scalar writer (two-path resolution) so downstream consumers (plan-em's certification preconditions, roadmap readiness, `/plan` sequencing) can trust it. It rewrites the single frontmatter line and is idempotent:
- Product tune → `product-tuned: yes`: `S=.claude/scripts/stamp-prd.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/stamp-prd.sh"; bash "$S" "$RESOLVED_PATH" product-tuned yes`
- Eng tune → `eng-tuned: yes`: `bash "$S" "$RESOLVED_PATH" eng-tuned yes` (same resolved `$S`).

**Terminate (recommend-only).** Emit `PRD certified.` (or `PRD certified — no findings.` on the clean path). Then recommend the next step **without invoking it**:
- **Product tune** → recommend `/plan-em <RESOLVED_PATH>` (or `/plan-pm` to redraft if fixes were substantial).
- **Eng tune** → recommend `/eng --build` / re-invoking `/plan-em` in build mode.

When `plan-em` invoked this tune inline as a certification precondition, it drives the next step itself — this recommendation is for the standalone-invocation path.

## References

- `refs/certification.md` — the seven checks, consumers, severity rubric, findings-table schema, the auto-fix terminal table, and the self-healing AHA loop. The whole certifier definition.
- `.claude/scripts/script-cert-mech.py` — checks 4, 5 and 6's structure, mechanised.
- `.claude/scripts/script-ledger.py` — the §7 findings ledger: locate/create, dedup, monotonic `#`, clean row.
- `.claude/scripts/script-aha.sh` · `.claude/scripts/script-openq.sh` — the shared devkit writers.
