---
name: PRD Update Protocol
description: The --update mode — target resolution, the deterministic L1 migration, the L2 style pass, the checks 1–6 convergence gate, and what may never change on the way through
type: reference
---

# Update mode (`--update`)

`--update` converges an **existing** PRD onto the current template. It is the one
deliberate exception to msg's read-side rule that no PRD on disk is ever
rewritten: every reader normalises the old shape in memory, no writer emits it,
and this mode only runs because a human asked for it by name. The read path
itself is unchanged — nothing here alters how any other skill reads a PRD.

This is **maintenance, not creation**. There is no `INTAKE.md` row for an
`--update` run and none is captured: the intake-only rule governs where a PRD's
*idea* comes from, and this run introduces no idea. The hard refusal (never skip
the PRD stage) is untouched. Steps 1–5 of `refs/protocol-pm.md` do not run.

The work splits in two, and the split is the safety story: **L1 is mechanical**
(a script, no judgement, idempotent), **L2 is the model** (restructuring prose
into the shapes the template asks for). L1 runs first so that L2 only ever sees
a file that is already structurally current.

## Step U1 — Resolve the targets

| Argument | Resolution |
|---|---|
| a path | Use it. Not a file → hard-refuse: `Hard failure: --update target '<value>' is not a PRD file.` |
| a number `<n>` | Lane-agnostic: `features/{planned,wip,done}/prd-<n>-*/prd-<n>-*.md`, then legacy flat `features/prd-<n>-*/`. First hit wins. No match → hard-refuse: `Hard failure: --update target '<n>' does not match any PRD under features/.` |
| `--all` | Every `prd-*.md` under `features/` in any lane, sub-PRDs included, sorted by id. |
| nothing | `AskUserQuestion` listing the PRDs found, plus an "all of them" option. |

Announce the resolved list before touching anything — on `--all` this is the
user's one chance to see the blast radius. Then run U2–U4 **per target**; one
target's skip never stops the rest.

## Step U2 — L1, the deterministic migration

```bash
S=.claude/scripts/script-prd-update.py; [ -f "$S" ] || S="$HOME/.claude/scripts/script-prd-update.py"; python3 "$S" <prd-path>
```

Read the exit code, never the prose: `0` already converged (nothing written) ·
`1` migrated · `2` skipped or errored. Add `--dry-run` when the user asks what
would change; the report is identical and nothing is written.

L1 owns, and L2 must not redo: the frontmatter mapping (`depends_on` → `deps`,
dropping `module`/`platform`/`affects`, fusing the two tune stamps into
`reviewed`, the status enum), moving an inline plan-review-findings section out
to `reports/review-prd-<n>-<slug>.md`, renumbering `## 8. Todos` to `## 7.`, and
folding a legacy `## Execution Table` heading into §6.

Two skips end the target at exit 2. Report them, carry on to the next target:

- **`retired-skipped`** — `status: retired` has no v5.4 equivalent. The file is
  left exactly as it is; say so and move on.
- **`report-exists`** — the PRD carries inline findings *and* a findings report
  already exists. Both are evidence and merging them is the user's call, so
  nothing was written. The next step is theirs, not yours.

A `intake-unresolved` warning is **not** a skip: L1 wrote a
`[USER: intake row #]` placeholder because no ledger row matched. Carry it into
U3 as an Open §5 row and finish the run 🟡 — the number is never invented.

## Step U3 — L2, the style pass

Only these four edits. Each one is a shape the template names and a script
cannot infer.

**S1 — §5 becomes the four-column table.** Every bullet becomes one row of
`# | Question | Answer | Status`, numbered from 1 in the order the bullets
appeared. A bullet that only asks → Question, empty Answer, `Open`. A bullet
that also states its resolution → split at the resolution: the ask goes in
Question, the resolution in Answer, Status `Addressed`. Owner/Due text stays
inline in the cell it came from — it is not a new column. Escape any `|` inside
a cell as `\|`, and keep each row on one line.

**S2 — dropped concepts are scrubbed, but only where you are already typing.**
`module:`, `affects` and the old status enum no longer exist; where a cell you
are restructuring mentions them, rewrite the sentence without them. Never touch
a sentence you are not otherwise moving.

**S3 — §1 becomes exactly three bullets.** `**Who**`, `**What changes**`,
`**Success signal**`, in that order, one line each. Every extra bullet moves to
§5 as an `Addressed` row — Question `"<subject> constraint confirmed?"`, Answer
the constraint text verbatim. The one exception: a bullet that only states the
platform is **deleted**, not relocated. Platform is detected from
`devkit/ARCHITECTURE.md` at run time and is not PRD content in any form.

**S4 — reserved placeholders go back to byte-exact.** If §6 or §7 is empty or
carries a paraphrase of its placeholder, restore the exact string from
`refs/template-prd.md`. If the section is genuinely populated, or is continued
by `## Engineering — <Agent>` / `## Todos — <Agent>` blocks, leave it alone.

### The invariants — hard, and checked by eye before you save

1. **§3 and §4 text is preserved verbatim.** Acceptance criteria and error cases
   are the certified contract. Table *structure* may be normalised; a single
   word of criterion text may not.
2. **F-IDs are never renumbered.** §6 keys on them; a renumber silently breaks
   the pipeline downstream.
3. **§6, §7 and every `Engineering — <Agent>` / `Todos — <Agent>` block are
   untouched.** They are downstream property.
4. **`reviewed: yes` survives.** Restructuring does not decertify a contract. It
   is downgraded to `no` — and reported as its own row in the closing message —
   only if this run had to do something beyond S1–S3, which means the PRD said
   something the current template has no home for.
5. **Idempotent.** Re-running `--update` on a converged PRD changes no byte, in
   L1 and in L2 alike. If a second pass wants to reword something, the first
   pass went too far.

## Step U4 — The convergence gate

```bash
S=.claude/scripts/script-prd-shape.py; [ -f "$S" ] || S="$HOME/.claude/scripts/script-prd-shape.py"; python3 "$S" <prd-path> --checks 1,2,3,4,5,6
```

Check 6 is the style check, opt-in and requested only here — fresh-draft gates
keep running 1–5. **Exit 0 or the target has not converged.** On a failure, fix
what the FAIL line names and re-run the gate; at most two attempts, then stop
and report the target red rather than editing around the validator.

The one tolerated failure is a `check=5 code=bad-value ref=intake` on a target
carrying the `[USER: intake row #]` placeholder from U2 — that gap needs the
user, not another edit. That target is 🟡, not 🔴.

## Step U5 — Close

One closing message for the whole run, per `../shared/refs/closing-message.md`,
using the `plan-pm --update` registry row. One `What happened` row per target,
naming the path and its outcome (converged · already converged · skipped, with
the reason). The protocol is deterministic:

| Outcome | Protocol |
|---|---|
| Every target passed the gate, no warnings | 🟢 |
| Every target passed, but something was skipped, warned, or left a `[USER: …]` placeholder | 🟡 |
| Any target failed the gate after its retry | 🔴 |

Log unexpected script failures to `devkit/DOCTOR.md` per
`../shared/refs/doctor-logging.md` — logging never changes what the run does.
