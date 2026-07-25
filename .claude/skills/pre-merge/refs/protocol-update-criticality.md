---
name: pre-merge-protocol-update-criticality
description: Spec for /pre-merge --update-criticality — the criticality reconcile pass. Inventory the tests lacking the platform's critical marker (diffed against the criticality_review stamp), let the LLM propose critical/not-critical with cited evidence, gate every proposal through one reviewable AskUserQuestion table, then write the approved markers into the test files as one commit and restamp criticality_review. Also defines the gate's read-only staleness nudge.
type: reference
---

# `/pre-merge --update-criticality`

The **tag-drift answer** for minified test selection. Under
`policies.test_selection` the critical floor is what every minified run includes
regardless of the diff (`refs/executor.md` §3c) — so a test that *should* be
critical but carries no marker silently loses its always-run guarantee: it runs
only when the diff happens to make it affected.

Authoring-time tagging covers the new regression tests (they are **born tagged** —
`refs/universal/protocol-regression.md` §2), but eng-authored unit/integration
tests, hand-written tests, and *evolving* criticality (a path becomes hot three
PRDs later) all drift. `--update-criticality` is the periodic reconcile that
catches the drift.

It follows `--update`'s philosophy exactly: **the LLM proposes once, the human
gates, the result is committed and deterministic**. It never picks tests per gate
run — selection at run time reads only declared tags and the resolved affected set
(AC-TS3).

**Boundaries.** `--update-criticality` never runs the gate, opens a PR, merges, or
deploys (same boundaries as `--init`/`--update`). It writes **exactly two** things,
both after approval: the critical markers **in the test files**, and the
`criticality_review` stamp in `devkit/policy.json`. It writes **no other policy
key** — not `policies.test_selection`, not `components[]`, not
`source_signature` (`../../shared/refs/policy-schema.md` writer table).

**Precondition.** It is meaningful only where a critical-marker vocabulary is
resolved (`policies.test_selection.critical_markers`). With the key absent, say so
in one line and name the enabling interview (`/pre-merge --init`, `refs/protocol-init.md`)
— do not silently invent a vocabulary. It **does** run with
`test_selection.enabled:false` (curating tags before/after a disable is legitimate;
tags are inert, not wrong — AC-TS12).

---

## 1 — Inventory

Enumerate the test tree and split it on the platform's marker
(`critical_markers.<platform>`, defaults in
[`../../shared/refs/component-catalog.md`](../../shared/refs/component-catalog.md)):
the `@critical` title tag, `@pytest.mark.critical`, the `TestCritical*` naming
convention, membership of `Critical.xctestplan`, the `@Critical` annotation.

**Diff against the last pass, don't re-walk history.** Read
`criticality_review` from `devkit/policy.json` — `{reviewed_at, suite_hash}`, the
`source_signature` pattern applied to the **test tree** (sha256 over the sorted
test-file paths + each file's declared markers,
`../../shared/refs/policy-schema.md` § `criticality_review`). Recompute the hash;
enumerate only what changed since. **Stamp absent ⇒ "never reviewed" ⇒
full inventory** — never a validation error, and identical to the
**full-inventory mode** the enabling interview's initial tagging pass runs
(`refs/protocol-init.md`, § *Enabling the flag*).

Emit the inventory as counts before anything else: total tests · tagged ·
untagged · untagged-since-last-review. A zero-untagged inventory ends the run
right there with one line — nothing to propose, nothing to gate, nothing written.

---

## 2 — Propose (LLM drafts, with cited evidence)

For each **untagged** test, draft a `critical` / `not-critical` proposal. Every
proposal carries **cited evidence** — a proposal with nothing to cite is
`not-critical` by default, never a bare assertion (AC-TS7):

| Signal | Evidence line cites |
|---|---|
| **PRD traceability** | the test locks in a PRD acceptance criterion the PRD marks **P0/critical** — cite `prd-<n>` + the criterion id (F-ID / §6 row) |
| **Failure history** | the test has produced a **blocker/high** finding in a past verdict — cite the run artifact (`.pre-merge/<ts>/*.json`, `reports/*.json`) + the finding's `rule` |
| **Graph position** | the test covers high fan-in / hotspot code — cite the symbol/file + the metric (tokensave `test_risk`, `hotspots`, `rank`) |

The deterministic signals are scored first; the LLM's job is to **compose the
proposal and the citation**, not to invent a signal. Graph unavailable ⇒ that
row simply carries no graph evidence (it never upgrades a proposal on a guess).

---

## 3 — Gate (the human decision)

Present **one reviewable table** via `AskUserQuestion` — test · proposed grade ·
evidence — with three options: **approve all** · **edit** (accept a subset /
flip individual rows) · **skip** (write nothing, run ends).

Two rules the gate never breaks:

- **Never re-grades an existing human-set tag** — the exact mirror of `--update`
  never re-grading a user-set `criticality` or re-prompting a settled
  `opted_out`/`n/a` (AC-UP2). A tag already in the test tree is a human decision;
  this pass proposes for the **untagged** only.
- **Removals need evidence, and only one kind.** A proposal to *remove* an
  existing marker is admissible **only** with a "the covered behavior no longer
  exists" or "duplicate of `<test>`" evidence line. "Feels less critical now" is
  not evidence — re-grading by vibe is exactly what AC-TS7 forbids.

Nothing is written before approval. Skip is a first-class outcome: it leaves the
tree and the stamp untouched (the next run re-proposes the same rows).

---

## 4 — Apply

1. Write the **approved** markers into the test files, using the platform's
   mechanism (title tag / `@pytest.mark.critical` / rename to `TestCritical*` /
   add the suite to `Critical.xctestplan` / add the `@Critical` annotation).
2. Commit them as **one reviewed commit**: `test(criticality): tag prd-<n>..<m> additions`
   — one commit, so the diff is reviewable as a unit in the PR, exactly like the
   regression subagent's authoring commit.
3. **Restamp `criticality_review`** — `{reviewed_at: <today>, suite_hash: <recomputed>}`.
   The skill stamps the date (scripts can't). No other policy key changes.
4. Print a one-line summary: *"N tagged critical, M left untagged, stamp
   refreshed — the critical floor is now K tests."*

Declined/edited-away rows are simply not written; they surface again on the next
pass. The file must re-load with zero validation warnings (AC-S6).

---

## Staleness nudge — read-only, and the gate's only involvement

A **minified** gate run counts untagged tests cheaply against the
`criticality_review` stamp. Over the threshold (**default 25**) it prints exactly
one line —

> *"N untagged tests since the last criticality review — run `/pre-merge --update-criticality`"*

— and **proceeds**. Fork E's pattern, verbatim: the gate is a pure reader.

| The gate does | The gate never does |
|---|---|
| recompute the suite hash / count untagged tests read-only | write a critical tag into a test file |
| print the one nudge line, then run the pipeline | write `criticality_review` or any `policy.json` key (AC-OW1, AC-TS2) |
| record what it selected (`refs/executor.md` §3c.3) | change a verdict because of the count — the nudge is never a finding |

The nudge is computed **only on a minified run** — with selection off (or `--full`)
no selection artifact is read at all, so no count is taken and no line is printed
(AC-TS1/AC-TS12). Only the human-gated `--init` / `--update` /
`--update-criticality` ever write a tag or the stamp.

---

## Full-inventory mode (the enabling interview's initial tagging pass)

The test-selection **enabling interview** (`refs/protocol-init.md`, § *Enabling the
flag*) reuses this machinery in full: on enable it runs §§1–4 with **no stamp** —
i.e. full inventory rather than a since-last-review diff — so the critical floor
is non-empty from day one rather than accumulating over the first N PRDs. Same
proposals, same evidence requirement, same single `AskUserQuestion` gate, same
commit, same stamp. It is the second (and only other) writer of
`criticality_review` (`../../shared/refs/policy-schema.md`).

---

## References

- [`executor.md`](executor.md) §3c — the selection rule, the size-tier rubric, and §3c.3's recording contract (the critical floor is consumed there)
- [`protocol-init.md`](protocol-init.md) — `--init`/`--update`, incl. the test-selection enabling interview + the disable contract
- [`universal/protocol-regression.md`](universal/protocol-regression.md) — born-tagged authoring, the primary tag-drift defense this pass backstops
- [`../../shared/refs/policy-schema.md`](../../shared/refs/policy-schema.md) — `policies.test_selection`, the `criticality_review` stamp, and the writer table
- [`../../shared/refs/component-catalog.md`](../../shared/refs/component-catalog.md) — the `critical_markers` per-platform defaults and their mechanisms
