# review — Surface/fingerprint cache

Mirrors `/cook`'s cache-first design for the `/review → fix → /review` iterate loop: when the diff hasn't changed since the last run, Steps 2-4 (fingerprint, eval-set bootstrap + classification, surface derivation) are expensive and produce the same result — skip straight to Step 5. Only applies when a PRD is known; there is no stable cache location without one.

## Cache file

`features/prd-<n>/review/.surface-cache.json`, written at the end of Step 4 on every run (overwriting any prior cache):

```json
{
  "diff_hash": "<sha256 of the resolved diff text>",
  "fingerprint": {
    "active_domains": ["<domain>"],
    "mechanical_runners": [],
    "secret_scanner": null,
    "flag_inventory": ["<flag>"]
  },
  "eval_set": [ { "text": "<assertion>", "class": "executable" | "intent" | "negative" } ],
  "eval_set_source": "prd" | "tests" | "schemas" | "diff" | "mixed",
  "eval_set_path": "<path>",
  "surface": {
    "files_changed": [ "<path>" ],
    "uncovered_changes": [ "<path or description>" ],
    "undetected_domain_note": "<optional>",
    "modes": [ { "mode": "<mode-name>", "flags": [ "<flag>" ] } ]
  }
}
```

## Read path (start of Step 2)

1. PRD location is a cheap glob (`features/prd-*/prd-*.md` by recency) — do this first, before anything else in Step 2, regardless of cache hit or miss. If no PRD is found, skip the cache entirely and run Steps 2-4 normally (same as today).
2. Compute `diff_hash` from the Step 1 diff text (`rtk git diff HEAD | shasum -a 256`-equivalent — any stable hash of the exact diff content).
3. If `features/prd-<n>/review/.surface-cache.json` exists and its `diff_hash` matches: load `fingerprint`, `eval_set` (with `class` already attached), `eval_set_source`, `eval_set_path`, and `surface` from the cache. Emit `Cache hit — reusing fingerprint/eval-set/surface (diff unchanged since last run).` Skip Steps 2-4's own derivation work entirely and go straight to Step 5.
4. Otherwise (no cache file, or `diff_hash` mismatch — diff changed): run Steps 2-4 exactly as documented, no different from today. This is the common case on a fresh PRD or after any code change.

## Write path (end of Step 4)

If a PRD is known, write the cache file with the current run's `diff_hash`, fingerprint, classified `eval_set`, `eval_set_source`, `eval_set_path`, and `surface`. If no PRD is known, skip the write (nothing changes from today's behavior).

## Invalidation

Purely content-based: any change to the diff (even a single line) changes `diff_hash`, which invalidates the cache on the next run. There is no separate TTL or manual invalidation flag — this mirrors `/cook`'s cache, which also keys on content rather than time. `--full-secret-scan` and `--min-severity` do not affect the cache — they only change Step 6/7 behavior, not the fingerprint/eval-set/surface Steps 2-4 produce.

## Interaction with Adjust (Step 5)

If the user picks **Adjust** at Step 5 (cache hit or miss, doesn't matter), the adjusted surface/`eval_set[]` is used for this run but is **not** written back to the cache — the cache always reflects the last *auto-derived* Step 2-4 output, never a manual adjustment. This keeps the cache's meaning unambiguous: a hit always means "Steps 2-4 would derive this from the diff," never "the user asked for this once."
