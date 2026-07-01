---
name: msg-init
description: >
  One-time project bootstrap. Scans the working directory, runs a
  three-phase interview (project basics, architecture, design system),
  then creates a `devkit/` directory containing AHA.md, GLOSSARY.md,
  ARCHITECTURE.md, DESIGN-SYSTEM.md, and OPEN-QUESTIONS.md, plus
  root-level README.md, .gitignore, CLAUDE.md, CHANGELOG.md, and the
  features/ directory. Idempotent — skips files that already exist;
  never overwrites. All other msg skills read these files but never
  create them.
model: claude-sonnet-4-6
allowed_tools:
  - AskUserQuestion
  - Bash
  - Read
  - Write
---

# msg-init

## Usage

**Invoke**: `/msg-init` — optionally pass a one-line project brief as input.

- Slash command `/msg-init`
- Natural language: "initialise project", "bootstrap repo", "set up the framework", "start a new project", "init the msg framework"
- Context: empty or near-empty repository where the user asks Claude to set up project structure
- Hand-off from another msg skill (e.g. `plan-pm`) when `AHA.md` or `GLOSSARY.md` is missing

**Hard refusals:**
- Working directory is not a git repository: emit a warning and ask the user to confirm via `AskUserQuestion` before proceeding. Do not block — proceed if confirmed.

## What is devkit

`devkit/` is a directory of agent-readable context files that lives at the root of every msg-initialised project. It is the single source of truth that all other msg skills read before doing any work — but only `msg-init` creates it.

| File | Purpose |
|------|---------|
| `AHA.md` | Institutional knowledge log — past learnings that future agents must not repeat |
| `GLOSSARY.md` | Canonical domain terms — ensures consistent naming across all agents |
| `ARCHITECTURE.md` | System constraints, layers, and integration points — scopes what agents may touch |
| `DESIGN-SYSTEM.md` | Component registry — tells agents which UI components exist and what needs data ingestion |
| `OPEN-QUESTIONS.md` | Unresolved decisions — build subagents write here when they hit ambiguity |

**Convention**: `devkit/` files are written once by `msg-init` and updated incrementally by agents (e.g. `plan-em` appends to `AHA.md`). They are never deleted or recreated by other skills. If `devkit/` is absent, any skill that reads it must halt and direct the user back to `msg-init`.

## Inputs

| Name | Format | Source |
|------|--------|--------|
| Working directory state | `key=value` lines from `init-setup.sh` | `init-setup.sh` at Step 1 |
| Project metadata | Interview answers | `AskUserQuestion` at Step 2 |
| Architecture details | Interview answers | `AskUserQuestion` at Step 3 |
| Design system details | Interview answers | `AskUserQuestion` at Step 4 |
| Optional brief | Free text | User message at invocation |

## Outputs

| Name | Format | Destination |
|------|--------|-------------|
| devkit/ | Directory — agent context files | `<cwd>/devkit/` |
| devkit/AHA.md | Markdown from `refs/template-AHA.md` | `<cwd>/devkit/AHA.md` |
| devkit/GLOSSARY.md | Markdown from `refs/template-GLOSSARY.md` | `<cwd>/devkit/GLOSSARY.md` |
| devkit/ARCHITECTURE.md | Markdown from `refs/template-ARCHITECTURE.md`, customised with platform and architecture interview | `<cwd>/devkit/ARCHITECTURE.md` |
| devkit/DESIGN-SYSTEM.md | Markdown from `refs/template-DESIGN-SYSTEM.md`, customised with design system interview | `<cwd>/devkit/DESIGN-SYSTEM.md` |
| devkit/OPEN-QUESTIONS.md | Markdown from `refs/template-OPEN-QUESTIONS.md`, written by build subagents for unresolved ambiguity | `<cwd>/devkit/OPEN-QUESTIONS.md` |
| README.md | Markdown from `refs/template-README.md`, customised with project name | `<cwd>/README.md` |
| .gitignore | Plain text from `refs/template-gitignore.md`, stack-specific | `<cwd>/.gitignore` |
| CLAUDE.md | Markdown from `refs/template-CLAUDE.md`, customised with platform | `<cwd>/CLAUDE.md` |
| CHANGELOG.md | Markdown from `refs/template-CHANGELOG.md`, written and updated by subagents | `<cwd>/CHANGELOG.md` |
| features/ | Empty directory | `<cwd>/features/` |
| Manifest | Inline table — file, status, line count | Shown inline at Step 7 |

## Progress emission

Emit `Step X/7 — <title>` at the start of each step, unconditionally.

## Step-by-step protocol

**Step 1/7 — Scan the working directory**

Run `init-setup.sh` via Bash:

```
<skill_dir>/init-setup.sh "<cwd>"
```

Parse the five `key=value` lines it prints and hold `PRESENT`, `MISSING`, `STACK_HINTS`, and `STACK_DEFAULT` in conversation context.

If `ALL_COMPLETE=true`, emit `All foundational files exist — nothing to initialise.` and stop. Skip every later step.

**Step 2/7 — Project basics interview**

Run 4–5 `AskUserQuestion` prompts, one at a time. Skip Q2 when `STACK_HINTS` has exactly one entry — in that case set `PLATFORM = STACK_DEFAULT` directly, no question asked. Otherwise, if `STACK_DEFAULT` is not "Not specified", pre-select it as Q2's default option (user can still pick another).

| Q | Question | Format |
|---|----------|--------|
| 1 | Project name and one-line description? | Free text |
| 2 | Primary platform or stack? | 4 options + Other: Web (frontend), Mobile (iOS/Android), Backend API, CLI |
| 2b | What is the primary language or framework? (e.g. Flutter, Go, React, NestJS, Swift) | Free text |
| 3 | Team type? | 4 options + Other: Solo, Small team (<5), Cross-functional, Open source |
| 4 | Any house conventions already in place? | Free text or "None yet" |

Hold every answer in conversation context.

**Step 3/7 — Architecture interview**

Run 5 `AskUserQuestion` prompts, one at a time, to understand the intended system design.

| Q | Question | Format |
|---|----------|--------|
| A1 | Describe the major components of your system and how they interact. | Free text |
| A2 | What external services or APIs will your system depend on? (e.g. Stripe, Auth0, S3) | Free text or "None" |
| A3 | What data stores will you use? | 4 options + Other (multiSelect): PostgreSQL, MySQL / MariaDB, MongoDB / DynamoDB, Redis |
| A4 | Authentication approach? | 4 options + Other: JWT / stateless sessions, OAuth 2.0 / SSO, API keys, None / not applicable |
| A5 | Deployment pipeline? (e.g. GitHub Actions → AWS ECS, Vercel, manual) | 4 options + Other: GitHub Actions, Vercel / Netlify, AWS / GCP / Azure, Not decided yet |

Hold every answer as `ARCH_OVERVIEW` (A1), `ARCH_EXTERNAL` (A2), `ARCH_DATA_STORES` (A3), `ARCH_AUTH` (A4), `ARCH_DEPLOYMENT` (A5) in conversation context.

**Step 4/7 — Design system interview**

Ask D1 first. If the user answers "No", skip D2–D4 and set all DS vars to "Not applicable — no UI layer."

| Q | Question | Format |
|---|----------|--------|
| D1 | Does this project include a UI layer? | 2 options: Yes, No |
| D2 | Which component library are you using? | 4 options + Other: shadcn/ui, MUI / Material UI, Tailwind UI, Custom / none |
| D3 | Where do your design tokens live? (e.g. src/tokens/colors.ts, Figma variables, CSS custom properties) | Free text or "Not defined yet" |
| D4 | Any naming or folder structure conventions for components? (e.g. Atomic design, feature-based folders) | Free text or "None yet" |

Hold every answer as `DS_LIBRARY` (D2), `DS_TOKENS` (D3), `DS_CONVENTIONS` (D4) in conversation context.

**Step 5/7 — Generate missing files**

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
DS_LIBRARY="<D2 answer>" \
DS_TOKENS="<D3 answer>" \
DS_CONVENTIONS="<D4 answer>" \
<skill_dir>/init.sh "<cwd>"
```

`init.sh` handles all template extraction, placeholder substitution, gitignore stack selection, `features/` creation, and idempotency. Capture its stdout — it includes the manifest for Step 7.

**Step 6/7 — Verify**

`init.sh` exits non-zero and marks failures in the manifest if any write fails. If the script exits non-zero, surface its stderr and stop. Do not retry — the user re-runs or fixes manually.

**Step 7/7 — Emit manifest and suggest next step**

Print the manifest from `init.sh` stdout verbatim. Then emit a one-line next-step suggestion:

> Next: run `/plan-pm` to draft the first PRD.

Do not invoke another skill. The next slash command is the user's choice.

## References

- `init-setup.sh` — directory scanner; called at Step 1; outputs `ALL_COMPLETE`, `PRESENT`, `MISSING`, `STACK_HINTS`, `STACK_DEFAULT`
- `init.sh` — deterministic template writer; called at Step 5 with all interview answers as env vars
- `refs/template-AHA.md` — template for AHA.md (institutional knowledge log)
- `refs/template-GLOSSARY.md` — template for GLOSSARY.md (canonical domain terms)
- `refs/template-README.md` — template for README.md (project placeholder)
- `refs/template-gitignore.md` — .gitignore content keyed by platform/stack
- `refs/template-CLAUDE.md` — template for CLAUDE.md (Claude Code project instructions)
- `refs/template-ARCHITECTURE.md` — template for ARCHITECTURE.md (architecture stub, populated from Step 3 interview)
- `refs/template-DESIGN-SYSTEM.md` — template for DESIGN-SYSTEM.md (component registry, populated from Step 4 interview)
- `refs/template-CHANGELOG.md` — template for CHANGELOG.md (code change log, written by subagents)
- `refs/template-OPEN-QUESTIONS.md` — template for OPEN-QUESTIONS.md (ambiguity log, written by build subagents)
