---
name: plan-review
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
  to the PRD file, and logs its findings to one growing report per PRD at
  reports/review-prd-[n]-[slug].md.
argument-hint: "[<prd-path>] [--product | --eng]"
allowed_tools:
  - AskUserQuestion
  - Bash
  - Read
  - Edit
---

# plan-review

## Usage

**Invoke**: `/plan-review [prd-path] [--product | --eng]`

- Slash command: `/plan-review`
- Natural language: "tune the PRD", "certify the PRD", "run the contract certifier", "check the PRD before plan-em"
- Context: a path to an existing PRD `.md` file, or invocation immediately after `plan-pm` or `plan-em` saved one

**Flags:** `--product` (product tune) · `--eng` (eng tune) · neither → auto-selected in Step 1.
`refs/certification.md` owns the checks, which tune runs which, the severity rubric, and the findings-table schema.

Path resolution and validation belong to `script-cert-preflight.sh` (Step 1) — this skill never re-derives them.

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
| Selected tune type | `Tune type: Product` or `Tune type: Eng` inline | End of Step 1 |
| Certification findings | Findings-table rows (`refs/certification.md`) | `<prd-dir>/reports/review-prd-[n]-[slug].md` — one growing table; a pre-v5.4 PRD keeps its **§7 Plan review findings** section instead |
| Auto-fix terminal table | `# \| Sev \| Found \| Fixed` (`refs/certification.md`) | Inline after fixes (Step 3) |
| Self-healing learnings | Category-tagged `[tune:<category>]` entries | Appended to `devkit/AHA.md` (Step 3), one per auto-fixed Critical/Major |
| Recurrence protocol-repair flag | Inline warning when a category recurs across ≥3 runs | Inline (Step 3) |
| Open questions table | Normalized to `# \| Question \| Answer \| Status` | `RESOLVED_PATH` Open questions section (edited in place) |
| Revised PRD | All Critical/Major (and selected Minor) fixes applied | `RESOLVED_PATH` (edited in place) |
| Frontmatter stamp | `reviewed: yes` (`product-tuned:` / `eng-tuned:` pair on a pre-v5.4 PRD) | `RESOLVED_PATH` frontmatter |

**The stamp is the gate, the report is the evidence.** `reviewed: yes` in the PRD's frontmatter is what `script-cert-status.sh` and `plan-em`'s preconditions read. The report explains *why* the stamp is what it is; it never gates anything on its own. The findings report is the **only file this skill creates**, and `script-ledger.py` creates it (`refs/protocol-review.md`).

## Run output

**Closing message (both tune types, every outcome):** end the run with the closing message per `../shared/refs/closing-message.md` — the last chat output, after the certification verdict / auto-fix table.

**Harness incidents (both tune types):** log unexpected script failures, tool errors, retries, and missed writes to `devkit/DOCTOR.md` per `../shared/refs/doctor-logging.md` — logging never changes what the run does next.

## Step-by-step protocol

Follow `refs/protocol-review.md` end-to-end — Steps 1–3 (resolve + tune-select + digest
read → certification → auto-fix / self-heal / stamp / recommend). It owns the steps,
their order, the script calls, and the only hard gate (the product-decision pause).

## References

- `refs/protocol-review.md` — the three-step protocol; followed from § Step-by-step protocol
- `refs/certification.md` — the seven checks, consumers, severity rubric, findings-table schema, the auto-fix terminal table, and the self-healing AHA loop. The whole certifier definition.
- `refs/template-review-report.md` — the external findings report: where it lives, its frontmatter and column contract, the status-recomputation rule, and how it differs from eng's `review-prd-<N>-<K>.json` build evidence.
- `.claude/scripts/script-cert-mech.py` — checks 4, 5 and 6's structure, mechanised.
- `.claude/scripts/script-ledger.py` — the findings ledger: pick the home, locate/create, dedup, monotonic `#`, clean row.
- `.claude/scripts/script-aha.sh` · `.claude/scripts/script-openq.sh` — the shared devkit writers.
