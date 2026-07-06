---
name: verify-prelude
description: Shared setup artifact cached by review/test/pre-merge. Holds the resolved diff, detected tooling, and eval-set path so whichever runs first pays for setup once and the rest consume it.
---

# verify prelude

A cached JSON at `.claude/msg/cache/verify-prelude.json` that dedups the setup
work `review`, `test`, and `pre-merge` each otherwise redo: diff resolution,
tooling detection, and eval-set bootstrap. It obeys the session-cache contract
(`session-cache.md`) — source is canonical, cache is disposable, never a hard
failure.

## Shape

```json
{
  "head": "<git rev-parse HEAD>",
  "base": "<diff base/range, e.g. origin/main or HEAD~1>",
  "diff": { "base": "...", "files_changed": ["..."], "lines_added": 0, "lines_removed": 0, "commit_count": 0 },
  "tooling": { /* verbatim test-tooling-detect.sh JSON */ },
  "eval_set_path": "features/prd-<n>/review/eval_set.json"
}
```

- `diff` — from `pre-merge/scripts/resolve-diff.sh <base>`.
- `tooling` — from `.claude/scripts/test-tooling-detect.sh`.
- `eval_set_path` — the path `review` bootstraps (`null` if no PRD).

## Freshness key

`head` (`rtk git rev-parse HEAD`) **plus** `base` (the diff base/range). This is
the T1.11 freshness pattern pre-merge already uses for `--test-json`: fresh ⟺
both equal the current run's HEAD and base. Any mismatch, missing file, or
unparseable JSON → **stale**.

## Generate-if-stale rule

Whoever runs first regenerates on stale/missing/corrupt (running the scripts +
eval bootstrap it already runs), then best-effort writes the prelude. On the
normal pipeline (review→test→pre-merge) **review is the producer** — it already
resolves the diff, detects tooling, and bootstraps the eval-set.

## Per-skill consume rule

When a **fresh** prelude exists, later skills consume it instead of redoing setup:
- **test** — take `tooling` + `eval_set_path` (wire into `--eval-set`) rather than re-detecting/re-deriving.
- **pre-merge** — take `diff` + `tooling` rather than re-resolving/re-detecting; composes with the existing `--test-json` bucket skip.

## Standalone fallback

No prelude, or stale → each skill generates/self-sets-up exactly as today. The
prelude is a dedup optimization only; behavior with no prelude is unchanged.
