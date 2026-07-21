---
name: msg-protocol-init
description: >
  Protocol for /msg --init — one-time project bootstrap. Scans the working
  directory, resolves the interview mode (cto = advisory / eng = direct) and
  delegates Step 2 to refs/protocol-cto.md or refs/protocol-eng.md, then
  creates a `devkit/` directory containing AHA.md,
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

- Slash command `/msg --init` (mode asked at Step 2), `/msg --init --cto`, `/msg --init --eng`
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
| `policy.json` | Committed release-flow + tooling policy read by both gates. `/msg --init` seeds it (`version`, `init:false`, `policies.release_flow`); `--init` (the gate skills' own `--init`, distinct from this `/msg --init`; `--doctor` is a deprecated one-release alias) completes it (tooling, branch-protection, `init:true`); `/msg --init-staging` flips the flow to `staged`. Schema: [`shared/refs/policy-schema.md`](../../shared/refs/policy-schema.md) |

**Convention**: `devkit/` files are written once by `/msg --init` and updated incrementally by agents (e.g. `plan-em` appends to `AHA.md`). They are never deleted or recreated by other skills. If `devkit/` is absent, any skill that reads it must halt and direct the user back to `/msg --init`.

## Inputs

| Name | Format | Source |
|------|--------|--------|
| Working directory state | `key=value` lines from `init-setup.sh` | `init-setup.sh` at Step 1 |
| Interview mode | `cto` \| `eng` | `--cto`/`--eng` sub-flag, else the Step 2 mode gate |
| Project metadata | Interview answers (eng) or recommendations (cto) | Step 2, delegated |
| Architecture details | Interview answers (eng) or recommendations (cto) | Step 2, delegated |
| Release flow | Mode answer + branch topology detection | Step 2, delegated |
| Design system details | Interview answers (eng) or recommendations (cto) | Step 2, delegated |
| Optional brief | Free text | User message at invocation |

## Outputs

| Name | Format | Destination |
|------|--------|-------------|
| devkit/ | Directory — agent context files | `<cwd>/devkit/` |
| devkit/AHA.md | Markdown from `refs/init/templates/template-AHA.md` | `<cwd>/devkit/AHA.md` |
| devkit/GLOSSARY.md | Markdown from `refs/init/templates/template-GLOSSARY.md` | `<cwd>/devkit/GLOSSARY.md` |
| devkit/ARCHITECTURE.md | Markdown from `refs/init/templates/template-ARCHITECTURE.md`, customised with the platform and architecture answers (eng) or recommendations (cto) | `<cwd>/devkit/ARCHITECTURE.md` |
| devkit/DESIGN-SYSTEM.md | Markdown from `refs/init/templates/template-DESIGN-SYSTEM.md`, customised with the design-system answers (eng) or recommendations (cto) | `<cwd>/devkit/DESIGN-SYSTEM.md` |
| devkit/OPEN-QUESTIONS.md | Markdown from `refs/init/templates/template-OPEN-QUESTIONS.md`, written by build subagents for unresolved ambiguity | `<cwd>/devkit/OPEN-QUESTIONS.md` |
| devkit/PLATFORMS.md | Markdown from `refs/init/templates/template-PLATFORMS.md`, one default row per shipping platform resolved at Step 2 (`PLATFORMS`) | `<cwd>/devkit/PLATFORMS.md` |
| devkit/policy.json | JSON seed skeleton written by the skill (not `init.sh` — the skill stamps `generated`); `version:1`, `init:false`, `generated_by:"msg --init"`, `policies.release_flow` from Step 2. Only these keys (AC-LC1). Never overwritten (AC-LC7). Schema: `shared/refs/policy-schema.md` | `<cwd>/devkit/policy.json` |
| README.md | Markdown from `refs/init/templates/template-README.md`, customised with project name | `<cwd>/README.md` |
| .gitignore | Plain text from `refs/init/templates/template-gitignore.md`, stack-specific. The Universal `# msg skill artifacts` section ignores `.pre-merge/` **and `INTAKE.md`** — the ledger is local working state (it is still created; ignored ≠ absent) | `<cwd>/.gitignore` |
| CLAUDE.md | Markdown from `refs/init/templates/template-CLAUDE.md`, customised with platform | `<cwd>/CLAUDE.md` |
| CHANGELOG.md | Markdown from `refs/init/templates/template-CHANGELOG.md`, maintained by the `kermit` commit-gate hook (not by msg skills) | `<cwd>/CHANGELOG.md` |
| INTAKE.md | Markdown from `refs/init/templates/TEMPLATE-INTAKE.md` — the root backlog ledger (D13: repo root, **not** devkit/; it is a living ledger written by `/intake`, `plan-pm`, `post-merge`). Table header + status-lifecycle + grade-cell doc + the empty `## Update log` section. **Gitignored** (see `.gitignore` row) — created, then ignored | `<cwd>/INTAKE.md` |
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

Parse the eight `key=value` lines it prints and hold `PRESENT`, `MISSING`, `STACK_HINTS`, `STACK_DEFAULT`, `LANG_DEFAULT`, `INITIALISED`, and `ROW_GAPS` in conversation context.

**Resolve the run mode** — first row that matches:

| Condition | Mode |
|---|---|
| `ALL_COMPLETE=true` **and** `ROW_GAPS=none` | **Nothing to do** — emit `All foundational files exist — nothing to initialise.` and stop. Skip every later step. |
| `INITIALISED=true` (a `devkit/` is already there) | **Top-up** — this repo was bootstrapped by an earlier version and is missing files or rows added since. See *Top-up mode* below. |
| otherwise | **Bootstrap** — the full path. Steps 2–5 exactly as written. |

**Top-up mode.** A repo bootstrapped before `INTAKE.md`, `devkit/PLATFORMS.md` or
`devkit/policy.json` existed can never receive them by waiting: `init.sh` writes any
absent file, but the protocol used to stop at "nothing to initialise" before
reaching it. Top-up is that repair — and it is **strictly additive**:

- **Never rewrite a file that exists.** `init.sh`'s "writes only files absent from
  the target" rule is untouched, and no step here edits prose a human wrote.
  `devkit/AHA.md` and `GLOSSARY.md` in particular are accumulated institutional
  knowledge — recreating them would destroy the thing they exist to hold.
- **Missing files** are created by the ordinary Step 3 `init.sh` call.
- **Missing rows** in files that already exist are added at Step 3b, additively,
  behind a preview and an explicit confirmation.
- **Ask only what the gap needs** (Step 2). A repo missing only `INTAKE.md` needs
  no interview at all.
- **No mode gate.** Top-up always uses [`protocol-eng.md`](protocol-eng.md). cto
  mode recommends an architecture for a project that doesn't exist yet; a top-up
  repo already has one, so there is nothing to advise on — asking is correct.

Emit `Step X/5` progress as normal; Step 2 and Step 3b are the only steps that
behave differently.

**Step 2/5 — Interview (mode-gated, delegated)**

Step 2 resolves an **interview mode** and hands off. This protocol owns no interview
text — the two modes own it:

| Mode | Posture | Protocol |
|------|---------|----------|
| **eng** | **Direct execution** — ask and build, staff-engineer posture. The user makes the technical calls. | [`protocol-eng.md`](protocol-eng.md) |
| **cto** | **Advisory** — take the user's project description and *recommend* the technical decisions. For a user who wants a sound baseline architecture without knowing the questions to ask. | [`protocol-cto.md`](protocol-cto.md) |

**Mode resolution.** Read the invocation:

1. `--init --eng` → **eng**. No gate.
2. `--init --cto` → **cto**. No gate.
3. Bare `--init`, any natural-language bootstrap phrasing, or an **unrecognised
   sub-flag** (`--init --foo`) → **the mode gate** below. An unrecognised sub-flag is
   never silently ignored — it falls to the gate like a bare invocation.

**The mode gate — exactly one `AskUserQuestion`:**

> header **Setup**, question "How should we make the technical decisions for this project?"
> - **Recommend a setup for me** — describe what you're building; I'll choose the architecture, language, release flow and design system, explain each call, and you can override anything. → **cto**
> - **I'll decide, you ask** — I'll ask about platform, language, architecture, release flow and design system, and build exactly what you answer. → **eng**

Both option labels must stay legible to a non-technical reader: the gate never says
"cto" or "eng" — those are this protocol's words, not the user's.

**Then dispatch** to the selected protocol and follow it end to end. It returns with
every Step 3 variable resolved. Mode is invisible from here on: both protocols
converge on the **identical** env-var set below, so Steps 3/4/5 never branch on it.

**Top-up mode — ask only what the gap needs.** In top-up mode there is no gate:
compute the **required-variable subset** from `MISSING` + any `ROW_GAPS` the user
approves at Step 3b, using the table below, and pass that subset to
[`protocol-eng.md`](protocol-eng.md), which asks only the questions that resolve it.
A variable no missing file consumes is **not asked** — its file already exists and
already carries its value.

| Missing artifact | Variables it needs |
|---|---|
| `INTAKE.md` · `devkit/AHA.md` · `devkit/GLOSSARY.md` · `devkit/OPEN-QUESTIONS.md` · `CHANGELOG.md` · `features/` | **none** — no placeholders; pure template |
| `README.md` | `PROJECT_NAME`, `PROJECT_DESCRIPTION` |
| `CLAUDE.md` | `PROJECT_NAME`, `PLATFORM`, `LANGUAGE`, `CONVENTIONS` |
| `.gitignore` | `LANGUAGE`, `PLATFORM` — no placeholders, but they **select the section** (`init.sh` keys on `LANGUAGE` first, `PLATFORM` second) |
| `devkit/ARCHITECTURE.md` | `PROJECT_NAME`, `PLATFORM`, `ARCH_OVERVIEW`, `ARCH_EXTERNAL`, `ARCH_DATA_STORES`, `ARCH_AUTH`, `ARCH_DEPLOYMENT` |
| `devkit/DESIGN-SYSTEM.md` | `PROJECT_NAME`, `DS_LIBRARY`, `DS_TOKENS`, `DS_CONVENTIONS` |
| `devkit/PLATFORMS.md` | `PLATFORMS` — no placeholders, but it **selects the default rows** |
| `devkit/policy.json` | `RELEASE_FLOW`, `PROD_BRANCH`, `STAGING_BRANCH` |
| row gap `CLAUDE.md:language` | `LANGUAGE` |

Two variables are free — take them without asking whenever they're needed:
`PROD_BRANCH` from branch topology, and `LANGUAGE` from `LANG_DEFAULT` when
detection resolved it. `PROJECT_NAME` can be read off an existing `README.md`/
`CLAUDE.md` H1 rather than asked.

**Everything the subset does not name keeps `init.sh`'s default.** That is safe by
construction: every variable has a fallback, so an unasked one yields a `[USER: …]`
stub in a file that didn't exist a moment ago — never a change to one that did.

**Step 3/5 — Generate missing files**

Run `init.sh` via Bash, passing all interview answers as env vars and the working directory as the positional argument:

```
PROJECT_NAME="<Q1 name>" \
PROJECT_DESCRIPTION="<Q1 description>" \
PLATFORM="<primary platform/stack>" \
LANGUAGE="<primary language/framework>" \
CONVENTIONS="<house conventions, or the init.sh default>" \
ARCH_OVERVIEW="<system components and how they interact>" \
ARCH_EXTERNAL="<external services and APIs>" \
ARCH_DATA_STORES="<data stores>" \
ARCH_AUTH="<authentication approach, or the init.sh stub>" \
ARCH_DEPLOYMENT="<deployment pipeline>" \
PLATFORMS="<platform keys, space-separated — e.g. web ios>" \
DS_LIBRARY="<component library>" \
DS_TOKENS="<design token locations>" \
DS_CONVENTIONS="<component naming / folder conventions>" \
<msg_skill_dir>/refs/init/init.sh "<cwd>"
```

**This env block is the contract both modes converge on.** Before invoking, confirm
every variable above is set — neither protocol may leave one unresolved, and no
variable outside this block reaches `init.sh`.

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
   `branch_protection`, no `steps` — those are the gate skills' `--init`'s to fill (`--doctor` is
   a deprecated one-release alias), which is why `init` is
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

Map the Step 2 release-flow variables: `RELEASE_FLOW` Staged → `"staged"`, Direct → `"direct"`;
`prod_branch` = `PROD_BRANCH` (detected from branch topology, never asked — this is what makes a
`master` repo seed a `prod_branch` that exists); `staging_branch` = `STAGING_BRANCH` (already
resolved to `null` for direct, `"staging"` for staged). Both keys are a **downstream contract** —
`pre-merge` and `post-merge` read them off `policy.json` and `policy-schema.md` declares them — so
they are seeded whether or not anything was asked. Add `devkit/policy.json` to the Step 5 manifest
as `created` (or `skipped (exists)`).

**Step 3b — Row top-up (top-up mode only; skip when `ROW_GAPS=none`)**

`ROW_GAPS` names rows the templates gained *after* an existing file was written.
The file is otherwise fine, so it is never rewritten — the row is **inserted** and
nothing else is touched.

This step is the skill's, not `init.sh`'s. `init.sh` never modifies an existing
file and that rule does not bend here; keeping the row top-up outside it is what
lets the never-overwrite guarantee stay absolute.

| Token | Row to add | Where | Value |
|---|---|---|---|
| `CLAUDE.md:language` | `- **Language**: <LANGUAGE>` | `## Project`, directly under the `- **Platform**:` row (append to the list if that row is absent) | `LANG_DEFAULT` when detection resolved it; otherwise ask once (Q2b) |

1. **Preview.** Show each proposed insertion as a diff — the file, the row, and the
   line it lands under. Never show a change to an existing line: if a gap can only
   be closed by rewording one, it is **not** a row gap. Drop it and report it.
2. **Confirm** with one `AskUserQuestion`:

   > header **Top-up**, question "Add `<n>` missing row(s) to files that already exist? Nothing else in them changes."
   > - **Add them** — insert the rows above; existing content is untouched.
   > - **Skip** — leave the files exactly as they are. Everything else in this run still applies.

3. **On approval**, insert each row with `Edit`. On skip, note them in the manifest
   as `skipped (declined)` and continue — a declined row is never a failure.
4. **Idempotent.** A row already present is not a gap (`init-setup.sh` only emits
   the token when it is genuinely absent), so re-running is a no-op.

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

- `refs/protocol-cto.md` — Step 2, cto mode (advisory): recommends the technical decisions against five objectives, derives every remaining `init.sh` variable
- `refs/protocol-eng.md` — Step 2, eng mode (direct execution): the batched question interview
- `refs/init/init-setup.sh` — directory scanner; called at Step 1; outputs `ALL_COMPLETE`, `PRESENT`, `MISSING`, `STACK_HINTS`, `STACK_DEFAULT`, `LANG_DEFAULT`, `INITIALISED`, `ROW_GAPS`. **Its `TARGETS` list gates `ALL_COMPLETE`** — any file this protocol creates must be listed there, or an already-bootstrapped repo can never receive it
- `refs/init/init.sh` — deterministic template writer; called at Step 3 with every Step 2 variable as env vars
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
