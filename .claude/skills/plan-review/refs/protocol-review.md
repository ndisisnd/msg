---
name: plan-review protocol
description: The three-step certification protocol — resolve + tune-select + digest read, run the checks, then auto-fix / self-heal / stamp / recommend
type: reference
---

# Step-by-step protocol

`[n]` is derived from the parent directory name of the input PRD (e.g., `features/prd-3/prd-3.md` → `n=3`).

**The findings report is the only file this skill creates**, and `script-ledger.py` creates it — never author it by hand. Everything else is an in-place edit of files that already exist; no other new file or folder is created at any step.

**Step 1/3 — Resolve path, read PRD, auto-select tune type**

**Run pre-flight:**

Run the pre-flight script via Bash, passing any path hint supplied at invocation as the first argument (omit the argument if no path was given). The script ships with this skill in the global scripts dir, so resolve it there when the current project has no vendored copy — never assume the CWD contains it:

```bash
S=.claude/scripts/script-cert-preflight.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-cert-preflight.sh"; "$S" "<path-hint>"   # drop the "<path-hint>" argument if none was given
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
G=.claude/scripts/script-prd-digest.py; [ -f "$G" ] || G="$HOME/.claude/scripts/script-prd-digest.py"; python3 "$G" "$RESOLVED_PATH" --slice product     # product tune
# or, for an eng tune:
python3 "$G" "$RESOLVED_PATH" --slice eng-audit
```

`certification.md` owns which slice each tune reads, what it contains, and the `prose_lines` escape hatch for details the slice omits. The generator re-parses the current PRD on every call, so the slice is never stale (`../../shared/refs/session-cache.md`).

**Exclude the findings ledger from every check.** This skill's own output is historical record, not certifiable content. On a v5.4 PRD that falls out for free — the ledger is a separate file the digest never opens. On a PRD written before v5.4 the **Plan review findings** section (and any legacy `## Audit — YYYY-MM-DD` section) sits inside the PRD, and the digest slice omits it. Either way, never treat a prior finding's "What is wrong" cell as a fresh instance of the problem it describes; the dedup rule in Step 2 governs how prior findings interact with this run.

**Read `devkit/AHA.md` if present** — for the recurrence count in Step 3 and to note any `[tune:*]` learning already recorded. Absent → the self-healing writeback is skipped in Step 3.

**Step 2/3 — Run the certification**

**Run the mechanical checks first.** `script-cert-mech.py` owns every check whose verdict is decidable from the PRD text: check 4 (F-ID coverage, empty Files, execution-table collisions), check 5 (ticket-graph cycles, unknown ticket ids, missing `done-when`) and check 6's structure (frontmatter-graph acyclicity, edge-target existence, platform bucket coverage).

```bash
S=.claude/scripts/script-cert-mech.py; [ -f "$S" ] || S="$HOME/.claude/scripts/script-cert-mech.py"
python3 "$S" "$RESOLVED_PATH" --checks 6        # product tune
python3 "$S" "$RESOLVED_PATH" --checks 4,5,6    # eng tune
```

Each `FINDING check=… sev=… code=… ref=… detail=…` line becomes one ledger row, with `Severity` taken from `sev` and the category taken from `code`. `SKIP` lines mean a facet had no input — record nothing. **Exit 0** = clean, **exit 1** = findings emitted, **exit 2** = the PRD is unreadable or has no frontmatter: stop and report it, do not certify.

**Adjudicate the rest yourself.** The tune's remaining checks are judgment, not parsing — **Product:** 1, 2, 3. **Eng:** 2, 7. Apply them from `certification.md` against the slice read in Step 1.

One finding per issue, from either source. Every "What is wrong" cites the section + which check fired; every "Why it matters" names the consumer that would break. `#`, `Date` and `Status` are the script's to set, not yours.

**Write the findings ledger.** Hand this run's findings to `script-ledger.py` as JSON. It owns choosing the ledger's home, creating the report from the template when absent, deduping against prior rows, the monotonic `#`, and the `Clean` marker row:

```bash
S=.claude/scripts/script-ledger.py; [ -f "$S" ] || S="$HOME/.claude/scripts/script-ledger.py"
echo '[{"severity":"Critical","what":"<section + which check fired>","fix":"<concrete action>","why":"<the consumer that breaks>"}]' \
  | python3 "$S" "$RESOLVED_PATH" --auditor P     # --auditor E for an eng tune
```

**Where it writes, and why you do not choose:** an existing `<prd-dir>/reports/review-prd-[n]-[slug].md` wins; else an existing findings section already inside the PRD (so a pre-v5.4 file keeps its ledger where it is, Auditor column and all); else a new report is created from `template-review-report.md`. `--auditor` is written into a legacy in-PRD row and ignored for the report, whose single mode has a single auditor. Read `LEDGER_TARGET=` and `LEDGER_FILE=` back to know which home was used.

Report a finding on every run it is still present: the script recognises a repeat by its "What is wrong" text and updates that row in place (`Status` → `Still open`, `Date` → today) rather than duplicating it. Omitting a finding leaves its row untouched — that is how a row you already marked `Fixed` stays `Fixed`. There is always exactly one table; never start a second file or a second table.

Read back each `LEDGER_ROW=<#> <added|carried> <severity>` line for the row numbers Step 3 needs. **Exit 2** = malformed findings JSON, or a findings table whose header is missing a canonical column: report it and stop — never hand-edit the table into shape.

**No-findings path:** send `[]`. The script writes the `Clean` marker row; skip straight to Step 3's open-questions normalization + frontmatter stamp.

**Step 3/3 — Auto-fix, self-heal, stamp, recommend**

**Auto-fix every Critical and Major.** For each Critical/Major finding, patch the exact PRD section(s) it cites — product sections in a product tune; engineering sections (add a missing API-contract row, cover an uncovered F-ID, break a dependency cycle, resolve an OPEN decision with a stated path) in an eng tune. In a Product tune, `## Engineering —` sections are out of scope; do not edit them. Set each fixed finding's ledger `Status` → `Fixed`.

**Product-decision pause (the only hard gate).** A finding whose fix requires choosing between product behaviors — e.g. two acceptance criteria genuinely contradict and either resolution changes the product — is **never** auto-fixed. Batch every such finding into one `AskUserQuestion` (≤4 per call, same shape as plan-pm's open-questions pause), each with a suggested resolution. Apply the chosen resolutions, then mark those rows `Fixed`. This is the only place the run stops.

Any product-decision finding the user leaves undecided is logged to the project's ambiguity log rather than silently dropped:

```bash
S=.claude/scripts/script-openq.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-openq.sh"
bash "$S" devkit/OPEN-QUESTIONS.md --title "<short title>" --question "<the decision>" \
  --severity high --context "<PRD section + which check fired>" --raised-by plan-review
```

The script appends into the open section only and never touches `## Resolved`. **Exit 3** = no `devkit/OPEN-QUESTIONS.md`: skip the log, note it inline. **Exit 2** = malformed input or a file with no open section: fix the call, do not hand-edit the file.

**Emit the auto-fix terminal table.** After the fixes land, emit the `# | Sev | Found | Fixed` table (`certification.md`) — one row per auto-fixed Critical/Major, 1–2 lines per cell. The user always *sees* what the machine changed without being gated on it.

**Self-healing writeback.** `script-aha.sh` owns the recurrence count and the append; you author the entry text.

1. **Recurrence count first.** For each category this run touched:

   ```bash
   S=.claude/scripts/script-aha.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-aha.sh"
   bash "$S" devkit/AHA.md --count "tune:<category>"
   ```

   If `AHA_COUNT` plus this run's pending entries reaches **≥3**, emit a **protocol-repair flag** inline: `[tune:<category>] recurs across ≥3 runs — fix the drafting protocol, not the PRDs:` naming the specific `plan-pm` ref (or the intake rubric) to amend. This is an improve-plan candidate, not a PRD edit.

2. **Write one learning per auto-fixed Critical/Major**, using the canonical categories in `certification.md`:

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

**Frontmatter stamp (always run, including the no-findings path):** Stamp certification onto the PRD frontmatter via the shared scalar writer (two-path resolution) so downstream consumers (plan-em's certification preconditions, roadmap readiness, `/plan` sequencing) can trust it. It rewrites the single frontmatter line and is idempotent. **This stamp, not the report, is the gate signal:**

```bash
S=.claude/scripts/script-prd-stamp.sh; [ -f "$S" ] || S="$HOME/.claude/scripts/script-prd-stamp.sh"; bash "$S" "$RESOLVED_PATH" reviewed yes
```

v5.4 fused the two tune stamps into this one `reviewed:` field. **The discriminator is the tune pair, not `reviewed` itself** — a PRD written before v5.4 carries `reviewed:` too, but its gate is the pair, so stamping `reviewed` alone would leave it uncertified. If the frontmatter has a `product-tuned:` or `eng-tuned:` line, stamp that pair instead — `bash "$S" "$RESOLVED_PATH" product-tuned yes` for a product tune, `eng-tuned yes` for an eng tune — and leave `reviewed:` alone. `script-cert-status.sh` reads the same way round, so the two never disagree.

**Terminate (recommend-only).** Emit `PRD certified.` (or `PRD certified — no findings.` on the clean path). Then recommend the next step **without invoking it**:
- **Product tune** → recommend `/plan-em <RESOLVED_PATH>` (or `/plan-pm` to redraft if fixes were substantial).
- **Eng tune** → recommend `/eng --build` / re-invoking `/plan-em` in build mode.

When `plan-em` invoked this tune inline as a certification precondition, it drives the next step itself — this recommendation is for the standalone-invocation path.
