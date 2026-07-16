---
name: msg-protocol-init
description: >
  Protocol for /msg --init — one-time project bootstrap. Scans the working
  directory, runs a batched interview (project basics, architecture, release
  flow, design system), then creates a `devkit/` directory containing AHA.md,
  GLOSSARY.md, ARCHITECTURE.md, DESIGN-SYSTEM.md, OPEN-QUESTIONS.md, and the
  seed `policy.json` (release-flow policy, `init:false`), plus root-level
  README.md, .gitignore, CLAUDE.md, CHANGELOG.md, and the features/ directory.
  Idempotent — skips files that already exist; never overwrites. All other msg
  skills read these files but never create them.
type: reference
---

# Protocol: --init

## Usage

**Invoke**: `/msg --init` — optionally pass a one-line project brief as input.

- Slash command `/msg --init`
- Natural language: "initialise project", "bootstrap repo", "set up the framework", "start a new project", "init the msg framework"
- Context: empty or near-empty repository where the user asks Claude to set up project structure
- Hand-off from another msg skill (e.g. `plan-pm`) when `AHA.md` or `GLOSSARY.md` is missing

**Hard refusals:**
- Working directory is not a git repository: emit a warning and ask the user to confirm via `AskUserQuestion` before proceeding. Do not block — proceed if confirmed.

## What is devkit

`devkit/` is a directory of agent-readable context files that lives at the root of every msg-initialised project. It is the single source of truth that all other msg skills read before doing any work — but only `/msg --init` creates it.

| File | Purpose |
|------|---------|
| `AHA.md` | Institutional knowledge log — past learnings that future agents must not repeat |
| `GLOSSARY.md` | Canonical domain terms — ensures consistent naming across all agents |
| `ARCHITECTURE.md` | System constraints, layers, and integration points — scopes what agents may touch |
| `DESIGN-SYSTEM.md` | Component registry — tells agents which UI components exist and what needs data ingestion |
| `OPEN-QUESTIONS.md` | Unresolved decisions — build subagents write here when they hit ambiguity |
| `PLATFORMS.md` | Per-platform tolerance profiles + deploy pipeline — read by `/pre-merge` Step 0 (strictness profile + bucket set) and by `/post-merge` (`staging_deploy_cmd` / `production_deploy_cmd`) |
| `policy.json` | Committed release-flow + tooling policy read by both gates. `/msg --init` seeds it (`version`, `init:false`, `policies.release_flow`); `--doctor` completes it (tooling, branch-protection, `init:true`); `/msg --init-staging` flips the flow to `staged`. Schema: [`shared/refs/policy-schema.md`](../../shared/refs/policy-schema.md) |

**Convention**: `devkit/` files are written once by `/msg --init` and updated incrementally by agents (e.g. `plan-em` appends to `AHA.md`). They are never deleted or recreated by other skills. If `devkit/` is absent, any skill that reads it must halt and direct the user back to `/msg --init`.

## Inputs

| Name | Format | Source |
|------|--------|--------|
| Working directory state | `key=value` lines from `init-setup.sh` | `init-setup.sh` at Step 1 |
| Project metadata | Interview answers | `AskUserQuestion` at Step 2 |
| Architecture details | Interview answers | `AskUserQuestion` at Step 2 |
| Release flow | Interview answers (mode + branches), pre-filled from branch topology | `AskUserQuestion` at Step 2, Call 4 |
| Design system details | Interview answers | `AskUserQuestion` at Step 2 |
| Optional brief | Free text | User message at invocation |

## Outputs

| Name | Format | Destination |
|------|--------|-------------|
| devkit/ | Directory — agent context files | `<cwd>/devkit/` |
| devkit/AHA.md | Markdown from `refs/init/templates/template-AHA.md` | `<cwd>/devkit/AHA.md` |
| devkit/GLOSSARY.md | Markdown from `refs/init/templates/template-GLOSSARY.md` | `<cwd>/devkit/GLOSSARY.md` |
| devkit/ARCHITECTURE.md | Markdown from `refs/init/templates/template-ARCHITECTURE.md`, customised with platform and architecture interview | `<cwd>/devkit/ARCHITECTURE.md` |
| devkit/DESIGN-SYSTEM.md | Markdown from `refs/init/templates/template-DESIGN-SYSTEM.md`, customised with design system interview | `<cwd>/devkit/DESIGN-SYSTEM.md` |
| devkit/OPEN-QUESTIONS.md | Markdown from `refs/init/templates/template-OPEN-QUESTIONS.md`, written by build subagents for unresolved ambiguity | `<cwd>/devkit/OPEN-QUESTIONS.md` |
| devkit/PLATFORMS.md | Markdown from `refs/init/templates/template-PLATFORMS.md`, one default row per shipping platform selected at the interview (P1 answer) | `<cwd>/devkit/PLATFORMS.md` |
| devkit/policy.json | JSON seed skeleton written by the skill (not `init.sh` — the skill stamps `generated`); `version:1`, `init:false`, `generated_by:"msg --init"`, `policies.release_flow` from Call 4. Only these keys (AC-LC1). Never overwritten (AC-LC7). Schema: `shared/refs/policy-schema.md` | `<cwd>/devkit/policy.json` |
| README.md | Markdown from `refs/init/templates/template-README.md`, customised with project name | `<cwd>/README.md` |
| .gitignore | Plain text from `refs/init/templates/template-gitignore.md`, stack-specific | `<cwd>/.gitignore` |
| CLAUDE.md | Markdown from `refs/init/templates/template-CLAUDE.md`, customised with platform | `<cwd>/CLAUDE.md` |
| CHANGELOG.md | Markdown from `refs/init/templates/template-CHANGELOG.md`, maintained by the `kermit` commit-gate hook (not by msg skills) | `<cwd>/CHANGELOG.md` |
| INTAKE.md | Markdown from `refs/init/templates/TEMPLATE-INTAKE.md` — the root backlog ledger (D13: repo root, **not** devkit/; it is a living ledger written by `/intake`, `plan-pm`, `post-merge`). Table header + status-lifecycle + grade-cell doc | `<cwd>/INTAKE.md` |
| features/ | Empty directory | `<cwd>/features/` |
| Manifest | Inline table — file, status, line count | Shown inline at Step 5 |

## Progress emission

Emit `Step X/5 — <title>` at the start of each step, unconditionally.

## Step-by-step protocol

**Step 1/5 — Scan the working directory**

Run `init-setup.sh` via Bash:

```
<msg_skill_dir>/refs/init/init-setup.sh "<cwd>"
```

Parse the five `key=value` lines it prints and hold `PRESENT`, `MISSING`, `STACK_HINTS`, and `STACK_DEFAULT` in conversation context.

If `ALL_COMPLETE=true`, emit `All foundational files exist — nothing to initialise.` and stop. Skip every later step.

**Step 2/5 — Interview (batched)**

Run the full interview — project basics, architecture, release flow, design system — as **batched `AskUserQuestion` calls, 2–4 questions per call**, in the five calls below (Call 5 fires only when a UI layer exists). The whole interview completes in **≤5 `AskUserQuestion` calls** (≤4 when there's no UI layer); no question is dropped. `AskUserQuestion` returns all answers in a call together, so ask each call's full set at once. Hold every answer in conversation context under the variable names given.

**Call 1 — Project basics** (Q1, Q2, Q2b, Q3):

| Q | Question | Format | Holds as |
|---|----------|--------|----------|
| 1 | Project name and one-line description? | Free text | `PROJECT_NAME`, `PROJECT_DESCRIPTION` |
| 2 | Primary platform or stack? | 4 options + Other: Web (frontend), Mobile (iOS/Android), Backend API, CLI | `PLATFORM` |
| 2b | What is the primary language or framework? (e.g. Flutter, Go, React, NestJS, Swift) | Free text | `LANGUAGE` |
| 3 | Team type? | 4 options + Other: Solo, Small team (<5), Cross-functional, Open source | `TEAM_TYPE` |

Skip Q2 when `STACK_HINTS` has exactly one entry — in that case set `PLATFORM = STACK_DEFAULT` directly, no question asked (Call 1 then carries Q1, Q2b, Q3 only). Otherwise, if `STACK_DEFAULT` is not "Not specified", pre-select it as Q2's default option (user can still pick another).

**Call 2 — Conventions + architecture** (Q4, A1, A2, A3):

| Q | Question | Format | Holds as |
|---|----------|--------|----------|
| 4 | Any house conventions already in place? | Free text or "None yet" | `CONVENTIONS` |
| A1 | Describe the major components of your system and how they interact. | Free text | `ARCH_OVERVIEW` |
| A2 | What external services or APIs will your system depend on? (e.g. Stripe, Auth0, S3) | Free text or "None" | `ARCH_EXTERNAL` |
| A3 | What data stores will you use? | 4 options + Other (multiSelect): PostgreSQL, MySQL / MariaDB, MongoDB / DynamoDB, Redis | `ARCH_DATA_STORES` |

**Call 3 — Architecture + platforms + UI gate** (A4, A5, P1, D1):

| Q | Question | Format | Holds as |
|---|----------|--------|----------|
| A4 | Authentication approach? | 4 options + Other: JWT / stateless sessions, OAuth 2.0 / SSO, API keys, None / not applicable | `ARCH_AUTH` |
| A5 | Deployment pipeline? (e.g. GitHub Actions → AWS ECS, Vercel, manual) | 4 options + Other: GitHub Actions, Vercel / Netlify, AWS / GCP / Azure, Not decided yet | `ARCH_DEPLOYMENT` |
| P1 | Which platforms does this project ship to? (drives `/pre-merge` tolerance profiles in `devkit/PLATFORMS.md`) | 4 options (multiSelect) + Other: Web, iOS, Android, macOS | `PLATFORMS_SHIPPED` |
| D1 | Does this project include a UI layer? | 2 options: Yes, No | (gates Call 5) |

P1 is the one v2 interview addition. Map the selected labels to the space-separated
platform keys `PLATFORMS` passes to `init.sh` (Web→`web`, iOS→`ios`, Android→`android`,
macOS→`macos`); an `Other` platform is recorded but has no baked default row — note it
so the user adds a row by hand. If P1 is skipped/empty, `init.sh` scaffolds all four
default rows for the user to prune.

**Call 4 — Release flow** (RF1, RF2, RF3):

First detect the current branch topology to pre-fill the answers (the skill runs this inline — `init.sh` never dates or branches):

```bash
git rev-parse --abbrev-ref HEAD 2>/dev/null                              # current branch
git show-ref --verify --quiet refs/heads/staging && echo HAS_STAGING     # staging present?
git show-ref --verify --quiet refs/heads/main    && echo HAS_MAIN
git show-ref --verify --quiet refs/heads/master  && echo HAS_MASTER
```

A `staging` branch already present → pre-select RF1 = **Staged**; otherwise pre-select **Direct**. Set RF2's prod default to `main` if present, else `master`, else the current branch.

| Q | Question | Format | Holds as |
|---|----------|--------|----------|
| RF1 | What's your release flow? | 2 options: `Staged` (feature → staging → prod), `Direct` (straight to prod) | `RELEASE_FLOW` |
| RF2 | Which branch is production? | Free text, default from topology (`main`/`master`/current) | `PROD_BRANCH` |
| RF3 | Staging branch name? (ignored when Direct) | Free text, default `staging` | `STAGING_BRANCH` |

Resolve after the call: if `RELEASE_FLOW` = `Direct`, discard RF3 and set `STAGING_BRANCH = null`; if `Staged` and RF3 is blank, `STAGING_BRANCH = "staging"`. These three feed the `policy.json` seed at Step 3 (`policies.release_flow`).

**Call 5 — Design system** (D2, D3, D4) — **only if D1 = "Yes"**:

| Q | Question | Format | Holds as |
|---|----------|--------|----------|
| D2 | Which component library are you using? | 4 options + Other: shadcn/ui, MUI / Material UI, Tailwind UI, Custom / none | `DS_LIBRARY` |
| D3 | Where do your design tokens live? (e.g. src/tokens/colors.ts, Figma variables, CSS custom properties) | Free text or "Not defined yet" | `DS_TOKENS` |
| D4 | Any naming or folder structure conventions for components? (e.g. Atomic design, feature-based folders) | Free text or "None yet" | `DS_CONVENTIONS` |

If D1 = "No", skip Call 5 entirely and set `DS_LIBRARY`, `DS_TOKENS`, `DS_CONVENTIONS` all to "Not applicable — no UI layer." (interview then completes in 4 calls).

**Step 3/5 — Generate missing files**

Run `init.sh` via Bash, passing all interview answers as env vars and the working directory as the positional argument:

```
PROJECT_NAME="<Q1 name>" \
PROJECT_DESCRIPTION="<Q1 description>" \
PLATFORM="<Q2 answer>" \
LANGUAGE="<Q2b answer>" \
TEAM_TYPE="<Q3 answer>" \
CONVENTIONS="<Q4 answer>" \
ARCH_OVERVIEW="<A1 answer>" \
ARCH_EXTERNAL="<A2 answer>" \
ARCH_DATA_STORES="<A3 answer>" \
ARCH_AUTH="<A4 answer>" \
ARCH_DEPLOYMENT="<A5 answer>" \
PLATFORMS="<P1 platform keys, space-separated — e.g. web ios>" \
DS_LIBRARY="<D2 answer>" \
DS_TOKENS="<D3 answer>" \
DS_CONVENTIONS="<D4 answer>" \
<msg_skill_dir>/refs/init/init.sh "<cwd>"
```

`init.sh` handles all template extraction, placeholder substitution, gitignore stack selection, `features/` creation, and idempotency. Capture its stdout — it includes the manifest for Step 5.

**Seed `devkit/policy.json`.** After `init.sh` returns (so `devkit/` exists), seed the committed
release-flow policy file. The **skill writes this one directly** (via `Write`) — not `init.sh` —
because the seed carries a `generated` date and scripts can't stamp the date. Schema authority:
[`shared/refs/policy-schema.md`](../../shared/refs/policy-schema.md) ("Seed skeleton").

1. **Idempotent — never overwrite.** If `<cwd>/devkit/policy.json` already exists, skip it
   entirely (do not read, do not rewrite) and note it as `skipped (exists)` alongside the manifest
   (AC-LC7). Consistent with `init.sh`'s "writes only files absent from the target" rule.
2. Otherwise write **exactly** the keys below — `version`, `init:false`, `generated`,
   `generated_by`, and `policies.release_flow` from Call 4, and **nothing else** (no `repo`, no
   `branch_protection`, no `steps` — those are `--doctor`'s to fill, which is why `init` is
   `false`) (AC-LC1). Stamp `generated` with today's date in `YYYY-MM-DD`:

```json
{
  "version": 1,
  "init": false,
  "generated": "<today, YYYY-MM-DD>",
  "generated_by": "msg --init",
  "policies": {
    "release_flow": {
      "mode": "<staged|direct>",
      "prod_branch": "<PROD_BRANCH>",
      "staging_branch": "<STAGING_BRANCH, or null in direct mode>"
    }
  }
}
```

Map Call 4: `RELEASE_FLOW` Staged → `"staged"`, Direct → `"direct"`; `prod_branch` = `PROD_BRANCH`;
`staging_branch` = `STAGING_BRANCH` (already resolved to `null` for direct, `"staging"` default for
staged). Add `devkit/policy.json` to the Step 5 manifest as `created` (or `skipped (exists)`).

**Step 4/5 — Verify**

`init.sh` exits non-zero and marks failures in the manifest if any write fails. If the script exits non-zero, surface its stderr and stop. Do not retry — the user re-runs or fixes manually.

**Step 5/5 — Emit manifest, offer branch-protection bootstrap, suggest next step**

Print the manifest from `init.sh` stdout verbatim.

**Branch-protection bootstrap (C3 — offer only when a GitHub remote exists).**
Check for a GitHub remote:

```bash
git remote -v 2>/dev/null | grep -qi github.com && command -v gh >/dev/null 2>&1 && echo HAS_GH_REMOTE
```

If `HAS_GH_REMOTE` prints, the v2 ship pipeline (`/post-merge`) needs branch
protection on `staging` and `main` — green-CI-required on both, plus ≥1 human
review on `main` (D11). Offer it via **one** `AskUserQuestion`:

> header **Branch protection**, question "Set up branch protection on `staging` + `main` now? (required for `/post-merge`)"
> - **Yes, bootstrap it** — run `bash .claude/scripts/post-merge-protection.sh --bootstrap` (resolve locally-first, else `$HOME/.claude/scripts/…`); it's idempotent. Print each `BOOTSTRAPPED`/`BOOTSTRAP_FAILED` line.
> - **Skip** — note that `/post-merge` will refuse until protection is set; the user can re-run the script later.

No GitHub remote (or no `gh`) → skip this offer silently; `staging`/`main` and
protection are set up when the user first pushes and runs the script. Never a
hard failure.

Then emit a one-line next-step suggestion:

> Next: run `/plan-pm` to draft the first PRD.

Do not invoke another skill (the bootstrap script is not a skill). The next slash command is the user's choice.

## References

- `refs/init/init-setup.sh` — directory scanner; called at Step 1; outputs `ALL_COMPLETE`, `PRESENT`, `MISSING`, `STACK_HINTS`, `STACK_DEFAULT`
- `refs/init/init.sh` — deterministic template writer; called at Step 3 with all interview answers as env vars
- `refs/init/templates/template-AHA.md` — template for AHA.md (institutional knowledge log)
- `refs/init/templates/template-GLOSSARY.md` — template for GLOSSARY.md (canonical domain terms)
- `refs/init/templates/template-README.md` — template for README.md (project placeholder)
- `refs/init/templates/template-gitignore.md` — .gitignore content keyed by platform/stack
- `refs/init/templates/template-CLAUDE.md` — template for CLAUDE.md (Claude Code project instructions)
- `refs/init/templates/template-ARCHITECTURE.md` — template for ARCHITECTURE.md (architecture stub, populated from Step 2 interview)
- `refs/init/templates/template-DESIGN-SYSTEM.md` — template for DESIGN-SYSTEM.md (component registry, populated from Step 2 interview)
- `refs/init/templates/template-CHANGELOG.md` — template for CHANGELOG.md (code change log, maintained by the `kermit` commit-gate hook)
- `refs/init/templates/template-OPEN-QUESTIONS.md` — template for OPEN-QUESTIONS.md (ambiguity log, written by build subagents)
- `refs/init/templates/template-PLATFORMS.md` — template for devkit/PLATFORMS.md (per-platform tolerance profiles + staging/production deploy commands; assembled from the P1 interview answer)
- `refs/init/templates/TEMPLATE-INTAKE.md` — template for root `INTAKE.md` (the backlog ledger written by `/intake`; scaffolded here from its `## Template body` block, idempotently; repo root per D13, never devkit/)
- `.claude/scripts/post-merge-protection.sh` — branch-protection `--bootstrap` (offered at Step 5 when a GitHub remote exists) / `--verify` (used by `/post-merge`)
- `../../shared/refs/policy-schema.md` — canonical `devkit/policy.json` schema; the Step 3 seed writes the "Seed skeleton" (`version`, `init:false`, `generated`, `generated_by`, `policies.release_flow`)
