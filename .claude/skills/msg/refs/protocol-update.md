---
name: msg-protocol-update
description: >
  Protocol for /msg --update — re-scan an already-bootstrapped repo for init
  components introduced since it was set up (missing devkit/root files,
  missing template rows, missing features/ lifecycle lanes) and for flat
  features/prd-*/ dirs never classified into a lane. Warns before offering a
  full reinit; the default path only adds what's missing, same idempotent
  guarantee as /msg --init's top-up. Batches ambiguous PRDs to the user via
  AskUserQuestion instead of silently defaulting them to "planned". Also the
  place to revisit whether GitHub Actions CI is wanted at all
  (policies.github_actions), and the single-run complete off switch for
  minified test selection (policies.test_selection) — turning it on hands
  off to pre-merge's own enabling interview instead. These are the two
  policy.json keys it writes.
type: reference
---

# Protocol: --update

## Usage

**Invoke**: `/msg --update`

- Natural language: "check for msg updates", "reinitialise this project", "resync my init setup", "are there new init components", "classify my PRDs"

**Hard refusal:** `devkit/` absent (`INITIALISED=false` from `init-setup.sh`) → this repo was never bootstrapped, there is nothing to update. A missing `devkit/policy.json` is **not** a refusal signal on its own — a repo bootstrapped before `policy.json` existed is exactly the top-up case this mode serves. Stop and direct the user to `/msg --init`. Do not create anything here.

## Inputs

| Name | Format | Source |
|------|--------|--------|
| Working directory state | `key=value` lines from `init-setup.sh` | Step 1 |
| Update path | full reinit \| update with new stuff | Step 2 `AskUserQuestion` |
| Interview answers (full reinit path only) | Step 2 of `protocol-init.md`, delegated | `protocol-cto.md` / `protocol-eng.md` |
| PRD lane classifications | planned \| wip \| done, per unresolved PRD | Step 4, batched `AskUserQuestion` |
| GitHub Actions decision | keep \| on \| off (+ reason when off) | Step 3-CI `AskUserQuestion`, gated on a GitHub remote + `gh` |
| Test selection decision | keep \| on (hand-off) \| off (+ reason when off) | Step 3-TS `AskUserQuestion`, gated on a detected test suite (a `unit`/`integration`/`regression` component present) |
| Untrack-`features/` decision | leave tracked \| untrack | Step 3-FT `AskUserQuestion`, gated on `git ls-files -- features/` being non-empty |

## Outputs

| Name | Format | Destination |
|------|--------|-------------|
| Newly-added devkit/root files, rows, lanes | Same as `/msg --init`'s Outputs | Same as `/msg --init` |
| Reclassified PRDs | `mv` (or `git mv` for a legacy tracked dir) into the user-chosen lane | `<cwd>/features/<lane>/prd-*/` |
| Untracked `features/` | `git rm -r --cached features/` — a **staged** deletion, on explicit confirmation only; never committed here | git index |
| GitHub Actions decision | `policies.github_actions: {enabled, reason}`, merged surgically — the only `policy.json` key this protocol writes | `<cwd>/devkit/policy.json` |
| Test selection disable | `policies.test_selection.enabled: false` (+ `reason`), merged surgically — enabling is never written here, only handed off | `<cwd>/devkit/policy.json` |
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

Also read `policies.github_actions` from `devkit/policy.json`
(`../../shared/refs/policy-schema.md` §2b) and hold its current value — absent,
`enabled:true`, or `enabled:false` + `reason`. This is a **settled decision, not a
gap**: it is never counted in the three signals above and never on its own reason
to keep the run going.

If all three signals are empty/`none`, there is no component work to do — but the
CI decision is still revisable, so **offer it rather than stopping flat**. Say
"Everything is up to date — no missing components, no row gaps, no unsorted
PRDs.", then run the Step 3-CI question below and stop after it. Skip Steps 2–4.

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

**Step 3-CI — Revisit the GitHub Actions decision** (named to avoid collision with `protocol-init.md`'s own Step 3b row top-up)

`protocol-init.md`'s Step 5 asks the CI question fresh; here the repo usually
already has an answer, so **show it and ask whether to change it** rather than
re-asking cold. Same `HAS_GH_REMOTE` gate, from the same resolver
(`.claude/scripts/script-branch-topology.sh "<cwd>"`) — `false` → skip silently,
write nothing.

> header **GitHub Actions**, question "GitHub Actions CI is currently **`<enabled|disabled>`**`<, reason: "<reason>"` when disabled`>`. Change it?"
> - **Keep it as is** — write nothing; `policy.json` is untouched.
> - **Turn it on** — CI runs on Actions; `/pre-merge --init` will scaffold `.github/workflows/pre-merge.yml`, and the gates expect PR checks to report.
> - **Turn it off** — no workflow is scaffolded and `/post-merge` accepts a PR with **zero** checks instead of flagging it. For repos with no Actions minutes (private repo on GitHub Free), or CI hosted elsewhere. Red or pending checks from any CI still block the merge; every human gate stands.

When the current state is *absent*, phrase it as "not set (defaults to enabled)"
and offer the same three options.

On a change, write `policies.github_actions` with the shared policy writer —
surgical by construction, every other byte of `policy.json` untouched — capturing
the user's `reason` when turning it off:

```bash
.claude/scripts/script-policy-set.py --file "<cwd>/devkit/policy.json" \
  --set policies.github_actions='{"enabled": false, "reason": "<why>"}'
```

No `--create` (the file must already exist — Step 1 refused otherwise) and no
`--stamp-by` (a policy revision is not a re-generation). Report the transition in
the Step 4 summary as `github_actions: <old> → <new>`; "Keep it as is" reports
nothing and calls nothing. `/msg --update` writes **no other `policy.json` key**
(AC-OW1 keeps the rest with the gates' own `--init`).

**Step 3-TS — Revisit the minified test selection decision** (named to avoid
collision with `protocol-init.md`'s own Step 3b row top-up, alongside Step 3-CI)

`policies.test_selection` (`../../shared/refs/policy-schema.md` §2c) is the
second policy key this protocol writes, and the two halves of the decision are
asymmetric. **Gate:** only asked when a test-running component (`unit`,
`integration`, or `regression`) is present in `components[]` — no test suite,
nothing to select over, skip silently and write nothing.

> header **Test selection**, question "Minified test selection is currently
> **`<enabled|disabled>`**`<, backstop: <full_run_backstop>` when enabled`>`.
> Change it?"
> - **Keep it as is** — write nothing; `policy.json` is untouched.
> - **Turn it on** — this protocol writes **nothing** for this choice. Enabling
>   is a bigger decision than flipping a boolean: it requires verifying the
>   declared `full_run_backstop` actually exists and running the initial
>   criticality-tagging pass so the critical floor isn't empty on day one
>   (AC-TS8) — that full interview belongs to `/pre-merge --init`/`--update`
>   (`pre-merge/refs/protocol-init.md`'s enabling interview; not duplicated
>   here). Tell the user to run one of those next.
> - **Turn it off** — the complete single-run disable (AC-TS12): flip
>   `enabled:false` (capturing a `reason` if offered), leaving every other
>   artifact the feature created untouched and inert-by-design — critical tags
>   in test code, `components[].run_minified`, `tiers`, `force_full_paths`,
>   `critical_markers`, and the `criticality_review` stamp are all read only
>   inside the selection path, so no second cleanup step exists or is needed.
>   End with the one-line retained-inert audit
>   (`../../shared/refs/policy-schema.md` §`policies.test_selection`), e.g.
>   *"test_selection disabled — critical tags and `run_minified` commands
>   retained (inert); re-enable via `/pre-merge --init` or `--update`."*

When the current state is *absent*, phrase it as "not set (defaults to
disabled)" and offer the same three options — note that this key's absent
default is `false` (opt-**in**), the inverse of `github_actions`' absent
default.

On a change, write `policies.test_selection.enabled` with the shared policy
writer — a **leaf** set, so `full_run_backstop`, `tiers`, `force_full_paths` and
every other key under `test_selection` survive untouched and inert:

```bash
.claude/scripts/script-policy-set.py --file "<cwd>/devkit/policy.json" \
  --set policies.test_selection.enabled=false \
  --set policies.test_selection.reason='"<why, when offered>"'
```

Report the transition in the Step 4 summary as
`test_selection: <old> → <new>`; "Keep it as is" and "Turn it on" (hand-off)
report nothing written. `/msg --update` never writes `enabled:true` itself
(AC-TS2) — only `/pre-merge --init`/`--update`'s enabling interview does.

**Step 3-FT — Untrack a previously committed `features/`** (named alongside Steps 3-CI
and 3-TS)

`features/` is gitignored from the Universal `# msg skill artifacts` block onward, but
**a gitignore row never untracks what is already committed**. A repo bootstrapped before
the ignore keeps committing its PRDs until someone runs `git rm -r --cached features/`.
**Gate:** only asked when `git ls-files -- features/` returns at least one path — an
already-untracked repo (every fresh one) skips silently and does nothing.

> header **Tracked PRDs**, question "`features/` is now gitignored, but this repo still
> tracks **`<n>`** committed file(s) under it. Untrack them?"
> - **Leave them tracked** — do nothing. The ignore has no effect on these files; they
>   keep committing exactly as before.
> - **Untrack them** — run `git rm -r --cached features/`. The files stay on disk, but
>   the change **stages a deletion of every one of them** and lands as a visible deletion
>   commit on the product repo, with their history ending at that commit.

Never do this silently and never commit it here — stage the removal, report it, and leave
the commit to the user. Report in the Step 4 summary as
`features/: untracked <n> file(s) — review and commit the staged deletion`.

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

Same tracked-vs-untracked branch `init.sh`'s own migration loop uses — plain `mv` in the normal case (`features/` is gitignored, so the dir is untracked), `git mv` only for a legacy dir tracked from before the ignore. Report each as `classified (manual) → <lane>` in the final summary.

**Summary.** Print what happened: components added/skipped (from Step 3's manifest), rows added/declined, the CI decision if it changed (Step 3-CI), the test-selection decision if it changed (Step 3-TS — a disable, or a hand-off note when the user chose to turn it on), and PRDs classified (automatic ladder vs. manual, each with its resulting lane). No next-step suggestion beyond noting the repo is now current with `/msg --init`'s latest scaffold.

## References

- `refs/protocol-init.md` — Steps 2–5 delegated to verbatim for the component top-up; owns the mode gate, the interview protocols, `init.sh`'s env-var contract, `devkit/policy.json` seeding, and the row top-up
- `refs/init/init-setup.sh` — Step 1 scan; the `FLAT_PRDS` line this protocol reads was added for `--update`
- `refs/init/init.sh` — Step 3 invocation; the `INTERACTIVE_LANES` env var and `UNRESOLVED` output line this protocol depends on were added for `--update`
- `refs/protocol-cto.md` / `refs/protocol-eng.md` — Step 2 interview modes, reached via `protocol-init.md`
- `.claude/scripts/script-policy-set.py` — the only writer of `devkit/policy.json`; both this protocol's keys (Step 3-CI `policies.github_actions`, Step 3-TS `policies.test_selection.enabled`) go through it, siblings preserved and the result re-parsed
- `.claude/scripts/script-branch-topology.sh` — the `HAS_GH_REMOTE` gate Step 3-CI reads; same resolver `protocol-init.md` uses
- `../../shared/refs/policy-schema.md` — §2b `policies.github_actions`, the one key this protocol writes (Step 3-CI); the read-contract that turns it into post-merge's inactive CI stage lives there too
- `../../shared/refs/policy-schema.md` — §2c `policies.test_selection`, the second key this protocol writes (Step 3-TS, disable only); the read-contract for the 5-step selection rule lives there too
- `../../pre-merge/refs/protocol-init.md` — owns the `policies.test_selection` **enabling** interview (backstop verification + the initial criticality-tagging pass) that Step 3-TS's "Turn it on" hands off to, rather than duplicating it here
