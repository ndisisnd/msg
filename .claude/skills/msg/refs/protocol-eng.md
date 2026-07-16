---
name: msg-protocol-eng
description: >
  The eng-mode Step 2 interview for /msg --init — direct execution, staff-engineer
  posture. Asks the user the technical questions (project basics, architecture,
  shipping platforms, release flow, design system) as batched AskUserQuestion calls
  and holds every init.sh variable in context. Selected by `--init --eng`, or by the
  Step 2 mode gate. The advisory alternative is refs/protocol-cto.md.
type: reference
---

# Protocol: --init, eng mode (Step 2 interview)

**Posture: direct execution.** The user makes the technical calls; you ask and
build. Do not recommend, do not editorialise, do not fill a silence with an
opinion — that is `refs/protocol-cto.md`'s job, and the user chose this mode
instead. Ask, record, move on.

This protocol owns **Step 2 only**. Steps 1, 3, 4 and 5 stay in
[`protocol-init.md`](protocol-init.md); it invokes this file and resumes at Step 3
with the variables below in context. Every variable named here is one `init.sh`
consumes — the mode is invisible downstream of Step 3.

## Top-up mode — asking a subset

When `protocol-init.md` invokes this protocol in **top-up mode**, it passes a
**required-variable subset** (computed from the missing files). Ask only the
questions that resolve a variable in that subset; drop every other question, and
collapse the remaining ones into as few calls as they fit — the call structure
below is the full-bootstrap shape, not a floor. A repo missing only `INTAKE.md`
resolves an empty subset and this protocol asks **nothing at all**.

Everything the subset omits keeps `init.sh`'s default. That is safe: the variable's
file already exists, and `init.sh` will not rewrite it.

The rest of this protocol describes the **bootstrap** shape — the full set.

## Call budget

The interview completes in **≤4 `AskUserQuestion` calls (≤3 when there is no UI
layer)**, 1–4 questions per call. `AskUserQuestion` returns all answers in a call
together, so ask each call's full set at once. Hold every answer in conversation
context under the variable names given.

## Call 1 — Project basics (Q1, Q2, Q2b)

| Q | Question | Format | Holds as |
|---|----------|--------|----------|
| 1 | Project name and one-line description? | Free text | `PROJECT_NAME`, `PROJECT_DESCRIPTION` |
| 2 | Primary platform or stack? | 4 options + Other: Web (frontend), Mobile (iOS/Android), Backend API, CLI | `PLATFORM` |
| 2b | What is the primary language or framework? (e.g. Flutter, Go, React, NestJS, Swift) | Free text | `LANGUAGE` |

**Q2 is conditional.** Skip it when `STACK_HINTS` has exactly one entry — in that
case set `PLATFORM = STACK_DEFAULT` directly, no question asked. Otherwise, if
`STACK_DEFAULT` is not "Not specified", pre-select it as Q2's default option (user
can still pick another).

**Q2b is conditional.** Ask it **only** when `LANG_DEFAULT` is `Not specified` —
i.e. `init-setup.sh` found no stack file it could key a language off, which is the
empty-repo bootstrap case. When `LANG_DEFAULT` names a language, pre-select it as
Q2b's default and still ask **only if** Q2 is being asked anyway (a free ride in an
already-firing call); when Q2 is skipped too, take `LANGUAGE = LANG_DEFAULT`
silently.

`LANGUAGE` must never reach Step 3 empty. `init.sh` picks the `.gitignore` section
off `LANGUAGE` first and `PLATFORM` second, so an unset `LANGUAGE` silently drops a
Dart/Flutter repo to a platform-level gitignore — and `CLAUDE.md` states the
project's language to every future agent, so an unset one reads as "Not specified"
forever. That is why the question can go but the variable cannot.

Call 1 can therefore carry 1–3 questions. Q1 always fires.

## Call 2 — Architecture (A1, A2, A3, A5)

| Q | Question | Format | Holds as |
|---|----------|--------|----------|
| A1 | Describe the major components of your system and how they interact. | Free text | `ARCH_OVERVIEW` |
| A2 | What external services or APIs will your system depend on? (e.g. Stripe, Auth0, S3) | Free text or "None" | `ARCH_EXTERNAL` |
| A3 | What data stores will you use? | 4 options + Other (multiSelect): PostgreSQL, MySQL / MariaDB, MongoDB / DynamoDB, Redis | `ARCH_DATA_STORES` |
| A5 | Deployment pipeline? (e.g. GitHub Actions → AWS ECS, Vercel, manual) | 4 options + Other: GitHub Actions, Vercel / Netlify, AWS / GCP / Azure, Not decided yet | `ARCH_DEPLOYMENT` |

**`ARCH_AUTH` is not asked in eng mode.** Not every project authenticates, so a
mandatory question is wrong. The key still reaches `init.sh`, which falls back to
its `[USER: authentication model]` placeholder — the same stub pattern every
unasked `ARCH_*` detail uses, and the user fills it in `devkit/ARCHITECTURE.md`.
cto mode derives it instead (`refs/protocol-cto.md`, architecture objective).

## Call 3 — Shipping platforms + release flow (P1, RF1)

First detect the current branch topology (the skill runs this inline — `init.sh`
never dates or branches):

```bash
git rev-parse --abbrev-ref HEAD 2>/dev/null                              # current branch
git show-ref --verify --quiet refs/heads/staging && echo HAS_STAGING     # staging present?
git show-ref --verify --quiet refs/heads/main    && echo HAS_MAIN
git show-ref --verify --quiet refs/heads/master  && echo HAS_MASTER
```

A `staging` branch already present → pre-select RF1 = **Staged**; otherwise
pre-select **Direct**.

| Q | Question | Format | Holds as |
|---|----------|--------|----------|
| P1 | Which platforms does this project ship to? (drives `/pre-merge` tolerance profiles in `devkit/PLATFORMS.md`) | 4 options (multiSelect) + Other: Web, iOS, Android, macOS | `PLATFORMS_SHIPPED` |
| RF1 | What's your release flow? | 2 options: `Staged` (feature → staging → prod), `Direct` (straight to prod) | `RELEASE_FLOW` |

Map P1's selected labels to the space-separated platform keys `PLATFORMS` passes to
`init.sh` (Web→`web`, iOS→`ios`, Android→`android`, macOS→`macos`); an `Other`
platform is recorded but has no baked default row — note it so the user adds a row
by hand. If P1 is skipped/empty, `init.sh` scaffolds all four default rows for the
user to prune.

**Branches are detected, not asked.** Resolve after the call:

- `PROD_BRANCH` = `main` if present, else `master` if present, else the current
  branch. Never asked — topology is a better answer than the user's recollection,
  and it is what makes a `master` repo bootstrap a `prod_branch` that actually
  exists.
- `STAGING_BRANCH` = `"staging"` when `RELEASE_FLOW` = `Staged`; **`null`** when
  `Direct`. The rule is now a constant, but it must still emit `null` for direct —
  the policy seed distinguishes the two.

These feed the `policy.json` seed at Step 3 (`policies.release_flow`).

## Call 4 — Design system (D2, D3, D4) — only when the UI predicate is true

**The UI predicate is derived, never asked.** Resolve it after Call 3, in order:

1. `PLATFORMS_SHIPPED` contains any of Web / iOS / Android / macOS → **UI = yes**.
   P1 wins any disagreement with `PLATFORM`: it names what the project *ships*,
   where `PLATFORM` names only the primary stack. A `Backend API` that ships to Web
   has a UI.
2. Otherwise map `PLATFORM`: `Web (frontend)` → **yes** · `Mobile (iOS/Android)` →
   **yes** · `Backend API` → **no** · `CLI` → **no**.
3. Otherwise — `PLATFORM` is `Other` free text, or empty → **yes**. Erring toward
   yes costs three skippable questions; erring toward no silently drops
   `DESIGN-SYSTEM.md` from a project that wanted it. The cheap error is the right
   default.

| Q | Question | Format | Holds as |
|---|----------|--------|----------|
| D2 | Which component library are you using? | 4 options + Other: shadcn/ui, MUI / Material UI, Tailwind UI, Custom / none | `DS_LIBRARY` |
| D3 | Where do your design tokens live? (e.g. src/tokens/colors.ts, Figma variables, CSS custom properties) | Free text or "Not defined yet" | `DS_TOKENS` |
| D4 | Any naming or folder structure conventions for components? (e.g. Atomic design, feature-based folders) | Free text or "None yet" | `DS_CONVENTIONS` |

UI predicate false → skip Call 4 entirely and set `DS_LIBRARY`, `DS_TOKENS`,
`DS_CONVENTIONS` all to "Not applicable — no UI layer." (interview then completes
in 3 calls).

**Known cost of the derivation.** A backend or CLI project that ships a UI anyway —
an admin panel, a TUI — can no longer say so directly; rule 1 recovers it only if
the user names that surface in P1. Accepted: cto mode recovers it via the
design-system objective, eng mode does not.

## Not asked in eng mode

| Variable | Why the question is gone |
|---|---|
| `CONVENTIONS` | Not asked — `init.sh` defaults it ("None recorded yet. Add house conventions as they emerge."), which is a sensible `CLAUDE.md`. cto derives it from its conventions objective. The **key survives**. |
| `ARCH_AUTH` | Not every project authenticates. Key survives; `init.sh` stubs it. See Call 2. |

Team type is not on this list because it no longer exists anywhere — msg is
solo-only by design, so the question and its key were deleted end-to-end.

## Hand back

Return to [`protocol-init.md`](protocol-init.md) Step 3 with every variable above
resolved. Step 3's env block is the contract — cross-check that none is unset
before invoking `init.sh`.
