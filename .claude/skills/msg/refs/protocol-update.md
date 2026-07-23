---
name: msg-protocol-update
description: >
  Protocol for /msg --update — re-scan an already-bootstrapped repo for init
  components introduced since it was set up (missing devkit/root files,
  missing template rows, missing features/ lifecycle lanes) and for flat
  features/prd-*/ dirs never classified into a lane. Warns before offering a
  full reinit; the default path only adds what's missing, same idempotent
  guarantee as /msg --init's top-up. Batches ambiguous PRDs to the user via
  AskUserQuestion instead of silently defaulting them to "planned".
type: reference
---

# Protocol: --update

## Usage

**Invoke**: `/msg --update`

- Natural language: "check for msg updates", "reinitialise this project", "resync my init setup", "are there new init components", "classify my PRDs"

**Hard refusal:** `devkit/policy.json` (equivalently, `devkit/` — `INITIALISED` from `init-setup.sh`) absent → this repo was never bootstrapped, there is nothing to update. Stop and direct the user to `/msg --init`. Do not create anything here.

## Inputs

| Name | Format | Source |
|------|--------|--------|
| Working directory state | `key=value` lines from `init-setup.sh` | Step 1 |
| Update path | full reinit \| update with new stuff | Step 2 `AskUserQuestion` |
| Interview answers (full reinit path only) | Step 2 of `protocol-init.md`, delegated | `protocol-cto.md` / `protocol-eng.md` |
| PRD lane classifications | planned \| wip \| done, per unresolved PRD | Step 4, batched `AskUserQuestion` |

## Outputs

| Name | Format | Destination |
|------|--------|-------------|
| Newly-added devkit/root files, rows, lanes | Same as `/msg --init`'s Outputs | Same as `/msg --init` |
| Reclassified PRDs | `git mv` / `mv` into the user-chosen lane | `<cwd>/features/<lane>/prd-*/` |
| Summary | Inline — components added, PRDs classified | Shown inline at Step 4 |

## Progress emission

Emit `Step X/4 — <title>` at the start of each step, unconditionally.

## Step-by-step protocol

**Step 1/4 — Precondition + scan**

Run `init-setup.sh` via Bash:

```
<msg_skill_dir>/refs/init/init-setup.sh "<cwd>"
```

Parse all nine `key=value` lines (see `refs/init/init-setup.sh`'s header). If `INITIALISED=false`, stop — hard refusal above; there is nothing to update.

Otherwise hold `MISSING`, `ROW_GAPS`, and `FLAT_PRDS` in context, and build the plain-language diff summary the user sees at Step 2:

| Signal | Human label |
|---|---|
| `MISSING != none` | "`<n>` init file(s)/lane(s) not yet created" |
| `ROW_GAPS != none` | "`<n>` template row(s) added since this file was written" |
| `FLAT_PRDS != none` | "`<n>` PRD(s) not yet sorted into planned/wip/done" |

If all three are empty/`none`, say so plainly — "Everything is up to date — no missing components, no row gaps, no unsorted PRDs." — and stop. There is nothing for Step 2 onward to do.

**Step 2/4 — Warn + choose the update path**

One `AskUserQuestion`, doubling as both the warning the user asked for and the path choice:

> header **Update mode**, question "This repo is already initialised. How do you want to update it?"
> - **Update with new stuff (recommended)** — add only what's missing (fill in the Step 1 counts: `<n>` file(s)/lane(s), `<n>` row(s), `<n>` PRD(s) to classify). Nothing that already exists is touched or re-asked.
> - **Full reinit** — re-run the complete setup interview (mode gate + every Step 2 question) as if bootstrapping fresh. **Warning:** no existing file is ever overwritten (same guarantee as the top-up path), but this re-asks every setup question and can produce different answers than what's already committed for anything still missing — only choose this if you want to redo the original setup decisions from scratch.

**Step 3/4 — Apply the component top-up**

Both paths converge on `protocol-init.md`'s Steps 2–5, with one required addition and one divergence from it:

- **Required addition.** When invoking `init.sh` at `protocol-init.md`'s Step 3, always set `INTERACTIVE_LANES=true` in the env block. This is the only thing that differs from a plain `--init` invocation — it turns rung-3 PRDs into an `UNRESOLVED` report instead of a silent `planned` default.
- **Divergence from `protocol-init.md`'s run-mode table.** Do not let `ALL_COMPLETE=true && ROW_GAPS=none` short-circuit to "nothing to initialise" — `--update` always runs `init.sh` at least once (Step 1 already confirmed there is something to do: a missing component, a row gap, or an unsorted PRD). A fully-complete repo can still have `FLAT_PRDS`, which plain `--init` would never revisit once `ALL_COMPLETE` goes true.

Path-specific behaviour within `protocol-init.md`:

| Path | `protocol-init.md` Step 2 behaviour |
|---|---|
| Update with new stuff | **Top-up mode** — ask only the required-variable subset for `MISSING` + confirmed `ROW_GAPS` (often none at all) |
| Full reinit | **Bootstrap mode, forced** — run the mode gate + the full Step 2 interview regardless of what's missing, even though only absent files receive the answers (idempotency still holds — no existing file is touched) |

Follow `protocol-init.md`'s Steps 3–5 (env-var contract, `devkit/policy.json` seeding, row top-up, manifest) exactly as written for the chosen behaviour. Capture `init.sh`'s stdout — it now also carries an `UNRESOLVED=<space-separated PRD basenames, or "none">` line, needed at Step 4.

**Step 4/4 — Batched PRD lane classification**

Parse `UNRESOLVED` from Step 3's `init.sh` output. If `none`, skip straight to the summary — every flat PRD was resolved automatically (rung 1 shipped / rung 2 wip) or there were none to begin with.

Otherwise, classify the `UNRESOLVED` basenames in batches of up to 4 per `AskUserQuestion` call (mirroring `--help`'s multi-question-per-call pattern), looping across further calls until every PRD is classified. For each PRD, one question:

> header **`<PRD id, e.g. prd-12>`**, question "Which lifecycle lane is `<basename>` in?"
> - **Planned** — drafted, not yet started
> - **WIP** — actively being built
> - **Done** — shipped to production

After each batch's answers, move each PRD immediately (don't wait for every batch to finish):

```bash
if [[ -n "$(git -C "<cwd>" ls-files "features/<basename>" 2>/dev/null)" ]]; then
  git -C "<cwd>" mv "features/<basename>" "features/<lane>/<basename>"
else
  mv "<cwd>/features/<basename>" "<cwd>/features/<lane>/<basename>"
fi
```

Same tracked-vs-untracked branch `init.sh`'s own migration loop uses — history-preserving `git mv` when the dir is tracked, plain `mv` otherwise. Report each as `classified (manual) → <lane>` in the final summary.

**Summary.** Print what happened: components added/skipped (from Step 3's manifest), rows added/declined, and PRDs classified (automatic ladder vs. manual, each with its resulting lane). No next-step suggestion beyond noting the repo is now current with `/msg --init`'s latest scaffold.

## References

- `refs/protocol-init.md` — Steps 2–5 delegated to verbatim for the component top-up; owns the mode gate, the interview protocols, `init.sh`'s env-var contract, `devkit/policy.json` seeding, and the row top-up
- `refs/init/init-setup.sh` — Step 1 scan; the `FLAT_PRDS` line this protocol reads was added for `--update`
- `refs/init/init.sh` — Step 3 invocation; the `INTERACTIVE_LANES` env var and `UNRESOLVED` output line this protocol depends on were added for `--update`
- `refs/protocol-cto.md` / `refs/protocol-eng.md` — Step 2 interview modes, reached via `protocol-init.md`
