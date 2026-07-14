---
name: post-merge-verify-deploy
description: Post-deploy verification — run each platform's smoke_cmd from devkit/PLATFORMS.md against the deployed target after every staging/production deploy. Exit 0 = verified; non-zero = a high `smoke-failed` finding that fails the run. Unconfigured ⇒ skipped with a note, never invented.
---

# Verify the deploy — smoke check against the live target

"The deploy command exited 0" is not "the app works". After every deploy —
`--staging` Step 5 and `--production` Step 7 — post-merge runs each platform's
`smoke_cmd` against the **deployed** environment and treats its exit code as the
verdict on whether the release is actually up. This is the pipeline's only look
at the running system; without it a mechanically-clean deploy of a broken app
reports `pass`.

## Resolve

1. From the same `devkit/PLATFORMS.md` parse as `refs/deploy.md`, read each
   shipping platform's `smoke_cmd` column.
2. Missing file, missing column (pre-`smoke_cmd` PLATFORMS.md), empty cell, or a
   `[USER: …]` placeholder → **skip verification for that platform with a note**
   (`verify.skipped += <platform>`). Never invent or infer a smoke command, and
   never treat a skipped check as a failure — but always surface the skip in the
   run report so the gap is visible.
3. A platform whose deploy was itself skipped (no deploy command) skips
   verification silently — there is nothing to verify.

## Run

For each platform with a resolved command:

- Run `smoke_cmd` from the repo root, after the deploy completes; capture
  stdout/stderr to a log alongside the deploy log.
- **Exit 0** → verified. Record it.
- **Non-zero exit** → the deploy is live but broken. Emit a canonical finding
  (`../shared/refs/finding-schema.md`):

```json
{
  "id": "verify-001",
  "source": "post-merge",
  "severity": "high",
  "category": "deploy",
  "rule": "smoke-failed",
  "message": "Staging deploy for web is up but failing its smoke check (exit 1)",
  "file": null,
  "line": null,
  "evidence": {
    "tool": "post-merge",
    "snippet": "<last lines of the smoke log — redact secrets>"
  },
  "suggestion": "The deployed target is not healthy. Fix forward via /pre-merge, or redeploy the previous build per the platform's rollback notes.",
  "repro": "<the exact smoke_cmd>",
  "regression_of": null
}
```

## Consequences by mode

| Mode | On smoke failure |
|---|---|
| `--staging` | Verdict `fail`. **Skip the human test script and the sign-off ask** (Steps 6–7) — never hand a human a script for a broken environment. The report points at fixing forward through `/pre-merge`. |
| `--production` | Verdict `fail`. **Skip the intake `completed` stamp** (Step 8) — a release that isn't verifiably live doesn't close its PRD. Surface the per-platform rollback notes (`rollback_possible`) prominently so the human can restore manually. |

The merge already happened in both cases — verification failure is surfaced
loudly, never silently swallowed, and never pretends to un-merge anything.

## Record

Carry the outcome into the clean-run summary (`refs/output-schema.md`):

```json
"verify": { "ran": true, "passed": true, "skipped": [] }
```

- `ran: false` when every platform skipped (nothing configured).
- `passed: false` (with the finding) on any smoke failure; `null` when `ran` is false.
- `skipped` lists platforms with no usable `smoke_cmd`.

The run report's `## Test results` gets one line per platform: verified /
smoke-failed / skipped (no smoke_cmd configured).
