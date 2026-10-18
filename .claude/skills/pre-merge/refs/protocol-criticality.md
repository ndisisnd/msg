---
name: pre-merge-protocol-criticality
description: The critical-test tagging pass — a gate step that runs automatically before test selection when selection is on. Inventory the tests lacking the platform's critical marker (diffed against the criticality_review stamp), tag the ones that must always run with cited evidence, commit the tags on the branch, restamp criticality_review, and list the tags in the report. No question.
type: reference
---

# Critical-test tagging — an automatic gate step

The **tag-drift answer** for minified test selection. Under
`policies.test_selection` the critical floor is what every minified run includes
regardless of the diff (`executor.md` §3c) — so a test that *should* be critical
but carries no marker silently loses its always-run guarantee: it runs only when
the diff happens to make it affected.

Authoring-time tagging covers the new regression tests (they are **born tagged** —
`universal/protocol-regression.md` §2), but eng-authored unit/integration tests,
hand-written tests, and *evolving* criticality (a path becomes hot three PRDs later)
all drift. This pass catches the drift **on every gate run**, so the floor never
goes stale.

**When it runs.** As gate step §3c.4, **before** selection, only when test
selection resolves **on** for this run (`executor.md` §3c). Selection off (or
`--full`) ⇒ the pass is skipped and nothing is read.

**No question.** A wrong "critical" tag only makes a test run more often, which is
safe. So the pass tags and commits without asking, and lists every tag in the
report for the human to see.

**What it writes — exactly two things.** The critical markers **in the test files**,
committed on the branch, and the `criticality_review` stamp in `devkit/policy.json`.
It writes **no other policy key** — not `policies.test_selection`, not
`components[]`, not `source_signature` (`../../shared/refs/policy-schema.md` writer
table). It is the one exception to "the gate changes no files" beside the sync-merge
commit.

**Precondition — the vocabulary.** Tagging needs the critical-marker vocabulary from
setup (`policies.test_selection.critical_markers`). With it absent, skip the pass and
say so in the report (*"critical tagging skipped — no critical-marker vocabulary; run
`/pre-merge --update`"*). Never invent a vocabulary.

---

## 1 — Inventory

Enumerate the test tree and split it on the platform's marker (`critical_markers.<platform>`, defaults in
[`../../shared/refs/component-catalog.md`](../../shared/refs/component-catalog.md)):
the `@critical` title tag, `@pytest.mark.critical`, the `TestCritical*` naming
convention, membership of `Critical.xctestplan`, the `@Critical` annotation.

**Diff against the last pass, don't re-walk history.** Read
`criticality_review` from `devkit/policy.json` — `{reviewed_at, suite_hash}`, the
`source_signature` pattern applied to the **test tree** (sha256 over the sorted
test-file paths + each file's declared markers,
`../../shared/refs/policy-schema-pre-merge.md` § `criticality_review`). Recompute the
hash; enumerate only what changed since. **Stamp absent ⇒ "never reviewed" ⇒ full
inventory** — never a validation error, and identical to the full-inventory mode
the enabling interview runs (`protocol-init.md`, § *Enabling the flag*).

Record the inventory counts for the report: total tests · tagged · untagged ·
untagged-since-last-review. Zero untagged since the last review ⇒ the pass ends
there: nothing to tag, nothing written, stamp unchanged.

---

## 2 — Decide (with cited evidence)

For each **untagged** test, decide `critical` / `not-critical`. Every `critical`
decision carries **cited evidence** — with nothing to cite, the test stays
`not-critical`, never a bare assertion:

| Signal | Evidence line cites |
|---|---|
| **PRD traceability** | the test locks in a PRD acceptance criterion the PRD marks **P0/critical** — cite `prd-<n>` + the criterion id (F-ID / §3 row) |
| **Failure history** | the test has produced a **blocker/high** finding in a past verdict — cite the run artifact (`.pre-merge/<ts>/*.json`, `reports/*.json`) + the finding's `rule` |
| **Graph position** | the test covers high fan-in / hotspot code — cite the symbol/file + the metric (tokensave `test_risk`, `hotspots`, `rank`) |

The deterministic signals are scored first; the model's job is to **compose the
decision and the citation**, not to invent a signal. Graph unavailable ⇒ that row
carries no graph evidence (it never upgrades a decision on a guess).

Two rules the pass never breaks:

- **Never re-grades an existing tag.** A tag already in the test tree is a human
  decision; this pass decides for the **untagged** only.
- **Never removes a tag.** Removing a marker makes a test run less often, which is not
  safe without a human. The pass only adds tags.

---

## 3 — Apply

1. Write the `critical` markers into the test files, using the platform's mechanism
   (title tag / `@pytest.mark.critical` / rename to `TestCritical*` / add the suite to
   `Critical.xctestplan` / add the `@Critical` annotation).
2. **Restamp `criticality_review`** — `{reviewed_at: <today>, suite_hash: <recomputed>}`
   via `.claude/scripts/script-policy-set.py`. No other policy key changes.
3. Commit the tagged test files **and** `devkit/policy.json` on the branch as **one
   commit**: `test(criticality): tag <n> critical tests` — one commit, so the diff is
   reviewable as a unit and the tree is clean after the pass.
4. **List the tags in the report**: a `### Critical tests tagged` block under the run
   report's `## Work done` — one line per tagged test with its evidence line, plus the
   one-line summary *"N tagged critical, M left untagged — the critical floor is now K
   tests."*

Selection (§3c) then runs with the refreshed floor.

---

## Full-inventory mode (the enabling interview's initial tagging pass)

The test-selection **enabling interview** (`protocol-init.md`, § *Enabling the flag*)
runs §§1–3 with **no stamp** — full inventory rather than a since-last-review diff —
so the critical floor is non-empty from day one. Same decisions, same evidence rule,
same commit, same stamp. It is the second (and only other) writer of
`criticality_review` (`../../shared/refs/policy-schema-pre-merge.md`).

---

## References

- [`executor.md`](executor.md) §3c — the selection rule, §3c.4 this pass's place in the run, §3c.3's recording contract
- [`protocol-init.md`](protocol-init.md) — setup and `--update`, incl. the test-selection enabling interview + the disable contract
- [`universal/protocol-regression.md`](universal/protocol-regression.md) — born-tagged authoring, the primary tag-drift defense this pass backstops
- [`../../shared/refs/policy-schema-pre-merge.md`](../../shared/refs/policy-schema-pre-merge.md) — `policies.test_selection` and the `criticality_review` stamp; the writer table is in [`policy-schema.md`](../../shared/refs/policy-schema.md)
- [`../../shared/refs/component-catalog.md`](../../shared/refs/component-catalog.md) — the `critical_markers` per-platform defaults and their mechanisms
