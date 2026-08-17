---
name: PRD lifecycle
description: The one home of the PRD status lifecycle — frontmatter fields, the INTAKE.md row lifecycle, who stamps what, and the status-vs-lane rule
type: reference
---

# PRD lifecycle

The canonical lifecycle of a PRD's status fields and its `INTAKE.md` ledger row.
Cited by `intake`, `plan-pm`, `plan-em`, `plan-review` and `merge`; no skill
restates these tables.

## PRD frontmatter fields

Each PRD carries status fields in its YAML frontmatter. The owning skill updates
the field immediately after completing the relevant work via the shared scalar
writer `.claude/scripts/script-prd-stamp.sh <prd> <field> <value>` (two-path
resolution) — one deterministic edit of the single frontmatter line, never
improvised Bash.

| Field | Initial | Updated by | Updated to | Trigger |
|-------|---------|-----------|-----------|---------|
| `status` | `backlog` | `plan-em` | `specced` | eng sections + todos written to PRD |
| `status` | `specced` | `plan-em` | `wip` | feature branch cut |
| `status` | `wip` | `merge --production` | `complete` | shipped to production |
| `reviewed` | `no` | `plan-review` | `yes` | certification passes |

**`status` is the lifecycle truth; the lane directory is the location truth.**
They answer different questions and neither is derived from the other — a
production ship both stamps `status: complete` and relocates the PRD folder into
the `done/` lane, but a consumer asking "has this shipped?" reads the status and
one asking "where does this file live?" reads the lane.

`reviewed: yes` is the single certification stamp, written by `plan-review` on a
successful run; the findings themselves live in
`<prd-dir>/reports/review-prd-[n]-[slug].md`. It is **orthogonal** to `status`:
`reviewed` records that the contract was certified, `status` records how far
through the pipeline the work is. The two are set independently and never
substitute for each other.

PRDs written before v5.4 carry the old enum (`product` → `eng` → `done`, plus
`retired`) and a `product-tuned`/`eng-tuned` pair instead of `reviewed`. Every
reader normalises those to the table above; no writer emits them. Additional
sign-off stamps (`staging-signoff:`) belong to `merge` and are specified in
`merge/refs/staging.md`.

## INTAKE.md row lifecycle (D14)

intake writes every new row as `backlog`. It never advances a row itself — **in
either mode.** intake's `--update` *reads* `status` as a gate
(`intake/refs/protocol-update.md` § Three edit surfaces) and still never writes
it.

| Status | Set by | When |
|--------|--------|------|
| `backlog` | **intake** | on capture |
| `in-progress` | `plan-pm` | when it creates the PRD and fills the `prd` cell |
| `completed` | `merge --production` | when the mapped PRD ships to `main` |

Every row write goes through the shared ledger writer
`.claude/scripts/script-intake-stamp.sh` (two-path resolution) — a single row
rewrite that leaves every other row byte-identical. plan-pm stamps the source
row when it creates the PRD: `status` cell → `in-progress`, `prd` cell →
`prd-[n]-[feature_slug]` (F4/D14).

The `/msg --gui` Intake tab may hand-edit statuses (same trust level as its
PRD-board edits).
