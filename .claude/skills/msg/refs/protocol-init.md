---
name: msg-protocol-init
description: >
  Protocol for /msg --init — one-time project bootstrap. Scans the working
  directory, resolves the interview mode (cto = advisory / eng = direct) and
  delegates Step 2 to refs/protocol-cto.md or refs/protocol-eng.md, then
  creates a `devkit/` directory containing AHA.md, DOCTOR.md, ENV.md,
  GLOSSARY.md, ARCHITECTURE.md, DESIGN-SYSTEM.md, OPEN-QUESTIONS.md, and the
  seed `policy.json` (release-flow policy, `init:false`), plus root-level
  README.md, .gitignore, CLAUDE.md, CHANGELOG.md, and the three `features/`
  lifecycle lanes (`planned/`, `wip/`, `done/`, each with a `.gitkeep` marking the
  empty lane). `features/` is gitignored — PRDs are local working state.
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
| `DOCTOR.md` | Harness-incident ledger — where the harness itself misbehaved (script failures, tool errors, retries, missed writes). Write-mostly: no skill reads it during a run; `/msg --doctor` reads it on demand. **Gitignored** (see `.gitignore` row). Contract: [`shared/refs/doctor-logging.md`](../../shared/refs/doctor-logging.md) |
| `ENV.md` | Env-setup contract — how to stand up an isolated test environment. Human prose (prereqs, ports, seed fixture, gotchas) around one fenced `env` block with the provision/seed/reset/teardown verbs both gates read. **Committed** (documentation, not telemetry). `/pre-merge --init` fills in what it detects; gate runs only read. Contract: [`shared/refs/env-contract.md`](../../shared/refs/env-contract.md) |
| `GLOSSARY.md` | Canonical domain terms — ensures consistent naming across all agents |
| `ARCHITECTURE.md` | System constraints, layers, and integration points — scopes what agents may touch |
| `DESIGN-SYSTEM.md` | Component registry — tells agents which UI components exist and what needs data ingestion |
| `OPEN-QUESTIONS.md` | Unresolved decisions — build subagents write here when they hit ambiguity |
| `PLATFORMS.md` | Per-platform tolerance profiles + deploy pipeline — read by `/pre-merge` Step 0 (strictness profile + bucket set) and by `/post-merge` (`staging_deploy_cmd` / `production_deploy_cmd`) |
| `policy.json` | Committed release-flow + tooling policy read by both gates. `/msg --init` seeds it (`version`, `init:false`, `policies.release_flow`, and `policies.github_actions` — whether you want GitHub Actions CI at all, revisable via `/msg --update`); `--init` (the gate skills' own `--init`, distinct from this `/msg --init`) completes it (tooling, branch-protection, `init:true`); `/msg --init-staging` flips the flow to `staged`. Schema: [`shared/refs/policy-schema.md`](../../shared/refs/policy-schema.md) |

**Convention**: `devkit/` files are written once by `/msg --init` and updated incrementally by agents (e.g. `plan-em` appends to `AHA.md`). They are never deleted or recreated by other skills. If `devkit/` is absent, any skill that reads it must halt and direct the user back to `/msg --init`.

## Inputs

| Name | Format | Source |
|------|--------|--------|
| Working directory state | `key=value` lines from `init-setup.sh` | `init-setup.sh` at Step 1 |
| Interview mode | `cto` \| `eng` | `--cto`/`--eng` sub-flag, else the Step 2 mode gate |
| Project metadata | Interview answers (eng) or recommendations (cto) | Step 2, delegated |
| Architecture details | Interview answers (eng) or recommendations (cto) | Step 2, delegated |
| Release flow | Mode answer + branch topology detection | Step 2, delegated |
| GitHub Actions decision | Yes / No (+ reason) | Step 5 `AskUserQuestion` — asked only when a GitHub remote + `gh` exist |
| Design system details | Interview answers (eng) or recommendations (cto) | Step 2, delegated |
| Optional brief | Free text | User message at invocation |

## Outputs

| Name | Format | Destination |
|------|--------|-------------|
| devkit/ | Directory — agent context files | `<cwd>/devkit/` |
| devkit/AHA.md | Markdown from `refs/init/templates/template-AHA.md` | `<cwd>/devkit/AHA.md` |
| devkit/DOCTOR.md | Markdown from `refs/init/templates/template-DOCTOR.md` — the harness-incident ledger, appended to by `.claude/scripts/script-doctor-log.sh` and read only by `/msg --doctor`. **Gitignored** (see `.gitignore` row) — created, then ignored | `<cwd>/devkit/DOCTOR.md` |
| devkit/ENV.md | Markdown from `refs/init/templates/template-ENV.md` — the env-setup contract, scaffolded with `provisioner: "none"` and `[USER: …]` placeholders; `/pre-merge --init` detects and fills the verbs. **Committed**, never gitignored | `<cwd>/devkit/ENV.md` |
| devkit/GLOSSARY.md | Markdown from `refs/init/templates/template-GLOSSARY.md` | `<cwd>/devkit/GLOSSARY.md` |
| devkit/ARCHITECTURE.md | Markdown from `refs/init/templates/template-ARCHITECTURE.md`, customised with the platform and architecture answers (eng) or recommendations (cto) | `<cwd>/devkit/ARCHITECTURE.md` |
| devkit/DESIGN-SYSTEM.md | Markdown from `refs/init/templates/template-DESIGN-SYSTEM.md`, customised with the design-system answers (eng) or recommendations (cto) | `<cwd>/devkit/DESIGN-SYSTEM.md` |
| devkit/OPEN-QUESTIONS.md | Markdown from `refs/init/templates/template-OPEN-QUESTIONS.md`, written by build subagents for unresolved ambiguity | `<cwd>/devkit/OPEN-QUESTIONS.md` |
| devkit/PLATFORMS.md | Markdown from `refs/init/templates/template-PLATFORMS.md`, one default row per shipping platform resolved at Step 2 (`PLATFORMS`) | `<cwd>/devkit/PLATFORMS.md` |
| devkit/policy.json | JSON seed skeleton written by `.claude/scripts/script-policy-set.py` (not `init.sh`); `version:1`, `init:false`, `generated_by:"msg --init"`, `policies.release_flow` from Step 2. Only these keys (AC-LC1). Never overwritten — `--skip-if-exists` (AC-LC7). **Plus `policies.github_actions`, merged in by the same script at Step 5** when the CI question was asked — the sole key this protocol writes into a file it did not create. Schema: `shared/refs/policy-schema.md` | `<cwd>/devkit/policy.json` |
| .claude/msg/pref.json | JSON, `{"exec_mode": "team"}` — the persisted team/solo planning execution mode consumed by `plan-em` (Step 0). Deterministic (no interview input); written by `init.sh`. Default `team` (the pipeline default), flipped anytime via `plan-em --solo`/`--team`. Never overwritten. Schema + consumers: `shared/refs/exec-mode-pref.md` | `<cwd>/.claude/msg/pref.json` |
| README.md | Markdown from `refs/init/templates/template-README.md`, customised with project name | `<cwd>/README.md` |
| .gitignore | Plain text from `refs/init/templates/template-gitignore.md`, stack-specific. The Universal `# msg skill artifacts` section ignores `.pre-merge/`, `INTAKE.md`, `INTAKE-UPDATE.md`, `features/`, **and `devkit/DOCTOR.md`** — the ledger files, the PRD lanes and the harness telemetry are all local working state for a solo-dev workflow (still created/creatable; ignored ≠ absent) | `<cwd>/.gitignore` |
| CLAUDE.md | Markdown from `refs/init/templates/template-CLAUDE.md`, customised with platform | `<cwd>/CLAUDE.md` |
| CHANGELOG.md | Markdown from `refs/init/templates/template-CHANGELOG.md`, maintained by the `kermit` commit-gate hook (not by msg skills) | `<cwd>/CHANGELOG.md` |
| INTAKE.md | Markdown from `refs/init/templates/TEMPLATE-INTAKE.md` — the root backlog ledger (D13: repo root, **not** devkit/; it is a living ledger written by `/intake`, `plan-pm`, `post-merge`). Table header + status-lifecycle + grade-cell doc + the row table — no log section. The edit-history log lives in a sibling file, `INTAKE-UPDATE.md`, which `/msg --init` does **not** scaffold — it is lazy-created by `intake --update`/`--delete` on their first write, and gitignored alongside `INTAKE.md` once it exists. **Gitignored** (see `.gitignore` row) — created, then ignored | `<cwd>/INTAKE.md` |
| features/ lanes | Three lifecycle lanes — `planned/`, `wip/`, `done/`, each with a `.gitkeep` marking the empty lane on disk. **Gitignored** (see `.gitignore` row) — created, then ignored. A PRD lives in exactly one lane, matching its pipeline stage (drafted → `planned`, branch cut → `wip`, shipped → `done`) | `<cwd>/features/{planned,wip,done}/` |
| roadmap/TEMPLATE-roadmap.md | Markdown from `refs/init/templates/TEMPLATE-roadmap.md` — the format guide for `roadmap/roadmap.md`, which is **hand-authored by the human**; no skill generates it. Shipped so there is something to author against and the `/msg --gui` Roadmap tab can parse the result. Copied by the user to `roadmap/roadmap.md` when the project has enough PRDs to sequence | `<cwd>/roadmap/TEMPLATE-roadmap.md` |
| Migrated PRDs | Any pre-lane flat `features/prd-*/` dir is moved into a lane by the completion ladder (plain `mv`; `git mv` only for the legacy case where the dir is already tracked) (shipped → `done/`, live branch → `wip/`, else → `planned/`); reported as `migrated` in the manifest. Empty `features/` → no migration | `<cwd>/features/<lane>/prd-*/` |
| Manifest | Inline table — file, status (created / skipped / migrated / FAILED), line count | Shown inline at Step 5 |

## Progress emission

Emit `Step X/5 — <title>` at the start of each step, unconditionally.

## Step-by-step protocol

**Step 1/5 — Scan the working directory**

Run `init-setup.sh` via Bash:

```
<msg_skill_dir>/refs/init/init-setup.sh "<cwd>"
```

Parse the nine `key=value` lines it prints and hold `PRESENT`, `MISSING`, `STACK_HINTS`, `STACK_DEFAULT`, `LANG_DEFAULT`, `INITIALISED`, `ROW_GAPS`, and `FLAT_PRDS` in conversation context. (`FLAT_PRDS` — unsorted flat `features/prd-*/` dirs — is read-only here; only [`/msg --update`](protocol-update.md) acts on it interactively. Plain `--init` still migrates them silently via `init.sh`'s completion ladder, same as ever.)

**Resolve the run mode** — first row that matches:

| Condition | Mode |
|---|---|
| `ALL_COMPLETE=true` **and** `ROW_GAPS=none` | **Nothing to do** — emit `All foundational files exist — nothing to initialise.` and stop. Skip every later step. |
| `INITIALISED=true` (a `devkit/` is already there) | **Top-up** — this repo was bootstrapped by an earlier version and is missing files or rows added since. See *Top-up mode* below. |
| otherwise | **Bootstrap** — the full path. Steps 2–5 exactly as written. |

**Top-up mode.** A repo bootstrapped before `INTAKE.md`, `devkit/DOCTOR.md`, `devkit/ENV.md`, `devkit/PLATFORMS.md`,
`devkit/policy.json` or `.claude/msg/pref.json` existed can never receive them by
waiting: `init.sh` writes any absent file, but the protocol used to stop at "nothing to
initialise" before reaching it. Top-up is that repair — and it is **strictly additive**:

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
| `INTAKE.md` · `devkit/AHA.md` · `devkit/DOCTOR.md` · `devkit/ENV.md` · `devkit/GLOSSARY.md` · `devkit/OPEN-QUESTIONS.md` · `CHANGELOG.md` · `features/planned/` · `features/wip/` · `features/done/` · `roadmap/TEMPLATE-roadmap.md` | **none** — no placeholders; pure template |
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

`init.sh` handles all template extraction, placeholder substitution, gitignore stack selection, the three `features/` lifecycle lanes (`planned/`, `wip/`, `done/`, each with a `.gitkeep`), a one-time migration of any pre-lane flat `features/prd-*/` dirs into a lane by the completion ladder (plain `mv`, or `git mv` for a legacy tracked dir; reported as `migrated`), and idempotency. Capture its stdout — it includes the manifest for Step 5.

**Seed `devkit/policy.json`.** After `init.sh` returns (so `devkit/` exists), seed the committed
release-flow policy file — with `script-policy-set.py`, msg's only policy writer. One call does the
whole seed, including the `generated` date stamp:

```bash
.claude/scripts/script-policy-set.py --file "<cwd>/devkit/policy.json" \
  --create --skip-if-exists --stamp-by "msg --init" \
  --set policies.release_flow.mode='"<staged|direct>"' \
  --set policies.release_flow.prod_branch='"<PROD_BRANCH>"' \
  --set policies.release_flow.staging_branch='<"staging"|null>'
```

- `--create` writes the seed skeleton — `version:1`, `init:false`, `generated`, `generated_by`,
  `policies` — and nothing else (no `repo`, no `branch_protection`, no `steps`; those are the gate
  skills' `--init`'s to fill, which is why `init` is `false`) (AC-LC1). `policies.github_actions`
  is the one later addition, merged at **Step 5** once the GitHub-remote-gated CI question has an
  answer; on a no-remote repo it is never written at all.
- `--skip-if-exists` is AC-LC7: an existing `policy.json` is left byte-for-byte alone and the
  script reports `STATUS=skipped-exists`. Same rule as `init.sh`'s "writes only files absent from
  the target".
- The script stamps `generated` itself. (The protocol used to hand-`Write` this file on the
  grounds that "scripts can't stamp the date" — they can, `date +%F`; the whole hand-write path
  rested on a premise that never held.)

Map the Step 2 release-flow variables: `RELEASE_FLOW` Staged → `"staged"`, Direct → `"direct"`;
`prod_branch` = `PROD_BRANCH` (from `script-branch-topology.sh`, never asked — this is what makes a
`master` repo seed a `prod_branch` that exists); `staging_branch` = `STAGING_BRANCH` (already
resolved to `null` for direct, `"staging"` for staged). Both keys are a **downstream contract** —
`pre-merge` and `post-merge` read them off `policy.json` and `policy-schema.md` declares them — so
they are seeded whether or not anything was asked. Schema authority:
[`shared/refs/policy-schema.md`](../../shared/refs/policy-schema.md) ("Seed skeleton"). Read the
script's `STATUS=` line and add `devkit/policy.json` to the Step 5 manifest as `created` or
`skipped (exists)` accordingly; a non-zero exit is a hard stop, surfaced verbatim.

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

**Step 5/5 — Emit manifest, settle the GitHub questions, suggest next step**

Print the manifest from `init.sh` stdout verbatim.

**GitHub offers (C3 — asked only when a GitHub remote exists).** Read `HAS_GH_REMOTE`
from the shared topology resolver — the same call Step 2 already made, re-run here if
its output is no longer in context:

```bash
.claude/scripts/script-branch-topology.sh "<cwd>"
```

`HAS_GH_REMOTE=false` (no GitHub remote, or no `gh`) → skip **both** questions below
silently and write neither key; `staging`/`main`, protection, and CI are settled when
the user first pushes and runs the script (or `/msg --update`). Never a hard failure.

If `HAS_GH_REMOTE=true`, ask **both** questions in a single `AskUserQuestion`
call:

> header **GitHub Actions**, question "Run your CI on GitHub Actions? Actions minutes are metered on private repos on the Free plan."
> - **Yes, use GitHub Actions** — `/pre-merge --init` will scaffold `.github/workflows/pre-merge.yml`, and the gates expect PR checks to report.
> - **No — CI elsewhere or none** — no workflow is scaffolded and `/post-merge` accepts a PR with **zero** checks instead of flagging it. Every other gate is unchanged: red or pending checks (from any CI) still block the merge, and every human gate stands.

> header **Branch protection**, question "Set up branch protection on `staging` + `main` now? (recommended for `/post-merge`)"
> - **Yes, bootstrap it** — run `bash .claude/scripts/post-merge-protection.sh --bootstrap` (resolve locally-first, else `$HOME/.claude/scripts/…`); it's idempotent. Print each `BOOTSTRAPPED`/`BOOTSTRAP_FAILED` line.
> - **Skip** — note that `/post-merge` will refuse until protection is set; the user can re-run the script later.

The two are **independent** — bootstrap sets `required_status_checks
{strict:true, contexts:[]}`, so protection is worth having with no CI at all
(linear history, no force-push, required review). Never make the protection offer
conditional on the Actions answer.

**Record the Actions answer** in `devkit/policy.json` under
`policies.github_actions` (`../../shared/refs/policy-schema.md` §2b) — this is
the one key `/msg --init` writes *after* the Step 3 seed, and it goes through the
same writer:

```bash
.claude/scripts/script-policy-set.py --file "<cwd>/devkit/policy.json" \
  --set policies.github_actions='{"enabled": false, "reason": "<the user's words, e.g. private repo on GitHub Free — no Actions minutes>"}'
```

- Yes → `--set policies.github_actions='{"enabled": true}'` (no `reason` needed).
- No → `{"enabled": false, "reason": "<why>"}` — ask for the reason only if the user's answer didn't already give one; otherwise record the option's own wording. A missing `reason` is honored but earns an `unjustified-policy` warn (AC-S3).
- **Surgical by construction.** The script merges only the named path and preserves
  every sibling, so this is safe whether Step 3 created the file or skipped it because
  one already existed. An existing `policies.github_actions` is **overwritten with the
  new answer** (the user was just asked; their fresh answer wins) — the whole object is
  replaced, which is why the value is passed complete. Report the script's `SET=` line
  in the manifest. No `--stamp-by` here: `generated_by` must not change when the file
  was not otherwise written.

Then emit a one-line next-step suggestion:

> Next: run `/plan-pm` to draft the first PRD.

Do not invoke another skill (the bootstrap script is not a skill). The next slash command is the user's choice.

## References

- `refs/protocol-update.md` — `/msg --update`: re-scans an already-bootstrapped repo for the same gaps this protocol's Top-up mode closes, plus interactive (batched) classification of `FLAT_PRDS` — delegates back into this protocol's Steps 2–5 rather than duplicating them
- `refs/protocol-cto.md` — Step 2, cto mode (advisory): recommends the technical decisions against five objectives, derives every remaining `init.sh` variable
- `refs/protocol-eng.md` — Step 2, eng mode (direct execution): the batched question interview
- `refs/init/init-setup.sh` — directory scanner; called at Step 1; outputs `ALL_COMPLETE`, `PRESENT`, `MISSING`, `STACK_HINTS`, `STACK_DEFAULT`, `LANG_DEFAULT`, `INITIALISED`, `ROW_GAPS`, `FLAT_PRDS`. **Its `TARGETS` list gates `ALL_COMPLETE`** — any file this protocol creates must be listed there, or an already-bootstrapped repo can never receive it
- `refs/init/init.sh` — deterministic template writer; called at Step 3 with every Step 2 variable as env vars. Accepts an optional `INTERACTIVE_LANES` env var (set by `/msg --update` only) that turns silent rung-3 PRD-lane defaulting into an `UNRESOLVED` report instead
- `refs/init/templates/template-AHA.md` — template for AHA.md (institutional knowledge log)
- `refs/init/templates/template-DOCTOR.md` — template for devkit/DOCTOR.md (the harness-incident ledger; gitignored, written by `script-doctor-log.sh`, read by `/msg --doctor`)
- `refs/init/templates/template-ENV.md` — template for devkit/ENV.md (the env-setup contract: prose + one fenced `env` block of provision/seed/reset/teardown verbs; committed, read by both gates, filled in by `/pre-merge --init`)
- `refs/init/templates/template-GLOSSARY.md` — template for GLOSSARY.md (canonical domain terms)
- `refs/init/templates/template-README.md` — template for README.md (project placeholder)
- `refs/init/templates/template-gitignore.md` — .gitignore content keyed by platform/stack
- `refs/init/templates/template-CLAUDE.md` — template for CLAUDE.md (Claude Code project instructions)
- `refs/init/templates/template-ARCHITECTURE.md` — template for ARCHITECTURE.md (architecture stub, populated from Step 2 interview)
- `refs/init/templates/template-DESIGN-SYSTEM.md` — template for DESIGN-SYSTEM.md (component registry, populated from Step 2 interview)
- `refs/init/templates/template-CHANGELOG.md` — template for CHANGELOG.md (code change log, maintained by the `kermit` commit-gate hook)
- `refs/init/templates/template-OPEN-QUESTIONS.md` — template for OPEN-QUESTIONS.md (ambiguity log, written by build subagents)
- `refs/init/templates/template-PLATFORMS.md` — template for devkit/PLATFORMS.md (per-platform tolerance profiles + staging/production deploy commands; assembled from the P1 interview answer)
- `refs/init/templates/TEMPLATE-roadmap.md` — template for `roadmap/TEMPLATE-roadmap.md` (the format guide for the hand-authored `roadmap/roadmap.md`; scaffolded from its `## Template body` block, idempotently)
- `refs/init/templates/TEMPLATE-INTAKE.md` — template for root `INTAKE.md` (the backlog ledger written by `/intake`; scaffolded here from its `## Template body` block, idempotently; repo root per D13, never devkit/)
- `.claude/scripts/script-policy-set.py` — **the only writer of `devkit/policy.json`**: the Step 3 seed (`--create --skip-if-exists --stamp-by`) and the Step 5 `policies.github_actions` merge. Sets a dotted key path, creates missing parents, preserves every sibling, re-parses the result, rolls back a bad write
- `.claude/scripts/script-branch-topology.sh` — the one branch-detection block: `CURRENT_BRANCH`, `HAS_MAIN`/`HAS_MASTER`/`HAS_STAGING`, the resolved `PROD_BRANCH`, and the `HAS_GH_REMOTE` gate Step 5 reads. Called from Step 2 (via `protocol-cto.md`/`protocol-eng.md`) and Step 5
- `.claude/scripts/post-merge-protection.sh` — branch-protection `--bootstrap` (offered at Step 5 when a GitHub remote exists) / `--verify` (used by `/post-merge`)
- `../../shared/refs/policy-schema.md` — canonical `devkit/policy.json` schema; the Step 3 seed writes the "Seed skeleton" (`version`, `init:false`, `generated`, `generated_by`, `policies.release_flow`), and Step 5 adds `policies.github_actions` (§2b) when a GitHub remote made the CI question askable
