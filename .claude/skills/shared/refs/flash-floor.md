---
name: flash-floor
description: The never-relaxed safety floor and common semantics every msg mode obeys. Referenced by each skill's refs/flash/mode-flash.md so no flash path re-states or re-implements them. v2 — per-skill write powers replace v1's blanket "never push / never PR / never merge".
---

# Safety floor (v2)

Every `--flash` mode loads its own `refs/flash/mode-flash.md` **instead of** the
comprehensive refs and obeys this file. Flash trades execution count (subagents,
buckets, gates, interview turns) for speed — **never** correctness or safety.
Some skills (notably `post-merge`) have **no flash mode at all** — their gates
never collapse.

## Write powers are per-skill, not blanket

v1's floor said "never push / never PR / never merge" for everyone. v2 replaces
that with **scoped write powers** — the harness now ships, so *someone* has to
open PRs and merge. The rule is that each skill's write power is exactly bounded,
and no skill can exceed its scope:

| Skill | May write | Must never |
|---|---|---|
| `eng` | commits to `feat/prd-<n>-*` **feature branches only** | push to / merge into / open a PR against `staging` or `main` |
| `pre-merge` | opens **exactly one** PR `feature → staging`, plus the D7 sync-merge commit | merge any PR; touch `main`; modify source |
| `post-merge` | the **only** skill that merges — `staging` via a green-CI PR merge, `production` via the double-confirmed `staging → main` PR merge; stamps `staging-signoff:`; runs deploys | reach `main` any other way than the double-confirmed release; merge on red/pending CI; self-certify staging; modify source |
| all others | their own artifacts (PRDs, reports, tickets, devkit appends) | push, merge, or open PRs |

**Nothing reaches `main` except from `staging`, and only via `post-merge
--production`.** That is the single production path; no flag, mode, or
orchestrator opens another.

## Human gates — never removed, in any mode

Branch protection enforces green CI on `staging` and `main` (and ≥1 human review
on `main`) — machine-enforced, not convention. On top of that, these human gates
fire in every mode, flash included:

- **Preview-deploy approval** — pre-merge's Step 8, on material UI/backend changes.
- **Staging sign-off** — a human tests staging before `post-merge --production` will run (`staging-signoff:` stamp).
- **Production double-confirmation** — two separate approvals before anything ships to `main`.

## Unchanged from v1 — always on, every skill, every mode

DB/data/prod-config pauses (`eng-db-touch.sh`) · breaking-change pauses · branch
isolation (`feat/prd-<n>-*`) · secret scan · frontmatter stamps · F-ID stability
· PRD §9 ledger · gate-fail ticket · pre-merge refusals.

## Common flash semantics

- Auto-proceed at plan/confirm gates (the safety-floor pauses and human gates above still fire).
- Cap tool stdout to ~50 lines; write full logs to a file and print its path.
- Emit a summary + artifact path, not a full JSON echo.

## Reuse v2 substrate — do not re-implement

Flash consumes, never re-copies: PRD-digest slices (`scan-prd-digest.py`), the
verify prelude (`verify-prelude.md`), flag-based injected cook, the session cache
(`session-cache.md`).

## Mode propagation (T3.3)

An orchestrator forwards its **resolved** mode into every `Skill(...)` handoff and
`Agent(...)` prompt; a leaf skill never re-reads the pref mid-pipeline.
`post-merge` is the exception that takes no mode — its gates never collapse, so a
forwarded `--flash` is accepted and discarded.
