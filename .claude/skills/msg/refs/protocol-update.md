---
name: msg-protocol-update
description: >
  Protocol for /msg --update — one update command for the whole harness. In one
  pass it runs msg's own update (missing devkit/root files, missing template rows,
  missing features/ lanes, unsorted flat PRDs, the GitHub Actions choice, the test
  selection off switch, untracking a committed features/), pre-merge's --update
  (components) and merge's --update (merge settings). It shows one combined change
  list in one format and asks one approval. /pre-merge --update and /merge --update
  stay for a single-skill update. No devkit/ ⇒ it runs /msg --init first.
type: reference
---

# Protocol: --update

## Usage

**Invoke**: `/msg --update`

- Natural language: "check for msg updates", "reinitialise this project", "resync my init setup", "are there new init components", "classify my PRDs", "update everything"

**No `devkit/`** (`INITIALISED=false` from `init-setup.sh`) → this repo was never set up.
Run setup (`refs/protocol-init.md`, as for `/msg --init`) instead of refusing. A fresh setup
has nothing left to update, so the run ends after it. A missing `devkit/policy.json` on its
own is **not** this case — a repo set up before `policy.json` existed is exactly the
top-up case this mode serves.

## One pass, three parts

| Part | Detects | Owner spec | Runs when |
|---|---|---|---|
| **msg** | missing files / rows / lanes, flat PRDs, `policies.github_actions`, `policies.test_selection` off switch, tracked `features/` | this file | always |
| **pre-merge** | `components[]` vs. the repo (tools added or removed, triggers, new components, `devkit/ENV.md` deltas) | `../../pre-merge/refs/protocol-init.md` § *`--update`* | `components[]` exists |
| **merge** | release flow (report only), branch protection, deploy and smoke tools, platforms + staging readiness, risky paths, CI wait limit | `../../merge/refs/protocol-init.md` § *`/merge --update`* | a `policies.merge` record exists |

A gate part whose setup never ran is **not** run here (its full setup belongs to its own
first run). Report one line for it instead: "`<skill>` is not set up yet — its first run
sets it up."

Every part **detects first and writes nothing** until the one approval (Step 3).

## The shared change-list format

All three parts report their changes in one format, one line each:

```
<part> · <key or file>: <old> → <new>
```

- `<part>` is `msg`, `pre-merge` or `merge`.
- An added item reads `(none) → <new>`; a removed one reads `<old> → (removed)`.
- A report-only line (nothing is written) ends with `— report only`.

`/pre-merge --update` and `/merge --update` print the same lines when run alone (without
the `<part> · ` prefix being required).

## Inputs

| Name | Format | Source |
|------|--------|--------|
| Working directory state | `key=value` lines from `init-setup.sh` | Step 1 |
| pre-merge and merge deltas | change-list lines | Step 1, from each part's detection |
| The one approval | Apply all \| Apply + redo setup answers \| Cancel | Step 3 `AskUserQuestion` |
| GitHub Actions decision | keep \| on \| off (+ reason when off) | Step 3, same prompt, gated on a GitHub remote + `gh` |
| Test selection decision | keep \| on (hand-off) \| off (+ reason when off) | Step 3, same prompt, gated on a detected test suite (a `unit`/`integration`/`regression` component present) |
| Untrack-`features/` decision | leave tracked \| untrack | Step 3, same prompt, gated on `git ls-files -- features/` being non-empty |
| Interview answers (missing files only) | Step 2 of `protocol-init.md`, delegated | `protocol-eng.md` |
| PRD lane classifications | planned \| wip \| done, per unresolved PRD | Step 5, batched `AskUserQuestion` |

## Outputs

| Name | Format | Destination |
|------|--------|-------------|
| Newly-added devkit/root files, rows, lanes | Same as `/msg --init`'s Outputs | Same as `/msg --init` |
| Reclassified PRDs | `mv` (or `git mv` for a legacy tracked dir) into the user-chosen lane | `<cwd>/features/<lane>/prd-*/` |
| Untracked `features/` | `git rm -r --cached features/` — a **staged** deletion, on explicit confirmation only; never committed here | git index |
| GitHub Actions decision | `policies.github_actions: {enabled, reason}`, merged surgically | `<cwd>/devkit/policy.json` |
| Test selection disable | `policies.test_selection.enabled: false` (+ `reason`), merged surgically — enabling is never written here, only handed off | `<cwd>/devkit/policy.json` |
| pre-merge and merge settings | each part's own writes, as its `--update` would make them | `<cwd>/devkit/policy.json`, `devkit/ENV.md` |
| Summary | Inline — the applied change list, PRDs classified | Shown at Step 6 |

## Step-by-step protocol

**Step 1/6 — Scan all three parts (no writes)**

Run `init-setup.sh` via Bash:

```
<msg_skill_dir>/refs/init/init-setup.sh "<cwd>"
```

Parse all nine `key=value` lines (see `refs/init/init-setup.sh`'s header). `INITIALISED=false`
⇒ run setup (§ Usage) and end.

Otherwise hold `MISSING`, `ROW_GAPS`, and `FLAT_PRDS`, and turn each into change-list lines:

| Signal | Line |
|---|---|
| `MISSING != none` | `msg · <file or lane>: (none) → created` |
| `ROW_GAPS != none` | `msg · <file>: (none) → row <token> added` (the Step 3b rows of `protocol-init.md`) |
| `FLAT_PRDS != none` | `msg · features/: <n> PRD(s) unsorted → sorted into planned/wip/done` |

Also read the current settings (`.claude/scripts/script-policy-read.py`): `policies.github_actions`
(`../../shared/refs/policy-schema.md` §2b) — absent, `enabled:true`, or `enabled:false` +
`reason` — and `policies.test_selection`. These are **settled decisions, not gaps**: they are
never change lines by themselves; Step 3 offers to change them.

Then run each gate part's **detection only** (its writes wait for Step 3):

- **pre-merge** — its § *`--update`* steps 1–2: re-run the preflight checks and diff them
  against `components[]`. Each delta is one `pre-merge · …` line.
- **merge** — its § *`/merge --update`* table, items (a)–(f). Each proposed change is one
  `merge · …` line; a release-flow mismatch is a `— report only` line.

**Step 2/6 — Show the combined change list**

Print every line from Step 1, grouped by part (msg, pre-merge, merge), plus the
"not set up yet" line of any skipped part.

No change lines at all ⇒ say "Everything is up to date." Step 3 still runs when at least
one settings question applies (the settings stay revisable); otherwise stop here.

**Step 3/6 — One approval (one prompt)**

One `AskUserQuestion` call. The first question is always asked; each settings question is
added only when its gate holds (up to 4 questions in the prompt). No change lines ⇒ leave
out the first question; ask only the settings questions that apply.

> header **Update**, question "Apply these `<n>` changes?"
> - **Apply all (recommended)** — add only what is missing and save the pre-merge and merge
>   changes. Nothing that already exists is rewritten or re-asked.
> - **Apply + redo setup answers** — the same, but re-run the full setup interview for the
>   missing files. **Warning:** no existing file is ever overwritten, but the questions are
>   asked fresh and can give different answers than the files already committed.
> - **Cancel** — write nothing.

> header **GitHub Actions** (only when `HAS_GH_REMOTE=true` from
> `.claude/scripts/script-branch-topology.sh "<cwd>"`), question "GitHub Actions CI is
> currently **`<enabled|disabled>`**`<, reason: "<reason>"` when disabled`>`. Change it?"
> - **Keep it as is** — write nothing.
> - **Turn it on** — CI runs on Actions; `/pre-merge --update` (or the first run, when not yet set up) will scaffold `.github/workflows/pre-merge.yml`, and the gates expect PR checks to report.
> - **Turn it off** — no workflow is scaffolded and `/merge` accepts a PR with **zero** checks instead of flagging it. For repos with no Actions minutes (private repo on GitHub Free), or CI hosted elsewhere. Red or pending checks from any CI still block the merge; every human gate stands.

When the current state is *absent*, phrase it as "not set (defaults to enabled)".

> header **Test selection** (only when a `unit`, `integration` or `regression` component is
> in `components[]`), question "Minified test selection is currently
> **`<enabled|disabled>`**`<, backstop: <full_run_backstop>` when enabled`>`. Change it?"
> - **Keep it as is** — write nothing.
> - **Turn it on** — this protocol writes **nothing** for this choice. Enabling needs the
>   declared `full_run_backstop` verified and the initial critical-test tagging pass run
>   (AC-TS8) — that interview belongs to `/pre-merge --update`
>   (`../../pre-merge/refs/protocol-init.md` § *Enabling the flag*). Tell the user to run it next.
> - **Turn it off** — the complete single-run disable (AC-TS12): flip `enabled:false`
>   (capturing a `reason` if offered), leaving every other artifact the feature created
>   untouched and inert — critical tags in test code, `components[].run_minified`, `tiers`,
>   `force_full_paths`, `critical_markers`, and the `criticality_review` stamp are read only
>   inside the selection path, so no second cleanup step exists. End with the one-line
>   retained-inert audit (`../../shared/refs/policy-schema-pre-merge.md`
>   §`policies.test_selection`), e.g. *"test_selection disabled — critical tags and
>   `run_minified` commands retained (inert); re-enable via `/pre-merge --update`."*

When the current state is *absent*, phrase it as "not set (defaults to disabled)" — this
key's absent default is `false` (opt-**in**), the inverse of `github_actions`.

> header **Tracked PRDs** (only when `git ls-files -- features/` returns at least one path),
> question "`features/` is now gitignored, but this repo still tracks **`<n>`** committed
> file(s) under it. Untrack them?"
> - **Leave them tracked** — do nothing. They keep committing exactly as before.
> - **Untrack them** — run `git rm -r --cached features/`. The files stay on disk, but the
>   change **stages a deletion of every one of them** and lands as a visible deletion commit
>   on the product repo, with their history ending at that commit.

**Cancel** ⇒ nothing in Step 4 runs, whatever the settings answers were. Say "Nothing was
changed." and stop.

**Step 4/6 — Apply, in order**

Each part writes through its own sanctioned writer (`.claude/scripts/script-policy-set.py`
for `devkit/policy.json`). The one approval covers every listed change: no part asks its
own Save / approve question again.

1. **msg — component top-up.** Follow `protocol-init.md`'s Steps 2–5 with three changes:
   - Always set `INTERACTIVE_LANES=true` in `init.sh`'s env block. It turns rung-3 PRDs
     into an `UNRESOLVED` report instead of a silent `planned` default.
   - Never let `ALL_COMPLETE=true && ROW_GAPS=none` short-circuit to "nothing to
     initialise" — a fully complete repo can still have `FLAT_PRDS`.
   - Step 3b's row confirm and Step 5's GitHub questions are **not** asked again: Step 3
     answered them. Step 2 asks only the required-variable subset for `MISSING` (often
     none), or the full interview after **Apply + redo setup answers**.

   Capture `init.sh`'s stdout — its `UNRESOLVED=<PRD basenames, or "none">` line feeds Step 5.
2. **msg — settings.** On a changed GitHub Actions answer:
   ```bash
   .claude/scripts/script-policy-set.py --file "<cwd>/devkit/policy.json" \
     --set policies.github_actions='{"enabled": false, "reason": "<why>"}'
   ```
   (`'{"enabled": true}'` for on). On **Turn it off** for test selection — a **leaf** set,
   so every other key under `test_selection` survives:
   ```bash
   .claude/scripts/script-policy-set.py --file "<cwd>/devkit/policy.json" \
     --set policies.test_selection.enabled=false \
     --set policies.test_selection.reason='"<why, when offered>"'
   ```
   No `--create` and no `--stamp-by` (a policy revision is not a re-generation). msg's part
   never writes `enabled:true` for test selection (AC-TS2). On **Untrack them**, run
   `git rm -r --cached features/`; never commit it here.
3. **pre-merge** — its § *`--update`* steps 4–6 (apply, fill new gaps through its gated
   per-item install offer, restamp, commit), as if its own approval had said yes.
4. **merge** — its § *`/merge --update`* save, as if its own **Save** had been chosen.

A part that fails stops the run there and names the error. Parts already applied stay
applied; the summary says which part did not run.

**Step 5/6 — Batched PRD lane classification**

Parse `UNRESOLVED` from step 4.1's `init.sh` output. If `none`, skip to the summary.

Otherwise, classify the `UNRESOLVED` basenames in batches of up to 4 per `AskUserQuestion`
call, looping until every PRD is classified. For each PRD, one question:

> header **`<PRD id, e.g. prd-12>`**, question "Which lifecycle lane is `<basename>` in?"
> - **Planned** — drafted, not yet started
> - **WIP** — actively being built
> - **Done** — shipped to production

After each batch's answers, move each PRD immediately:

```bash
if [[ -n "$(git -C "<cwd>" ls-files "features/<basename>" 2>/dev/null)" ]]; then
  git -C "<cwd>" mv "features/<basename>" "features/<lane>/<basename>"
else
  mv "<cwd>/features/<basename>" "<cwd>/features/<lane>/<basename>"
fi
```

Plain `mv` in the normal case (`features/` is gitignored), `git mv` only for a legacy dir
tracked from before the ignore. Report each as `classified (manual) → <lane>`.

**Step 6/6 — Summary**

Print the applied change list in the shared format, plus: the settings that changed
(`msg · policies.github_actions: <old> → <new>`, `msg · policies.test_selection: <old> → <new>`,
or a hand-off note when the user chose to turn selection on), `features/: untracked <n>
file(s) — review and commit the staged deletion` when chosen, PRDs classified (automatic
ladder vs. manual, each with its lane), and any part that was skipped or stopped.

## References

- `refs/protocol-init.md` — Steps 2–5 used for the msg part's component top-up; owns the interview hand-off, `init.sh`'s env-var contract, `devkit/policy.json` seeding, and the row top-up
- `refs/protocol-eng.md` — the one Step 2 interview, reached via `protocol-init.md`
- `refs/init/init-setup.sh` — Step 1 scan; the `FLAT_PRDS` line this protocol reads was added for `--update`
- `refs/init/init.sh` — step 4.1 invocation; the `INTERACTIVE_LANES` env var and `UNRESOLVED` output line this protocol depends on were added for `--update`
- `../../pre-merge/refs/protocol-init.md` § *`--update`* — the pre-merge part (detection, apply, gated installs); also owns the `policies.test_selection` **enabling** interview that "Turn it on" hands off to
- `../../merge/refs/protocol-init.md` § *`/merge --update`* — the merge part (items (a)–(f))
- `.claude/scripts/script-policy-set.py` — the only writer of `devkit/policy.json`; every part's writes go through it, siblings preserved and the result re-parsed
- `.claude/scripts/script-policy-read.py` — reads the current settings at Step 1
- `.claude/scripts/script-branch-topology.sh` — the `HAS_GH_REMOTE` gate for the GitHub Actions question; same resolver `protocol-init.md` uses
- `../../shared/refs/policy-schema.md` — §2b `policies.github_actions`, the writer table
- `../../shared/refs/policy-schema-pre-merge.md` — §2c `policies.test_selection`
