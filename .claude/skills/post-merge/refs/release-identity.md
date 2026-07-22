---
name: post-merge-release-identity
description: The release identity contract for post-merge --production. Version source of truth = the last v* tag reachable on the prod branch (READ-ONLY — post-merge never writes a VERSION file or a bump commit, per the safety floor). Next version computed from it (default minor bump, overridable); per-platform build numbers derived from the tag; provenance asserted against the signed-off commit; and, only after a successful release, a git tag v<x.y.z>+<build> is cut on prod (a tag is release metadata, not a source modification). Release notes generated for the tag from the shipping PRDs.
---

# Release identity — version, build number, provenance, tag

A release needs an **identity**: what version is this, what build number rides to
each store, was the deployed artifact actually built from the commit a human
signed off, and a durable marker on `prod` recording the answer. post-merge tracks
commits and PRs but had no artifact identity — for mobile/desktop the artifact is
the release unit and store-monotonic build numbers are ship-blocking. This ref is
the identity contract for `--production` (`refs/production.md` wires the steps).

## Source of truth: the last `v*` tag on `prod` — READ-ONLY (D8)

The authoritative version is **the newest `v*` tag reachable on the prod branch**.
Nothing else — no `VERSION` file, no manifest, no bump commit. This is decisive,
not incidental: post-merge is **forbidden from modifying source** (`../shared/refs/safety-floor.md`
— its sanctioned writes are enumerated once, canonically, in `../SKILL.md` (Hard
refusals); none of them is a tracked-file change). A file-based version would force
post-merge to make a bump commit it may not make (I3). Git tags sidestep that
entirely — a tag
is **release metadata attached to a commit, not a change to any tracked file** (the
tree is untouched), so tagging is consistent with the floor. post-merge **reads**
the tag to resolve the current version and **writes exactly one new tag** at
release; it never rewrites or deletes tags.

```bash
git fetch origin "$PROD" --tags --quiet
CURRENT_TAG=$(git tag --list 'v*' --merged "origin/$PROD" --sort=-v:refname | head -1)
#   e.g. v2.2.0+417   → version 2.2.0, build 417
#   none              → no release yet; treat CURRENT as v0.0.0, build 0
```

`--merged origin/$PROD` scopes to tags reachable on prod (a tag on an unmerged
branch is not a release). `--sort=-v:refname` gives newest-semver-first; take the
head. Parse `v<major>.<minor>.<patch>[+<build>]` — the `+<build>` metadata is
informational for the version compare (semver ignores build metadata in ordering);
the build integer is read separately for the monotonicity check below.

## Next version — default **minor** bump, overridable

post-merge ships PRDs (features), so the default bump is **minor**:
`v<major>.<minor>.<patch>` → `v<major>.<minor+1>.0`. From `v0.0.0` (no prior tag)
the first release is `v0.1.0`.

Override on the `--production` invocation (both additive, no new required arg):

| Override | Effect |
|---|---|
| `--bump major` \| `minor` \| `patch` | pick the semver level; `major` → `v<major+1>.0.0`, `patch` → `v<major>.<minor>.<patch+1>` |
| `--version <x.y.z>` | set the exact next version; must be **strictly greater** than `CURRENT_TAG`'s version (else refuse **`version_regression`**, `refs/refusal-patterns.md` — a release never goes backward). Resolved early with the rest of the identity, so this refusal fires **before** the lock is acquired |

Neither given → **minor**. The resolved next version + tag is surfaced in the
Step 3 final-confirm and the release-PR body **before** anything ships, so the
human sees exactly which tag will be cut and can cancel.

## Per-platform build number — derived from history, monotonic by construction

The build number is **derived**, not authored: it is the **commit count reachable
on prod at the commit being released**, shared by every platform.

```bash
BUILD=$(git rev-list --count "origin/$PROD")   # total commits on prod at release
```

**Read it at tag-time truth, after the merge (F13).** The release commit only lands
on prod at `--production` Step 5, so `BUILD` must be computed **after that merge and
the Step-5 fetch that refreshes `origin/$PROD`** (`refs/production.md` Step 5). The
value resolved early (for the Step-3 confirm) is a **preview** that does not yet count
the merge commit; the **authoritative** `BUILD` used by the Step-6 monotonicity gate
and the Step-9 tag is the post-merge recompute. Reading it pre-merge would undercount
by the merge commit and let a same-commit re-release tag a build it should not.

Chosen over a per-tag counter because it is **monotonic by construction** on an
append-only prod branch (every release adds ≥1 commit, so `BUILD` strictly
increases release-over-release) and needs **no state** beyond git history —
credential-free and deterministic, the small-team fit. All platforms share the one
`BUILD`; the new tag encodes it as `v<x.y.z>+<BUILD>`.

**Monotonicity check — `submission` platforms, BEFORE submit (AC-RI3).** Stores
reject a build number ≤ the last accepted one, so this is checked *before* running
`production_deploy_cmd` for any `submission` platform, using the **post-merge
recomputed `BUILD`** (above) against `last_tag_build`:

```bash
# last_tag_build: the +<build> metadata in CURRENT_TAG; fall back for a legacy tag
case "$CURRENT_TAG" in
  *+*) last_tag_build=${CURRENT_TAG##*+} ;;                 # v2.2.0+417 → 417
  "")  last_tag_build=0 ;;                                  # no prior tag
  *)   last_tag_build=$(git rev-list --count "$CURRENT_TAG") ;;  # F14: legacy tag, no +<build>
esac
```

- `BUILD > last_tag_build` → proceed.
- `BUILD ≤ last_tag_build` → **refuse `nonmonotonic_build`** (`refs/refusal-patterns.md`)
  before submitting — name the resolved build, the last tagged build, and that a
  store will reject a non-increasing build. Because `BUILD` is the **post-merge**
  count, this can only trip when the release commit did **not** advance prod
  (re-releasing the same commit, or rewound/divergent history) — a genuine stop, not
  a nuisance. **Legacy-tag fallback (F14):** a `CURRENT_TAG` with no `+<build>`
  metadata (a tag cut before this scheme) has its build reconstructed as
  `git rev-list --count <tag>` — the same commit-count basis, so the comparison stays
  apples-to-apples.

`deploy` platforms are not build-number-gated (no store monotonicity contract) —
the check is `submission`-only.

## Provenance — the deployed artifact came from the signed-off commit (AC-RI2)

Staging and prod are built by **separate cmd runs**; nothing structurally forces
the artifact `production_deploy_cmd` ships to be the commit a human tested. The
provenance anchor is **C2's sign-off pin** — `staging-signoff: <date>@<certified_sha>`
records the exact commit certified (`refs/staging.md`, `refs/production.md`
§ *Sign-off coverage*). The release commit is that certified sha (the coverage
check guarantees `origin/staging`'s content == the newest stamped sha, and prod is
the merge of it).

**The read is declared, not probed** — declared-artifact style, no new infra. A
platform's optional `version_probe` (`template-PLATFORMS.md`) prints the
**deployed/submitted artifact's source commit**. After deploy (`refs/production.md`
Step 7), for each platform with a `version_probe`:

```bash
PROBE_SHA=$( <version_probe> )    # e.g. curl -fsS https://app/version → the live commit
```

Verified only if `PROBE_SHA` is inside **this release's window** — equal to a
signed-off sha of this release, or reachable from prod **but not already in the last
tag** (`$CURRENT_TAG..origin/$PROD`, read after the Step-5 fetch):

```bash
# verified: reachable from prod AND not already shipped in CURRENT_TAG
git merge-base --is-ancestor "$PROBE_SHA" "origin/$PROD" \
  && { [ -z "$CURRENT_TAG" ] || ! git merge-base --is-ancestor "$PROBE_SHA" "$CURRENT_TAG"; }
```

- Both conditions hold (or `PROBE_SHA` equals a signed-off sha of this release) →
  **provenance verified**.
- `PROBE_SHA` is **outside the window** → **`fail`** with a provenance finding
  (`refs/output-schema.md`) — the artifact shipped was built from a commit no human
  certified for this release (stale CI cache, wrong branch, a hand-built `.ipa` from
  an old checkout). **A bare `is-ancestor origin/$PROD` is not enough**: last year's
  release commit is *also* an ancestor of prod, so the old test wrongly passed a
  stale checkout. Requiring the commit to be in `$CURRENT_TAG..origin/$PROD` excludes
  everything already released in a prior tag. This fails the run; it is **not** a
  refusal (the merge already stands). (`$CURRENT_TAG` empty ⇒ first-ever release ⇒
  the whole prod history is the window, so the tag-exclusion is skipped.)
- **No `version_probe` declared** → provenance is **asserted structurally**
  (post-merge deployed from the merged prod branch it controls) and recorded as
  `asserted (unverified)` with a note — never a fail. Declaring a probe upgrades
  the assertion to a verified check.

## Tag at release — the one new write, only after success (AC-RI1)

After a **successful** `--production` — merged, deployed (or deploy-skipped-with-note),
and verified (or verify-skipped-with-note), i.e. the same success condition that
lets Step 8 stamp intake `completed` — post-merge cuts the release tag on prod:

```bash
git tag -a "v${NEXT_VERSION}+${BUILD}" "origin/$PROD" -m "<release notes>"
git push origin "v${NEXT_VERSION}+${BUILD}"
```

Both `origin/$PROD` here and the `BUILD` above are the **post-Step-5-merge** values —
the tag lands on the release merge commit and encodes the recomputed build. This
relies on the Step-5 `git fetch origin $PROD` (`refs/production.md` Step 5); without
it the tag would point at the *previous* release's head.

- Annotated tag on the prod release commit. **This is the only new write C4 adds**,
  and it writes **no tracked file** — the tree is unchanged, so the safety floor
  holds (stated again because it is the crux of D8).
- A **failed** release (deploy/smoke failure, or a provenance `fail`) does **not**
  tag — an unverified release gets no version identity, mirroring the skipped
  intake stamp. Never tag on `fail`.
- The tag is **skipped with a note** (never a hard failure) if there is no remote
  or `git push` is rejected — the release shipped; the tag is metadata, so a push
  failure is surfaced, not treated as an un-ship.

## Release notes — generated for the tag from the shipping PRDs

The annotated tag's message (and the release-PR body reuse it) is generated from
the PRDs this release ships — not hand-typed:

- One line per shipped PRD: `prd-<n> · <feature>` + its linked report.
- The commit list `git log --oneline <CURRENT_TAG>..origin/$PROD` (for the tag, post
  merge). The **PR body** (Step 4, pre-merge) uses the flow-dependent head instead —
  `$PROD..$STG` in `staged` flow, `$PROD..<feature-branch>` in `direct` flow
  (`refs/production.md` Step 4).
- The resolved `v<x.y.z>+<build>` and, per `submission` platform, the submitted
  track + the monitor-handoff pointer (`refs/submission.md`).

## What this ref does NOT do

- No `VERSION`/manifest file, ever (I3/D8) — tags only.
- No bump **commit** — the version is computed and tagged, never committed.
- No auto-bump beyond the default-minor rule; the human sees and can override the
  resolved version at the double-confirm before any tag is cut.
- No store-number probing — build numbers are derived from git history, and the
  monotonicity check compares against post-merge's own last tag, not a store query.
