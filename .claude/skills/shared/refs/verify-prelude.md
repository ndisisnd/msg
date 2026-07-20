---
name: verify-prelude
description: Setup artifact pre-merge produces once and consumes on re-run. Holds the resolved diff + detected tooling so the gate pays for diff-resolution / fingerprint setup once instead of on every stage or re-invocation.
---

# verify prelude

A cached JSON at `.claude/msg/cache/verify-prelude.json` that dedups the setup
work pre-merge does at the top of a run: diff resolution and tooling detection.
It obeys the session-cache contract (`session-cache.md`) — source is canonical,
cache is disposable, never a hard failure.

Pre-merge is **both producer and consumer** — it writes the prelude when it
resolves the diff at the top of a run, and consumes a fresh one on a later
re-invocation against the same HEAD/base instead of re-resolving. The old
review→test→pre-merge producer/consumer split is gone (review and test are
retired). In v3 the executor reads each component's resolved `run` from the
`components[]` manifest, so the prelude no longer detects tooling — only the diff.

## Shape

```json
{
  "head": "<git rev-parse HEAD>",
  "base": "<diff base/range, e.g. staging or origin/main>",
  "diff": { "base": "...", "files_changed": ["..."], "lines_added": 0, "lines_removed": 0, "commit_count": 0 },
  "tooling": null
}
```

- `diff` — from `pre-merge/scripts/resolve-diff.sh <base>`.
- `tooling` — **superseded in v3**: tooling is resolved at `--init`/`--update` into each
  component's `run` command in `devkit/policy.json` `components[]` (via the
  `preflight-check-*.sh` family), which the executor reads directly. The prelude no
  longer caches a tooling fingerprint (the field stays `null` for back-compat); it caches
  only the resolved `diff`.

## Freshness key

`head` (`rtk git rev-parse HEAD`) **plus** `base` (the diff base/range). Fresh ⟺
both equal the current run's HEAD and base. Any mismatch, missing file, or
unparseable JSON → **stale**.

## Generate-if-stale rule

Pre-merge regenerates on stale/missing/corrupt (running `resolve-diff.sh` at the
top of the run), then best-effort writes the prelude. The write never fails the run.

## Consume rule

When a **fresh** prelude exists at the top of the run, pre-merge takes `diff` from
it rather than re-resolving. The empty-diff refusal is evaluated on whichever
`files_changed` was used (prelude or fresh).

## Standalone fallback

No prelude, or stale → pre-merge self-sets-up exactly as it would with no cache.
The prelude is a dedup optimization only; behavior with no prelude is unchanged.
