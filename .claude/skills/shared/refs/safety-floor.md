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
| `merge` | the **only** skill that merges, plus the stamps, reports and release tags its own protocol enumerates — canonical list: `merge/SKILL.md` (Hard refusals) | reach `main` any other way than the double-confirmed release; merge on red/pending CI; self-certify staging; modify source |
| `emulate` | **nothing in the repo** — no commit, branch, PR, stamp or report; its only writes are its own launch logs under `.emulate/` | modify source; write any tracked file; touch `.gitignore` |
| all others | their own artifacts (PRDs, reports, tickets, devkit appends) | push, merge, or open PRs |

**Nothing reaches `main` except from `staging`, and only via `merge
--production`.** That is the single production path; no flag or orchestrator
opens another.

**Killing processes is a write power too.** `/emulate` is the only skill that
signals a process it did not start, and the power is bounded three ways: an
allowlist of build-tool shapes compiled into `script-emulate-sweep.sh` (never a
user-supplied pattern, never a broad `killall`), attribution to the current repo
(working directory or command line inside it, or holding the dev-server port
about to be bound), and TERM before KILL. Every kill is announced with its pid
and reason, and `--dry-run` prints the same list while signalling nothing.

## Human gates — never removed

Branch protection enforces green CI on `staging` and `main` (and ≥1 human review
on `main`) — machine-enforced, not convention. On top of that, these human gates
always fire:

- **Staging sign-off** — a human tests staging before `merge --production` will run (`staging-signoff:` stamp). In `staged` flow this is **the** human look at the running feature; the old pre-merge preview approval was removed because it tested the same content twice, and its judgment moved here — not away.
- **Direct-flow human test** — with no staging branch, `merge --production` asks the human to attest they have tested the build **before** the merge. This is the `direct` flow's equivalent of the staging sign-off, and it is the only remaining pre-merge-time human look.
- **Production double-confirmation** — two separate approvals before anything ships to `main`.

## Secret-scan floor — never hollow

The `security` gate component is `mandatory`, and secret-scan **coverage** is a hard
requirement to *pass* — not merely a scanner that runs *if present*. When **no** secret
scanner is detected, `security` emits a `blocker` (`no-secret-scanner`,
`safety-floor-unmet`): there is **no green-gate path without secret-scan coverage**. A
leaked credential is the highest-stakes, cheapest-to-catch failure, so this is the one
signal the floor genuinely guarantees. The scanner **install** stays per-item approved
(the gated-install rule holds — `/pre-merge --init` strongly offers gitleaks and flags
declining it as a safety-floor gap), but a *passing* gate can never have had zero
secret-scan coverage. SAST / dependency / container / `/cook` semantic layers stay
best-effort — their absence is a note, never a blocker (`pre-merge/refs/universal/protocol-security.md`).

## Always on, every skill

DB/data/prod-config pauses (`script-eng-db-touch.sh`) · breaking-change pauses · branch
isolation (`feat/prd-<n>-*`) · the secret-scan floor above · frontmatter stamps ·
F-ID stability · PRD §7 ledger · gate-fail ticket · pre-merge refusals.
