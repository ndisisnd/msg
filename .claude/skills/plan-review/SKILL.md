---
name: plan-review
description: >
  Staff PM contract certifier. Reads an existing PRD and runs a fixed seven-check
  certification, each check tied to a named downstream consumer. Picks the
  product check or the eng check from the PRD's content, auto-fixes every Critical
  and Major, logs Minors without asking, and stops only for a product decision.
  Writes one AHA learning per auto-fixed Critical/Major so the next plan-pm draft
  self-heals, logs findings to reports/review-prd-[n]-[slug].md, and ends with one
  result block. Use it when the user says "certify the PRD", "review the PRD",
  "check the PRD before plan-em", or invokes /plan-review.
argument-hint: "[<prd-path>]"
allowed_tools:
  - AskUserQuestion
  - Bash
  - Read
  - Edit
---

# plan-review

## Usage

**Invoke**: `/plan-review [prd-path]` — a manual step the user can run at any time.

- Natural language: "certify the PRD", "review the PRD", "run the contract certifier", "check the PRD before plan-em"
- Context: a path to an existing PRD `.md` file, or a run right after `plan-pm` or `plan-em` saved one
- plan-pm and plan-em run it at the end of their run when their auto-review switch is on, and plan-em runs it before engineering when the PRD has no stamp.

The skill picks the **product check** (checks 1, 2, 3, 6) or the **eng check** (checks 2, 4, 5, 6, 7) by itself. `refs/certification.md` owns the checks, the severity rubric and the findings-table schema. Scripts handle PRDs written before v5.4.

## Posture

A certifier, not an adversarial reviewer: run the selected check's subset and nothing else — no check without a consumer.
Never interview the user. The only question is one batched product-decision pause.

## Inputs

| Name | Format | Required | Source |
|------|--------|----------|--------|
| PRD file path | `.md` file matching `features/prd-*/prd-*.md` | Yes (asked if missing) | User message, or the skill that ran it |
| `devkit/` files | `AHA.md`, `OPEN-QUESTIONS.md`, `PLATFORMS.md` | No | Each is used when present and skipped silently when absent |

## Outputs

| Name | Destination |
|------|-------------|
| Findings ledger | `<prd-dir>/reports/review-prd-[n]-[slug].md`, written by `script-ledger.py` once, after the fixes |
| Revised PRD | `RESOLVED_PATH` — every Critical/Major fix, and the normalised Open questions table |
| Certification stamp | PRD frontmatter, via `script-prd-stamp.sh --certify` — written only when no Critical stays open |
| Self-healing learnings | `devkit/AHA.md`, one `[tune:<category>]` entry per auto-fixed Critical/Major |
| Result block | Inline, at the end of the run (`refs/protocol-review.md` Step 3) |

**The stamp is the gate, the report is the evidence.** `script-cert-status.sh` and plan-em read the stamp and the open Criticals in the report.

## Step-by-step protocol

Follow `refs/protocol-review.md` end to end — Steps 1–3 (resolve and select → certify → fix, record, stamp, report).

**Closing message:** end every run with the closing message per `../shared/refs/closing-message.md`, after the result block. When plan-em runs this skill inline, plan-em's digest carries the result and plan-em closes the run.

**Harness incidents:** log unexpected script failures, tool errors, retries and missed writes to `devkit/DOCTOR.md` per `../shared/refs/doctor-logging.md`.

## References

- `refs/protocol-review.md` — the three-step protocol
- `refs/certification.md` — the seven checks, consumers, severity rubric, findings-table schema, AHA categories
- `.claude/scripts/` — `script-cert-preflight.sh` (path + check type), `script-cert-mech.py` (checks 4, 5, 6 structure), `script-ledger.py` (the ledger), `script-prd-stamp.sh --certify` (the stamp), `script-aha.sh` · `script-openq.sh` (devkit writers)
