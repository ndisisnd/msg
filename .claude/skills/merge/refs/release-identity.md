---
name: merge-release-identity
description: The release identity contract for merge --production — version, build number, provenance, tag. The version source of truth is the last v* tag reachable on prod (READ-ONLY — merge never writes a VERSION file or a bump commit). script-release-identity.sh resolves the whole set; this ref is the contract it implements and the rules the model applies to its verdicts.
---

# Release identity — version, build number, provenance, tag

A release needs an **identity**: what version is this, what build number rides to
each store, was the deployed artifact actually built from the commit a human
signed off, and a durable marker on `prod` recording the answer.

Every part of that is deterministic, so it is **scripted, not reasoned**:

```bash
S=.claude/scripts/script-release-identity.sh
bash "$S" --prod "$PROD" [--bump major|minor|patch] [--version <x.y.z>] [--probe-sha <sha>]
```

It emits `key=value` lines — `CURRENT_TAG`, `CURRENT_VERSION`, `CURRENT_BUILD`,
`NEXT_VERSION`, `BUMP`, `BUILD`, `NEXT_TAG`, `VERSION_REGRESSION`,
`NONMONOTONIC_BUILD`, `PROVENANCE`, and a `VERDICT` — and is **read-only**: it
never tags, never pushes, never fetches. `refs/production.md` wires it into the
steps; this ref is the contract.

## Source of truth: the last `v*` tag on `prod` — READ-ONLY

The authoritative version is the **newest `v*` tag reachable on the prod
branch**. Nothing else — no `VERSION` file, no manifest, no bump commit. This is
decisive, not incidental: merge is forbidden from modifying source
(`../shared/refs/safety-floor.md`; its sanctioned writes are enumerated once in
`SKILL.md`). A file-based version would force a bump commit it may not make. A
tag is **release metadata attached to a commit, not a change to any tracked
file**, so tagging is consistent with the floor. merge **reads** tags to
resolve the current version and **writes exactly one new tag** at release; it
never rewrites or deletes tags.

Scoping is `--merged origin/$PROD` (a tag on an unmerged branch is not a
release), newest-semver-first. Tags parse as `v<major>.<minor>.<patch>[+<build>]`;
the `+<build>` metadata is informational for version ordering (semver ignores
build metadata) and read separately for the monotonicity check. No tag at all ⇒
current is `0.0.0`, build `0`.

## Next version — default **minor** bump, overridable

merge ships PRDs (features), so the default bump is **minor**. From `0.0.0`
the first release is `v0.1.0`.

| Override | Effect |
|---|---|
| `--bump major` \| `minor` \| `patch` | pick the semver level |
| `--version <x.y.z>` | set the exact next version; must be **strictly greater** than the current tag's version, else `VERSION_REGRESSION=true` → refuse **`version_regression`** (`refs/refusal-patterns.md`) — a release never goes backward. Resolved early, so this refusal fires **before** the lock is acquired |

Neither given → **minor**. The resolved version + tag is surfaced in the Step-3
final confirm and the release-PR body **before** anything ships, so the human
sees which tag will be cut and can cancel.

## Build number — derived from history, monotonic by construction

The build number is **derived, not authored**: the commit count reachable on prod
at the commit being released, shared by every platform. Chosen over a per-tag
counter because it is monotonic by construction on an append-only prod branch and
needs **no state** beyond git history — credential-free and deterministic.

**Read it at tag-time truth, after the merge.** The release commit only lands on
prod at Step 5, so the script must be re-run **after that merge and the Step-5
fetch**. The early run (for the Step-3 confirm) is a **preview** that does not yet
count the merge commit. Reading it pre-merge would undercount by the merge commit
and let a same-commit re-release tag a build it should not.

**Monotonicity — `submission` platforms, BEFORE submit.** Stores reject a build
number ≤ the last accepted one, so `NONMONOTONIC_BUILD=true` **refuses
`nonmonotonic_build`** before running any `submission` platform's
`production_deploy_cmd` — naming the resolved build and the last tagged build.
Because the comparison uses the **merge** count, it can only trip when the
release commit did not advance prod (re-releasing the same commit, or
rewound/divergent history) — a genuine stop, not a nuisance. A **legacy tag** with
no `+<build>` has its build reconstructed as the commit count at that tag, so the
comparison stays apples-to-apples. `deploy` platforms are not build-gated — no
store monotonicity contract applies.

## Provenance — the deployed artifact came from this release

Staging and prod are built by **separate cmd runs**; nothing structurally forces
the artifact `production_deploy_cmd` ships to be the commit a human tested. The
anchor is the sign-off pin — `staging-signoff: <date>@<certified_sha>` records the
exact commit certified.

**The read is declared, not probed.** A platform's optional `version_probe`
(`template-PLATFORMS.md`) prints the deployed/submitted artifact's source commit;
pass it as `--probe-sha`:

- `PROVENANCE=verified` — the commit is inside **this release's window**: reachable from prod **and not already contained in the current tag**.
- `PROVENANCE=fail` — **outside** the window ⇒ a provenance finding (`refs/output-schema.md`), verdict `fail`: the artifact shipped was built from a commit no human certified for this release (a stale CI cache, the wrong branch, a hand-built artifact from an old checkout). A bare ancestor-of-prod test is **not enough** — last year's release commit is also an ancestor. This fails the run; it is **not** a refusal, the merge already stands.
- `PROVENANCE=asserted_unverified` — no probe declared: merge deployed from the merged prod branch it controls, recorded with a note, never a fail. Declaring a probe upgrades the assertion to a verified check.

(First-ever release, no current tag ⇒ the whole prod history is the window.)

## Tag at release — the one new write, only after success

After a **successful** `--production` — merged, deployed (or
deploy-skipped-with-note), verified (or verify-skipped-with-note), provenance not
`fail` — merge cuts the annotated tag `NEXT_TAG` on the prod release commit
and pushes it (`refs/production.md` Step 9). Both the tag target and the build are
**merge** values, relying on the Step-5 fetch; without it the tag would point
at the previous release's head.

- The tag writes **no tracked file** — the tree is unchanged, so the safety floor holds.
- A **failed** release does **not** tag — an unverified release gets no version identity, mirroring the skipped intake stamp.
- No remote / push rejected → **skip the tag with a note**, never a hard failure: the release shipped and the tag is metadata.

## Release notes — generated from the shipping PRDs

The annotated tag's message (reused by the release-PR body) is generated, not
hand-typed:

- One line per shipped PRD: `prd-<n> · <feature>` + its linked report.
- The commit list `git log --oneline <CURRENT_TAG>..origin/$PROD` for the tag. The **PR body** uses the flow-dependent head instead — `$PROD..$STG` in `staged` flow, `$PROD..<feature-branch>` in `direct`.
- The resolved `v<x.y.z>+<build>` and, per `submission` platform, the submitted track + the monitor-handoff pointer (`refs/submission.md`).

## What this ref does NOT do

- No `VERSION`/manifest file, ever — tags only.
- No bump **commit** — the version is computed and tagged, never committed.
- No auto-bump beyond the default-minor rule; the human sees and can override the resolved version at the double-confirm before any tag is cut.
- No store-number probing — build numbers come from git history, and the monotonicity check compares against merge's own last tag, not a store query.
