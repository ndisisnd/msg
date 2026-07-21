---
name: safety-floor
description: The never-relaxed safety floor every msg skill obeys — scoped per-skill write powers, the always-on human gates, and the pauses that fire on every invocation. Cited by any skill that ships, merges, or writes.
---

# Safety floor

Every msg skill obeys this file. It bounds what each skill may write, fixes the
human gates that never collapse, and lists the pauses that fire on every run.

## Write powers are per-skill, not blanket

Each skill's write power is exactly bounded, and no skill can exceed its scope —
the harness ships, so *someone* has to open PRs and merge, but only within these
lanes:

| Skill | May write | Must never |
|---|---|---|
| `eng` | commits to `feat/prd-<n>-*` **feature branches only** | push to / merge into / open a PR against `staging` or `main` |
| `pre-merge` | opens **exactly one** PR `feature → staging`, plus the D7 sync-merge commit | merge any PR; touch `main`; modify source |
| `post-merge` | the **only** skill that merges — `staging` via a green-CI PR merge, `production` via the double-confirmed `staging → main` PR merge; stamps `staging-signoff:`; runs deploys; cuts the release + transient release-lock **git tags** (metadata on a commit — no tracked file, so not a source write) | reach `main` any other way than the double-confirmed release; merge on red/pending CI; self-certify staging; modify source |
| all others | their own artifacts (PRDs, reports, tickets, devkit appends) | push, merge, or open PRs |

**Nothing reaches `main` except from `staging`, and only via `post-merge
--production`.** That is the single production path; no flag or orchestrator
opens another.

## Human gates — never removed

Branch protection enforces green CI on `staging` and `main` (and ≥1 human review
on `main`) — machine-enforced, not convention. On top of that, these human gates
always fire:

- **Preview-deploy approval** — pre-merge's Step 8, on material UI/backend changes.
- **Staging sign-off** — a human tests staging before `post-merge --production` will run (`staging-signoff:` stamp).
- **Production double-confirmation** — two separate approvals before anything ships to `main`.

## Secret-scan floor — never hollow (C9)

The `security` gate component is `mandatory`, and secret-scan **coverage** is a hard
requirement to *pass* — not merely a scanner that runs *if present*. When **no** secret
scanner is detected, `security` emits a `blocker` (`no-secret-scanner`,
`safety-floor-unmet`): there is **no green-gate path without secret-scan coverage**. A
leaked credential is the highest-stakes, cheapest-to-catch failure, so this is the one
signal the floor genuinely guarantees. The scanner **install** stays per-item approved
(the gated-install rule holds — `/pre-merge --init` strongly offers gitleaks and flags
declining it as a safety-floor gap), but a *passing* gate can never have had zero
secret-scan coverage. SAST / dependency / container / `/cook` semantic layers stay
best-effort — their absence is a note, never a blocker (`pre-merge/refs/universal/protocol-security.md`, C9).

## Always on, every skill

DB/data/prod-config pauses (`eng-db-touch.sh`) · breaking-change pauses · branch
isolation (`feat/prd-<n>-*`) · **secret scan (guaranteed floor — no-scanner blocks, C9)**
· frontmatter stamps · F-ID stability · PRD §9 ledger · gate-fail ticket · pre-merge
refusals.
