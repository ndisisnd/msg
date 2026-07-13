---
name: verify-prelude
description: Setup artifact pre-merge produces once and consumes on re-run. Holds the resolved diff + detected tooling so the gate pays for diff-resolution / fingerprint setup once instead of on every stage or re-invocation.
---

# verify prelude

A cached JSON at `.claude/msg/cache/verify-prelude.json` that dedups the setup
work pre-merge does at the top of a run: diff resolution and tooling detection.
It obeys the session-cache contract (`session-cache.md`) — source is canonical,
cache is disposable, never a hard failure.

In v2 pre-merge is **both producer and consumer** — it writes the prelude when it
resolves the diff and detects tooling (gate steps 0–1), and consumes a fresh one
on a later re-invocation against the same HEAD/base instead of redoing that setup.
The old review→test→pre-merge producer/consumer split is gone (review and test are
retired).

## Shape

```json
{
  "head": "<git rev-parse HEAD>",
  "base": "<diff base/range, e.g. staging or origin/main>",
  "diff": { "base": "...", "files_changed": ["..."], "lines_added": 0, "lines_removed": 0, "commit_count": 0 },
  "tooling": { /* verbatim pre-merge-tooling-detect.sh JSON */ }
}
```

- `diff` — from `pre-merge/scripts/resolve-diff.sh <base>`.
- `tooling` — from `.claude/scripts/pre-merge-tooling-detect.sh`.

## Freshness key

`head` (`rtk git rev-parse HEAD`) **plus** `base` (the diff base/range). Fresh ⟺
both equal the current run's HEAD and base. Any mismatch, missing file, or
unparseable JSON → **stale**.

## Generate-if-stale rule

Pre-merge regenerates on stale/missing/corrupt (running `resolve-diff.sh` +
`pre-merge-tooling-detect.sh` it already runs at gate steps 0–1), then best-effort
writes the prelude. The write never fails the run.

## Consume rule

When a **fresh** prelude exists at gate step 0/1, pre-merge takes `diff` + `tooling`
from it rather than re-resolving/re-detecting. The empty-diff refusal is evaluated
on whichever `files_changed` was used (prelude or fresh).

## Standalone fallback

No prelude, or stale → pre-merge self-sets-up exactly as it would with no cache.
The prelude is a dedup optimization only; behavior with no prelude is unchanged.
