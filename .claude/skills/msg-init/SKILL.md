---
name: msg-init
description: >
  One-time project bootstrap. Scans the working directory, asks 3–4
  questions about the project, then creates any missing foundational
  files: AHA.md, GLOSSARY.md, README.md, .gitignore, CLAUDE.md,
  ARCHITECTURE.md, and the features/ directory. Idempotent — skips files
  that already exist; never overwrites. All other msg skills read these
  files but never create them.
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

## Inputs

| Name | Format | Source |
|------|--------|--------|
| Working directory state | File listing and stat checks | Bash scan at Step 1 |
| Project metadata | Interview answers | `AskUserQuestion` at Step 2 |
| Optional brief | Free text | User message at invocation |

## Outputs

| Name | Format | Destination |
|------|--------|-------------|
| AHA.md | Markdown from `refs/template-AHA.md` | `<cwd>/AHA.md` |
| GLOSSARY.md | Markdown from `refs/template-GLOSSARY.md` | `<cwd>/GLOSSARY.md` |
| README.md | Markdown from `refs/template-README.md`, customised with project name | `<cwd>/README.md` |
| .gitignore | Plain text from `refs/template-gitignore.md`, stack-specific | `<cwd>/.gitignore` |
| CLAUDE.md | Markdown from `refs/template-CLAUDE.md`, customised with platform | `<cwd>/CLAUDE.md` |
| ARCHITECTURE.md | Markdown from `refs/template-ARCHITECTURE.md`, customised with platform | `<cwd>/ARCHITECTURE.md` |
| features/ | Empty directory | `<cwd>/features/` |
| Manifest | Inline table — file, status, line count | Shown inline at Step 5 |

## Progress emission

Emit `Step X/5 — <title>` at the start of each step, unconditionally.

## Step-by-step protocol

**Step 1/5 — Scan the working directory**

Run via Bash in parallel: stat-check each of `AHA.md`, `GLOSSARY.md`, `README.md`, `.gitignore`, `CLAUDE.md`, `ARCHITECTURE.md`, `features/`. Build two lists in conversation context: `present[]` and `missing[]`.

Also detect stack hints: `package.json`, `tsconfig.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `Gemfile`, `pom.xml`, `build.gradle`, `Podfile`. Hold the detected stack as a default for Q2.

If all seven targets exist, emit `All foundational files exist — nothing to initialise.` and stop. Skip every later step.

**Step 2/5 — Interview**

Run 3–4 `AskUserQuestion` prompts, one at a time. Skip Q2 when exactly one stack hint is present (platform is unambiguous).

| Q | Question | Format |
|---|----------|--------|
| 1 | Project name and one-line description? | Free text |
| 2 | Primary platform or stack? | 4 options + Other: Web (frontend), Mobile (iOS/Android), Backend API, CLI |
| 3 | Team type? | 4 options + Other: Solo, Small team (<5), Cross-functional, Open source |
| 4 | Any house conventions already in place? | Free text or "None yet" |

Hold every answer in conversation context.

**Step 3/5 — Generate missing files**

Run `init.sh` via Bash, passing interview answers as env vars and the working directory as the positional argument:

```
PROJECT_NAME="<Q1 name>" \
PROJECT_DESCRIPTION="<Q1 description>" \
PLATFORM="<Q2 answer>" \
TEAM_TYPE="<Q3 answer>" \
CONVENTIONS="<Q4 answer>" \
<skill_dir>/init.sh "<cwd>"
```

`init.sh` handles all template extraction, placeholder substitution, gitignore stack selection, `features/` creation, and idempotency. Capture its stdout — it includes the manifest for Step 5.

**Step 4/5 — Verify**

`init.sh` exits non-zero and marks failures in the manifest if any write fails. If the script exits non-zero, surface its stderr and stop. Do not retry — the user re-runs or fixes manually.

**Step 5/5 — Emit manifest and suggest next step**

Print the manifest from `init.sh` stdout verbatim. Then emit a one-line next-step suggestion:

> Next: run `/plan-pm` to draft the first PRD.

Do not invoke another skill. The next slash command is the user's choice.

## References

- `init.sh` — deterministic template writer; called at Step 3 with interview answers as env vars
- `refs/template-AHA.md` — template for AHA.md (institutional knowledge log)
- `refs/template-GLOSSARY.md` — template for GLOSSARY.md (canonical domain terms)
- `refs/template-README.md` — template for README.md (project placeholder)
- `refs/template-gitignore.md` — .gitignore content keyed by platform/stack
- `refs/template-CLAUDE.md` — template for CLAUDE.md (Claude Code project instructions)
- `refs/template-ARCHITECTURE.md` — template for ARCHITECTURE.md (architecture stub)
